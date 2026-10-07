## Pocket Realm 3.1

**Opravy podle hraní na iPhonu**
- **Gemini funguje:** vypnuté „přemýšlení“ modelu (spotřebovalo celý limit a odpověď vyšla prázdná), při přetížení
  serveru se pokus sám zopakuje a naposledy zkusí lehčí model. Když online vypravěč přesto selže, hra napíše proč
  a tah vypráví telefon.
- **Méně opakování:** vypravěč v telefonu má zábranu proti opakování celých obratů (i z předchozích odpovědí)
  a tvůj tah čte až na konci zadání, aby odpovídal na všechno, co napíšeš.
- **Ochrana proti přehřátí:** když je telefon horký, vypravěč zpomalí, aby se čip ochladil a hra se nesekala.
  Celá historie příběhu se přepočítává mnohem méně často.

## Pocket Realm 3.0

Jednoduchá česká textová hra jako AI Dungeon. Vypravěč běží v telefonu, volitelně i online.

**Co je nového – celá hra je zjednodušená, aby základ fungoval dobře**
- **Rychlejší a chladnější telefon:** jedno volání vypravěče na tah místo dvou, obyčejný text místo JSONu,
  kratší odpovědi a model přepočítává jen nové tahy. Žádné animace na pozadí. Tah trvá zhruba 10–15 s.
- **Příběh drží pohromadě:** vypravěč má v paměti doslovně poslední tahy, krátká jasná pravidla s ukázkou,
  reaguje na to, co napíšeš, na otázky („Kde jsem?“) odpoví popisem a nic nevymýšlí bez příčiny.
- **Klidný úvod:** nejdřív zjistíš, kde jsi a co se děje, k problému se dostáváš postupně.
- **5 postav** (Válečník, Zloděj, Čaroděj, Bard, Lovec) s vlastní výbavou – bard už nemá meč.
  Vlastnosti mění šanci u riskantních činů.
- **Pryč:** zdraví, stres, předměty, čas akcí, počasí, ekonomika osady, úrovně, úspěchy, oznámení a nápovědy.
  Zůstal jen postup k cíli a nezdary.
- **Vlastní téma** se opravdu použije (dřív se vybíral pořád stejný příběh).
- **Nový vzhled:** tmavý, bez animací, velké čitelné písmo (nastavitelné), šetrný k baterii i očím.
- **Online vypravěč navrch (nepovinné):** Claude nebo Gemini s vlastním klíčem; bez signálu hraje hned offline.
- Rozehrané hry ze 2.x se převedou (jméno, postava, mód, celý deník).

## Pocket Realm 2.3

Temné RPG s AI vypravěčem, který běží celý v iPhonu.

**Novinky ve 2.3**
- **Výrazně méně zátěže pro telefon:** kontrola tvaru odpovědi vypravěče už neprochází u každého slova celý slovník
  modelu (262 tisíc položek) – ušetří ~20 s plně vytíženého procesoru na každý tah. Model běží na grafickém čipu
  se dvěma vlákny procesoru, animace pozadí se při psaní vypravěče zastaví, text se překresluje úsporněji.
- **Kratší a rychlejší vyprávění** (2–4 věty), takže tah trvá kratší dobu.
- **Je vidět, co se děje:** počítadlo sekund u čekání a nápis „Vypravěč zapisuje následky…“, když je text hotový
  a model ještě zapisuje zdraví, předměty a místo. Když vyprší časový limit, text končí celou větou.
- **Vypravěč reaguje na tvůj tah:** na otázku („Kde stojím?“) odpoví popisem, bez hodu kostkou a bez vlivu na výpravu.
  Výpravu posouvají jen činy, které míří na její aktuální úkol.
- **Žádné prozrazování:** vypravěč předem neřekne, co máš teprve zjistit (kolik je stráží, kudy vede cesta).
- **Bez čísel v textu**, ani slovy („ztratíš sedm bodů“, „stres stoupne“) – ty ukazuje panel.

**Ze 2.2**
- **Více rozehraných her najednou** – seznam na titulní obrazovce, jedním klepnutím přepneš mezi dlouhou a krátkou hrou.
  Osadu jde **zastavit**, když nehraješ (nebo nechat žít ve skutečném čase).
- **Pojistky:** kontrola stavu po každém tahu, časový limit vypravěče (tah se nikdy nezasekne), záloha uložené hry
  pro případ poškození, čistý restart modelu po chybě.
- **Vyvážení podle tisíců simulovaných her:** opatrný hráč vyhrává, bezhlavý prohrává; rozumný vládce dovede osadu
  k městu, líný ji ztratí. Pomalejší úrovně, rychlejší ekonomika osady, férovější nájezdy.
- **Testy:** zátěžové hry se „šíleným“ modelem, samotest aplikace v simulátoru při každém sestavení.

**Novinky ve 2.1**
- **Tvorba postavy:** 11 původů (nově Lovec, Potulný kněz, Vědmák, Bard, Kovář, Hrobník), každý se zvláštní schopností
  (Bojový řev, Léčivé ruce, Splynutí se stínem…, 2× denně), povaha – 2 z 12 vlastností (Odvážný, Otužilý, Noční pták,
  Šťastlivec, Rozený vůdce…) a 2 volné body do schopností.
- **Jako v AI Dungeon:** režimy Čin / Řeč / Příběh, tlačítko ⏩ Pokračuj, „Znovu“ (stejný hod, jiné vyprávění), „Vrátit tah“,
  paměť vypravěče, poznámka ke stylu a vlastní zápletka při založení hry.
- **Hloubka:** úrovně a zkušenosti, stavy hrdiny (krvácení, horečka, únava), počasí a roční období (úroda, cestování),
  zakázky od obyvatel, paměť postav, etapy výprav, povyšování osady.
- **Vzhled:** přehlednější panel (počasí, úroveň, stavy, zakázka, dá se sbalit), déšť, sníh, mlha a blesky ve scéně,
  oddělovače dní v deníku, iniciály, barevně odlišené události, list Svět s postavami.
- **Vypravěč:** vždy ve 2. osobě, bez čísel statistik v textu, kratší názvy míst; výprava postupuje jen odvážnými činy.
- **Technika:** zkušební hra se skutečným modelem v CI, staré uložené hry se načtou i v nové verzi.

**Ze 2.0**
- Vypravěč se stáhne sám (Gemma 3 4B, ~2,5 GB, ověřeno SHA-256), pak vše offline.
- Čtyři módy bez limitů tahů; čas běží podle činů; každý mód jde prohrát.

Instalace krok za krokem: [docs/INSTALACE.md](https://github.com/stepanvcelak11/osobn--agent/blob/main/docs/INSTALACE.md)
