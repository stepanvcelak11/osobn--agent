// Rovnováha – zobrazení a ovládání (tažení karty do čtyř stran, šipky, klávesy, uložení hry).
import { portrait, meterIcon, glyph, icon, mood, mix } from './art.js';
import { duelSetup } from './duel.js';
import { LEVELS, levelOf, MASTERY, LEVEL_TEXT, TREE, TREE_MAX, RELICS, RELIC_SLOTS, SKINS, PRESTIGE_BONUS, ROMAN, CAMPAIGN } from './meta.js';
import { FACTIONS, FACTION_REVOLT, PROJECTS, PROJECT_MONTHS, albumPeople, whoOf, master, chargeOf, ENDINGS_PAST, offerPerks, skipCard, bestDir, sageHint, shiftMeter, SHIFT, newGame, newBlitz, newRun, daily, touches, seesAhead, personOf, seasonOf, SEASON_NAMES, RIVALS, MODS, BRANCHES, WONDERS, modBonus, ageOf, leaderTitle, hasElections, lawAllowed, AGES, AGE_LEN, choose, nextLeader, currentCard, cardById, preview, outcome, optionOf, unlocked, skip, nudge, reformLaw, choosePerk, ready, tenure, timeLabel, danger, kindOf, upgrade, activeLaws, seals, taskById, taskProgress, seesDirection, toElection, support, KINDS, ACTIVE, CHARGE, NUDGE, METERS, ENDINGS, LAWS, TASKS, ERAS, SPECIAL, PEOPLE, REL_LOYAL, PERKS, CRISES, ELECTION, VOTE_MIN, BLITZ_START, BLITZ_BONUS, BLITZ_FALL } from './game.js';

const SAVE = 'rovnovaha.save';
const app = document.getElementById('app');
let state = load();

// Výška aplikace = skutečně viditelná plocha. CSS jednotky (vh, lvh, %) v aplikaci z plochy iPhonu
// občas vrací špatnou výšku a dole pak zůstane prázdný pruh nebo se obsah usekne.
function fitApp() {
  document.documentElement.style.setProperty('--app-h', `${window.innerHeight}px`);
}
fitApp();
window.addEventListener('resize', () => { fitApp(); if (ui) fitText(ui.q); });
window.addEventListener('orientationchange', () => setTimeout(fitApp, 300));
document.addEventListener('focusout', () => setTimeout(() => { window.scrollTo(0, 0); fitApp(); }, 250));
window.addEventListener('pageshow', fitApp);

function load() {
  try {
    const s = JSON.parse(localStorage.getItem(SAVE));
    if (!s || s.v !== 1) return null;
    return upgrade(s); // starší uložení doplní o nové části

  } catch { return null; }
}
function save() {
  if (state?.mode === 'blitz') return; // bleskovka se neukládá – hlavní hra zůstává netknutá
  if (state?.mode === 'duel') return; // hra pro dva se neukládá
  try { localStorage.setItem(state?.camp ? CAMP : state?.mode === 'daily' ? `${DAILY}.${state.chal ?? 'd2089'}` : SAVE, JSON.stringify(state)); } catch { /* soukromé okno – hraje se bez ukládání */ }
}
// Denní výzva má vlastní uložení – hlavní hra zůstává netknutá.
const DAILY = 'rovnovaha.daily';
const CAMP = 'rovnovaha.camp'; // rozehraná kapitola kampaně
const today = (d = new Date()) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
/// Výzvy: denní (Rok 2089 / Dějiny) a týdenní (Dějiny, tři vládci).
const weekKey = (d = new Date()) => {
  const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
  const day = t.getUTCDay() || 7;
  t.setUTCDate(t.getUTCDate() + 4 - day);
  const y = t.getUTCFullYear(), w = Math.ceil(((t - Date.UTC(y, 0, 1)) / 864e5 + 1) / 7);
  return `${y}-T${w}`;
};
const CHAL = {
  d2089: { name: 'Denní výzva', sub: 'Rok 2089 · jedna vláda', world: '2089', lives: 1, key: () => today() },
  ddej: { name: 'Denní výzva – Dějiny', sub: 'od pravěku · jedna vláda', world: 'dejiny', lives: 1, key: () => `${today()}d` },
  week: { name: 'Týdenní výzva', sub: 'Dějiny · tři vládci po sobě', world: 'dejiny', lives: 3, key: () => weekKey() },
};
function loadDaily(ch = 'd2089') {
  try {
    const s = JSON.parse(localStorage.getItem(`${DAILY}.${ch}`));
    return s && s.day === CHAL[ch].key() && !s.dead ? upgrade(s) : null;
  } catch { return null; }
}
/** Zpět do hlavní nabídky – vždy s hlavní hrou (ne s bleskovkou ani denní výzvou). */
function home() {
  if (blitz) { clearInterval(blitz.id); blitz = null; }
  state = load();
  startScreen();
}
// ── Statistiky hráče (přežijí i novou hru) ───────────
const STATS = 'rovnovaha.stats';
/// Odemykání vůdců za body: na začátku je volných pět, každý další stojí PRICE bodů.
const START_KINDS = ['vize', 'krize', 'odklad', 'kormidlo', 'rada'];
const PRICE = 5;
/// Vybavení do příští vlády (kupuje se za body v obchodě na úvodní obrazovce). Ve hře se nic neovládá –
/// na začátku další vlády v hlavní hře se od každého druhu použije jeden kus. Cena odpovídá síle.
const ITEMS = {
  rada: { name: 'Rada mudrce', icon: 'rada', price: 2, text: 'Na prvních 20 kartách vlády ti mudrc radí. Napůl trefí volbu, která pomůže, napůl jen hádá.' },
  vyhoda: { name: 'Výhoda do začátku', icon: 'perk', price: 4, text: 'Hned na začátku vlády si vybereš jednu ze tří výhod.' },
  stit: { name: 'Štít', icon: 'zachrance', price: 5, text: 'Jednou tě zachrání před pádem – ukazatel se odrazí na 15, nebo 85 %.' },
};
const HINTS = 20;
const OLD_ITEMS = { vyrovnat: 4 }; // zrušené pomůcky – body se vrátí
/// Jednorázové pomůcky: ve hře je použiješ tlačítkem s klíčem v rohu karty (jen v hlavní hře).
const TOOLS = {
  preskok: { name: 'Přeskočit kartu', icon: 'odklad', price: 3, text: 'Karta zmizí bez následků, uplyne jen měsíc.' },
  posun: { name: 'Posunout ukazatel', icon: 'kormidlo', price: 3, text: `Posuneš libovolný ukazatel o ${SHIFT} nahoru, nebo dolů – kam potřebuješ.` },
  zpet: { name: 'Vrátit tah', icon: 'undo', price: 4, text: 'Vezme zpět poslední rozhodnutí – karta se vrátí a můžeš volit znovu.' },
};
let undoSnap = null;
/// Kdo odpoví rychleji než za vteřinu, nečte – další karta mu jen uškodí (ne v bleskovce).
const RUSH_MS = 1000;
let shownAt = 0; // stav před posledním rozhodnutím (pro „Vrátit tah“)
const bodu = (n) => (n === 1 ? 'bod' : n >= 2 && n <= 4 ? 'body' : 'bodů');
const emptyStats = () => ({ points: 0, unlocked: [...START_KINDS], items: {}, games: 0, decisions: 0, reigns: 0, months: 0, tasks: 0, elections: 0, crises: 0, ends: {}, top: [], blitz: [], daily: {}, weekly: {}, ach: {}, kinds: [], wonders: 0, wars: 0, traitors: 0,
  xp: {}, tree: {}, relics: [], equip: [], skins: ['klasik'], skin: 'klasik', met: [], albums: [], camp: {}, prestige: 0, weekAward: {} });
let stats = loadStats();
function loadStats() {
  let s = null;
  try { s = JSON.parse(localStorage.getItem(STATS)); } catch { /* nic */ }
  if (s) {
    const st = { ...emptyStats(), ...s };
    if (s.points == null) st.points = Object.keys(s.ach ?? {}).length; // starší hráči dostanou body za dosavadní úspěchy
    if (state?.leader?.kind && !st.unlocked.includes(state.leader.kind)) st.unlocked.push(state.leader.kind);
    for (const [id, price] of Object.entries(OLD_ITEMS)) if (st.items[id]) { st.points += st.items[id] * price; delete st.items[id]; }
    return st;
  }
  // První spuštění se statistikami: převezmi vůdce z kroniky.
  const st = emptyStats();
  for (const h of state?.history ?? []) {
    st.reigns += 1; st.months += h.months; st.ends[h.ending] = (st.ends[h.ending] ?? 0) + 1;
    st.top.push({ name: h.name, months: h.months, title: h.title, kind: null });
  }
  st.top = st.top.sort((a, b) => b.months - a.months).slice(0, 10);
  st.games = state ? 1 : 0;
  return st;
}
function saveStats() { try { localStorage.setItem(STATS, JSON.stringify(stats)); } catch { /* nic */ } }
const isUnlocked = (id) => stats.unlocked.includes(id);
const isMain = () => state && ['normal', 'dejiny'].includes(state.mode) && !state.camp;
/** Postup hráče, který si vůdce bere do hlavní hry: úroveň typu, strom dynastie, nasazené relikvie. */
const metaFor = (kind) => ({ lvl: levelOf(stats.xp[kind]), meta: { tree: { ...stats.tree }, relics: [...stats.equip] } });
/** Relikvie: náhodná, kterou hráč ještě nemá (nebo konkrétní). */
function dropRelic(why, id = null) {
  const free = Object.keys(RELICS).filter((r) => !stats.relics.includes(r));
  if (id && stats.relics.includes(id)) id = null;
  const r = id ?? free[Math.floor(Math.random() * free.length)];
  if (!r) return;
  stats.relics.push(r);
  if (stats.equip.length < RELIC_SLOTS) stats.equip.push(r);
  saveStats();
  sfx('ach');
  toast(`Relikvie: ${RELICS[r].name} (${why})`, 'ach');
}
let lastAward = null; // body za poslední vládu (na obrazovku konce vlády)
/** Připíše body a oznámí to. */
function award(n, why) {
  if (!n) return;
  stats.points += n;
  saveStats();
  toast(`+${n} ${bodu(n)} · ${why}`, 'points');
}
/** Konec vlády do statistik (jen hlavní hra). */
function recordReign() {
  const h = state.history[state.history.length - 1];
  if (!h || state.mode === 'blitz') return;
  stats.reigns += 1;
  stats.months += h.months;
  stats.ends[h.ending] = (stats.ends[h.ending] ?? 0) + 1;
  stats.top.push({ name: h.name, months: h.months, score: h.score ?? h.months, title: h.title, kind: state.leader.kind, mods: state.mods?.length ?? 0 });
  if (!stats.kinds.includes(state.leader.kind)) stats.kinds.push(state.leader.kind);
  stats.top = stats.top.sort((a, b) => (b.score ?? b.months) - (a.score ?? a.months)).slice(0, 10);
  saveStats();
  // Body: 1 rok = 1, 3 roky = 2, 6 let = 3; se ztížením dvojnásob; legenda +3.
  let n = h.months >= 72 ? 3 : h.months >= 36 ? 2 : h.months >= 12 ? 1 : 0;
  if (n && state.mods?.length) n *= 2;
  if (h.ending.startsWith('x.')) n += 3;
  // Zkušenost vůdce (úrovně typu).
  const kind = state.leader.kind, before = levelOf(stats.xp[kind]);
  stats.xp[kind] = (stats.xp[kind] ?? 0) + h.months;
  const after = levelOf(stats.xp[kind]);
  if (after > before) setTimeout(() => toast(`${KINDS.find((k) => k.id === kind).short}: úroveň ${after} – ${LEVEL_TEXT[after]}`, 'ach'), 900);
  if (before >= 4 && h.months >= 12) n += 1;
  if (isMain()) {
    n = Math.round(n * (1 + 0.2 * (stats.tree.pokladna ?? 0)) * (1 + PRESTIGE_BONUS * (state.prestige ?? 0)));
    if (h.months >= 60 || h.ending.startsWith('x.')) dropRelic(h.ending.startsWith('x.') ? 'legenda' : 'dlouhá vláda');
  }
  saveStats();
  lastAward = n;
  award(n, `vláda ${tenure(h.months)}${state.mods?.length ? ' se ztížením' : ''}`);
}
/// Hodnocení: body za nejdelší vládu, konce, úkoly, volby, krize a zkušenosti.
const RANKS = [[0, 'Nováček'], [30, 'Radní'], [80, 'Ministr'], [160, 'Prezident'], [300, 'Státník'], [500, 'Legenda republiky']];
function rating() {
  const best = Math.max(state?.best ?? 0, stats.top[0]?.score ?? stats.top[0]?.months ?? 0);
  const ends = state?.endings?.length ?? 0;
  const pts = best + 5 * ends + 4 * stats.tasks + 3 * stats.crises + 3 * stats.elections + 2 * Object.keys(stats.ach).length + Math.floor(stats.decisions / 50);
  let i = RANKS.length - 1;
  while (RANKS[i][0] > pts) i--;
  return { pts, rank: RANKS[i][1], from: RANKS[i][0], to: RANKS[i + 1]?.[0] ?? null, next: RANKS[i + 1]?.[1] ?? null, best, ends };
}

// ── Úspěchy ──────────────────────────────────────────
const anyEnd = (pre) => (s) => (s?.endings ?? []).some((e) => e.startsWith(pre));
const ACH = [
  { id: 'prvni', name: 'První krok', text: 'Udělej první rozhodnutí.', ok: () => stats.decisions >= 1 },
  { id: 'rok', name: 'Celý rok', text: 'Vládni aspoň rok.', ok: (s) => s.turn >= 12 },
  { id: 'pet', name: 'Pětiletka', text: 'Vládni 5 let.', ok: (s) => s.turn >= 60 },
  { id: 'deset', name: 'Dekáda', text: 'Vládni 10 let.', ok: (s) => s.turn >= 120 },
  { id: 'dvacet', name: 'Otec národa', text: 'Vládni 20 let.', ok: (s) => s.turn >= 240 },
  { id: 'harmonie', name: 'Harmonie', text: 'Měj všech 7 ukazatelů zároveň mezi 40 a 60 %.', ok: (s) => s.turn > 3 && Object.values(s.meters).every((v) => v >= 40 && v <= 60) },
  { id: 'vlasek', name: 'O vlásek', text: 'Přežij s ukazatelem na 5 % nebo 95 %.', ok: (s) => !s.dead && s.turn > 0 && Object.values(s.meters).some((v) => v <= 5 || v >= 95) },
  { id: 'zakony', name: 'Zákonodárce', text: 'Měj zároveň v platnosti 4 zákony.', ok: (s) => activeLaws(s).length >= 4 },
  { id: 'pratele', name: 'Přátelé na dvoře', text: 'Měj zároveň 3 věrné lidi.', ok: (s) => Object.values(s.rel ?? {}).filter((r) => r >= REL_LOYAL).length >= 3 },
  { id: 'nepratele', name: 'Všichni proti mně', text: 'Měj zároveň 3 nepřátele – a přežij to.', ok: (s) => !s.dead && Object.values(s.rel ?? {}).filter((r) => r <= -REL_LOYAL).length >= 3 },
  { id: 'volby', name: 'Mandát lidu', text: 'Vyhraj volby.', ok: () => stats.elections >= 1 },
  { id: 'volby3', name: 'Věčný prezident', text: 'Vyhraj troje volby jedním vůdcem.', ok: (s) => !s.dead && s.turn >= 144 },
  { id: 'krize', name: 'Krizový štáb', text: 'Zvládni krizi.', ok: () => stats.crises >= 1 },
  { id: 'krize5', name: 'Ostřílený', text: 'Zvládni 5 krizí.', ok: () => stats.crises >= 5 },
  { id: 'vyhoda', name: 'Výhodný obchod', text: 'Vyber si výhodu za splněný úkol.', ok: (s) => (s.perks ?? []).length >= 1 },
  { id: 'pecete', name: 'Pět pečetí', text: 'Získej 5 pečetí.', ok: (s) => seals(s) >= 5 },
  { id: 'zemedelci', name: 'Zemědělci', text: 'V Dějinách lidstva přiveď kmen do starověku.', ok: (s) => s.mode === 'dejiny' && (s.age ?? 7) >= 2 },
  { id: 'dejiny', name: 'Od pazourku ke hvězdám', text: 'Proveď lid všemi dobami až do budoucnosti.', ok: (s) => s.mode === 'dejiny' && (s.age ?? 7) >= 7 },
  { id: 'era3', name: 'Nové hranice', text: 'Doveď svět do třetí éry.', ok: (s) => (s.era ?? 1) >= 3 },
  { id: 'dynastie', name: 'Dynastie', text: 'Doveď republiku k 10. vůdci.', ok: (s) => s.leader.n >= 10 },
  { id: 'konce5', name: 'Sběratel', text: 'Odemkni 5 různých konců.', ok: (s) => (s.endings ?? []).length >= 5 },
  { id: 'konce12', name: 'Kronikář', text: 'Odemkni 12 různých konců.', ok: (s) => (s.endings ?? []).length >= 12 },
  { id: 'legenda', name: 'Legenda', text: 'Dosáhni tajného konce.', ok: anyEnd('x.') },
  { id: 'typy', name: 'Všestranný', text: 'Vládni s 5 různými typy vůdců.', ok: () => stats.kinds.length >= 5 },
  { id: 'blesk30', name: 'Rychlé prsty', text: 'Stihni v bleskovce 30 rozhodnutí.', ok: () => (stats.blitz[0]?.score ?? 0) >= 30 },
  { id: 'blesk60', name: 'Blesk', text: 'Stihni v bleskovce 60 rozhodnutí.', ok: () => (stats.blitz[0]?.score ?? 0) >= 60 },
  { id: 'denni', name: 'Každodenní služba', text: 'Dokonči denní výzvu.', ok: () => Object.keys(stats.daily).length >= 1 },
  { id: 'serie3', name: 'Série', text: 'Hraj denní výzvu 3 dny po sobě.', ok: () => dailyStreak() >= 3 },
];
/** Zkontroluje úspěchy a nové oznámí. */
function checkAch() {
  if (!state) return;
  let got = false;
  for (const a of ACH) {
    if (stats.ach[a.id]) continue;
    let ok = false;
    try { ok = a.ok(state); } catch { ok = false; }
    if (ok) { stats.ach[a.id] = Date.now(); got = true; toast(`Úspěch: ${a.name}`, 'ach'); award(1, 'úspěch'); }
  }
  if (got) saveStats();
}
/** Kolik dní po sobě (do dneška nebo včerejška) hráč dokončil denní výzvu. */
function dailyStreak() {
  const d = new Date();
  const played = (x) => stats.daily[today(x)] != null || stats.daily[`${today(x)}d`] != null;
  if (!played(d)) d.setDate(d.getDate() - 1);
  let n = 0;
  while (played(d)) { n++; d.setDate(d.getDate() - 1); }
  return n;
}

const esc = (t) => String(t).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]);
const ARROW = { left: '←', right: '→', up: '↑', down: '↓' };
const kindName = (k, female) => (female ? k.f : k.m);
const DIR_WORD = { left: 'doleva ←', right: 'doprava →', up: 'nahoru ↑', down: 'dolů ↓' };

/** Výběr typu prezidenta (start i nástupce): řada ikon a pod ní popis vybraného typu. Popis jde i přetáhnout prstem. */
function kindPicker() {
  return `<div class="kinds">${KINDS.map((k) => { const lv = levelOf(stats.xp[k.id]); return `<button class="kind${isUnlocked(k.id) ? '' : ' locked'}" data-k="${k.id}" aria-label="${k.m}">${icon(k.id)}${lv > 1 ? `<i class="lv">${lv}</i>` : ''}</button>`; }).join('')}</div>
    <div class="kdesc" id="kd"></div>`;
}
function bindPicker(root, selected, female, onPick) {
  let cur = selected;
  let look = selected;
  const show = (id) => {
    look = id;
    const k = KINDS.find((x) => x.id === id);
    const open = isUnlocked(id);
    for (const b of root.querySelectorAll('.kind')) { b.classList.toggle('on', b.dataset.k === id && open); b.classList.toggle('peek', b.dataset.k === id && !open); b.classList.toggle('locked', !isUnlocked(b.dataset.k)); }
    const name = female() == null ? k.m.replace('Prezident s rádcem', 'S rádcem') : kindName(k, female());
    const active = ACTIVE.includes(k.id) ? 'Schopnost na tlačítko' : 'Stálá schopnost';
    const d = root.querySelector('.kdesc');
    d.classList.toggle('lockeddesc', !open);
    d.innerHTML = `${icon(k.id, 'ico lg')}<div><b>${name}</b><em>${open ? `${active} · úroveň ${levelOf(stats.xp[k.id])}` : 'Zamčeno'}</em><small>${k.text}${levelOf(stats.xp[k.id]) >= 3 ? ` <b>Mistr:</b> ${MASTERY[k.id]}` : ''}</small>
      ${open ? '' : `<button class="unlock"${stats.points < PRICE ? ' disabled' : ''}>Odemknout za ${PRICE} bodů (máš ${stats.points})</button>`}</div>`;
    d.querySelector('.unlock')?.addEventListener('click', (e) => {
      e.stopPropagation();
      if (stats.points < PRICE) return;
      stats.points -= PRICE;
      stats.unlocked.push(id);
      saveStats();
      sfx('ach');
      toast(`Odemčeno: ${k.m}`, 'ach');
      show(id);
    });
    if (open) { cur = id; onPick(id); }
  };
  for (const b of root.querySelectorAll('.kind')) b.onclick = () => show(b.dataset.k);
  const d = root.querySelector('.kdesc');
  let x0 = null;
  d.onpointerdown = (e) => (x0 = e.clientX);
  d.onpointerup = (e) => {
    if (x0 == null) return;
    const dx = e.clientX - x0, i = KINDS.findIndex((k) => k.id === look);
    x0 = null;
    if (Math.abs(dx) > 40) show(KINDS[(i + (dx < 0 ? 1 : KINDS.length - 1)) % KINDS.length].id);
  };
  show(cur);
  return { refresh: () => show(cur) };
}
const $ = (sel) => app.querySelector(sel);

// ── Úvod ─────────────────────────────────────────────
function startScreen() {
  undoSnap = null;
  document.body.classList.remove('game');
  app.innerHTML = `
    <div class="start">
      <img class="logo" src="icons/icon-192.png" alt="">
      <h1>ROVNOVÁHA</h1>
      <button class="pts" id="shop">${icon('trophy', 'ico sm')} ${stats.points} ${bodu(stats.points)} · obchod</button>
      <p>Veď svůj lid od pravěkého ohně přes hrady a parní stroje až do budoucnosti.
        Udrž sedm sil v rovnováze – ideál je uprostřed, na krajích čeká katastrofa.</p>
      <div class="col">
        ${state ? `<button class="primary" id="cont">Pokračovat – ${esc(state.leader.name)}</button>` : ''}
        <button class="${state ? 'ghost' : 'primary'}" id="new">${state ? 'Nová hra od začátku' : 'Nová hra'}</button>
        <div class="modes grid4">
          <button class="ghost" id="daily">${icon('sun', 'ico sm')}<span><b>Výzvy</b><small>${dailyLabel()}</small></span></button>
          <button class="ghost" id="blitz">${icon('timer', 'ico sm')}<span><b>Bleskovka</b><small>3 minuty na čas</small></span></button>
          <button class="ghost" id="camp">${icon('book', 'ico sm')}<span><b>Kampaň</b><small>${campLabel()}</small></span></button>
          <button class="ghost" id="duel">${icon('people', 'ico sm')}<span><b>Hra pro dva</b><small>na jednom mobilu</small></span></button>
          <button class="ghost" id="dyn">${icon('era', 'ico sm')}<span><b>Dynastie</b><small>úrovně a vylepšení</small></span></button>
          <button class="ghost" id="col">${icon('key', 'ico sm')}<span><b>Sbírka</b><small>postavy, relikvie</small></span></button>
          <button class="ghost" id="stats">${icon('stats', 'ico sm')}<span><b>Statistiky</b><small>a úspěchy</small></span></button>
          <button class="ghost" id="help">${icon('help', 'ico sm')}<span><b>Jak hrát</b><small>pravidla</small></span></button>
        </div>
      </div>
    </div>`;
  app.scrollLeft = 0;
  $('#help').onclick = () => helpScreen(startScreen);
  $('#stats').onclick = () => statsScreen(startScreen);
  $('#blitz').onclick = () => setupScreen('blitz');
  $('#daily').onclick = challengePicker;
  $('#duel').onclick = () => duelSetup({ app, home, sfx, unlocked: stats.unlocked, award });
  $('#shop').onclick = () => shop(startScreen);
  $('#camp').onclick = () => campaignScreen();
  $('#dyn').onclick = () => dynastyScreen(startScreen);
  $('#col').onclick = () => collectionScreen(startScreen);
  if (state?.world === 'dejiny' && (state.age ?? 1) >= 7) {
    const b = document.createElement('button');
    b.className = 'ghost prestige';
    b.innerHTML = `${icon('trophy', 'ico sm')} Prestiž ${ROMAN[(state.prestige ?? 0) + 1]}: znovu od pravěku`;
    b.onclick = prestigeStart;
    $('.start .col').insertBefore(b, $('#new').nextSibling);
  }
  if (state) $('#cont').onclick = () => (state.dead ? deathScreen() : gameScreen());
  $('#new').onclick = setupScreen;
}

/** Nový vůdce: jméno, prezident/prezidentka a typ – vše na jedné obrazovce bez posouvání. */
function setupScreen(mode = 'normal', kind = 'vize') {
  let female = false, world = 'dejiny';
  const blitzMode = mode === 'blitz';
  app.innerHTML = `
    <div class="start setup">
      <h2 class="title">${blitzMode ? 'Bleskovka' : 'Kdo povede tvůj lid?'}</h2>
      ${blitzMode ? '' : `<div class="seg world"><button id="w1" class="on">${icon('era', 'ico sm')} Dějiny lidstva<small>od pravěku do budoucnosti</small></button><button id="w2">${icon('kontakt', 'ico sm')} Rok 2089<small>jen Nová republika</small></button></div>`}
      ${blitzMode ? `<div class="small">Máš ${BLITZ_START / 60} minuty. Každé rozhodnutí přidá ${BLITZ_BONUS} s, pád vlády ${BLITZ_FALL} s ubere. Kolik rozhodnutí stihneš?</div>` : ''}
      <div class="seg"><button id="m" class="on">Vládce</button><button id="f">Vládkyně</button></div>
      ${blitzMode ? '' : `<details class="mods"><summary>${icon('crisis', 'ico sm')} Ztížení za víc bodů <span id="mb"></span></summary>
        <div class="modlist">${Object.entries(MODS).map(([id, m]) => `<button class="mod" data-mod="${id}"><b>${m.name} <em>+${Math.round(m.bonus * 100)} %</em></b><small>${m.text}</small></button>`).join('')}</div></details>`}
      <div class="label">Jaký budeš vůdce?</div>
      <div id="kp">${kindPicker()}</div>
      ${blitzMode ? '' : gearLine()}
      <div class="col">
        <button class="primary" id="go">${blitzMode ? 'Spustit odpočet' : 'Začít vládnout'}</button>
        <button class="ghost" id="back">Zpět</button>
      </div>
    </div>`;
  const picker = bindPicker($('#kp'), kind, () => female, (k) => (kind = k));
  const seg = (f) => { female = f; $('#m').classList.toggle('on', !f); $('#f').classList.toggle('on', f); picker.refresh(); };
  $('#m').onclick = () => seg(false);
  $('#f').onclick = () => seg(true);
  if (!blitzMode) {
    const pick = (w) => { world = w; $('#w1').classList.toggle('on', w === 'dejiny'); $('#w2').classList.toggle('on', w === 'normal'); };
    $('#w1').onclick = () => pick('dejiny');
    $('#w2').onclick = () => pick('normal');
  }
  const mods = new Set();
  for (const b of app.querySelectorAll('.mod')) b.onclick = () => {
    const id = b.dataset.mod;
    if (mods.has(id)) mods.delete(id); else mods.add(id);
    b.classList.toggle('on', mods.has(id));
    const bonus = [...mods].reduce((a, m) => a + MODS[m].bonus, 0);
    $('#mb').textContent = bonus ? `· skóre ×${(1 + bonus).toFixed(2).replace('.', ',')}` : '';
  };
  $('#back').onclick = startScreen;
  $('#go').onclick = () => {
    if (blitzMode) { startBlitz({ female, kind }); return; }
    if (state && !confirm('Opravdu začít znovu? Současná hra i kronika vůdců se smažou (odemčené konce zůstanou).')) return;
    const keep = state ? { endings: state.endings, best: state.best } : null;
    state = newGame({ female, kind, mode: world === 'dejiny' ? 'dejiny' : 'normal', world, mods: [...mods], ...metaFor(kind) }, (Math.random() * 2 ** 32) >>> 0);
    if (keep) Object.assign(state, keep);
    stats.games += 1; saveStats();
    save();
    equip();
    gameScreen();
    if (world === 'dejiny') ageSplash(); else toast(`Úkol: ${taskById(state.task.id).text}`, 'newtask');
  };
}

function dailyLabel() {
  if (Object.keys(CHAL).some((c) => loadDaily(c))) return 'rozehraná – pokračuj';
  const k = KINDS.find((x) => x.id === daily(today()).kind);
  return `dnes: ${k.short}${dailyStreak() > 1 ? ` · série ${dailyStreak()}` : ''}`;
}
/** Výběr výzvy: denní (2089 / Dějiny) a týdenní. */
function challengePicker() {
  const p = document.createElement('div');
  p.className = 'pop';
  const row = (id) => {
    const c = CHAL[id], key = c.key(), best = id === 'week' ? stats.weekly[key] : stats.daily[key], run = loadDaily(id);
    const kind = KINDS.find((x) => x.id === daily(key).kind);
    return `<button class="mi" data-c="${id}">${icon(id === 'week' ? 'era' : 'sun', 'ico')}<span><b>${c.name}</b><small>${c.sub} · ${kind.short}${run ? ' · rozehraná' : best != null ? ` · nejlépe ${tenure(best)}` : ''}</small></span>${icon('chev', 'ico chev')}</button>`;
  };
  p.innerHTML = `
    <div class="pane" role="dialog" aria-label="Výzvy">
      <b class="pane-title">${icon('sun', 'ico')} Výzvy</b>
      <div class="small">Všichni mají ve stejný den (týden) stejný začátek a stejný typ vůdce. Počítá se, jak dlouho vydržíš. Série dní: <b>${dailyStreak()}</b></div>
      <div class="mlist">${Object.keys(CHAL).map(row).join('')}</div>
      ${weekLadder()}
      <button class="ghost" data-x>Zpět</button>
    </div>`;
  p.onclick = (e) => {
    const b = e.target.closest('button');
    if (e.target === p || b?.dataset.x !== undefined) { p.remove(); return; }
    if (b?.dataset.c) { p.remove(); startDaily(b.dataset.c); }
  };
  document.body.appendChild(p);
}
/** Týdenní žebříček: výsledky posledních týdnů a série týdnů v řadě. */
function weekStreak() {
  let n = 0, d = new Date();
  if (stats.weekly[weekKey(d)] == null) d = new Date(Date.now() - 7 * 864e5);
  while (stats.weekly[weekKey(d)] != null) { n += 1; d = new Date(d.getTime() - 7 * 864e5); }
  return n;
}
function weekLadder() {
  const rows = [];
  for (let i = 0; i < 6; i++) { const k = weekKey(new Date(Date.now() - i * 7 * 864e5)); rows.push([k, stats.weekly[k]]); }
  const best = Math.max(1, ...rows.map(([, v]) => v ?? 0));
  return `<div class="label" style="text-align:left">Týdenní žebříček · série ${weekStreak()} ${weekStreak() === 1 ? 'týden' : weekStreak() >= 2 && weekStreak() <= 4 ? 'týdny' : 'týdnů'}</div>
    ${rows.map(([k, v]) => `<div class="past"><span>${k.replace('-T', ', týden ')}${k === weekKey() ? ' (tento)' : ''}</span><span class="wk"><i style="width:${Math.round(((v ?? 0) / best) * 100)}%"></i><b>${v != null ? tenure(v) : '–'}</b></span></div>`).join('')}
    <div class="small">Každé 3 týdny v řadě = 3 body navíc.</div>`;
}
function startDaily(ch = 'd2089') {
  const cont = loadDaily(ch);
  if (cont) { state = cont; gameScreen(); return; }
  const c = CHAL[ch], key = c.key(), d = daily(key), main = load();
  state = newRun({ name: main?.leader?.name ?? '', female: main?.leader?.female ?? false, kind: d.kind, world: c.world }, d.seed, 'daily');
  state.day = key;
  state.chal = ch;
  save();
  gameScreen();
  const k = KINDS.find((x) => x.id === d.kind);
  toast(`${c.name}: ${k.short}. ${c.lives > 1 ? 'Máš tři vládce.' : 'Vydrž co nejdéle!'}`, 'sun');
}
/** Pád vlády ve výzvě: u týdenní výzvy nastoupí další vůdce, dokud nejsou vyčerpaní všichni tři. */
function dailyFall() {
  const c = CHAL[state.chal ?? 'd2089'];
  recordReign();
  if (state.leader.n < c.lives) {
    const d = state.dead;
    nextLeader(state, state.leader.kind);
    save();
    render(true);
    toast(`${d.title} · nastupuje ${state.leader.n}. vůdce ze ${c.lives}`, 'fall');
    return;
  }
  dailyEnd();
}
function dailyEnd() {
  sfx('end');
  const ch = state.chal ?? 'd2089', c = CHAL[ch];
  const d = state.dead, day = state.day;
  const months = c.lives > 1 ? state.history.reduce((a, h) => a + h.months, 0) : d.months;
  const store = ch === 'week' ? stats.weekly : stats.daily;
  const prev = store[day];
  store[day] = Math.max(prev ?? 0, months);
  if (prev == null) award(1, 'výzva dokončena');
  if (ch === 'week' && prev == null && weekStreak() % 3 === 0 && !stats.weekAward[day]) { stats.weekAward[day] = 1; award(3, `série ${weekStreak()} týdnů`); }
  saveStats();
  try { localStorage.removeItem(`${DAILY}.${ch}`); } catch { /* nic */ }
  if (c.lives === 1) recordReign();
  checkAch();
  ui = null;
  document.body.classList.remove('game');
  const m = METERS.find((x) => x.id === d.meter);
  const tomorrow = KINDS.find((x) => x.id === daily(ch === 'week' ? weekKey(new Date(Date.now() + 7 * 864e5)) : CHAL[ch].key().replace(today(), today(new Date(Date.now() + 864e5)))).kind).short;
  app.innerHTML = `
    <div class="sheet">
      <div class="big">${icon(ch === 'week' ? 'era' : 'sun', 'ico xl')}</div>
      <h2 class="legend">${c.name}</h2>
      <div class="score"><b>${tenure(months)}</b><span>${c.lives > 1 ? `${state.history.length} vládci dohromady` : `${esc(d.title)}${m ? ` · ${m.name}` : ''}`}</span></div>
      ${prev == null || months > prev ? `<div class="record">${prev == null ? 'Výsledek zapsán' : 'Nový osobní rekord!'}</div>` : `<div class="small" style="text-align:center">Tvůj nejlepší výsledek: ${tenure(prev)}</div>`}
      <p>${esc(d.text)}</p>
      <div class="stats">
        <div class="stat"><span class="small">Série dní</span><b>${dailyStreak()}</b></div>
        <div class="stat"><span class="small">${ch === 'week' ? 'Příští týden' : 'Zítra'}</span><b>${tomorrow}</b></div>
      </div>
      <button class="primary" id="again">Zkusit znovu</button>
      <button class="ghost" id="home">Hlavní nabídka</button>
    </div>`;
  $('#again').onclick = () => { startDaily(ch); };
  $('#home').onclick = home;
}

/** Body a odemykání vůdců. */
function shop(back) {
  ui = null;
  document.body.classList.remove('game');
  app.innerHTML = `
    <div class="sheet">
      <div class="rankcard">${icon('trophy', 'ico xl')}<h2 class="legend">${stats.points} ${bodu(stats.points)}</h2>
        <div class="small">Za body si odemykáš další vůdce (${PRICE} bodů) a kupuješ vybavení na celou vládu i jednorázové pomůcky.</div></div>
      <h3>Vybavení na celou vládu</h3>
      <div class="small">Nic se neovládá: na začátku tvé příští vlády v hlavní hře se od každého druhu použije jeden kus. Ve výzvách, bleskovce a hře pro dva se nepoužívá.</div>
      <div class="shoplist">${Object.entries(ITEMS).map(([id, it]) => `<div class="shopitem got">${icon(it.icon, 'ico')}<div><b>${it.name}${stats.items[id] ? ` <span class="dim">(máš ${stats.items[id]})</span>` : ''}</b><small>${it.text}</small></div>
        <button class="unlock" data-buy="${id}"${stats.points < it.price ? ' disabled' : ''}>${it.price} b.</button></div>`).join('')}</div>
      <h3>Jednorázové pomůcky</h3>
      <div class="small">Ve hře je použiješ tlačítkem s klíčem v levém horním rohu karty (jen v hlavní hře).</div>
      <div class="shoplist">${Object.entries(TOOLS).map(([id, it]) => `<div class="shopitem got">${icon(it.icon, 'ico')}<div><b>${it.name}${stats.items[id] ? ` <span class="dim">(máš ${stats.items[id]})</span>` : ''}</b><small>${it.text}</small></div>
        <button class="unlock" data-buy="${id}"${stats.points < it.price ? ' disabled' : ''}>${it.price} b.</button></div>`).join('')}</div>
      <h3>Vůdci (${stats.unlocked.length} z ${KINDS.length})</h3>
      <div class="shoplist">${KINDS.map((k) => `<div class="shopitem${isUnlocked(k.id) ? ' got' : ''}">${icon(k.id, 'ico')}<div><b>${k.m}</b><small>${k.text}</small></div>
        ${isUnlocked(k.id) ? '<span class="dim">odemčeno</span>' : `<button class="unlock" data-k="${k.id}"${stats.points < PRICE ? ' disabled' : ''}>${PRICE} b.</button>`}</div>`).join('')}</div>
      <h3>Jak získat body</h3>
      <div class="past"><span>Vláda aspoň 1 rok / 3 roky / 6 let</span><span>1 / 2 / 3</span></div>
      <div class="past"><span>Totéž se ztížením</span><span>dvojnásob</span></div>
      <div class="past"><span>Tajný konec (legenda)</span><span>+3</span></div>
      <div class="past"><span>Splněný úkol, nový úspěch</span><span>1</span></div>
      <div class="past"><span>Dokončená výzva (poprvé za den/týden)</span><span>1</span></div>
      <div class="past"><span>Bleskovka 30 / 60 rozhodnutí</span><span>1 / 2</span></div>
      <div class="past"><span>Vítězství v souboji pro dva</span><span>1</span></div>
      <button class="primary" id="back">Zpět</button>
    </div>`;
  for (const b of app.querySelectorAll('[data-buy]')) b.onclick = () => {
    const it = ITEMS[b.dataset.buy] ?? TOOLS[b.dataset.buy];
    if (stats.points < it.price) return;
    stats.points -= it.price;
    stats.items[b.dataset.buy] = (stats.items[b.dataset.buy] ?? 0) + 1;
    saveStats();
    sfx('good');
    toast(`Koupeno: ${it.name}`, 'perk');
    shop(back);
  };
  for (const b of app.querySelectorAll('.unlock[data-k]')) b.onclick = () => {
    if (stats.points < PRICE) return;
    stats.points -= PRICE;
    stats.unlocked.push(b.dataset.k);
    saveStats();
    sfx('ach');
    toast(`Odemčeno: ${KINDS.find((k) => k.id === b.dataset.k).m}`, 'ach');
    shop(back);
  };
  $('#back').onclick = back;
}

/** Řádek „Do vlády si bereš…“ na obrazovce výběru vůdce. */
function gearLine() {
  const own = Object.keys(ITEMS).filter((id) => stats.items[id]);
  return own.length ? `<div class="gear">${icon('key', 'ico sm')} Do vlády si bereš: ${own.map((id) => `<b>${ITEMS[id].name}</b>`).join(', ')}</div>` : '';
}
/** Na začátku vlády v hlavní hře se od každého druhu vybavení použije jeden kus. */
function equip() {
  state.hints = 0;
  if (!isMain()) return;
  state.meta = { tree: { ...stats.tree }, relics: [...stats.equip] };
  const pred = stats.tree.predkove ?? 0, dech = stats.tree.dech ?? 0;
  if (pred) state.hints = 5 * pred;
  if (dech >= 3) (state.perks ??= []).push('sance');
  else if (dech) { state.dechLeft ??= dech; if (state.dechLeft > 0) { state.dechLeft -= 1; (state.perks ??= []).push('sance'); } }
  const used = [];
  for (const id of Object.keys(ITEMS)) {
    if (!stats.items[id]) continue;
    if (id === 'rada') state.hints = Math.max(state.hints, HINTS);
    if (id === 'stit') (state.perks ??= []).push('sance');
    if (id === 'vyhoda') state.perkOffer = offerPerks(state);
    if (!state.perkOffer && id === 'vyhoda') continue; // není co nabídnout – kus zůstane
    stats.items[id] -= 1;
    if (!stats.items[id]) delete stats.items[id];
    used.push(ITEMS[id].name);
  }
  if (!used.length) return;
  saveStats();
  setTimeout(() => toast(`Vybavení: ${used.join(', ')}`, 'perk'), 600);
}

const toolCount = () => Object.keys(TOOLS).reduce((a, id) => a + (stats.items[id] ?? 0), 0);
function updateBag() {
  const bg = $('#bag');
  if (!bg) return;
  bg.hidden = !toolCount() || !isMain();
  bg.innerHTML = `${icon('key', 'ico sm')}<span>${toolCount()}</span>`;
}
/** Jednorázové pomůcky (jen v hlavní hře – ve výzvách a bleskovce by to nebylo fér). */
function bag() {
  if (busy || state.dead || document.querySelector('.pop')) return;
  const p = document.createElement('div');
  p.className = 'pop';
  p.innerHTML = `
    <div class="pane" role="dialog" aria-label="Pomůcky">
      <b class="pane-title">${icon('key', 'ico')} Pomůcky</b>
      <div class="mlist">${Object.entries(TOOLS).filter(([id]) => stats.items[id]).map(([id, it]) => `
        <button class="mi" data-i="${id}">${icon(it.icon, 'ico')}<span><b>${it.name} ×${stats.items[id]}</b><small>${it.text}</small></span><em class="use">Použít</em></button>`).join('')}</div>
      <button class="ghost" data-x>Zpět</button>
    </div>`;
  p.onclick = (e) => {
    const b = e.target.closest('button');
    if (e.target === p || b?.dataset.x !== undefined) { p.remove(); return; }
    if (b?.dataset.i) useTool(b.dataset.i, p);
  };
  document.body.appendChild(p);
}
function spendTool(id) {
  stats.items[id] -= 1;
  if (!stats.items[id]) delete stats.items[id];
  saveStats();
}
function useTool(id, pop) {
  if (id === 'preskok') {
    const before = { ...state.meters };
    undoSnap = JSON.stringify(state);
    if (!skipCard(state)) { undoSnap = null; toast('Tuhle kartu přeskočit nejde'); return; }
    spendTool(id); pop.remove(); save();
    if (state.dead) { undoSnap = null; recordReign(); deathScreen(); return; }
    render(true); flash(before); toast('Karta přeskočena', 'perk'); showNews(); offerPerk();
  }
  if (id === 'zpet') {
    if (!undoSnap) { toast('Zatím není co vracet'); return; }
    state = JSON.parse(undoSnap);
    undoSnap = null;
    spendTool(id); pop.remove(); save();
    render(true); toast('Tah vrácen – vol znovu', 'perk');
  }
  if (id === 'posun') {
    pop.remove();
    const p = document.createElement('div');
    p.className = 'pop';
    const row = (m) => {
      const v = state.meters[m.id], dn = Math.max(5, v - SHIFT), up = Math.min(95, v + SHIFT);
      return `<div class="shiftrow"><span>${glyph(m.id)} ${m.name} <b>${v} %</b></span>
        <button data-m="${m.id}" data-s="-1"${dn === v ? ' disabled' : ''}>▼ ${dn}</button><button data-m="${m.id}" data-s="1"${up === v ? ' disabled' : ''}>▲ ${up}</button></div>`;
    };
    p.innerHTML = `<div class="pane" role="dialog"><b class="pane-title">${icon('kormidlo', 'ico')} Který ukazatel a kam?</b>
      <div class="shiftlist">${METERS.map(row).join('')}</div>
      <button class="ghost" data-x>Zpět</button></div>`;
    p.onclick = (e) => {
      const b = e.target.closest('button');
      if (e.target === p || b?.dataset.x !== undefined) { p.remove(); return; }
      if (b?.dataset.m) {
        const before = { ...state.meters };
        if (shiftMeter(state, b.dataset.m, Number(b.dataset.s))) { spendTool(id); p.remove(); save(); render(false); flash(before); }
      }
    };
    document.body.appendChild(p);
  }
}

// ── Hra ──────────────────────────────────────────────
let ui = null;       // odkazy na prvky herní obrazovky
let selected = null; // směr vybraný klepnutím na šipku (druhé klepnutí potvrdí)
let busy = false;    // karta právě odlétá

function gameScreen() {
  document.body.classList.add('game');
  window.scrollTo(0, 0); // iOS po zavření klávesnice někdy nechá obrazovku posunutou
  app.innerHTML = `
    <div class="top">
      <button class="burger" id="menu" aria-label="Nabídka"><i></i><i></i><i></i></button>
      <div class="leader"><b id="who"></b><span id="nth"></span></div>
      <button class="ability" id="ab"><svg class="rings" viewBox="0 0 44 44"><circle cx="22" cy="22" r="19" class="ring0"/><circle cx="22" cy="22" r="19" class="ring" pathLength="100"/></svg><i></i></button>
    </div>
    <header class="meters">${METERS.map((m) => `
      <button class="meter" data-m="${m.id}" aria-label="${m.name}">${meterIcon(m.id)}<i class="mbar" data-b="${m.id}"><b></b></i><span class="dot" data-d="${m.id}"></span></button>`).join('')}
    </header>
    <div class="question" id="q"><p></p></div>
    <section class="stage">
      ${['up', 'left', 'right', 'down'].map((d) => `<button class="chev ${d}" data-dir="${d}" aria-label="Volba ${d}">${{ up: '▲', down: '▼', left: '◀', right: '▶' }[d]}</button>`).join('')}
      <button class="bag" id="bag" aria-label="Pomůcky"></button>
      <div class="deck"><div class="card next" id="nextcard"></div><div class="card" id="card"></div></div>
    </section>
    <div class="name"><b><span id="person"></span><span id="mood"></span></b><div class="advice" id="adv"></div></div>`;
  ui = {
    card: $('#card'),
    next: $('#nextcard'),
    q: $('#q'),
    person: $('#person'),
    icons: Object.fromEntries(METERS.map((m) => [m.id, app.querySelector(`.meter:nth-child(${METERS.indexOf(m) + 1}) .micon`)])),
    levels: Object.fromEntries(METERS.map((m) => [m.id, $(`.lvl[data-l="${m.id}"]`)])),
    dots: Object.fromEntries(METERS.map((m) => [m.id, $(`.dot[data-d="${m.id}"]`)])),
    chev: Object.fromEntries([...app.querySelectorAll('.chev')].map((b) => [b.dataset.dir, b])),
  };
  $('#menu').onclick = menu;
  $('#ab').onclick = ability;
  $('#bag').onclick = bag;
  for (const b of app.querySelectorAll('.meter')) b.onclick = () => meterInfo(b.dataset.m);
  for (const b of Object.values(ui.chev)) b.onclick = () => tapDir(b.dataset.dir);
  setupDrag(ui.card);
  render(true);
  offerPerk();
  tips();
}

/** Krátký průvodce při první hře (jen jednou). */
const TIPS = 'rovnovaha.tips';
function tips() {
  // Jen na úplném začátku nové hry a nikdy přes jiné okno.
  if (['blitz', 'daily'].includes(state.mode) || state.total > 1 || document.querySelector('.pop')) return;
  try { if (localStorage.getItem(TIPS)) return; } catch { return; }
  const steps = [
    ['Táhni kartu', 'Každá karta má čtyři volby: doleva, doprava, nahoru a dolů. Při tažení uvidíš, co volba udělá, a tečky ukážou, kterých ukazatelů se dotkne.'],
    ['Sedm ukazatelů', 'Ideál je uprostřed. Když ukazatel spadne na nulu, nebo vystoupá na maximum, vláda končí. Klepnutím na ikonu zjistíš víc.'],
    ['Tvoje schopnost', 'Vpravo nahoře je ikona tvého typu vůdce. Kroužek kolem ní ukazuje nabíjení – když svítí, klepni.'],
    ['Úkoly a nabídka', 'Pod třemi čárkami najdeš Stav republiky (úkol, zákony, volby, lidi), kroniku a statistiky. Hodně štěstí!'],
  ];
  let i = 0;
  const p = document.createElement('div');
  p.className = 'pop tips';
  const show = () => {
    p.innerHTML = `
      <div class="pane" role="dialog">
        <div class="dots">${steps.map((_, j) => `<i class="${j === i ? 'on' : ''}"></i>`).join('')}</div>
        <b class="pane-title">${steps[i][0]}</b>
        <p>${steps[i][1]}</p>
        <button class="primary">${i < steps.length - 1 ? 'Další' : 'Rozumím'}</button>
        ${i < steps.length - 1 ? '<button class="ghost" data-skip>Přeskočit</button>' : ''}
      </div>`;
  };
  p.onclick = (e) => {
    const b = e.target.closest('button');
    if (!b) return;
    if (b.dataset.skip !== undefined || ++i >= steps.length) {
      p.remove();
      try { localStorage.setItem(TIPS, '1'); } catch { /* nic */ }
      return;
    }
    show();
  };
  show();
  document.body.appendChild(p);
}

function render(enter) {
  const l = state.leader;
  $('#who').textContent = l.name;
  const k = kindOf(state);
  $('#nth').textContent = `${l.n}. ${leaderTitle(state)} · ${(state.world ?? state.mode) === 'dejiny' ? `${ageOf(state).name} · ` : ''}Rok ${Math.floor(state.turn / 12) + 1} · ${SEASON_NAMES[seasonOf(state)]}`;
  if (state.mode === 'blitz') updateClock();
  updateBag();
  // Vpravo nahoře: ikona typu vůdce. U aktivních schopností kroužek ukazuje nabití.
  const ab = $('#ab'), active = ACTIVE.includes(k.id);
  if (ab.dataset.k !== k.id) { ab.querySelector('i').innerHTML = icon(k.id); ab.dataset.k = k.id; }
  ab.classList.toggle('active', active);
  ab.querySelector('.ring').style.strokeDasharray = active ? `${(Math.min(state.charge, chargeOf(state)) / chargeOf(state)) * 100} 100` : '0 100';
  ab.classList.toggle('ready', active && ready(state));
  ab.setAttribute('aria-label', kindName(k, l.female));
  const c0 = currentCard(state), chips = [];
  meet(whoOf(state, c0));
  const angry = Object.entries(state.fac ?? {}).filter(([, a]) => a >= FACTION_REVOLT - 2).map(([f]) => FACTIONS[f].name);
  if (angry.length) chips.push(`<span class="warn">${icon('people', 'ico sm')} Neklid: ${angry.join(', ')}</span>`);
  if (state.rush) chips.push(`<span class="warn">${icon('crisis', 'ico sm')} Nečetl{a} jsi – každá volba teď škodí</span>`.replace('{a}', state.leader.female ? 'a' : ''));
  if (state.advice) chips.push(`${icon('rada', 'ico sm')} Rádce radí: <b>${DIR_WORD[state.advice]}</b>`);
  else if (state.hints > 0) {
    const key = `${state.total}:${state.card}`;
    if (state.hint?.key !== key) state.hint = { key, dir: sageHint(state) };
    chips.push(`${icon('rada', 'ico sm')} Mudrc radí: <b>${DIR_WORD[state.hint.dir]}</b> <span class="dim">(ještě ${state.hints}×)</span>`);
  }
  if (c0.crisis) chips.push(`<span class="warn">${icon('crisis', 'ico sm')} ${CRISES[c0.crisis].name} · krok ${CRISES[c0.crisis].steps.indexOf(c0.id) + 1} z ${CRISES[c0.crisis].steps.length}</span>`);
  else if (state.crisis) chips.push(`${icon('crisis', 'ico sm')} Probíhá: ${CRISES[state.crisis.id].name}`);
  if (state.turn > 0 && toElection(state) <= 6) chips.push(`${icon('vote', 'ico sm')} Volby za ${toElection(state)} m. · podpora <b class="${support(state) >= VOTE_MIN ? 'ok' : 'bad'}">${support(state)} %</b>`);
  const nx = state.peek && cardById(state.peek);
  if (nx && seesAhead(state)) chips.push(`${icon('prorok', 'ico sm')} Příště ovlivní: ${touches(state, state.peek).map((k) => glyph(k, 'glyph sm')).join('')}`);
  $('#adv').innerHTML = chips.map((x) => `<span>${x}</span>`).join('');
  for (const m of METERS) {
    const v = state.meters[m.id], d = danger(v);
    ui.levels[m.id].style.transform = `translateY(${((100 - v) * 0.24).toFixed(2)}px)`;
    ui.icons[m.id].classList.toggle('warn', d >= 0.45 && d < 0.7);
    ui.icons[m.id].classList.toggle('bad', d >= 0.7);
    ui.icons[m.id].classList.toggle('edge', d >= 0.82); // blízko kraje: varovné pulzování
    bar(app.querySelector(`.mbar[data-b="${m.id}"]`), v);
    ui.icons[m.id].parentElement.setAttribute('aria-label', `${m.name}: ${v} %`);
  }
  const c = currentCard(state);
  document.body.style.setProperty('--scene', mix(c.person.color, '#0d0c0b', 0.8));
  ui.q.firstElementChild.textContent = c.text;
  ui.person.textContent = c.person.name;
  $('#mood').innerHTML = mood(state.rel?.[c.who] ?? 0, REL_LOYAL);
  // Pod kartou leží další: je vidět, kdo přijde (při tažení se odkryje celá).
  const np = nx ? personOf(state, nx) : null;
  ui.next.parentElement.classList.remove('dragging');
  ui.next.className = 'card next' + (enter ? ' rise' : '');
  const age = state.age ?? 7;
  ui.next.classList.add(`age${age}`);
  ui.next.innerHTML = np ? `${portrait(np, age)}<div class="nextname">${esc(np.name)}</div>` : '';
  const card = ui.card;
  card.className = `card age${age}` + (enter ? ' enter' : '');
  if (enter) shownAt = performance.now();
  app.querySelector('.stage').classList.toggle('rush', !!state.rush);
  card.style.transform = '';
  card.style.opacity = '';
  card.innerHTML = portrait(c.person, age) +
    ['left', 'right', 'up', 'down'].map((d) => {
      // Podmíněná volba, kterou si vláda „odemkla“, je označená klíčem.
      const o = optionOf(state, c, d), special = c.opts[d].need && unlocked(state, c.opts[d]);
      return `<div class="opt ${d}${special ? ' unl' : ''}" data-o="${d}">${special ? icon('key', 'ico sm') : ''}${esc(o.t)}</div>`;
    }).join('');
  ui.opts = Object.fromEntries([...card.querySelectorAll('.opt')].map((o) => [o.dataset.o, o]));
  fitText(ui.q);
  current = null;
  highlight(null, 0);
}

/** Proužek hodnoty pod ikonou: výplň do aktuální hodnoty, ryska uprostřed = ideál, barva podle nebezpečí. */
function bar(el, v) {
  if (!el) return;
  const d = Math.abs(v - 50) / 50;
  el.firstElementChild.style.width = `${v}%`;
  el.className = `mbar${d >= 0.7 ? ' bad' : d >= 0.45 ? ' warn' : ''}`;
}

let flashTimer = 0;
/** Po rozhodnutí se dotčené ukazatele na chvíli obarví: nahoru modře (nebe), dolů zeleně (tráva). */
function flash(before) {
  clearFlash();
  for (const m of METERS) {
    const d = state.meters[m.id] - before[m.id];
    if (!d) continue;
    ui.icons[m.id].classList.add(d > 0 ? 'rise' : 'fall');
    ui.dots[m.id].className = `dot ${d > 0 ? 'rise' : 'fall'}${Math.abs(d) >= 12 ? ' much' : ''}`;
  }
  flashTimer = setTimeout(clearFlash, 1700);
}
function clearFlash() {
  clearTimeout(flashTimer);
  if (!ui) return;
  for (const m of METERS) {
    ui.icons[m.id].classList.remove('rise', 'fall');
    if (!current) ui.dots[m.id].className = 'dot';
  }
}

/** Text se nikdy neposouvá: písmo se zmenší, dokud se celý nevejde. */
function fitText(box) {
  const p = box.firstElementChild;
  let size = 21;
  box.style.fontSize = `${size}px`;
  while (size > 14 && p.scrollHeight > box.clientHeight) {
    size -= 1;
    box.style.fontSize = `${size}px`;
  }
}

let current = null; // směr, který je právě zvýrazněný

/** Zvýrazní volbu: štítek na kartě (průhlednost podle vzdálenosti), šipka a tečky u dotčených ukazatelů. */
function highlight(dir, strength) {
  if (dir !== current) {
    if (dir) clearFlash();
    if (current && ui.opts[current]) ui.opts[current].style.opacity = 0;
    for (const [d, b] of Object.entries(ui.chev)) b.classList.toggle('on', d === dir);
    ui.card.classList.toggle('choosing', !!dir);
    if (dir && seesDirection(state)) {
      // Vizionář vidí směr změny, ne její velikost.
      const after = outcome(state, dir);
      for (const m of METERS) {
        const d = after[m.id] - state.meters[m.id];
        ui.dots[m.id].className = 'dot' + (d > 0 ? ' rise' : d < 0 ? ' fall' : '') + (d && master(state) && Math.abs(d) >= 12 ? ' much' : '');
      }
    } else {
      const pv = dir ? preview(currentCard(state), dir, state) : {};
      for (const m of METERS) ui.dots[m.id].className = 'dot ' + (pv[m.id] || '');
    }
    current = dir;
  }
  if (dir && ui.opts[dir]) ui.opts[dir].style.opacity = String(Math.min(1, strength));
}

function tapDir(dir) {
  if (busy) return;
  if (selected === dir) { selected = null; commit(dir); return; }
  selected = dir;
  highlight(dir, 1);
}

function commit(dir) {
  busy = true;
  const card = ui.card;
  const far = { left: 'translate(-150%, 30px) rotate(-16deg)', right: 'translate(150%, 30px) rotate(16deg)', up: 'translate(0, -140%)', down: 'translate(0, 140%)' }[dir];
  sfx('swipe'); vibrate(8);
  ui.card.parentElement.classList.add('dragging');
  card.className = `card fly age${state.age ?? 7}`;
  card.style.transform = far;
  card.style.opacity = '0';
  selected = null;
  const before = { ...state.meters };
  setTimeout(() => {
    undoSnap = ['normal', 'dejiny'].includes(state.mode) ? JSON.stringify(state) : null;
    if (state.hints > 0) state.hints -= 1;
    const fast = state.mode !== 'blitz' && !['intro', 'dej_intro'].includes(state.card) && performance.now() - shownAt < RUSH_MS;
    const dead = choose(state, dir);
    if (fast && !dead) { state.rush = true; toast('Moc rychle! Nečteš – další karta ti jen uškodí. Veď zemi pořádně.', 'fall'); vibrate([20, 40, 20]); }
    stats.decisions += 1; saveStats();
    if (state.mode === 'blitz') {
      blitz.left += BLITZ_BONUS * 1000;
      state.decisions += 1;
      busy = false;
      if (dead) { blitzFall(dead); checkAch(); return; }
      render(true); flash(before); showNews(); offerPerk(); checkAch();
      return;
    }
    save();
    busy = false;
    if (dead && state.mode === 'daily') { dailyFall(); return; }
    if (state.camp) { if (dead) { campFall(); return; } if (campCheck()) return; }
    if (dead) { undoSnap = null; recordReign(); checkAch(); deathScreen(); } else { render(true); flash(before); showNews(); offerPerk(); checkAch(); }
  }, 220);
}

function setupDrag(card) {
  let sx = 0, sy = 0, dx = 0, dy = 0, t0 = 0, active = false, frame = 0;
  const dirOf = () => (Math.abs(dx) > Math.abs(dy) ? (dx > 0 ? 'right' : 'left') : (dy > 0 ? 'down' : 'up'));
  // Překreslení jen jednou za snímek obrazovky – tažení je plynulé.
  const paint = () => {
    frame = 0;
    // Jedna plynulá funkce pro všechny směry – při změně směru karta neskáče.
    // Svisle jede jen kousek (s měkkým odporem), aby nezakryla ukazatele a tečky nahoře.
    const vy = dy < 0 ? -45 * (1 - Math.exp(dy / 120)) : 90 * (1 - Math.exp(-dy / 170));
    card.style.transform = `translate3d(${dx.toFixed(1)}px, ${vy.toFixed(1)}px, 0) rotate(${(dx / 24).toFixed(2)}deg)`;
    const dist = Math.max(Math.abs(dx), Math.abs(dy));
    highlight(dist > 18 ? dirOf() : null, (dist - 18) / 50);
  };
  card.addEventListener('pointerdown', (e) => {
    if (busy) return;
    active = true; sx = e.clientX; sy = e.clientY; dx = dy = 0; t0 = performance.now();
    selected = null;
    card.className = `card age${state.age ?? 7}`;
    card.parentElement.classList.add('dragging');
    card.setPointerCapture(e.pointerId);
  });
  card.addEventListener('pointermove', (e) => {
    if (!active) return;
    dx = e.clientX - sx; dy = e.clientY - sy;
    if (!frame) frame = requestAnimationFrame(paint);
  });
  const end = () => {
    if (!active) return;
    active = false;
    if (frame) { cancelAnimationFrame(frame); frame = 0; }
    const dist = Math.max(Math.abs(dx), Math.abs(dy));
    const speed = dist / Math.max(1, performance.now() - t0); // px/ms – rychlé švihnutí stačí i na kratší vzdálenost
    if (dist > 90 || (dist > 40 && speed > 0.6)) { commit(dirOf()); return; }
    card.className = `card back age${state.age ?? 7}`;
    card.parentElement.classList.remove('dragging');
    card.style.transform = '';
    highlight(null, 0);
  };
  card.addEventListener('pointerup', end);
  card.addEventListener('pointercancel', end);
}

document.addEventListener('keydown', (e) => {
  const dir = { ArrowLeft: 'left', ArrowRight: 'right', ArrowUp: 'up', ArrowDown: 'down' }[e.key];
  if (dir && ui && document.contains(ui.card) && state && !state.dead && !document.querySelector('.menu, .pop')) { e.preventDefault(); tapDir(dir); }
});

// ── Schopnosti: odložit kartu / posunout ukazatel ─────
const toasts = [];
// ── Zvuk (jemné syntetické tóny, dá se vypnout v nabídce) ──
const SOUND = 'rovnovaha.sound';
let soundOn = (() => { try { return localStorage.getItem(SOUND) !== '0'; } catch { return true; } })();
let actx = null;
function sfx(kind) {
  if (!soundOn) return;
  try {
    actx ??= new (window.AudioContext || window.webkitAudioContext)();
    if (actx.state === 'suspended') actx.resume();
    const t = actx.currentTime;
    const tone = (f, at, dur, vol = 0.05, type = 'sine') => {
      const o = actx.createOscillator(), g = actx.createGain();
      o.type = type; o.frequency.setValueAtTime(f, t + at);
      g.gain.setValueAtTime(0, t + at);
      g.gain.linearRampToValueAtTime(vol, t + at + 0.01);
      g.gain.exponentialRampToValueAtTime(0.0001, t + at + dur);
      o.connect(g).connect(actx.destination);
      o.start(t + at); o.stop(t + at + dur + 0.02);
    };
    if (kind === 'swipe') { tone(520, 0, 0.09, 0.03, 'triangle'); tone(390, 0.05, 0.12, 0.025, 'triangle'); }
    if (kind === 'good') { tone(660, 0, 0.18); tone(880, 0.1, 0.25); }
    if (kind === 'ach') { tone(660, 0, 0.15); tone(880, 0.09, 0.15); tone(1320, 0.18, 0.35); }
    if (kind === 'end') { tone(220, 0, 0.6, 0.06); tone(165, 0.15, 0.9, 0.05); }
    if (kind === 'tick') tone(1200, 0, 0.05, 0.03, 'square');
    if (kind === 'warn') tone(300, 0, 0.2, 0.04, 'sawtooth');
  } catch { /* zvuk není k dispozici */ }
}
const vibrate = (ms) => { try { if (soundOn) navigator.vibrate?.(ms); } catch { /* nic */ } };

function toast(text, kind = '') {
  if (['task', 'crisis', 'election', 'perk', 'rescue', 'era', 'wonder', 'war', 'traitor'].includes(kind)) sfx('good');
  if (kind === 'ach') sfx('ach');
  if (['crisisLost', 'fall', 'electionSoon', 'warLost', 'traitorStrike', 'traitorHint'].includes(kind)) sfx('warn');
  toasts.push({ text, kind });
  if (toasts.length === 1) nextToast();
}
function nextToast() {
  const m = toasts[0];
  if (!m) return;
  const t = document.createElement('div');
  t.className = `toast ${m.kind}`;
  const ic = { law: 'law', task: 'task', era: 'era', crisis: 'crisis', crisisLost: 'crisis', election: 'vote', electionSoon: 'vote', rescue: 'rescue', perk: 'perk', fall: 'crisis', ach: 'trophy', points: 'trophy', sun: 'sun', age: 'era', enemy: 'crisis', friend: 'people', wonder: 'era', war: 'trophy', warLost: 'crisis', rival: 'globe',
    traitor: 'key', traitorHint: 'key', traitorStrike: 'crisis' }[m.kind];
  t.innerHTML = (ic ? icon(ic, 'ico sm') : '') + `<span>${esc(m.text)}</span>`;
  document.body.appendChild(t);
  setTimeout(() => { t.remove(); toasts.shift(); nextToast(); }, m.kind ? 2800 : 1800);
}
/** Zprávy ze hry (zákon, úkol, éra) jako krátké oznámení. */
function showNews() {
  for (const n of state.news ?? []) {
    if (n.kind === 'age') { if (isMain() && Math.random() < 0.4) dropRelic('nová doba'); ageSplash(); continue; }
    toast(n.text, n.kind);
    if (n.kind === 'task') { stats.tasks += 1; if (state.mode !== 'blitz') award(1 + (state.meta?.relics?.includes('kalich') ? 1 : 0), 'splněný úkol'); }
    if (isMain() && n.kind === 'wonder' && Math.random() < 0.5) dropRelic('dílo dokončeno');
    if (n.kind === 'election') stats.elections += 1;
    if (n.kind === 'crisis') stats.crises += 1;
    if (n.kind === 'wonder') stats.wonders = (stats.wonders ?? 0) + 1;
    if (n.kind === 'war') stats.wars = (stats.wars ?? 0) + 1;
    if (n.kind === 'traitor') stats.traitors = (stats.traitors ?? 0) + 1;
  }
  if (state.news?.length) saveStats();
  if (state.news?.length) { state.news = []; save(); }
}

function ability() {
  if (busy || state.dead) return;
  const k = state.leader.kind;
  if (!ACTIVE.includes(k)) { kindInfo(); return; }
  if (!ready(state)) {
    const n = chargeOf(state) - state.charge;
    toast(`Nabije se za ${n} rozhodnutí`);
    return;
  }
  if (k === 'odklad') {
    if (state.card === 'intro') { toast('Úvod odložit nejde'); return; }
    busy = true;
    ui.card.className = `card fly age${state.age ?? 7}`;
    ui.card.style.transform = 'translate(0, 30px) scale(.85)';
    ui.card.style.opacity = '0';
    setTimeout(() => {
      skip(state); save(); busy = false;
      if (state.dead) { if (state.mode === 'blitz') { blitzFall(state.dead); return; } if (state.mode === 'daily') { dailyFall(); return; } recordReign(); deathScreen(); return; }
      render(true); toast('Karta odložena'); showNews(); offerPerk();
    }, 220);
  }
  if (k === 'kormidlo') steerPicker();
  if (k === 'reform') lawPicker();
}

/** Popis schopnosti vůdce (u typů, které se nepoužívají klepnutím). */
function kindInfo() {
  const k = kindOf(state);
  const p = document.createElement('div');
  p.className = 'pop';
  p.innerHTML = `
    <div class="pane" role="dialog">
      <div class="pane-head">${icon(k.id, 'ico lg')}<div><b>${kindName(k, state.leader.female)}</b><span class="dim">Tvoje schopnost</span></div></div>
      <p>${k.text}</p>
      ${perkList()}
      <button class="primary">Zpět do hry</button>
    </div>`;
  p.onclick = (e) => { if (e.target === p || e.target.tagName === 'BUTTON') p.remove(); };
  document.body.appendChild(p);
}

function perkList() {
  const ps = state.perks ?? [];
  return ps.length ? `<div class="label" style="text-align:left">Výhody</div>${ps.map((p) => `<div class="perkrow">${icon('perk', 'ico sm')}<div><b>${PERKS[p].name}</b> – ${PERKS[p].text}</div></div>`).join('')}` : '';
}

/** Po splněném úkolu: vyber jednu ze tří výhod (do konce vlády). */
function offerPerk() {
  if (!state.perkOffer || document.querySelector('.pop.perks')) return;
  const p = document.createElement('div');
  p.className = 'pop perks';
  p.innerHTML = `
    <div class="pane" role="dialog" aria-label="Vyber výhodu">
      <div class="pane-head">${icon('perk', 'ico lg')}<div><b>${state.turn ? 'Úkol splněn!' : 'Výhoda do začátku'}</b><span class="dim">Vyber si jednu výhodu na zbytek vlády</span></div></div>
      <div class="steer">${state.perkOffer.map((id) => `<button class="perk" data-p="${id}"><b>${PERKS[id].name}</b><small>${PERKS[id].text}</small></button>`).join('')}</div>
    </div>`;
  p.onclick = (e) => {
    const b = e.target.closest('button[data-p]');
    if (!b || !choosePerk(state, b.dataset.p)) return;
    p.remove();
    save();
    if (ui) render(false);
    toast(`Výhoda: ${PERKS[b.dataset.p].name}`, 'perk');
    checkAch();
  };
  document.body.appendChild(p);
}

/** Reformátor: zavede, nebo zruší libovolný zákon. */
function lawPicker() {
  const p = document.createElement('div');
  p.className = 'pop';
  const on = activeLaws(state), allowed = Object.keys(LAWS).filter((l) => lawAllowed(state, l) || on.includes(l));
  if (!allowed.length) { toast(`V době „${ageOf(state).name}“ ještě žádné zákony nejsou`); return; }
  const per = (l) => Object.entries(LAWS[l].per).map(([k, v]) => `<span class="${v > 0 ? 'up' : 'down'}">${METERS.find((m) => m.id === k).name} ${v > 0 ? '▲' : '▼'}</span>`).join(' ');
  p.innerHTML = `
    <div class="pane scroll" role="dialog" aria-label="Zákony">
      <b class="pane-title">${icon('reform', 'ico')} Který zákon zavést, nebo zrušit?</b>
      <div class="steer">${allowed.map((l) => `<button data-l="${l}" class="law${on.includes(l) ? ' on' : ''}"><span><b>${LAWS[l].name}</b><small>${per(l)}</small></span><em>${on.includes(l) ? 'Zrušit' : 'Zavést'}</em></button>`).join('')}</div>
      <button class="ghost" data-x>Zatím ne</button>
    </div>`;
  p.onclick = (e) => {
    const b = e.target.closest('button');
    if (e.target === p || b?.dataset.x !== undefined) { p.remove(); return; }
    if (b?.dataset.l && reformLaw(state, b.dataset.l)) { p.remove(); save(); render(false); showNews(); }
  };
  document.body.appendChild(p);
}

/** Kormidelník vybere ukazatel, který posune k rovnováze. */
function steerPicker() {
  const p = document.createElement('div');
  p.className = 'pop';
  const rows = METERS.filter((m) => state.meters[m.id] !== 50).sort((a, b) => danger(state.meters[b.id]) - danger(state.meters[a.id]));
  p.innerHTML = `
    <div class="pane" role="dialog" aria-label="Posunout ukazatel">
      <b class="pane-title">${icon('kormidlo', 'ico')} Který ukazatel posunout k rovnováze?</b>
      <div class="steer">${rows.map((m) => {
        const v = state.meters[m.id], to = v < 50 ? Math.min(50, v + NUDGE) : Math.max(50, v - NUDGE);
        return `<button data-m="${m.id}"><span>${glyph(m.id)} ${m.name}</span><span>${v} % → <b>${to} %</b></span></button>`;
      }).join('') || '<div class="small">Všechno je přesně uprostřed.</div>'}</div>
      <button class="ghost" data-x>Zatím ne</button>
    </div>`;
  p.onclick = (e) => {
    const b = e.target.closest('button');
    if (e.target === p || b?.dataset.x !== undefined) { p.remove(); return; }
    if (b?.dataset.m) steer(b.dataset.m, p);
  };
  document.body.appendChild(p);
}
function steer(id, pop) {
  const before = { ...state.meters };
  if (!nudge(state, id)) return;
  pop.remove();
  save();
  render(false);
  flash(before);
}

// ── Ukazatel: stav, význam a co ho ovlivňuje ─────────
function meterInfo(id) {
  if (busy || document.querySelector('.pop')) return;
  const m = METERS.find((x) => x.id === id), v = state.meters[id], d = danger(v);
  const side = v < 50 ? m.low : m.high;
  const status = d < 0.45 ? ['ok', 'V rovnováze'] : d < 0.7 ? ['warn', `Pozor – blíží se ${side.toLowerCase()}`] : ['bad', `Nebezpečí – hrozí ${side.toLowerCase()}`];
  const p = document.createElement('div');
  p.className = 'pop';
  p.innerHTML = `
    <div class="pane" role="dialog" aria-label="${m.name}">
      <div class="pane-head">${meterIcon(id).replace(/clip-/g, 'pclip-')}<div><b>${m.name}</b><span class="${status[0]}">${status[1]}</span></div><em>${v} %</em></div>
      <div class="scale"><i style="left:${v}%"></i></div>
      <div class="ends"><span>0 % · ${m.low}</span><span>ideál</span><span>${m.high} · 100 %</span></div>
      <p>${m.about}</p>
      <dl><dt>Zvyšuje</dt><dd>${m.up}</dd><dt>Snižuje</dt><dd>${m.down}</dd>${(() => {
        const laws = activeLaws(state).filter((l) => LAWS[l].per[id]);
        return laws.length ? `<dt>Zákony</dt><dd>${laws.map((l) => `${LAWS[l].name} ${LAWS[l].per[id] > 0 ? '<span class="up">▲</span>' : '<span class="down">▼</span>'}`).join(', ')}</dd>` : '';
      })()}</dl>
      ${state.leader.kind === 'kormidlo' && ready(state) && v !== 50 ? `<button class="steer1">${icon('kormidlo', 'ico sm')} Posunout k rovnováze o ${NUDGE}</button>` : ''}
      <button class="primary">Zpět do hry</button>
    </div>`;
  p.querySelector('.steer1')?.addEventListener('click', (e) => { e.stopPropagation(); steer(id, p); });
  p.querySelector('.lvl').style.transform = `translateY(${((100 - v) * 0.24).toFixed(2)}px)`;
  p.onclick = (e) => { if (e.target === p || e.target.tagName === 'BUTTON') p.remove(); };
  document.body.appendChild(p);
}

// ── Nabídka (tři čárky) ──────────────────────────────
function menu() {
  const m = document.createElement('div');
  m.className = 'menu';
  const bl = state.mode === 'blitz';
  const item = (a, ic, label, sub = '') => `<button class="mi" data-a="${a}">${icon(ic, 'ico')}<span><b>${label}</b>${sub ? `<small>${sub}</small>` : ''}</span>${a === 'sound' ? `<i class="sw${soundOn ? ' on' : ''}"></i>` : icon('chev', 'ico chev')}</button>`;
  m.innerHTML = `
    <div class="sheetmenu" role="dialog" aria-label="Nabídka">
      <div class="grab"></div>
      <div class="mhead"><img src="icons/icon-192.png" alt=""><div><b>${esc(state.leader.name)}</b><small>${state.leader.n}. ${leaderTitle(state)}${(state.world ?? state.mode) === 'dejiny' ? ` · ${ageOf(state).name}` : ''}</small></div></div>
      <button class="primary mplay" data-a="back">${icon('play', 'ico')} ${bl ? 'Pokračovat (čas stojí)' : 'Zpět do hry'}</button>
      <div class="mlist">
        ${item('realm', 'globe', 'Stav republiky', 'úkol, zákony, lidé, volby')}
        ${bl ? '' : item('chron', 'book', 'Kronika a konce', 'vůdci a odemčené konce')}
        ${bl ? '' : item('stats', 'trophy', 'Statistiky a úspěchy', 'hodnocení a rekordy')}
        ${item('help', 'help', 'Jak hrát')}
        ${item('sound', soundOn ? 'sound' : 'mute', 'Zvuk a vibrace')}
        ${bl ? item('endblitz', 'timer', 'Ukončit bleskovku') : item('start', 'home', 'Hlavní nabídka')}
      </div>
      <div class="small mnote">${bl ? 'Bleskovka se neukládá. Tvoje hlavní hra zůstává, jak byla.' : state.mode === 'daily' ? 'Denní výzva se ukládá zvlášť – můžeš ji kdykoli dohrát.' : 'Hra se ukládá sama po každém rozhodnutí.'}</div>
    </div>`;
  m.onclick = (e) => {
    const b = e.target.closest('button'), a = b?.dataset.a;
    if (!a && e.target !== m) return;
    if (a === 'sound') {
      soundOn = !soundOn;
      try { localStorage.setItem(SOUND, soundOn ? '1' : '0'); } catch { /* nic */ }
      b.querySelector('.sw').classList.toggle('on', soundOn);
      b.querySelector('.ico').outerHTML = icon(soundOn ? 'sound' : 'mute', 'ico');
      sfx('good');
      return;
    }
    m.remove();
    if (a === 'chron') chronicleScreen(gameScreen);
    if (a === 'realm') realmScreen(gameScreen);
    if (a === 'help') helpScreen(gameScreen);
    if (a === 'stats') statsScreen(gameScreen);
    if (a === 'endblitz') endBlitz();
    if (a === 'start') home();
  };
  document.body.appendChild(m);
}

// ── Konec vlády ──────────────────────────────────────
function deathScreen() {
  undoSnap = null;
  sfx('end'); vibrate([30, 60, 30]);
  ui = null;
  document.body.classList.remove('game');
  const d = state.dead, l = state.leader, m = METERS.find((x) => x.id === d.meter);
  const total = 15 + Object.keys(SPECIAL).length;
  const why = d.special ? 'Tajný konec – legenda' : d.election ? `Podpora Lidu a Spojenců klesla pod ${VOTE_MIN} %` : `Ukazatel ${m.name} ${d.side === 'low' ? 'klesl na nulu' : 'vystoupal na maximum'}`;
  app.innerHTML = `
    <div class="sheet">
      <div class="big">${d.special ? icon(d.special, 'ico xl') : d.election ? icon('vote', 'ico xl bad') : glyph(m.id, 'glyph xl')}</div>
      <h2 class="${d.special ? 'legend' : ''}">${esc(d.title)}</h2>
      <div class="small" style="text-align:center">${why}</div>
      <p>${esc(d.text)}</p>
      <div class="stats">
        <div class="stat"><span class="small">${l.female ? 'Vládla' : 'Vládl'}</span><b>${tenure(d.months)}</b>${state.mods?.length ? `<span class="small">skóre ${d.score} (×${modBonus(state).toFixed(2).replace('.', ',')})</span>` : ''}</div>
        <div class="stat"><span class="small">Nejdelší vláda</span><b>${tenure(state.best)}</b></div>
        <div class="stat"><span class="small">Vůdců republiky</span><b>${l.n}</b></div>
        <div class="stat"><span class="small">Odemčené konce</span><b>${state.endings.length} z ${total}</b></div>
        <div class="stat"><span class="small">Získané body</span><b>${lastAward ? `+${lastAward}` : '0'}</b><span class="small">celkem ${stats.points}</span></div>
        <div class="stat"><span class="small">Vůdci</span><b>${stats.unlocked.length} z ${KINDS.length}</b><span class="small">další za ${PRICE} bodů</span></div>
      </div>
      <div class="label">Jaký bude nástupce?</div>
      <div id="kp">${kindPicker()}</div>
      ${gearLine()}
      <button class="primary" id="next">Úřad přebírá nástupce</button>
      <div class="row2"><button class="ghost" id="chron">Kronika</button><button class="ghost" id="tohome">Hlavní nabídka</button></div>
    </div>`;
  $('#tohome').onclick = startScreen;
  let kind = l.kind;
  bindPicker($('#kp'), kind, () => null, (k) => (kind = k));
  $('#next').onclick = () => { nextLeader(state, kind, levelOf(stats.xp[kind])); equip(); save(); gameScreen(); toast(`Úkol: ${taskById(state.task.id).text}`, 'newtask'); };
  $('#chron').onclick = () => chronicleScreen(deathScreen);
}

/** Frakce, stavby, čekající důsledky, úroveň vůdce a prestiž. */
function depthBox() {
  const fac = Object.entries(FACTIONS).map(([f, x]) => {
    const a = state.fac?.[f] ?? 0, pct = Math.round((a / FACTION_REVOLT) * 100);
    return `<div class="past"><span>${glyph(x.m, 'glyph sm')} ${x.name}</span><span class="facbar"><i class="${a >= FACTION_REVOLT - 2 ? 'bad' : ''}" style="width:${Math.min(100, pct)}%"></i></span></div>`;
  }).join('');
  const lv = state.leader.lvl ?? 1;
  return `<h3>${icon('people', 'ico')} Frakce</h3>
    <div class="small">Když jejich ukazatel dlouho klesá, roste jejich hněv. Plný pruh = vzpoura.</div>${fac}
    <h3>${icon('law', 'ico')} Velké stavby</h3>
    <div class="small">${state.project ? `Staví se: <b>${PROJECTS[state.project.id].name}</b> – hotovo za ${state.project.left} m. (každý měsíc stojí zásoby).` : 'Nic se nestaví. Nabídka stavby přijde na začátku vlády.'}
    ${state.built?.length ? `<br>Hotovo: ${state.built.map((b) => `<b>${PROJECTS[b].name}</b>`).join(', ')} – drží svůj ukazatel u rovnováhy.` : ''}</div>
    ${(state.later ?? []).length ? `<div class="small">${icon('crisis', 'ico sm')} Na zemi čeká ${(state.later ?? []).length}× důsledek dřívějších rozhodnutí.</div>` : ''}
    ${state.echoes?.length ? `<h3>${icon('book', 'ico')} Ozvěny minulosti</h3>${state.echoes.slice(-4).reverse().map((e) => `<div class="small">• ${esc(e.text)}</div>`).join('')}` : ''}
    <div class="small">Vůdce: úroveň ${lv}${lv >= 3 ? ` (mistr: ${MASTERY[state.leader.kind]})` : ''}${state.prestige ? ` · Prestiž ${ROMAN[state.prestige]}` : ''}${state.meta?.relics?.length ? ` · Relikvie: ${state.meta.relics.map((r) => RELICS[r].name).join(', ')}` : ''}</div>`;
}

/** Sousední říše, divy světa, cesta dějin, zrádce a ztížení. */
function worldBox() {
  const age = state.age ?? 7, out = [];
  if (age < 7 && RIVALS[age]) {
    const r = state.rival ?? { power: 30 }, mood = state.rel?.riv ?? 0;
    out.push(`<h3>${icon('globe', 'ico')} Sousední říše</h3>
      ${r.absorbed ? '<div class="small">Sousední říše se s tou tvou spojila. V této době už žádného soupeře nemáš.</div>' : `
      <div class="box"><div class="past"><span>${RIVALS[age].name}</span><span>${mood >= 3 ? 'spojenec' : mood <= -3 ? 'nepřítel' : mood > 0 ? 'přátelský' : mood < 0 ? 'nevraživý' : 'neutrální'}</span></div>
      <div class="small">Síla soupeře</div><div class="bar"><i style="width:${Math.round(r.power)}%;background:${r.power > 60 ? 'var(--bad)' : 'var(--accent)'}"></i></div>
      <div class="small">${r.power > 60 ? 'Soused je mocný – může žádat tribut nebo zaútočit.' : r.power < 25 ? 'Soused slábne – možná ho půjde pohltit.' : 'Válku vyhraje ten, kdo má víc Síly.'}</div></div>`}`);
  }
  const branches = Object.keys(BRANCHES).filter((f) => state.flags.includes(f));
  if (branches.length) out.push(`<h3>${icon('era', 'ico')} Cesta dějin</h3><div class="small">${branches.map((f) => BRANCHES[f]).join(' → ')}</div>`);
  const built = state.wonders ?? [], building = WONDERS.filter((w) => state.flags.includes(`stavba_${w.id}`));
  if (built.length || building.length) {
    out.push(`<h3>${icon('trophy', 'ico')} Divy světa</h3>${built.map((id) => { const w = WONDERS.find((x) => x.id === id); return `<div class="past"><span>${w.name}</span><span>drží ${METERS.find((m) => m.id === w.m).name}</span></div>`; }).join('')}
      ${building.map((w) => `<div class="past"><span>${w.name}</span><span>staví se…</span></div>`).join('')}`);
  }
  if (state.traitor && !state.traitor.known) out.push(`<h3>${icon('key', 'ico')} Zrada</h3><div class="small">Někdo z tvých blízkých vynáší tajemství. Když ho včas neodhalíš, zradí tě. Poslouchej, co ti řeknou vyšetřovatelé.</div>`);
  if (state.mods?.length) out.push(`<h3>${icon('crisis', 'ico')} Ztížení (skóre ×${modBonus(state).toFixed(2).replace('.', ',')})</h3><div class="small">${state.mods.map((m) => MODS[m].name).join(', ')}</div>`);
  return out.join('');
}

/** Cesta dějinami: kde svět je a jak daleko je další přelom. */
function timeline() {
  const a = state.age ?? 7, done = Math.min(AGE_LEN, state.total - (state.ageStart ?? 0));
  return `<h3>${icon('era', 'ico')} Doba: ${ageOf(state).name}</h3>
    <div class="ages">${AGES.map((x) => `<span class="${x.n < a ? 'done' : x.n === a ? 'now' : ''}" title="${x.name}"><i></i></span>`).join('')}</div>
    <div class="ageends"><span>Pravěk</span><span>Budoucnost</span></div>
    ${a < 7 ? `<div class="bar"><i style="width:${Math.round((done / AGE_LEN) * 100)}%"></i></div>
    <div class="small">${done < AGE_LEN ? `Do přelomového objevu zbývá asi ${AGE_LEN - done} rozhodnutí.` : 'Přelomový objev je na spadnutí – když ho přijmeš, svět se posune do další doby.'}</div>` : '<div class="small">Dějiny dorazily do budoucnosti.</div>'}`;
}

/** Úvod nové doby: co se změnilo. */
function ageSplash() {
  if (document.querySelector('.agesplash')) return;
  const a = ageOf(state);
  const what = {
    1: 'Žádné zákony, žádné volby. Jen kmen, zvěř a duchové předků. Až přijde objev zemědělství, můžeš svět posunout dál.',
    2: 'Města, chrámy a první zákony. Vládneš jako král nebo královna – a lid čeká chléb a hry.',
    3: 'Hrady, církev a rytíři. Pozor na mor a na kazatele.',
    4: 'Lodě, parní stroje a revoluce. Lidé chtějí práva.',
    5: 'Republika! Od teď se každé 4 roky volí – hlasy ti dají Lid a Spojenci.',
    6: 'Internet, sítě a oteplování planety. Svět se zrychluje.',
    7: 'Velký výpadek změnil všechno. Vítej v Nové republice roku 2089 – éry, zákony, krize i tajné příběhy.',
  }[a.n];
  sfx('good');
  const p = document.createElement('div');
  p.className = 'pop tips agesplash';
  p.innerHTML = `
    <div class="pane" role="dialog">
      ${icon('era', 'ico xl')}
      <div class="small">${a.when}</div>
      <b class="pane-title">${a.n === 1 ? 'Začíná' : 'Nová doba'}: ${a.name}</b>
      <p>${a.text}</p>
      <p class="dim">${what}</p>
      <button class="primary">Vládnout</button>
    </div>`;
  p.onclick = (e) => { if (e.target.closest('button')) { p.remove(); if (ui) { render(false); tips(); } } };
  document.body.appendChild(p);
}

// ── Stav republiky: éra, úkol, zákony, lidé ──────────
function realmScreen(back) {
  ui = null;
  document.body.classList.remove('game');
  const t = taskById(state.task?.id), p = taskProgress(state);
  const era = ERAS[(state.era ?? 1) - 1], nextEra = ERAS[state.era ?? 1];
  const laws = activeLaws(state);
  const people = Object.entries(state.rel ?? {}).filter(([, r]) => r !== 0).sort((a, b) => b[1] - a[1]);
  const per = (l) => Object.entries(LAWS[l].per).map(([k, v]) => `<span class="${v > 0 ? 'up' : 'down'}">${METERS.find((m) => m.id === k).name} ${v > 0 ? '▲' : '▼'}</span>`).join(' ');
  app.innerHTML = `
    <div class="sheet realm">
      ${(state.world ?? state.mode) === 'dejiny' ? timeline() : ''}
      ${worldBox()}
      ${depthBox()}
      ${(state.age ?? 7) >= 7 ? `<h3>${icon('era', 'ico')} Éra: ${era.name}</h3>
      <div class="small">${nextEra ? `Další éra „${nextEra.name}“ přijde s časem${nextEra.seals ? ` a se ${nextEra.seals} pečetěmi (máš ${seals(state)})` : ''}.` : 'Svět dosáhl poslední éry.'}</div>` : ''}
      <h3>${icon('task', 'ico')} Úkol vůdce</h3>
      ${t ? `<div class="box"><p>${esc(t.text)}</p><div class="bar"><i style="width:${Math.round((p.now / p.of) * 100)}%"></i></div><div class="small">${p.now} / ${p.of}</div></div>` : '<div class="small">Žádný úkol.</div>'}
      <div class="small">Pečetě (splněné úkoly): <b>${seals(state)} z ${TASKS.length}</b>. Splněný úkol hned nabije schopnost a dá ti vybrat výhodu.</div>
      ${hasElections(state) ? `<h3>${icon('vote', 'ico')} Volby</h3>
      <div class="small">Další volby za ${toElection(state)} ${toElection(state) === 1 ? 'měsíc' : toElection(state) < 5 ? 'měsíce' : 'měsíců'}. Podpora (průměr Lidu a Spojenců): <b class="${support(state) >= VOTE_MIN ? 'ok' : 'bad'}">${support(state)} %</b>, potřebuješ aspoň ${VOTE_MIN} %.</div>` : ''}
      ${state.crisis ? `<h3>${icon('crisis', 'ico')} Krize</h3><div class="small">${CRISES[state.crisis.id].name}: krok ${state.crisis.step} z ${CRISES[state.crisis.id].steps.length} za tebou, zvládnuto ${state.crisis.score}. K úspěchu potřebuješ zvládnout ${CRISES[state.crisis.id].good}.</div>` : ''}
      ${state.perks?.length ? `<h3>${icon('perk', 'ico')} Výhody</h3>${perkList().replace(/<div class="label"[^>]*>Výhody<\/div>/, '')}` : ''}
      ${(state.age ?? 7) < 7 && !laws.length ? '' : `<h3>${icon('law', 'ico')} Zákony (${laws.length})</h3>
      ${laws.length ? laws.map((l) => `<div class="past"><span>${LAWS[l].name}</span><span class="per">${per(l)} / měsíc</span></div>`).join('') : '<div class="small">Žádný zákon zatím neplatí. Návrhy zákonů ti přinesou ministři.</div>'}`}
      <h3>${icon('people', 'ico')} Lidé</h3>
      ${people.length ? people.map(([who, r]) => `<div class="past"><span>${esc(PEOPLE[who]?.name ?? who)} ${mood(r, REL_LOYAL)}</span><span class="rel"><i style="width:${(Math.abs(r) / 5) * 50}%;${r > 0 ? 'left:50%' : `right:50%`}" class="${r > 0 ? 'pos' : 'neg'}"></i></span></div>`).join('') : '<div class="small">Zatím si o tobě nikdo neudělal názor.</div>'}
      <button class="primary" id="back">Zpět</button>
    </div>`;
  $('#back').onclick = back;
}

// ── Kronika ──────────────────────────────────────────
function chronicleScreen(back) {
  ui = null;
  document.body.classList.remove('game');
  const past = [...state.history].reverse();
  const ends = METERS.flatMap((m) => ['low', 'high'].map((s) => ({ key: `${m.id}.${s}`, m, s, e: ENDINGS[m.id][s] })));
  const total = ends.length + 1 + Object.keys(SPECIAL).length;
  app.innerHTML = `
    <div class="sheet">
      <h3>Vůdci republiky</h3>
      ${past.length ? past.map((h) => `<div class="past"><span>${h.n}. ${esc(h.name)}</span><span>${tenure(h.months)} · ${esc(h.title)}</span></div>`).join('')
        : '<div class="small">Zatím nikdo nepadl. Vládni dlouho!</div>'}
      <h3>Konce (${state.endings.length} z ${total})</h3>
      <div class="endings">${ends.map(({ key, m, s, e }) => `
        <div class="ending ${state.endings.includes(key) ? '' : 'locked'}">
          <b>${glyph(m.id)} ${state.endings.includes(key) ? esc(e.title) : '???'}</b>${m.name} ${s === 'low' ? 'na nule' : 'na maximu'}
        </div>`).join('')}
        <div class="ending ${state.endings.includes('volby') ? '' : 'locked'}"><b>${icon('vote', 'ico sm')} ${state.endings.includes('volby') ? ELECTION.title : '???'}</b>Volby každé 4 roky</div>
      </div>
      <h3>Tajné konce</h3>
      <div class="endings">${Object.entries(SPECIAL).map(([id, e]) => {
        const got = state.endings.includes(`x.${id}`);
        return `<div class="ending ${got ? 'legend' : 'locked'}"><b>${got ? icon(id, 'ico sm') : ''} ${got ? esc(e.title) : '???'}</b>${got ? 'Legenda' : 'Skrytý příběh'}</div>`;
      }).join('')}</div>
      <button class="primary" id="back">Zpět</button>
    </div>`;
  $('#back').onclick = back;
}

// ── Bleskovka ────────────────────────────────────────
let blitz = null; // {left: ms, last: čas posledního tiku, id: interval}
function startBlitz(opts) {
  if (blitz) clearInterval(blitz.id);
  state = newBlitz(opts, (Math.random() * 2 ** 32) >>> 0);
  blitz = { left: BLITZ_START * 1000, last: performance.now(), id: setInterval(tickBlitz, 200), kind: opts.kind, female: opts.female, name: opts.name };
  gameScreen();
}
function tickBlitz() {
  const now = performance.now(), dt = now - blitz.last;
  blitz.last = now;
  // Čas stojí v nabídce, v oknech, mimo herní obrazovku a když je aplikace na pozadí.
  if (document.hidden || !ui || document.querySelector('.pop, .menu')) return;
  blitz.left -= dt;
  updateClock();
  if (blitz.left <= 0) endBlitz();
}
function updateClock() {
  const el = $('#nth');
  if (!el || !blitz) return;
  const sec = Math.max(0, Math.ceil(blitz.left / 1000));
  el.textContent = `${Math.floor(sec / 60)}:${String(sec % 60).padStart(2, '0')} · ${state.decisions} rozhodnutí`;
  el.classList.toggle('hurry', sec <= 15);
  if (sec <= 10 && sec !== blitz.lastTick) { blitz.lastTick = sec; sfx('tick'); }
}
/** Pád vlády v bleskovce: hned nastupuje další, ale stojí to čas. */
function blitzFall(d) {
  blitz.left -= BLITZ_FALL * 1000;
  toast(`${d.title} · −${BLITZ_FALL} s, vládu přebírá nástupce`, 'fall');
  nextLeader(state, state.leader.kind);
  render(true);
  if (blitz.left <= 0) endBlitz();
}
function endBlitz() {
  if (!blitz) return;
  clearInterval(blitz.id);
  const timeUp = blitz.left <= 0;
  const run = { score: state.decisions, months: state.total, leaders: state.leader.n, kind: state.leader.kind, date: Date.now() };
  const prev = stats.blitz[0]?.score ?? 0;
  stats.blitz = [...stats.blitz, run].sort((a, b) => b.score - a.score).slice(0, 10);
  award(run.score >= 60 ? 2 : run.score >= 30 ? 1 : 0, `bleskovka ${run.score} rozhodnutí`);
  saveStats();
  checkAch();
  const place = stats.blitz.indexOf(run) + 1;
  const again = { kind: blitz.kind };
  blitz = null;
  ui = null;
  for (const x of document.querySelectorAll('.pop, .menu')) x.remove();
  document.body.classList.remove('game');
  state = load(); // zpět k hlavní hře
  app.innerHTML = `
    <div class="sheet">
      <div class="big">${icon('timer', 'ico xl')}</div>
      <h2 class="legend">${timeUp ? 'Čas vypršel' : 'Bleskovka ukončena'}</h2>
      <div class="score"><b>${run.score}</b><span>rozhodnutí</span></div>
      ${run.score > prev ? '<div class="record">Nový rekord!</div>' : place > 0 ? `<div class="small" style="text-align:center">${place}. místo v tvých bleskovkách</div>` : ''}
      <div class="stats">
        <div class="stat"><span class="small">Uplynulo</span><b>${tenure(run.months)}</b></div>
        <div class="stat"><span class="small">Vůdců</span><b>${run.leaders}</b></div>
        <div class="stat"><span class="small">Rekord</span><b>${stats.blitz[0].score}</b></div>
        <div class="stat"><span class="small">Typ</span><b>${KINDS.find((k) => k.id === run.kind)?.short ?? ''}</b></div>
      </div>
      <button class="primary" id="again">Hrát znovu</button>
      <button id="st">Statistiky</button>
      <button class="ghost" id="home">Hlavní nabídka</button>
    </div>`;
  $('#again').onclick = () => setupScreen('blitz', again.kind);
  $('#st').onclick = () => statsScreen(startScreen);
  $('#home').onclick = home;
}

// ── Statistiky a hodnocení ───────────────────────────
function statsScreen(back) {
  ui = null;
  document.body.classList.remove('game');
  const r = rating();
  const pct = r.to ? Math.round(((r.pts - r.from) / (r.to - r.from)) * 100) : 100;
  const avg = stats.reigns ? Math.round(stats.months / stats.reigns) : 0;
  const total = 15 + Object.keys(SPECIAL).length;
  const endName = (key) => {
    if (key === 'volby') return ELECTION.title;
    if (key.startsWith('x.')) return SPECIAL[key.slice(2)]?.title ?? key;
    const [m, side] = key.split('.');
    return ENDINGS[m]?.[side]?.title ?? key;
  };
  const common = Object.entries(stats.ends).sort((a, b) => b[1] - a[1]).slice(0, 3);
  const date = (t) => new Date(t).toLocaleDateString('cs-CZ', { day: 'numeric', month: 'numeric' });
  app.innerHTML = `
    <div class="sheet">
      <div class="rankcard">
        ${icon('trophy', 'ico xl')}
        <div class="small">Tvoje hodnocení</div>
        <h2 class="legend">${r.rank}</h2>
        <div class="small">${r.pts} bodů</div>
        <div class="bar"><i style="width:${pct}%"></i></div>
        <div class="small">${r.next ? `Do hodnosti ${r.next} chybí ${r.to - r.pts} bodů` : 'Nejvyšší hodnost – víc už nejde.'}</div>
      </div>
      <div class="stats">
        <div class="stat"><span class="small">Nejdelší vláda</span><b>${r.best ? tenure(r.best) : '–'}</b></div>
        <div class="stat"><span class="small">Průměrná vláda</span><b>${stats.reigns ? tenure(avg) : '–'}</b></div>
        <div class="stat"><span class="small">Vůdců celkem</span><b>${stats.reigns}</b></div>
        <div class="stat"><span class="small">Rozhodnutí</span><b>${stats.decisions}</b></div>
        <div class="stat"><span class="small">Splněné úkoly</span><b>${stats.tasks}</b></div>
        <div class="stat"><span class="small">Vyhrané volby</span><b>${stats.elections}</b></div>
        <div class="stat"><span class="small">Zvládnuté krize</span><b>${stats.crises}</b></div>
        <div class="stat"><span class="small">Odemčené konce</span><b>${r.ends} z ${total}</b></div>
      </div>
      <div class="small">Body: nejdelší vláda v měsících + 5 za každý konec + 4 za úkol + 3 za vyhrané volby a zvládnutou krizi + 2 za úspěch + 1 za každých 50 rozhodnutí.</div>
      <h3>${icon('trophy', 'ico')} Úspěchy (${Object.keys(stats.ach).length} z ${ACH.length})</h3>
      <div class="achs">${ACH.map((a) => `<div class="ach${stats.ach[a.id] ? ' got' : ''}">${icon(stats.ach[a.id] ? 'trophy' : 'key', 'ico sm')}<div><b>${a.name}</b><small>${a.text}</small></div></div>`).join('')}</div>
      <h3>${icon('trophy', 'ico')} Nejdelší vlády</h3>
      ${stats.top.length ? `<table class="board"><tbody>${stats.top.map((t, i) => `
        <tr><td class="n">${i + 1}.</td><td>${t.kind ? icon(t.kind, 'ico sm') : ''} ${esc(t.name)}<small>${esc(t.title)}</small></td><td class="r">${tenure(t.months)}${t.mods ? `<small>skóre ${t.score}</small>` : ''}</td></tr>`).join('')}</tbody></table>`
        : '<div class="small">Zatím žádná dokončená vláda.</div>'}
      ${common.length ? `<h3>Nejčastější konce</h3>${common.map(([k, n]) => `<div class="past"><span>${esc(endName(k))}</span><span>${n}×</span></div>`).join('')}` : ''}
      <h3>${icon('sun', 'ico')} Denní výzva</h3>
      ${Object.keys(stats.daily).length ? `<div class="small">Série: <b>${dailyStreak()}</b> ${dailyStreak() === 1 ? 'den' : dailyStreak() < 5 && dailyStreak() > 0 ? 'dny' : 'dní'} po sobě · odehráno dní: ${Object.keys(stats.daily).length}</div>
        <table class="board"><tbody>${Object.entries(stats.daily).sort((a, b) => b[0].localeCompare(a[0])).slice(0, 7).map(([d, mo]) => `
        <tr><td>${d.split('-').reverse().slice(0, 2).map(Number).join('. ')}.</td><td class="r">${tenure(mo)}</td></tr>`).join('')}</tbody></table>`
        : '<div class="small">Každý den nová výzva: všichni mají stejný typ vůdce a stejný začátek. Najdeš ji v hlavní nabídce.</div>'}
      <h3>${icon('timer', 'ico')} Bleskovka</h3>
      ${stats.blitz.length ? `<table class="board"><tbody>${stats.blitz.slice(0, 5).map((b, i) => `
        <tr><td class="n">${i + 1}.</td><td>${icon(b.kind, 'ico sm')} ${b.score} rozhodnutí<small>${tenure(b.months)} · ${b.leaders} ${b.leaders === 1 ? 'vůdce' : 'vůdců'}</small></td><td class="r">${date(b.date)}</td></tr>`).join('')}</tbody></table>`
        : '<div class="small">Bleskovku jsi ještě nehrál/a. Najdeš ji v hlavní nabídce.</div>'}
      <button class="primary" id="back">Zpět</button>
    </div>`;
  $('#back').onclick = back;
}

// ── Nápověda ─────────────────────────────────────────
function helpScreen(back) {
  ui = null;
  document.body.classList.remove('game');
  app.innerHTML = `
    <div class="sheet help">
      <h3>Jak hrát</h3>
      <ul>
        <li>Za tebou chodí ministři, generálové, vědci i obyčejní lidé. Každá karta má <b>čtyři možnosti</b> – táhni ji
          <b>doleva, doprava, nahoru, nebo dolů</b>. Volbu uvidíš, ještě než kartu pustíš; když si to rozmyslíš, vrať ji doprostřed.</li>
        <li>Můžeš také klepnout na šipku u karty (ukáže volbu) a klepnutím znovu ji potvrdit.</li>
        <li>Pod každým ukazatelem je <b>proužek s jeho hodnotou</b> (ryska uprostřed = ideál). Nahoře je <b>sedm ukazatelů</b>: ${METERS.map((m) => m.name).join(', ')}.</li>
        <li><b>Ideál je uprostřed</b> (světlejší pásmo). Když ukazatel klesne na nulu, nebo vystoupá na maximum, vláda skončí katastrofou.</li>
        <li>Při tažení se pod ukazateli objeví <b>tečky</b> – čeho se rozhodnutí dotkne (větší = víc). Jestli nahoru, nebo dolů, musíš odhadnout.</li>
        <li>Po rozhodnutí se dotčené ukazatele na chvíli obarví: <b style="color:var(--sky)">modře, když stouply</b> (nebe nahoře),
          <b style="color:var(--grass)">zeleně, když klesly</b> (tráva dole).</li>
        <li>Klepnutím na ukazatel zjistíš jeho stav, co znamená a co ho zvyšuje nebo snižuje.</li>
        <li>Rozhodnutí mají následky – některá se ti vrátí za pár měsíců. Když padneš, úřad převezme nástupce, ale svět si pamatuje, co se stalo.</li>
        <li><b>Typy vůdců</b> – každý má jednu schopnost (ikona vpravo nahoře):<br>${KINDS.map((k) => `<b>${k.m}</b> – ${k.text}`).join('<br>')}</li>
        <li><b>Lidé si pamatují.</b> Komu pomůžeš, ten ti bude věrný (srdíčko u jména) a přijde s pomocí. Komu škodíš, rozzlobí se (blesk) – a jednou si to vybere.</li>
        <li><b>Zákony</b> platí, dokud je někdo nezruší, a každý měsíc pomalu posouvají ukazatele. Platí i pro nástupce.</li>
        <li><b>Úkoly:</b> každý vůdce dostane úkol. Splněný úkol je pečeť – pečetě a čas otevírají nové éry světa a tajné příběhy s legendárními konci.</li>
        <li>Některé volby se odemknou, jen když je země silná v něčem (třeba v diplomacii) – poznáš je podle <b>klíče</b>.</li>
        <li><b>Dějiny lidstva:</b> začneš jako náčelník kmene v pravěku. Každá doba (pravěk, starověk, středověk, novověk, moderní doba, současnost, budoucnost) má vlastní postavy, karty a konce. Po čase přijde přelomový objev – když ho přijmeš, svět se posune dál. Volby jsou až od moderní doby, zákony podle doby.</li>
        <li><b>Cesta dějin:</b> každý přelom nabízí dva objevy (třeba knihtisk, nebo střelný prach). Tvoje volba otevře jiné karty v další době.</li>
        <li><b>Divy světa:</b> v každé době můžeš postavit velkou stavbu. Stavba trvá několik karet; hotový div navždy drží jeden ukazatel u rovnováhy.</li>
        <li><b>Sousední říše</b> (v dávných dobách) sílí s časem. Obchoduj, uzavírej spojenectví, plať tribut, nebo válči – válku rozhoduje tvoje Síla proti síle souseda. Slabého souseda můžeš pohltit.</li>
        <li><b>Roční období:</b> zima ubírá zásoby, podzim přináší úrodu a každé období má vlastní karty.</li>
        <li><b>Zrádci:</b> občas někdo z tvých blízkých začne vynášet tajemství. Když ho vyšetřovatel včas neodhalí, zradí tě.</li>
        <li><b>Dynastie:</b> každý typ vůdce sbírá zkušenost (měsíce vlády) a roste na úroveň 2–4 – na úrovni 3 je mistr se silnější schopností. Za body kupuješ trvalá vylepšení stromu dynastie.</li>
        <li><b>Sbírka:</b> album postav, galerie konců, relikvie (najdeš je za dlouhé vlády, legendy, divy a nové doby; nasadíš dvě) a vzhledy karet.</li>
        <li><b>Frakce</b> (Kněží, Kupci, Vojsko, Učenci) se zlobí, když jejich ukazatel dlouho klesá – nakonec se vzbouří. <b>Zvěsti</b> můžou a nemusí být pravda, a některá rozhodnutí se ti vrátí až po letech.</li>
        <li><b>Velké stavby:</b> na začátku vlády můžeš začít stavět. Stavba stojí zásoby každý měsíc a po dokončení navždy drží svůj ukazatel u rovnováhy. Kdo vládne aspoň 3 roky, předá nástupci jednu výhodu a věrné lidi.</li>
        <li><b>Kampaň:</b> 10 kapitol s pevným zadáním, hodnocení hvězdami. <b>Prestiž:</b> po dosažení budoucnosti začni znovu od pravěku – těžší, ale s víc body.</li>
        <li><b>Čti karty.</b> Kdo odpoví rychleji než za vteřinu, nečte – další karta (s červeným rámečkem) mu pak jen uškodí, ať zvolí cokoli. V bleskovce to neplatí.</li>
        <li><b>Čím déle vládneš, tím víc rozhodnutí váží</b> – na začátku vlády mají účinek 1,8×, po čtyřech letech 2,6×. Nový vůdce začíná zase mírněji.</li>
        <li><b>Dlouhé krajnosti</b> mají následky (hladomor, fanatici, vojáci nad zákonem…), dlouhý klid přinese zlatý věk.</li>
        <li><b>Ztížení</b> (při založení hry) – hladová léta, nevraživí sousedé, bouřlivá doba, hnízdo zrádců – násobí skóre vlády.</li>
        <li><b>Výzvy:</b> denní výzva v roce 2089 i v Dějinách a týdenní výzva se třemi vládci.</li>
        <li><b>Hra pro dva:</b> bleskovka pro dva naráz. Obrazovka se rozdělí – jeden hraje zespodu, druhý shora (jeho polovina je otočená). Každý má vlastního vůdce a vlastní hodiny; vyhrává, kdo se dostane nejdál.</li>
        <li><b>Body a obchod:</b> za dlouhé vlády (2, 5, 10 let; se ztížením dvojnásob), úkoly, úspěchy, výzvy, bleskovku a vítězství v souboji dostáváš body. V obchodě za ně odemkneš další vůdce (na začátku je volných pět) a koupíš pomůcky: radu, přeskočení karty, vyrovnání ukazatele nebo štít.</li>
        <li><b>Výhody:</b> za splněný úkol si vybereš jednu ze tří výhod (třeba Brzda, Druhá šance nebo Zvědové). Platí do konce vlády.</li>
        <li><b>Volby</b> jsou každé 4 roky. Hlasy ti dají Lid a Spojenci – když je jejich průměr pod ${VOTE_MIN} %, prohraješ a vláda končí. Půl roku předem tě varují.</li>
        <li><b>Krize</b> (epidemie, povodeň, útok na síť) trvají několik karet. Když zvládneš většinu kroků, země z toho vyjde silnější, jinak to bolí.</li>
        <li><b>Bleskovka:</b> hra na čas. Začínáš se 3 minutami, každé rozhodnutí přidá 5 s, pád vlády 15 s ubere. Počítá se, kolik rozhodnutí stihneš.</li>
        <li><b>Denní výzva:</b> každý den nový začátek a typ vůdce – stejný pro všechny. Jedna vláda, počítá se, jak dlouho vydržíš. Hraj ji každý den a buduj sérii.</li>
        <li><b>Úspěchy:</b> 26 odznaků za výjimečné vlády (Harmonie, O vlásek, Dynastie…). Najdeš je ve statistikách.</li>
        <li><b>Statistiky</b> ukazují tvoje hodnocení (od Nováčka po Legendu republiky), nejdelší vlády a rekordy z bleskovky.</li>
        <li>Sbírej všech <b>${15 + Object.keys(SPECIAL).length} konců</b> a překonej svou nejdelší vládu.</li>
        <li>Hra běží i offline. V Safari dej <b>Sdílet → Přidat na plochu</b> a hraj jako aplikaci.</li>
      </ul>
      <button class="primary" id="back">Zpět</button>
    </div>`;
  $('#back').onclick = back;
}

// ── Postup: dynastie, sbírka, kampaň, prestiž ───────
const stars = (n) => '★'.repeat(n) + '☆'.repeat(3 - n);
function applySkin() {
  for (const c of [...document.body.classList]) if (c.startsWith('skin-')) document.body.classList.remove(c);
  document.body.classList.add(`skin-${stats.skin ?? 'klasik'}`);
}
/** Album: zapíše postavu, kterou hráč potkal; za kompletní dobu odměna. */
function meet(who) {
  if (!who || !PEOPLE[who] || stats.met.includes(who)) return;
  stats.met.push(who);
  for (const [age, ids] of Object.entries(albumPeople())) {
    if (stats.albums.includes(age) || !ids.every((x) => stats.met.includes(x))) continue;
    stats.albums.push(age);
    if (!stats.skins.includes('hvezdy')) stats.skins.push('hvezdy');
    award(3, `album: ${Number(age) < 7 ? AGES[age - 1].name : 'Nová republika'} kompletní`);
  }
  saveStats();
}

/** Dynastie: úrovně vůdců, strom vylepšení a prestiž. */
function dynastyScreen(back) {
  ui = null;
  document.body.classList.remove('game');
  const row = (k) => {
    const xp = stats.xp[k.id] ?? 0, lv = levelOf(xp), next = LEVELS[lv];
    const pct = next ? Math.round(((xp - LEVELS[lv - 1]) / (next - LEVELS[lv - 1])) * 100) : 100;
    return `<div class="lvrow${isUnlocked(k.id) ? '' : ' dim'}">${icon(k.id, 'ico')}<div><b>${k.short} <span class="dim">úroveň ${lv}</span></b>
      <div class="bar"><i style="width:${pct}%"></i></div><small>${next ? `${xp} / ${next} měsíců vlády · další: ${LEVEL_TEXT[lv + 1]}` : 'Nejvyšší úroveň – Legenda'}${lv >= 3 ? ` · <b>Mistr:</b> ${MASTERY[k.id]}` : ''}</small></div></div>`;
  };
  const tree = Object.entries(TREE).map(([id, t]) => {
    const n = stats.tree[id] ?? 0, cost = t.cost[n];
    return `<div class="shopitem${n ? ' got' : ''}">${icon(t.icon, 'ico')}<div><b>${t.name} <span class="pips">${'●'.repeat(n)}${'○'.repeat(TREE_MAX - n)}</span></b><small>${n ? t.text(n) : t.text(1)}${n && n < TREE_MAX ? ` → další: ${t.text(n + 1)}` : ''}</small></div>
      ${n >= TREE_MAX ? '<span class="dim">hotovo</span>' : `<button class="unlock" data-t="${id}"${stats.points < cost ? ' disabled' : ''}>${cost} b.</button>`}</div>`;
  }).join('');
  app.innerHTML = `
    <div class="sheet">
      <div class="rankcard">${icon('era', 'ico xl')}<h2 class="legend">Dynastie</h2>
        <div class="small">Máš <b>${stats.points} ${bodu(stats.points)}</b>. Vylepšení platí v hlavní hře pro všechny další vůdce.</div></div>
      <h3>Strom dynastie</h3>
      <div class="shoplist">${tree}</div>
      <h3>Úrovně vůdců</h3>
      <div class="small">Zkušenost = měsíce vlády s daným typem. Úroveň 2: mírnější začátek vlády. Úroveň 3: mistrovství (silnější schopnost). Úroveň 4: bod navíc za každou vládu delší než rok.</div>
      ${KINDS.map(row).join('')}
      <h3>Prestiž</h3>
      <div class="small">${stats.prestige ? `Nejvyšší dosažená prestiž: <b>${ROMAN[stats.prestige]}</b>. ` : ''}Když v Dějinách lidstva dovedeš lid až do budoucnosti, můžeš začít znovu od pravěku s vyšší prestiží: rozhodnutí váží o ${Math.round(0.15 * 100)} % víc, ale za vládu dostaneš o ${Math.round(PRESTIGE_BONUS * 100)} % víc bodů (za každý stupeň).</div>
      <button class="primary" id="back">Zpět</button>
    </div>`;
  for (const b of app.querySelectorAll('[data-t]')) b.onclick = () => {
    const id = b.dataset.t, n = stats.tree[id] ?? 0, cost = TREE[id].cost[n];
    if (stats.points < cost || n >= TREE_MAX) return;
    stats.points -= cost;
    stats.tree[id] = n + 1;
    saveStats();
    sfx('ach');
    toast(`${TREE[id].name}: stupeň ${n + 1}`, 'ach');
    dynastyScreen(back);
  };
  $('#back').onclick = back;
}

/** Sbírka: album postav, konce, relikvie a vzhledy karet. */
function collectionScreen(back, tab = 'lide') {
  ui = null;
  document.body.classList.remove('game');
  const tabs = { lide: 'Postavy', konce: 'Konce', relikvie: 'Relikvie', vzhled: 'Vzhledy' };
  let body = '';
  if (tab === 'lide') {
    const groups = albumPeople();
    body = Object.entries(groups).map(([age, ids]) => {
      const got = ids.filter((x) => stats.met.includes(x)).length;
      return `<h3>${Number(age) < 7 ? AGES[age - 1].name : 'Nová republika'} <span class="dim">${got} / ${ids.length}${stats.albums.includes(age) ? ' ✓' : ''}</span></h3>
        <div class="album">${ids.map((who) => stats.met.includes(who)
          ? `<div class="ap">${portrait(PEOPLE[who], Number(age))}<small>${esc(PEOPLE[who].name)}</small></div>`
          : '<div class="ap unknown"><div class="q">?</div><small>neznámý</small></div>').join('')}</div>`;
    }).join('') + '<div class="small">Za každou kompletní dobu dostaneš 3 body a Hvězdný vzhled karet.</div>';
  }
  if (tab === 'konce') {
    const meterName = (id) => METERS.find((m) => m.id === id)?.name;
    const list = (ends, label) => `<h3>${label}</h3>${Object.entries(ends).flatMap(([m, sides]) => ['low', 'high'].map((side) => {
      const key = `${m}.${side}`, got = stats.ends[key] || state?.endings?.includes(key);
      return `<div class="endrow${got ? '' : ' locked'}">${glyph(m, 'glyph')}<div><b>${got ? esc(sides[side].title) : '???'}</b><small>${got ? `${stats.ends[key] ?? 1}× · ` : 'Nápověda: '}${meterName(m)} ${side === 'low' ? 'klesne na nulu' : 'vystoupá na maximum'}</small></div></div>`;
    })).join('')}`;
    body = list(ENDINGS_PAST, 'Dávné doby') + list(ENDINGS, 'Nová republika')
      + `<h3>Legendy</h3>${Object.entries(SPECIAL).map(([id, e]) => { const got = stats.ends[`x.${id}`] || state?.endings?.includes(`x.${id}`); return `<div class="endrow${got ? '' : ' locked'}">${icon(id, 'ico')}<div><b>${got ? esc(e.title) : '???'}</b><small>${got ? 'tajný konec' : 'Tajný příběh – sleduj podivné karty a odemčené volby.'}</small></div></div>`; }).join('')}`;
  }
  if (tab === 'relikvie') {
    body = `<div class="small">Relikvie najdeš za dlouhou vládu (5 let), legendu, dokončený div světa nebo stavbu a příchod nové doby. Nasadit můžeš nejvýš ${RELIC_SLOTS} – platí v hlavní hře od další vlády.</div>
      <div class="shoplist">${Object.entries(RELICS).map(([id, r]) => {
        const own = stats.relics.includes(id), on = stats.equip.includes(id);
        return `<div class="shopitem${own ? ' got' : ''}">${r.m ? glyph(r.m, 'glyph') : icon('key', 'ico')}<div><b>${own ? r.name : '???'}</b><small>${own ? r.text : 'Zatím nenalezeno.'}</small></div>
          ${own ? `<button class="unlock${on ? ' on' : ''}" data-r="${id}">${on ? 'Nasazeno' : 'Nasadit'}</button>` : ''}</div>`;
      }).join('')}</div>`;
  }
  if (tab === 'vzhled') {
    body = `<div class="small">Vzhled karet v celé hře. Kupuje se za body, Hvězdný získáš za kompletní album jedné doby.</div>
      <div class="shoplist">${Object.entries(SKINS).map(([id, k]) => {
        const own = stats.skins.includes(id), on = stats.skin === id;
        return `<div class="shopitem got"><div class="swatch skin-${id}"><i></i></div><div><b>${k.name}</b><small>${own ? (on ? 'Používáš' : 'Máš') : k.how ?? `Za ${k.price} bodů`}</small></div>
          ${own ? `<button class="unlock${on ? ' on' : ''}" data-s="${id}">${on ? 'Vybráno' : 'Vybrat'}</button>` : k.how ? '' : `<button class="unlock" data-buy-skin="${id}"${stats.points < k.price ? ' disabled' : ''}>${k.price} b.</button>`}</div>`;
      }).join('')}</div>`;
  }
  app.innerHTML = `
    <div class="sheet">
      <h2 class="legend" style="text-align:center">Sbírka</h2>
      <div class="seg tabs">${Object.entries(tabs).map(([id, n]) => `<button data-tab="${id}" class="${id === tab ? 'on' : ''}">${n}</button>`).join('')}</div>
      ${body}
      <button class="primary" id="back">Zpět</button>
    </div>`;
  for (const b of app.querySelectorAll('[data-tab]')) b.onclick = () => collectionScreen(back, b.dataset.tab);
  for (const b of app.querySelectorAll('[data-r]')) b.onclick = () => {
    const id = b.dataset.r;
    if (stats.equip.includes(id)) stats.equip = stats.equip.filter((x) => x !== id);
    else { if (stats.equip.length >= RELIC_SLOTS) stats.equip.shift(); stats.equip.push(id); }
    saveStats();
    collectionScreen(back, tab);
  };
  for (const b of app.querySelectorAll('[data-s]')) b.onclick = () => { stats.skin = b.dataset.s; saveStats(); applySkin(); collectionScreen(back, tab); };
  for (const b of app.querySelectorAll('[data-buy-skin]')) b.onclick = () => {
    const id = b.dataset.buySkin, k = SKINS[id];
    if (stats.points < k.price) return;
    stats.points -= k.price; stats.skins.push(id); stats.skin = id;
    saveStats(); applySkin(); sfx('ach');
    collectionScreen(back, tab);
  };
  $('#back').onclick = back;
}

/** Prestiž: svět začne znovu od pravěku, rozhodnutí váží víc, body se násobí. */
function prestigeStart() {
  const lvl = (state.prestige ?? 0) + 1;
  if (!confirm(`Začít znovu od pravěku s prestiží ${ROMAN[lvl]}? Rozhodnutí budou vážit víc, ale za vládu dostaneš o ${Math.round(PRESTIGE_BONUS * lvl * 100)} % víc bodů. Odemčené konce zůstanou.`)) return;
  const keep = { endings: state.endings, best: state.best };
  const kind = state.leader.kind;
  state = newGame({ female: state.leader.female, kind, mode: 'dejiny', world: 'dejiny', mods: state.mods ?? [], ...metaFor(kind), prestige: lvl }, (Math.random() * 2 ** 32) >>> 0);
  Object.assign(state, keep);
  stats.prestige = Math.max(stats.prestige ?? 0, lvl);
  stats.games += 1;
  saveStats();
  equip();
  save();
  gameScreen();
  ageSplash();
}

// ── Kampaň ───────────────────────────────────────────
const campOpen = (i) => i === 0 || (stats.camp[CAMPAIGN[i - 1].id] ?? 0) > 0;
function campLabel() {
  const done = CAMPAIGN.filter((c) => stats.camp[c.id]).length;
  return `${done} / ${CAMPAIGN.length} kapitol`;
}
function campaignScreen() {
  ui = null;
  document.body.classList.remove('game');
  let run = null;
  try { run = JSON.parse(localStorage.getItem(CAMP)); } catch { /* nic */ }
  const total = CAMPAIGN.reduce((a, c) => a + (stats.camp[c.id] ?? 0), 0);
  app.innerHTML = `
    <div class="sheet">
      <div class="rankcard">${icon('book', 'ico xl')}<h2 class="legend">Kampaň</h2>
        <div class="small">Kapitoly s pevným zadáním. Hvězdy podle toho, kolik ukazatelů je při splnění v klidu (mezi 30 a 70 %). Za každou novou hvězdu bod. Celkem <b>${total} / ${CAMPAIGN.length * 3} ★</b></div></div>
      ${run && !run.dead ? `<button class="primary" id="cont">Pokračovat: ${esc(CAMPAIGN.find((c) => c.id === run.camp)?.name ?? '')}</button>` : ''}
      <div class="mlist">${CAMPAIGN.map((c, i) => `<button class="mi${campOpen(i) ? '' : ' locked'}" data-k="${i}"${campOpen(i) ? '' : ' disabled'}>
        <span class="chap">${i + 1}</span><span><b>${c.name} <em class="stars">${stars(stats.camp[c.id] ?? 0)}</em></b><small>${campOpen(i) ? c.text : 'Zamčeno – nejdřív dokonči předchozí kapitolu.'}</small></span>${icon('chev', 'ico chev')}</button>`).join('')}</div>
      <button class="ghost" id="back">Zpět</button>
    </div>`;
  for (const b of app.querySelectorAll('[data-k]')) b.onclick = () => startCamp(Number(b.dataset.k));
  if (run && !run.dead) $('#cont').onclick = () => { state = upgrade(run); gameScreen(); };
  $('#back').onclick = home;
}
function startCamp(i) {
  const c = CAMPAIGN[i];
  state = newGame({ kind: c.kind, mode: c.world === 'dejiny' ? 'dejiny' : 'normal', world: c.world, mods: c.mods ?? [], meters: c.meters }, (Math.random() * 2 ** 32) >>> 0);
  state.camp = c.id;
  save();
  gameScreen();
  toast(`Kapitola ${i + 1}: ${c.text}`, 'task');
}
/** Splněno zadání kapitoly? (prohra při překročení limitu) */
function campCheck() {
  const c = CAMPAIGN.find((x) => x.id === state.camp), g = c.goal;
  if (g.max && Object.entries(g.max).some(([m, v]) => state.meters[m] > v)) { campEnd(false, `${METERS.find((m) => m.id === Object.keys(g.max)[0]).name} přerostla limit.`); return true; }
  if (g.within && state.total > g.within && (state.age ?? 7) < g.age) { campEnd(false, 'Nestihl jsi to včas.'); return true; }
  const ok = (g.months ? state.turn >= g.months : true) && (g.age ? (state.age ?? 7) >= g.age : true) && (g.laws ? activeLaws(state).length >= g.laws : true);
  if (ok) { campEnd(true); return true; }
  return false;
}
function campFall() {
  const c = CAMPAIGN.find((x) => x.id === state.camp);
  recordReign();
  if (state.leader.n < (c.lives ?? 1)) {
    const d = state.dead;
    nextLeader(state, state.leader.kind);
    save();
    render(true);
    toast(`${d.title} · nastupuje ${state.leader.n}. vůdce z ${c.lives}`, 'fall');
    return;
  }
  campEnd(false, state.dead.title);
}
function campEnd(win, why = '') {
  const i = CAMPAIGN.findIndex((x) => x.id === state.camp), c = CAMPAIGN[i];
  const calm = METERS.filter((m) => state.meters[m.id] >= 30 && state.meters[m.id] <= 70).length;
  const got = win ? (calm >= 6 ? 3 : calm >= 4 ? 2 : 1) : 0;
  const prev = stats.camp[c.id] ?? 0;
  if (got > prev) { stats.camp[c.id] = got; saveStats(); award(got - prev, `kampaň: ${c.name}`); }
  if (win && got === 3 && prev < 3) dropRelic('kampaň na tři hvězdy');
  try { localStorage.removeItem(CAMP); } catch { /* nic */ }
  sfx(win ? 'ach' : 'end');
  ui = null;
  document.body.classList.remove('game');
  const next = CAMPAIGN[i + 1];
  app.innerHTML = `
    <div class="sheet">
      <div class="big">${icon(win ? 'trophy' : 'crisis', 'ico xl')}</div>
      <h2 class="legend">${win ? 'Kapitola splněna' : 'Kapitola nesplněna'}</h2>
      <div class="score"><b>${win ? stars(got) : '☆☆☆'}</b><span>${esc(c.name)}${win ? ` · v klidu ${calm} ze 7 ukazatelů` : ` · ${esc(why)}`}</span></div>
      <div class="col">
        ${win && next ? `<button class="primary" id="next">Další kapitola: ${esc(next.name)}</button>` : ''}
        <button class="${win && next ? 'ghost' : 'primary'}" id="again">Hrát znovu</button>
        <button class="ghost" id="list">Kapitoly</button>
      </div>
    </div>`;
  if (win && next) $('#next').onclick = () => startCamp(i + 1);
  $('#again').onclick = () => startCamp(i);
  $('#list').onclick = campaignScreen;
  state = load();
}

// ── Start ────────────────────────────────────────────
applySkin();
if ('serviceWorker' in navigator) navigator.serviceWorker.register('sw.js').catch(() => {});
if (state && state.dead) deathScreen();
else if (state && state.total > 0) gameScreen();
else startScreen();
