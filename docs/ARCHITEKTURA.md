# Architektura

## Cíl
Osobní AI agent pro **iPhone 14 Pro** (A16, 6 GB RAM), který běží **úplně offline**. Žádný server, žádná cloudová AI, žádná analytika. Data nikdy neopustí telefon.

## Platforma a technologie

| Oblast | Volba | Proč |
|---|---|---|
| Aplikace | Swift + SwiftUI, iOS 17+ | Nativní výkon, Secure Enclave, Metal, žádné cizí UI frameworky |
| Jazykový model | **llama.cpp** (oficiální XCFramework b11440, Metal) | Ověřený runtime, GGUF = jeden soubor (snadná výměna modelu), gramatiky GBNF pro spolehlivé volání nástrojů |
| Výchozí model | **Qwen3 4B Instruct 2507, Q4_K_M** (~2,5 GB) | Na 6 GB RAM nejlepší poměr kvality volání nástrojů a češtiny; alternativa Gemma 3 4B (plynulejší čeština). Výměna = nahrát jiný GGUF |
| Přepis řeči | **whisper.cpp** v1.9.2 + large-v3-turbo q5_0 | Kvalitní čeština, běží v procesu aplikace (nic se neposílá) |
| Čtení nahlas | AVSpeechSynthesizer (české hlasy iOS v zařízení) | Offline, bez dalších knihoven |
| Sémantické hledání | EmbeddingGemma 300M (GGUF) přes llama.cpp + fulltext FTS5 | Vektory uložené šifrovaně v DB, hledání bez internetu |
| Databáze | **SQLCipher 4.19** (AES-256, zkompilováno ze zdrojů do aplikace) | Šifrováno vše: poznámky, úkoly, události, historie chatu, vektory, nastavení |
| Odvození klíče z hesla | **Argon2id** (referenční implementace PHC) | Zálohy a nouzové heslo |

## Struktura repozitáře

```
App/                     iOS aplikace (SwiftUI)
  Sources/App            vstup, AppModel (stav, zámek, automatické zamykání)
  Sources/Security       KeyManager (Secure Enclave + Face ID), cesty, detekce jailbreaku
  Sources/AI             správa modelů (import + ověření hashe), načítání modelů, mikrofon, TTS
  Sources/Notifications  lokální notifikace (plánuje iOS → fungují i při zavřené aplikaci)
  Sources/UI             obrazovky (přehled, chat, karty akcí, data, nastavení, zálohy, test modelu)
Widget/                  widget „Rychlý záznam“ (plocha + zamčená obrazovka), bez přístupu k datům
Packages/AgentCore       jádro nezávislé na UI – testováno na Linuxu v CI
  Storage                šifrovaná DB (SQLCipher), schéma, zálohy
  Time                   deterministický parser českých časů, opakování, české formátování
  Agent                  nástroje, gramatika, pravidla, vykonavatel akcí, deník „Zpět“, prompty, benchmark
  Security               Argon2id + AES-GCM (zálohy, nouzové heslo), ověřování modelů
  Search                 sémantické hledání
Packages/LlamaKit        obal nad llama.cpp (generování s KV cache, gramatika, embeddingy)
Packages/WhisperBridge   obal nad whisper.cpp
tools/grammar-check      ověření gramatik skutečným parserem llama.cpp (v CI)
scripts/audit_no_network.sh  audit hotové aplikace: žádné síťové symboly ani analytika
```

## Jak agent rozhoduje (hybrid)

```
vstup (text / přepis řeči)
   │
   ├─ 1. rozpracovaný dotaz? („Kdy ti to mám připomenout?“ → „zítra ráno“) → doplní se
   ├─ 2. PEVNÁ PRAVIDLA (RuleRouter) – běžné fráze, okamžitě, bez modelu:
   │      „zítra v 8 mi připomeň…“, „poznamenej si…“, „přidej úkol…“, „co mám dnes?“, „vrať to“
   └─ 3. LOKÁLNÍ MODEL s nástroji:
          výstup je gramatikou VYNUCENÝ JSON: answer | ask | tool(name, args)
          → kontrola argumentů → čas spočítá deterministický parser (model data nepočítá)
          → vykonavatel (ToolExecutor) → karta akce → případně další krok (max. 4)
```

Nástroje: `create_note`, `create_task`, `create_reminder`, `create_event`, `complete_task`, `update_item`, `delete_item`, `list_agenda`, `list_tasks`, `search_notes`, `undo_last`, `set_timer`, `set_alarm`, `cancel_alarm`, `list_alarms`, `stopwatch`.

### Verze 1.1
- **Budíky/minutky:** jádro rozhoduje, aplikace plánuje přes protokol `ClockService` (`AppClockService`). Na iOS 26+ používá AlarmKit (budík zvoní i v tichém režimu, má odložení, Live Activity ve widgetu), na starším iOS lokální notifikace. Čas budíku má vlastní režim parseru: „v 6“ = 6:00, ne 18:00.
- **Kalendář/Připomínky Apple (EventKit):** zdrojem pravdy zůstává šifrovaná DB. `DataStore.onEntityChange` hlásí každou změnu položky a `AppleIntegration` ji zrcadlí do vybraného kalendáře nebo seznamu (tabulka `external_links` drží vazby). Proto fungují úpravy, smazání i „Zpět“. Čtení Kalendáře Apple jde volitelně do přehledu i k agentovi přes `ExternalAgendaItem`.
- **Poznámky Apple:** přes zkratku uživatele (`shortcuts://x-callback-url/run-shortcut`) s návratem do aplikace. Na 2 minuty se kvůli tomu neaktivuje zámek.
- **Nahrávky:** `LongRecorder` (režim `audio` na pozadí) ukládá 16kHz zvuk do dočasného souboru šifrovaného AES-GCM klíčem jen v paměti. `RecordingProcessor` přepisuje po 5 minutách (whisper.cpp), `TranscriptSummarizer` shrnuje po částech (map → reduce) kvůli malému kontextu a výsledek uloží jako poznámku. Úkoly ze shrnutí jsou jen návrhy (`ToolExecutor.propose`).

### Pravidla vynucená v kódu (ne jen v promptu)
- **Mazání vždy čeká na potvrzení** uživatelem (karta „Smazat / Zrušit“). Model ho provést nemůže.
- Vytváření se provede hned a ukáže kartu **Upravit / Zpět** (volitelně lze vyžadovat potvrzení všeho).
- Každá akce se zapíše do **deníku akcí** se stavem před a po → „Zpět“ funguje i vícekrát.
- Agent má přístup **jen k datům aplikace** – žádné kontakty, kalendář iOS, soubory ani síť.
- Data a výsledky nástrojů jdou do promptu v `<data>…</data>` a jsou **očištěna od řídicích sekvencí** šablony (ochrana proti vložení instrukcí do poznámky).

## Čas a opakování
`CzechTimeParser` rozumí: dnes/zítra/pozítří, dny v týdnu (i „příští pátek“, „do pátku“), data („15. 10.“, „1. listopadu“), časy („v 8“, „ve 14:30“, „o půl osmé“, „ve čtvrt na devět“, „za 2 hodiny“), části dne (ráno, večer…), opakování („každé pondělí a čtvrtek v 7“, „každý pracovní den“, „o víkendech“, „obden“, „každého 15.“, „každý rok“). Funguje i bez diakritiky. Co si domyslí („ve tři“ = 15:00), ukáže na kartě.

## Notifikace
Plánuje je iOS (UNUserNotificationCenter) → doručí se i při zavřené aplikaci, po restartu i v úsporném režimu. Aplikace drží nejbližších 60 (limit iOS je 64) a přeplánuje je při každé změně a při otevření. Na odložení (10 min / 1 h) přímo z notifikace není potřeba odemykat data. Ranní a večerní přehled přijde jako obecná notifikace; samotné shrnutí se vygeneruje až po odemčení (data jsou do té doby zašifrovaná).

## Výkon (iPhone 14 Pro)
- Model ~4B Q4 + kontext 3072 tokenů ≈ 3–3,5 GB RAM. Whisper se načítá až při diktování a po zamčení se uvolní.
- Společný začátek promptu (systémový prompt, historie) se drží v KV cache → další odpovědi začínají rychleji.
- Běžné příkazy řeší pravidla bez modelu (okamžitě).
