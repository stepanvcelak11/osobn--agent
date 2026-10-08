// Vlastní odpověď skládaná ze slov (jako v Pocket Realmu, jen bez psaní): Čin + Co + (Jak) + (Pro koho).
// Hra větu „rozumí“ podle významu slov: každé slovo nese změny ukazatelů a věta je jejich součet.
import { tr } from './i18n.js';
import { cardById, optionOf, whoOf, CARES, PEOPLE, DIRS, METERS, INTRO, PEN_EVERY } from './game.js';
export { PEN_EVERY };

/// Co se zvedne, když „toho je víc“ (sloveso se znaménkem −1 to otočí).
export const OBJECTS = {
  dane: { t: 'daně', e: { fin: 10, lid: -8 }, v: ['zvysit', 'snizit', 'zrusit', 'odlozit'] },
  vojsko: { t: 'vojsko', e: { sil: 10, fin: -6 }, v: ['posilit', 'omezit', 'rozpustit', 'odlozit'] },
  straze: { t: 'stráže', e: { sil: 8, lid: -4 }, v: ['posilit', 'omezit', 'odlozit'] },
  chramy: { t: 'chrámy', e: { vir: 10, fin: -5, ved: -3 }, v: ['postavit', 'podporit', 'zavrit', 'odlozit'] },
  skoly: { t: 'školy', e: { ved: 10, fin: -6 }, v: ['postavit', 'podporit', 'zavrit', 'odlozit'] },
  vyzkum: { t: 'výzkum', e: { ved: 8, vir: -5, fin: -3 }, v: ['podporit', 'zakazat', 'odlozit'] },
  lesy: { t: 'lesy', e: { pri: 10, fin: -5 }, v: ['chranit', 'kacet', 'odlozit'] },
  tezbu: { t: 'těžbu', e: { fin: 8, pri: -8 }, v: ['rozsirit', 'omezit', 'zakazat', 'odlozit'] },
  obchod: { t: 'obchod', e: { fin: 8, dip: 4, pri: -5 }, v: ['podporit', 'omezit', 'odlozit'] },
  chleb: { t: 'jídlo', e: { lid: 10, fin: -8 }, v: ['rozdat', 'pridelovat', 'odlozit'] },
  svatky: { t: 'svátky', e: { lid: 8, vir: 3, fin: -6 }, v: ['vyhlasit', 'zakazat', 'odlozit'] },
  prava: { t: 'práva lidu', e: { lid: 8, sil: -6 }, v: ['rozsirit', 'omezit', 'odlozit'] },
  spojenectvi: { t: 'spojenectví', e: { dip: 10, sil: -4 }, v: ['uzavrit', 'zrusit', 'odlozit'] },
  hranice: { t: 'hranice', e: { sil: 6, dip: -6, fin: -3 }, v: ['opevnit', 'otevrit', 'odlozit'] },
};
/// Sloveso: s = směr (+1 víc, −1 míň), k = síla, e = vlastní příchuť.
export const VERBS = {
  zvysit: { t: 'Zvýšit', s: 1 }, snizit: { t: 'Snížit', s: -1 }, zrusit: { t: 'Zrušit', s: -1, k: 1.4, e: { lid: -2 } },
  posilit: { t: 'Posílit', s: 1 }, omezit: { t: 'Omezit', s: -1 }, rozpustit: { t: 'Rozpustit', s: -1, k: 1.5 },
  postavit: { t: 'Postavit', s: 1, k: 1.2, e: { fin: -4 } }, podporit: { t: 'Podpořit', s: 1 }, zavrit: { t: 'Zavřít', s: -1, k: 1.2 },
  zakazat: { t: 'Zakázat', s: -1, k: 1.2, e: { sil: 3, lid: -3 } }, chranit: { t: 'Chránit', s: 1 }, kacet: { t: 'Kácet', s: -1, e: { fin: 5 } },
  rozsirit: { t: 'Rozšířit', s: 1 }, rozdat: { t: 'Rozdat', s: 1, k: 1.2 }, pridelovat: { t: 'Přidělovat', s: -1, e: { sil: 3 } },
  vyhlasit: { t: 'Vyhlásit', s: 1 }, uzavrit: { t: 'Uzavřít', s: 1 }, opevnit: { t: 'Opevnit', s: 1, k: 1.1 }, otevrit: { t: 'Otevřít', s: -1 },
  odlozit: { t: 'Odložit', s: 1, k: 0.2, e: { lid: -3 }, stall: true },
};
/// Jak: k = násobek, e = příchuť, hide = tento ukazatel se neprojeví (ale může to prasknout).
export const MANNERS = {
  opatrne: { t: 'opatrně', k: 0.6 },
  rychle: { t: 'rychle', k: 1.4, e: { lid: -2 } },
  silou: { t: 'silou', k: 1.2, e: { sil: 4, lid: -5 } },
  penezi: { t: 'za peníze', k: 1.25, e: { fin: -6 } },
  knezi: { t: 's požehnáním kněží', e: { vir: 4, ved: -3 } },
  ucenci: { t: 's radou učenců', e: { ved: 4, vir: -3 } },
  tajne: { t: 'tajně', hide: 'lid', risk: { p: 0.35, e: { lid: -10 }, text: 'Vyšlo najevo, co jsi tajně udělal{a}. Lid zuří.' } },
};
/// Pro koho: malý dárek jedné skupině (a uklidní její frakci).
export const TARGETS = {
  lid: { t: 'pro lid', e: { lid: 3 } },
  kupci: { t: 'pro kupce', e: { fin: 3, lid: -2 }, calm: 'kupci' },
  vojsko: { t: 'pro vojsko', e: { sil: 3 }, calm: 'vojsko' },
  knezi: { t: 'pro kněze', e: { vir: 3 }, calm: 'kneze' },
  ucenci: { t: 'pro učence', e: { ved: 3 }, calm: 'ucenci' },
  sousedy: { t: 'pro sousedy', e: { dip: 3 } },
};
const TAX = 0.8; // vlastní rozhodnutí je slabší v tom dobrém (cena za volnost)
const CAP = 15, CAP_UP = 8; // zlepšení je u vlastní odpovědi menší než zhoršení

/** Dá se na kartu odpovědět vlastními slovy? Ne u přelomů, finále, prvních karet a karet, které otevírají příběh. */
export const penLeft = (state) => Math.max(0, PEN_EVERY - (state.pen ?? PEN_EVERY));
export const canCustom = (state) => penLeft(state) === 0 && cardTakesWords(state);
export function cardTakesWords(state) {
  const c = cardById(state.card);
  if (!c || c.id === INTRO.id || c.id.startsWith('dej_') || c.milestone || c.finale || state.dead) return false;
  return !DIRS.some((d) => { const o = c.opts[d]; return o?.end || o?.advance || o?.arcEnd || o?.clue || o?.edu || o?.project; });
}

/// Základ odpovědi: vyhovět tomu, kdo přišel, odmítnout, napůl, nebo odložit.
export const ANSWERS = { ano: { t: 'Ano' }, ne: { t: 'Ne' }, napul: { t: 'Napůl' }, pozdeji: { t: 'Později' } };
const ACT_W = 0.5; // doplňující čin má poloviční váhu

/** Co znamená „ano“ a „ne“ u této karty: volba nejpříznivější / nejméně příznivá pro to, na čem mluvčímu záleží. */
export function yesNo(state) {
  const c = cardById(state.card), cm = CARES[whoOf(state, c)];
  // „Ano“ = co nejvíc vyhovět (při shodě ta rozhodnější volba), „ne“ = co nejméně.
  const score = (d) => { const e = optionOf(state, c, d)?.e ?? {}, sum = Object.values(e).reduce((a, n) => a + n, 0), size = Object.values(e).reduce((a, n) => a + Math.abs(n), 0);
    return cm ? (e[cm] ?? 0) * 100 + size * Math.sign(e[cm] ?? 0) : sum * 10 + size; };
  const ranked = DIRS.filter((d) => c.opts[d]).sort((a, b) => score(b) - score(a));
  return { yes: ranked[0], no: ranked.at(-1) };
}
/** Činy, které ke kartě sedí: jen ty, které hýbou ukazateli, o které na kartě jde. */
export function cardActions(state) {
  // Jen dva ukazatele, o které na kartě jde nejvíc, a u každého věci jen „víc“ a „míň“.
  const c = cardById(state.card), weight = {};
  for (const d of DIRS) for (const [m, n] of Object.entries(optionOf(state, c, d)?.e ?? {})) weight[m] = (weight[m] ?? 0) + Math.abs(n);
  const top = Object.entries(weight).sort((a, b) => b[1] - a[1]).slice(0, 2).map(([m]) => m);
  const out = {};
  const objs = Object.entries(OBJECTS).filter(([, ob]) => top.includes(Object.keys(ob.e)[0]))
    .sort((a, b) => top.indexOf(Object.keys(a[1].e)[0]) - top.indexOf(Object.keys(b[1].e)[0]));
  const per = {};
  for (const [oid, ob] of objs) {
    const m = Object.keys(ob.e)[0];
    if ((per[m] = (per[m] ?? 0) + 1) > 2) continue; // u každého ukazatele nejvýš dvě věci
    const plus = ob.v.find((v) => VERBS[v].s > 0 && !VERBS[v].stall), minus = ob.v.find((v) => VERBS[v].s < 0);
    for (const vid of [plus, minus].filter(Boolean)) out[`${vid}.${oid}`] = { t: `${tr(VERBS[vid].t)} ${tr(ob.t)}`, verb: vid, obj: oid };
  }
  return out;
}
/** Pro koho: mluvčí karty (zlepší vztah) a skupiny. */
export function cardTargets(state) {
  const c = cardById(state.card), who = whoOf(state, c), p = PEOPLE[who];
  const out = {};
  if (p && !who.startsWith('@')) out.spk = { t: tr('vyjít vstříc: {kdo}').replace('{kdo}', tr(p.name)), rel: who, cm: CARES[who] };
  return { ...out, ...TARGETS };
}
export function sentence(sel, state) {
  const parts = [tr(ANSWERS[sel.ans]?.t ?? '')];
  const act = sel.act && cardActions(state)[sel.act];
  if (act) parts.push(`${tr('a k tomu')} ${[VERBS[act.verb].t, OBJECTS[act.obj].t].map(tr).join(' ').toLowerCase()}`);
  if (sel.how) parts.push(tr(MANNERS[sel.how].t));
  if (sel.who) parts.push(cardTargets(state)[sel.who]?.t ?? '');
  return parts.filter(Boolean).join(', ');
}

/** Složí odpověď: základ (ano/ne/napůl/později) + doplňující čin + způsob + pro koho. */
export function customOption(state, sel) {
  const ans = ANSWERS[sel.ans];
  if (!ans) return null;
  const c = cardById(state.card), { yes, no } = yesNo(state);
  const e = {};
  const add = (x, k = 1) => { for (const [m, n] of Object.entries(x ?? {})) e[m] = (e[m] ?? 0) + n * k; };
  const how = MANNERS[sel.how], tg = cardTargets(state)[sel.who];
  const k = how?.k ?? 1;
  if (sel.ans === 'ano') add(optionOf(state, c, yes).e, k);
  if (sel.ans === 'ne') add(optionOf(state, c, no).e, k);
  if (sel.ans === 'napul') { add(optionOf(state, c, yes).e, 0.5 * k); add(optionOf(state, c, no).e, 0.5 * k); }
  if (sel.ans === 'pozdeji') add({ lid: -3 });
  const act = sel.act && cardActions(state)[sel.act];
  if (act) { const v = VERBS[act.verb]; add(OBJECTS[act.obj].e, v.s * (v.k ?? 1) * ACT_W * k); add(v.e, ACT_W); }
  add(how?.e); add(tg?.e);
  if (tg?.cm) add({ [tg.cm]: 2 });
  if (how?.hide) delete e[how.hide];
  for (const m of Object.keys(e)) {
    let n = e[m] > 0 ? e[m] * TAX : e[m];
    n = Math.max(-CAP, Math.min(CAP_UP, Math.round(n)));
    if (n) e[m] = n; else delete e[m];
  }
  const stall = sel.ans === 'pozdeji';
  const o = { t: sentence(sel, state), e, custom: true, offTopic: stall, again: stall && !c.once };
  if (tg?.calm) o.calm = tg.calm;
  if (tg?.rel) o.rel = { [tg.rel]: 1 };
  if (how?.risk) o.later = [{ p: how.risk.p, in: 3, e: how.risk.e, text: how.risk.text }];
  return o;
}

/** Krátká odezva: jak země přijala vlastní rozhodnutí (podle dvou největších změn). */
const REACT = {
  fin: ['Pokladna se plní.', 'Pokladna řídne.'], lid: ['Lid jásá.', 'Lid reptá.'], sil: ['Stráže sebevědomě pochodují.', 'Velitelé se mračí.'],
  ved: ['Učenci pracují dnem i nocí.', 'Učenci balí knihy.'], pri: ['Krajina si oddechla.', 'Krajina trpí.'], vir: ['Chrámy jsou plné.', 'Kněží se bouří.'],
  dip: ['Sousedé posílají dary.', 'Sousedé chladnou.'],
};
export function reaction(state, before, o, speaker) {
  const ch = METERS.map((m) => [m.id, state.meters[m.id] - before[m.id]]).filter(([, d]) => d).sort((a, b) => Math.abs(b[1]) - Math.abs(a[1])).slice(0, 2);
  const parts = ch.map(([m, d]) => REACT[m][d > 0 ? 0 : 1]);
  if (o.offTopic) parts.push(VERBS_STALL_TEXT(speaker));
  return parts.map(tr).join(' ') || tr('Nic se nezměnilo.');
}
const VERBS_STALL_TEXT = (who) => tr('„Ale co můj problém?“ ptá se {kdo}. Vrátí se s ním.').replace('{kdo}', who ?? tr('posel'));

// ── Výprava: vlastní čin hrdiny ──────────────────────
/// Sloveso určí vlastnost (jako v Pocket Realmu), cíl a způsob obtížnost.
export const Q_VERBS = {
  zautocit: { t: 'Zaútočit na', a: 'sila' }, prorazit: { t: 'Prorazit do', a: 'sila', gen: true }, proplizit: { t: 'Proplížit se kolem', a: 'obratnost', gen: true },
  ukrast: { t: 'Ukrást', a: 'obratnost' }, prozkoumat: { t: 'Prozkoumat', a: 'duvtip' }, vystopovat: { t: 'Vystopovat', a: 'duvtip' },
  premluvit: { t: 'Přemluvit', a: 'charisma' }, zastrasit: { t: 'Zastrašit', a: 'charisma', d: 1 },
};
export const Q_OBJECTS = {
  hlidky: { t: 'hlídky', g: 'hlídek', d: 0 }, vudce: { t: 'vůdce', g: 'vůdce', d: 2 }, tabor: { t: 'tábor', g: 'tábora', d: 1 }, stopy: { t: 'stopy', g: 'stop', d: -1 },
  mistni: { t: 'místní lidi', g: 'místních lidí', d: -1 }, ukryt: { t: 'úkryt', g: 'úkrytu', d: 1 }, zasoby: { t: 'zásoby', g: 'zásob', d: 0 },
};
export const Q_MANNERS = {
  opatrne: { t: 'opatrně', d: -2 }, nenapadne: { t: 'nenápadně', d: -1 }, odvazne: { t: 'odvážně', d: 2, heal: true }, lsti: { t: 'lstí', d: 0, a: 'duvtip' },
};
/** Vlastní čin hrdiny jako volba výpravy {t, a, d, ok, bad}: „opatrně“ je snazší, „odvážně“ těžší, ale úspěch zahojí jedno zranění. */
export function questOption(sel, female) {
  const v = Q_VERBS[sel.verb], ob = Q_OBJECTS[sel.obj], how = Q_MANNERS[sel.how];
  if (!v || !ob) return null;
  const a = how?.a ?? v.a, t = [v.t, v.gen ? ob.g : ob.t, how?.t].filter(Boolean).map(tr).join(' ');
  const cin = (s) => tr(s).replaceAll('{cin}', t.toLowerCase()).replaceAll('{a}', female ? 'a' : '');
  return { t, a, d: (v.d ?? 0) + ob.d + (how?.d ?? 0), heal: !!how?.heal, custom: true,
    ok: cin('{hrdina} se rozhodl{a}: {cin}. A vyšlo to – cesta je volná.'),
    bad: cin('{hrdina} se rozhodl{a}: {cin}. Nevyšlo to a odnesl{a} to šrámem.') };
}
