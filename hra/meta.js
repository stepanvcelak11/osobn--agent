// Postup mezi hrami: úrovně vůdců, strom dynastie, relikvie, vzhledy, kampaň a prestiž.
// Jen data – engine (game.js) a obrazovky (ui.js) z nich čtou.

/// Zkušenost vůdce = odvládnuté měsíce s daným typem. Úroveň 2: mírnější začátek vlády,
/// úroveň 3: mistrovství (typ dostane silnější schopnost), úroveň 4: legenda (body navíc).
export const LEVELS = [0, 36, 120, 300];
export const levelOf = (xp = 0) => LEVELS.filter((n) => xp >= n).length;
export const MASTERY = {
  vize: 'Vidí i velikost změny – velká změna má plnou tečku.',
  krize: 'Za krajnost bere už ukazatel pod 35 % nebo nad 65 %.',
  odklad: 'Schopnost se nabije už po 4 rozhodnutích.',
  kormidlo: 'Schopnost se nabije po 4 rozhodnutích a posune o 20 bodů.',
  rada: 'Rádce radí nejlépe v 85 % případů.',
  zachrance: 'Zachrání se dvakrát za vládu.',
  charisma: 'Nepřátelství roste jen normálně rychle, přátelství dál dvojnásob.',
  prorok: 'Vidí i směr změny jako Vizionář.',
  byro: 'Zákony působí třikrát silněji.',
  hazard: 'Náhoda je mu nakloněná: účinek 0,5× až 1,2×.',
  reform: 'Schopnost se nabije už po 4 rozhodnutích.',
};
export const LEVEL_TEXT = ['', 'Nováček', 'Zkušený: vláda začíná mírněji', 'Mistr: silnější schopnost', 'Legenda: +1 bod za každou vládu delší než rok'];

/// Strom dynastie – trvalá vylepšení za body (3 stupně).
export const TREE = {
  zaklady: { name: 'Pevné základy', icon: 'law', cost: [4, 8, 12], text: (n) => `Začátek každé vlády je mírnější (síla −${(n * 0.06).toFixed(2).replace('.', ',')}).` },
  slechta: { name: 'Stará šlechta', icon: 'vote', cost: [3, 6, 9], text: (n) => `Ve volbách máš podporu +${n * 4} %.` },
  pokladna: { name: 'Pokladna', icon: 'trophy', cost: [5, 10, 15], text: (n) => `Za vládu dostaneš o ${n * 20} % bodů víc.` },
  predkove: { name: 'Moudrost předků', icon: 'rada', cost: [3, 6, 9], text: (n) => `Na prvních ${n * 5} kartách každé vlády radí mudrc.` },
  dech: { name: 'Druhý dech', icon: 'rescue', cost: [6, 10, 16], text: (n) => (n >= 3 ? 'Každý vůdce se jednou zachrání před pádem.' : `${n === 1 ? 'Jednou' : 'Dvakrát'} za hru tě zachrání před pádem.`) },
};
export const TREE_MAX = 3;

/// Relikvie – vzácné předměty. Nasadit lze nejvýš dvě.
export const RELIC_SLOTS = 2;
export const RELICS = {
  mince: { name: 'Stará mince', m: 'fin', text: 'Finance se mění o čtvrtinu méně.' },
  korali: { name: 'Korálky lidu', m: 'lid', text: 'Lid se mění o čtvrtinu méně.' },
  mec: { name: 'Zlomený meč', m: 'sil', text: 'Síla se mění o čtvrtinu méně.' },
  svitek: { name: 'Svitek mudrců', m: 'ved', text: 'Věda se mění o čtvrtinu méně.' },
  semeno: { name: 'Věčné semeno', m: 'pri', text: 'Příroda se mění o čtvrtinu méně.' },
  ohen: { name: 'Ohnivý kámen', m: 'vir', text: 'Víra se mění o čtvrtinu méně.' },
  pecet: { name: 'Pečeť míru', m: 'dip', text: 'Diplomacie se mění o čtvrtinu méně.' },
  koruna: { name: 'Železná koruna', text: 'Ve volbách máš podporu +5 %.' },
  hodiny: { name: 'Přesýpací hodiny', text: 'Síla rozhodnutí roste pomaleji (maximum až po 6 letech vlády).' },
  kompas: { name: 'Zlatý kompas', text: 'Vidíš, které ukazatele ovlivní další karta.' },
  zrcadlo: { name: 'Zrcadlo osudu', text: 'Jednou za hru tě zachrání před pádem.' },
  kalich: { name: 'Kalich hojnosti', text: 'Za splněný úkol dostaneš bod navíc.' },
};

/// Vzhledy karet (třída na <body>).
export const SKINS = {
  klasik: { name: 'Klasický', price: 0 },
  zlato: { name: 'Zlatý rám', price: 4 },
  noc: { name: 'Noční', price: 4 },
  krev: { name: 'Rudý', price: 4 },
  smaragd: { name: 'Smaragdový', price: 6 },
  hvezdy: { name: 'Hvězdný', price: 0, how: 'Za kompletní album postav jedné doby.' },
};

/// Prestiž: po dosažení budoucnosti v Dějinách lze začít znovu od pravěku, těžší a s víc body.
export const PRESTIGE_STEP = 0.15; // o kolik zesílí rozhodnutí na každý stupeň
export const PRESTIGE_BONUS = 0.5; // o kolik víc bodů na každý stupeň
export const ROMAN = ['', 'I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X'];

/// Kampaň: kapitoly s pevným zadáním. Hvězdy podle toho, kolik ukazatelů je při splnění v klidu (30–70 %).
export const CAMPAIGN = [
  { id: 'k1', name: 'První zima', text: 'Pravěk. Doveď kmen přes první rok.', world: 'dejiny', kind: 'vize', goal: { months: 12 } },
  { id: 'k2', name: 'Hladový kmen', text: 'Zásoby jsou skoro pryč (Finance 25 %). Vydrž 18 měsíců.', world: 'dejiny', kind: 'krize', meters: { fin: 25 }, goal: { months: 18 } },
  { id: 'k3', name: 'Oheň a víra', text: 'Šaman má moc (Víra 75 %). Vydrž 2 roky a drž Víru pod 85 %.', world: 'dejiny', kind: 'rada', meters: { vir: 75 }, goal: { months: 24, max: { vir: 85 } } },
  { id: 'k4', name: 'Zemědělci', text: 'Dostaň kmen do starověku (přijmi objev zemědělství).', world: 'dejiny', kind: 'odklad', goal: { age: 2 } },
  { id: 'k5', name: 'Válka za řekou', text: 'Silný soused (Síla 30 %, Diplomacie 30 %). Vydrž 2 roky.', world: 'dejiny', kind: 'kormidlo', meters: { sil: 30, dip: 30 }, goal: { months: 24 } },
  { id: 'k6', name: 'Velký skok', text: 'Doveď říši do středověku dřív, než uplyne 60 karet.', world: 'dejiny', kind: 'prorok', goal: { age: 3, within: 60 } },
  { id: 'k7', name: 'Nová republika', text: 'Rok 2089. Vyhraj první volby (vydrž 4 roky).', world: '2089', kind: 'charisma', goal: { months: 48 } },
  { id: 'k8', name: 'Rozbouřená země', text: 'Ztížení Bouřlivé časy. Vydrž 3 roky.', world: '2089', kind: 'zachrance', mods: ['boure'], goal: { months: 36 } },
  { id: 'k9', name: 'Úřednická vláda', text: 'Byrokrat. Měj zároveň 3 zákony v platnosti.', world: '2089', kind: 'byro', goal: { laws: 3 } },
  { id: 'k10', name: 'Od pazourku ke hvězdám', text: 'Proveď lid všemi dobami až do budoucnosti.', world: 'dejiny', kind: 'vize', goal: { age: 7 }, lives: 5 },
];
