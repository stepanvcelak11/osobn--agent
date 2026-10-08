// Rovnováha – zobrazení a ovládání (tažení karty do čtyř stran, šipky, klávesy, uložení hry).
import { portrait, meterIcon, glyph, icon, mood, mix } from './art.js';
import { newGame, newBlitz, newRun, daily, touches, seesAhead, ageOf, leaderTitle, hasElections, lawAllowed, AGES, AGE_LEN, choose, nextLeader, currentCard, cardById, preview, outcome, optionOf, unlocked, skip, nudge, reformLaw, choosePerk, ready, tenure, timeLabel, danger, kindOf, upgrade, activeLaws, seals, taskById, taskProgress, seesDirection, toElection, support, KINDS, ACTIVE, CHARGE, NUDGE, METERS, ENDINGS, LAWS, TASKS, ERAS, SPECIAL, PEOPLE, REL_LOYAL, PERKS, CRISES, ELECTION, VOTE_MIN, BLITZ_START, BLITZ_BONUS, BLITZ_FALL } from './game.js';

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
  try { localStorage.setItem(state?.mode === 'daily' ? DAILY : SAVE, JSON.stringify(state)); } catch { /* soukromé okno – hraje se bez ukládání */ }
}
// Denní výzva má vlastní uložení – hlavní hra zůstává netknutá.
const DAILY = 'rovnovaha.daily';
const today = (d = new Date()) => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
function loadDaily() {
  try {
    const s = JSON.parse(localStorage.getItem(DAILY));
    return s && s.day === today() && !s.dead ? upgrade(s) : null;
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
const emptyStats = () => ({ games: 0, decisions: 0, reigns: 0, months: 0, tasks: 0, elections: 0, crises: 0, ends: {}, top: [], blitz: [], daily: {}, ach: {}, kinds: [] });
let stats = loadStats();
function loadStats() {
  let s = null;
  try { s = JSON.parse(localStorage.getItem(STATS)); } catch { /* nic */ }
  if (s) return { ...emptyStats(), ...s };
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
/** Konec vlády do statistik (jen hlavní hra). */
function recordReign() {
  const h = state.history[state.history.length - 1];
  if (!h || state.mode === 'blitz') return;
  stats.reigns += 1;
  stats.months += h.months;
  stats.ends[h.ending] = (stats.ends[h.ending] ?? 0) + 1;
  stats.top.push({ name: h.name, months: h.months, title: h.title, kind: state.leader.kind });
  if (!stats.kinds.includes(state.leader.kind)) stats.kinds.push(state.leader.kind);
  stats.top = stats.top.sort((a, b) => b.months - a.months).slice(0, 10);
  saveStats();
}
/// Hodnocení: body za nejdelší vládu, konce, úkoly, volby, krize a zkušenosti.
const RANKS = [[0, 'Nováček'], [30, 'Radní'], [80, 'Ministr'], [160, 'Prezident'], [300, 'Státník'], [500, 'Legenda republiky']];
function rating() {
  const best = Math.max(state?.best ?? 0, stats.top[0]?.months ?? 0);
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
    if (ok) { stats.ach[a.id] = Date.now(); got = true; toast(`Úspěch: ${a.name}`, 'ach'); }
  }
  if (got) saveStats();
}
/** Kolik dní po sobě (do dneška nebo včerejška) hráč dokončil denní výzvu. */
function dailyStreak() {
  const d = new Date();
  if (stats.daily[today(d)] == null) d.setDate(d.getDate() - 1);
  let n = 0;
  while (stats.daily[today(d)] != null) { n++; d.setDate(d.getDate() - 1); }
  return n;
}

const esc = (t) => String(t).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]);
const ARROW = { left: '←', right: '→', up: '↑', down: '↓' };
const kindName = (k, female) => (female ? k.f : k.m);
const DIR_WORD = { left: 'doleva ←', right: 'doprava →', up: 'nahoru ↑', down: 'dolů ↓' };

/** Výběr typu prezidenta (start i nástupce): řada ikon a pod ní popis vybraného typu. Popis jde i přetáhnout prstem. */
function kindPicker() {
  return `<div class="kinds">${KINDS.map((k) => `<button class="kind" data-k="${k.id}" aria-label="${k.m}">${icon(k.id)}</button>`).join('')}</div>
    <div class="kdesc" id="kd"></div>`;
}
function bindPicker(root, selected, female, onPick) {
  let cur = selected;
  const show = (id) => {
    cur = id;
    const k = KINDS.find((x) => x.id === id);
    for (const b of root.querySelectorAll('.kind')) b.classList.toggle('on', b.dataset.k === id);
    const name = female() == null ? k.m.replace('Prezident s rádcem', 'S rádcem') : kindName(k, female());
    const active = ACTIVE.includes(k.id) ? 'Schopnost na tlačítko' : 'Stálá schopnost';
    root.querySelector('.kdesc').innerHTML = `${icon(k.id, 'ico lg')}<div><b>${name}</b><em>${active}</em><small>${k.text}</small></div>`;
    onPick(id);
  };
  for (const b of root.querySelectorAll('.kind')) b.onclick = () => show(b.dataset.k);
  const d = root.querySelector('.kdesc');
  let x0 = null;
  d.onpointerdown = (e) => (x0 = e.clientX);
  d.onpointerup = (e) => {
    if (x0 == null) return;
    const dx = e.clientX - x0, i = KINDS.findIndex((k) => k.id === cur);
    x0 = null;
    if (Math.abs(dx) > 40) show(KINDS[(i + (dx < 0 ? 1 : KINDS.length - 1)) % KINDS.length].id);
  };
  show(cur);
  return { refresh: () => show(cur) };
}
const $ = (sel) => app.querySelector(sel);

// ── Úvod ─────────────────────────────────────────────
function startScreen() {
  document.body.classList.remove('game');
  app.innerHTML = `
    <div class="start">
      <img class="logo" src="icons/icon-192.png" alt="">
      <h1>ROVNOVÁHA</h1>
      <p>Veď svůj lid od pravěkého ohně přes hrady a parní stroje až do budoucnosti.
        Udrž sedm sil v rovnováze – ideál je uprostřed, na krajích čeká katastrofa.</p>
      <div class="col">
        ${state ? `<button class="primary" id="cont">Pokračovat – ${esc(state.leader.name)}</button>` : ''}
        <button class="${state ? 'ghost' : 'primary'}" id="new">${state ? 'Nová hra od začátku' : 'Nová hra'}</button>
        <div class="row2 modes">
          <button class="ghost" id="daily">${icon('sun', 'ico sm')}<span><b>Denní výzva</b><small>${dailyLabel()}</small></span></button>
          <button class="ghost" id="blitz">${icon('timer', 'ico sm')}<span><b>Bleskovka</b><small>3 minuty na čas</small></span></button>
        </div>
        <div class="row2"><button class="ghost" id="stats">${icon('stats', 'ico sm')} Statistiky</button><button class="ghost" id="help">${icon('help', 'ico sm')} Jak hrát</button></div>
      </div>
    </div>`;
  $('#help').onclick = () => helpScreen(startScreen);
  $('#stats').onclick = () => statsScreen(startScreen);
  $('#blitz').onclick = () => setupScreen('blitz');
  $('#daily').onclick = startDaily;
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
      <input id="name" maxlength="30" placeholder="Tvoje jméno" autocomplete="off" enterkeyhint="done">
      <div class="seg"><button id="m" class="on">Vládce</button><button id="f">Vládkyně</button></div>
      <div class="label">Jaký budeš vůdce?</div>
      <div id="kp">${kindPicker()}</div>
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
  $('#name').onkeydown = (e) => { if (e.key === 'Enter') e.target.blur(); };
  $('#back').onclick = startScreen;
  $('#go').onclick = () => {
    if (blitzMode) { startBlitz({ name: $('#name').value, female, kind }); return; }
    if (state && !confirm('Opravdu začít znovu? Současná hra i kronika vůdců se smažou (odemčené konce zůstanou).')) return;
    const keep = state ? { endings: state.endings, best: state.best } : null;
    state = newGame({ name: $('#name').value, female, kind, mode: world }, (Math.random() * 2 ** 32) >>> 0);
    if (keep) Object.assign(state, keep);
    stats.games += 1; saveStats();
    save();
    gameScreen();
    if (world === 'dejiny') ageSplash(); else toast(`Úkol: ${taskById(state.task.id).text}`, 'newtask');
  };
}

function dailyLabel() {
  const k = KINDS.find((x) => x.id === daily(today()).kind);
  const best = stats.daily[today()];
  if (loadDaily()) return 'rozehraná – pokračuj';
  return best != null ? `dnes: ${tenure(best)}` : `dnes: ${k.short}`;
}
/** Denní výzva: všichni mají ve stejný den stejný typ vůdce a stejný začátek. Jedna vláda, počítají se měsíce. */
function startDaily() {
  const cont = loadDaily();
  if (cont) { state = cont; gameScreen(); return; }
  const d = daily(today()), main = state;
  state = newRun({ name: main?.leader?.name ?? '', female: main?.leader?.female ?? false, kind: d.kind }, d.seed, 'daily');
  state.day = today();
  save();
  gameScreen();
  const k = KINDS.find((x) => x.id === d.kind);
  toast(`Denní výzva: ${k.short}. Vydrž co nejdéle!`, 'sun');
}
function dailyEnd() {
  sfx('end');
  const d = state.dead, day = state.day, months = d.months;
  const prev = stats.daily[day];
  stats.daily[day] = Math.max(prev ?? 0, months);
  saveStats();
  try { localStorage.removeItem(DAILY); } catch { /* nic */ }
  recordReign();
  checkAch();
  ui = null;
  document.body.classList.remove('game');
  const m = METERS.find((x) => x.id === d.meter);
  app.innerHTML = `
    <div class="sheet">
      <div class="big">${icon('sun', 'ico xl')}</div>
      <h2 class="legend">Denní výzva</h2>
      <div class="score"><b>${tenure(months)}</b><span>${esc(d.title)}${m ? ` · ${m.name}` : ''}</span></div>
      ${prev == null || months > prev ? `<div class="record">${prev == null ? 'Dnešní výsledek zapsán' : 'Lepší než dnes ráno!'}</div>` : `<div class="small" style="text-align:center">Dnešní nejlepší: ${tenure(prev)}</div>`}
      <p>${esc(d.text)}</p>
      <div class="stats">
        <div class="stat"><span class="small">Série dní</span><b>${dailyStreak()}</b></div>
        <div class="stat"><span class="small">Zítra</span><b>${KINDS.find((x) => x.id === daily(today(new Date(Date.now() + 864e5))).kind).short}</b></div>
      </div>
      <button class="primary" id="again">Zkusit znovu</button>
      <button class="ghost" id="home">Hlavní nabídka</button>
    </div>`;
  $('#again').onclick = () => { state = null; startDaily(); };
  $('#home').onclick = home;
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
      <button class="meter" data-m="${m.id}" aria-label="${m.name}">${meterIcon(m.id)}<span class="dot" data-d="${m.id}"></span></button>`).join('')}
    </header>
    <div class="question" id="q"><p></p></div>
    <section class="stage">
      ${['up', 'left', 'right', 'down'].map((d) => `<button class="chev ${d}" data-dir="${d}" aria-label="Volba ${d}">${{ up: '▲', down: '▼', left: '◀', right: '▶' }[d]}</button>`).join('')}
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
  $('#nth').textContent = `${l.n}. ${leaderTitle(state)} · ${state.mode === 'dejiny' ? `${ageOf(state).name} · ` : ''}${timeLabel(state)}`;
  if (state.mode === 'blitz') updateClock();
  // Vpravo nahoře: ikona typu vůdce. U aktivních schopností kroužek ukazuje nabití.
  const ab = $('#ab'), active = ACTIVE.includes(k.id);
  if (ab.dataset.k !== k.id) { ab.querySelector('i').innerHTML = icon(k.id); ab.dataset.k = k.id; }
  ab.classList.toggle('active', active);
  ab.querySelector('.ring').style.strokeDasharray = active ? `${(Math.min(state.charge, CHARGE) / CHARGE) * 100} 100` : '0 100';
  ab.classList.toggle('ready', active && ready(state));
  ab.setAttribute('aria-label', kindName(k, l.female));
  const c0 = currentCard(state), chips = [];
  if (state.advice) chips.push(`${icon('rada', 'ico sm')} Rádce radí: <b>${DIR_WORD[state.advice]}</b>`);
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
    ui.icons[m.id].parentElement.setAttribute('aria-label', `${m.name}: ${v} %`);
  }
  const c = currentCard(state);
  document.body.style.setProperty('--scene', mix(c.person.color, '#0d0c0b', 0.8));
  ui.q.firstElementChild.textContent = c.text;
  ui.person.textContent = c.person.name;
  $('#mood').innerHTML = mood(state.rel?.[c.who] ?? 0, REL_LOYAL);
  // Pod kartou leží další: je vidět, kdo přijde (při tažení se odkryje celá).
  const np = nx ? PEOPLE[nx.who] : null;
  ui.next.parentElement.classList.remove('dragging');
  ui.next.className = 'card next' + (enter ? ' rise' : '');
  ui.next.innerHTML = np ? `${portrait(np)}<div class="nextname">${esc(np.name)}</div>` : '';
  const card = ui.card;
  card.className = 'card' + (enter ? ' enter' : '');
  card.style.transform = '';
  card.style.opacity = '';
  card.innerHTML = portrait(c.person) +
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
        ui.dots[m.id].className = 'dot' + (d > 0 ? ' rise' : d < 0 ? ' fall' : '');
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
  card.className = 'card fly';
  card.style.transform = far;
  card.style.opacity = '0';
  selected = null;
  const before = { ...state.meters };
  setTimeout(() => {
    const dead = choose(state, dir);
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
    if (dead && state.mode === 'daily') { dailyEnd(); return; }
    if (dead) { recordReign(); checkAch(); deathScreen(); } else { render(true); flash(before); showNews(); offerPerk(); checkAch(); }
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
    card.className = 'card';
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
    card.className = 'card back';
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
  if (['task', 'crisis', 'election', 'perk', 'rescue', 'era'].includes(kind)) sfx('good');
  if (kind === 'ach') sfx('ach');
  if (['crisisLost', 'fall', 'electionSoon'].includes(kind)) sfx('warn');
  toasts.push({ text, kind });
  if (toasts.length === 1) nextToast();
}
function nextToast() {
  const m = toasts[0];
  if (!m) return;
  const t = document.createElement('div');
  t.className = `toast ${m.kind}`;
  const ic = { law: 'law', task: 'task', era: 'era', crisis: 'crisis', crisisLost: 'crisis', election: 'vote', electionSoon: 'vote', rescue: 'rescue', perk: 'perk', fall: 'crisis', ach: 'trophy', sun: 'sun', age: 'era', enemy: 'crisis', friend: 'people' }[m.kind];
  t.innerHTML = (ic ? icon(ic, 'ico sm') : '') + `<span>${esc(m.text)}</span>`;
  document.body.appendChild(t);
  setTimeout(() => { t.remove(); toasts.shift(); nextToast(); }, m.kind ? 2800 : 1800);
}
/** Zprávy ze hry (zákon, úkol, éra) jako krátké oznámení. */
function showNews() {
  for (const n of state.news ?? []) {
    if (n.kind === 'age') { ageSplash(); continue; }
    toast(n.text, n.kind);
    if (n.kind === 'task') stats.tasks += 1;
    if (n.kind === 'election') stats.elections += 1;
    if (n.kind === 'crisis') stats.crises += 1;
  }
  if (state.news?.length) saveStats();
  if (state.news?.length) { state.news = []; save(); }
}

function ability() {
  if (busy || state.dead) return;
  const k = state.leader.kind;
  if (!ACTIVE.includes(k)) { kindInfo(); return; }
  if (!ready(state)) {
    const n = CHARGE - state.charge;
    toast(`Nabije se za ${n} rozhodnutí`);
    return;
  }
  if (k === 'odklad') {
    if (state.card === 'intro') { toast('Úvod odložit nejde'); return; }
    busy = true;
    ui.card.className = 'card fly';
    ui.card.style.transform = 'translate(0, 30px) scale(.85)';
    ui.card.style.opacity = '0';
    setTimeout(() => {
      skip(state); save(); busy = false;
      if (state.dead) { if (state.mode === 'blitz') { blitzFall(state.dead); return; } if (state.mode === 'daily') { dailyEnd(); return; } recordReign(); deathScreen(); return; }
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
      <div class="pane-head">${icon('perk', 'ico lg')}<div><b>Úkol splněn!</b><span class="dim">Vyber si jednu výhodu na zbytek vlády</span></div></div>
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
      <div class="mhead"><img src="icons/icon-192.png" alt=""><div><b>${esc(state.leader.name)}</b><small>${state.leader.n}. ${leaderTitle(state)}${state.mode === 'dejiny' ? ` · ${ageOf(state).name}` : ''}</small></div></div>
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
        <div class="stat"><span class="small">${l.female ? 'Vládla' : 'Vládl'}</span><b>${tenure(d.months)}</b></div>
        <div class="stat"><span class="small">Nejdelší vláda</span><b>${tenure(state.best)}</b></div>
        <div class="stat"><span class="small">Vůdců republiky</span><b>${l.n}</b></div>
        <div class="stat"><span class="small">Odemčené konce</span><b>${state.endings.length} z ${total}</b></div>
      </div>
      <div class="label">Jaký bude nástupce?</div>
      <div id="kp">${kindPicker()}</div>
      <button class="primary" id="next">Úřad přebírá nástupce</button>
      <button class="ghost" id="chron">Kronika a konce</button>
    </div>`;
  let kind = l.kind;
  bindPicker($('#kp'), kind, () => null, (k) => (kind = k));
  $('#next').onclick = () => { nextLeader(state, kind); save(); gameScreen(); toast(`Úkol: ${taskById(state.task.id).text}`, 'newtask'); };
  $('#chron').onclick = () => chronicleScreen(deathScreen);
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
      ${state.mode === 'dejiny' ? timeline() : ''}
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
        <tr><td class="n">${i + 1}.</td><td>${t.kind ? icon(t.kind, 'ico sm') : ''} ${esc(t.name)}<small>${esc(t.title)}</small></td><td class="r">${tenure(t.months)}</td></tr>`).join('')}</tbody></table>`
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
        <li>Nahoře je <b>sedm ukazatelů</b>: ${METERS.map((m) => m.name).join(', ')}.</li>
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

// ── Start ────────────────────────────────────────────
if ('serviceWorker' in navigator) navigator.serviceWorker.register('sw.js').catch(() => {});
if (state && state.dead) deathScreen();
else if (state && state.total > 0) gameScreen();
else startScreen();
