# Instalace a vyzkoušení na iPhonu

## 1. Stáhni aplikaci (IPA)
GitHub Actions při každé změně sestaví **nepodepsaný** soubor `OsobniAgent-unsigned.ipa`:
- **Releases** repozitáře → poslední vydání → `OsobniAgent-unsigned.ipa` (+ `.sha256` pro kontrolu),
- nebo Actions → „iOS – sestavení IPA“ → poslední běh → Artifacts.

## 2. Nainstaluj ho do iPhonu
Apple nedovoluje instalovat aplikace mimo App Store bez podpisu. Máš tři možnosti:

| Možnost | Co potřebuješ | Platnost |
|---|---|---|
| **Sideloadly** (doporučeno) | Počítač s Windows/macOS, kabel, bezplatné Apple ID | 7 dní, pak znovu podepsat (data v aplikaci zůstanou) |
| **AltStore / SideStore** | Jednorázově počítač, pak obnovuje přímo v telefonu | 7 dní, obnovuje se automaticky |
| **Placený Apple Developer účet** (99 USD/rok) | Sideloadly nebo Xcode s tvým účtem | 1 rok |
| Mac s Xcode | `brew install xcodegen && xcodegen generate`, otevřít `OsobniAgent.xcodeproj`, zvolit svůj tým a spustit na telefonu | 7 dní (zdarma) / 1 rok (placený účet) |

Postup se Sideloadly:
1. Nainstaluj Sideloadly (sideloadly.io) a iTunes/Apple Devices (Windows).
2. Připoj iPhone kabelem, přetáhni `OsobniAgent-unsigned.ipa` do Sideloadly, zadej Apple ID, Start.
3. V iPhonu: **Nastavení → Obecné → Správa VPN a zařízení** → důvěřovat svému Apple ID.
4. **Nastavení → Soukromí a zabezpečení → Režim pro vývojáře → zapnout** (telefon se restartuje).

> Podepisovací nástroj potřebuje internet jen na počítači při podepisování. Samotná aplikace síť nepoužívá.

## 3. Nahraj modely (jednorázově)
Aplikace nic nestahuje. Modely si stáhneš ručně (např. v Safari v iPhonu → uloží se do Souborů → Stažené):

| Účel | Soubor | Kde | Velikost |
|---|---|---|---|
| Jazykový model (doporučený) | `Qwen3-4B-Instruct-2507-Q4_K_M.gguf` | huggingface.co/unsloth/Qwen3-4B-Instruct-2507-GGUF | ~2,5 GB |
| Alternativa (plynulejší čeština) | `google_gemma-3-4b-it-Q4_K_M.gguf` | huggingface.co/bartowski/google_gemma-3-4b-it-GGUF | ~2,5 GB |
| Přepis řeči | `ggml-large-v3-turbo-q5_0.bin` | huggingface.co/ggerganov/whisper.cpp | 547 MB |
| Hledání podle významu | `embeddinggemma-300M-Q8_0.gguf` | huggingface.co/ggml-org/embeddinggemma-300M-GGUF | ~330 MB |

V aplikaci: **Nastavení → Modely**:
1. Zvol typ modelu.
2. Vlož očekávaný **SHA-256** – na Hugging Face klepni na soubor, na jeho stránce je „SHA256: …“. (U Whisperu není nutné – aplikace zná oficiální součty.)
3. **Vybrat soubor modelu…** → aplikace soubor zkopíruje, ověří formát a součet. Nesouhlasí-li, soubor odmítne a smaže.
4. Soubor ve Stažených pak můžeš smazat (kopie je v aplikaci).

Českou kvalitu čtení nahlas zlepšíš stažením hlasu: Nastavení iOS → Zpřístupnění → Předčítání obsahu → Hlasy → Čeština → např. Zuzana (vylepšená).

---

## Vyzkoušení po milnících

### Milník 0 – prototyp: zvládne model češtinu a nástroje?
1. Nahraj jazykový model (viz výše).
2. **Nastavení → Test modelu (čeština a nástroje) → Spustit test.** 30 českých vět, cca 2–5 minut.
3. Výsledek ukáže: platný JSON (díky gramatice by měl být 100 %), správné rozhodnutí, správné argumenty, rychlost v tok/s.
4. **Uložit výsledek (JSON)** a pošli mi ho – podle něj doladím prompt nebo doporučím jiný model. Obsahuje jen testovací věty.
5. Pro porovnání nahraj i Gemmu, přepni ji (klepnutím v seznamu) a test spusť znovu.

Orientačně: správné rozhodnutí ≥ 85 % = dobrý model. Rychlost generování 4B Q4 na A16 by měla být zhruba 10–20 tok/s.

### Milník 1 – lokální chat
- Zapni **režim Letadlo** (všechno musí fungovat i tak).
- Záložka **Chat** → „Ahoj, co umíš?“ → odpověď se vypisuje průběžně.
- Ikona čipu vlevo nahoře je zelená = model načten.

### Milník 2 – nástroje a šifrovaná databáze
- „Poznamenej si: kód od garáže je 4512“ → karta Poznámka (Upravit / Zpět).
- „Přidej úkol zaplatit nájem do pátku“ → úkol s termínem.
- „V pátek ve 14 mám schůzku s Petrem v kanceláři“ → událost (model).
- „Co mám tento týden?“ → přehled.
- „Smaž poznámku o garáži“ → karta **Čeká na potvrzení**; nic se nesmaže, dokud neklepneš „Smazat“. Pak „Zpět“ → vrátí se.
- **Zámek:** odejdi z aplikace → po návratu chce Face ID. V přepínači aplikací je obsah skrytý.
- Nastavení → Stav zabezpečení: SQLCipher, Secure Enclave, kód zařízení, jailbreak.

### Milník 3 – připomínky a notifikace
- „Za 2 minuty mi připomeň vypnout troubu“ → zamkni telefon, **zavři aplikaci** (přetažením nahoru) → notifikace přijde.
- Na zamčené obrazovce je jen „Připomínka – Otevři aplikaci pro podrobnosti“.
- Podrž notifikaci → „Odložit o 10 minut“.
- „Každé pondělí a čtvrtek v 7 mi připomeň cvičení“ → karta s opakováním.
- Zapni úsporný režim a zopakuj – notifikace plánuje iOS, přijde i tak.

### Milník 4 – hlas
- Nahraj Whisper model.
- **Podrž velké tlačítko mikrofonu** dole, řekni „zítra v osm mi připomeň zavolat doktorovi“, pusť → přepis → karta připomínky. Tažením prstu nahoru nahrávku zrušíš. Krátké klepnutí otevře psaní.
- Nastavení → Hlas → „Číst odpovědi nahlas“.
- **Rychlý záznam:** přidej widget „Rychlý záznam“ na plochu nebo zamčenou obrazovku. Klepnutí → Face ID → rovnou nahrává → agent sám zařadí (poznámka / úkol / připomínka).
- Nastavení iOS → Zpřístupnění → Dotyk → Klepnutí na zadní stranu → Dvojité klepnutí → zkratka „Rychlý záznam“.

### Milník 5 – domovská obrazovka a shrnutí
- Záložka **Přehled**: nahoře „Právě probíhá“ / „Nejbližší“ s odpočtem, shrnutí dne, dnešek, nesplněné úkoly (odškrtnutí jedním klepnutím, s „Zpět“), příštích 7 dní, nedávné poznámky.
- ✨ u shrnutí → shrnutí vygeneruje lokální model.
- Nastavení → Notifikace → ranní přehled (výchozí 7:30), volitelně večerní.
- Nahraj EmbeddingGemma → Data → Poznámky → hledej „heslo“ nebo „co jsem psal o dovolené“ a stiskni Hledat (podle významu).

### Milník 6 – zálohy a zabezpečení
- Nastavení → Šifrovaná záloha → heslo → ulož soubor `.oabak` do Souborů.
- Smaž poznámku, pak Obnovení → vyber soubor → heslo → Obnovit → poznámka je zpět.
- Špatné heslo → „Špatné heslo nebo poškozený soubor“.
- Nastavení → Zabezpečení → „Smazat data po neúspěšných pokusech“ (volitelné).
- Nastavení → Zabezpečení → „Změnit nouzové heslo“.

---

## Verze 1.1 – nové funkce a jak je vyzkoušet

### Psaní místo mluvení
- Nastavení → Ovládání a propojení → **Preferuji psaní**. Hlavní tlačítko dole pak ukazuje klávesnici: klepnutím píšeš, podržením můžeš dál diktovat.
- Na přehledu je rychlá akce **Napsat**. Rychlý záznam z widgetu začne klávesnicí místo mikrofonu.

### Budíky, minutky a stopky
- „**Vzbuď mě zítra v 6:30**“, „**budík každý pracovní den v 6:15**“, „**minutka 10 minut na těstoviny**“, „**spusť stopky**“, „**zastav stopky**“, „**jaké mám budíky?**“, „**zruš budík**“. Rušení budíku se potvrzuje, minutka se zruší rovnou.
- Na **iOS 26** jsou to skutečné budíky Apple: zvoní i v tichém režimu, mají tlačítko **Odložit** (9 min) a minutka běží na zamčené obrazovce a v Dynamic Islandu. Při prvním použití povol „Budíky a časovače“.
- Na starším iOS chodí jako notifikace (tichý režim nepřebijí).
- Přehled → **Hodiny**: stopky s mezičasy, rychlé minutky (1–60 min), seznam a přidání budíků.

### Kalendář, Připomínky a Poznámky Apple
- Nastavení → **Kalendář, Připomínky a Poznámky Apple**. Všechno je ve výchozím stavu vypnuté.
- **Zapisovat události do Kalendáře**: vyber kalendář. Pro čistě lokální uložení zvol kalendář „Na iPhonu“, iCloud kalendář se synchronizuje do cloudu. Zkus „v pátek ve 14 schůzka s Petrem“ → událost je v aplikaci Kalendář. „Zpět“ ji zase smaže.
- **Zobrazovat události z Kalendáře v přehledu**: tvé ostatní události se objeví v Přehledu a agent je zná („co mám zítra?“).
- **Připomínky a úkoly**: zkopírují se do aplikace Připomínky, splnění i smazání se propíše.
- **Poznámky Apple**: v aplikaci Zkratky vytvoř zkratku **„Uložit do Poznámek“** (akce *Vytvořit poznámku* s obsahem *Vstup zkratky*; v podrobnostech zkratky zapni *Přijímat: Text*). U karty poznámky pak klepni na **Do Poznámek Apple**.
- Notifikace dál posílá jen tato aplikace, kopie v Kalendáři a Připomínkách jsou bez upozornění, aby nechodily dvakrát.

### Nahrávání a shrnutí přednášky / porady
1. Přehled → **Nahrát** (nebo Nastavení → Nahrát a shrnout).
2. Zvol typ (Přednáška / Porada / Rozhovor) a nahrávej. **Můžeš telefon zamknout**, nahrávání běží dál. Nahoře v aplikaci je červený pruh s časem. Telefonní hovor nahrávání pozastaví a po hovoru pokračuje.
3. **Konec** → **Přepsat a uložit**. Přepis běží offline (Whisper) po 5minutových částech a pak lokální model napíše název, shrnutí, hlavní body a úkoly. Hodina záznamu se zpracuje zhruba za 5–15 minut, nech přitom aplikaci otevřenou.
4. Výsledek se uloží jako **poznámka** (shrnutí + celý přepis s časovými značkami, jde v ní hledat). **Navržené úkoly** čekají na tvé potvrzení.
5. Jde zpracovat i **hotový zvukový soubor** (např. z Diktafonu): „Vybrat zvukový soubor…“.
- Rozlišení mluvčích („kdo co řekl“) offline zatím neumí.
- Nahrávej jen se souhlasem ostatních.
