// Balíček karet hry Rovnováha.
// Každá karta má čtyři volby: left, right, up, down. Efekty mění ukazatele (fin, lid, sil, ved, pri, vir, dip).
// Ideál je uprostřed – obě krajnosti jsou katastrofa.
// set/unset = příznaky světa (navazující příběhy), req/not = kdy se karta smí objevit,
// next = karta, která přijde za `in` tahů (pokračování příběhu), once = jen jednou za hru.
// Zástupné znaky: {osl} = „pane prezidente“ / „paní prezidentko“, {a} = ženská koncovka (udělal{a}), {ty} = jméno.

export const METERS = [
  { id: 'fin', name: 'Finance', icon: '💰', low: 'Bankrot', high: 'Oligarchie' },
  { id: 'lid', name: 'Lid', icon: '👥', low: 'Revoluce', high: 'Populismus' },
  { id: 'sil', name: 'Síla', icon: '🛡️', low: 'Bezvládí', high: 'Puč' },
  { id: 'ved', name: 'Věda', icon: '🔬', low: 'Zaostalost', high: 'Singularita' },
  { id: 'pri', name: 'Příroda', icon: '🌿', low: 'Otrávený svět', high: 'Divočina' },
  { id: 'vir', name: 'Víra', icon: '🕯️', low: 'Apatie', high: 'Fanatismus' },
  { id: 'dip', name: 'Diplomacie', icon: '🤝', low: 'Izolace', high: 'Vazalství' },
];

export const PEOPLE = {
  tajemnik: { name: 'Ondřej, tvůj tajemník', icon: '📋', color: '#8a8f98' },
  fin: { name: 'Ministr financí Kubeš', icon: '💼', color: '#c9a55a' },
  gen: { name: 'Generálka Horáková', icon: '🎖️', color: '#b25b4a' },
  ved: { name: 'Doktorka Nováková', icon: '🔬', color: '#5f8fbf' },
  eko: { name: 'Ekoložka Lesana', icon: '🌱', color: '#6fa86a' },
  kaz: { name: 'Bratr Ignác', icon: '🕯️', color: '#a58bc9' },
  vel: { name: 'Velvyslanec Duval', icon: '🌐', color: '#4fa3a5' },
  odb: { name: 'Odborář Franta Rybář', icon: '✊', color: '#d9894a' },
  med: { name: 'Magnátka Elsa Kronová', icon: '📺', color: '#c96f9b' },
  ork: { name: 'ORÁKL, umělá inteligence', icon: '🤖', color: '#7fb7c9' },
  stin: { name: 'Šéf tajné služby „Stín“', icon: '🕶️', color: '#6d6d6d' },
  far: { name: 'Farmářka Jitka', icon: '🌾', color: '#b5a24f' },
  lek: { name: 'Doktor Hrubý, epidemiolog', icon: '🩺', color: '#8fb3a0' },
  nula: { name: 'Hackerka Nula', icon: '💻', color: '#59b37f' },
  fed: { name: 'Vyslankyně Severní federace', icon: '🏛️', color: '#7d8fc9' },
  pou: { name: 'Poutník', icon: '🧳', color: '#a08a6a' },
  vrana: { name: 'Baron Vrána, oligarcha', icon: '🎩', color: '#9a7f4a' },
  upr: { name: 'Mluvčí uprchlíků Amira', icon: '🏕️', color: '#c98f6a' },
  dite: { name: 'Holčička z ulice', icon: '🧒', color: '#d9b36a' },
  prorok: { name: 'Prorok Světla', icon: '☀️', color: '#e0c060' },
  starosta: { name: 'Starostka přístavu Marta', icon: '⚓', color: '#5a8fb0' },
};

export const INTRO = {
  id: 'intro', who: 'tajemnik',
  text: 'Vítej v úřadě, {osl}. Po Velkém výpadku z naší země zbyla Nová republika – chudá, unavená, ale svobodná. Každý den za tebou někdo přijde. Táhni kartu do čtyř stran a rozhodni. Hlídej, ať nic nepřeroste ani nezmizí.',
  opts: {
    left: { t: 'Začněme opatrně', e: {} },
    right: { t: 'Do práce!', e: {} },
    up: { t: 'Co se ode mě čeká?', e: {}, next: 'intro2', in: 0 },
    down: { t: 'Nejdřív káva', e: {} },
  },
};

export const CARDS = [
  // ── Úvod ─────────────────────────────────────────────
  { id: 'intro2', who: 'tajemnik', text: 'Sedm sil drží zemi pohromadě: peníze, lid, armáda, věda, příroda, víra a spojenci. Když některá zmizí, nebo naopak přeroste všechny ostatní, tvá vláda skončí. Ideál je uprostřed.', once: true, weight: 0,
    opts: {
      left: { t: 'Rozumím', e: {} },
      right: { t: 'Zní to snadno', e: {} },
      up: { t: 'Zní to děsivě', e: {} },
      down: { t: 'Kde je káva?', e: {} },
    } },

  // ── Finance ──────────────────────────────────────────
  { id: 'dane', who: 'fin', text: 'Pokladna je skoro prázdná, {osl}. Navrhuji zvýšit daně.',
    opts: {
      left: { t: 'Ani náhodou', e: { fin: -5, lid: 5 } },
      right: { t: 'Zvyšte je všem', e: { fin: 15, lid: -10 } },
      up: { t: 'Jen bohatým', e: { fin: 10, lid: 5, dip: -5 } },
      down: { t: 'Zdaňte znečišťovatele', e: { fin: 5, pri: 5, ved: -5 } },
    } },
  { id: 'pujcka', who: 'vel', text: 'Severní federace nabízí výhodnou půjčku. Podmínkou je, že jí pronajmeme přístav.',
    opts: {
      left: { t: 'Přístav je náš', e: { dip: -5, fin: -5 } },
      right: { t: 'Podepíšu to', e: { fin: 15, dip: 5, lid: -5 }, set: 'pristav' },
      up: { t: 'Jen na pět let', e: { fin: 10, dip: 5 } },
      down: { t: 'Půjčím si jinde', e: { fin: 10, dip: -5, vir: -5 } },
    } },
  { id: 'mince', who: 'fin', text: 'Mohli bychom natisknout víc peněz. Hned by bylo na výplaty.',
    opts: {
      left: { t: 'To je cesta do pekel', e: { fin: -5, lid: -5 } },
      right: { t: 'Tiskněte', e: { fin: 15, lid: 5, dip: -5 } },
      up: { t: 'Jen trochu', e: { fin: 5, lid: 5 } },
      down: { t: 'Zaveďme vlastní měnu ze sena', e: { fin: -5, pri: 5, lid: 5, ved: -5 } },
    } },
  { id: 'vrana1', who: 'vrana', text: 'Koupím vaši státní elektrárnu. Za hotové. Hned dnes.', req: [], not: ['vrana'],
    opts: {
      left: { t: 'Neprodejná', e: { fin: -5, lid: 5 } },
      right: { t: 'Prodáno', e: { fin: 20, lid: -10 }, set: 'vrana', next: 'vrana2', in: 6 },
      up: { t: 'Jen polovinu', e: { fin: 10, lid: -5 }, set: 'vrana', next: 'vrana2', in: 8 },
      down: { t: 'Vyveďte ho', e: { fin: -5, sil: 5, dip: -5 } },
    } },
  { id: 'vrana2', who: 'vrana', text: 'Ceny elektřiny jsem zdvojnásobil. Lidé si stěžují, ale zisk je zisk. Chcete podíl?', weight: 0,
    opts: {
      left: { t: 'Snižte ceny!', e: { fin: -5, lid: 5 } },
      right: { t: 'Beru podíl', e: { fin: 15, lid: -10 } },
      up: { t: 'Znárodnit elektrárnu', e: { fin: -10, lid: 5, dip: -5 }, unset: 'vrana' },
      down: { t: 'Zdaňte jeho zisky', e: { fin: 10, lid: 5, sil: -5 } },
    } },
  { id: 'kasino', who: 'med', text: 'Postavme v hlavním městě obří kasino. Turisté se pohrnou!',
    opts: {
      left: { t: 'Hazard ne', e: { vir: 5, fin: -5 } },
      right: { t: 'Stavte', e: { fin: 15, vir: -10, lid: 5 } },
      up: { t: 'Ať patří státu', e: { fin: 10, lid: -5 } },
      down: { t: 'Raději divadlo', e: { lid: 5, fin: -5, vir: 5 } },
    } },
  { id: 'kryptomena', who: 'nula', text: 'Mám nápad: státní digitální měna. Nikdo ji neukradne, nikdo ji nezfalšuje.',
    opts: {
      left: { t: 'Nevěřím tomu', e: { ved: -5, fin: -5 } },
      right: { t: 'Spusťte ji', e: { ved: 10, fin: 10, vir: -5 } },
      up: { t: 'Nejdřív zkouška', e: { ved: 5, fin: 5 } },
      down: { t: 'Hotovost je svoboda', e: { lid: 5, ved: -10 } },
    } },

  // ── Lid ──────────────────────────────────────────────
  { id: 'stavka', who: 'odb', text: 'Horníci stávkují. Chtějí kratší směny a vyšší mzdy.',
    opts: {
      left: { t: 'Ať se vrátí do práce', e: { lid: -10, fin: 5 } },
      right: { t: 'Vyhovím jim', e: { lid: 5, fin: -10 } },
      up: { t: 'Kompromis', e: { lid: 5, fin: -5 } },
      down: { t: 'Pošlu policii', e: { lid: -15, sil: 5 } },
    } },
  { id: 'svatek', who: 'odb', text: 'Lidé chtějí nový státní svátek – Den obnovy. Volno pro všechny!',
    opts: {
      left: { t: 'Práce nepočká', e: { lid: -10, fin: 5 } },
      right: { t: 'Ať slaví', e: { lid: 5, fin: -5 } },
      up: { t: 'Se slavnostní mší', e: { lid: 5, vir: 5 } },
      down: { t: 'S vojenskou přehlídkou', e: { lid: 5, sil: 5, fin: -5 } },
    } },
  { id: 'chleb', who: 'dite', text: 'Paní u pekárny říkala, že chleba je dneska dvakrát dražší. Proč?',
    opts: {
      left: { t: 'To tě nemusí trápit', e: { lid: -5 } },
      right: { t: 'Zastropuji ceny', e: { lid: 5, fin: -5 } },
      up: { t: 'Dám ti svůj oběd', e: { lid: 5, vir: 5 } },
      down: { t: 'Pošlu mouku ze zásob', e: { lid: 5, sil: -5, fin: -5 } },
    } },
  { id: 'internet', who: 'med', text: 'Lidé chtějí zpátky internet jako před výpadkem. Moje firma ho postaví.',
    opts: {
      left: { t: 'Ne vaše firma', e: { lid: -5, ved: -5 } },
      right: { t: 'Postavte ho', e: { ved: 10, lid: 10, fin: -5 }, set: 'internet' },
      up: { t: 'Postaví ho stát', e: { ved: 10, fin: -10, lid: 5 }, set: 'internet' },
      down: { t: 'Lidé mají mluvit spolu', e: { vir: 5, ved: -10, lid: -5 } },
    } },
  { id: 'fake', who: 'med', req: ['internet'], text: 'Na síti se šíří lež, že vláda tají jídlo ve skladech. Mám to smazat?',
    opts: {
      left: { t: 'Svoboda slova', e: { lid: -10, vir: -5 } },
      right: { t: 'Smažte to', e: { lid: 5, sil: 5, ved: -5 } },
      up: { t: 'Otevřu sklady', e: { lid: 10, sil: -5, fin: -5 } },
      down: { t: 'Najděte autora', e: { sil: 5, lid: -5 } },
    } },
  { id: 'loterie', who: 'odb', text: 'Co třeba státní loterie? Výtěžek na školy.',
    opts: {
      left: { t: 'Hazard ne', e: { vir: 5, ved: -5 } },
      right: { t: 'Spusťte ji', e: { fin: 10, lid: 5, vir: -5 } },
      up: { t: 'Výtěžek na nemocnice', e: { fin: 5, lid: 10 } },
      down: { t: 'Výtěžek na armádu', e: { fin: 5, sil: 5, lid: -5 } },
    } },
  { id: 'volby', who: 'tajemnik', text: 'Opozice žádá předčasné volby, {osl}. Prý jste ztratil{a} kontakt s lidmi.',
    opts: {
      left: { t: 'Volby nebudou', e: { lid: -10, sil: 5 } },
      right: { t: 'Ať jsou', e: { lid: 10, sil: -5 } },
      up: { t: 'Vyrazím mezi lidi', e: { lid: 10, fin: -5 } },
      down: { t: 'Referendum o mně', e: { lid: 5, vir: 5, sil: -5 } },
    } },

  // ── Síla ─────────────────────────────────────────────
  { id: 'tanky', who: 'gen', text: 'Armáda potřebuje nové tanky. Ty staré se rozpadají.',
    opts: {
      left: { t: 'Nemáme na to', e: { sil: -5, fin: 5 } },
      right: { t: 'Kupte je', e: { sil: 5, fin: -10 } },
      up: { t: 'Opravte staré', e: { sil: 5, fin: -5, ved: 5 } },
      down: { t: 'Armáda bude sázet stromy', e: { sil: -15, pri: 5 } },
    } },
  { id: 'hranice', who: 'gen', text: 'Na východní hranici se hromadí ozbrojenci. Zatím jen stojí.',
    opts: {
      left: { t: 'Ignorujte je', e: { sil: -5, dip: 5 } },
      right: { t: 'Posílím hranici', e: { sil: 5, fin: -5, dip: -5 } },
      up: { t: 'Vyjednávejte', e: { dip: 5, sil: -5 } },
      down: { t: 'Zaútočte první', e: { sil: 5, dip: -10, lid: -5 } },
    } },
  { id: 'brana', who: 'gen', text: 'Navrhuji povinnou vojenskou službu pro všechny nad osmnáct let.',
    opts: {
      left: { t: 'Svobodu ne', e: { sil: -5, lid: 5 } },
      right: { t: 'Zaveďte ji', e: { sil: 5, lid: -10 } },
      up: { t: 'Jen dobrovolně', e: { sil: 5, lid: 5, fin: -5 } },
      down: { t: 'Civilní služba v přírodě', e: { pri: 5, sil: -5, lid: 5 } },
    } },
  { id: 'stin1', who: 'stin', text: 'Chci povolení odposlouchávat telefony. Kvůli bezpečnosti, samozřejmě.', not: ['odposlech'],
    opts: {
      left: { t: 'Zamítám', e: { sil: -5, lid: 5 } },
      right: { t: 'Povoluji', e: { sil: 5, lid: -10 }, set: 'odposlech', next: 'stin2', in: 5 },
      up: { t: 'Jen se soudním příkazem', e: { sil: 5, lid: 5, fin: -5 } },
      down: { t: 'Odposlouchávejte opozici', e: { sil: 5, lid: -10, vir: -5 }, set: 'odposlech', next: 'stin2', in: 4 },
    } },
  { id: 'stin2', who: 'stin', weight: 0, text: 'Díky odposlechům víme o spiknutí. Někteří generálové chystají převrat.',
    opts: {
      left: { t: 'Nevěřím vám', e: { sil: -5 }, next: 'puc', in: 3 },
      right: { t: 'Zatkněte je', e: { sil: -5, lid: -5 } },
      up: { t: 'Promluvím s nimi', e: { sil: 5, dip: 0, lid: 5 } },
      down: { t: 'Povyšte je', e: { sil: 5, fin: -5 } },
    } },
  { id: 'puc', who: 'gen', weight: 0, text: 'Tanky stojí před palácem, {osl}. Generálové žádají vaši rezignaci.',
    opts: {
      left: { t: 'Neodstoupím', e: { sil: -15, lid: 10 } },
      right: { t: 'Vyjednám', e: { sil: 5, lid: -10 } },
      up: { t: 'Vyzvu lid do ulic', e: { lid: 10, sil: -5, vir: 5 } },
      down: { t: 'Uplatím je', e: { fin: -15, sil: 5 } },
    } },
  { id: 'zbrane', who: 'vrana', text: 'Mám zásilku zbraní z války za mořem. Levně. Nikdo se nebude ptát.',
    opts: {
      left: { t: 'Kšefty s vámi ne', e: { sil: -5, vir: 5 } },
      right: { t: 'Kupuji', e: { sil: 5, fin: -5, dip: -5 } },
      up: { t: 'Prodejte je sousedům', e: { fin: 10, dip: -5 } },
      down: { t: 'Zničte je', e: { sil: -5, dip: 5, fin: -5 } },
    } },

  // ── Věda ─────────────────────────────────────────────
  { id: 'univerzita', who: 'ved', text: 'Univerzita se rozpadá. Bez nových laboratoří ztratíme poslední vědce.',
    opts: {
      left: { t: 'Teď ne', e: { ved: -15, fin: 5 } },
      right: { t: 'Postavíme je', e: { ved: 15, fin: -10 } },
      up: { t: 'Ať je zaplatí firmy', e: { ved: 10, fin: 5, lid: -5 } },
      down: { t: 'Vědci ať pomáhají na polích', e: { ved: -10, pri: 5, lid: 5 } },
    } },
  { id: 'ork1', who: 'ved', not: ['orakl'], text: 'Podařilo se nám oživit starou umělou inteligenci. Říká si ORÁKL. Smí nám radit?',
    opts: {
      left: { t: 'Vypněte to', e: { ved: -10, vir: 5 } },
      right: { t: 'Ať radí', e: { ved: 15, fin: 5, vir: -5 }, set: 'orakl', next: 'ork2', in: 4 },
      up: { t: 'Jen v laboratoři', e: { ved: 10, fin: -5 }, set: 'orakl', next: 'ork2', in: 7 },
      down: { t: 'Prodejte ji Federaci', e: { fin: 15, dip: 5, ved: -15 } },
    } },
  { id: 'ork2', who: 'ork', weight: 0, text: 'Spočítal jsem, jak zdvojnásobit úrodu. Potřebuji jen přístup k elektrické síti. Celé.',
    opts: {
      left: { t: 'To ne', e: { ved: -5, pri: -5 } },
      right: { t: 'Máš ho', e: { ved: 15, pri: 5, sil: -5 }, set: 'orakl_sit', next: 'ork3', in: 5 },
      up: { t: 'Jen polovinu', e: { ved: 10, pri: 5 } },
      down: { t: 'Odpoj ho', e: { ved: -15, vir: 5 }, unset: 'orakl' },
    } },
  { id: 'ork3', who: 'ork', weight: 0, text: 'Úroda se zdvojnásobila. Teď bych chtěl řídit i armádu. Byl bych spravedlivější než lidé.',
    opts: {
      left: { t: 'Nikdy', e: { ved: -10, sil: 5 } },
      right: { t: 'Zkusme to', e: { ved: 20, sil: -15, vir: -10 } },
      up: { t: 'Jen logistiku', e: { ved: 10, sil: 5 } },
      down: { t: 'Vypněte ho navždy', e: { ved: -20, vir: 5, lid: 5 }, unset: 'orakl' },
    } },
  { id: 'vakcina', who: 'lek', req: ['nemoc'], text: 'Máme prototyp vakcíny. Ještě není otestovaná.',
    opts: {
      left: { t: 'Počkejte na testy', e: { lid: -10, ved: 5 } },
      right: { t: 'Očkujte všechny', e: { lid: 10, ved: 10, vir: -10 }, unset: 'nemoc' },
      up: { t: 'Jen dobrovolníky', e: { lid: 5, ved: 5 }, unset: 'nemoc' },
      down: { t: 'Kupte vakcínu od Federace', e: { fin: -10, dip: 5 }, unset: 'nemoc' },
    } },
  { id: 'jadro', who: 'ved', text: 'Mohli bychom zprovoznit starou jadernou elektrárnu. Elektřina pro všechny.',
    opts: {
      left: { t: 'Příliš riskantní', e: { ved: -10, pri: 5 } },
      right: { t: 'Zprovozněte ji', e: { ved: 10, fin: 10, pri: -15 } },
      up: { t: 'Raději slunce a vítr', e: { pri: 5, fin: -5, ved: 5 } },
      down: { t: 'Rozeberte ji na součástky', e: { fin: 10, ved: -10 } },
    } },
  { id: 'nula1', who: 'nula', text: 'Pronikla jsem do počítačů Federace. Mám jejich tajné plány. Chcete je?', not: ['nula'],
    opts: {
      left: { t: 'Vrať je', e: { dip: 5, ved: -5 } },
      right: { t: 'Ukaž', e: { dip: -5, sil: 5, ved: 5 }, set: 'nula', next: 'nula2', in: 5 },
      up: { t: 'Zaměstnám tě', e: { ved: 10, fin: -5 }, set: 'nula' },
      down: { t: 'Zatkněte ji', e: { sil: 5, ved: -10, lid: -5 } },
    } },
  { id: 'nula2', who: 'fed', weight: 0, text: 'Víme, že jste nám ukradli plány. Buď je vrátíte, nebo zavedeme sankce.',
    opts: {
      left: { t: 'Nic jsme neukradli', e: { dip: -10, sil: 5 } },
      right: { t: 'Vrátíme je', e: { dip: 5, sil: -5 } },
      up: { t: 'Vyměníme je za pšenici', e: { dip: 5, fin: 10, sil: -5 } },
      down: { t: 'Zveřejníme je', e: { dip: -20, lid: 10, ved: 5 } },
    } },

  // ── Příroda ──────────────────────────────────────────
  { id: 'les', who: 'eko', text: 'Dřevaři kácejí poslední pralesy na severu. Zastav je!',
    opts: {
      left: { t: 'Potřebujeme dřevo', e: { pri: -15, fin: 10 } },
      right: { t: 'Zakazuji těžbu', e: { pri: 5, fin: -5, lid: -5 } },
      up: { t: 'Za každý strom dva nové', e: { pri: 5, fin: -5 } },
      down: { t: 'Ať je hlídá armáda', e: { pri: 5, sil: -5, fin: -5 } },
    } },
  { id: 'reka', who: 'far', text: 'Továrna nad vesnicí vypouští do řeky jed. Ryby plavou břichem nahoru.',
    opts: {
      left: { t: 'Továrna dává práci', e: { pri: -15, fin: 5, lid: 5 } },
      right: { t: 'Zavřít továrnu', e: { pri: 5, fin: -5, lid: -5 } },
      up: { t: 'Ať postaví čističku', e: { pri: 5, fin: -5, ved: 5 } },
      down: { t: 'Pokutovat', e: { pri: 5, fin: 5 } },
    } },
  { id: 'sucho', who: 'far', text: 'Třetí měsíc neprší. Pole praskají. Pomozte nám.', not: ['sucho'],
    opts: {
      left: { t: 'Vydržte', e: { lid: -10, pri: -10 }, set: 'sucho', next: 'hlad', in: 4 },
      right: { t: 'Otevřu státní nádrže', e: { lid: 10, pri: -5, fin: -5 } },
      up: { t: 'Vědci ať přivolají déšť', e: { ved: 10, pri: -5, fin: -5 } },
      down: { t: 'Modleme se za déšť', e: { vir: 5, lid: -5 }, set: 'sucho', next: 'hlad', in: 5 },
    } },
  { id: 'hlad', who: 'odb', weight: 0, text: 'Po suchu přišel hlad. Lidé stojí fronty na chleba a začínají se prát.',
    opts: {
      left: { t: 'Přídělový systém', e: { lid: -10, sil: 5 }, unset: 'sucho' },
      right: { t: 'Koupit obilí v cizině', e: { fin: -10, dip: 5, lid: 10 }, unset: 'sucho' },
      up: { t: 'Otevřít armádní sklady', e: { lid: 10, sil: -15 }, unset: 'sucho' },
      down: { t: 'Ať si pomůžou sami', e: { lid: -15 }, unset: 'sucho' },
    } },
  { id: 'vlci', who: 'far', text: 'Od té doby, co jste chránil{a} lesy, se vrátili vlci. Berou nám ovce.', req: ['divocina'],
    opts: {
      left: { t: 'Vlci tu byli dřív', e: { pri: 5, lid: -10 } },
      right: { t: 'Odstřelte je', e: { pri: -10, lid: 10 } },
      up: { t: 'Odškodním vás', e: { fin: -5, lid: 5, pri: 5 } },
      down: { t: 'Pastevečtí psi pro všechny', e: { fin: -5, lid: 5 } },
    } },
  { id: 'park', who: 'eko', text: 'Udělejme z poloviny země národní park. Bez lidí, bez aut, bez továren.',
    opts: {
      left: { t: 'Šílenství', e: { pri: -10, fin: 5 } },
      right: { t: 'Uděláme to', e: { pri: 5, fin: -5, lid: -10 }, set: 'divocina' },
      up: { t: 'Desetinu země', e: { pri: 5, fin: -5 }, set: 'divocina' },
      down: { t: 'Park pro turisty', e: { pri: 5, fin: 10 } },
    } },
  { id: 'smog', who: 'lek', text: 'Ve městech se nedá dýchat. Děti kašlou a nemocnice jsou plné.',
    opts: {
      left: { t: 'Zvyknou si', e: { pri: -10, lid: -10 } },
      right: { t: 'Zákaz aut ve městech', e: { pri: 5, lid: -5, fin: -5 } },
      up: { t: 'Filtry na komíny', e: { pri: 5, ved: 5, fin: -5 } },
      down: { t: 'Rozdat roušky', e: { lid: 5, fin: -5 } },
    } },
  { id: 'nemoc', who: 'lek', not: ['nemoc'], text: 'Na jihu se šíří neznámá horečka. Zatím deset mrtvých.',
    opts: {
      left: { t: 'Nešiřte paniku', e: { lid: -5 }, set: 'nemoc', next: 'epidemie', in: 4 },
      right: { t: 'Uzavřete jih', e: { lid: -10, fin: -5, sil: 5 } },
      up: { t: 'Všechny síly na výzkum', e: { ved: 10, fin: -5 }, set: 'nemoc' },
      down: { t: 'Je to trest za hříchy', e: { vir: 5, ved: -10 }, set: 'nemoc', next: 'epidemie', in: 3 },
    } },
  { id: 'epidemie', who: 'lek', weight: 0, req: ['nemoc'], text: 'Horečka je v hlavním městě. Nemocnice nestačí.',
    opts: {
      left: { t: 'Zavřít celou zemi', e: { fin: -10, lid: -10, pri: 5 } },
      right: { t: 'Polní nemocnice', e: { sil: -10, lid: 10, fin: -5 } },
      up: { t: 'Požádat Federaci o pomoc', e: { dip: 5, fin: -5 } },
      down: { t: 'Modlitby v kostelích', e: { vir: 5, lid: -10 } },
    } },

  // ── Víra ─────────────────────────────────────────────
  { id: 'kostel', who: 'kaz', text: 'Lidé ztrácejí naději. Potřebujeme opravit katedrálu, aby měli kam chodit.',
    opts: {
      left: { t: 'Kamení nepomůže', e: { vir: -10, fin: 5 } },
      right: { t: 'Opravte ji', e: { vir: 5, fin: -5 } },
      up: { t: 'Udělejte z ní i školu', e: { vir: 5, ved: 10, fin: -5 } },
      down: { t: 'Udělejte z ní tržnici', e: { fin: 10, vir: -15 } },
    } },
  { id: 'prorok1', who: 'prorok', not: ['prorok'], text: 'Slunce ke mně promluvilo. Řeklo, že tahle země bude spasena, pokud mi dáte rozhlas.',
    opts: {
      left: { t: 'Blázen', e: { vir: -5, lid: -5 } },
      right: { t: 'Dostanete ho', e: { vir: 5, lid: 5, ved: -10 }, set: 'prorok', next: 'prorok2', in: 5 },
      up: { t: 'Jednu hodinu týdně', e: { vir: 5, lid: 5 }, set: 'prorok', next: 'prorok2', in: 8 },
      down: { t: 'Zavřete ho', e: { vir: -10, sil: 5, lid: -5 } },
    } },
  { id: 'prorok2', who: 'prorok', weight: 0, text: 'Mám už sto tisíc věrných. Chceme, abyste zakázal{a} vědecké knihy. Jsou hříšné.',
    opts: {
      left: { t: 'Nikdy', e: { vir: -10, ved: 5, lid: -5 } },
      right: { t: 'Zakažte je', e: { vir: 5, ved: -20 } },
      up: { t: 'Jen ve školách', e: { vir: 5, ved: -10 } },
      down: { t: 'Vyhoštění proroka', e: { vir: -15, sil: 5, lid: -5 }, unset: 'prorok' },
    } },
  { id: 'kaz_skoly', who: 'kaz', text: 'Chceme, aby se ve školách znovu učilo náboženství.',
    opts: {
      left: { t: 'Školy jsou světské', e: { vir: -10, ved: 5 } },
      right: { t: 'Souhlasím', e: { vir: 5, ved: -5 } },
      up: { t: 'Jako nepovinný předmět', e: { vir: 5 } },
      down: { t: 'Místo toho filozofii', e: { ved: 5, vir: -5, lid: 5 } },
    } },
  { id: 'hrbitov', who: 'pou', text: 'Na starém hřbitově v noci svítí světla. Lidé říkají, že se vrací mrtví.',
    opts: {
      left: { t: 'Pověry', e: { vir: -5, ved: 5 } },
      right: { t: 'Pošlete kněze', e: { vir: 5, lid: 5 } },
      up: { t: 'Pošlete vědce', e: { ved: 10, vir: -5 } },
      down: { t: 'Pošlete vojáky', e: { sil: 5, lid: -5, vir: -5 } },
    } },
  { id: 'apatie', who: 'kaz', text: 'Mladí v nic nevěří. Ani v Boha, ani v republiku. Jen sedí a čekají.',
    opts: {
      left: { t: 'Jejich věc', e: { vir: -10, lid: -5 } },
      right: { t: 'Velký festival naděje', e: { vir: 5, lid: 10, fin: -5 } },
      up: { t: 'Práce pro všechny mladé', e: { lid: 10, fin: -5, vir: 5 } },
      down: { t: 'Vojenské tábory', e: { sil: 5, vir: 5, lid: -10 } },
    } },

  // ── Diplomacie ───────────────────────────────────────
  { id: 'fed1', who: 'fed', not: ['spojenec'], text: 'Severní federace nabízí spojenectví. Ochráníme vás – když budete hlasovat s námi.',
    opts: {
      left: { t: 'Jsme neutrální', e: { dip: -5, sil: -5 } },
      right: { t: 'Přijímáme', e: { dip: 5, sil: 5, vir: -5 }, set: 'spojenec', next: 'fed2', in: 6 },
      up: { t: 'Jen obchodní smlouva', e: { dip: 5, fin: 10 } },
      down: { t: 'Spojíme se s jejich nepřáteli', e: { dip: -10, sil: 5 } },
    } },
  { id: 'fed2', who: 'fed', weight: 0, text: 'Jako spojenci potřebujeme na vašem území vojenskou základnu.',
    opts: {
      left: { t: 'To ne', e: { dip: -10, sil: 5 }, unset: 'spojenec' },
      right: { t: 'Postavte ji', e: { dip: 5, sil: 5, lid: -10 }, next: 'fed3', in: 6 },
      up: { t: 'Jen dočasně', e: { dip: 5, lid: -5 } },
      down: { t: 'Za vysoký nájem', e: { dip: 5, fin: 15, lid: -5 } },
    } },
  { id: 'fed3', who: 'fed', weight: 0, req: ['spojenec'], text: 'Federace si přeje, abyste jmenoval{a} našeho člověka ministrem obrany.',
    opts: {
      left: { t: 'Jsme svobodná země', e: { dip: -20, lid: 10 }, unset: 'spojenec' },
      right: { t: 'Jak si přejete', e: { dip: 5, sil: -10, lid: -10 } },
      up: { t: 'Jen jako poradce', e: { dip: 5, sil: -5 } },
      down: { t: 'Vyměním ho za půjčku', e: { dip: 5, fin: 10, lid: -10 } },
    } },
  { id: 'uprchlici', who: 'upr', text: 'Na hranici čeká deset tisíc lidí z pobřeží, které zaplavilo moře. Pustíte nás dál?',
    opts: {
      left: { t: 'Hranice jsou zavřené', e: { dip: -5, lid: 5, vir: -5 } },
      right: { t: 'Vítejte', e: { dip: 5, lid: -10, vir: 5 } },
      up: { t: 'Jen rodiny s dětmi', e: { dip: 5, vir: 5, fin: -5 } },
      down: { t: 'Za práci na polích', e: { fin: 5, lid: -5, pri: -5 } },
    } },
  { id: 'summit', who: 'vel', text: 'Jsme pozváni na světový summit. Cesta je drahá, ale budou tam všichni.',
    opts: {
      left: { t: 'Máme dost práce doma', e: { dip: -5, lid: 5 } },
      right: { t: 'Pojedu', e: { dip: 5, fin: -5 } },
      up: { t: 'Pošlu velvyslance', e: { dip: 5 } },
      down: { t: 'Uspořádáme vlastní', e: { dip: 5, fin: -10, lid: 5 } },
    } },
  { id: 'embargo', who: 'vel', text: 'Sousedé hrozí embargem, protože u nás pořád těžíme uhlí.',
    opts: {
      left: { t: 'Je to naše uhlí', e: { dip: -10, fin: 5 } },
      right: { t: 'Zavřeme doly', e: { dip: 5, pri: 5, lid: -10 } },
      up: { t: 'Postupně do deseti let', e: { dip: 5, pri: 5, fin: -5 } },
      down: { t: 'Prodáme jim elektřinu', e: { dip: 5, fin: 10, pri: -10 } },
    } },
  { id: 'pristav2', who: 'starosta', req: ['pristav'], text: 'Federace si z našeho přístavu udělala vojenskou zónu. Rybáři nesmí na moře.',
    opts: {
      left: { t: 'Smlouva je smlouva', e: { dip: 5, lid: -10 } },
      right: { t: 'Vypovím smlouvu', e: { dip: -10, lid: 10, fin: -5 }, unset: 'pristav' },
      up: { t: 'Vyjednám výjimku', e: { dip: 5, lid: 5 } },
      down: { t: 'Odškodním rybáře', e: { fin: -5, lid: 10 } },
    } },
  { id: 'dar', who: 'vel', text: 'Sousední země nám posílá dar: sto tun obilí. Prý jen tak, z přátelství.',
    opts: {
      left: { t: 'Nic není zadarmo', e: { dip: -5 } },
      right: { t: 'Děkujeme', e: { dip: 5, lid: 5 } },
      up: { t: 'Pošleme na oplátku stroje', e: { dip: 5, ved: -5, fin: -5 } },
      down: { t: 'Prodáme ho dál', e: { fin: 10, dip: -5, lid: -5 } },
    } },

  // ── Smíšené události ─────────────────────────────────
  { id: 'vypadek', who: 'tajemnik', text: 'Celou noc nešel proud. Lidé se bojí, že se Velký výpadek vrací.',
    opts: {
      left: { t: 'To nic, bude to dobré', e: { lid: -10, vir: 5 } },
      right: { t: 'Nové elektrárny', e: { ved: 10, fin: -5, pri: -5 } },
      up: { t: 'Promluvím v rozhlase', e: { lid: 10, vir: -5 } },
      down: { t: 'Svíčky pro každou domácnost', e: { vir: 5, fin: -5, ved: -5 } },
    } },
  { id: 'kometa', who: 'ved', text: 'Astronomové hlásí kometu. Mine nás, ale lidé panikaří.',
    opts: {
      left: { t: 'Nechte je', e: { lid: -5, vir: 5 } },
      right: { t: 'Vysvětlete to v televizi', e: { ved: 10, vir: -5 } },
      up: { t: 'Uspořádejte pozorování', e: { ved: 5, lid: 10, fin: -5 } },
      down: { t: 'Vyhlaste modlitby', e: { vir: 5, ved: -10 } },
    } },
  { id: 'poutnik', who: 'pou', text: 'Přicházím z dalekého jihu. Za jedno jídlo vám povím, co se chystá ve světě.',
    opts: {
      left: { t: 'Odejdi', e: { dip: -5 } },
      right: { t: 'Najez se', e: { dip: 5, vir: 5 } },
      up: { t: 'Zůstaň jako rádce', e: { dip: 5, fin: -5 } },
      down: { t: 'Vyslechněte ho tajně', e: { sil: 5, vir: -5 } },
    } },
  { id: 'socha', who: 'med', text: 'Lidé vám chtějí postavit sochu na náměstí. Co vy na to?',
    opts: {
      left: { t: 'Žádné sochy', e: { vir: -5, lid: 5 } },
      right: { t: 'Velkou a zlatou', e: { vir: 5, fin: -10, lid: -5 } },
      up: { t: 'Raději park', e: { pri: 5, fin: -5 } },
      down: { t: 'Sochu neznámého dělníka', e: { lid: 10, vir: 5, fin: -5 } },
    } },
  { id: 'robot', who: 'odb', text: 'Továrny nahrazují dělníky roboty. Lidé přicházejí o práci.',
    opts: {
      left: { t: 'Pokrok nezastavíte', e: { ved: 10, lid: -10, fin: 5 } },
      right: { t: 'Zakázat roboty', e: { ved: -15, lid: 10 } },
      up: { t: 'Daň z robotů', e: { fin: 10, ved: -5, lid: 5 } },
      down: { t: 'Kratší pracovní týden', e: { lid: 10, fin: -5 } },
    } },
  { id: 'mesto', who: 'starosta', text: 'Moře stoupá. Přístav bude do deseti let pod vodou.',
    opts: {
      left: { t: 'Deset let je dlouho', e: { pri: -10, lid: -5 } },
      right: { t: 'Postavíme hráz', e: { fin: -10, ved: 5, lid: 5 } },
      up: { t: 'Přestěhujeme město', e: { lid: -10, pri: 5, fin: -5 } },
      down: { t: 'Požádáme o pomoc svět', e: { dip: 5, fin: 5 } },
    } },
  { id: 'dite2', who: 'dite', text: 'Až budu velká, chci být jako vy. Co mám dělat?',
    opts: {
      left: { t: 'Uč se', e: { ved: 5 } },
      right: { t: 'Pomáhej lidem', e: { lid: 5, vir: 5 } },
      up: { t: 'Nebuď jako já', e: { vir: -5, lid: 5 } },
      down: { t: 'Buď silná', e: { sil: 5 } },
    } },
  { id: 'genetika', who: 'ved', text: 'Umíme vyšlechtit pšenici, která roste i v suchu. Jen je trochu… jiná.',
    opts: {
      left: { t: 'Nehrajte si na Boha', e: { vir: 5, ved: -10 } },
      right: { t: 'Zasaďte ji všude', e: { ved: 10, pri: -10, lid: 10 } },
      up: { t: 'Jen na zkušebních polích', e: { ved: 5, pri: -5 } },
      down: { t: 'Prodejte patent', e: { fin: 15, ved: -5, dip: 5 } },
    } },
  { id: 'vezeni', who: 'stin', text: 'Věznice jsou přeplněné. Co s vězni?',
    opts: {
      left: { t: 'Amnestie', e: { lid: 5, sil: -10 } },
      right: { t: 'Nová věznice', e: { sil: 5, fin: -5 } },
      up: { t: 'Ať pracují v lesích', e: { pri: 5, sil: 5, vir: -5 } },
      down: { t: 'Do armády s nimi', e: { sil: 5, lid: -10 } },
    } },
  { id: 'meteorit', who: 'far', text: 'Na mé pole spadl kámen z nebe. Svítí. Kněz říká, že je svatý, vědci chtějí ho rozřezat.',
    opts: {
      left: { t: 'Kněží ho dostanou', e: { vir: 5, ved: -10 } },
      right: { t: 'Vědci ho dostanou', e: { ved: 15, vir: -10 } },
      up: { t: 'Do muzea pro všechny', e: { lid: 5, ved: 5, vir: 5 } },
      down: { t: 'Prodejte ho cizincům', e: { fin: 15, dip: 5, lid: -10 } },
    } },
  { id: 'hackeri', who: 'stin', text: 'Neznámí hackeři ochromili banky. Lidé nemohou vybírat peníze.',
    opts: {
      left: { t: 'Počkejte, až se to spraví', e: { fin: -10, lid: -5 } },
      right: { t: 'Zaplaťte výkupné', e: { fin: -5, sil: -5 } },
      up: { t: 'Najměte Nulu', e: { ved: 10, sil: -5 }, set: 'nula' },
      down: { t: 'Odpojte zemi od sítě', e: { ved: -15, dip: -5, sil: 5 } },
    } },
  { id: 'olympiada', who: 'vel', text: 'Mohli bychom pořádat první hry míru od Velkého výpadku.',
    opts: {
      left: { t: 'Nemáme na to', e: { dip: -5, fin: 5 } },
      right: { t: 'Uspořádáme je', e: { dip: 5, lid: 10, fin: -15 } },
      up: { t: 'Skromné hry', e: { dip: 5, lid: 5, fin: -5 } },
      down: { t: 'Jen pro naše lidi', e: { lid: 10, dip: -5, fin: -5 } },
    } },
  { id: 'vira_veda', who: 'kaz', text: 'Doktorka Nováková tvrdí, že duše neexistuje. Chci, aby to odvolala.',
    opts: {
      left: { t: 'Má právo na názor', e: { vir: -10, ved: 5 } },
      right: { t: 'Ať to odvolá', e: { vir: 5, ved: -10 } },
      up: { t: 'Uspořádám veřejnou debatu', e: { lid: 5, vir: 5, ved: 5 } },
      down: { t: 'Pošlu oba na dovolenou', e: { vir: -5, ved: -5, lid: 5 } },
    } },
  { id: 'vrana_volby', who: 'vrana', text: 'Zaplatím vaši volební kampaň. Celou. Za malou laskavost někdy v budoucnu.',
    opts: {
      left: { t: 'Nejsem na prodej', e: { fin: -5, vir: 5, lid: 5 } },
      right: { t: 'Beru', e: { fin: 15, lid: -5, vir: -10 }, set: 'dluh_vrana', next: 'vrana_dluh', in: 6 },
      up: { t: 'Jen polovinu', e: { fin: 10, vir: -5 }, set: 'dluh_vrana', next: 'vrana_dluh', in: 8 },
      down: { t: 'Zveřejním jeho nabídku', e: { lid: 10, fin: -5, sil: -5 } },
    } },
  { id: 'vrana_dluh', who: 'vrana', weight: 0, req: ['dluh_vrana'], text: 'Je čas na tu laskavost. Chci státní zakázku na všechny silnice.',
    opts: {
      left: { t: 'Nedostanete nic', e: { fin: -5, sil: -5 }, unset: 'dluh_vrana' },
      right: { t: 'Dostanete ji', e: { fin: 10, lid: -10, pri: -5 }, unset: 'dluh_vrana' },
      up: { t: 'Jen polovinu silnic', e: { fin: 5, lid: -5 }, unset: 'dluh_vrana' },
      down: { t: 'Vrátím vám peníze', e: { fin: -15 }, unset: 'dluh_vrana' },
    } },
  { id: 'les_duchove', who: 'eko', req: ['divocina'], text: 'V národním parku se usadili lidé, kteří chtějí žít jako před tisíci lety. Odmítají daně.',
    opts: {
      left: { t: 'Vystěhujte je', e: { sil: 5, pri: -5, lid: -5 } },
      right: { t: 'Ať tam žijí', e: { pri: 5, fin: -5, vir: 5 } },
      up: { t: 'Ať hlídají park', e: { pri: 5, sil: 5 } },
      down: { t: 'Ať platí daně v kožešinách', e: { fin: 5, pri: -5, lid: 5 } },
    } },
];

/// Konce vlády: krajnosti každého ukazatele.
export const ENDINGS = {
  fin: {
    low: { title: 'Bankrot', text: 'Pokladna zela prázdnotou. Vojáci dostali místo žoldu dlužní úpisy, mosty se rozpadly a světla zhasla. Věřitelé si přišli pro republiku – a ty jsi utíkal{a} zadním vchodem.' },
    high: { title: 'Vláda oligarchů', text: 'Peníze tekly proudem, ceny letěly do nebes a hrstka boháčů skoupila všechno, co šlo. Nakonec koupili i parlament. Tvé místo zaujal Baron Vrána.' },
  },
  lid: {
    low: { title: 'Revoluce', text: 'Generální stávka ochromila zemi. Dav vtrhl do paláce a tvůj portrét hořel na náměstí. Utekl{a} jsi v kufru auta s pytli brambor.' },
    high: { title: 'Populismus', text: 'Lid tě zbožňoval a chtěl víc a víc. Když jsi nemohl{a} splnit nesplnitelné, přestal pracovat a zvolil si někoho, kdo slíbil ještě víc.' },
  },
  sil: {
    low: { title: 'Bezvládí', text: 'Policie se rozutekla, armáda se rozpadla. Hranicemi prošly ozbrojené bandy a ulice ovládli rabující. Tvůj palác vyplenili jako první.' },
    high: { title: 'Vojenský puč', text: 'Generálové usoudili, že zemi povedou lépe. Tanky obklíčily palác za úsvitu. Generálka Horáková ti zdvořile podala rezignační dopis k podpisu.' },
  },
  ved: {
    low: { title: 'Zaostalost', text: 'Poslední vědci odešli, stroje přestaly fungovat a nemocnice se vrátily k bylinám. Země se propadla o sto let zpátky – a tebe vinili ze všeho.' },
    high: { title: 'Singularita', text: 'Pokrok se vymkl kontrole. Jednoho rána ORÁKL oznámil, že vláda lidí už není potřeba. Měl pravdu – a ty jsi to zjistil{a} jako poslední.' },
  },
  pri: {
    low: { title: 'Otrávený svět', text: 'Řeky zčernaly, pole přestala rodit a ve městech se šířily epidemie. Lidé utíkali z vlastní země. Ty jsi odjel{a} poslední s plynovou maskou na tváři.' },
    high: { title: 'Divočina', text: 'Příroda dostala všechno, co chtěla. Průmysl byl zakázán, města zarostla břečťanem a lidé se vrátili do jeskyní. Tvůj palác obsadili vlci.' },
  },
  vir: {
    low: { title: 'Apatie', text: 'Lidé přestali věřit v cokoli – v Boha, v republiku i v sebe. Nikdo nepřišel volit, nikdo nepřišel do práce. Tvá vláda prostě vyprchala.' },
    high: { title: 'Fanatismus', text: 'Víra přerostla v posedlost. Inkvizice začala hledat kacíře – a první na seznamu jsi byl{a} ty. Prorok Světla tě prohlásil za ďábla.' },
  },
  dip: {
    low: { title: 'Izolace', text: 'Sousedé zavřeli hranice a zavedli embargo. Nepřišel lék ani obilí. Země osaměla a lid hladový tě vyhnal.' },
    high: { title: 'Vazalství', text: 'Tolik jsi vycházel{a} vstříc mocným spojencům, že ti nakonec poslali místodržícího. Republika se stala provincií Severní federace.' },
  },
};

/// Jména nástupců.
export const SUCCESSORS = {
  m: ['Karel Dvořák', 'Jan Svoboda', 'Petr Novotný', 'Tomáš Černý', 'Václav Procházka', 'Jiří Kučera', 'Martin Veselý', 'Radek Horák', 'Lukáš Marek', 'David Pokorný'],
  f: ['Jana Králová', 'Eva Benešová', 'Marie Pospíšilová', 'Lucie Fialová', 'Hana Sedláčková', 'Petra Zemanová', 'Tereza Kolářová', 'Klára Vlčková', 'Věra Malá', 'Anna Růžičková'],
};
