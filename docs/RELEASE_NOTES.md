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
