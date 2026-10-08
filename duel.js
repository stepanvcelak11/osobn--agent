// Hra pro dva: rozdělená obrazovka, bleskovka pro dva naráz. Spodní polovina patří hráči 1,
// horní (otočená vzhůru nohama) hráči 2 – každý drží telefon ze své strany. Každý má vlastního vůdce,
// vlastní karty i vlastní hodiny. Vyhrává ten, kdo se dostane nejdál (doba, pak počet rozhodnutí).
import { portrait, meterIcon, icon, glyph, mix } from './art.js';
import { newRun, choose, nextLeader, currentCard, cardById, optionOf, preview, outcome, skip, nudge, reformLaw, choosePerk, ready,
  activeLaws, kindOf, seesDirection, seesAhead, touches, personOf, ageOf, leaderTitle, KINDS, ACTIVE, CHARGE, METERS, PEOPLE, PERKS, AGES } from './game.js';

export const DUEL_START = 120; // sekund na začátku
export const DUEL_BONUS = 4;   // za každé rozhodnutí
export const DUEL_FALL = 15;   // pád vlády

const esc = (t) => String(t).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' })[c]);
const DIRS = ['left', 'right', 'up', 'down'];

/** Nastavení na rozdělené obrazovce: každý hráč si na své polovině vybere vůdce.
 *  `ctx` = { app, home, sfx, unlocked: [id], award(n, why) } */
export function duelSetup(ctx) {
  const { app } = ctx;
  const can = (id) => !ctx.unlocked || ctx.unlocked.includes(id);
  const half = (p) => `
    <section class="half ${p ? 'top' : 'bottom'} dsetup" data-p="${p}">
      <div class="dstitle">${p ? 'Hráč 2' : 'Hráč 1'}</div>
      <div class="kinds">${KINDS.map((k) => `<button class="kind${k.id === 'vize' ? ' on' : ''}${can(k.id) ? '' : ' locked'}" data-k="${k.id}" aria-label="${k.m}">${icon(k.id)}</button>`).join('')}</div>
      <div class="dk"><b>${KINDS[0].m}</b> ${KINDS[0].text}</div>
      <button class="primary dready">Připraven</button>
    </section>`;
  app.innerHTML = `
    <div class="duel dsetupwrap">
      ${half(1)}
      <div class="dmid">
        <button class="ghost" data-a="back">✕</button>
        <div class="seg world"><button data-w="dejiny" class="on">${icon('era', 'ico sm')} Dějiny</button><button data-w="2089">${icon('kontakt', 'ico sm')} Rok 2089</button></div>
      </div>
      ${half(0)}
    </div>`;
  document.body.classList.add('duelmode');
  const kinds = ['vize', 'vize'], ready = [false, false];
  let world = 'dejiny';
  for (const box of app.querySelectorAll('.dsetup')) {
    const p = Number(box.dataset.p);
    for (const b of box.querySelectorAll('.kind')) b.onclick = () => {
      const k = KINDS.find((x) => x.id === b.dataset.k);
      if (!can(k.id)) { box.querySelector('.dk').innerHTML = `<b>${k.m}</b> je zamčený – odemkni ho za body v obchodě.`; return; }
      kinds[p] = k.id;
      for (const x of box.querySelectorAll('.kind')) x.classList.toggle('on', x === b);
      box.querySelector('.dk').innerHTML = `<b>${k.m}</b> ${k.text}`;
    };
    box.querySelector('.dready').onclick = (e) => {
      ready[p] = !ready[p];
      e.target.classList.toggle('on', ready[p]);
      e.target.textContent = ready[p] ? 'Připraven ✓ (čekám na soupeře)' : 'Připraven';
      if (ready.every(Boolean)) {
        const names = ['Hráč 1', 'Hráč 2'];
        startDuel(ctx, { names, kinds, world });
      }
    };
  }
  for (const b of app.querySelectorAll('[data-w]')) b.onclick = () => {
    world = b.dataset.w;
    for (const x of app.querySelectorAll('[data-w]')) x.classList.toggle('on', x === b);
  };
  app.querySelector('[data-a="back"]').onclick = () => { document.body.classList.remove('duelmode'); ctx.home(); };
}

/** Samotný souboj. */
function startDuel(ctx, cfg) {
  const { app } = ctx;
  const seed = (Math.random() * 2 ** 32) >>> 0;
  const players = [0, 1].map((p) => ({
    p, name: cfg.names[p],
    st: newRun({ name: cfg.names[p], kind: cfg.kinds[p], world: cfg.world }, seed, 'duel'),
    left: DUEL_START * 1000, decisions: 0, falls: 0, done: false, busy: false,
  }));
  document.body.classList.add('game', 'duelmode');
  app.innerHTML = `<div class="duel">${[1, 0].map((p) => `
    <section class="half ${p ? 'top' : 'bottom'}" data-p="${p}">
      <div class="dhead"><b class="dname">${esc(players[p].name)}</b><span class="dsub"></span><span class="dclock"></span><button class="dab" aria-label="Schopnost"></button></div>
      <div class="dmeters">${METERS.map((m) => `<span class="dm" data-m="${m.id}">${meterIcon(m.id).replace(/clip-/g, `d${p}clip-`)}<i class="mbar"><b></b></i><i class="dot"></i></span>`).join('')}</div>
      <div class="dq"><p></p></div>
      <div class="dstage"><div class="ddeck"><div class="card dcard"></div></div></div>
      <div class="dwho"></div>
      <div class="dtoast"></div>
      <div class="dover" hidden></div>
    </section>`).join('<button class="dpause" aria-label="Pauza">II</button>')}</div>`;
  const half = (p) => app.querySelector(`.half[data-p="${p}"]`);
  let paused = false, last = performance.now(), over = false;

  const toast = (pl, text) => {
    const t = half(pl.p).querySelector('.dtoast');
    t.textContent = text;
    t.classList.add('on');
    clearTimeout(t._h);
    t._h = setTimeout(() => t.classList.remove('on'), 2200);
  };
  const clock = (pl) => {
    const sec = Math.max(0, Math.ceil(pl.left / 1000));
    const el = half(pl.p).querySelector('.dclock');
    el.textContent = `${Math.floor(sec / 60)}:${String(sec % 60).padStart(2, '0')}`;
    el.classList.toggle('hurry', sec <= 15);
  };
  const render = (pl, enter) => {
    const h = half(pl.p), s = pl.st;
    const age = s.age ?? 7;
    h.querySelector('.dsub').textContent = `${cfg.world === 'dejiny' ? `${ageOf(s).name} · ` : ''}${pl.decisions} rozh.`;
    const k = kindOf(s), ab = h.querySelector('.dab');
    ab.innerHTML = icon(k.id, 'ico');
    ab.classList.toggle('ready', ACTIVE.includes(k.id) && ready(s));
    ab.style.opacity = ACTIVE.includes(k.id) ? (ready(s) ? 1 : 0.45) : 0.8;
    for (const m of METERS) {
      const v = s.meters[m.id], d = Math.abs(v - 50) / 50, ic = h.querySelector(`.dm[data-m="${m.id}"] .micon`);
      h.querySelector(`.dm[data-m="${m.id}"] .lvl`).style.transform = `translateY(${((100 - v) * 0.24).toFixed(2)}px)`;
      ic.classList.toggle('warn', d >= 0.45 && d < 0.7);
      ic.classList.toggle('bad', d >= 0.7);
      const bar = h.querySelector(`.dm[data-m="${m.id}"] .mbar`);
      bar.firstElementChild.style.width = `${v}%`;
      bar.className = `mbar${d >= 0.7 ? ' bad' : d >= 0.45 ? ' warn' : ''}`;
    }
    const c = currentCard(s);
    h.style.setProperty('--scene', mix(c.person.color, '#0d0c0b', 0.8));
    h.querySelector('.dq p').textContent = c.text;
    fit(h.querySelector('.dq'));
    const chips = [];
    if (s.advice) chips.push(`${icon('rada', 'ico sm')} radí: ${{ left: '←', right: '→', up: '↑', down: '↓' }[s.advice]}`);
    if (s.peek && seesAhead(s)) chips.push(`${icon('prorok', 'ico sm')} ${touches(s, s.peek).map((x) => glyph(x, 'glyph sm')).join('')}`);
    h.querySelector('.dwho').innerHTML = `<b>${esc(c.person.name)}</b>${chips.length ? ` <span>${chips.join(' ')}</span>` : ''}`;
    const card = h.querySelector('.dcard');
    card.className = `card dcard age${age}${enter ? ' enter' : ''}`;
    card.style.transform = '';
    card.style.opacity = '';
    card.innerHTML = portrait(c.person, age) + DIRS.map((d) => `<div class="opt ${d}" data-o="${d}">${esc(optionOf(s, c, d).t)}</div>`).join('');
    pl.cur = null;
    dots(pl, null);
  };
  const dots = (pl, dir) => {
    const h = half(pl.p), s = pl.st;
    let pv = {};
    if (dir && seesDirection(s)) {
      const after = outcome(s, dir);
      for (const m of METERS) { const d = after[m.id] - s.meters[m.id]; if (d) pv[m.id] = d > 0 ? 'rise' : 'fall'; }
    } else if (dir) pv = preview(currentCard(s), dir, s);
    for (const m of METERS) h.querySelector(`.dm[data-m="${m.id}"] .dot`).className = `dot ${pv[m.id] || ''}`;
  };
  const fit = (box) => {
    let size = 16;
    box.style.fontSize = `${size}px`;
    while (size > 11 && box.firstElementChild.scrollHeight > box.clientHeight) box.style.fontSize = `${--size}px`;
  };
  const news = (pl) => {
    for (const n of pl.st.news ?? []) if (!['newtask', 'traitorHint'].includes(n.kind)) toast(pl, n.text);
    pl.st.news = [];
    // Výhodu po splněném úkolu vybere hra sama (na rozdělené obrazovce není místo na okno).
    if (pl.st.perkOffer) { const id = pl.st.perkOffer[0]; choosePerk(pl.st, id); toast(pl, `Výhoda: ${PERKS[id].name}`); }
  };
  const flash = (pl, before) => {
    const h = half(pl.p);
    for (const m of METERS) {
      const d = pl.st.meters[m.id] - before[m.id], ic = h.querySelector(`.dm[data-m="${m.id}"] .micon`);
      ic.classList.remove('rise', 'fall');
      if (d) { void ic.getBoundingClientRect(); ic.classList.add(d > 0 ? 'rise' : 'fall'); setTimeout(() => ic.classList.remove('rise', 'fall'), 1400); }
    }
  };
  const commit = (pl, dir) => {
    if (pl.busy || pl.done || paused || over) return;
    pl.busy = true;
    const card = half(pl.p).querySelector('.dcard');
    card.className = `card dcard fly age${pl.st.age ?? 7}`;
    card.style.transform = { left: 'translate(-150%, 30px) rotate(-16deg)', right: 'translate(150%, 30px) rotate(16deg)', up: 'translate(0, -140%)', down: 'translate(0, 140%)' }[dir];
    card.style.opacity = '0';
    ctx.sfx('swipe');
    const before = { ...pl.st.meters };
    setTimeout(() => {
      const dead = choose(pl.st, dir);
      pl.decisions += 1;
      pl.left += DUEL_BONUS * 1000;
      pl.busy = false;
      if (dead) fall(pl);
      render(pl, true);
      flash(pl, before);
      news(pl);
    }, 200);
  };
  const fall = (pl) => {
    const d = pl.st.dead;
    pl.falls += 1;
    pl.left -= DUEL_FALL * 1000;
    nextLeader(pl.st, pl.st.leader.kind);
    pl.st.news = [];
    toast(pl, `${d.title} · −${DUEL_FALL} s, nastupuje nástupce`);
    ctx.sfx('warn');
  };
  const ability = (pl) => {
    const s = pl.st, k = s.leader.kind;
    if (pl.done || paused || !ACTIVE.includes(k)) { toast(pl, kindOf(s).text); return; }
    if (!ready(s)) { toast(pl, `Schopnost se nabije za ${CHARGE - s.charge} rozhodnutí`); return; }
    const before = { ...s.meters };
    if (k === 'odklad' && skip(s)) { toast(pl, 'Karta odložena'); if (s.dead) fall(pl); }
    if (k === 'kormidlo') {
      const [id] = Object.entries(s.meters).sort((a, b) => Math.abs(b[1] - 50) - Math.abs(a[1] - 50))[0];
      if (nudge(s, id)) toast(pl, `${METERS.find((m) => m.id === id).name} se vrací k rovnováze`);
    }
    if (k === 'reform') {
      const laws = activeLaws(s);
      if (laws.length && reformLaw(s, laws[laws.length - 1])) toast(pl, 'Poslední zákon zrušen');
      else toast(pl, 'Žádný zákon ke zrušení');
    }
    render(pl, false);
    flash(pl, before);
    news(pl);
  };
  // Tažení karty – každý hráč svým prstem (víc dotyků naráz). Horní polovina je otočená, proto se posun obrací.
  const drag = (pl) => {
    const h = half(pl.p), flip = pl.p === 1 ? -1 : 1;
    let sx = 0, sy = 0, dx = 0, dy = 0, t0 = 0, id = null;
    const dirOf = () => (Math.abs(dx) > Math.abs(dy) ? (dx > 0 ? 'right' : 'left') : (dy > 0 ? 'down' : 'up'));
    h.querySelector('.dstage').addEventListener('pointerdown', (e) => {
      const card = e.target.closest('.dcard');
      if (!card || pl.busy || pl.done || paused || id !== null) return;
      id = e.pointerId; sx = e.clientX; sy = e.clientY; dx = dy = 0; t0 = performance.now();
      card.className = `card dcard age${pl.st.age ?? 7}`;
      card.setPointerCapture(id);
    });
    h.querySelector('.dstage').addEventListener('pointermove', (e) => {
      if (e.pointerId !== id) return;
      dx = (e.clientX - sx) * flip; dy = (e.clientY - sy) * flip;
      const card = h.querySelector('.dcard');
      const vy = dy < 0 ? -30 * (1 - Math.exp(dy / 100)) : 50 * (1 - Math.exp(-dy / 140));
      card.style.transform = `translate3d(${dx.toFixed(1)}px, ${vy.toFixed(1)}px, 0) rotate(${(dx / 22).toFixed(2)}deg)`;
      const dist = Math.max(Math.abs(dx), Math.abs(dy)), dir = dist > 14 ? dirOf() : null;
      if (dir !== pl.cur) {
        for (const o of card.querySelectorAll('.opt')) o.style.opacity = 0;
        pl.cur = dir;
        dots(pl, dir);
      }
      if (dir) card.querySelector(`.opt.${dir}`).style.opacity = String(Math.min(1, (dist - 14) / 40));
    });
    const end = (e) => {
      if (e.pointerId !== id) return;
      id = null;
      const dist = Math.max(Math.abs(dx), Math.abs(dy)), speed = dist / Math.max(1, performance.now() - t0);
      if (dist > 70 || (dist > 32 && speed > 0.6)) { commit(pl, dirOf()); return; }
      const card = h.querySelector('.dcard');
      card.className = `card dcard back age${pl.st.age ?? 7}`;
      card.style.transform = '';
      for (const o of card.querySelectorAll('.opt')) o.style.opacity = 0;
      pl.cur = null;
      dots(pl, null);
    };
    h.querySelector('.dstage').addEventListener('pointerup', end);
    h.querySelector('.dstage').addEventListener('pointercancel', end);
    h.querySelector('.dab').onclick = () => ability(pl);
  };
  const score = (pl) => [cfg.world === 'dejiny' ? pl.st.age ?? 7 : 0, pl.decisions];
  const finishPlayer = (pl) => {
    pl.done = true;
    pl.left = 0;
    clock(pl);
    const o = half(pl.p).querySelector('.dover');
    o.hidden = false;
    o.innerHTML = `<b>Čas vypršel</b><span>${cfg.world === 'dejiny' ? `${ageOf(pl.st).name} · ` : ''}${pl.decisions} rozhodnutí</span><small>Počkej na soupeře…</small>`;
    ctx.sfx('end');
  };
  const results = () => {
    over = true;
    clearInterval(timer);
    const [a, b] = players, sa = score(a), sb = score(b);
    const cmp = sa[0] - sb[0] || sa[1] - sb[1];
    for (const pl of players) {
      const other = players[1 - pl.p], me = cmp === 0 ? 0 : (pl.p === 0 ? cmp : -cmp);
      const o = half(pl.p).querySelector('.dover');
      o.hidden = false;
      o.className = `dover final ${me > 0 ? 'win' : me < 0 ? 'lose' : ''}`;
      o.innerHTML = `<b>${me > 0 ? 'Vítězství!' : me < 0 ? 'Prohra' : 'Remíza'}</b>
        <span>Ty: ${cfg.world === 'dejiny' ? `${ageOf(pl.st).name}, ` : ''}${pl.decisions} rozhodnutí, ${pl.falls} ${pl.falls === 1 ? 'pád' : pl.falls >= 2 && pl.falls <= 4 ? 'pády' : 'pádů'}</span>
        <span>${esc(other.name)}: ${cfg.world === 'dejiny' ? `${ageOf(other.st).name}, ` : ''}${other.decisions} rozhodnutí</span>
        <div class="drow"><button class="primary" data-a="again">Odveta</button><button class="ghost" data-a="end">Konec</button></div>`;
      o.querySelector('[data-a="again"]').onclick = () => startDuel(ctx, cfg);
      o.querySelector('[data-a="end"]').onclick = () => { document.body.classList.remove('duelmode'); ctx.home(); };
    }
    ctx.sfx('ach');
    if (cmp !== 0 && ctx.award) ctx.award(1, `vítězství v souboji (${esc(players[cmp > 0 ? 0 : 1].name)})`);
  };
  const timer = setInterval(() => {
    const now = performance.now(), dt = now - last;
    last = now;
    if (paused || over || document.hidden) return;
    for (const pl of players) {
      if (pl.done) continue;
      pl.left -= dt;
      clock(pl);
      if (pl.left <= 0) finishPlayer(pl);
    }
    if (players.every((pl) => pl.done)) results();
  }, 200);
  app.querySelector('.dpause').onclick = () => {
    if (over) return;
    paused = !paused;
    app.querySelector('.duel').classList.toggle('paused', paused);
    app.querySelector('.dpause').textContent = paused ? '▶' : 'II';
    if (paused) {
      const m = document.createElement('div');
      m.className = 'dpausebox';
      m.innerHTML = `<button class="primary" data-a="go">Pokračovat</button><button class="ghost" data-a="quit">Ukončit souboj</button>`;
      m.onclick = (e) => {
        const a = e.target.closest('button')?.dataset.a;
        if (a === 'go') app.querySelector('.dpause').click();
        if (a === 'quit') { clearInterval(timer); over = true; document.body.classList.remove('duelmode'); m.remove(); ctx.home(); }
      };
      app.querySelector('.duel').appendChild(m);
    } else app.querySelector('.dpausebox')?.remove();
  };
  for (const pl of players) { drag(pl); render(pl, true); clock(pl); }
}
