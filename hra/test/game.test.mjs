import test from 'node:test';
import assert from 'node:assert/strict';
import { effect, newGame, choose, nextLeader, currentCard, preview, fill, tenure, DIRS, cardById, METERS, CARDS, INTRO, PEOPLE, ENDINGS } from '../game.js';

const meterIds = new Set(METERS.map((m) => m.id));
const all = [INTRO, ...CARDS];

test('balíček je v pořádku', () => {
  const ids = new Set();
  const setFlags = new Set();
  for (const c of all) for (const d of DIRS) if (c.opts[d]?.set) setFlags.add(c.opts[d].set);
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
    while (g++ < 400) {
      seen.add(s.card);
      choose(s, randomDir(s));
      if (s.dead) nextLeader(s);
    }
  }
  for (const id of ['vrana2', 'ork2', 'ork3', 'prorok2', 'fed2', 'fed3', 'stin2', 'hlad', 'epidemie', 'vakcina', 'nula2', 'vrana_dluh', 'pristav2', 'vlci', 'intro2']) {
    assert.ok(seen.has(id), `pokračování ${id} se nikdy neobjevilo`);
  }
  const never = CARDS.filter((c) => !seen.has(c.id)).map((c) => c.id);
  assert.deepEqual(never, [], 'každá karta se někdy objeví');
});
