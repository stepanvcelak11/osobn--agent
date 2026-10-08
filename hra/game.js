// Herní logika Rovnováhy – bez DOMu, aby šla testovat v Node.
import { METERS, CARDS as BASE, INTRO, ENDINGS, SUCCESSORS, PEOPLE } from './cards.js';
import { EXTRA, LAWS, TASKS, ERAS, SPECIAL, CARES, REL_MAX, REL_LOYAL, PERKS, CRISES, ELECTION } from './world.js';

const CARDS = [...BASE, ...EXTRA];

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
  { id: 'rada', short: 'Rádce', m: 'Prezident s rádcem', f: 'Prezidentka s rádcem', icon: '🦉', text: 'Rádce mu ke každé kartě poradí. V 7 případech z 10 radí to nejlepší, jinak se mýlí.' },
  { id: 'zachrance', short: 'Zachránce', m: 'Zachránce', f: 'Zachránkyně', icon: '🛟', text: 'Jednou za vládu ho ukazatel na nule ani na maximu nesesadí – odrazí se zpátky na 15, nebo 85 %.' },
  { id: 'charisma', short: 'Charismatik', m: 'Charismatik', f: 'Charismatička', icon: '⭐', text: 'Vztahy s lidmi se mu mění dvakrát rychleji. Věrné spojence získá snadno – nepřátele taky.' },
  { id: 'prorok', short: 'Prorok', m: 'Prorok', f: 'Prorokyně', icon: '🔮', text: 'Vidí, kdo za ním přijde příště, a může se na to připravit.' },
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
export const RESCUE = 15;    // Zachránce / Druhá šance: kam se ukazatel odrazí od kraje
export const TERM = 48;      // volby každé 4 roky
export const VOTE_MIN = 40;  // potřebná podpora (průměr Lidu a Spojenců)
export const kindOf = (state) => KINDS.find((k) => k.id === state.leader.kind) || KINDS[0];
export const has = (state, perk) => (state.perks ?? []).includes(perk);
/** Vidí vůdce směr změn / další kartu? (typ, nebo výhoda) */
export const seesDirection = (state) => state.leader.kind === 'vize' || has(state, 'smer');
export const seesAhead = (state) => state.leader.kind === 'prorok' || has(state, 'nahled');

// Deterministický generátor (mulberry32) – stav se ukládá, takže hra jde přesně obnovit.
export function random(state) {
  let t = (state.seed = (state.seed + 0x6d2b79f5) >>> 0);
  t = Math.imul(t ^ (t >>> 15), t | 1);
  t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
}

function freshMeters() { return Object.fromEntries(METERS.map((m) => [m.id, START])); }

export function newGame({ name = '', female = false, kind = 'vize' } = {}, seed = Date.now() >>> 0) {
  const leaderName = name.trim().slice(0, 30) || (female ? 'Jana Nová' : 'Jan Nový');
  const s = {
    v: 1,
    seed: seed >>> 0 || 1,
    leader: { name: leaderName, female: !!female, n: 1, kind },
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
    mode: 'normal',
    meters: freshMeters(),
    flags: [],
    queue: [],
    recent: [],
    used: [],
    turn: 0, // měsíce vlády současného vůdce
    total: 0, // karty za celou hru
    card: INTRO.id,
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
  return text
    .replaceAll('{osl}', f ? 'paní prezidentko' : 'pane prezidente')
    .replaceAll('{a}', f ? 'a' : '')
    .replaceAll('{ty}', leader.name);
}

export function currentCard(state) {
  const c = cardById(state.card) || INTRO;
  return { ...c, person: PEOPLE[c.who], text: fill(c.text, state.leader) };
}

function eligible(state, c) {
  if ((c.weight ?? 1) <= 0) return false;
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
  state.luck = state.leader.kind === 'hazard' ? 0.5 + Math.round(random(state) * 10) / 10 : 1;
  state.peek = seesAhead(state) ? peekCard(state) : null;
  state.advice = state.leader.kind === 'rada' ? advise(state) : null;
}

/** Prorok: kdo přijde příště (pokračování příběhu, nebo předem vylosovaná karta). */
function peekCard(state) {
  const due = state.queue.find((q) => q.at <= state.total + 1);
  if (due) return due.id;
  const pool = CARDS.filter((c) => c.id !== state.card && eligible(state, c));
  if (!pool.length) return null;
  return pool[Math.floor(random(state) * pool.length)].id;
}

/** Další karta: nejdřív pokračování příběhu, které je na řadě, jinak náhodná vhodná karta. */
export function pickCard(state) {
  const due = state.queue.findIndex((q) => q.at <= state.total);
  if (due >= 0) {
    const [q] = state.queue.splice(due, 1);
    const c = cardById(q.id);
    // Pokračování dává smysl jen tehdy, když jeho předpoklady pořád platí.
    if (c && (!c.req || c.req.every((f) => state.flags.includes(f)))) return c.id;
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
  const weights = pool.map((c) => (c.weight ?? 1) * (c.req ? 2 : 1) * (c.rel ? 3 : 1));
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
  for (const [k, v] of Object.entries(o?.e || {})) if (v) out[k] = Math.abs(effect(k, v)) >= 12 ? 'big' : 'small';
  return out;
}

const clamp = (v) => Math.max(0, Math.min(100, v));

/** Jak se ukazatele po volbě změní (včetně schopnosti Krizového manažera) – bez změny stavu. */
export function outcome(state, dir) {
  const card = cardById(state.card) || INTRO;
  const out = { ...state.meters };
  const crisis = state.leader.kind === 'krize';
  let mult = state.leader.kind === 'byro' ? 0.75 : state.leader.kind === 'hazard' ? state.luck ?? 1 : 1;
  if (has(state, 'tlumic')) mult *= 0.8;
  for (const [k, v] of Object.entries(optionOf(state, card, dir).e || {})) {
    const from = out[k];
    let d = effect(k, v);
    if (mult !== 1) d = Math.round(d * mult);
    if (has(state, 'brzda')) d = Math.max(-12, Math.min(12, d));
    // Krok zpátky ke středu z krajnosti má dvojnásobnou sílu – ale za střed ho bonus nepřehoupne.
    if (crisis && d && Math.abs(from - START) > EXTREME && Math.sign(d) === Math.sign(START - from)) {
      const doubled = from + 2 * d;
      d = d > 0 ? Math.max(d, Math.min(doubled, START) - from) : Math.min(d, Math.max(doubled, START) - from);
    }
    out[k] = clamp(from + d);
  }
  return out;
}

/** Nejlepší volba pro tuto chvíli: žádná katastrofa a ukazatele co nejblíž středu. */
export function bestDir(state) {
  let best = DIRS[0], bestScore = Infinity;
  for (const d of DIRS) {
    const m = outcome(state, d);
    const vals = Object.values(m).map((v) => Math.abs(v - START));
    const score = (vals.some((v) => v >= 50) ? 1e6 : 0) + vals.reduce((a, v) => a + v * v, 0) + 2 * Math.max(...vals) ** 2;
    if (score < bestScore) { bestScore = score; best = d; }
  }
  return best;
}

/** Rada rádce: v 70 % nejlepší volba, jinak jiná. */
function advise(state) {
  const best = bestDir(state);
  if (random(state) < ADVICE_OK) return best;
  const others = DIRS.filter((d) => d !== best);
  return others[Math.floor(random(state) * others.length)];
}

export const ready = (state) => (state.charge ?? 0) >= CHARGE;

/** Vyčkávač: odloží kartu. Měsíc uplyne, ukazatele se nehnou. */
export function skip(state) {
  if (state.leader.kind !== 'odklad' || !ready(state) || state.dead || state.card === INTRO.id) return false;
  state.charge = 0;
  const card = cardById(state.card);
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
  const v = state.meters[id];
  if (v === START) return false;
  state.meters[id] = v < START ? Math.min(START, v + NUDGE) : Math.max(START, v - NUDGE);
  state.charge = 0;
  return true;
}

/** Reformátor: zavede, nebo zruší libovolný zákon. */
export function reformLaw(state, id) {
  if (state.leader.kind !== 'reform' || !ready(state) || state.dead || !LAWS[id]) return false;
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
  state.meters = outcome(state, dir);
  state.charge = Math.min(CHARGE, (state.charge ?? 0) + (has(state, 'nabiti') ? 2 : 1));
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
  relate(state, card, o);
  if (card.crisis) crisisStep(state, card, o);
  if (card.once && !state.used.includes(card.id)) state.used.push(card.id);
  state.recent = [...state.recent, card.id].slice(-RECENT);
  state.total += 1;
  if (o.end) return endReign(state, { special: o.end, ...SPECIAL[o.end] }, `x.${o.end}`);
  if (card.id !== INTRO.id) {
    state.turn += 1;
    monthPasses(state);
    if (state.dead) return state.dead;
  }
  draw(state);
  return null;
}

function news(state, kind, text) { (state.news ??= []).push({ kind, text }); }

/** Lidé si pamatují: komu volba pomohla, toho si naklonila. */
function relate(state, card, o) {
  state.rel ??= {};
  const k = state.leader.kind === 'charisma' ? 2 : 1;
  const add = (who, n) => {
    const m = n * k * (n > 0 && has(state, 'sarm') ? 2 : 1);
    state.rel[who] = Math.max(-REL_MAX, Math.min(REL_MAX, (state.rel[who] ?? 0) + m));
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
export const support = (state) => Math.round((state.meters.lid + state.meters.dip) / 2);

/** Uplynul měsíc: zákony, konec vlády, úkol, éra. */
function monthPasses(state) {
  state.drift ??= {};
  const lawPower = state.leader.kind === 'byro' ? 2 : 1;
  for (const id of activeLaws(state)) for (const [k, v] of Object.entries(LAWS[id].per)) state.drift[k] = (state.drift[k] ?? 0) + v * lawPower;
  if (has(state, 'stabilita') && state.turn % 12 === 0) {
    for (const m of METERS) { const v = state.meters[m.id]; state.meters[m.id] = v < START ? Math.min(START, v + 3) : Math.max(START, v - 3); }
  }
  for (const [k, v] of Object.entries(state.drift)) {
    const whole = Math.trunc(v);
    if (whole) { state.meters[k] = clamp(state.meters[k] + whole); state.drift[k] = v - whole; }
  }
  let hit = METERS.find((m) => state.meters[m.id] <= 0 || state.meters[m.id] >= 100);
  if (hit && ((state.leader.kind === 'zachrance' && !state.rescued) || has(state, 'sance'))) {
    // Záchrana: ukazatel se odrazí od kraje. Typ Zachránce jednou za vládu, výhoda Druhá šance jednou.
    if (has(state, 'sance')) state.perks = state.perks.filter((p) => p !== 'sance');
    else state.rescued = true;
    state.meters[hit.id] = state.meters[hit.id] <= 0 ? RESCUE : 100 - RESCUE;
    news(state, 'rescue', `Na poslední chvíli: ${hit.name} se vrací na ${state.meters[hit.id]} %`);
    hit = METERS.find((m) => state.meters[m.id] <= 0 || state.meters[m.id] >= 100);
  }
  if (hit) {
    const side = state.meters[hit.id] <= 0 ? 'low' : 'high';
    endReign(state, { meter: hit.id, side, ...ENDINGS[hit.id][side] }, `${hit.id}.${side}`);
    return;
  }
  if (state.turn > 0 && state.turn % TERM === 0) {
    const v = support(state);
    if (v < VOTE_MIN) { endReign(state, { election: true, ...ELECTION, text: ELECTION.text.replace('{v}', v) }, 'volby'); return; }
    state.tally.elections += 1;
    news(state, 'election', `Vyhrál${state.leader.female ? 'a' : ''} jsi volby s ${v} % hlasů`);
  } else if (state.turn % TERM === TERM - 6) {
    news(state, 'electionSoon', `Za půl roku jsou volby. Hlasy ti dají Lid a Spojenci (teď ${support(state)} %, potřebuješ ${VOTE_MIN} %).`);
  }
  progressTask(state);
  const era = ERAS.filter((e) => state.total >= (e.total ?? 0) && seals(state) >= (e.seals ?? 0)).pop().n;
  if (era > (state.era ?? 1)) {
    state.era = era;
    state.queue.unshift({ id: `era${era}`, at: state.total });
    news(state, 'era', `Začíná éra: ${ERAS[era - 1].name}`);
  }
}

function endReign(state, e, key) {
  state.dead = { meter: e.meter ?? null, side: e.side ?? null, special: e.special ?? null, election: !!e.election, title: e.title, text: fill(e.text, state.leader), months: state.turn };
  state.history.push({ name: state.leader.name, female: state.leader.female, n: state.leader.n, months: state.turn, ending: key, title: e.title });
  if (!state.endings.includes(key)) state.endings.push(key);
  state.best = Math.max(state.best, state.turn);
  return state.dead;
}

// ── Úkoly vůdců ──────────────────────────────────────
export const taskById = (id) => TASKS.find((t) => t.id === id);

function assignTask(state) {
  const done = new Set(state.tasksDone ?? []);
  const fits = (t) => t.id !== state.task?.id && (state.era ?? 1) >= (t.era ?? 1) && !(t.type === 'flag' && state.flags.includes(t.flag));
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
export function nextLeader(state, kind = state.leader.kind) {
  const female = random(state) < 0.5;
  const names = female ? SUCCESSORS.f : SUCCESSORS.m;
  const used = new Set(state.history.map((h) => h.name));
  const free = names.filter((n) => !used.has(n));
  const list = free.length ? free : names;
  const name = list[Math.floor(random(state) * list.length)];
  state.leader = { name, female, n: state.leader.n + 1, kind };
  state.charge = 0;
  state.drift = {};
  state.perks = [];
  state.perkOffer = null;
  state.rescued = false;
  state.crisis = null;
  state.peek = null;
  // Nový vůdce = nová šance: vztahy vychladnou na polovinu.
  for (const k of Object.keys(state.rel ?? {})) state.rel[k] = Math.trunc(state.rel[k] / 2);
  state.meters = freshMeters();
  state.queue = state.queue.filter((q) => q.id.startsWith('era')); // nová éra nezapadne
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
  state.mode ??= 'normal';
  if (!state.task && !state.dead) assignTask(state);
  return state;
}

export { METERS, ENDINGS, PEOPLE, CARDS, INTRO, LAWS, TASKS, ERAS, SPECIAL, REL_LOYAL, PERKS, CRISES, ELECTION };
