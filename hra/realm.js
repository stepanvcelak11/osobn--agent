// Kraje, hrdinové a výpravy (inspirováno Pocket Realmem): říše má sedm krajů, v krajích vznikají hrozby
// a hrdinové na ně vyrážejí. Výprava = tři riskantní kroky, každý se hází k20 + 2× vlastnost proti 11 + obtížnost.
import { THREATS, QUEST_STEPS } from './quests.js';

/// Kraj patří k jednomu ukazateli: jeho spokojenost tíhne k tomu, jak je ukazatel v rovnováze.
export const PROVINCES = {
  hlavni: { name: 'Hradiště', desc: 'hlavní město', m: 'lid', x: 50, y: 50 },
  nizina: { name: 'Polánka', desc: 'úrodná nížina', m: 'fin', x: 30, y: 66 },
  hory: { name: 'Skaliny', desc: 'hory', m: 'sil', x: 22, y: 26 },
  les: { name: 'Hvozdy', desc: 'lesy', m: 'pri', x: 74, y: 24 },
  pristav: { name: 'Brodec', desc: 'přístav', m: 'dip', x: 82, y: 62 },
  udoli: { name: 'Svatava', desc: 'posvátné údolí', m: 'vir', x: 52, y: 84 },
  akademie: { name: 'Moudrov', desc: 'kraj učenců', m: 'ved', x: 48, y: 18 },
};
export const PROV_OF = Object.fromEntries(Object.entries(PROVINCES).map(([id, p]) => [p.m, id]));
export const LOST_MAX = 3; // tolik odtržených krajů = rozpad říše

export const ATTRS = { sila: 'Síla', obratnost: 'Obratnost', duvtip: 'Důvtip', charisma: 'Charisma' };
export const HERO_CLASSES = {
  valecnik: { m: 'Válečník', f: 'Válečnice', icon: 'krize', text: 'Voják z povolání. Nejlépe vyřeší věci silou.', a: { sila: 3, obratnost: 1, duvtip: -1, charisma: 0 } },
  zlodej: { m: 'Zloděj', f: 'Zlodějka', icon: 'key', text: 'Stín z uliček. Projde tam, kam jiní nemohou.', a: { sila: -1, obratnost: 3, duvtip: 1, charisma: 0 } },
  carodej: { m: 'Čaroděj', f: 'Čarodějka', icon: 'prorok', text: 'Učenec tajných nauk. Každé kouzlo má svou cenu.', a: { sila: -1, obratnost: 0, duvtip: 3, charisma: 1 } },
  bard: { m: 'Bard', f: 'Bardka', icon: 'charisma', text: 'Potulný pěvec. Slovem otevře dveře i srdce.', a: { sila: -1, obratnost: 1, duvtip: 0, charisma: 3 } },
  lovec: { m: 'Lovec', f: 'Lovkyně', icon: 'vize', text: 'Stopař z hlubokých lesů. Zná divočinu jako vlastní dlaň.', a: { sila: 1, obratnost: 2, duvtip: 1, charisma: -1 } },
};
const HERO_NAMES = {
  m: ['Bořek', 'Vít', 'Kryštof', 'Jiřík', 'Ctibor', 'Radim', 'Hostivít', 'Lubor', 'Dalibor', 'Šimon', 'Matyáš', 'Zbyněk'],
  f: ['Radka', 'Alena', 'Dobromila', 'Libuše', 'Vlasta', 'Mlada', 'Zora', 'Bohdana', 'Jitka', 'Marta', 'Kazi', 'Vendula'],
};
export const HEROES_MAX = 3;
export const WOUNDS_MAX = 3; // tolik zranění = hrdina padne
export const REST = 6; // po výpravě hrdina odpočívá (měsíce)
export const HIRE_COST = { fin: -8 }; // najmutí hrdiny stojí zásoby
export const HIRE_EVERY = 12; // najmout jde jednou za rok
export const TARGET = 11;
export const STEPS = 3, NEED = 2; // tři kroky, k úspěchu stačí dva

function rnd(state) {
  let t = (state.seed = (state.seed + 0x6d2b79f5) >>> 0);
  t = Math.imul(t ^ (t >>> 15), t | 1);
  t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
}
const pick = (state, list) => list[Math.floor(rnd(state) * list.length)];
const clamp = (v, a = 0, b = 100) => Math.max(a, Math.min(b, v));

export const freshProvinces = () => Object.fromEntries(Object.keys(PROVINCES).map((id) => [id, { sat: 70, lost: false, threat: null }]));
export const heroName = (h) => h.name;
export const heroClass = (h) => HERO_CLASSES[h.cls] ?? HERO_CLASSES.valecnik;
export const heroTitle = (h) => (h.female ? heroClass(h).f : heroClass(h).m);
/** Vlastnost hrdiny včetně zkušenosti (každá úroveň +1 k nejlepší vlastnosti). */
export const attrOf = (h, a) => (heroClass(h).a[a] ?? 0) + (h.boost?.[a] ?? 0);

export function newHero(state, cls = null) {
  const female = rnd(state) < 0.5;
  const taken = new Set((state.heroes ?? []).map((h) => h.name));
  const pool = HERO_NAMES[female ? 'f' : 'm'].filter((n) => !taken.has(n));
  return { id: `h${(state.heroSeq = (state.heroSeq ?? 0) + 1)}`, cls: cls ?? pick(state, Object.keys(HERO_CLASSES)), name: pick(state, pool.length ? pool : HERO_NAMES[female ? 'f' : 'm']), female, lvl: 1, xp: 0, wounds: 0, rest: 0, boost: {}, deeds: 0 };
}
export const canHire = (state) => (state.heroes ?? []).length < HEROES_MAX && (state.total ?? 0) >= (state.hireAt ?? 0) && !state.dead;
export function hire(state) {
  if (!canHire(state)) return null;
  const h = newHero(state);
  state.heroes.push(h);
  for (const [k, v] of Object.entries(HIRE_COST)) state.meters[k] = clamp(state.meters[k] + v);
  state.hireAt = state.total + HIRE_EVERY;
  return h;
}
export const ready = (h) => h.rest <= 0 && h.wounds < WOUNDS_MAX;

/** Šance na úspěch (0–1): k20 + 2× vlastnost + (úroveň − 1) ≥ 11 + obtížnost; 20 vždy uspěje, 1 vždy selže. */
export function chance(h, o) {
  const need = TARGET + (o.d ?? 0) - 2 * attrOf(h, o.a) - (h.lvl - 1);
  let n = 0;
  for (let die = 1; die <= 20; die++) if (die === 20 || (die !== 1 && die >= need)) n++;
  return n / 20;
}

/** Měsíc v krajích: spokojenost tíhne ke zdraví ukazatele, hrozby škodí, vznikají nové; vrací zprávy a odtržení. */
export function provinceMonth(state, news) {
  state.prov ??= freshProvinces();
  const lostNow = [];
  for (const [id, p] of Object.entries(state.prov)) {
    if (p.lost) continue;
    const v = state.meters[PROVINCES[id].m], target = 100 - 2 * Math.abs(v - 50);
    p.sat += (target - p.sat) * 0.12;
    if (p.threat && p.threat.type !== 'treasure') p.sat -= 3.5;
    if (p.threat?.type === 'treasure' && state.total - p.threat.since > 18) { p.threat = null; news('threat', `Stopa pokladu v kraji ${PROVINCES[id].name} vychladla.`); }
    p.sat = clamp(Math.round(p.sat * 10) / 10);
    if (p.sat <= 0) {
      p.lost = true; p.threat = null; lostNow.push(id);
      state.meters[PROVINCES[id].m] = clamp(state.meters[PROVINCES[id].m] - 10);
      news('provLost', `Kraj ${PROVINCES[id].name} se odtrhl od říše! Pošli hrdinu, ať ho získá zpět.`);
    } else if (p.sat <= 20 && !p.warned) { p.warned = true; news('enemy', `Kraj ${PROVINCES[id].name} je na pokraji odtržení.`); }
    else if (p.sat > 30) p.warned = false;
  }
  for (const h of state.heroes ?? []) if (h.rest > 0) h.rest -= 1;
  // Nová hrozba: zhruba jednou za rok, nejvýš dvě naráz.
  const active = Object.values(state.prov).filter((p) => p.threat).length;
  if ((state.turn ?? 0) >= 6 && active < 2 && rnd(state) < 1 / 11) {
    const free = Object.keys(state.prov).filter((id) => !state.prov[id].lost && !state.prov[id].threat);
    if (free.length) {
      const id = pick(state, free), type = rnd(state) < 0.15 ? 'treasure' : pick(state, ['bandits', 'beast', 'plague', 'revolt', 'cult']);
      state.prov[id].threat = { type, since: state.total };
      news('threat', type === 'treasure' ? `V kraji ${PROVINCES[id].name} se mluví o ztraceném pokladu.` : `${THREATS[type].name} v kraji ${PROVINCES[id].name}! Pošli hrdinu, než se kraj vzbouří.`);
    }
  }
  return lostNow;
}
export const lostCount = (state) => Object.values(state.prov ?? {}).filter((p) => p.lost).length;
/** Kraj, ze kterého karta přichází (podle toho, o co se mluvčí stará). */
export const provinceFor = (meter) => PROV_OF[meter] ?? null;

// ── Výprava ──────────────────────────────────────────
/** Vyslat hrdinu do kraje (hrozba, nebo odtržený kraj). */
export function startQuest(state, provId, heroId) {
  const p = state.prov?.[provId], h = (state.heroes ?? []).find((x) => x.id === heroId);
  if (!p || !h || !ready(h) || state.quest || state.dead) return false;
  const type = p.lost ? 'revolt' : p.threat?.type;
  if (!type) return false;
  const all = QUEST_STEPS[type].map((s, i) => [s, i]);
  const chosen = [];
  while (chosen.length < STEPS && all.length) chosen.push(all.splice(Math.floor(rnd(state) * all.length), 1)[0]);
  state.quest = { prov: provId, hero: heroId, type, regain: p.lost, steps: chosen.sort((a, b) => a[1] - b[1]).map(([s]) => s.id), i: 0, ok: 0, bad: 0, log: [] };
  return true;
}
export const stepById = (id) => Object.values(QUEST_STEPS).flat().find((s) => s.id === id);
export const questHero = (state) => (state.heroes ?? []).find((h) => h.id === state.quest?.hero);
/** Riskantní čin: hod kostkou. Vrací výsledek kroku; po posledním kroku výpravu vyhodnotí. */
export function questRoll(state, dir) {
  const q = state.quest, h = questHero(state);
  if (!q || !h) return null;
  const step = stepById(q.steps[q.i]), o = step.opts[dir];
  const die = 1 + Math.floor(rnd(state) * 20);
  const bonus = 2 * attrOf(h, o.a) + (h.lvl - 1), target = TARGET + (o.d ?? 0);
  const success = die === 20 || (die !== 1 && die + bonus >= target);
  if (success) q.ok += 1; else { q.bad += 1; h.wounds += 1; }
  const r = { die, bonus, target, success, crit: die === 20 || die === 1, a: o.a, text: success ? o.ok : o.bad };
  q.log.push(r);
  q.i += 1;
  const dead = h.wounds >= WOUNDS_MAX;
  if (q.i >= q.steps.length || dead || q.ok >= NEED || q.bad > STEPS - NEED) r.end = finishQuest(state, dead);
  return r;
}
function finishQuest(state, dead) {
  const q = state.quest, h = questHero(state), p = state.prov[q.prov], P = PROVINCES[q.prov];
  const win = !dead && q.ok >= NEED;
  const res = { win, dead, type: q.type, prov: q.prov, regain: q.regain, hero: h.name, lvlUp: false };
  if (win) {
    if (q.regain) { p.lost = false; p.sat = 45; }
    else { p.threat = null; p.sat = clamp(p.sat + 30); }
    const m = P.m, v = state.meters[m];
    state.meters[m] = v < 50 ? Math.min(50, v + 10) : Math.max(50, v - 10); // vyřešený kraj pomůže i svému ukazateli
    if (q.type === 'treasure') state.meters.fin = clamp(state.meters.fin + (state.meters.fin < 50 ? 12 : 4));
    h.xp += 1; h.deeds += 1;
    if (h.xp >= h.lvl * 2) {
      h.xp = 0; h.lvl += 1; res.lvlUp = true;
      const best = Object.keys(ATTRS).sort((a, b) => attrOf(h, b) - attrOf(h, a)).find((a) => attrOf(h, a) < 5);
      if (best) h.boost[best] = (h.boost[best] ?? 0) + 1;
    }
  } else if (!q.regain && p.threat) {
    p.sat = clamp(p.sat - 15);
  }
  h.rest = REST;
  if (dead) state.heroes = state.heroes.filter((x) => x.id !== h.id);
  state.quest = null;
  (state.deeds ??= []).push({ hero: h.name, cls: h.cls, female: h.female, prov: q.prov, type: q.type, win, dead, at: state.total });
  state.deeds = state.deeds.slice(-30);
  return res;
}
export { THREATS, QUEST_STEPS };
