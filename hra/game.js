// Herní logika Rovnováhy – bez DOMu, aby šla testovat v Node.
import { METERS, CARDS as BASE, INTRO, ENDINGS, SUCCESSORS, PEOPLE } from './cards.js';
import { EXTRA, LAWS, TASKS, ERAS, SPECIAL, CARES, REL_MAX, REL_LOYAL } from './world.js';

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
];
export const CHARGE = 5;     // po kolika rozhodnutích se nabije schopnost
export const NUDGE = 15;     // o kolik posune Kormidelník
const EXTREME = 20;          // Krizový manažer: krajnost = dál než 20 od středu (pod 30 / nad 70)
export const ADVICE_OK = 0.7;
export const kindOf = (state) => KINDS.find((k) => k.id === state.leader.kind) || KINDS[0];

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
  state.advice = state.leader.kind === 'rada' ? advise(state) : null;
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
  for (const [k, v] of Object.entries(optionOf(state, card, dir).e || {})) {
    const from = out[k];
    let d = effect(k, v);
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

/** Rozhodnutí. Vrací konec vlády (nebo null). */
export function choose(state, dir) {
  if (state.dead) return state.dead;
  const card = cardById(state.card) || INTRO;
  if (!card.opts[dir]) throw new Error(`neznámý směr ${dir}`);
  const o = optionOf(state, card, dir);
  state.meters = outcome(state, dir);
  state.charge = Math.min(CHARGE, (state.charge ?? 0) + 1);
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
  const add = (who, n) => { state.rel[who] = Math.max(-REL_MAX, Math.min(REL_MAX, (state.rel[who] ?? 0) + n)); };
  const cares = CARES[card.who];
  const raw = cares ? (o.e?.[cares] ?? 0) : 0;
  if (raw && !o.rel?.[card.who]) add(card.who, Math.sign(raw));
  for (const [who, n] of Object.entries(o.rel || {})) add(who, n);
}

export const activeLaws = (state) => state.flags.filter((f) => f.startsWith('zakon_')).map((f) => f.slice(6)).filter((id) => LAWS[id]);
export const seals = (state) => (state.tasksDone ?? []).length;

/** Uplynul měsíc: zákony, konec vlády, úkol, éra. */
function monthPasses(state) {
  state.drift ??= {};
  for (const id of activeLaws(state)) for (const [k, v] of Object.entries(LAWS[id].per)) state.drift[k] = (state.drift[k] ?? 0) + v;
  for (const [k, v] of Object.entries(state.drift)) {
    const whole = Math.trunc(v);
    if (whole) { state.meters[k] = clamp(state.meters[k] + whole); state.drift[k] = v - whole; }
  }
  const hit = METERS.find((m) => state.meters[m.id] <= 0 || state.meters[m.id] >= 100);
  if (hit) {
    const side = state.meters[hit.id] <= 0 ? 'low' : 'high';
    endReign(state, { meter: hit.id, side, ...ENDINGS[hit.id][side] }, `${hit.id}.${side}`);
    return;
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
  state.dead = { meter: e.meter ?? null, side: e.side ?? null, special: e.special ?? null, title: e.title, text: fill(e.text, state.leader), months: state.turn };
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
  state.charge = CHARGE; // odměna: schopnost se hned nabije
  news(state, 'task', `Úkol splněn: ${t.text}`);
  assignTask(state);
  news(state, 'newtask', `Nový úkol: ${taskById(state.task.id).text}`);
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
  // Nový vůdce = nová šance: vztahy vychladnou na polovinu.
  for (const k of Object.keys(state.rel ?? {})) state.rel[k] = Math.trunc(state.rel[k] / 2);
  state.meters = freshMeters();
  state.queue = state.queue.filter((q) => q.id.startsWith('era')); // nová éra nezapadne
  state.turn = 0;
  state.dead = null;
  assignTask(state);
  draw(state);
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
  if (!state.task && !state.dead) assignTask(state);
  return state;
}

export { METERS, ENDINGS, PEOPLE, CARDS, INTRO, LAWS, TASKS, ERAS, SPECIAL, REL_LOYAL };
