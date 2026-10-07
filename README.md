# Rovnováha

Česká karetní hra ve stylu **Reigns** a **Lapse**: vládneš zemi po kolapsu a za tebou chodí ministři, generálové,
vědci i obyčejní lidé. Každá karta má **čtyři možnosti** – táhni ji **doleva, doprava, nahoru, nebo dolů**.

**Hrát: https://stepanvcelak11.github.io/osobn--agent/**

## Jak hra funguje

Sedm ukazatelů drží zemi pohromadě. **Ideál je uprostřed – oba kraje jsou katastrofa:**

| | Ukazatel | 0 % | 100 % |
|---|---|---|---|
| 💰 | Finance | bankrot | oligarchie, hyperinflace |
| 👥 | Lid | revoluce, stávka | populismus |
| 🛡️ | Síla | bezvládí, vpád | vojenský puč |
| 🔬 | Věda | zaostalost | singularita |
| 🌿 | Příroda | otrávený svět | divočina pohltí civilizaci |
| 🕯️ | Víra | apatie | fanatismus, inkvizice |
| 🤝 | Diplomacie | izolace, embargo | vazalství |

- Při tažení karty se pod ukazateli objeví **tečky** – čeho se rozhodnutí dotkne (velká = hodně). Směr musíš odhadnout.
- Rozhodnutí mají **následky**: oživená umělá inteligence se za pár měsíců vrátí s požadavkem, prodaná elektrárna
  zdraží proud, spojenectví s Federací skončí žádostí o základnu…
- Když vláda padne, úřad převezme **nástupce** – svět si ale pamatuje, co se stalo.
- **Kronika** ukazuje všechny vůdce a sbírku **14 konců**.

## Hloubka hry

- **Jedenáct typů vůdců:** Vizionář (vidí směr změn), Krizový manažer (návrat z krajnosti ×2), Vyčkávač (každých 5 rozhodnutí odloží kartu),
  Kormidelník (každých 5 rozhodnutí posune ukazatel o 15 k rovnováze), Prezident s rádcem (rada je v 70 % nejlepší),
  Zachránce (jednou se odrazí od kraje), Charismatik (vztahy ×2), Prorok (vidí další kartu), Byrokrat (volby ×0,75, zákony ×2),
  Hazardér (náhodný účinek 0,5–1,5×, dvě pečetě za úkol), Reformátor (každých 5 rozhodnutí zavede/zruší zákon).
- **Výhody:** po splněném úkolu výběr jedné ze tří výhod na zbytek vlády.
- **Volby** každé 4 roky (průměr Lidu a Spojenců aspoň 40 %), **víceměsíční krize** (epidemie, povodeň, útok na síť).
- **Statistiky a hodnocení** (Nováček → Legenda republiky), žebříček nejdelších vlád, **bleskovka** na čas (3 min, +5 s za rozhodnutí).
- **Lidé si pamatují** – věrní pomáhají, rozzlobení škodí.
- **Zákony** platí, dokud je někdo nezruší, a každý měsíc posouvají ukazatele.
- **Úkoly vůdců** dávají pečetě; čas a pečetě otevírají **éry** (Obnova → Rozmach → Nové hranice).
- **Podmíněné volby** (klíč) se odemknou jen silné zemi; **tři tajné příběhy** končí legendou (18 konců celkem).
- Obsah hloubky je v `hra/world.js`.

## Na iPhonu jako aplikace (offline)

1. Otevři odkaz výše v **Safari**.
2. Klepni na **Sdílet** (čtvereček se šipkou) → **Přidat na plochu** → **Přidat**.
3. Spouštěj ikonu z plochy. Hra běží celá v telefonu, **i bez internetu**; rozehraná hra se ukládá sama.

Nová verze se stáhne sama při příštím spuštění s internetem.

## Vývoj

```
hra/cards.js     balíček karet, postavy, konce (čeština, zástupné znaky {osl} a {a} pro oslovení a ženské tvary)
hra/game.js      herní logika bez DOMu (výběr karet, navazující příběhy, konce vlády, nástupci)
hra/ui.js        zobrazení a ovládání (tažení do 4 stran, šipky, klávesy, uložení)
hra/sw.js        offline (service worker)
hra/test/        testy + simulace tisíců her (vyváženost, dosažitelnost konců, navazující příběhy)
```

```bash
cd hra && node --test test/game.test.mjs   # testy
python3 -m http.server -d hra 8000         # hrát lokálně na http://localhost:8000
```

Každý push do `main` spustí testy a nasadí hru do větve `gh-pages` (GitHub Pages).

> Předchozí projekty: textové RPG s AI vypravěčem je ve větvi [`archiv-pocket-realm-ai`](../../tree/archiv-pocket-realm-ai),
> osobní AI agent ve větvi [`archiv-osobni-agent`](../../tree/archiv-osobni-agent).
