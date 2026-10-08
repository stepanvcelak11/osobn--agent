// Větvení dějin a divy světa.
// BRANCH_CARDS: na každém přelomu si hráč vybere jeden ze dvou objevů (příznak b_*),
// který v další době odemkne dvě karty – důsledky toho objevu.
// WONDERS + WONDER_CARDS: v každé době lze postavit jeden div světa. Stavba trvá několik let
// (řetěz tří karet); dokončený div navždy uklidní jeden ukazatel.

const o = ([t, e, more = {}]) => ({ t, e, ...more });
const c = (id, age, who, text, l, r, u, d, extra = {}) => {
  const card = { id, who, text, opts: { left: o(l), right: o(r), up: o(u), down: o(d) }, ...extra };
  if (age) card.age = age;
  return card;
};

export const BRANCH_CARDS = [
  // ── 1→2: zemědělství a pole ───────────────────────────
  c('br_pole_1', 2, 'pis', 'Pole se táhnou až k obzoru a sýpky praskají. Sedláci se ale přou o meze, {osl}. Mám zeměměřiče rozdělit půdu podle provazu?',
    ['Měřit a zapsat', { ved: 10, lid: -5 }], ['Půda patří chrámu', { vir: 5, lid: -10, fin: 5 }], ['Ať si to rozdělí', { lid: 5, sil: -5 }], ['Daň z každého lánu', { fin: 10, lid: -5, dip: -5 }], { req: ['b_pole'] }),
  c('br_pole_2', 2, 'kup', 'Máme víc obilí, než sníme. Cizí lodě ho chtějí koupit, ale když přijde neúroda, budeme litovat, {osl}.',
    ['Prodat přebytky', { fin: 10, dip: 5, lid: -10 }], ['Schovat do sýpek', { lid: 5, fin: -5 }], ['Obilí za cedry', { dip: 5, pri: 5, lid: -5 }], ['Rozdat chudým', { lid: 10, fin: -10 }], { req: ['b_pole'] }),
  // ── 1→2: chov stád ────────────────────────────────────
  c('br_stada_1', 2, 'voj', 'Pastevci zvládnou koně. Na koni dojedeme dál než kterákoli pěchota. Dáš mi jízdu, {osl}?',
    ['Vycvičit jezdce', { sil: 10, fin: -10 }], ['Koně jen k orbě', { fin: 10, sil: -10 }], ['Válečné vozy', { sil: 5, dip: -5, lid: -5 }], ['Koně prodávat', { fin: 5, lid: 5, sil: -5, dip: 5 }], { req: ['b_stada'] }),
  c('br_stada_2', 2, 'knez', 'Stáda spásla posvátný háj až na holou zem. Velekněz žádá, aby pastevci odvedli dobytek pryč.',
    ['Háj je posvátný', { pri: 10, fin: -5, sil: -5 }], ['Stáda mají přednost', { fin: 10, vir: -5, pri: -5 }], ['Obětovat býka', { vir: 5, fin: -5 }], ['Ohradit pastviny', { pri: 5, ved: 5, lid: -10 }], { req: ['b_stada'] }),

  // ── 2→3: kláštery a víra ──────────────────────────────
  c('br_klastery_1', 3, 'bisk', 'Mniši v klášteře opisují staré knihy a učí číst. Opat žádá o les a tři vesnice, aby se uživili.',
    ['Dát jim les i vsi', { ved: 10, fin: -5, pri: -5 }], ['Jen jednu ves', { ved: 5, lid: -5 }], ['Ať se uživí sami', { fin: 10, vir: -5 }], ['Škola i pro sedláky', { lid: 10, vir: -5, fin: -5 }], { req: ['b_klastery'] }),
  c('br_klastery_2', 3, 'sedl', 'Klášter chce desátek z každé sklizně, {osl}. Lidé říkají, že mniši jedí lépe než my na poli.',
    ['Desátek se platí', { vir: 5, lid: -10, fin: 5 }], ['Zrušit desátek', { lid: 10, vir: -5 }], ['Polovinu klášteru', { lid: 5, fin: -5 }], ['Ať mniši pracují', { fin: 5, lid: -5 }], { req: ['b_klastery'] }),
  // ── 2→3: hrady a léna ─────────────────────────────────
  c('br_hrady_1', 3, 'ryt', 'Páni na hradech vybírají mýto a nikoho se neptají. Hradní páni tě poslouchají jen, když se jim to hodí.',
    ['Zbořit nejdrzejší hrad', { sil: 5, dip: -5, fin: -5 }], ['Dát jim víc lén', { sil: 5, fin: 5, lid: -10 }], ['Královská mýta', { fin: 10, sil: -5 }], ['Turnaj a smír', { dip: 5, lid: 5, fin: -5, sil: -5 }], { req: ['b_hrady'] }),
  c('br_hrady_2', 3, 'sedl', 'Rytíři honí zvěř přes naše obilí a pán nás nutí robotovat šest dní v týdnu. Ochrana hradu je drahá, {osl}.',
    ['Snížit robotu', { lid: 10, sil: -10 }], ['Robota je robota', { fin: 5, sil: 5, lid: -10 }], ['Zakázat hony v polích', { lid: 5, sil: -5 }], ['Utečte do města', { lid: 5, fin: 5, sil: -5, dip: -5 }], { req: ['b_hrady'] }),

  // ── 3→4: knihtisk ─────────────────────────────────────
  c('br_tisk_1', 4, 'rev', 'V Praze vychází první noviny! Píšou o cenách chleba, o válkách i o tvém dvoře. Někdo už chce cenzuru.',
    ['Svoboda tisku', { lid: 10, ved: 5, sil: -10 }], ['Zavést cenzuru', { sil: 5, lid: -10, ved: -5 }], ['Dvorní noviny', { fin: 5, lid: -5 }], ['Psát do nich sám', { lid: 5, fin: -5 }], { req: ['b_tisk'] }),
  c('br_tisk_2', 4, 'hrabe', 'Po městě kolují pamflety, které tě zesměšňují, {osl}. Tiskárny je chrlí po tisících každou noc.',
    ['Zavřít tiskárny', { sil: 5, ved: -10, lid: -5 }], ['Najít autora', { sil: 5, lid: -5 }], ['Smát se s nimi', { lid: 10, sil: -5, fin: -5 }], ['Odpovědět pamfletem', { ved: 5, sil: -5 }], { req: ['b_tisk'] }),
  // ── 3→4: střelný prach ────────────────────────────────
  c('br_prach_1', 4, 'kap', 'Děla nové generace prostřelí každou hradbu. Generalita chce dělostřelecký pluk a slévárnu, {osl}.',
    ['Postavit slévárnu', { sil: 10, fin: -10, pri: -5 }], ['Koupit děla v cizině', { sil: 5, fin: -5, dip: 5 }], ['Děla na lodě', { fin: 10, dip: -10 }], ['Hradby stačí', { fin: 5, sil: -5, pri: 5 }], { req: ['b_prach'] }),
  c('br_prach_2', 4, 'tov', 'Mušketýři potřebují tisíce pušek a prach. Moje továrna je udělá – za zakázku na deset let dopředu.',
    ['Podepsat zakázku', { sil: 10, fin: -10 }], ['Jen polovinu', { sil: 5, fin: -5 }], ['Ať soutěží víc dílen', { fin: 5, ved: 5, sil: -5 }], ['Raději pluhy', { lid: 5, fin: 5, sil: -5 }], { req: ['b_prach'] }),

  // ── 4→5: elektřina ────────────────────────────────────
  c('br_elektrina_1', 5, 'inz', 'Můžeme natáhnout dráty do každé vesnice, {osl}. Světlo, rádio, mlýny bez vody. Stojí to ale jmění.',
    ['Elektřina všem', { lid: 10, fin: -10 }], ['Jen do měst', { ved: 5, lid: -5 }], ['Ať to platí firmy', { fin: 10, lid: -5, sil: -5 }], ['Vodní elektrárny', { pri: -5, fin: 5 }], { req: ['b_elektrina'] }),
  c('br_elektrina_2', 5, 'novin', 'Rozhlas teď mluví do každé kuchyně. Kdo ovládne vysílání, ovládne lidi. Komu ho svěříš, {osl}?',
    ['Svobodný rozhlas', { lid: 10, sil: -5, fin: -5 }], ['Státní rozhlas', { sil: 5, lid: -5, ved: -5 }], ['Vysílat i za hranice', { dip: 10, fin: -5, sil: -5 }], ['Reklama ho zaplatí', { fin: 10, lid: -5, ved: -5 }], { req: ['b_elektrina'] }),
  // ── 4→5: ropa a motor ─────────────────────────────────
  c('br_ropa_1', 5, 'inz', 'Automobilka chce postavit továrnu na lidový vůz. Auto pro každou rodinu – ale silnice jsou blátivé cesty.',
    ['Továrnu i silnice', { fin: -10, lid: 10, pri: -10 }], ['Jen továrnu', { fin: 10, pri: -5, lid: -5 }], ['Raději vlaky', { pri: 10, lid: -5, sil: -5 }], ['Auta pro armádu', { sil: 5, fin: 5, lid: -5 }], { req: ['b_ropa'] }),
  c('br_ropa_2', 5, 'dipl', 'Ropa je teď krev světa a my ji nemáme. Pouštní šejk nabízí smlouvu na dvacet let, {osl}.',
    ['Podepsat smlouvu', { dip: 10, fin: -10 }], ['Hledat ropu doma', { ved: 5, pri: -5, fin: 5 }], ['Uhlí stačí', { fin: 5, pri: -5, dip: -5 }], ['Poslat loďstvo', { fin: 10, dip: -10, lid: -5 }], { req: ['b_ropa'] }),

  // ── 5→6: internet ─────────────────────────────────────
  c('br_sit_1', 6, 'infl', 'Celá země je online a já mám deset milionů sledujících! Sítě ale zaplavily lži a hádky, {osl}.',
    ['Regulovat sítě', { lid: -5, ved: 5 }], ['Nechat to být', { lid: 5, ved: -5 }], ['Učit děti média', { ved: 10, fin: -5, lid: -5 }], ['Státní aplikace', { sil: 5, lid: -5, ved: -5 }], { req: ['b_sit'] }),
  c('br_sit_2', 6, 'tech', 'Moje firma ví o lidech víc než oni sami. Chceš ta data pro úřady? Za drobnou úlevu na daních, {osl}.',
    ['Data ano, úleva ne', { sil: 5, lid: -5 }], ['Ochrana soukromí', { lid: 10, fin: -5, sil: -5 }], ['Zdanit data', { fin: 10, ved: -5, dip: -5 }], ['Spolupracovat', { ved: 10, fin: -5, lid: -5 }], { req: ['b_sit'] }),
  // ── 5→6: vesmírný program ─────────────────────────────
  c('br_vesmir_1', 6, 'tech', 'Moje rakety přistávají zpátky na rampě. Pošlu tvého astronauta na Měsíc – stačí státní zakázka, {osl}.',
    ['Letíme na Měsíc', { ved: 10, lid: 5, fin: -10, pri: -5 }], ['Jen satelity', { ved: 5, dip: 5, fin: -5 }], ['Ať letí soukromě', { fin: 10, dip: -5 }], ['Peníze na Zemi', { lid: 5, ved: -10, fin: 5 }], { req: ['b_vesmir'] }),
  c('br_vesmir_2', 6, 'klim', 'Družice ukazují, jak rychle tají ledovce. Konečně máme důkaz – ale nikdo nechce slyšet tu zprávu.',
    ['Zveřejnit snímky', { pri: 10, lid: -5, sil: -5 }], ['Sdílet se světem', { dip: 10, pri: 5, fin: -10 }], ['Počkat po volbách', { lid: 5, fin: 5, pri: -10 }], ['Družice pro armádu', { sil: 5, fin: 5, dip: -10 }], { req: ['b_vesmir'] }),

  // ── 6→7: od nuly po Velkém výpadku (bez doby = budoucnost) ──
  c('br_nula_1', null, 'nula', 'Po výpadku jsme začínali s papírem a tužkou. Teď lidé chtějí síť zpátky – ale tentokrát otevřenou a bez pánů.',
    ['Otevřená síť', { lid: 10, ved: 5, sil: -5 }], ['Síť pod státem', { sil: 5, fin: 5, lid: -10 }], ['Raději bez sítě', { pri: 10, ved: -10 }], ['Síť od Federace', { dip: 10, lid: 5, sil: -10 }], { req: ['b_nula'] }),
  c('br_nula_2', null, 'far', 'Když nejely kamiony, nakrmily nás vesnické zahrady. Lidi chtějí, aby každá obec zůstala soběstačná, {osl}.',
    ['Družstva v obcích', { lid: 5, pri: 5, fin: -5 }], ['Zpět ke kamionům', { fin: 10, pri: -10 }], ['Zásoby na rok', { lid: 5, fin: -5, dip: -5 }], ['Ať si poradí', { fin: 10, lid: -10 }], { req: ['b_nula'] }),
  // ── 6→7: Nová republika pevnou rukou ──────────────────
  c('br_republika_1', null, 'stin', 'Republiku jsme postavili pevnou rukou a pořádek drží. Jenže výjimečné zákony stále platí, {osl}. Zrušíme je?',
    ['Zrušit je', { lid: 10, sil: -5 }], ['Ponechat', { sil: 10, lid: -10, dip: -5 }], ['Zrušit jen polovinu', { lid: 5, sil: -5, fin: 5 }], ['Referendum', { lid: 5, fin: -5, dip: 5 }], { req: ['b_republika'] }),
  c('br_republika_2', null, 'gen', 'Armáda zachránila republiku a teď chce svůj díl: ministerstvo, rozpočet a místo v radě. Co jim dáš?',
    ['Místo v radě', { sil: 10, lid: -5, dip: -5 }], ['Vojáci do kasáren', { sil: -10, fin: 5, dip: 5 }], ['Jen vyšší rozpočet', { sil: 5, fin: -10 }], ['Vojáci staví domy', { lid: 10, sil: -5 }], { req: ['b_republika'] }),
];

/// Divy světa – jeden v každé době. Dokončený div navždy uklidní ukazatel `m`.
export const WONDERS = [
  { id: 'kruh', age: 1, name: 'Kamenný kruh', m: 'ved' },
  { id: 'pyramida', age: 2, name: 'Velká pyramida', m: 'vir' },
  { id: 'katedrala', age: 3, name: 'Katedrála', m: 'lid' },
  { id: 'zeleznice', age: 4, name: 'Železnice přes celou zemi', m: 'fin' },
  { id: 'prehrada', age: 5, name: 'Velká přehrada', m: 'pri' },
  { id: 'observator', age: 6, name: 'Vesmírný dalekohled', m: 'dip' },
  { id: 'vytah', age: 7, name: 'Vesmírný výtah', m: 'sil' },
];

// Zkratky pro stavbu divu: start (nastaví stavbu), dál (pokračuje), hotovo (div dokončen), konec (stavba zrušena).
const start = (id) => ({ set: `stavba_${id}`, next: `div_${id}_2`, in: 3 });
const dal = (id) => ({ next: `div_${id}_3`, in: 3 });
const hotovo = (id) => ({ wonder: id, unset: `stavba_${id}` });
const konec = (id) => ({ unset: `stavba_${id}` });
const w = (id, age, who, [t1, a1, b1, c1, d1], [t2, a2, b2, c2, d2], [t3, a3, b3, c3, d3]) => {
  const ag = age === 7 ? null : age;
  return [
    c(`div_${id}_1`, ag, who[0], t1, [...a1, start(id)], [...b1, start(id)], c1, d1, { not: [`div_${id}`, `stavba_${id}`], weight: 0.8 }),
    c(`div_${id}_2`, ag, who[1], t2, [...a2, dal(id)], [...b2, dal(id)], [...c2, konec(id)], [...d2, konec(id)], { weight: 0, req: [`stavba_${id}`] }),
    c(`div_${id}_3`, ag, who[2], t3, [...a3, hotovo(id)], [...b3, hotovo(id)], [...c3, konec(id)], [...d3, konec(id)], { weight: 0, req: [`stavba_${id}`] }),
  ];
};

export const WONDER_CARDS = [
  // ── Kamenný kruh (pravěk) ─────────────────────────────
  ...w('kruh', 1, ['star', 'lov', 'sam'], [
    'Stařešina chce postavit kruh z obrovských kamenů, podle kterého poznáme slunovrat. Táhnout je budeme mnoho let, {osl}.',
    ['Stavět kruh', { fin: -10, lid: -5, ved: 10 }], ['Malý kruh ze dřeva', { fin: -5, ved: 5 }],
    ['Nemáme sil', { lid: 5, fin: 5, ved: -5 }], ['Kameny jsou duchů', { vir: 5, fin: 5, ved: -10 }],
  ], [
    'Kámen se utrhl z lan a rozdrtil dva muže. Lovci odmítají táhnout dál, dokud jim nedáš víc masa.',
    ['Dát jim maso', { fin: -5, lid: 5 }], ['Ať táhnou i ženy', { lid: -10, ved: 5 }],
    ['Kameny nechat ležet', { lid: 10, ved: -10 }], ['Duchové nechtějí', { vir: 5, ved: -5, fin: 5 }],
  ], [
    'Poslední kámen stojí! Za úsvitu slunovratu prošel první paprsek přesně středem kruhu. Kmen ztichl úžasem.',
    ['Slavit u ohně', { lid: 10, fin: -5 }], ['Učit z něj mladé', { ved: 10, vir: -5 }],
    ['Kruh je špatně', { ved: -5, lid: -5 }], ['Rozbít ho na pazourky', { fin: 5, vir: -5 }],
  ]),

  // ── Velká pyramida (starověk) ─────────────────────────
  ...w('pyramida', 2, ['knez', 'pis', 'knez'], [
    'Velekněz chce hrob pro krále až do nebe. Pyramida bude stát tisíc let – ale stavět ji budou celé generace, {osl}.',
    ['Stavět pyramidu', { fin: -10, vir: 10, lid: -5 }], ['Stavět jen v zimě', { fin: -5, lid: -5, vir: 5 }],
    ['Raději sýpky', { fin: 5, vir: -5 }], ['Zbytečná pýcha', { lid: 5, fin: 5, vir: -5 }],
  ], [
    'Spočítal jsem náklady, {osl}. Pyramida už spolkla třetinu pokladu a dělníci stávkují, protože jim došel chléb a pivo.',
    ['Přidat chléb a pivo', { fin: -5, lid: 5 }], ['Vojáci je donutí', { sil: 5, lid: -10 }],
    ['Zastavit stavbu', { fin: 10, vir: -5 }], ['Postavit jen základ', { fin: 5, vir: -5, ved: -5 }],
  ], [
    'Zlatý vrchol pyramidy se zaleskl v poledním slunci. Lidé ji vidí z celé pouště a padají na kolena.',
    ['Slavnost pro lid', { lid: 10, fin: -10 }], ['Zasvětit ji bohům', { vir: 5, ved: 5, lid: -5 }],
    ['Vrchol se zřítil', { lid: -5, fin: -5 }], ['Prodat zlato z vrcholu', { fin: 10, vir: -10 }],
  ]),

  // ── Katedrála (středověk) ─────────────────────────────
  ...w('katedrala', 3, ['bisk', 'alch', 'bisk'], [
    'Biskup sní o katedrále s okny jako drahokamy. Stavět ji budou ještě vnuci dnešních kameníků, {osl}.',
    ['Položit základní kámen', { fin: -10, vir: 10, lid: -5 }], ['Ať přispějí cechy', { fin: -5, lid: 5, vir: 5, sil: -5 }],
    ['Stačí kostel', { fin: 5, vir: -5 }], ['Raději hradby', { fin: 5, sil: 5, vir: -5 }],
  ], [
    'Klenba se zřítila, {osl}! Stavitel tvrdí, že jen alchymie spočítá, jak má stát. Biskup ho chce upálit.',
    ['Nechat ho počítat', { ved: 10, vir: -5, fin: -5 }], ['Nový stavitel z Francie', { dip: 5, fin: -10 }],
    ['Nechat ji bez klenby', { fin: 10, vir: -5, lid: -5 }], ['Je to znamení', { vir: 5, fin: 5, ved: -10 }],
  ], [
    'Zvony katedrály se poprvé rozezněly nad městem. Barevné světlo z oken zalilo lid, který na ni platil celé věky.',
    ['Mše pro celou zem', { lid: 10, fin: -10 }], ['Otevřít ji poutníkům', { fin: 10, dip: 5, vir: -5 }],
    ['Věže praskají', { fin: -5, vir: -5 }], ['Dát ji klášteru', { vir: 5, lid: -10 }],
  ]),

  // ── Železnice (novověk) ───────────────────────────────
  ...w('zeleznice', 4, ['vyn', 'tov', 'kap'], [
    'Parní lokomotiva uveze víc než tisíc koní. Natáhněme koleje z jednoho konce země na druhý, {osl}!',
    ['Státní železnice', { fin: -10, ved: 10, pri: -5 }], ['Akciová společnost', { fin: -5, lid: -5, ved: 5 }],
    ['Koně stačí', { pri: 5, fin: 5, ved: -10 }], ['Nejdřív kanály', { fin: 10, pri: -5, ved: -5 }],
  ], [
    'Tunel pod horami se zavalil a dělníci stávkují. Akcionáři zpanikařili a chtějí své peníze zpátky, {osl}.',
    ['Přidat dělníkům', { lid: 5, fin: -10 }], ['Stávku rozehnat', { sil: 5, lid: -10 }],
    ['Trať končí tady', { fin: 5, ved: -5 }], ['Prodat ji cizincům', { fin: 10, dip: -5, ved: -10 }],
  ], [
    'První vlak projel celou zemí za jediný den! Na nádražích mávají davy a obchodníci už počítají zisky.',
    ['Jízdenky pro všechny', { lid: 10, fin: -5 }], ['Vozit zboží a uhlí', { fin: 10, pri: -5 }],
    ['Vlak vykolejil', { lid: -10, fin: -5, ved: 5 }], ['Koleje na děla', { sil: 5, fin: -5, ved: -5 }],
  ]),

  // ── Velká přehrada (moderní doba) ─────────────────────
  ...w('prehrada', 5, ['inz', 'novin', 'inz'], [
    'Přehrada na řece by zastavila povodně a dala proud půlce země. Pod vodu by ale šlo deset vesnic, {osl}.',
    ['Stavět přehradu', { fin: -10, ved: 5, lid: -5, pri: 5 }], ['Menší hráz', { fin: -5, pri: 5 }],
    ['Vesnice zůstanou', { lid: 5, fin: 5, ved: -5 }], ['Uhelná elektrárna', { fin: 10, pri: -10 }],
  ], [
    'Lidé z vesnic odmítají odejít a sedí na střechách. Kamery mají celý svět, {osl}. Rozpočet už se zdvojnásobil.',
    ['Odškodnit je štědře', { fin: -10, lid: 10 }], ['Vystěhovat policií', { sil: 5, lid: -10 }],
    ['Stavbu zrušit', { lid: 10, ved: -10 }], ['Přehradu prodat', { fin: 10, dip: -5, ved: -5 }],
  ], [
    'Hráz stojí a jezero se plní. Turbíny se roztočily a povodně jsou minulostí. Nad zatopenými vesnicemi se blýská hladina.',
    ['Pomník vesnicím', { lid: 5, pri: 5, fin: -5 }], ['Levný proud všem', { lid: 10, fin: -5, pri: 5 }],
    ['Hráz prosakuje', { pri: -5, lid: -5 }], ['Vypustit jezero', { pri: 10, lid: -5, ved: -5 }],
  ]),

  // ── Vesmírný dalekohled (současnost) ──────────────────
  ...w('observator', 6, ['klim', 'tech', 'tech'], [
    'Obří dalekohled na oběžné dráze by uviděl planety u cizích hvězd. Sám ho nezaplatíme – jen spolu se světem.',
    ['Vést mezinárodní tým', { fin: -10, dip: 10, lid: -5 }], ['Přispět skromně', { fin: -5, ved: 5 }],
    ['Peníze na klima', { pri: 5, ved: -5 }], ['Ať to platí jiní', { fin: 10, dip: -10 }],
  ], [
    'Zrcadlo dalekohledu prasklo při zkouškách. Partneři se hádají, kdo to zaplatí, a hrozí odchodem z projektu.',
    ['Zaplatíme to my', { fin: -10, dip: 10 }], ['Opravit mou firmou', { fin: -5, ved: 5, lid: -5 }],
    ['Odejít z projektu', { fin: 10, dip: -10 }], ['Přenechat to ostatním', { dip: 5, fin: 5, ved: -10 }],
  ], [
    'Dalekohled se rozložil ve vesmíru a poslal první snímek: modrou planetu u cizí hvězdy. Celý svět se dívá s tebou.',
    ['Snímek patří všem', { dip: 10, fin: -5 }], ['Pozvat ostatní do rady', { dip: 5, ved: 5, sil: -5 }],
    ['Dalekohled oslepl', { ved: -5, dip: -5 }], ['Prodat ho armádě', { sil: 5, fin: 5, dip: -10 }],
  ]),

  // ── Vesmírný výtah (budoucnost) ───────────────────────
  ...w('vytah', 7, ['ved', 'odb', 'ork'], [
    'Lano z uhlíkových vláken až na oběžnou dráhu – vesmírný výtah. Republika by vládla cestě ke hvězdám, {osl}.',
    ['Stavět výtah', { fin: -10, ved: 10 }], ['Stavět s Federací', { fin: -5, dip: 5, sil: -5 }],
    ['Raději domy', { lid: 5, ved: -5 }], ['Je to sci-fi', { ved: -10, fin: 10 }],
  ], [
    'Na kotvišti výtahu se dělníci bojí výšky a robotů. Žádají dvojí mzdu, jinak stavbu zastaví, {osl}.',
    ['Dát dvojí mzdu', { fin: -10, lid: 10 }], ['Stavět jen roboty', { ved: 5, lid: -10 }],
    ['Výtah zastavit', { fin: 5, ved: -5 }], ['Předat ho Federaci', { dip: 5, sil: -5 }],
  ], [
    'Kabina vyjela až na oběžnou dráhu. ORÁKL hlásí: spojení stabilní. Republika má vlastní cestu ke hvězdám.',
    ['Výtah pro vědu', { ved: 10, lid: 5 }], ['Výtah pod armádou', { sil: 10, lid: -5, dip: -5 }],
    ['Lano se přetrhlo', { fin: -5, lid: -5, ved: -5 }], ['ORÁKL to zarazil', { ved: -5, lid: 5, sil: -5 }],
  ]),
];
