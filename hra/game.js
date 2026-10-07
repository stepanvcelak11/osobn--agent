// Herní logika Rovnováhy – bez DOMu, aby šla testovat v Node.
import { METERS, CARDS, INTRO, ENDINGS, SUCCESSORS, PEOPLE } from './cards.js';

export const DIRS = ['left', 'right', 'up', 'down'];
export const START = 50;
const RECENT = 14;
/// Citlivost ukazatelů – vyrovnává, jak často karty který ukazatel mění (ladí se simulací v testech),
/// aby žádný konec nebyl skoro nedosažitelný.
export const SCALE = { fin: 0.7, lid: 0.7, sil: 1.5, ved: 0.9, pri: 1.7, vir: 1.35, dip: 1.6 };
export function effect(k, v) { return Math.round(v * (SCALE[k] ?? 1)); }
const BY_ID = new Map([[INTRO.id, INTRO], ...CARDS.map((c) => [c.id, c])]);

export function cardById(id) { return BY_ID.get(id); }

// Deterministický generátor (mulberry32) – stav se ukládá, takže hra jde přesně obnovit.
export function random(state) {
  let t = (state.seed = (state.seed + 0x6d2b79f5) >>> 0);
  t = Math.imul(t ^ (t >>> 15), t | 1);
  t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
}

function freshMeters() { return Object.fromEntries(METERS.map((m) => [m.id, START])); }

export function newGame({ name = '', female = false } = {}, seed = Date.now() >>> 0) {
  const leaderName = name.trim().slice(0, 30) || (female ? 'Jana Nová' : 'Jan Nový');
  return {
    v: 1,
    seed: seed >>> 0 || 1,
    leader: { name: leaderName, female: !!female, n: 1 },
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
  return true;
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
  const weights = pool.map((c) => (c.weight ?? 1) * (c.req ? 2 : 1));
  let r = random(state) * weights.reduce((a, b) => a + b, 0);
  for (let i = 0; i < pool.length; i++) {
    r -= weights[i];
    if (r <= 0) return pool[i].id;
  }
  return pool[pool.length - 1].id;
}

/** Které ukazatele volba změní (bez prozrazení směru) – pro tečky pod ukazateli. */
export function preview(card, dir) {
  const o = card.opts[dir];
  const out = {};
  for (const [k, v] of Object.entries(o?.e || {})) if (v) out[k] = Math.abs(effect(k, v)) >= 12 ? 'big' : 'small';
  return out;
}

const clamp = (v) => Math.max(0, Math.min(100, v));

/** Rozhodnutí. Vrací konec vlády (nebo null). */
export function choose(state, dir) {
  if (state.dead) return state.dead;
  const card = cardById(state.card) || INTRO;
  const o = card.opts[dir];
  if (!o) throw new Error(`neznámý směr ${dir}`);
  for (const [k, v] of Object.entries(o.e || {})) state.meters[k] = clamp(state.meters[k] + effect(k, v));
  if (o.set && !state.flags.includes(o.set)) state.flags.push(o.set);
  if (o.unset) state.flags = state.flags.filter((f) => f !== o.unset);
  if (o.next) state.queue.push({ id: o.next, at: state.total + 1 + (o.in ?? 3) });
  if (card.once && !state.used.includes(card.id)) state.used.push(card.id);
  state.recent = [...state.recent, card.id].slice(-RECENT);
  if (card.id !== INTRO.id) state.turn += 1;
  state.total += 1;

  const hit = METERS.find((m) => state.meters[m.id] <= 0 || state.meters[m.id] >= 100);
  if (hit) {
    const side = state.meters[hit.id] <= 0 ? 'low' : 'high';
    const e = ENDINGS[hit.id][side];
    state.dead = { meter: hit.id, side, title: e.title, text: fill(e.text, state.leader), months: state.turn };
    state.history.push({ name: state.leader.name, female: state.leader.female, n: state.leader.n, months: state.turn, ending: `${hit.id}.${side}`, title: e.title });
    const key = `${hit.id}.${side}`;
    if (!state.endings.includes(key)) state.endings.push(key);
    state.best = Math.max(state.best, state.turn);
    return state.dead;
  }
  state.card = pickCard(state);
  return null;
}

/** Nástupce: nový vůdce, ukazatele zpět doprostřed. Svět (příznaky) zůstává. */
export function nextLeader(state) {
  const female = random(state) < 0.5;
  const names = female ? SUCCESSORS.f : SUCCESSORS.m;
  const used = new Set(state.history.map((h) => h.name));
  const free = names.filter((n) => !used.has(n));
  const list = free.length ? free : names;
  const name = list[Math.floor(random(state) * list.length)];
  state.leader = { name, female, n: state.leader.n + 1 };
  state.meters = freshMeters();
  state.queue = [];
  state.turn = 0;
  state.dead = null;
  state.card = pickCard(state);
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

export { METERS, ENDINGS, PEOPLE, CARDS, INTRO };
