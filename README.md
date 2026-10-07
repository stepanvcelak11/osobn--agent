# Pocket Realm

Temné RPG pro iPhone s AI vypravěčem (Pánem jeskyně), který běží **celý v telefonu**.
Po jednorázovém automatickém stažení vypravěče hraje úplně offline. Žádné účty, žádná analytika. Česky.

> Předchozí projekt v tomto repozitáři (Osobní AI agent) je archivovaný ve větvi
> [`archiv-osobni-agent`](../../tree/archiv-osobni-agent) a ve vydáních v1.0.0 a v1.1.0.

## Jak hra funguje

Jednoduchá textová hra jako **AI Dungeon, jen česky**: napíšeš, co tvůj hrdina udělá, a vypravěč odpoví, co se stane.
Žádné nabídky voleb, žádné nápovědy, žádné statistiky – jen příběh.

- **4 druhy příběhu:** Rychlá výprava (jeden cíl, tři kroky), Cesta světem (karavana přes divočinu),
  Vláda nad osadou (z vesnice město) a Nekonečná říše. Každý má cíl a každý jde prohrát.
- **5 postav:** Válečník, Zloděj, Čaroděj, Bard a Lovec (i v ženské podobě). Každá má jinou výbavu, kterou zná
  i vypravěč, a čtyři vlastnosti – Síla, Obratnost, Důvtip, Charisma.
- **Kostky jen u riskantních činů** (boj, plížení, kouzla, přesvědčování…). Vlastnosti mění šanci: válečník
  v boji uspěje skoro vždy, bard spíš přemluví stráž. Otázky („Kde to jsem?“) a běžné činy se nehází.
- **Cíl a nezdary:** tečky nahoře ukazují postup k cíli. Kroky k cíli hledáš sám. Nepovedené riskantní činy
  přidávají nezdary; když jich je moc, příběh končí prohrou.
- **Čin / Řeč / Příběh / ⏩ Pokračuj, Znovu, Vrátit, Paměť vypravěče a styl vyprávění** – jako v AI Dungeon.
- **Vlastní téma:** napiš, o čem má výprava být („Drak unesl princeznu z Bezdězu“), a hra z toho udělá příběh.
- **Víc her najednou** – každá hra se ukládá po každém tahu.
- **Online vypravěč navrch (nepovinné):** v Nastavení můžeš připojit Claude (Anthropic) nebo Gemini (Google)
  s vlastním klíčem. Bez signálu hra okamžitě vypráví offline.

Vypravěč v telefonu (Gemma 3 4B) dostává jen krátká pravidla a doslovně celé poslední tahy, odpovídá obyčejným
textem 2–4 větami a model při každém tahu přepočítá jen pár desítek nových slov – tah trvá zhruba 10–15 s.

## Instalace

**Podrobný návod krok za krokem: [docs/INSTALACE.md](docs/INSTALACE.md)**

1. V [Releases](../../releases) stáhni `PocketRealm-unsigned.ipa`.
2. Nainstaluj přes **Sideloadly** nebo **AltStore** (podepíše se tvým Apple ID; bezplatný účet = platnost 7 dní).
3. Na iPhonu: Nastavení → Obecné → VPN a správa zařízení → důvěřovat svému Apple ID.

### Vypravěč se stáhne sám

Při prvním spuštění hra **automaticky stáhne** vypravěče – jazykový model Gemma 3 4B (asi 2,5 GB) – a potom
hlasové ovládání Whisper (asi 550 MB, lze vypnout v Nastavení). Stahuje se jednou, i na pozadí, ideálně na Wi-Fi.
Soubor se ověří podle velikosti a kontrolního součtu SHA-256; když jeden zdroj selže, zkusí se další zrcadlo.
Potom už hra běží **úplně offline**. Než se stahování dokončí, dá se hrát s jednoduchým záložním vypravěčem.

Na iPhonu 14 Pro trvá jeden tah zhruba 10–15 s (vyprávění se zobrazuje průběžně).

## Soukromí a bezpečnost

- Bez online vypravěče je jediné připojení k internetu jednorázové stažení modelů z `huggingface.co`.
  Online vypravěč (nepovinný) posílá text příběhu jen zvolené službě; klíč je v Klíčence telefonu.
  CI po každém sestavení kontroluje, že binárka neobsahuje jiné adresy, sockety ani analytiku (`scripts/audit_no_network.sh`).
- Uložené hry jsou JSON soubory v kontejneru aplikace, vyloučené ze zálohy iCloud.
- Řídicí sekvence šablon se v textu hráče neutralizují; pravidla hry (kostky, postup, nezdary) počítá hra, ne model.

## Vývoj

```
Packages/RealmCore     herní jádro (příběh, postavy, kostky, vypravěč, online API) + testy (Linux i macOS)
Packages/LlamaKit      llama.cpp (XCFramework b11440) – jazykový model
Packages/WhisperBridge whisper.cpp (XCFramework v1.9.2) – rozpoznávání řeči
App/                   SwiftUI aplikace (iOS 17+)
tools/playtest         zkušební hra se skutečným modelem (macOS; CI „Zkušební hra se skutečným modelem“)
```

```bash
cd Packages/RealmCore && swift test          # testy jádra
brew install xcodegen && xcodegen generate   # projekt Xcode
```

Vydání: GitHub Actions → „iOS – sestavení IPA“ → Run workflow → `release_tag` (např. `v3.0.1`).
