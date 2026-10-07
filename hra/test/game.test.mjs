import test from 'node:test';
import assert from 'node:assert/strict';
import { effect, newGame, choose, nextLeader, currentCard, preview, fill, tenure, DIRS, cardById, METERS, CARDS, INTRO, PEOPLE, ENDINGS, KINDS, outcome, bestDir, skip, nudge, ready, CHARGE, activeLaws, optionOf, taskProgress, upgrade, SPECIAL, TASKS } from '../game.js';

const meterIds = new Set(METERS.map((m) => m.id));
const all = [INTRO, ...CARDS];

test('balíček je v pořádku', () => {
  const ids = new Set();
  const setFlags = new Set();
  for (const c of all) for (const d of DIRS) { const o = c.opts[d]; if (o?.set) setFlags.add(o.set); if (o?.law) setFlags.add(`zakon_${o.law}`); }
  for (const c of all) {
    assert.ok(!ids.has(c.id), `duplicitní karta ${c.id}`);
    ids.add(c.id);
    assert.ok(PEOPLE[c.who], `neznámá postava ${c.who} (${c.id})`);
    assert.ok(c.text.length > 20 && c.text.length < 330, `délka textu ${c.id}`);
    for (const d of DIRS) {
      const o = c.opts[d];
      assert.ok(o, `${c.id} nemá volbu ${d}`);
      assert.ok(o.t.length >= 2 && o.t.length <= 30, `${c.id}.${d} popisek „${o.t}“ má ${o.t.length} znaků`);
      for (const [k, v] of Object.entries(o.e)) {
        assert.ok(meterIds.has(k), `${c.id}.${d}: neznámý ukazatel ${k}`);
        assert.ok(Math.abs(v) <= 20, `${c.id}.${d}: příliš velký efekt`);
      }
      if (c.id !== INTRO.id && c.id !== 'intro2' && c.id !== 'dite2') {
        assert.ok(Object.values(o.e).some((v) => v !== 0), `${c.id}.${d} nic nedělá`);
      }
      if (o.next) assert.ok(cardById(o.next), `${c.id}.${d}: neexistující pokračování ${o.next}`);
    }
    for (const f of [...(c.req || []), ...(c.not || [])]) assert.ok(setFlags.has(f), `${c.id}: příznak ${f} nikdo nenastavuje`);
  }
  assert.ok(CARDS.length >= 60, `karet je jen ${CARDS.length}`);
});

test('čtyři volby karty se od sebe liší', () => {
  for (const c of CARDS) {
    const sigs = DIRS.map((d) => JSON.stringify(c.opts[d].e));
    if (['intro2'].includes(c.id)) continue;
    assert.equal(new Set(sigs).size, 4, `${c.id}: dvě volby mají stejný účinek`);
  }
});

test('ženské tvary a oslovení', () => {
  const f = { name: 'Eva', female: true }, m = { name: 'Jan', female: false };
  assert.equal(fill('Ztratil{a} jste důvěru, {osl}.', f), 'Ztratila jste důvěru, paní prezidentko.');
  assert.equal(fill('Ztratil{a} jste důvěru, {osl}.', m), 'Ztratil jste důvěru, pane prezidente.');
  for (const c of all) assert.ok(!/[{}]/.test(fill(c.text, f)), `nedosazený znak v ${c.id}`);
  for (const k of Object.keys(ENDINGS)) for (const s of ['low', 'high']) assert.ok(!/[{}]/.test(fill(ENDINGS[k][s].text, m)));
});

test('úvod, rozhodnutí, konec vlády a nástupce', () => {
  const s = newGame({ name: 'Eva Malá', female: true }, 42);
  assert.equal(currentCard(s).id, 'intro');
  choose(s, 'up');
  assert.equal(s.card, 'intro2', 'otázka „Co se ode mě čeká?“ vede na vysvětlení');
  assert.equal(s.turn, 0, 'úvod se do vlády nepočítá');
  let guard = 0;
  while (!s.dead && guard++ < 5000) choose(s, 'right');
  assert.ok(s.dead, 'vláda jednou skončí');
  assert.ok(s.dead.title && s.dead.text.length > 40);
  assert.equal(s.history.length, 1);
  assert.equal(s.endings.length, 1);
  const before = s.leader.name;
  nextLeader(s);
  assert.equal(s.leader.n, 2);
  assert.notEqual(s.leader.name, before);
  assert.ok(Object.values(s.meters).every((v) => v === 50));
  assert.equal(s.dead, null);
});

test('stejné semínko = stejná hra (obnova ze zálohy)', () => {
  const a = newGame({}, 7), b = newGame({}, 7);
  for (let i = 0; i < 40; i++) { const d = DIRS[i % 4]; choose(a, d); choose(b, d); if (a.dead) { nextLeader(a); nextLeader(b); } }
  assert.deepEqual(a, b);
  const c = JSON.parse(JSON.stringify(a));
  choose(a, 'left'); choose(c, 'left');
  assert.deepEqual(a, c);
});

test('náhled ukazuje jen dotčené ukazatele', () => {
  const c = cardById('stavka');
  assert.deepEqual(Object.keys(preview(c, 'down')).sort(), ['lid', 'sil']);
});

test('délka vlády', () => {
  assert.equal(tenure(0), 'necelý měsíc');
  assert.equal(tenure(1), '1 měsíc');
  assert.equal(tenure(14), '1 rok a 2 měsíce');
  assert.equal(tenure(60), '5 let');
});

// ── Simulace: vyváženost ────────────────────────────────
function play(strategy, seed, leaders = 1) {
  const s = newGame({}, seed);
  const reigns = [];
  while (reigns.length < leaders) {
    let g = 0;
    while (!s.dead && g++ < 2000) choose(s, strategy(s));
    reigns.push({ months: s.turn, end: s.dead?.meter + '.' + s.dead?.side, seen: [...s.recent] });
    nextLeader(s);
  }
  return { reigns, s };
}
const randomDir = (s) => DIRS[Math.floor(Math.random() * 4)];
// Rozumný hráč: volí to, co drží ukazatele nejblíž středu (zná směr změn – v praxi ho tuší z textu).
const wise = (s) => {
  const c = cardById(s.card);
  let best = 'left', bestScore = Infinity;
  for (const d of DIRS) {
    let score = 0;
    for (const m of METERS) { const v = s.meters[m.id] + effect(m.id, c.opts[d].e[m.id] || 0); score += (v - 50) ** 2; }
    if (score < bestScore) { bestScore = score; best = d; }
  }
  return best;
};

test('náhodný hráč vládne krátce, rozumný dlouho', () => {
  const rnd = [], wiseR = [], ends = {};
  for (let i = 0; i < 400; i++) {
    const r = play(randomDir, i + 1, 3);
    for (const x of r.reigns) { rnd.push(x.months); ends[x.end] = (ends[x.end] || 0) + 1; }
  }
  for (let i = 0; i < 100; i++) wiseR.push(...play(wise, 1000 + i, 1).reigns.map((x) => x.months));
  const avg = (a) => a.reduce((x, y) => x + y, 0) / a.length;
  const median = (a) => [...a].sort((x, y) => x - y)[Math.floor(a.length / 2)];
  console.log('náhodný: průměr', avg(rnd).toFixed(1), 'medián', median(rnd), '| rozumný: průměr', avg(wiseR).toFixed(1), 'medián', median(wiseR));
  console.log('konce:', JSON.stringify(Object.entries(ends).sort((a, b) => b[1] - a[1])));
  assert.ok(avg(rnd) >= 12 && avg(rnd) <= 45, `náhodný hráč vládne v průměru ${avg(rnd)} měsíců`);
  assert.ok(median(wiseR) >= 120, `rozumný hráč vládne jen ${median(wiseR)} měsíců`);
  assert.ok(Object.keys(ends).length >= 12, 'skoro všechny konce jsou dosažitelné');
});

test('navazující příběhy opravdu navazují', () => {
  const seen = new Set();
  for (let i = 0; i < 300; i++) {
    const s = newGame({}, 500 + i);
    let g = 0;
    // Napůl rozumná hra, ať se svět dostane i do pozdějších ér a k tajným příběhům.
    while (g++ < 900) {
      seen.add(s.card);
      choose(s, Math.random() < 0.5 ? randomDir(s) : wise(s));
      if (s.dead) nextLeader(s);
    }
  }
  for (const id of ['vrana2', 'ork2', 'ork3', 'prorok2', 'fed2', 'fed3', 'stin2', 'hlad', 'epidemie', 'vakcina', 'nula2', 'vrana_dluh', 'pristav2', 'vlci', 'intro2']) {
    assert.ok(seen.has(id), `pokračování ${id} se nikdy neobjevilo`);
  }
  const never = CARDS.filter((c) => !seen.has(c.id)).map((c) => c.id);
  assert.deepEqual(never, [], 'každá karta se někdy objeví');
});

// ── Typy prezidenta ─────────────────────────────────────
function onCard(kind, id, meters = {}) {
  const s = newGame({ kind }, 3);
  choose(s, 'left'); // pryč z úvodu
  s.card = id;
  Object.assign(s.meters, meters);
  return s;
}

test('Krizový manažer: krok z krajnosti k rovnováze je dvojnásobný, jinak normální', () => {
  // stavka.down = „Pošlu policii“: lid −, sil +
  const o = cardById('stavka').opts.down.e;
  const dl = effect('lid', o.lid), ds = effect('sil', o.sil);
  assert.ok(dl < 0 && ds > 0);
  const plain = onCard('vize', 'stavka', { lid: 85, sil: 50 });
  const crisis = onCard('krize', 'stavka', { lid: 85, sil: 50 });
  assert.equal(outcome(plain, 'down').lid, 85 + dl);
  assert.equal(outcome(crisis, 'down').lid, 85 + 2 * dl, 'z krajnosti dvojnásob');
  assert.equal(outcome(crisis, 'down').sil, 50 + ds, 'u středu beze změny');
  // bonus nepřehoupne přes střed
  assert.equal(outcome(onCard('krize', 'stavka', { lid: 71 }), 'down').lid, Math.max(50, 71 + 2 * dl));
  // směrem do krajnosti se nic nezdvojuje
  assert.equal(outcome(onCard('krize', 'stavka', { sil: 75 }), 'down').sil, 75 + ds);
});

test('Vyčkávač: odložení se nabije po 5 rozhodnutích a nic nezmění', () => {
  const s = newGame({ kind: 'odklad' }, 9);
  choose(s, 'left');
  assert.equal(skip(s), false, 'zatím nenabito');
  while (!ready(s)) choose(s, bestDir(s));
  const meters = { ...s.meters }, card = s.card, turn = s.turn;
  assert.equal(skip(s), true);
  assert.deepEqual(s.meters, meters);
  assert.notEqual(s.card, card);
  assert.equal(s.turn, turn + 1);
  assert.equal(s.charge, 0);
  assert.equal(skip(s), false, 'znovu až po dalších 5');
  const other = newGame({ kind: 'vize' }, 9); other.charge = CHARGE; choose(other, 'left');
  assert.equal(skip(other), false, 'jiný typ odkládat nemůže');
});

test('Kormidelník: posun o 15 k rovnováze, nikdy přes střed', () => {
  const s = newGame({ kind: 'kormidlo' }, 11);
  s.charge = CHARGE; s.meters.fin = 20;
  assert.equal(nudge(s, 'fin'), true);
  assert.equal(s.meters.fin, 35);
  assert.equal(nudge(s, 'fin'), false, 'vybito');
  s.charge = CHARGE; s.meters.vir = 58;
  nudge(s, 'vir');
  assert.equal(s.meters.vir, 50);
});

test('Rádce radí z 70 % nejlépe', () => {
  let ok = 0, n = 0;
  for (let i = 0; i < 300; i++) {
    const s = newGame({ kind: 'rada' }, 2000 + i);
    choose(s, 'left');
    for (let k = 0; k < 10 && !s.dead; k++) {
      assert.ok(DIRS.includes(s.advice));
      if (s.advice === bestDir(s)) ok++;
      n++;
      choose(s, DIRS[(i + k) % 4]);
    }
  }
  const rate = ok / n;
  console.log('rádce trefil', (rate * 100).toFixed(1), '%');
  assert.ok(rate > 0.63 && rate < 0.77, `rádce radí dobře v ${rate}`);
  const v = newGame({ kind: 'vize' }, 1); choose(v, 'left');
  assert.equal(v.advice, null, 'jiný typ rádce nemá');
});

test('každý typ prezidenta vydrží s rozumnou hrou déle než náhoda', () => {
  for (const k of KINDS) {
    const months = [];
    for (let i = 0; i < 40; i++) {
      const s = newGame({ kind: k.id }, 3000 + i);
      let g = 0;
      while (!s.dead && g++ < 3000) {
        if (k.id === 'odklad' && ready(s) && s.card !== 'intro') { const m = outcome(s, bestDir(s)); if (Object.values(m).some((v) => v < 15 || v > 85)) { skip(s); continue; } }
        if (k.id === 'kormidlo' && ready(s)) { const [id] = Object.entries(s.meters).sort((a, b) => Math.abs(b[1] - 50) - Math.abs(a[1] - 50))[0]; nudge(s, id); }
        choose(s, k.id === 'rada' && s.advice ? s.advice : bestDir(s));
      }
      months.push(s.turn);
    }
    months.sort((a, b) => a - b);
    console.log(k.id, 'medián', months[20]);
    assert.ok(months[20] >= 60, `${k.id}: medián ${months[20]}`);
    assert.ok(k.m && k.f && k.text && k.icon);
  }
});

// ── Hloubka světa ───────────────────────────────────────
test('zákon platí a každý měsíc posouvá ukazatele, petice ho zruší', () => {
  const s = onCard('vize', 'zakon_brannost');
  choose(s, 'right');
  assert.deepEqual(activeLaws(s), ['brannost']);
  assert.ok(s.news.some((n) => n.kind === 'law'));
  const sil = s.meters.sil, lid = s.meters.lid;
  for (let i = 0; i < 4; i++) { s.card = 'intro2'; choose(s, 'left'); }
  assert.equal(s.meters.sil, sil + 2, 'za 4 měsíce +2 Síla');
  assert.equal(s.meters.lid, lid - 2);
  s.card = 'zrus_brannost';
  choose(s, 'right');
  assert.deepEqual(activeLaws(s), []);
});

test('postavy si pamatují: komu volba pomůže, ten je vstřícnější', () => {
  const s = onCard('vize', 'zakon_brannost');
  choose(s, 'right'); // generálce (Síla) se líbí
  assert.equal(s.rel.gen, 1);
  s.card = 'zakon_brannost'; s.flags = [];
  choose(s, 'left'); // „Nikdy“ – Síla dolů
  assert.equal(s.rel.gen, 0);
  s.rel.gen = -3;
  let seen = false;
  for (let i = 0; i < 300 && !seen; i++) { s.dead = null; s.meters = Object.fromEntries(Object.keys(s.meters).map((k) => [k, 50])); s.recent = []; s.card = 'intro2'; choose(s, 'left'); seen = s.card === 'gen_zla'; }
  assert.ok(seen, 'nepřátelská generálka přijde s výhrůžkou');
});

test('podmíněná volba se odemkne až při splnění podmínky', () => {
  const s = onCard('vize', 'valka_sousedu', { dip: 40 });
  const card = cardById('valka_sousedu');
  assert.equal(optionOf(s, card, 'up').t, 'Nabídneme mír');
  s.meters.dip = 65;
  assert.equal(optionOf(s, card, 'up').t, 'Zprostředkujeme mír');
  for (const c of all) for (const d of DIRS) {
    const o = c.opts[d];
    if (o.need) { assert.ok(o.alt?.t && o.alt.e, `${c.id}.${d} nemá náhradu`); assert.ok(o.alt.t.length <= 30); }
  }
});

test('úkol se plní, dává pečeť a nový úkol; éra se mění', () => {
  const s = newGame({}, 77);
  assert.ok(s.task && TASKS.some((t) => t.id === s.task.id));
  s.task = { id: 'zakony', streak: 0 };
  choose(s, 'left');
  s.flags.push('zakon_brannost', 'zakon_cenzura');
  s.card = 'zakon_lesy';
  choose(s, 'right');
  assert.deepEqual(s.tasksDone, ['zakony']);
  assert.notEqual(s.task.id, 'zakony');
  assert.ok(s.news.some((n) => n.kind === 'task'));
  assert.equal(s.charge, CHARGE, 'odměna: nabitá schopnost');
  s.total = 70; s.card = 'intro2'; s.meters = Object.fromEntries(Object.keys(s.meters).map((k) => [k, 50]));
  choose(s, 'left');
  assert.equal(s.era, 2);
  assert.equal(s.card, 'era2');
});

test('tajný příběh končí legendou, ne katastrofou', () => {
  const s = onCard('vize', 'signal3');
  s.flags.push('signal');
  const d = choose(s, 'right');
  assert.equal(d.special, 'kontakt');
  assert.equal(d.title, SPECIAL.kontakt.title);
  assert.ok(s.endings.includes('x.kontakt'));
  nextLeader(s);
  assert.equal(s.dead, null);
});

test('stará uložená hra se doplní', () => {
  const old = newGame({}, 5);
  for (const k of ['rel', 'drift', 'task', 'tasksDone', 'era', 'news', 'charge']) delete old[k];
  delete old.leader.kind;
  const s = upgrade(JSON.parse(JSON.stringify(old)));
  assert.equal(s.leader.kind, 'vize');
  assert.ok(s.task);
  choose(s, 'left'); choose(s, 'left');
  assert.ok(taskProgress(s));
});
