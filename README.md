# Osobní agent (offline) pro iPhone

Osobní AI agent, který běží **100 % offline přímo v telefonu**. Bez serveru, bez cloudové AI, bez analytiky. Data nikdy neopustí zařízení.

- 🗣️ **Česky – psaním i hlasem.** Přepis řeči (whisper.cpp) i čtení nahlas fungují offline.
- 🛠️ **Agent opravdu jedná.** „Zítra v 8 mi připomeň zavolat doktorovi“ → připomínka + karta (Upravit / Zpět) + notifikace. Umí poznámky, úkoly, události, opakování („každé pondělí a čtvrtek v 7“), přehledy a hledání v poznámkách podle významu.
- ⚡ **Hybrid.** Běžné fráze řeší pevná pravidla okamžitě, složitější věci lokální model (llama.cpp, Metal) s gramatikou vynuceným voláním nástrojů.
- 🏠 **Dnešní přehled.** Co probíhá, co je nejbližší, shrnutí dne, úkoly, příštích 7 dní, poznámky.
- 🎙️ **Rychlý záznam.** Widget na ploše nebo zamčené obrazovce: klepni, řekni myšlenku, agent ji sám zařadí.
- ⏰ **Budíky, minutky, stopky.** „Vzbuď mě zítra v 6:30“, „minutka 10 minut“. Na iOS 26 skutečné budíky Apple (zvoní i v tichém režimu).
- 📅 **Kalendář, Připomínky a Poznámky Apple** (volitelné): agent zapisuje i do aplikací Apple a v přehledu ukazuje tvé události z Kalendáře.
- 🎓 **Nahrávky přednášek a porad.** Nahrávání i se zamčeným telefonem, přepis a shrnutí offline, hlavní body a navržené úkoly.
- ⌨️ **Psaní nebo mluvení.** Volba „Preferuji psaní“.
- 🔒 **Bezpečnost.** SQLCipher AES-256, klíč v Secure Enclave vázaný na Face ID, automatické zamykání, žádný síťový kód (ověřuje CI), šifrované zálohy Argon2id + AES-GCM, ověřování hashů modelů, mazání jen s potvrzením.

| Dokument | Obsah |
|---|---|
| [docs/INSTALACE.md](docs/INSTALACE.md) | Instalace do iPhonu, nahrání modelů, **postup testování po milnících** |
| [docs/ARCHITEKTURA.md](docs/ARCHITEKTURA.md) | Architektura, volba modelu a runtime, jak agent rozhoduje |
| [docs/BEZPECNOST.md](docs/BEZPECNOST.md) | Bezpečnostní audit a zbývající rizika |
| [third_party/VERSIONS.md](third_party/VERSIONS.md) | Připnuté verze a kontrolní součty závislostí |

## Vývoj
- Jádro (`Packages/AgentCore`) jde testovat i bez Macu: `cd Packages/AgentCore && swift test` (Linux potřebuje `libssl-dev`).
- iOS: `brew install xcodegen && xcodegen generate && open OsobniAgent.xcodeproj`.
- CI: `Jádro – testy` (Linux, 59 testů + ověření gramatik parserem llama.cpp), `iOS – sestavení IPA` (macOS, nepodepsané IPA + síťový audit). Tag `v*` vytvoří vydání s IPA.
