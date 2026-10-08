// Herní logika Rovnováhy – bez DOMu, aby šla testovat v Node.
import { METERS, CARDS as BASE, INTRO, ENDINGS, SUCCESSORS, PEOPLE } from './cards.js';
import { EXTRA, LAWS, TASKS, ERAS, SPECIAL, CARES, REL_MAX, REL_LOYAL, PERKS, CRISES, ELECTION } from './world.js';
import { AGES, AGE_LEN, AGE_PEOPLE, AGE_CARES, AGE_NAMES, AGE_CARDS, ENDINGS_PAST } from './ages.js';

import { bondCards } from './bonds.js';
import { AGE_CARDS_MORE } from './ages_more.js';
import { SEASON_CARDS, STATE_CARDS, RIVAL_CARDS, TRAITOR_CARDS } from './events.js';
import { BRANCH_CARDS, WONDERS, WONDER_CARDS } from './history_more.js';
import { FACTION_CARDS, RUMOR_CARDS, ECHO_CARDS } from './depth.js';
import { PROJECT_CARDS, PROJECTS, PROJECT_MONTHS } from './projects.js';
import { RELICS, PRESTIGE_STEP } from './meta.js';

Object.assign(PEOPLE, AGE_PEOPLE, {
  // Zástupné postavy: skutečnou osobu určí doba (viz DYN) – tady jen pro jistotu.
  '@kraj': { name: 'Posel z kraje', icon: '🧺', color: '#9a8466', look: 'straw' },
  '@rada': { name: 'Rádce', icon: '📜', color: '#8a8f98', look: 'hair' },
  '@vysetr': { name: 'Vyšetřovatel', icon: '🕵️', color: '#6d6d6d', look: 'shades' },
  '@zradce': { name: 'Zrádce', icon: '🗡️', color: '#5a4a5a', look: 'hood' },
  riv: { name: 'Vyslanec sousedů', icon: '🏳️', color: '#7a6a9a', look: 'tophat' },
});
/// Kdo za zástupnou postavu mluví v které době.
const DYN = {
  '@kraj': { 1: 'sber', 2: 'pis', 3: 'sedl', 4: 'rev', 5: 'novin', 6: 'klim', 7: 'far' },
  '@rada': { 1: 'star', 2: 'pis', 3: 'bisk', 4: 'hrabe', 5: 'dipl', 6: 'tech', 7: 'tajemnik' },
  '@vysetr': { 1: 'sam', 2: 'knez', 3: 'bisk', 4: 'hrabe', 5: 'genl', 6: 'infl', 7: 'stin' },
};
/// Sousední říše v jednotlivých dobách (Dějiny lidstva).
export const RIVALS = {
  1: { name: 'Sokol, náčelník kmene za řekou', look: 'hood', color: '#7a6a5a' },
  2: { name: 'Vyslanec říše za pouští', look: 'bald', color: '#b08a4a' },
  3: { name: 'Vévoda ze sousedního království', look: 'cap', color: '#6a5a8a' },
  4: { name: 'Velvyslanec sousedního císařství', look: 'tophat', color: '#7a6a9a' },
  5: { name: 'Vyslanec sousední mocnosti', look: 'hair', color: '#5a6a7a' },
  6: { name: 'Premiérka sousední země', look: 'long', color: '#5a8a9a' },
};
/// Ztížení: víc bodů za těžší hru.
export const MODS = {
  hlad: { name: 'Hladová léta', text: 'Zásoby (Finance) každý měsíc trochu ubývají.', bonus: 0.25 },
  sousede: { name: 'Nevraživí sousedé', text: 'Diplomacie každý měsíc klesá a sousední říše sílí rychleji.', bonus: 0.25 },
  boure: { name: 'Bouřlivá doba', text: 'Všechna rozhodnutí mají o čtvrtinu větší účinek.', bonus: 0.4 },
  zradci: { name: 'Hnízdo zrádců', text: 'Zrádci se objevují třikrát častěji.', bonus: 0.2 },
};
export const BRANCHES = {
  b_pole: 'Zemědělství', b_stada: 'Chov stád', b_klastery: 'Kláštery a víra', b_hrady: 'Hrady a léna', b_tisk: 'Knihtisk', b_prach: 'Střelný prach',
  b_elektrina: 'Elektřina', b_ropa: 'Ropa a motory', b_sit: 'Internet', b_vesmir: 'Vesmírný program', b_nula: 'Začátek od nuly', b_republika: 'Pevná ruka',
};
const WONDER_BY_ID = Object.fromEntries(WONDERS.map((w) => [w.id, w]));
Object.assign(CARES, AGE_CARES);
// Kdo žije ve které době (podle karet) – karty vztahů se objeví jen tam.
const PERSON_AGE = {};
for (const c of [...AGE_CARDS, ...AGE_CARDS_MORE]) PERSON_AGE[c.who] ??= c.age;
const OWN_BONDS = [...new Set(EXTRA.filter((c) => c.rel).map((c) => c.who))];
const BONDS = bondCards(CARES, PERSON_AGE, OWN_BONDS, REL_LOYAL);
const CARDS = [...BASE, ...EXTRA, ...AGE_CARDS, ...AGE_CARDS_MORE, ...BONDS, ...SEASON_CARDS, ...STATE_CARDS, ...RIVAL_CARDS, ...TRAITOR_CARDS, ...BRANCH_CARDS, ...WONDER_CARDS, ...FACTION_CARDS, ...RUMOR_CARDS, ...ECHO_CARDS, ...PROJECT_CARDS];
export { PROJECTS, PROJECT_MONTHS };
/// Frakce: když jejich ukazatel dlouho klesá, roste jejich hněv a nakonec se vzbouří.
export const FACTIONS = {
  kneze: { name: 'Kněží', m: 'vir' },
  kupci: { name: 'Kupci', m: 'fin' },
  vojsko: { name: 'Vojsko', m: 'sil' },
  ucenci: { name: 'Učenci', m: 'ved' },
};
export const FACTION_MAX = 10, FACTION_REVOLT = 6;

export const DIRS = ['left', 'right', 'up', 'down'];
export const START = 50;
const RECENT = 14;
/// Citlivost ukazatelů – vyrovnává, jak často karty který ukazatel mění (ladí se simulací v testech),
/// aby žádný konec nebyl skoro nedosažitelný.
export const SCALE = { fin: 0.75, lid: 0.7, sil: 1.3, ved: 0.8, pri: 1.7, vir: 1.35, dip: 1.6 };
export function effect(k, v) { return Math.round(v * (SCALE[k] ?? 1)); }
const BY_ID = new Map([[INTRO.id, INTRO], ...CARDS.map((c) => [c.id, c])]);

export function cardById(id) { return BY_ID.get(id); }

/// Typy prezidenta – každý má jednu schopnost.
export const KINDS = [
  { id: 'vize', short: 'Vizionář', m: 'Vizionář', f: 'Vizionářka', icon: '🔭', text: 'Při tažení vidí, jestli volba ukazatel zvedne, nebo sníží – ale ne o kolik.' },
  { id: 'krize', short: 'Krizový', m: 'Krizový manažer', f: 'Krizová manažerka', icon: '🧯', text: 'Když je ukazatel v krajnosti (pod 30 % nebo nad 70 %), kroky zpět k rovnováze mají dvojnásobný účinek.' },
  { id: 'odklad', short: 'Vyčkávač', m: 'Vyčkávač', f: 'Vyčkávačka', icon: '⏭️', text: 'Po každých 5 rozhodnutích může jednu kartu odložit – nic se nestane a jde se dál.' },
  { id: 'kormidlo', short: 'Kormidelník', m: 'Kormidelník', f: 'Kormidelnice', icon: '🧭', text: 'Po každých 5 rozhodnutích může jeden ukazatel posunout o 15 bodů k rovnováze.' },
  { id: 'rada', short: 'Rádce', m: 'Prezident s rádcem', f: 'Prezidentka s rádcem', icon: '🦉', text: 'Rádce mu ke každé kartě poradí. V 7 případech z 10 radí to nejlepší, ve zbylých 3 to nejhorší.' },
  { id: 'zachrance', short: 'Zachránce', m: 'Zachránce', f: 'Zachránkyně', icon: '🛟', text: 'Jednou za vládu ho ukazatel na nule ani na maximu nesesadí – odrazí se zpátky na 15, nebo 85 %.' },
  { id: 'charisma', short: 'Charismatik', m: 'Charismatik', f: 'Charismatička', icon: '⭐', text: 'Vztahy s lidmi se mu mění dvakrát rychleji. Věrné spojence získá snadno – nepřátele taky.' },
  { id: 'prorok', short: 'Prorok', m: 'Prorok', f: 'Prorokyně', icon: '🔮', text: 'Vidí dopředu, které ukazatele ovlivní další karta – a může se na to připravit.' },
  { id: 'byro', short: 'Byrokrat', m: 'Byrokrat', f: 'Byrokratka', icon: '🗂️', text: 'Každé rozhodnutí má jen tři čtvrtiny účinku, ale zákony působí dvakrát silněji.' },
  { id: 'hazard', short: 'Hazardér', m: 'Hazardér', f: 'Hazardérka', icon: '🎲', text: 'Účinek každé volby je náhodně poloviční až jedenapůlnásobný. Za splněný úkol dostane dvě pečetě.' },
  { id: 'reform', short: 'Reformátor', m: 'Reformátor', f: 'Reformátorka', icon: '📜', text: 'Po každých 5 rozhodnutích může zavést, nebo zrušit libovolný zákon.' },
];
/// Typy se schopností, kterou hráč spouští sám (tlačítko vpravo nahoře se nabíjí).
export const ACTIVE = ['odklad', 'kormidlo', 'reform'];
export const CHARGE = 5;     // po kolika rozhodnutích se nabije schopnost
export const NUDGE = 15;     // o kolik posune Kormidelník
const EXTREME = 20;          // Krizový manažer: krajnost = dál než 20 od středu (pod 30 / nad 70)
export const ADVICE_OK = 0.7;
/// Celková síla rozhodnutí (laděno simulací): náhodné volby vydrží jen kolem roku, hráč, který se
/// občas splete, několik let, pečlivý hráč desítky let. Každá chyba je znát.
/// Na začátku vlády mírnější (1,8×), s každým měsícem vlády roste až na 2,6× – nováček hned nevypadne,
/// ale dlouhá vláda je čím dál ostřejší.
export const INTENSITY_START = globalThis.ROVNOVAHA_I0 ?? 1.8, INTENSITY_MAX = globalThis.ROVNOVAHA_I1 ?? 2.6;
export const INTENSITY_RAMP = globalThis.ROVNOVAHA_RAMP ?? 48; // za kolik měsíců vlády dosáhne maxima
export function intensity(state) {
  const p = (state?.prestige ?? 0) * PRESTIGE_STEP;
  const lo = INTENSITY_START + p - (state && lvlOf(state) >= 2 ? 0.1 : 0) - 0.06 * (state ? treeOf(state, 'zaklady') : 0);
  const hi = INTENSITY_MAX + p;
  const ramp = state && relic(state, 'hodiny') ? 72 : INTENSITY_RAMP;
  return lo + (hi - lo) * Math.min(1, (state?.turn ?? 0) / ramp);
}
export const PAST_SOFT = globalThis.ROVNOVAHA_PAST ?? 1; // dávné doby mají kratší balíčky – účinky jsou mírnější, aby vlády nebyly krátké
export const RESCUE = 15;    // Zachránce / Druhá šance: kam se ukazatel odrazí od kraje
export const TERM = 48;      // volby každé 4 roky
export const VOTE_MIN = 40;  // potřebná podpora (průměr Lidu a Spojenců)
export const lvlOf = (state) => state.leader?.lvl ?? 1;
export const master = (state) => lvlOf(state) >= 3;
export const relic = (state, id) => (state.meta?.relics ?? []).includes(id);
export const treeOf = (state, id) => state.meta?.tree?.[id] ?? 0;
export const chargeOf = (state) => CHARGE - (master(state) && ['odklad', 'kormidlo', 'reform'].includes(state.leader.kind) ? 1 : 0);
export const kindOf = (state) => KINDS.find((k) => k.id === state.leader.kind) || KINDS[0];
export const has = (state, perk) => (state.perks ?? []).includes(perk);
/** Vidí vůdce směr změn / další kartu? (typ, nebo výhoda) */
export const seesDirection = (state) => state.leader.kind === 'vize' || has(state, 'smer') || (state.leader.kind === 'prorok' && master(state));
/** Kdo přijde příště, vidí každý (karta pod kartou). Prorok a výhoda Zvědové navíc vidí, co další karta ovlivní. */
export const seesAhead = (state) => state.leader.kind === 'prorok' || has(state, 'nahled') || relic(state, 'kompas');

// Deterministický generátor (mulberry32) – stav se ukládá, takže hra jde přesně obnovit.
export function random(state) {
  let t = (state.seed = (state.seed + 0x6d2b79f5) >>> 0);
  t = Math.imul(t ^ (t >>> 15), t | 1);
  t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
}

function freshMeters() { return Object.fromEntries(METERS.map((m) => [m.id, START])); }

export function newGame({ name = '', female = false, kind = 'vize', mode = 'normal', world = null, mods = [], lvl = 1, meta = null, prestige = 0, meters = null } = {}, seed = Date.now() >>> 0) {
  const history = mode === 'dejiny' || world === 'dejiny';
  const leaderName = name.trim().slice(0, 30) || (history ? (female ? 'Ara' : 'Brok') : female ? 'Jana Nová' : 'Jan Nový');
  const s = {
    v: 1,
    seed: seed >>> 0 || 1,
    leader: { name: leaderName, female: !!female, n: 1, kind, age: history ? 1 : 7, lvl },
    meta: { tree: { ...(meta?.tree ?? {}) }, relics: [...(meta?.relics ?? [])] }, // trvalý postup hráče (strom, relikvie)
    prestige, // kolikrát svět začal znovu od pravěku
    fac: { kneze: 0, kupci: 0, vojsko: 0, ucenci: 0 }, // hněv frakcí
    later: [], // odložené důsledky {at, e, text}
    echoes: [], // co se z minulosti vrátilo (kronika)
    project: null, // rozestavěný velký projekt {id, left}
    built: [], // dokončené projekty
    mirror: false, // relikvie Zrcadlo osudu už zachránila
    charge: 0, // rozhodnutí od posledního použití schopnosti
    rel: {}, // vztahy postav k vládě (−5 … +5)
    drift: {}, // nastřádané účinky zákonů (zlomky bodů)
    task: null, // úkol současného vůdce {id, streak}
    tasksDone: [], // splněné úkoly = pečetě (celý svět)
    era: 1,
    news: [], // zprávy pro hráče (úkol splněn, nová éra, zákon…)
    advice: null, // co radí rádce k aktuální kartě
    peek: null, // kdo přijde příště (Prorok)
    luck: 1, // násobek účinku aktuální karty (Hazardér)
    rescued: false, // Zachránce už svou záchranu použil
    perks: [], // výhody současného vůdce
    perkOffer: null, // nabídka výhod po splněném úkolu (čeká na výběr)
    bonusSeals: 0,
    crisis: null, // probíhající krize {id, step, score}
    tally: { elections: 0, crises: 0 }, // vyhrané volby a zvládnuté krize (celá hra)
    mode,
    world: history ? 'dejiny' : '2089',
    mods: mods.filter((m) => MODS[m]),
    rival: { power: 30, absorbed: false }, // sousední říše (jen v dávných dobách)
    traitor: null, // skrytý zrádce {who, since, known}
    ext: {}, // jak dlouho je který ukazatel v krajnosti
    wonders: [], // dokončené divy světa
    age: history ? 1 : 7, // doba (Dějiny lidstva: 1 = pravěk … 7 = budoucnost)
    ageStart: 0, // kdy začala současná doba (počet karet)
    futureAt: history ? null : 0, // kdy svět dorazil do budoucnosti (éry Nové republiky se počítají od té chvíle)
    meters: { ...freshMeters(), ...(meters ?? {}) },
    flags: [],
    queue: [],
    recent: [],
    used: [],
    turn: 0, // měsíce vlády současného vůdce
    total: 0, // karty za celou hru
    card: history && mode === 'dejiny' ? 'dej_intro' : INTRO.id,
    history: [], // dřívější vůdci
    endings: [], // odemčené konce "fin.low"…
    best: 0,
    dead: null,
  };
  assignTask(s);
  return s;
}

/** Text s dosazeným oslovením a ženskými tvary. */
export function fill(text, leader) {
  const f = leader.female;
  const age = AGES[(leader.age ?? 7) - 1] ?? AGES[6];
  return text
    .replaceAll('{osl}', age.osl[f ? 1 : 0])
    .replaceAll('{a}', f ? 'a' : '')
    .replaceAll('{ty}', leader.name);
}

const MOOD_BAD = ['Bez pozdravu', 'Chladně', 'Nevraživě', 'Úsečně'];
const MOOD_GOOD = ['S úsměvem', 'Přátelsky', 'Srdečně'];
/** Kdo kartu skutečně přináší (zástupné postavy podle doby, zrádce). */
export function whoOf(state, c) {
  if (!c?.who?.startsWith('@')) return c?.who;
  if (c.who === '@zradce') return state.traitor?.who ?? 'tajemnik';
  return DYN[c.who]?.[state.age ?? 7] ?? 'tajemnik';
}
export function personOf(state, c) {
  const who = whoOf(state, c);
  if (who === 'riv') return { ...PEOPLE.riv, ...(RIVALS[state.age ?? 7] ?? {}) };
  return PEOPLE[who];
}
export function seasonOf(state) {
  const m = (state.turn % 12) + 1;
  return m === 12 || m <= 2 ? 'zima' : m <= 5 ? 'jaro' : m <= 8 ? 'leto' : 'podzim';
}
export const SEASON_NAMES = { zima: 'zima', jaro: 'jaro', leto: 'léto', podzim: 'podzim' };

export function currentCard(state) {
  const c0 = cardById(state.card) || INTRO;
  const c = { ...c0, who: whoOf(state, c0) };
  let text = fill(c.text, state.leader);
  // Rozzlobení a věrní lidé mluví jinak.
  const r = state.rel?.[c.who] ?? 0;
  if (!c.rel && c.who !== 'tajemnik' && !c.traitor) {
    const h = [...c.id].reduce((x, ch) => x + ch.charCodeAt(0), 0);
    if (r <= -REL_LOYAL) text = `${MOOD_BAD[h % MOOD_BAD.length]}: „${text}“`;
    else if (r >= REL_LOYAL) text = `${MOOD_GOOD[h % MOOD_GOOD.length]}: „${text}“`;
  }
  return { ...c, person: personOf(state, c0), text };
}

/** Které ukazatele ovlivní karta (kterákoli volba) – pro Proroka. */
export function touches(state, id) {
  const c = cardById(id);
  if (!c) return [];
  const out = new Set();
  for (const d of DIRS) for (const [k, v] of Object.entries(optionOf(state, c, d)?.e ?? {})) if (v) out.add(k);
  return METERS.map((m) => m.id).filter((k) => out.has(k));
}

function eligible(state, c) {
  if ((c.weight ?? 1) <= 0 || c.faction || c.queueOnly) return false;
  // Dějiny lidstva: karta dávné doby jen ve své době, karty budoucnosti až v budoucnosti.
  const age = state.age ?? 7;
  const timeless = c.season || c.traitor || c.who?.startsWith('@');
  if (c.age) { if (c.age !== age) return false; }
  else if (c.pastOnly) { if (age >= 7 || state.rival?.absorbed) return false; }
  else if (!timeless && age < 7) return false;
  if (c.season && seasonOf(state) !== c.season) return false;
  if (c.traitor === 'hunt' && !(state.traitor && !state.traitor.known)) return false;
  if (c.rivalMin != null && (state.rival?.power ?? 0) < c.rivalMin) return false;
  if (c.rivalMax != null && (state.rival?.power ?? 0) > c.rivalMax) return false;
  if (state.recent.includes(c.id)) return false;
  if (c.once && state.used.includes(c.id)) return false;
  if (c.req && !c.req.every((f) => state.flags.includes(f))) return false;
  if (c.not && c.not.some((f) => state.flags.includes(f))) return false;
  if (c.era && (state.era ?? 1) < c.era) return false;
  if (c.crisis && (state.crisis || (state.total ?? 0) < 10)) return false;
  if (c.seals && seals(state) < c.seals) return false;
  if (c.rel) {
    const [who, n] = c.rel, r = state.rel?.[who] ?? 0;
    if (n < 0 ? r > n : r < n) return false;
  }
  return true;
}

/** Nová karta na stůl (a rada rádce k ní). */
function draw(state) {
  state.card = pickCard(state);
  state.luck = state.leader.kind === 'hazard' ? 0.5 + Math.round(random(state) * (master(state) ? 7 : 10)) / 10 : 1;
  state.peek = peekCard(state);
  state.advice = state.leader.kind === 'rada' ? advise(state) : null;
}

/** Prorok: kdo přijde příště (pokračování příběhu, nebo předem vylosovaná karta). */
function peekCard(state) {
  const due = state.queue.find((q) => q.at <= state.total + 1);
  if (due) return due.id;
  const pool = CARDS.filter((c) => c.id !== state.card && eligible(state, c));
  if (!pool.length) return null;
  const seen = state.seen ?? {};
  const w = pool.map((c) => (c.weight ?? 1) * (c.req ? 2 : 1) * (c.rel ? 3 : 1) / (1 + 0.8 * (seen[c.id] ?? 0)));
  let r = random(state) * w.reduce((x, y) => x + y, 0);
  for (let i = 0; i < pool.length; i++) { r -= w[i]; if (r <= 0) return pool[i].id; }
  return pool[pool.length - 1].id;
}

/** Další karta: nejdřív pokračování příběhu, které je na řadě, jinak náhodná vhodná karta. */
export function pickCard(state) {
  const due = state.queue.findIndex((q) => q.at <= state.total);
  if (due >= 0) {
    const [q] = state.queue.splice(due, 1);
    const c = cardById(q.id);
    // Pokračování dává smysl jen tehdy, když jeho předpoklady pořád platí.
    // Pokračování z minulé doby po přelomu propadne.
    if (c && (!c.req || c.req.every((f) => state.flags.includes(f))) && (!c.age || c.age === (state.age ?? 7))) return c.id;
  }
  if (state.peek) {
    // Předpověď Proroka platí, pokud ji mezitím nezměnilo rozhodnutí.
    const p = cardById(state.peek);
    state.peek = null;
    if (p && eligible(state, p)) return p.id;
  }
  let pool = CARDS.filter((c) => eligible(state, c));
  if (pool.length === 0) {
    state.recent = state.recent.slice(-4);
    pool = CARDS.filter((c) => eligible(state, c));
  }
  // Méně viděné karty mají přednost (méně opakování); rozzlobení lidé chodí častěji.
  const seen = state.seen ?? {};
  const weights = pool.map((c) => (c.weight ?? 1) * (c.req ? 2 : 1) * (c.rel ? 3 : 1) / (1 + 0.8 * (seen[c.id] ?? 0))
    * ((state.rel?.[c.who] ?? 0) <= -REL_LOYAL ? 1.5 : 1) * (c.season ? 2.5 : 1) * (c.traitor ? 3 : 1));
  let r = random(state) * weights.reduce((a, b) => a + b, 0);
  for (let i = 0; i < pool.length; i++) {
    r -= weights[i];
    if (r <= 0) return pool[i].id;
  }
  return pool[pool.length - 1].id;
}

/** Splňuje vláda podmínku volby? */
export function unlocked(state, o) {
  if (!o?.need) return true;
  const v = state.meters[o.need.m];
  return (o.need.min == null || v >= o.need.min) && (o.need.max == null || v <= o.need.max);
}
/** Volba, která skutečně platí (podmíněná volba, nebo její náhrada). */
export function optionOf(state, card, dir) {
  const o = card.opts[dir];
  return unlocked(state, o) ? o : o.alt;
}

/** Které ukazatele volba změní (bez prozrazení směru) – pro tečky pod ukazateli. */
export function preview(card, dir, state) {
  const o = state ? optionOf(state, card, dir) : card.opts[dir];
  const out = {};
  for (const [k, v] of Object.entries(o?.e || {})) if (v) out[k] = Math.abs(effect(k, v) * intensity(state)) >= 15 ? 'big' : 'small';
  return out;
}

const clamp = (v) => Math.max(0, Math.min(100, v));

/** Jak se ukazatele po volbě změní (včetně schopnosti Krizového manažera) – bez změny stavu. */
export function outcome(state, dir) {
  const card = cardById(state.card) || INTRO;
  const out = { ...state.meters };
  const crisis = state.leader.kind === 'krize';
  let mult = intensity(state) * (state.leader.kind === 'byro' ? 0.75 : state.leader.kind === 'hazard' ? state.luck ?? 1 : 1);
  if (has(state, 'tlumic')) mult *= 0.8;
  if (state.mods?.includes('boure')) mult *= 1.25;
  if ((state.age ?? 7) < 7) mult *= PAST_SOFT;
  for (const [k, v] of Object.entries(optionOf(state, card, dir).e || {})) {
    const from = out[k];
    let d = effect(k, v);
    if (mult !== 1) d = Math.round(d * mult);
    if (has(state, 'brzda')) d = Math.max(-12, Math.min(12, d));
    if ((state.meta?.relics ?? []).some((r) => RELICS[r]?.m === k)) d = Math.round(d * 0.75);
    // Krok zpátky ke středu z krajnosti má dvojnásobnou sílu – ale za střed ho bonus nepřehoupne.
    if (crisis && d && Math.abs(from - START) > (master(state) ? 15 : EXTREME) && Math.sign(d) === Math.sign(START - from)) {
      const doubled = from + 2 * d;
      d = d > 0 ? Math.max(d, Math.min(doubled, START) - from) : Math.min(d, Math.max(doubled, START) - from);
    }
    // Trest za odpověď bez čtení: každá změna odtlačí ukazatel od rovnováhy.
    if (state.rush && d) d = Math.abs(d) * (from > START ? 1 : -1);
    out[k] = clamp(from + d);
  }
  return out;
}

/** Volby seřazené od nejlepší po nejhorší: žádná katastrofa a ukazatele co nejblíž středu. */
const balanceScore = (m) => {
  const vals = Object.values(m).map((v) => Math.abs(v - START));
  return (vals.some((v) => v >= 50) ? 1e6 : 0) + vals.reduce((a, v) => a + v * v, 0) + 2 * Math.max(...vals) ** 2;
};
export function rankDirs(state) {
  return DIRS.map((d) => [d, balanceScore(outcome(state, d))]).sort((a, b) => a[1] - b[1]).map(([d]) => d);
}
export const bestDir = (state) => rankDirs(state)[0];

/** Rada rádce: v 70 % nejlepší volba, jinak ta nejhorší. */
function advise(state) {
  const r = rankDirs(state);
  return random(state) < (master(state) ? 0.85 : ADVICE_OK) ? r[0] : r[r.length - 1];
}

/** Rada mudrce (vybavení z obchodu): napůl volba, která rovnováhu zlepší (ne nutně nejlepší), napůl cokoli. */
export function sageHint(state, rnd = Math.random) {
  if (rnd() >= 0.5) return DIRS[Math.floor(rnd() * DIRS.length)];
  const now = balanceScore(state.meters);
  const good = DIRS.filter((d) => balanceScore(outcome(state, d)) < now);
  const pool = good.length ? good : [bestDir(state)];
  return pool[Math.floor(rnd() * pool.length)];
}

/** Posun ukazatele (jednorázová pomůcka): o SHIFT tam, kam hráč chce – nikdy ne až na kraj. */
export const SHIFT = 15;
export function shiftMeter(state, id, sign) {
  if (state.dead || !(id in state.meters)) return false;
  const v = state.meters[id], to = Math.max(5, Math.min(95, v + Math.sign(sign) * SHIFT));
  if (to === v) return false;
  state.meters[id] = to;
  return true;
}

export const ready = (state) => (state.charge ?? 0) >= chargeOf(state);

/** Vyčkávač: odloží kartu. Měsíc uplyne, ukazatele se nehnou. */
export function skip(state) {
  if (state.leader.kind !== 'odklad' || !ready(state) || state.dead || state.card === INTRO.id) return false;
  state.charge = 0;
  return passCard(state);
}
/** Pomůcka z obchodu: přeskočí kartu bez ohledu na typ vůdce. */
export function skipCard(state) {
  if (state.dead || state.card === INTRO.id || state.card === 'dej_intro' || cardById(state.card)?.milestone) return false;
  return passCard(state);
}
function passCard(state) {
  const card = cardById(state.card);
  state.rush = false;
  if (card?.crisis) crisisStep(state, card, {}); // odložený krok krize se počítá jako nezvládnutý
  state.recent = [...state.recent, state.card].slice(-RECENT);
  state.turn += 1;
  state.total += 1;
  monthPasses(state);
  if (state.dead) return true;
  draw(state);
  return true;
}

/** Kormidelník: posune jeden ukazatel o 15 k rovnováze (nikdy přes střed). */
export function nudge(state, id) {
  if (state.leader.kind !== 'kormidlo' || !ready(state) || state.dead) return false;
  if (!steerMeter(state, id, master(state) ? 20 : NUDGE)) return false;
  state.charge = 0;
  return true;
}
/** Posune ukazatel o NUDGE k rovnováze (Kormidelník, nebo pomůcka z obchodu). */
export function steerMeter(state, id, by = NUDGE) {
  const v = state.meters[id];
  if (v === START || state.dead) return false;
  state.meters[id] = v < START ? Math.min(START, v + by) : Math.max(START, v - by);
  return true;
}

/** Reformátor: zavede, nebo zruší libovolný zákon. */
export function reformLaw(state, id) {
  if (state.leader.kind !== 'reform' || !ready(state) || state.dead || !LAWS[id] || !lawAllowed(state, id)) return false;
  const flag = `zakon_${id}`;
  if (state.flags.includes(flag)) {
    state.flags = state.flags.filter((f) => f !== flag);
    news(state, 'law', `Zákon „${LAWS[id].name}“ zrušen`);
  } else {
    state.flags.push(flag);
    news(state, 'law', `Zákon „${LAWS[id].name}“ platí`);
  }
  state.charge = 0;
  return true;
}

/** Výběr výhody z nabídky po splněném úkolu. */
export function choosePerk(state, id) {
  if (!state.perkOffer?.includes(id)) return false;
  (state.perks ??= []).push(id);
  state.perkOffer = null;
  if (id === 'nahled' && !state.peek) state.peek = peekCard(state);

  return true;
}

/** Rozhodnutí. Vrací konec vlády (nebo null). */
export function choose(state, dir) {
  if (state.dead) return state.dead;
  const card = cardById(state.card) || INTRO;
  if (!card.opts[dir]) throw new Error(`neznámý směr ${dir}`);
  const o = optionOf(state, card, dir);
  const before = state.meters;
  state.meters = outcome(state, dir);
  state.rush = false;
  factionMood(state, before, o);
  for (const l of o.later ?? []) if (random(state) < (l.p ?? 1)) (state.later ??= []).push({ at: state.total + 1 + (l.in ?? 2), e: l.e, text: l.text });
  if (o.project && PROJECTS[o.project] && !state.project) {
    state.project = { id: o.project, left: PROJECT_MONTHS };
    news(state, 'law', `Začala stavba: ${PROJECTS[o.project].name}. Hotovo za ${PROJECT_MONTHS} měsíců.`);
  }
  state.charge = Math.min(chargeOf(state), (state.charge ?? 0) + (has(state, 'nabiti') ? 2 : 1));
  if (o.set && !state.flags.includes(o.set)) state.flags.push(o.set);
  if (o.unset) state.flags = state.flags.filter((f) => f !== o.unset);
  if (o.law && !state.flags.includes(`zakon_${o.law}`)) {
    state.flags.push(`zakon_${o.law}`);
    news(state, 'law', `Zákon „${LAWS[o.law].name}“ platí`);
  }
  if (o.repeal) {
    state.flags = state.flags.filter((f) => f !== `zakon_${o.repeal}`);
    news(state, 'law', `Zákon „${LAWS[o.repeal].name}“ zrušen`);
  }
  if (o.next) state.queue.push({ id: o.next, at: state.total + 1 + (o.in ?? 3) });
  if (card.milestone) {
    if (o.advance) advanceAge(state);
    else state.queue.push({ id: card.id, at: state.total + 9 }); // objev se vrátí později
  }
  relate(state, { ...card, who: whoOf(state, card) }, o);
  if (card.crisis) crisisStep(state, card, o);
  if (o.wonder && WONDER_BY_ID[o.wonder] && !state.wonders.includes(o.wonder)) {
    const w = WONDER_BY_ID[o.wonder];
    state.wonders.push(o.wonder);
    if (!state.flags.includes(`div_${o.wonder}`)) state.flags.push(`div_${o.wonder}`);
    news(state, 'wonder', `Div světa dokončen: ${w.name}! Navždy bude držet ${METERS.find((m) => m.id === w.m).name} v rovnováze.`);
  }
  if (o.power) state.rival.power = Math.max(0, Math.min(100, state.rival.power + o.power));
  if (o.war) war(state);
  if (o.absorb) {
    state.rival.absorbed = true;
    news(state, 'rival', 'Sousední říše se spojila s tvou. Hranice zmizely a země je větší než kdy dřív.');
  }
  if (o.expose && state.traitor) {
    state.traitor.known = true;
    news(state, 'traitor', `Zrádce odhalen: ${PEOPLE[state.traitor.who]?.name ?? state.traitor.who}!`);
    state.queue.unshift({ id: 'zrada_trest', at: state.total + 1 });
  }
  if (card.traitor === 'punish' && state.traitor) {
    state.rel[state.traitor.who] = -REL_MAX;
    state.traitor = null;
  }
  if (card.once && !state.used.includes(card.id)) state.used.push(card.id);
  (state.seen ??= {})[card.id] = (state.seen[card.id] ?? 0) + 1;
  state.recent = [...state.recent, card.id].slice(-RECENT);
  state.total += 1;
  if (o.end) return endReign(state, { special: o.end, ...SPECIAL[o.end] }, `x.${o.end}`);
  if (card.id !== INTRO.id && card.id !== 'dej_intro') {
    state.turn += 1;
    monthPasses(state);
    if (state.dead) return state.dead;
  }
  draw(state);
  return null;
}

function news(state, kind, text) { (state.news ??= []).push({ kind, text }); }

/** Válka se sousední říší: rozhoduje Síla proti síle soupeře (a trocha štěstí). */
function war(state) {
  const r = state.rival;
  const won = state.meters.sil + random(state) * 40 > r.power + 20;
  const apply = (e) => { for (const [k, v] of Object.entries(e)) state.meters[k] = clamp(state.meters[k] + effect(k, v)); };
  if (won) {
    apply({ fin: 10, lid: 5, sil: -5 });
    r.power = Math.max(0, r.power - 25);
    news(state, 'war', 'Válka vyhrána! Soused je oslaben a lid slaví.');
  } else {
    apply({ fin: -10, lid: -10, sil: -10 });
    r.power = Math.min(100, r.power + 10);
    news(state, 'warLost', 'Válka prohrána. Soused zesílil a země truchlí.');
  }
  state.rel.riv = Math.max(-REL_MAX, (state.rel.riv ?? 0) - 2);
}

/** Lidé si pamatují: komu volba pomohla, toho si naklonila. */
function relate(state, card, o) {
  state.rel ??= {};
  const k = state.leader.kind === 'charisma' ? 2 : 1;
  const add = (who, n) => {
    const m = n * (n < 0 && master(state) ? 1 : k) * (n > 0 && has(state, 'sarm') ? 2 : 1);
    const before = state.rel[who] ?? 0;
    state.rel[who] = Math.max(-REL_MAX, Math.min(REL_MAX, before + m));
    const name = PEOPLE[who]?.name ?? who;
    if (before > -REL_LOYAL && state.rel[who] <= -REL_LOYAL) news(state, 'enemy', `${name}: teď je to tvůj nepřítel. Však on si to vybere.`);
    if (before < REL_LOYAL && state.rel[who] >= REL_LOYAL) news(state, 'friend', `${name}: teď stojí věrně při tobě.`);
  };
  const cares = CARES[card.who];
  const raw = cares ? (o.e?.[cares] ?? 0) : 0;
  if (raw && !o.rel?.[card.who]) add(card.who, Math.sign(raw));
  for (const [who, n] of Object.entries(o.rel || {})) add(who, n);
}

export const activeLaws = (state) => state.flags.filter((f) => f.startsWith('zakon_')).map((f) => f.slice(6)).filter((id) => LAWS[id]);
export const seals = (state) => (state.tasksDone ?? []).length + (state.bonusSeals ?? 0);

/** Víceměsíční krize: každý krok se počítá, na konci odměna, nebo trest. */
function crisisStep(state, card, o) {
  const cr = CRISES[card.crisis];
  if (!state.crisis || state.crisis.id !== card.crisis) state.crisis = { id: card.crisis, step: 0, score: 0 };
  state.crisis.step += 1;
  if (o.ok) state.crisis.score += 1;
  if (state.crisis.step < cr.steps.length) {
    state.queue.push({ id: cr.steps[state.crisis.step], at: state.total + 2 });
    return;
  }
  const won = state.crisis.score >= cr.good;
  const r = won ? cr.win : cr.lose;
  for (const [k, v] of Object.entries(r.e)) state.meters[k] = clamp(state.meters[k] + effect(k, v));
  if (won) state.tally.crises += 1;
  news(state, won ? 'crisis' : 'crisisLost', `${cr.name}: ${fill(r.text, state.leader)}`);
  state.crisis = null;
}

/** Do voleb zbývá (měsíců). */
export const toElection = (state) => TERM - (state.turn % TERM);
/** Hněv frakcí: pokles jejich ukazatele je zlobí, vzestup uklidňuje. Při hněvu FACTION_REVOLT přijde vzpoura. */
function factionMood(state, before, o) {
  state.fac ??= { kneze: 0, kupci: 0, vojsko: 0, ucenci: 0 };
  for (const [f, { m }] of Object.entries(FACTIONS)) {
    const d = state.meters[m] - before[m];
    let a = state.fac[f] ?? 0;
    if (d < 0) a += -d / 8; else if (d > 0) a -= d / 16;
    state.fac[f] = Math.max(0, Math.min(FACTION_MAX, Math.round(a * 10) / 10));
  }
  if (o.calm && o.calm in state.fac) state.fac[o.calm] = 0;
  const angry = Object.keys(FACTIONS).find((f) => state.fac[f] >= FACTION_REVOLT);
  if (angry && !state.queue.some((q) => q.id.startsWith('vzp_')) && !String(state.card).startsWith('vzp_')) {
    state.queue.push({ id: `vzp_${angry}_1`, at: state.total + 2 });
    state.fac[angry] = FACTION_REVOLT - 2;
    news(state, 'enemy', `${FACTIONS[angry].name} se bouří – brzy přijdou s požadavky.`);
  }
}

export const support = (state) => Math.round((state.meters.lid + state.meters.dip) / 2) + 4 * treeOf(state, 'slechta') + (relic(state, 'koruna') ? 5 : 0);

/** Uplynul měsíc: zákony, konec vlády, úkol, éra. */
function monthPasses(state) {
  state.drift ??= {};
  const lawPower = state.leader.kind === 'byro' ? (master(state) ? 3 : 2) : 1;
  for (const id of activeLaws(state)) for (const [k, v] of Object.entries(LAWS[id].per)) state.drift[k] = (state.drift[k] ?? 0) + v * lawPower;
  if (has(state, 'stabilita') && state.turn % 12 === 0) {
    for (const m of METERS) { const v = state.meters[m.id]; state.meters[m.id] = v < START ? Math.min(START, v + 3) : Math.max(START, v - 3); }
  }
  const add = (k, v) => { state.drift[k] = (state.drift[k] ?? 0) + v; };
  const season = seasonOf(state);
  if (season === 'zima') add('fin', -0.3);
  if (season === 'podzim') add('fin', 0.3);
  if (state.mods?.includes('hlad')) add('fin', -0.4);
  if (state.mods?.includes('sousede')) add('dip', -0.3);
  // Divy světa a dokončené projekty drží svůj ukazatel u rovnováhy.
  for (const m of [...(state.wonders ?? []).map((id) => WONDER_BY_ID[id]?.m), ...(state.built ?? []).map((id) => PROJECTS[id]?.m)]) {
    const v = state.meters[m];
    if (m && v !== START) add(m, v < START ? 0.5 : -0.5);
  }
  // Rozestavěný projekt stojí každý měsíc zásoby.
  if (state.project) {
    add('fin', -0.5);
    state.project.left -= 1;
    if (state.project.left <= 0) {
      const p = PROJECTS[state.project.id];
      (state.built ??= []).push(state.project.id);
      news(state, 'wonder', `Stavba dokončena: ${p.name}! Navždy bude držet ${METERS.find((m) => m.id === p.m).name} v rovnováze.`);
      state.project = null;
    }
  }
  // Odložené důsledky dřívějších rozhodnutí.
  for (const l of (state.later ?? []).filter((x) => x.at <= state.total)) {
    for (const [k, v] of Object.entries(l.e ?? {})) state.meters[k] = clamp(state.meters[k] + effect(k, v));
    news(state, 'echo', l.text);
    (state.echoes ??= []).push({ text: l.text, at: state.total });
    state.echoes = state.echoes.slice(-20);
  }
  state.later = (state.later ?? []).filter((x) => x.at > state.total);
  for (const [k, v] of Object.entries(state.drift)) {
    const whole = Math.trunc(v);
    if (whole) { state.meters[k] = clamp(state.meters[k] + whole); state.drift[k] = v - whole; }
  }
  let hit = METERS.find((m) => state.meters[m.id] <= 0 || state.meters[m.id] >= 100);
  const mirror = relic(state, 'zrcadlo') && !state.mirror;
  if (hit && ((state.leader.kind === 'zachrance' && !state.rescued) || has(state, 'sance') || mirror)) {
    // Záchrana: ukazatel se odrazí od kraje. Typ Zachránce jednou za vládu (mistr dvakrát), výhoda Druhá šance jednou,
    // relikvie Zrcadlo osudu jednou za hru.
    if (has(state, 'sance')) state.perks = state.perks.filter((p) => p !== 'sance');
    else if (state.leader.kind === 'zachrance' && !state.rescued) { state.zUsed = (state.zUsed ?? 0) + 1; state.rescued = state.zUsed >= (master(state) ? 2 : 1); }
    else state.mirror = true;
    state.meters[hit.id] = state.meters[hit.id] <= 0 ? RESCUE : 100 - RESCUE;
    news(state, 'rescue', `Na poslední chvíli: ${hit.name} se vrací na ${state.meters[hit.id]} %`);
    hit = METERS.find((m) => state.meters[m.id] <= 0 || state.meters[m.id] >= 100);
  }
  if (hit) {
    const side = state.meters[hit.id] <= 0 ? 'low' : 'high';
    const ends = (state.age ?? 7) < 7 ? ENDINGS_PAST : ENDINGS;
    endReign(state, { meter: hit.id, side, ...ends[hit.id][side] }, `${hit.id}.${side}`);
    return;
  }
  if (!hasElections(state)) { /* v dávných dobách se nevolí */ } else if (state.turn > 0 && state.turn % TERM === 0) {
    const v = support(state);
    if (v < VOTE_MIN) { endReign(state, { election: true, ...ELECTION, text: ELECTION.text.replace('{v}', v) }, 'volby'); return; }
    state.tally.elections += 1;
    news(state, 'election', `Vyhrál${state.leader.female ? 'a' : ''} jsi volby s ${v} % hlasů`);
  } else if (state.turn % TERM === TERM - 6) {
    news(state, 'electionSoon', `Za půl roku jsou volby. Hlasy ti dají Lid a Spojenci (teď ${support(state)} %, potřebuješ ${VOTE_MIN} %).`);
  }
  progressTask(state);
  worldEvents(state);
  const age = state.age ?? 7;
  if (age < 7) {
    // Přelom: po čase v dané době přijde objev, který může svět posunout dál.
    const id = `prelom${age}`;
    if (state.total - (state.ageStart ?? 0) >= AGE_LEN && state.card !== id && !state.queue.some((q) => q.id === id)) state.queue.push({ id, at: state.total });
    return;
  }
  const since = state.total - (state.futureAt ?? 0);
  const era = ERAS.filter((e) => since >= (e.total ?? 0) && seals(state) >= (e.seals ?? 0)).pop().n;
  if (era > (state.era ?? 1)) {
    state.era = era;
    state.queue.unshift({ id: `era${era}`, at: state.total });
    news(state, 'era', `Začíná éra: ${ERAS[era - 1].name}`);
  }
}

/** Svět žije: soused sílí, zrádci se objevují, dlouhé krajnosti mají následky. */
function worldEvents(state) {
  const age = state.age ?? 7;
  state.rival ??= { power: 30, absorbed: false };
  if (age < 7 && !state.rival.absorbed) state.rival.power = Math.min(100, state.rival.power + (state.mods?.includes('sousede') ? 0.6 : 0.3));
  // Zrádce
  if (!state.traitor && state.turn >= 8 && random(state) < (state.mods?.includes('zradci') ? 0.06 : 0.02)) {
    const people = [...new Set(Object.keys(state.seen ?? {}).map((id) => cardById(id)).filter((c) => c && !c.who.startsWith('@') && !['tajemnik', 'riv'].includes(c.who)
      && (c.age ? c.age === age : age === 7)).map((c) => c.who))];
    if (people.length) {
      const who = people[Math.floor(random(state) * people.length)];
      state.traitor = { who, since: state.total, known: false };
      news(state, 'traitorHint', 'Šíří se šeptanda: někdo z tvých blízkých vynáší tajemství. Kdo to jen může být?');
    }
  } else if (state.traitor && !state.traitor.known && state.total - state.traitor.since >= 20) {
    const name = PEOPLE[state.traitor.who]?.name ?? state.traitor.who;
    for (const [k, v] of Object.entries({ fin: -10, sil: -10 })) state.meters[k] = clamp(state.meters[k] + effect(k, v));
    state.rel[state.traitor.who] = -REL_MAX;
    news(state, 'traitorStrike', `Zrada! ${name} prodává tvá tajemství cizím a mizí. Pokladna i stráže to pocítí.`);
    state.traitor = null;
  }
  // Dlouhé krajnosti a zlatý věk
  state.ext ??= {};
  let calm = true;
  for (const m of METERS) {
    const v = state.meters[m.id], e = (state.ext[m.id] ??= { low: 0, high: 0 });
    e.low = v <= 20 ? e.low + 1 : 0;
    e.high = v >= 80 ? e.high + 1 : 0;
    if (v < 35 || v > 65) calm = false;
    for (const side of ['low', 'high']) {
      const id = `stav_${m.id}_${side}`;
      if (e[side] === 4 && cardById(id) && !state.queue.some((q) => q.id === id)) state.queue.push({ id, at: state.total });
    }
  }
  state.ext.calm = calm ? (state.ext.calm ?? 0) + 1 : 0;
  if (state.ext.calm === 6 && !state.queue.some((q) => q.id === 'zlaty_vek')) state.queue.push({ id: 'zlaty_vek', at: state.total });
}

/** Skóre vlády: měsíce × bonus za ztížení. */
export const modBonus = (state) => 1 + (state.mods ?? []).reduce((a, m) => a + (MODS[m]?.bonus ?? 0), 0);

/** Ve které době se volí: v moderní době a později (a vždy v hlavní hře). */
export const hasElections = (state) => (state.age ?? 7) >= 5;
export const ageOf = (state) => AGES[(state.age ?? 7) - 1];
export const leaderTitle = (state) => ageOf(state).title[state.leader.female ? 1 : 0];
/** Zákony dávají smysl až od starověku; moderní zákony až v pozdějších dobách. */
export const lawAllowed = (state, id) => (state.age ?? 7) >= (LAWS[id]?.age ?? 5);

/** Svět se posune do další doby (Dějiny lidstva). */
function advanceAge(state) {
  if ((state.age ?? 7) >= 7) return;
  state.age += 1;
  state.ageStart = state.total;
  state.leader.age = state.age;
  state.queue = state.queue.filter((q) => !q.id.startsWith('prelom'));
  state.rival = { power: 30, absorbed: false }; // nová doba = nový soused
  if (state.rel) state.rel.riv = 0;
  if (state.traitor && !state.traitor.known) state.traitor = null;
  if (state.age === 7) {
    state.futureAt = state.total;
    state.era = 1;
  }
  news(state, 'age', `Nová doba: ${AGES[state.age - 1].name}`);
}

function endReign(state, e, key) {
  state.dead = { meter: e.meter ?? null, side: e.side ?? null, special: e.special ?? null, election: !!e.election, title: e.title, text: fill(e.text, state.leader), months: state.turn };
  const score = Math.round(state.turn * modBonus(state));
  state.dead.score = score;
  state.history.push({ name: state.leader.name, female: state.leader.female, n: state.leader.n, months: state.turn, score, ending: key, title: e.title, kind: state.leader.kind });
  if (!state.endings.includes(key)) state.endings.push(key);
  state.best = Math.max(state.best, state.turn);
  return state.dead;
}

// ── Úkoly vůdců ──────────────────────────────────────
export const taskById = (id) => TASKS.find((t) => t.id === id);

function assignTask(state) {
  const done = new Set(state.tasksDone ?? []);
  const past = (state.age ?? 7) < 7;
  const fits = (t) => t.id !== state.task?.id && (state.era ?? 1) >= (t.era ?? 1) && !(t.type === 'flag' && state.flags.includes(t.flag))
    && !(past && ['flag', 'rel', 'laws'].includes(t.type));
  let pool = TASKS.filter((t) => fits(t) && !done.has(t.id));
  if (!pool.length) pool = TASKS.filter(fits);
  const t = pool[Math.floor(random(state) * pool.length)];
  state.task = { id: t.id, streak: 0 };
}

/** Jak je úkol daleko: {now, of} pro ukazatel postupu. */
export function taskProgress(state) {
  const t = taskById(state.task?.id);
  if (!t) return null;
  const st = state.task;
  switch (t.type) {
    case 'months': return { now: Math.min(state.turn, t.n), of: t.n };
    case 'calm': case 'hold': return { now: Math.min(st.streak, t.n), of: t.n };
    case 'laws': return { now: Math.min(activeLaws(state).length, t.n), of: t.n };
    case 'rel': return { now: Math.max(0, Math.min(state.rel?.[t.who] ?? 0, t.n)), of: t.n };
    case 'friends': return { now: Math.min(Object.values(state.rel ?? {}).filter((r) => r >= REL_LOYAL).length, t.n), of: t.n };
    case 'reach': return { now: Math.min(state.meters[t.m], t.min), of: t.min };
    case 'flag': return { now: state.flags.includes(t.flag) ? 1 : 0, of: 1 };
  }
  return null;
}

function progressTask(state) {
  if (!state.task) return;
  const t = taskById(state.task.id);
  if (t.type === 'calm') state.task.streak = Object.values(state.meters).every((v) => v >= 30 && v <= 70) ? state.task.streak + 1 : 0;
  if (t.type === 'hold') state.task.streak = state.meters[t.m] >= t.min ? state.task.streak + 1 : 0;
  const p = taskProgress(state);
  if (p.now < p.of) return;
  if (!state.tasksDone.includes(t.id)) state.tasksDone.push(t.id);
  if (state.leader.kind === 'hazard') state.bonusSeals = (state.bonusSeals ?? 0) + 1;
  state.charge = CHARGE; // odměna: schopnost se hned nabije
  state.perkOffer = offerPerks(state);
  news(state, 'task', `Úkol splněn: ${t.text}`);
  assignTask(state);
  news(state, 'newtask', `Nový úkol: ${taskById(state.task.id).text}`);
}

/** Tři náhodné výhody, které vůdce ještě nemá a které mu k něčemu jsou. */
export function offerPerks(state) {
  const k = state.leader.kind;
  const useless = { smer: k === 'vize', nahled: k === 'prorok', sance: k === 'zachrance' && !state.rescued, sarm: k === 'charisma', nabiti: !ACTIVE.includes(k) };
  const pool = Object.keys(PERKS).filter((p) => !has(state, p) && !useless[p]);
  const out = [];
  while (out.length < 3 && pool.length) out.push(pool.splice(Math.floor(random(state) * pool.length), 1)[0]);
  return out.length ? out : null;
}

/** Nástupce: nový vůdce, ukazatele zpět doprostřed. Svět (příznaky) zůstává. */
export function nextLeader(state, kind = state.leader.kind, lvl = 1) {
  // Dědictví: kdo vládl aspoň 3 roky, předá nástupci jednu výhodu a věrné lidi.
  const legacy = state.turn >= 36;
  const keepPerk = legacy ? (state.perks ?? []).find((p) => p !== 'sance') : null;
  const female = random(state) < 0.5;
  const pool = (state.age ?? 7) < 7 ? AGE_NAMES[state.age] : SUCCESSORS;
  const names = female ? pool.f : pool.m;
  const used = new Set(state.history.map((h) => h.name));
  const free = names.filter((n) => !used.has(n));
  const list = free.length ? free : names;
  const name = list[Math.floor(random(state) * list.length)];
  state.leader = { name, female, n: state.leader.n + 1, kind, age: state.age ?? 7, lvl };
  state.charge = 0;
  state.drift = {};
  state.perks = keepPerk ? [keepPerk] : [];
  state.perkOffer = null;
  state.rescued = false;
  state.zUsed = 0;
  state.crisis = null;
  state.peek = null;
  // Nový vůdce = nová šance: vztahy vychladnou na polovinu (po dlouhé vládě zůstanou věrní věrnými).
  for (const k of Object.keys(state.rel ?? {})) if (!(legacy && state.rel[k] >= REL_LOYAL)) state.rel[k] = Math.trunc(state.rel[k] / 2) || 0;
  if (legacy) news(state, 'friend', `Dědictví: ${keepPerk ? `výhoda ${PERKS[keepPerk].name} a ` : ''}věrní lidé zůstávají i novému vůdci.`);
  state.meters = freshMeters();
  state.queue = state.queue.filter((q) => q.id.startsWith('era') || q.id.startsWith('prelom')); // nová éra ani přelom nezapadne
  if (!state.project) state.queue.push({ id: PROJECT_CARDS[Math.floor(random(state) * PROJECT_CARDS.length)].id, at: state.total + 4 });
  state.turn = 0;
  state.dead = null;
  assignTask(state);
  draw(state);
}

/** Bleskovka: hra na čas bez úvodu. Čas hlídá zobrazení (BLITZ_START, +BLITZ_BONUS za rozhodnutí). */
export const BLITZ_START = 180;
export const BLITZ_BONUS = 5;
export const BLITZ_FALL = 15; // pád vlády stojí sekundy
export function newBlitz(opts, seed) { return newRun(opts, seed, 'blitz'); }
/** Hra bez úvodu v jiném režimu (bleskovka, denní výzva). */
export function newRun(opts, seed, mode) {
  const s = newGame(opts, seed);
  s.mode = mode;
  s.decisions = 0;
  draw(s);
  return s;
}

/** Denní výzva: stejné semínko a typ vůdce pro všechny v daný den. */
export function daily(dateKey) {
  let h = 2166136261;
  for (const ch of dateKey) h = Math.imul(h ^ ch.charCodeAt(0), 16777619) >>> 0;
  return { seed: h >>> 0 || 1, kind: KINDS[h % KINDS.length].id };
}

/** „2 roky a 3 měsíce“ */
export function tenure(months) {
  const y = Math.floor(months / 12), m = months % 12;
  const ys = y === 0 ? '' : y === 1 ? '1 rok' : y < 5 ? `${y} roky` : `${y} let`;
  const ms = m === 0 ? '' : m === 1 ? '1 měsíc' : m < 5 ? `${m} měsíce` : `${m} měsíců`;
  if (!ys && !ms) return 'necelý měsíc';
  return [ys, ms].filter(Boolean).join(' a ');
}

export function timeLabel(state) {
  return `Rok ${Math.floor(state.turn / 12) + 1} · měsíc ${(state.turn % 12) + 1}`;
}

/** Jak blízko je ukazatel katastrofě (0 = ideál uprostřed, 1 = na kraji). */
export function danger(v) { return Math.abs(v - 50) / 50; }

/** Starší uložené hry doplní o nové části stavu. */
export function upgrade(state) {
  state.leader.kind ??= 'vize';
  state.charge ??= 0;
  state.rel ??= {};
  state.drift ??= {};
  state.tasksDone ??= [];
  state.era ??= 1;
  state.news ??= [];
  state.perks ??= [];
  state.perkOffer ??= null;
  state.bonusSeals ??= 0;
  state.crisis ??= null;
  state.tally ??= { elections: 0, crises: 0 };
  state.luck ??= 1;
  state.seen ??= {};
  state.world ??= state.mode === 'dejiny' ? 'dejiny' : '2089';
  state.mods ??= [];
  state.rival ??= { power: 30, absorbed: false };
  state.traitor ??= null;
  state.ext ??= {};
  state.wonders ??= [];
  state.mode ??= 'normal';
  state.age ??= 7;
  state.ageStart ??= 0;
  if (state.futureAt === undefined) state.futureAt = 0;
  state.leader.age ??= state.age;
  if (!state.task && !state.dead) assignTask(state);
  return state;
}

export { WONDERS, METERS, ENDINGS, PEOPLE, CARDS, INTRO, LAWS, TASKS, ERAS, SPECIAL, REL_LOYAL, PERKS, CRISES, ELECTION, AGES, AGE_LEN, ENDINGS_PAST };
