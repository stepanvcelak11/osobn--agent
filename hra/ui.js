// Rovnováha – zobrazení a ovládání (tažení karty do čtyř stran, šipky, klávesy, uložení hry).
import { portrait, meterIcon, glyph, icon, mood, mix } from './art.js';
import { newGame, choose, nextLeader, currentCard, preview, outcome, optionOf, unlocked, skip, nudge, ready, tenure, timeLabel, danger, kindOf, upgrade, activeLaws, seals, taskById, taskProgress, KINDS, CHARGE, NUDGE, METERS, ENDINGS, LAWS, TASKS, ERAS, SPECIAL, PEOPLE, REL_LOYAL } from './game.js';

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
  try { localStorage.setItem(SAVE, JSON.stringify(state)); } catch { /* soukromé okno – hraje se bez ukládání */ }
}
const esc = (t) => String(t).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]);
const ARROW = { left: '←', right: '→', up: '↑', down: '↓' };
const kindName = (k, female) => (female ? k.f : k.m);
const DIR_WORD = { left: 'doleva ←', right: 'doprava →', up: 'nahoru ↑', down: 'dolů ↓' };

/** Výběr typu prezidenta (start i nástupce): řada ikon a pod ní popis vybraného typu. Popis jde i přetáhnout prstem. */
function kindPicker() {
  return `<div class="kinds">${KINDS.map((k) => `<button class="kind" data-k="${k.id}" aria-label="${k.m}">${icon(k.id)}<span>${k.short}</span></button>`).join('')}</div>
    <div class="kdesc" id="kd"></div>`;
}
function bindPicker(root, selected, female, onPick) {
  let cur = selected;
  const show = (id) => {
    cur = id;
    const k = KINDS.find((x) => x.id === id);
    for (const b of root.querySelectorAll('.kind')) b.classList.toggle('on', b.dataset.k === id);
    const name = female() == null ? k.m.replace('Prezident s rádcem', 'S rádcem') : kindName(k, female());
    root.querySelector('.kdesc').innerHTML = `${icon(k.id, 'ico lg')}<div><b>${name}</b><small>${k.text}</small></div>`;
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
      <p>Rok 2089. Po Velkém výpadku z naší země zbyla Nová republika a právě tě zvolili do jejího čela.
        Udrž sedm sil v rovnováze – ideál je uprostřed, na krajích čeká katastrofa.</p>
      <div class="col">
        ${state ? `<button class="primary" id="cont">Pokračovat – ${esc(state.leader.name)}</button>` : ''}
        <button class="${state ? 'ghost' : 'primary'}" id="new">${state ? 'Nová hra od začátku' : 'Nová hra'}</button>
        <button class="ghost" id="help">Jak hrát</button>
      </div>
    </div>`;
  $('#help').onclick = () => helpScreen(startScreen);
  if (state) $('#cont').onclick = () => (state.dead ? deathScreen() : gameScreen());
  $('#new').onclick = setupScreen;
}

/** Nový vůdce: jméno, prezident/prezidentka a typ – vše na jedné obrazovce bez posouvání. */
function setupScreen() {
  let female = false, kind = 'vize';
  app.innerHTML = `
    <div class="start setup">
      <h2 class="title">Kdo povede republiku?</h2>
      <input id="name" maxlength="30" placeholder="Tvoje jméno" autocomplete="off" enterkeyhint="done">
      <div class="seg"><button id="m" class="on">Prezident</button><button id="f">Prezidentka</button></div>
      <div class="label">Jaký budeš vůdce?</div>
      <div id="kp">${kindPicker()}</div>
      <div class="col">
        <button class="primary" id="go">Začít vládnout</button>
        <button class="ghost" id="back">Zpět</button>
      </div>
    </div>`;
  const picker = bindPicker($('#kp'), kind, () => female, (k) => (kind = k));
  const seg = (f) => { female = f; $('#m').classList.toggle('on', !f); $('#f').classList.toggle('on', f); picker.refresh(); };
  $('#m').onclick = () => seg(false);
  $('#f').onclick = () => seg(true);
  $('#name').onkeydown = (e) => { if (e.key === 'Enter') e.target.blur(); };
  $('#back').onclick = startScreen;
  $('#go').onclick = () => {
    if (state && !confirm('Opravdu začít znovu? Současná hra i kronika vůdců se smažou (odemčené konce zůstanou).')) return;
    const keep = state ? { endings: state.endings, best: state.best } : null;
    state = newGame({ name: $('#name').value, female, kind }, (Math.random() * 2 ** 32) >>> 0);
    if (keep) Object.assign(state, keep);
    save();
    gameScreen();
    toast(`Úkol: ${taskById(state.task.id).text}`, 'newtask');
  };
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
      <div class="deck"><div class="card" id="card"></div></div>
    </section>
    <div class="name"><b><span id="person"></span><span id="mood"></span></b><div class="advice" id="adv"></div></div>`;
  ui = {
    card: $('#card'),
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
}

function render(enter) {
  const l = state.leader;
  $('#who').textContent = l.name;
  const k = kindOf(state);
  $('#nth').textContent = `${l.n}. ${l.female ? 'prezidentka' : 'prezident'} · ${timeLabel(state)}`;
  // Vpravo nahoře: ikona typu vůdce. U aktivních schopností kroužek ukazuje nabití.
  const ab = $('#ab'), active = ['odklad', 'kormidlo'].includes(k.id);
  if (ab.dataset.k !== k.id) { ab.querySelector('i').innerHTML = icon(k.id); ab.dataset.k = k.id; }
  ab.classList.toggle('active', active);
  ab.querySelector('.ring').style.strokeDasharray = active ? `${(Math.min(state.charge, CHARGE) / CHARGE) * 100} 100` : '0 100';
  ab.classList.toggle('ready', active && ready(state));
  ab.setAttribute('aria-label', kindName(k, l.female));
  $('#adv').innerHTML = state.advice ? `${icon('rada', 'ico sm')} Rádce radí: <b>${DIR_WORD[state.advice]}</b>` : '';
  for (const m of METERS) {
    const v = state.meters[m.id], d = danger(v);
    ui.levels[m.id].style.transform = `translateY(${((100 - v) * 0.24).toFixed(2)}px)`;
    ui.icons[m.id].classList.toggle('warn', d >= 0.45 && d < 0.7);
    ui.icons[m.id].classList.toggle('bad', d >= 0.7);
    ui.icons[m.id].parentElement.setAttribute('aria-label', `${m.name}: ${v} %`);
  }
  const c = currentCard(state);
  document.body.style.setProperty('--scene', mix(c.person.color, '#0d0c0b', 0.8));
  ui.q.firstElementChild.textContent = c.text;
  ui.person.textContent = c.person.name;
  $('#mood').innerHTML = mood(state.rel?.[c.who] ?? 0, REL_LOYAL);
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
    if (dir && state.leader.kind === 'vize') {
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
  card.className = 'card fly';
  card.style.transform = far;
  card.style.opacity = '0';
  selected = null;
  const before = { ...state.meters };
  setTimeout(() => {
    const dead = choose(state, dir);
    save();
    busy = false;
    if (dead) deathScreen(); else { render(true); flash(before); showNews(); }
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
function toast(text, kind = '') {
  toasts.push({ text, kind });
  if (toasts.length === 1) nextToast();
}
function nextToast() {
  const m = toasts[0];
  if (!m) return;
  const t = document.createElement('div');
  t.className = `toast ${m.kind}`;
  t.innerHTML = (m.kind && m.kind !== 'newtask' ? icon({ law: 'law', task: 'task', era: 'era' }[m.kind] || 'task', 'ico sm') : '') + `<span>${esc(m.text)}</span>`;
  document.body.appendChild(t);
  setTimeout(() => { t.remove(); toasts.shift(); nextToast(); }, m.kind ? 2800 : 1800);
}
/** Zprávy ze hry (zákon, úkol, éra) jako krátké oznámení. */
function showNews() {
  for (const n of state.news ?? []) toast(n.text, n.kind);
  if (state.news?.length) { state.news = []; save(); }
}

function ability() {
  if (busy || state.dead) return;
  const k = state.leader.kind;
  if (!['odklad', 'kormidlo'].includes(k)) { kindInfo(); return; }
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
    setTimeout(() => { skip(state); save(); busy = false; if (state.dead) { deathScreen(); return; } render(true); toast('Karta odložena'); showNews(); }, 220);
  }
  if (k === 'kormidlo') steerPicker();
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
      <button class="primary">Zpět do hry</button>
    </div>`;
  p.onclick = (e) => { if (e.target === p || e.target.tagName === 'BUTTON') p.remove(); };
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
  m.innerHTML = `
    <button class="primary" data-a="back">Zpět do hry</button>
    <button data-a="realm">Stav republiky</button>
    <button data-a="chron">Kronika a konce</button>
    <button data-a="help">Jak hrát</button>
    <button class="ghost" data-a="start">Hlavní nabídka</button>
    <div class="small">Hra se ukládá sama po každém rozhodnutí.</div>`;
  m.onclick = (e) => {
    const a = e.target.dataset?.a;
    if (!a && e.target !== m) return;
    m.remove();
    if (a === 'chron') chronicleScreen(gameScreen);
    if (a === 'realm') realmScreen(gameScreen);
    if (a === 'help') helpScreen(gameScreen);
    if (a === 'start') startScreen();
  };
  document.body.appendChild(m);
}

// ── Konec vlády ──────────────────────────────────────
function deathScreen() {
  ui = null;
  document.body.classList.remove('game');
  const d = state.dead, l = state.leader, m = METERS.find((x) => x.id === d.meter);
  const total = 14 + Object.keys(SPECIAL).length;
  app.innerHTML = `
    <div class="sheet">
      <div class="big">${d.special ? icon(d.special, 'ico xl') : glyph(m.id, 'glyph xl')}</div>
      <h2 class="${d.special ? 'legend' : ''}">${esc(d.title)}</h2>
      <div class="small" style="text-align:center">${d.special ? 'Tajný konec – legenda' : `Ukazatel ${m.name} ${d.side === 'low' ? 'klesl na nulu' : 'vystoupal na maximum'}`}</div>
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
      <h3>${icon('era', 'ico')} Éra: ${era.name}</h3>
      <div class="small">${nextEra ? `Další éra „${nextEra.name}“ přijde s časem${nextEra.seals ? ` a se ${nextEra.seals} pečetěmi (máš ${seals(state)})` : ''}.` : 'Svět dosáhl poslední éry.'}</div>
      <h3>${icon('task', 'ico')} Úkol vůdce</h3>
      ${t ? `<div class="box"><p>${esc(t.text)}</p><div class="bar"><i style="width:${Math.round((p.now / p.of) * 100)}%"></i></div><div class="small">${p.now} / ${p.of}</div></div>` : '<div class="small">Žádný úkol.</div>'}
      <div class="small">Pečetě (splněné úkoly): <b>${seals(state)} z ${TASKS.length}</b>. Splněný úkol hned nabije schopnost.</div>
      <h3>${icon('law', 'ico')} Zákony (${laws.length})</h3>
      ${laws.length ? laws.map((l) => `<div class="past"><span>${LAWS[l].name}</span><span class="per">${per(l)} / měsíc</span></div>`).join('') : '<div class="small">Žádný zákon zatím neplatí. Návrhy zákonů ti přinesou ministři.</div>'}
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
  const total = ends.length + Object.keys(SPECIAL).length;
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
        <li>Sbírej všech <b>14 konců</b> a překonej svou nejdelší vládu.</li>
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
