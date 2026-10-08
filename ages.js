// Dějiny lidstva: hra začíná v pravěku a přes starověk, středověk, novověk, moderní dobu a současnost
// dojde až do budoucnosti (Nová republika roku 2089 – zbytek balíčku).
// Každá doba má vlastní postavy, karty, oslovení, konce a přelomovou kartu (objev), která posune svět dál.
// Karta s `age: n` se objeví jen v době n. Přelom: volby s `advance: true` posunou svět do další doby,
// ostatní přelom odloží (karta se vrátí později).

/// Kolik rozhodnutí v jedné době, než přijde přelomový objev.
export const AGE_LEN = 25;

export const AGES = [
  { n: 1, name: 'Pravěk', when: 'asi 10 000 let před naším letopočtem', title: ['náčelník', 'náčelnice'], osl: ['náčelníku', 'náčelnice'],
    text: 'Malý kmen lovců a sběračů u velké řeky. Žádná města, žádné písmo – jen oheň, zvěř a hvězdy.' },
  { n: 2, name: 'Starověk', when: 'asi 2 000 let před naším letopočtem', title: ['král', 'královna'], osl: ['Veličenstvo', 'Veličenstvo'],
    text: 'Z vesnic vyrostla města a z kmene říše. Kněží, písaři a vojevůdci – a chrámy až do nebe.' },
  { n: 3, name: 'Středověk', when: 'asi rok 1200', title: ['kníže', 'kněžna'], osl: ['Vaše Jasnosti', 'Vaše Jasnosti'],
    text: 'Hrady, kláštery a rytíři. Mor, katedrály a kupci z daleké ciziny.' },
  { n: 4, name: 'Novověk', when: 'asi rok 1750', title: ['panovník', 'panovnice'], osl: ['Vaše Výsosti', 'Vaše Výsosti'],
    text: 'Lodě objevují nové kontinenty, parní stroje mění svět a lidé začínají mluvit o svých právech.' },
  { n: 5, name: 'Moderní doba', when: 'asi rok 1930', title: ['prezident', 'prezidentka'], osl: ['pane prezidente', 'paní prezidentko'],
    text: 'Rádio, auta, atom a rakety. Republika a volby – i hrozba velkých válek.' },
  { n: 6, name: 'Současnost', when: 'asi rok 2025', title: ['prezident', 'prezidentka'], osl: ['pane prezidente', 'paní prezidentko'],
    text: 'Chytré telefony, sociální sítě, oteplování planety a první umělé inteligence.' },
  { n: 7, name: 'Budoucnost', when: 'rok 2089', title: ['prezident', 'prezidentka'], osl: ['pane prezidente', 'paní prezidentko'],
    text: 'Po Velkém výpadku zbyla Nová republika – chudá, unavená, ale svobodná. Roboti, umělá inteligence ORÁKL a cesta ke hvězdám.' },
];

/// Postavy jednotlivých dob (vzhled používá stejné kreslené podobizny jako zbytek hry).
export const AGE_PEOPLE = {
  // pravěk
  star: { name: 'Stařešina Bór', icon: '🪶', color: '#9a8466', look: 'bald' },
  sam: { name: 'Šaman Oko', icon: '🦴', color: '#8f6aa8', look: 'hood' },
  lov: { name: 'Lovkyně Tura', icon: '🏹', color: '#a8643f', look: 'long' },
  sber: { name: 'Sběračka Lísa', icon: '🌾', color: '#8fa457', look: 'bun' },
  ciz: { name: 'Cizinec z hor', icon: '⛰️', color: '#6f8a9a', look: 'scarf' },
  // starověk
  knez: { name: 'Velekněz Amon', icon: '🏺', color: '#c9a24f', look: 'halo' },
  voj: { name: 'Vojevůdce Marek', icon: '🗡️', color: '#a85a48', look: 'cap' },
  pis: { name: 'Písař Tet', icon: '📜', color: '#b59a6a', look: 'glasses' },
  kup: { name: 'Kupkyně Dido', icon: '⛵', color: '#4f8fa8', look: 'long' },
  filo: { name: 'Filozof Ariston', icon: '🏛️', color: '#9fa0a8', look: 'bald' },
  // středověk
  bisk: { name: 'Biskup Vojtěch', icon: '⛪', color: '#8c6aa0', look: 'hood' },
  ryt: { name: 'Rytíř Zikmund', icon: '🛡️', color: '#7a7f8c', look: 'cap' },
  alch: { name: 'Alchymista Kelley', icon: '⚗️', color: '#6aa08c', look: 'tophat' },
  sedl: { name: 'Sedlák Matěj', icon: '🌾', color: '#a8905a', look: 'straw' },
  // novověk
  vyn: { name: 'Vynálezkyně Ada', icon: '⚙️', color: '#5f8fbf', look: 'glasses' },
  tov: { name: 'Továrník Kraus', icon: '🏭', color: '#8a7a6a', look: 'tophat' },
  kap: { name: 'Kapitán Hora', icon: '🧭', color: '#4f7fa0', look: 'beanie' },
  rev: { name: 'Revolucionářka Marie', icon: '🚩', color: '#c0574a', look: 'scarf' },
  hrabe: { name: 'Hrabě Vrbenský, dvorní rádce', icon: '🎩', color: '#9a7fa8', look: 'hair' },
  // moderní doba
  novin: { name: 'Novinářka Milena', icon: '📰', color: '#b0806a', look: 'bun' },
  genl: { name: 'Generál Ludvík', icon: '🎖️', color: '#6a7a5a', look: 'cap' },
  inz: { name: 'Inženýr Kolben', icon: '🔧', color: '#5a8fa0', look: 'glasses' },
  dipl: { name: 'Ministr zahraničí Jan', icon: '🌐', color: '#4fa3a5', look: 'hair' },
  // současnost
  infl: { name: 'Influencerka Kiki', icon: '📱', color: '#d07aa8', look: 'long' },
  klim: { name: 'Klimatoložka Eva', icon: '🌡️', color: '#6fa86a', look: 'bun' },
  tech: { name: 'Technologický miliardář Max', icon: '💻', color: '#59b37f', look: 'hoodie' },
};

/// Na čem kterému člověku záleží (pro vztahy).
export const AGE_CARES = {
  star: 'lid', sam: 'vir', lov: 'sil', sber: 'pri', ciz: 'dip',
  knez: 'vir', voj: 'sil', pis: 'ved', kup: 'fin', filo: 'ved',
  bisk: 'vir', ryt: 'sil', alch: 'ved', sedl: 'lid',
  vyn: 'ved', tov: 'fin', kap: 'dip', rev: 'lid', hrabe: 'dip',
  novin: 'lid', genl: 'sil', inz: 'ved', dipl: 'dip',
  infl: 'lid', klim: 'pri', tech: 'fin',
};

/// Jména nástupců podle doby (budoucnost používá jména z hlavní hry).
export const AGE_NAMES = {
  1: { m: ['Brok', 'Ugo', 'Taran', 'Hrom', 'Kel', 'Dub'], f: ['Ara', 'Ena', 'Lusa', 'Iva', 'Kora', 'Vlna'] },
  2: { m: ['Krok', 'Přemysl', 'Kazimír', 'Bořek', 'Ramon', 'Leon'], f: ['Libuše', 'Kazi', 'Teta', 'Nefera', 'Dida', 'Ilona'] },
  3: { m: ['Václav', 'Boleslav', 'Vratislav', 'Otakar', 'Jiří', 'Soběslav'], f: ['Ludmila', 'Anežka', 'Eliška', 'Dobrava', 'Kunhuta', 'Blanka'] },
  4: { m: ['Rudolf', 'Josef', 'Leopold', 'Ferdinand', 'Karel', 'František'], f: ['Marie', 'Karolína', 'Alžběta', 'Johana', 'Žofie', 'Terezie'] },
  5: { m: ['Tomáš Novák', 'Edvard Malý', 'Jan Kříž', 'Ludvík Hora', 'Karel Bílý', 'Emil Vrba'], f: ['Milada Horká', 'Olga Králová', 'Božena Ryšavá', 'Věra Čáslavská', 'Jarmila Nová', 'Helena Kubová'] },
  6: { m: ['Petr Dvořák', 'Jakub Šťastný', 'Ondřej Malý', 'Filip Kos', 'Adam Polák', 'Daniel Veselý'], f: ['Tereza Nová', 'Kristýna Horáková', 'Lenka Bartošová', 'Monika Pešková', 'Barbora Kalina', 'Nikola Říhová'] },
};

/// Konce vlády v dávných dobách (budoucnost má vlastní, viz cards.js). Klíče jsou stejné jako u hlavních konců.
export const ENDINGS_PAST = {
  fin: {
    low: { title: 'Hlad a bída', text: 'Zásoby došly a pokladna zela prázdnotou. Lidé odešli hledat obživu jinam a ty jsi zůstal{a} vládnout prázdným domům.' },
    high: { title: 'Vláda boháčů', text: 'Bohatí obchodníci zbohatli tolik, že si koupili i tvůj trůn. Vládneš jen naoko – rozhodují oni.' },
  },
  lid: {
    low: { title: 'Vzpoura', text: 'Lid povstal. Dav vtrhl do tvého sídla a ty jsi utekl{a} za soumraku jen s tím, co jsi měl{a} na sobě.' },
    high: { title: 'Vláda davu', text: 'Lid tě miloval tak, že chtěl pořád víc. Kdo slíbil ještě víc, ten tě svrhl – za jásotu davu.' },
  },
  sil: {
    low: { title: 'Bezvládí', text: 'Bojovníci se rozutekli a nikdo nehlídal hranice. Nájezdníci si vzali, co chtěli – i tvou vládu.' },
    high: { title: 'Převrat', text: 'Válečníci usoudili, že vládnout umějí lépe. Za úsvitu tě obklíčili a vůdce vojska usedl na tvé místo.' },
  },
  ved: {
    low: { title: 'Zaostalost', text: 'Sousedé se naučili nové věci, ale tvůj lid zůstal pozadu. Když přišli s lepšími zbraněmi, nebylo čím se bránit.' },
    high: { title: 'Vláda učenců', text: 'Učenci získali takovou moc, že převzali vládu sami – prý pro dobro všech. Ty jsi jim jen překážel{a}.' },
  },
  pri: {
    low: { title: 'Zničená zem', text: 'Lesy padly, řeky zčernaly a pole přestala rodit. Země, která vás živila, umírá – a lid tě vyhnal.' },
    high: { title: 'Divočina', text: 'Příroda pohltila pole i vesnice. Lidé se rozprchli do lesů a tvé sídlo zarostlo trním.' },
  },
  vir: {
    low: { title: 'Ztráta víry', text: 'Lidé přestali věřit čemukoli – bohům, tradicím i tobě. Nikdo už neposlouchal tvé příkazy.' },
    high: { title: 'Fanatismus', text: 'Kněží a proroci rozpálili lid k šílenství. Prohlásili tě za rouhače a vyhnali tě ze země.' },
  },
  dip: {
    low: { title: 'Osamění', text: 'Pohádal{a} ses se všemi sousedy. Když přišla bída, nikdo nepomohl – a když přišli nepřátelé, nikdo nestál při vás.' },
    high: { title: 'Poddanství', text: 'Tolik ses klaněl{a} mocným sousedům, že si nakonec vzali celou zemi. Teď jsi jen jejich správce.' },
  },
};

// Zkratka pro zápis karty: c(id, doba, kdo, text, [popisek, efekty, navíc] × 4 (vlevo, vpravo, nahoru, dolů), vlastnosti karty)
const o = ([t, e, more = {}]) => ({ t, e, ...more });
const c = (id, age, who, text, l, r, u, d, extra = {}) => ({ id, age, who, text, opts: { left: o(l), right: o(r), up: o(u), down: o(d) }, ...extra });
const ADV = { advance: true };
const adv = (flag) => ({ advance: true, set: flag }); // přelom s volbou cesty dějin
const milestone = { weight: 0, milestone: true };

export const AGE_CARDS = [
  // ── Pravěk ────────────────────────────────────────────
  c('dej_intro', 1, 'star', 'Stařešinové tě zvolili do čela kmene. Jsme hrstka lovců u velké řeky. Každý den za tebou někdo přijde – táhni kartu do čtyř stran a rozhodni. Hlídej, ať nic nepřeroste ani nezmizí.',
    ['Povedu vás', { lid: 5 }], ['Nejdřív lov', { sil: 5 }], ['Poradím se s duchy', { vir: 5 }], ['Ukažte mi zásoby', { fin: 5 }], { weight: 0, once: true }),
  c('p_mamut', 1, 'lov', 'Stopy mamuta, {osl}! Jeden úlovek nasytí kmen na celou zimu. Jenže mamut umí zabíjet.',
    ['Lovit všichni', { lid: 10, sil: -10 }], ['Jen nejlepší lovci', { sil: -5, lid: 5 }], ['Nechat ho jít', { pri: 10, lid: -10 }], ['Past z jámy', { ved: 10, sil: -5, pri: -5 }]),
  c('p_ohen', 1, 'sam', 'Blesk zapálil strom. Šaman tvrdí, že oheň je dar duchů a smí ho střežit jen on.',
    ['Oheň patří všem', { lid: 10, vir: -10 }], ['Ať ho střeží šaman', { vir: 5, ved: -5, lid: -5 }], ['Naučit se ho rozdělat', { ved: 15, vir: -5 }], ['Oheň je nebezpečný', { pri: 5, lid: -5, ved: -5 }]),
  c('p_malby', 1, 'sber', 'Děti malují na stěny jeskyně zvířata. Stařešinové říkají, že je to plýtvání vzácnou hlinkou.',
    ['Ať malují', { vir: 5, lid: 5, fin: -5 }], ['Zakázat to', { fin: 5, lid: -5, vir: -5 }], ['Malby pro šťastný lov', { vir: 5, sil: -5, ved: 5 }], ['Vyměnit hlinku', { fin: 10, vir: -5 }]),
  c('p_zima', 1, 'star', 'Přichází tuhá zima a zásoby nevydrží všem. Co uděláme, {osl}?',
    ['Dělit spravedlivě', { lid: 10, fin: -10 }], ['Nejdřív lovci', { sil: 5, lid: -10 }], ['Táhnout na jih', { dip: 10, lid: -5, fin: -5 }], ['Vzít zásoby sousedům', { fin: 10, dip: -15, sil: 5 }]),
  c('p_vlci', 1, 'lov', 'Vlci krouží kolem tábora. Jedno vlče přišlo až k ohni a vůbec se nás nebojí.',
    ['Vlky zahnat', { sil: 5, pri: -10 }], ['Ochočit vlče', { ved: 10, pri: -5 }], ['Vlci jsou posvátní', { vir: 5, sil: -5 }], ['Přesunout tábor', { lid: -5, pri: 5, fin: -5 }]),
  c('p_soused', 1, 'ciz', 'Jsem z kmene za horami. Nabízíme pazourky za vaše kožešiny – a ruku naší dcery tvému synovi.',
    ['Odmítnout cizince', { dip: -10, vir: -5 }], ['Obchodovat', { fin: 10, dip: 5, pri: -5 }], ['Svatba a spojenectví', { dip: 15, vir: -5, lid: -5 }], ['Přepadnout je', { sil: 5, fin: 5, dip: -15 }]),
  c('p_nemoc', 1, 'sam', 'Polovina tábora má horečku. Šaman chce obětovat duchům nejlepší kožešiny.',
    ['Obětovat', { vir: 10, fin: -10 }], ['Byliny od sběraček', { ved: 10, vir: -5 }], ['Oddělit nemocné', { lid: -10, sil: 5, ved: 5 }], ['Odejít od nemocných', { lid: -15, fin: 5 }]),
  c('p_hvezdy', 1, 'star', 'Stařešina Bór sleduje hvězdy. Tvrdí, že podle nich pozná, kdy přijde jaro.',
    ['Hloupost', { ved: -5, lid: 5 }], ['Postavit kamenný kruh', { ved: 10, vir: 5, fin: -10 }], ['Hvězdy jsou bohové', { vir: 10, ved: -10 }], ['Ať učí mladé', { ved: 5, lid: 5, fin: -5 }]),
  c('p_reka', 1, 'sber', 'U řeky rostou divoká zrna. Kdybychom tu zůstali, nemuseli bychom věčně táhnout za stády.',
    ['Jsme kočovníci', { vir: 5, ved: -5, pri: 5 }], ['Zůstat u řeky', { fin: 10, pri: -10 }], ['Zkusit to jedno léto', { ved: 5, fin: 5, lid: -5 }], ['Sbírat a jít dál', { lid: 5, fin: -5 }]),
  c('p_hrob', 1, 'sam', 'Zemřel nejstarší lovec kmene. Jak ho pohřbíme?',
    ['Se zbraněmi a dary', { vir: 5, fin: -10 }], ['Prostě ho pohřbít', { fin: 5, vir: -5 }], ['Velká mohyla', { vir: 5, lid: 5, fin: -10 }], ['Spálit na hranici', { pri: -5, vir: 5, lid: -5 }]),
  c('prelom1', 1, 'sber', 'Zrna, která jsme loni zasadili u řeky, vzešla! Můžeme se usadit a pěstovat obilí – nebo ochočit kozy a ovce a chovat stáda. Začala by nová doba.',
    ['Zasít pole', { fin: 10, pri: -10 }, adv('b_pole')], ['Ještě ne', { pri: 5, vir: 5 }], ['Chovat stáda', { lid: 5, pri: -5, sil: 5 }, adv('b_stada')], ['Zůstat lovci', { sil: 5, ved: -5 }], milestone),

  // ── Starověk ──────────────────────────────────────────
  c('s_chram', 2, 'knez', 'Bohové žádají chrám vyšší než hory, {osl}. Stavět se bude dvacet let.',
    ['Nestavět', { vir: -10, fin: 5 }], ['Postavit chrám', { vir: 10, fin: -10 }], ['Menší svatyně', { vir: 5, fin: -5 }], ['Chrám i tržiště', { fin: 5, vir: 5, lid: -10 }]),
  c('s_pismo', 2, 'pis', 'Vymyslel jsem znaky, kterými lze zapsat řeč. Zákony i sklizně by se daly zaznamenat navždy.',
    ['K čemu to je?', { ved: -10, lid: 5 }], ['Učit písaře', { ved: 10, fin: -5 }], ['Psát zákony', { ved: 5, sil: 5, lid: -5 }], ['Písmo jen pro kněze', { vir: 5, ved: 5, lid: -10 }]),
  c('s_kanaly', 2, 'pis', 'Řeka každé jaro zaplaví pole. Mohli bychom kopat kanály a zavlažovat i poušť.',
    ['Kopat kanály', { fin: 10, pri: -10, lid: -5 }], ['Nechat řeku být', { pri: 10, fin: -5 }], ['Najmout dělníky', { lid: 5, fin: 5, ved: 5, sil: -5 }], ['Obětovat bohu řeky', { vir: 5, fin: 5, pri: -5 }]),
  c('s_hry', 2, 'filo', 'Lid se nudí a reptá. Uspořádejme hry – závody, zápas a hudbu na počest bohů.',
    ['Hry pro všechny', { lid: 10, fin: -10 }], ['Žádné hry', { lid: -10, fin: 5 }], ['Hry se sousedy', { dip: 10, lid: 5, fin: -10 }], ['Zápasy v aréně', { lid: 10, vir: -5, sil: 5 }]),
  c('s_barbari', 2, 'voj', 'Za hranicí se shromáždili barbaři, {osl}. Mám vyrazit, nebo stavět zeď?',
    ['Postavit zeď', { sil: 5, fin: -10 }], ['Vyrazit do boje', { sil: -5, fin: 10, lid: -10 }], ['Uplatit je zlatem', { fin: -10, dip: 10 }], ['Najmout je do vojska', { sil: 5, dip: 5, lid: -5 }]),
  c('s_mor', 2, 'knez', 'Ve městě je mor. Kněží tvrdí, že bohové trestají naše hříchy.',
    ['Velké oběti', { vir: 5, fin: -10 }], ['Zavřít brány', { sil: 5, lid: -10, dip: -5 }], ['Poslat pro lékaře', { ved: 10, fin: -5, vir: -5 }], ['Utéct z města', { lid: -15, sil: -5 }]),
  c('s_vestirna', 2, 'knez', 'Věštkyně prorokuje, že padne velká říše. Neřekla ale která.',
    ['Vyhlásit válku', { sil: -5, fin: 5, dip: -10 }], ['Věštbu umlčet', { vir: -10, sil: 5 }], ['Ptát se znovu', { vir: 5, fin: -5 }], ['Smát se tomu', { vir: -5, lid: 5, ved: 5 }]),
  c('s_zakonik', 2, 'pis', 'Lidé se přou o půdu a dluhy. Vytesáme zákony do kamene, aby platily pro všechny?',
    ['Zákon pro všechny', { lid: 10, sil: -5, fin: -5 }], ['Zákon je král', { sil: 5, lid: -10, fin: 5 }], ['Oko za oko', { sil: 5, vir: 5, lid: -5 }], ['Ať soudí kněží', { vir: 10, ved: -5 }]),
  c('s_lod', 2, 'kup', 'Postavila jsem loď, která dopluje až za moře. Dejte mi zboží a vrátím se se zlatem.',
    ['Riskovat to', { fin: 10, dip: 5, sil: -5 }], ['Moře je zrádné', { fin: -5, dip: -5 }], ['Celá flotila', { fin: 15, dip: 10, pri: -10 }], ['Vzít i vojáky', { sil: 5, dip: -10, fin: 5 }]),
  c('s_filozof', 2, 'filo', 'Učím mladé lidi pochybovat o všem – i o bozích. Kněží chtějí, abych vypil jed.',
    ['Ať vypije jed', { vir: 5, ved: -10 }], ['Nechat ho učit', { ved: 10, vir: -10 }], ['Založit akademii', { ved: 10, fin: -10 }], ['Do vyhnanství', { dip: 5, ved: -5, lid: -5 }]),
  c('prelom2', 2, 'voj', 'Velká říše se rozpadá. Na jejích troskách mniši stavějí kláštery a rytíři hrady. Přijmeme nový řád?',
    ['Kláštery a víra', { vir: 10, fin: -5 }, adv('b_klastery')], ['Udržet starou říši', { sil: 5, fin: -5 }], ['Hrady a léna', { sil: 10, lid: -5 }, adv('b_hrady')], ['Ještě počkat', { lid: 5, ved: -5 }], milestone),

  // ── Středověk ─────────────────────────────────────────
  c('m_vyprava', 3, 'bisk', 'Papež volá k výpravě do Svaté země. Rytíři se hlásí, ale někdo to musí zaplatit.',
    ['Poslat rytíře', { vir: 5, sil: -10, fin: -5 }], ['Zůstat doma', { vir: -10, sil: 5 }], ['Jen zaplatit', { fin: -10, dip: 10 }], ['Vést výpravu', { vir: 10, lid: -10, sil: -5 }]),
  c('m_mor', 3, 'sedl', 'Černá smrt! Celé vesnice vymírají a lidé hledají viníka.',
    ['Zavřít vesnice', { sil: 5, lid: -5, fin: -10 }], ['Procesí a modlitby', { vir: 5, lid: -10 }], ['Pálit mrtvé', { ved: 5, vir: -5, pri: -5 }], ['Hledat viníky', { lid: 5, sil: 5, dip: -10 }]),
  c('m_katedrala', 3, 'bisk', 'Chceme postavit katedrálu, jakou svět neviděl, {osl}. Stavba potrvá sto let.',
    ['Stavět', { vir: 10, fin: -15 }], ['Na to nemáme', { vir: -10, fin: 5 }], ['Menší kostel', { vir: 5, fin: -5 }], ['Ať zaplatí cechy', { fin: 5, vir: 5, lid: -10 }]),
  c('m_turnaj', 3, 'ryt', 'Uspořádejte rytířský turnaj, {osl}! Přijedou šlechtici z celé Evropy.',
    ['Velký turnaj', { sil: 5, dip: 10, fin: -10 }], ['Žádné turnaje', { sil: -5, fin: 5 }], ['Turnaj pro lid', { lid: 10, fin: -5 }], ['Rytíři ať cvičí', { sil: 10, lid: -5 }]),
  c('m_alchymie', 3, 'alch', 'Jsem blízko! Ještě rok a promění olovo ve zlato. Potřebuji jen víc peněz.',
    ['Vyhodit ho', { ved: -5, fin: 5 }], ['Platit mu', { fin: -10, ved: 10 }], ['Ať hledá léky', { ved: 5, lid: 5, fin: -5 }], ['Upálit čaroděje', { vir: 5, ved: -15 }]),
  c('m_univerzita', 3, 'alch', 'Mistři a studenti chtějí vlastní univerzitu – svobodnou, bez dohledu biskupa.',
    ['Založit univerzitu', { ved: 15, vir: -5, fin: -10 }], ['Vzdělání patří církvi', { vir: 5, ved: -5, lid: -5 }], ['Univerzita s církví', { ved: 5, vir: 5, fin: -5 }], ['Studenti jsou buřiči', { sil: 5, ved: -10 }]),
  c('m_hlad', 3, 'sedl', 'Neúroda, {osl}. Sedláci nemají co jíst a pán chce desátek jako vždycky.',
    ['Odpustit desátek', { lid: 10, fin: -10 }], ['Vybrat desátek', { fin: 10, lid: -15 }], ['Otevřít sýpky', { lid: 10, fin: -5, sil: -5 }], ['Koupit obilí', { dip: 5, fin: -10, lid: 5 }]),
  c('m_kazatel', 3, 'bisk', 'Kazatel Jan káže proti bohatství církve. Lid ho miluje, biskup ho chce upálit.',
    ['Upálit ho', { vir: 5, lid: -15 }], ['Ochránit ho', { lid: 10, vir: -10 }], ['Pozvat ho k debatě', { ved: 5, vir: -5, lid: 5 }], ['Vyhnat ho ze země', { dip: -5, vir: 5, lid: -5 }]),
  c('m_spor', 3, 'ryt', 'Dva šlechtici se přou o hranice panství. Hrozí válka mezi tvými vazaly.',
    ['Rozsoudit sám', { sil: 5, lid: -5 }], ['Ať rozhodne souboj', { sil: -5, vir: 5 }], ['Vzít půdu oběma', { fin: 10, sil: -10 }], ['Sňatek mezi rody', { dip: 5, sil: 5, fin: -5 }]),
  c('m_kupci', 3, 'kup', 'Kupci z Benátek chtějí trh ve tvém městě. Přinesou koření, hedvábí – a cizí zvyky.',
    ['Otevřít trh', { fin: 10, dip: 5, vir: -5 }], ['Zavřít brány', { dip: -10, vir: -5 }], ['Vysoké clo', { fin: 15, dip: -10 }], ['Trh, ale ne v půstu', { fin: 5, vir: 5, lid: -5 }]),
  c('prelom3', 3, 'alch', 'Dva vynálezy mění svět: knihtisk, díky kterému se poznání rozletí mezi lidi, a střelný prach, před kterým nevydrží žádné hradby. Do čeho vložíme síly?',
    ['Knihtisk', { ved: 15, vir: -10 }, adv('b_tisk')], ['Zakázat obojí', { vir: 10, ved: -10 }], ['Střelný prach', { sil: 10, dip: -5 }, adv('b_prach')], ['Ještě počkat', { sil: 5, ved: -5 }], milestone),

  // ── Novověk ───────────────────────────────────────────
  c('n_plavba', 4, 'kap', 'Chci plout na západ a najít novou cestu do Indie. Potřebuji tři lodě, {osl}.',
    ['Dát mu lodě', { fin: -5, dip: 5, ved: 5 }], ['Je to šílenství', { fin: 5, ved: -10 }], ['Jen jednu loď', { fin: -5, ved: 5 }], ['Plout s vojskem', { sil: 10, dip: -10, fin: -5 }]),
  c('n_para', 4, 'vyn', 'Můj parní stroj pohání tkalcovský stav desetkrát rychleji než lidské ruce.',
    ['Postavit továrny', { fin: 15, pri: -10, lid: -5 }], ['Zakázat stroje', { lid: 10, ved: -10 }], ['Stroje i na pole', { ved: 10, fin: -5 }], ['Prodat ho cizině', { dip: 10, fin: 5, ved: -10 }]),
  c('n_ludite', 4, 'rev', 'Dělníci rozbíjejí stroje. Říkají, že jim berou práci a chléb.',
    ['Poslat vojsko', { sil: 5, lid: -15 }], ['Kratší pracovní den', { lid: 10, fin: -10 }], ['Škola pro dělníky', { ved: 5, lid: 5, fin: -10 }], ['Nevšímat si', { lid: -10, fin: 5 }]),
  c('n_ockovani', 4, 'vyn', 'Lékař tvrdí, že kravské neštovice chrání před pravými. Chce očkovat děti.',
    ['Očkovat všechny', { ved: 10, lid: 5, vir: -10 }], ['To je ďábelské', { vir: 10, ved: -10 }], ['Nejdřív dobrovolníci', { ved: 5, fin: -5 }], ['Očkovat vojáky', { sil: 5, ved: 5, lid: -5 }]),
  c('n_zeleznice', 4, 'tov', 'Postavme železnici přes celou zemi! Vlak dojede do přístavu za jediný den.',
    ['Stavět', { fin: 5, dip: 5, pri: -10 }], ['Koně stačí', { pri: 5, ved: -5 }], ['Ať staví soukromníci', { fin: 10, lid: -10 }], ['Trať pro vojsko', { sil: 10, fin: -10 }]),
  c('n_osvicenstvi', 4, 'hrabe', 'Filozofové píšou, že každý člověk má práva – i proti panovníkovi. Mám ty spisy zakázat?',
    ['Zakázat spisy', { vir: 5, sil: 5, lid: -10 }], ['Svoboda tisku', { lid: 10, ved: 5, sil: -10 }], ['Pozvat je ke dvoru', { ved: 10, dip: 5, vir: -5 }], ['Jen mírná cenzura', { sil: 5, ved: -5 }]),
  c('n_revoluce', 4, 'rev', 'Lid se shromáždil na náměstí a žádá ústavu. Prý jinak padne koruna.',
    ['Dát jim ústavu', { lid: 15, sil: -10 }], ['Rozehnat dav', { sil: 5, lid: -15 }], ['Slíbit reformy', { lid: 5, vir: -5 }], ['Utéct z paláce', { lid: -5, dip: 5, sil: -5 }]),
  c('n_uhli', 4, 'tov', 'Moje továrna potřebuje uhlí. Pod lesem v horách je ho plno – jen ten les vykácet.',
    ['Kácet a těžit', { fin: 15, pri: -10 }], ['Les zůstane', { pri: 10, fin: -10 }], ['Jen část lesa', { fin: 5, pri: -5 }], ['Ať koupí cizí uhlí', { dip: 5, fin: -5, pri: 5 }]),
  c('n_bal', 4, 'hrabe', 'Dvorní bál, {osl}! Pozvat celou Evropu stojí jmění, ale spojenectví se dělají při tanci.',
    ['Velký bál', { dip: 10, fin: -15 }], ['Skromnost', { fin: 5, dip: -10 }], ['Bál pro měšťany', { lid: 10, fin: -5 }], ['Bál se zásnubami', { dip: 10, vir: 5, lid: -5 }]),
  c('n_novy_svet', 4, 'kap', 'Na novém kontinentu je bohatství. Zabrat tamní půdu, nebo s místními obchodovat?',
    ['Obchodovat', { fin: 5, dip: 10 }], ['Zabrat půdu', { fin: 15, dip: -15, vir: -5 }], ['Poslat misionáře', { vir: 10, dip: -5 }], ['Nechat je být', { vir: 5, fin: -5 }]),
  c('prelom4', 4, 'vyn', 'Podařilo se mi zkrotit elektřinu – světlo bez ohně! Jenže továrník Kraus sází na ropu a spalovací motor. Kudy se dá svět?',
    ['Elektřina', { ved: 10, fin: -10 }, adv('b_elektrina')], ['Je to nebezpečné', { ved: -10, vir: 5 }], ['Ropa a motory', { fin: 10, pri: -10 }, adv('b_ropa')], ['Nejdřív pokusy', { ved: 5, fin: -5 }], milestone),

  // ── Moderní doba ──────────────────────────────────────
  c('x_volebni_pravo', 5, 'novin', 'Ženy chtějí volit. Tradicionalisté varují, že to rozvrátí rodiny.',
    ['Volební právo všem', { lid: 10, vir: -5 }], ['Nic se nemění', { vir: 5, lid: -10 }], ['Nejdřív v obcích', { lid: 5, sil: -5 }], ['Vypsat referendum', { lid: 5, fin: -5, vir: 5 }]),
  c('x_krach', 5, 'dipl', 'Burza se zhroutila, {osl}. Lidé vybírají úspory a banky krachují jedna za druhou.',
    ['Zachránit banky', { fin: 10, lid: -10 }], ['Veřejné stavby', { lid: 10, fin: -15 }], ['Tisknout peníze', { fin: 5, lid: 5, dip: -10 }], ['Šetřit', { fin: 5, lid: -15 }]),
  c('x_radio', 5, 'inz', 'Rádio dosáhne do každé chalupy. Kdo bude rozhodovat, co se vysílá?',
    ['Státní rozhlas', { sil: 5, vir: 5, lid: -5 }], ['Svobodné vysílání', { lid: 10, sil: -5 }], ['Vzdělávací pořady', { ved: 10, fin: -5 }], ['Zaplatí to reklama', { fin: 10, vir: -5 }]),
  c('x_diktator', 5, 'genl', 'Sousední diktátor shromažďuje vojska u hranic. Spojenci slibují pomoc – možná.',
    ['Zbrojit', { sil: 15, fin: -10, lid: -5 }], ['Ustoupit mu', { dip: 10, sil: -15 }], ['Spojenectví', { dip: 10, sil: 5, fin: -5 }], ['Neutralita', { dip: -10, fin: 5 }]),
  c('x_atom', 5, 'inz', 'Umíme rozštěpit atom. Můžeme mít levnou elektřinu – nebo strašlivou zbraň.',
    ['Jaderná elektrárna', { ved: 10, fin: 5, pri: -10 }], ['Vyrobit bombu', { sil: 15, dip: -15 }], ['Mezinárodní dohled', { dip: 10, ved: 5, sil: -5 }], ['Zakázat výzkum', { ved: -15, pri: 5 }]),
  c('x_auto', 5, 'tov', 'Lidové auto pro každou rodinu! Jen k tomu potřebujeme silnice, {osl}.',
    ['Stavět dálnice', { fin: -10, lid: 10, pri: -10 }], ['Raději vlaky', { pri: 5, fin: -5, lid: 5 }], ['Auta jen pro bohaté', { fin: 10, lid: -10 }], ['Zůstat u koní', { ved: -10, pri: 10 }]),
  c('x_druzice', 5, 'inz', 'Sousedé vypustili družici. Jestli nechceme zaostat, musíme taky do vesmíru.',
    ['Vlastní raketa', { ved: 15, fin: -15 }], ['Na to nemáme', { ved: -10, fin: 5 }], ['Spolupracovat', { dip: 10, ved: 5, fin: -5 }], ['Vojenská raketa', { sil: 10, dip: -10 }]),
  c('x_osn', 5, 'dipl', 'Národy zakládají společnou organizaci pro mír. Vstoupíme do ní?',
    ['Vstoupit', { dip: 15, sil: -5 }], ['Zůstat stranou', { dip: -10, sil: 5 }], ['Chtít křeslo v radě', { dip: 10, fin: -10 }], ['Vstoupit a mlčet', { dip: 5, lid: -5 }]),
  c('x_televize', 5, 'novin', 'Lidé milují televizi. Opozice chce na obrazovce stejně času jako vláda.',
    ['Dát jim ho', { lid: 10, sil: -5 }], ['Televize je naše', { sil: 5, vir: 5, lid: -10 }], ['Debata naživo', { lid: 5, ved: 5, vir: -5 }], ['Jen zábava', { lid: 5, ved: -10 }]),
  c('x_zelezna_opona', 5, 'genl', 'Za hranicí vyrostla zeď s ostnatým drátem. Špioni jsou všude.',
    ['Stavět kryty', { sil: 5, fin: -10, lid: -5 }], ['Uvolnit napětí', { dip: 10, sil: -10 }], ['Špionáž', { sil: 10, dip: -10 }], ['Otevřít hranice', { lid: 10, sil: -10 }]),
  c('prelom5', 5, 'inz', 'Máme peníze jen na jeden velký projekt: spojit počítače do celosvětové sítě, nebo poslat lidi do vesmíru?',
    ['Internet', { ved: 10, lid: 5, vir: -5 }, adv('b_sit')], ['Ani jedno', { ved: -10, fin: 5 }], ['Vesmírný program', { ved: 10, fin: -10 }, adv('b_vesmir')], ['Počkat na sousedy', { dip: 5, ved: -5 }], milestone),

  // ── Současnost ────────────────────────────────────────
  c('c_video', 6, 'infl', 'Moje video o vaší vládě vidělo pět milionů lidí. Mám natočit další?',
    ['Ignorovat ji', { lid: -5, vir: -5 }], ['Spolupracovat', { lid: 10, vir: -5, fin: -5 }], ['Regulovat sítě', { fin: 5, lid: -10, ved: 5 }], ['Vlastní kanál vlády', { lid: 5, fin: -10, vir: 5 }]),
  c('c_klima', 6, 'klim', 'Ledovce tají rychleji, než jsme čekali, {osl}. Musíme okamžitě omezit uhlí.',
    ['Zavřít doly', { pri: 15, fin: -10, lid: -5 }], ['Uhlí je práce', { fin: 10, pri: -15 }], ['Solární elektrárny', { pri: 10, ved: 5, fin: -10 }], ['Uhlíková daň', { fin: 5, pri: 5, lid: -10 }]),
  c('c_ai', 6, 'tech', 'Moje umělá inteligence píše, maluje i programuje. Lidé se bojí o práci.',
    ['Zakázat ji', { ved: -15, lid: 5 }], ['Volný trh', { fin: 10, ved: 10, lid: -15 }], ['Pravidla pro AI', { ved: 5, fin: 5, lid: -5 }], ['Rekvalifikace', { lid: 10, fin: -10 }]),
  c('c_virus', 6, 'klim', 'Ze zámoří se šíří nový virus. Zavřeme hranice, obchody a školy?',
    ['Zavřít všechno', { sil: -5, fin: -10, lid: -5 }], ['Žít normálně', { lid: 5, fin: 5, ved: -10 }], ['Roušky a testy', { ved: 10, fin: -5, lid: -5 }], ['Zavřít jen hranice', { dip: -10, fin: -5, sil: 5 }]),
  c('c_mobily', 6, 'tech', 'Každé dítě chce chytrý telefon. Učitelé chtějí zakázat mobily ve školách.',
    ['Zakázat ve školách', { ved: 5, lid: -5 }], ['Tablet každému žákovi', { ved: 10, fin: -5, sil: -5 }], ['Digitální výuka', { ved: 5, fin: -5, vir: -5 }], ['Ať rozhodnou rodiče', { lid: 5, ved: -5 }]),
  c('c_hoax', 6, 'infl', 'Po síti koluje lež, že vláda tají mimozemšťany. Věří jí čtvrtina lidí.',
    ['Vysvětlit pravdu', { ved: 5, vir: -5 }], ['Smazat to', { sil: -5, lid: -5 }], ['Zasmát se tomu', { lid: 5, vir: -5, ved: -5 }], ['„Přiznat“ je', { vir: 15, ved: -10 }]),
  c('c_krypto', 6, 'tech', 'Proč tisknout peníze? Udělejte z kryptoměny státní platidlo!',
    ['Ani náhodou', { fin: 5, ved: -5 }], ['Zkusit to', { fin: -10, ved: 10, dip: -5 }], ['Regulovat je', { fin: 10, sil: -5, lid: -5 }], ['Státní těžba', { fin: 10, pri: -10 }]),
  c('c_hranice', 6, 'dipl', 'K hranicím míří tisíce lidí, kteří utíkají před válkou.',
    ['Přijmout je', { dip: 10, lid: -10 }], ['Zavřít hranice', { dip: -10, sil: 5, lid: 5 }], ['Rozdělit je v Evropě', { dip: 5, fin: -5 }], ['Pomoc v jejich zemi', { fin: -10, dip: 5, vir: 5 }]),
  c('c_vetrniky', 6, 'klim', 'Postavíme na horách větrné elektrárny? Turisté a ochránci ptáků jsou proti.',
    ['Stavět', { fin: -10, pri: 10, lid: -5 }], ['Ne v horách', { lid: 5, pri: -5 }], ['Na moři', { fin: -10, pri: 10, dip: 5 }], ['Jádro místo větru', { ved: 10, fin: -10, lid: -5 }]),
  c('prelom6', 6, 'tech', 'Celý svět je napojený na jedinou síť – a ta právě spadla. Elektřina, banky, telefony, všechno. Začíná Velký výpadek.',
    ['Začít znovu od nuly', { lid: -5, ved: -5 }, adv('b_nula')], ['Restartovat síť', { ved: 5, fin: -10 }], ['Pevnou rukou', { vir: 5, sil: 5 }, adv('b_republika')], ['Stav nouze', { sil: 10, lid: -10 }], milestone),
];
