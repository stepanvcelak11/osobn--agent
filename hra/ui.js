// Rovnováha – zobrazení a ovládání (tažení karty do čtyř stran, klávesy, uložení hry).
import { newGame, choose, nextLeader, currentCard, preview, tenure, timeLabel, danger, DIRS, METERS, ENDINGS } from './game.js';

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
const ARROW = { left: '◀', right: '▶', up: '▲', down: '▼' };
const title = (l) => (l.female ? 'prezidentka' : 'prezident');

// ── Úvod ─────────────────────────────────────────────
function startScreen() {
  let female = false;
  app.innerHTML = `
    <div class="start">
      <h1>ROVNOVÁHA</h1>
      <p>Rok 2089. Po Velkém výpadku z naší země zbyla Nová republika. Právě tě zvolili do jejího čela.<br>Udrž sedm sil v rovnováze – ideál je uprostřed, na krajích čeká katastrofa.</p>
      <div class="col">
        ${state ? `<button class="primary" id="cont">Pokračovat – ${esc(state.leader.name)}</button>` : ''}
        <input id="name" maxlength="30" placeholder="Tvoje jméno" autocomplete="off">
        <div class="seg"><button id="m" class="on">Prezident</button><button id="f">Prezidentka</button></div>
        <button class="${state ? '' : 'primary'}" id="new">${state ? 'Nová hra od začátku' : 'Začít vládnout'}</button>
        <button id="help">Jak hrát</button>
      </div>
    </div>`;
  const seg = (f) => { female = f; app.querySelector('#m').classList.toggle('on', !f); app.querySelector('#f').classList.toggle('on', f); };
  app.querySelector('#m').onclick = () => seg(false);
  app.querySelector('#f').onclick = () => seg(true);
  app.querySelector('#help').onclick = () => helpScreen(startScreen);
  if (state) app.querySelector('#cont').onclick = () => (state.dead ? deathScreen() : gameScreen());
  app.querySelector('#new').onclick = () => {
    if (state && !confirm('Opravdu začít znovu? Současná hra i kronika se smažou.')) return;
    const keep = state ? { endings: state.endings, best: state.best } : null;
    state = newGame({ name: app.querySelector('#name').value, female }, (Math.random() * 2 ** 32) >>> 0);
    if (keep) Object.assign(state, keep);
    save();
    gameScreen();
  };
}

// ── Hra ──────────────────────────────────────────────
let selected = null; // směr vybraný klepnutím na šipku (druhé klepnutí potvrdí)

function gameScreen() {
  app.innerHTML = `
    <header class="meters">${METERS.map((m) => `
      <div class="meter" title="${m.name}" aria-label="${m.name}">
        <div class="bar"><div class="fill" data-m="${m.id}"></div><div class="mid"></div></div>
        <span class="ico">${m.icon}</span><span class="dot" data-d="${m.id}"></span>
      </div>`).join('')}
    </header>
    <div class="leader"><span><b id="who"></b> <span id="nth"></span></span><span id="time"></span></div>
    <section class="stage">
      <button class="hint" data-dir="up" aria-label="Volba nahoru">▲</button>
      <div class="row">
        <button class="hint" data-dir="left" aria-label="Volba doleva">◀</button>
        <div class="card" id="card"></div>
        <button class="hint" data-dir="right" aria-label="Volba doprava">▶</button>
      </div>
      <button class="hint" data-dir="down" aria-label="Volba dolů">▼</button>
    </section>
    <div class="tip" id="tip">Táhni kartu do jedné ze čtyř stran</div>
    <div class="bottom"><button id="chron">Kronika</button><button id="help">Jak hrát</button><button id="menu">Menu</button></div>`;
  app.querySelector('#chron').onclick = () => chronicleScreen(gameScreen);
  app.querySelector('#help').onclick = () => helpScreen(gameScreen);
  app.querySelector('#menu').onclick = startScreen;
  for (const b of app.querySelectorAll('.hint')) b.onclick = () => tapDir(b.dataset.dir);
  setupDrag(app.querySelector('#card'));
  render(true);
}

function render(enter) {
  const l = state.leader;
  app.querySelector('#who').textContent = l.name;
  app.querySelector('#nth').textContent = `· ${title(l)} č. ${l.n}`;
  app.querySelector('#time').textContent = timeLabel(state);
  for (const m of METERS) {
    const v = state.meters[m.id], f = app.querySelector(`.fill[data-m="${m.id}"]`), d = danger(v);
    f.style.height = `${v}%`;
    f.className = 'fill' + (d >= 0.7 ? ' bad' : d >= 0.45 ? ' warn' : '');
    f.parentElement.parentElement.setAttribute('aria-label', `${m.name}: ${v} %`);
  }
  const c = currentCard(state);
  const card = app.querySelector('#card');
  card.className = 'card' + (enter ? ' enter' : '');
  card.style.transform = '';
  card.style.opacity = '';
  card.innerHTML = `
    <div class="opt top" id="optTop"></div>
    <div class="portrait" style="background:${c.person.color}33">${c.person.icon}</div>
    <div class="who">${esc(c.person.name)}</div>
    <div class="text">${esc(c.text)}</div>
    <div class="opt bottom" id="optBottom"></div>`;
  showChoice(null);
}

/** Zvýrazní volbu: popisek na kartě a tečky u ukazatelů, kterých se týká. */
function showChoice(dir) {
  const c = currentCard(state);
  const top = app.querySelector('#optTop'), bottom = app.querySelector('#optBottom');
  for (const el of [top, bottom]) el.classList.remove('show');
  for (const b of app.querySelectorAll('.hint')) b.classList.toggle('on', b.dataset.dir === dir);
  const pv = dir ? preview(c, dir) : {};
  for (const m of METERS) app.querySelector(`.dot[data-d="${m.id}"]`).className = 'dot ' + (pv[m.id] || '');
  const tip = app.querySelector('#tip');
  if (!dir) { tip.textContent = selected ? '' : 'Táhni kartu do jedné ze čtyř stran'; return; }
  const el = dir === 'down' ? bottom : top;
  el.textContent = `${ARROW[dir]}  ${c.opts[dir].t}`;
  el.classList.add('show');
  tip.textContent = selected === dir ? 'Klepni znovu na šipku pro potvrzení' : '';
}

function tapDir(dir) {
  if (selected === dir) { selected = null; commit(dir); return; }
  selected = dir;
  showChoice(dir);
}

function commit(dir) {
  const card = app.querySelector('#card');
  const far = { left: 'translate(-140%, 0) rotate(-14deg)', right: 'translate(140%, 0) rotate(14deg)', up: 'translate(0, -130%)', down: 'translate(0, 130%)' }[dir];
  card.className = 'card fly';
  card.style.transform = far;
  card.style.opacity = '0';
  selected = null;
  setTimeout(() => {
    const dead = choose(state, dir);
    save();
    if (dead) deathScreen(); else render(true);
  }, 200);
}

function setupDrag(card) {
  let sx = 0, sy = 0, dx = 0, dy = 0, active = false;
  const dirOf = () => (Math.abs(dx) > Math.abs(dy) ? (dx > 0 ? 'right' : 'left') : (dy > 0 ? 'down' : 'up'));
  card.addEventListener('pointerdown', (e) => {
    active = true; sx = e.clientX; sy = e.clientY; dx = dy = 0;
    selected = null;
    card.className = 'card';
    card.setPointerCapture(e.pointerId);
  });
  card.addEventListener('pointermove', (e) => {
    if (!active) return;
    dx = e.clientX - sx; dy = e.clientY - sy;
    const horiz = Math.abs(dx) > Math.abs(dy);
    // Karta jde jen po ose převažujícího směru – volba je jednoznačná.
    card.style.transform = horiz ? `translate(${dx}px, ${dy * 0.15}px) rotate(${dx / 22}deg)` : `translate(${dx * 0.15}px, ${dy}px)`;
    showChoice(Math.max(Math.abs(dx), Math.abs(dy)) > 35 ? dirOf() : null);
  });
  const end = () => {
    if (!active) return;
    active = false;
    if (Math.max(Math.abs(dx), Math.abs(dy)) > 95) { commit(dirOf()); return; }
    card.className = 'card back';
    card.style.transform = '';
    showChoice(null);
  };
  card.addEventListener('pointerup', end);
  card.addEventListener('pointercancel', end);
}

document.addEventListener('keydown', (e) => {
  const dir = { ArrowLeft: 'left', ArrowRight: 'right', ArrowUp: 'up', ArrowDown: 'down' }[e.key];
  if (dir && app.querySelector('#card') && state && !state.dead) { e.preventDefault(); tapDir(dir); }
});

// ── Konec vlády ──────────────────────────────────────
function deathScreen() {
  const d = state.dead, l = state.leader, m = METERS.find((x) => x.id === d.meter);
  app.innerHTML = `
    <div class="sheet">
      <div class="small">${m.icon} ${m.name} – ${d.side === 'low' ? 'nula' : 'maximum'}</div>
      <h2>${esc(d.title)}</h2>
      <p>${esc(d.text)}</p>
      <div class="small">${esc(l.name)}, ${title(l)} č. ${l.n}, ${l.female ? 'vládla' : 'vládl'} ${tenure(d.months)}.
        Nejdelší vláda: ${tenure(state.best)}. Odemčené konce: ${state.endings.length} ze 14.</div>
      <button class="primary" id="next">Úřad přebírá nástupce</button>
      <button id="chron">Kronika</button>
    </div>`;
  app.querySelector('#next').onclick = () => { nextLeader(state); save(); gameScreen(); };
  app.querySelector('#chron').onclick = () => chronicleScreen(deathScreen);
}

// ── Kronika ──────────────────────────────────────────
function chronicleScreen(back) {
  const past = [...state.history].reverse();
  const ends = METERS.flatMap((m) => ['low', 'high'].map((s) => ({ key: `${m.id}.${s}`, m, s, e: ENDINGS[m.id][s] })));
  app.innerHTML = `
    <div class="sheet">
      <h3>Vůdci republiky</h3>
      ${past.length ? past.map((h) => `<div class="past"><span>${h.n}. ${esc(h.name)}</span><span>${tenure(h.months)} · ${esc(h.title)}</span></div>`).join('')
        : '<p class="small">Zatím nikdo nepadl. Vládni dlouho!</p>'}
      <h3>Konce (${state.endings.length} ze 14)</h3>
      <div class="endings">${ends.map(({ key, m, s, e }) => state.endings.includes(key)
        ? `<div class="ending"><b>${m.icon} ${esc(e.title)}</b>${m.name} ${s === 'low' ? 'na nule' : 'na maximu'}</div>`
        : `<div class="ending locked"><b>${m.icon} ???</b>${m.name} ${s === 'low' ? 'na nule' : 'na maximu'}</div>`).join('')}
      </div>
      <button class="primary" id="back">Zpět</button>
    </div>`;
  app.querySelector('#back').onclick = back;
}

// ── Nápověda ─────────────────────────────────────────
function helpScreen(back) {
  app.innerHTML = `
    <div class="sheet help">
      <h3>Jak hrát</h3>
      <ul>
        <li>Za tebou chodí ministři, generálové, vědci i obyčejní lidé. Každá karta má <b>čtyři možnosti</b> – táhni ji <b>doleva, doprava, nahoru, nebo dolů</b>. Můžeš také klepnout na šipku (ukáže volbu) a klepnutím znovu ji potvrdit.</li>
        <li>Nahoře je <b>sedm ukazatelů</b>: ${METERS.map((m) => `${m.icon} ${m.name}`).join(', ')}.</li>
        <li><b>Ideál je uprostřed.</b> Když ukazatel klesne na nulu, nebo vystoupá na maximum, tvá vláda skončí katastrofou.</li>
        <li>Při tažení se pod ukazateli objeví <b>tečky</b>: ukazují, čeho se rozhodnutí dotkne (velká tečka = hodně). Jestli nahoru, nebo dolů, musíš odhadnout.</li>
        <li>Rozhodnutí mají následky – některé se ti vrátí za pár měsíců. Když padneš, úřad převezme nástupce, ale svět si pamatuje, co se stalo.</li>
        <li>Sbírej všech <b>14 konců</b> a překonej svou nejdelší vládu.</li>
        <li>Hra běží offline. V Safari dej <b>Sdílet → Přidat na plochu</b> a hraj jako aplikaci.</li>
      </ul>
      <button class="primary" id="back">Zpět</button>
    </div>`;
  app.querySelector('#back').onclick = back;
}

// ── Start ────────────────────────────────────────────
if ('serviceWorker' in navigator) navigator.serviceWorker.register('sw.js').catch(() => {});
if (state && !state.dead && state.total > 0) gameScreen(); else startScreen();
