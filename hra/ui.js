// Rovnováha – zobrazení a ovládání (tažení karty do čtyř stran, šipky, klávesy, uložení hry).
import { portrait, meterIcon, mix } from './art.js';
import { newGame, choose, nextLeader, currentCard, preview, tenure, timeLabel, danger, METERS, ENDINGS } from './game.js';

const SAVE = 'rovnovaha.save';
const app = document.getElementById('app');
let state = load();

function load() {
  try { const s = JSON.parse(localStorage.getItem(SAVE)); return s && s.v === 1 ? s : null; } catch { return null; }
}
function save() {
  try { localStorage.setItem(SAVE, JSON.stringify(state)); } catch { /* soukromé okno – hraje se bez ukládání */ }
}
const esc = (t) => String(t).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]);
const ARROW = { left: '←', right: '→', up: '↑', down: '↓' };
const title = (l) => (l.female ? 'prezidentka' : 'prezident');
const $ = (sel) => app.querySelector(sel);

// ── Úvod ─────────────────────────────────────────────
function startScreen() {
  document.body.classList.remove('game');
  let female = false;
  app.innerHTML = `
    <div class="start">
      <img class="logo" src="icons/icon-192.png" alt="">
      <h1>ROVNOVÁHA</h1>
      <p>Rok 2089. Po Velkém výpadku z naší země zbyla Nová republika a právě tě zvolili do jejího čela.
        Udrž sedm sil v rovnováze – ideál je uprostřed, na krajích čeká katastrofa.</p>
      <div class="col">
        ${state ? `<button class="primary" id="cont">Pokračovat – ${esc(state.leader.name)}</button>` : ''}
        <input id="name" maxlength="30" placeholder="Tvoje jméno" autocomplete="off" enterkeyhint="go">
        <div class="seg"><button id="m" class="on">Prezident</button><button id="f">Prezidentka</button></div>
        <button class="${state ? 'ghost' : 'primary'}" id="new">${state ? 'Nová hra od začátku' : 'Začít vládnout'}</button>
        <button class="ghost" id="help">Jak hrát</button>
      </div>
    </div>`;
  const seg = (f) => { female = f; $('#m').classList.toggle('on', !f); $('#f').classList.toggle('on', f); };
  $('#m').onclick = () => seg(false);
  $('#f').onclick = () => seg(true);
  $('#help').onclick = () => helpScreen(startScreen);
  if (state) $('#cont').onclick = () => (state.dead ? deathScreen() : gameScreen());
  $('#new').onclick = () => {
    if (state && !confirm('Opravdu začít znovu? Současná hra i kronika vůdců se smažou (odemčené konce zůstanou).')) return;
    const keep = state ? { endings: state.endings, best: state.best } : null;
    state = newGame({ name: $('#name').value, female }, (Math.random() * 2 ** 32) >>> 0);
    if (keep) Object.assign(state, keep);
    save();
    gameScreen();
  };
}

// ── Hra ──────────────────────────────────────────────
let ui = null;       // odkazy na prvky herní obrazovky
let selected = null; // směr vybraný klepnutím na šipku (druhé klepnutí potvrdí)
let busy = false;    // karta právě odlétá

function gameScreen() {
  document.body.classList.add('game');
  app.innerHTML = `
    <div class="top">
      <button class="burger" id="menu" aria-label="Nabídka"><i></i><i></i><i></i></button>
      <div class="leader"><b id="who"></b><span id="nth"></span></div>
      <span></span>
    </div>
    <header class="meters">${METERS.map((m) => `
      <div class="meter" aria-label="${m.name}">${meterIcon(m.id)}<span class="dot" data-d="${m.id}"></span></div>`).join('')}
    </header>
    <div class="question" id="q"><p></p></div>
    <section class="stage">
      ${['up', 'left', 'right', 'down'].map((d) => `<button class="chev ${d}" data-dir="${d}" aria-label="Volba ${d}">${{ up: '▲', down: '▼', left: '◀', right: '▶' }[d]}</button>`).join('')}
      <div class="deck"><div class="card" id="card"></div></div>
    </section>
    <div class="name"><b id="person"></b></div>
    <div class="tip" id="tip"></div>`;
  ui = {
    card: $('#card'),
    q: $('#q'),
    person: $('#person'),
    icons: Object.fromEntries(METERS.map((m) => [m.id, app.querySelector(`.meter:nth-child(${METERS.indexOf(m) + 1}) .micon`)])),
    levels: Object.fromEntries(METERS.map((m) => [m.id, $(`.lvl[data-l="${m.id}"]`)])),
    dots: Object.fromEntries(METERS.map((m) => [m.id, $(`.dot[data-d="${m.id}"]`)])),
    chev: Object.fromEntries([...app.querySelectorAll('.chev')].map((b) => [b.dataset.dir, b])),
    tip: $('#tip'),
  };
  $('#menu').onclick = menu;
  for (const b of Object.values(ui.chev)) b.onclick = () => tapDir(b.dataset.dir);
  setupDrag(ui.card);
  render(true);
}

function render(enter) {
  const l = state.leader;
  $('#who').textContent = l.name;
  $('#nth').textContent = `${title(l)} č. ${l.n} · ${timeLabel(state)}`;
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
  const card = ui.card;
  card.className = 'card' + (enter ? ' enter' : '');
  card.style.transform = '';
  card.style.opacity = '';
  card.innerHTML = portrait(c.person) +
    ['left', 'right', 'up', 'down'].map((d) => `<div class="opt ${d}" data-o="${d}">${esc(c.opts[d].t)}</div>`).join('');
  ui.opts = Object.fromEntries([...card.querySelectorAll('.opt')].map((o) => [o.dataset.o, o]));
  fitText(ui.q);
  current = null;
  highlight(null, 0);
  ui.tip.textContent = state.total < 3 ? 'Táhni kartu doleva, doprava, nahoru, nebo dolů' : '';
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
    if (current && ui.opts[current]) ui.opts[current].style.opacity = 0;
    for (const [d, b] of Object.entries(ui.chev)) b.classList.toggle('on', d === dir);
    ui.card.classList.toggle('choosing', !!dir);
    const pv = dir ? preview(currentCard(state), dir) : {};
    for (const m of METERS) ui.dots[m.id].className = 'dot ' + (pv[m.id] || '');
    current = dir;
  }
  if (dir && ui.opts[dir]) ui.opts[dir].style.opacity = String(Math.min(1, strength));
}

function tapDir(dir) {
  if (busy) return;
  if (selected === dir) { selected = null; commit(dir); return; }
  selected = dir;
  highlight(dir, 1);
  ui.tip.textContent = 'Klepni na šipku znovu pro potvrzení';
}

function commit(dir) {
  busy = true;
  const card = ui.card;
  const far = { left: 'translate(-150%, 30px) rotate(-16deg)', right: 'translate(150%, 30px) rotate(16deg)', up: 'translate(0, -140%)', down: 'translate(0, 140%)' }[dir];
  card.className = 'card fly';
  card.style.transform = far;
  card.style.opacity = '0';
  selected = null;
  setTimeout(() => {
    const dead = choose(state, dir);
    save();
    busy = false;
    if (dead) deathScreen(); else render(true);
  }, 220);
}

function setupDrag(card) {
  let sx = 0, sy = 0, dx = 0, dy = 0, t0 = 0, active = false, frame = 0;
  const dirOf = () => (Math.abs(dx) > Math.abs(dy) ? (dx > 0 ? 'right' : 'left') : (dy > 0 ? 'down' : 'up'));
  // Překreslení jen jednou za snímek obrazovky – tažení je plynulé.
  const paint = () => {
    frame = 0;
    const horiz = Math.abs(dx) > Math.abs(dy);
    // Svisle karta jede jen kousek (s odporem), aby nezakryla ukazatele a tečky nahoře.
    const vy = dy < 0 ? -Math.min(45, -dy * 0.35) : Math.min(90, dy * 0.5);
    card.style.transform = horiz ? `translate3d(${dx}px, ${dy * 0.1}px, 0) rotate(${dx / 24}deg)` : `translate3d(${dx * 0.1}px, ${vy}px, 0)`;
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
  if (dir && ui && document.contains(ui.card) && state && !state.dead && !document.querySelector('.menu')) { e.preventDefault(); tapDir(dir); }
});

// ── Nabídka (tři čárky) ──────────────────────────────
function menu() {
  const m = document.createElement('div');
  m.className = 'menu';
  m.innerHTML = `
    <button class="primary" data-a="back">Zpět do hry</button>
    <button data-a="chron">Kronika a konce</button>
    <button data-a="help">Jak hrát</button>
    <button class="ghost" data-a="start">Hlavní nabídka</button>
    <div class="small">Hra se ukládá sama po každém rozhodnutí.</div>`;
  m.onclick = (e) => {
    const a = e.target.dataset?.a;
    if (!a && e.target !== m) return;
    m.remove();
    if (a === 'chron') chronicleScreen(gameScreen);
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
  app.innerHTML = `
    <div class="sheet">
      <div class="big">${m.icon}</div>
      <h2>${esc(d.title)}</h2>
      <div class="small" style="text-align:center">Ukazatel ${m.name} ${d.side === 'low' ? 'klesl na nulu' : 'vystoupal na maximum'}</div>
      <p>${esc(d.text)}</p>
      <div class="stats">
        <div class="stat"><span class="small">${l.female ? 'Vládla' : 'Vládl'}</span><b>${tenure(d.months)}</b></div>
        <div class="stat"><span class="small">Nejdelší vláda</span><b>${tenure(state.best)}</b></div>
        <div class="stat"><span class="small">Vůdců republiky</span><b>${l.n}</b></div>
        <div class="stat"><span class="small">Odemčené konce</span><b>${state.endings.length} ze 14</b></div>
      </div>
      <div class="spacer"></div>
      <button class="primary" id="next">Úřad přebírá nástupce</button>
      <button class="ghost" id="chron">Kronika a konce</button>
    </div>`;
  $('#next').onclick = () => { nextLeader(state); save(); gameScreen(); };
  $('#chron').onclick = () => chronicleScreen(deathScreen);
}

// ── Kronika ──────────────────────────────────────────
function chronicleScreen(back) {
  ui = null;
  document.body.classList.remove('game');
  const past = [...state.history].reverse();
  const ends = METERS.flatMap((m) => ['low', 'high'].map((s) => ({ key: `${m.id}.${s}`, m, s, e: ENDINGS[m.id][s] })));
  app.innerHTML = `
    <div class="sheet">
      <h3>Vůdci republiky</h3>
      ${past.length ? past.map((h) => `<div class="past"><span>${h.n}. ${esc(h.name)}</span><span>${tenure(h.months)} · ${esc(h.title)}</span></div>`).join('')
        : '<div class="small">Zatím nikdo nepadl. Vládni dlouho!</div>'}
      <h3>Konce (${state.endings.length} ze 14)</h3>
      <div class="endings">${ends.map(({ key, m, s, e }) => `
        <div class="ending ${state.endings.includes(key) ? '' : 'locked'}">
          <b>${m.icon} ${state.endings.includes(key) ? esc(e.title) : '???'}</b>${m.name} ${s === 'low' ? 'na nule' : 'na maximu'}
        </div>`).join('')}
      </div>
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
        <li>Nahoře je <b>sedm ukazatelů</b>: ${METERS.map((m) => `${m.icon} ${m.name}`).join(', ')}.</li>
        <li><b>Ideál je uprostřed</b> (světlejší pásmo). Když ukazatel klesne na nulu, nebo vystoupá na maximum, vláda skončí katastrofou.</li>
        <li>Při tažení se pod ukazateli objeví <b>tečky</b> – čeho se rozhodnutí dotkne (větší = víc). Jestli nahoru, nebo dolů, musíš odhadnout.</li>
        <li>Rozhodnutí mají následky – některá se ti vrátí za pár měsíců. Když padneš, úřad převezme nástupce, ale svět si pamatuje, co se stalo.</li>
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
