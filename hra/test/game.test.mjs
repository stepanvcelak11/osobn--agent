import test from 'node:test';
import assert from 'node:assert/strict';
import { effect, newGame, choose, nextLeader, currentCard, preview, fill, tenure, DIRS, cardById, METERS, CARDS, INTRO, PEOPLE, ENDINGS, KINDS, outcome, bestDir, rankDirs, sageHint, shiftMeter, skip, nudge, ready, CHARGE, activeLaws, optionOf, taskProgress, upgrade, SPECIAL, TASKS, AGES, AGE_LEN, ENDINGS_PAST, hasElections, leaderTitle, lawAllowed, touches, skipCard, steerMeter , reformLaw, choosePerk, offerPerks, newBlitz, newRun, daily, toElection, PERKS, CRISES, TERM, VOTE_MIN, RESCUE, seals , whoOf, seasonOf, modBonus, MODS, WONDERS as WD, RIVALS } from '../game.js';

const meterIds = new Set(METERS.map((m) => m.id));
const all = [INTRO, ...CARDS];

test('balíček je v pořádku', () => {
  const ids = new Set();
  const setFlags = new Set();
  for (const c of all) for (const d of DIRS) { const o = c.opts[d]; if (o?.set) setFlags.add(o.set); if (o?.law) setFlags.add(`zakon_${o.law}`); if (o?.wonder) setFlags.add(`div_${o.wonder}`); }
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
    const s = newGame({ mode: i % 3 === 0 ? 'dejiny' : 'normal' }, 500 + i);
    let g = 0;
    // Napůl rozumná hra, ať se svět dostane i do pozdějších ér a k tajným příběhům.
    while (g++ < (s.mode === 'dejiny' ? 1200 : 900)) {
      seen.add(s.card);
      choose(s, Math.random() < 0.5 ? randomDir(s) : wise(s));
      if (s.dead) nextLeader(s);
    }
  }
  for (const id of ['vrana2', 'ork2', 'ork3', 'prorok2', 'fed2', 'fed3', 'stin2', 'hlad', 'epidemie', 'vakcina', 'nula2', 'vrana_dluh', 'pristav2', 'vlci', 'intro2']) {
    assert.ok(seen.has(id), `pokračování ${id} se nikdy neobjevilo`);
  }
  const never = CARDS.filter((c) => !c.generated && !seen.has(c.id)).map((c) => c.id);
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

test('Rádce radí z 70 % nejlépe, jinak nejhůř', () => {
  let ok = 0, n = 0;
  for (let i = 0; i < 300; i++) {
    const s = newGame({ kind: 'rada' }, 2000 + i);
    choose(s, 'left');
    for (let k = 0; k < 10 && !s.dead; k++) {
      assert.ok(DIRS.includes(s.advice));
      if (s.advice === bestDir(s)) ok++;
      else assert.equal(s.advice, rankDirs(s)[3], 'když se plete, radí nejhorší');
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

// ── Další typy, výhody, volby, krize, bleskovka ─────────
test('Zachránce se jednou za vládu odrazí od kraje', () => {
  const s = onCard('zachrance', 'stavka', { lid: 3 });
  choose(s, 'down'); // lid −15 → pod nulu
  assert.equal(s.dead, null);
  assert.equal(s.meters.lid, RESCUE);
  assert.ok(s.rescued);
  s.meters.lid = 3; s.card = 'stavka';
  assert.ok(choose(s, 'down'), 'podruhé už ne');
});

test('Charismatik mění vztahy dvakrát rychleji', () => {
  const a = onCard('vize', 'gen_verna'), b = onCard('charisma', 'gen_verna');
  const dir = DIRS.find((d) => cardById('gen_verna').opts[d].e.sil > 0);
  choose(a, dir); choose(b, dir);
  assert.equal(Math.abs(b.rel.gen), 2 * Math.abs(a.rel.gen));
});

test('Prorok vidí, kdo přijde příště, a předpověď platí', () => {
  let hits = 0, n = 0;
  for (let i = 0; i < 50; i++) {
    const s = newGame({ kind: 'prorok' }, 500 + i);
    choose(s, 'left');
    for (let k = 0; k < 20 && !s.dead; k++) {
      const p = s.peek;
      assert.ok(p, 'předpověď existuje');
      choose(s, bestDir(s));
      if (s.dead) break;
      n++; if (s.card === p) hits++;
    }
  }
  assert.ok(hits / n > 0.85, `předpověď vyšla jen v ${hits}/${n}`);
});

test('Byrokrat: menší účinek voleb, dvojnásobné zákony', () => {
  const a = onCard('vize', 'stavka', { lid: 50 }), b = onCard('byro', 'stavka', { lid: 50 });
  choose(a, 'down'); choose(b, 'down');
  assert.ok(50 - b.meters.lid < 50 - a.meters.lid);
});

test('Hazardér: náhodný násobek a dvě pečetě za úkol', () => {
  const s = newGame({ kind: 'hazard' }, 9);
  const seen = new Set();
  for (let i = 0; i < 30 && !s.dead; i++) { choose(s, bestDir(s)); seen.add(s.luck); }
  assert.ok(seen.size > 3 && [...seen].every((x) => x >= 0.5 && x <= 1.5));
  const h = newGame({ kind: 'hazard' }, 77);
  h.task = { id: 'zakony', streak: 0 };
  choose(h, 'left');
  h.flags.push('zakon_brannost', 'zakon_cenzura');
  h.card = 'zakon_lesy';
  choose(h, 'right');
  assert.equal(seals(h), 2);
});

test('Reformátor zavede a zruší zákon, když je nabitý', () => {
  const s = onCard('reform', 'stavka');
  assert.equal(reformLaw(s, 'skolstvi'), false, 'nenabitý');
  s.charge = CHARGE;
  assert.ok(reformLaw(s, 'skolstvi'));
  assert.ok(activeLaws(s).includes('skolstvi'));
  s.charge = CHARGE;
  reformLaw(s, 'skolstvi');
  assert.ok(!activeLaws(s).includes('skolstvi'));
});

test('splněný úkol nabídne výhody, výběr platí do konce vlády', () => {
  const s = newGame({ kind: 'vize' }, 77);
  s.task = { id: 'zakony', streak: 0 };
  choose(s, 'left');
  s.flags.push('zakon_brannost', 'zakon_cenzura');
  s.card = 'zakon_lesy';
  choose(s, 'right');
  assert.equal(s.perkOffer.length, 3);
  assert.ok(!s.perkOffer.includes('smer'), 'Vizionář nedostane výhodu, kterou už má');
  assert.ok(!s.perkOffer.includes('nabiti'), 'pasivní typ nedostane nabíjení');
  assert.equal(choosePerk(s, 'neexistuje'), false);
  const p = s.perkOffer[0];
  assert.ok(choosePerk(s, p));
  assert.deepEqual(s.perks, [p]);
  assert.equal(s.perkOffer, null);
  for (const id of Object.keys(PERKS)) assert.ok(PERKS[id].name && PERKS[id].text);
  s.dead = null; nextLeader(s);
  assert.deepEqual(s.perks, []);
});

test('výhoda Brzda a Druhá šance', () => {
  let pick = null;
  for (const c of CARDS) for (const d of DIRS) for (const [k, v] of Object.entries(c.opts[d].e)) if (!pick && !c.opts[d].need && Math.abs(effect(k, v)) > 12) pick = { id: c.id, d, k, v };
  const s = onCard('vize', pick.id);
  s.perks = ['brzda'];
  choose(s, pick.d);
  assert.equal(s.meters[pick.k], 50 + Math.sign(pick.v) * 12);
  const t = onCard('vize', 'stavka', { lid: 3 });
  t.perks = ['sance'];
  choose(t, 'down');
  assert.equal(t.dead, null);
  assert.deepEqual(t.perks, [], 'šance se spotřebuje');
});

test('volby každé 4 roky: s podporou vyhraješ, bez ní končíš', () => {
  const s = onCard('vize', 'intro2');
  s.turn = TERM - 1;
  choose(s, 'left');
  assert.equal(s.dead, null);
  assert.equal(s.tally.elections, 1);
  const t = onCard('vize', 'intro2', { lid: 20, dip: 30 });
  t.turn = TERM - 1;
  const d = choose(t, 'left');
  assert.ok(d?.election, 'prohrané volby');
  assert.ok(t.endings.includes('volby'));
  assert.ok(!/[{}]/.test(d.text));
  const u = onCard('vize', 'intro2');
  u.turn = TERM - 7;
  choose(u, 'left');
  assert.ok(u.news.some((n) => n.kind === 'electionSoon'));
  assert.equal(toElection(u), 6);
});

test('krize jde po krocích a končí odměnou, nebo trestem', () => {
  for (const [id, cr] of Object.entries(CRISES)) {
    for (const good of [true, false]) {
      const s = onCard('vize', cr.steps[0]);
      s.total = 20;
      for (let i = 0; i < cr.steps.length; i++) {
        assert.equal(s.card, cr.steps[i], `${id}: krok ${i + 1}`);
        Object.assign(s.meters, Object.fromEntries(Object.keys(s.meters).map((k) => [k, 50])));
        const c = cardById(s.card);
        const dir = DIRS.find((d) => !!c.opts[d].ok === good);
        choose(s, dir);
        if (i < cr.steps.length - 1) { assert.equal(s.crisis.step, i + 1); choose(s, bestDir(s)); }
      }
      assert.equal(s.crisis, null);
      assert.equal(s.tally.crises, good ? 1 : 0);
      assert.ok(s.news.some((n) => n.kind === (good ? 'crisis' : 'crisisLost')));
    }
  }
});

test('bleskovka začíná rovnou hrou', () => {
  const s = newBlitz({ kind: 'krize' }, 4);
  assert.equal(s.mode, 'blitz');
  assert.notEqual(s.card, 'intro');
  choose(s, 'left');
  assert.equal(s.turn, 1);
});

test('denní výzva: stejný den = stejná hra, jiný den jinak', () => {
  const a = daily('2026-10-08'), b = daily('2026-10-08'), c = daily('2026-10-09');
  assert.deepEqual(a, b);
  assert.notEqual(a.seed, c.seed);
  assert.ok(KINDS.some((k) => k.id === a.kind));
  const s1 = newRun({ kind: a.kind }, a.seed, 'daily'), s2 = newRun({ kind: a.kind }, a.seed, 'daily');
  assert.equal(s1.card, s2.card);
  assert.equal(s1.mode, 'daily');
});

test('Dějiny lidstva: od pravěku přes přelomy až do budoucnosti', () => {
  const s = newGame({ mode: 'dejiny', female: true, kind: 'vize' }, 21);
  assert.equal(s.card, 'dej_intro');
  assert.equal(s.age, 1);
  assert.equal(leaderTitle(s), 'náčelnice');
  assert.ok(!/prezident/.test(currentCard(s).text));
  choose(s, 'left');
  assert.equal(s.turn, 0, 'úvod se nepočítá');
  const seenAges = new Set();
  let g = 0, prelomSeen = 0;
  while (s.age < 7 && g++ < 5000) {
    const c = cardById(s.card);
    seenAges.add(s.age);
    if (c.age) assert.equal(c.age, s.age, `${c.id} nepatří do doby ${s.age}`);
    else if (!['dej_intro'].includes(c.id) && !(c.season || c.traitor || c.pastOnly || c.who.startsWith('@'))) assert.fail(`karta budoucnosti ${c.id} v době ${s.age}`);
    if (c.milestone) {
      prelomSeen++;
      // nejdřív odmítnout – objev se vrátí, pak přijmout
      const no = DIRS.find((d) => !c.opts[d].advance), yes = DIRS.find((d) => c.opts[d].advance);
      const before = s.age;
      choose(s, prelomSeen % 2 ? no : yes);
      if (s.dead) nextLeader(s);
      if (prelomSeen % 2) assert.equal(s.age, before); else assert.equal(s.age, before + 1);
      continue;
    }
    choose(s, bestDir(s));
    if (s.dead) {
      if (s.dead.meter) assert.equal(s.dead.title, ENDINGS_PAST[s.dead.meter][s.dead.side].title, 'konce dávných dob');
      assert.ok(!s.dead.election, 'v pravěku se nevolí');
      nextLeader(s);
    }
  }
  assert.equal(s.age, 7);
  assert.deepEqual([...seenAges].sort(), [1, 2, 3, 4, 5, 6]);
  assert.equal(leaderTitle(s), s.leader.female ? 'prezidentka' : 'prezident');
  assert.ok(s.news.some((n) => n.kind === 'age'));
  // v budoucnosti běží hlavní hra a éry se počítají od příchodu
  assert.equal(s.era, 1);
  for (let i = 0; i < 30 && !s.dead; i++) choose(s, bestDir(s));
  assert.ok(!cardById(s.card).age, 'v budoucnosti už jen karty Nové republiky');
});

test('Dějiny: volby až od moderní doby, zákony podle doby, oslovení podle doby', () => {
  const s = newGame({ mode: 'dejiny' }, 3);
  assert.equal(hasElections(s), false);
  assert.equal(lawAllowed(s, 'robotizace'), false);
  s.age = 2;
  assert.equal(lawAllowed(s, 'brannost'), true);
  s.age = 5;
  assert.equal(hasElections(s), true);
  for (const a of AGES) {
    assert.ok(a.name && a.when && a.text && a.title.length === 2 && a.osl.length === 2);
    if (a.n < 7) assert.ok(cardById(`prelom${a.n}`)?.milestone, `přelom doby ${a.n}`);
    if (a.n < 7) assert.ok(CARDS.filter((c) => c.age === a.n && !c.milestone).length >= 9, `karty doby ${a.n}`);
  }
  const normal = newGame({}, 3);
  assert.equal(normal.age, 7);
  assert.equal(currentCard(normal).id, 'intro');
});

test('rozzlobený člověk se ozve a mluví jinak, věrný se odvděčí', () => {
  // pravěký lovec: na čem mu záleží (síla), toho se dotkneme
  const s = newGame({ mode: 'dejiny' }, 8);
  choose(s, 'left');
  s.rel.lov = -2;
  s.card = 'p_mamut';
  choose(s, 'left'); // Lovit všichni: síla dolů → lovkyně se zlobí
  assert.equal(s.rel.lov, -3);
  assert.ok(s.news.some((n) => n.kind === 'enemy' && /Lovkyně/.test(n.text)), 'zpráva o nepříteli');
  s.card = 'p_vlci';
  assert.ok(/^(Bez pozdravu|Chladně|Nevraživě|Úsečně): „/.test(currentCard(s).text), 'nepřátelský tón');
  let met = false;
  for (let i = 0; i < 200 && !met; i++) { s.dead = null; s.meters = Object.fromEntries(Object.keys(s.meters).map((k) => [k, 50])); choose(s, bestDir(s)); met = s.card === 'zloba_lov'; if (s.dead) nextLeader(s); s.rel.lov = -3; }
  assert.ok(met, 'rozzlobená lovkyně přijde s výčitkami');
  const z = cardById('zloba_lov');
  assert.equal(z.age, 1);
  assert.ok(cardById('vdek_lov') && cardById('vdek_tech') && !cardById('zloba_gen'), 'postavy s vlastními kartami se nezdvojují');
});

test('karta pod kartou: každý vidí, kdo přijde, Prorok i co ovlivní', () => {
  const s = newGame({ kind: 'vize' }, 4);
  choose(s, 'left');
  assert.ok(s.peek, 'předpověď má každý');
  const t = touches(s, s.peek);
  assert.ok(t.length >= 1 && t.every((k) => ['fin', 'lid', 'sil', 'ved', 'pri', 'vir', 'dip'].includes(k)));
});

test('karty se tolik neopakují', () => {
  const s = newGame({ mode: 'dejiny' }, 12);
  choose(s, 'left');
  const seen = [];
  for (let i = 0; i < 20; i++) { seen.push(s.card); choose(s, bestDir(s)); if (s.dead) nextLeader(s); }
  const uniq = new Set(seen).size;
  assert.ok(uniq >= 14, `ve 20 kartách jen ${uniq} různých`);
});

// ── Větvení dějin, divy, soused, roční období, zrádce, krajnosti, ztížení ──
const flat = (s) => { s.meters = Object.fromEntries(Object.keys(s.meters).map((k) => [k, 50])); };

test('přelom nabízí dvě cesty a každá otevře jiné karty', () => {
  for (const [flag, other] of [['b_pole', 'b_stada'], ['b_tisk', 'b_prach']]) {
    const c = CARDS.filter((x) => x.req?.includes(flag));
    assert.equal(c.length, 2, flag);
    assert.ok(c.every((x) => !x.req.includes(other)));
  }
  const s = newGame({ mode: 'dejiny' }, 5);
  choose(s, 'left');
  s.card = 'prelom1';
  const dir = DIRS.find((d) => cardById('prelom1').opts[d].set === 'b_stada');
  choose(s, dir);
  assert.equal(s.age, 2);
  assert.ok(s.flags.includes('b_stada'));
});

test('div světa: stavba po krocích, pak drží svůj ukazatel u rovnováhy', () => {
  const w = WD.find((x) => x.id === 'kruh');
  const s = newGame({ mode: 'dejiny' }, 6);
  choose(s, 'left');
  s.card = 'div_kruh_1';
  choose(s, DIRS.find((d) => cardById('div_kruh_1').opts[d].set === 'stavba_kruh'));
  assert.ok(s.flags.includes('stavba_kruh'));
  s.card = 'div_kruh_3';
  choose(s, DIRS.find((d) => cardById('div_kruh_3').opts[d].wonder === 'kruh'));
  assert.deepEqual(s.wonders, ['kruh']);
  assert.ok(s.flags.includes('div_kruh') && !s.flags.includes('stavba_kruh'));
  s.meters[w.m] = 30;
  const before = s.meters[w.m];
  for (let i = 0; i < 6 && !s.dead; i++) { const o = s.meters; s.card = 'intro2'; choose(s, 'left'); }
  assert.ok(s.meters[w.m] > before, 'div táhne ukazatel k rovnováze');
});

test('sousední říše: válka podle Síly, pohlcení slabého souseda', () => {
  const s = newGame({ mode: 'dejiny' }, 7);
  choose(s, 'left');
  s.card = 'riv_hranice';
  const warDir = DIRS.find((d) => cardById('riv_hranice').opts[d].war);
  s.meters.sil = 95; s.rival.power = 20;
  choose(s, warDir);
  assert.ok(s.news.some((n) => n.kind === 'war'), 'silná země vyhraje');
  assert.ok(s.rival.power <= 20);
  const t = newGame({ mode: 'dejiny' }, 7);
  choose(t, 'left');
  t.card = 'riv_hranice'; t.meters.sil = 5; t.rival.power = 90;
  choose(t, warDir);
  assert.ok(t.news.some((n) => n.kind === 'warLost'), 'slabá prohraje');
  const u = newGame({ mode: 'dejiny' }, 7);
  choose(u, 'left');
  u.card = 'riv_pohlceni'; u.rival.power = 10;
  choose(u, DIRS.find((d) => cardById('riv_pohlceni').opts[d].absorb));
  assert.ok(u.rival.absorbed);
  assert.equal(whoOf(u, cardById('riv_obchod')), 'riv');
  assert.ok(RIVALS[1].name && currentCard({ ...u, card: 'riv_obchod' }).person.name === RIVALS[1].name);
  const f = newGame({}, 7);
  choose(f, 'left');
  for (let i = 0; i < 200; i++) { assert.ok(!cardById(f.card).pastOnly, 'v roce 2089 soused není'); choose(f, bestDir(f)); if (f.dead) nextLeader(f); }
});

test('roční období: karty jen ve své sezóně', () => {
  const s = newGame({}, 9);
  choose(s, 'left');
  for (let i = 0; i < 400; i++) {
    const c = cardById(s.card);
    if (c.season) assert.equal(c.season, seasonOf(s), `${c.id} mimo sezónu`);
    choose(s, bestDir(s));
    if (s.dead) nextLeader(s);
  }
});

test('zrádce: objeví se, dá se odhalit a potrestat; neodhalený zradí', () => {
  const s = newGame({ mode: 'dejiny' }, 10);
  choose(s, 'left');
  s.traitor = { who: 'lov', since: s.total, known: false };
  s.card = 'zrada_hledat';
  assert.equal(whoOf(s, cardById('zrada_hledat')), 'sam');
  choose(s, DIRS.find((d) => cardById('zrada_hledat').opts[d].expose));
  assert.ok(s.traitor.known);
  assert.equal(s.card, 'zrada_trest');
  assert.equal(currentCard(s).person.name, PEOPLE.lov.name);
  choose(s, 'left');
  assert.equal(s.traitor, null);
  const t = newGame({ mode: 'dejiny' }, 10);
  choose(t, 'left');
  t.traitor = { who: 'lov', since: t.total - 25, known: false };
  t.card = 'p_hrob'; flat(t);
  choose(t, 'left');
  assert.equal(t.traitor, null);
  assert.ok(t.news.some((n) => n.kind === 'traitorStrike'));
});

test('dlouhá krajnost přivolá kartu, dlouhý klid zlatý věk', () => {
  const s = newGame({}, 11);
  choose(s, 'left');
  s.meters.fin = 12;
  for (let i = 0; i < 5; i++) { s.card = 'intro2'; s.meters.fin = 12; choose(s, 'left'); if (s.card === 'stav_fin_low') break; }
  assert.equal(s.card, 'stav_fin_low');
  const g = newGame({}, 12);
  choose(g, 'left');
  for (let i = 0; i < 10 && g.card !== 'zlaty_vek'; i++) { flat(g); g.card = 'intro2'; choose(g, 'left'); }
  assert.equal(g.card, 'zlaty_vek');
});

test('ztížení: víc bodů, hladová léta berou zásoby', () => {
  const s = newGame({ mods: ['hlad', 'boure'] }, 13);
  assert.equal(modBonus(s), 1 + MODS.hlad.bonus + MODS.boure.bonus);
  choose(s, 'left');
  s.card = 'intro2'; flat(s);
  for (let i = 0; i < 6; i++) { s.card = 'intro2'; choose(s, 'left'); }
  assert.ok(s.meters.fin < 50);
  let g = 0;
  while (!s.dead && g++ < 3000) choose(s, randomDir(s));
  assert.equal(s.dead.score, Math.round(s.dead.months * modBonus(s)));
  const a = newGame({}, 14), b = newGame({ mods: ['boure'] }, 14);
  choose(a, 'left'); choose(b, 'left');
  a.card = b.card = 'stavka'; flat(a); flat(b);
  choose(a, 'down'); choose(b, 'down');
  assert.ok(Math.abs(b.meters.lid - 50) > Math.abs(a.meters.lid - 50));
});

test('výzva v Dějinách začíná v pravěku bez úvodu', () => {
  const s = newRun({ kind: 'vize', world: 'dejiny' }, 99, 'daily');
  assert.equal(s.age, 1);
  assert.equal(s.world, 'dejiny');
  const c = cardById(s.card);
  assert.ok(c.age === 1 || c.season || c.pastOnly || c.who.startsWith('@'), c.id);
});

test('pomůcky z obchodu: přeskočení karty a vyrovnání ukazatele pro každý typ', () => {
  const s = newGame({ kind: 'vize' }, 31);
  choose(s, 'left');
  const card = s.card, turn = s.turn, m = { ...s.meters };
  assert.ok(skipCard(s));
  assert.notEqual(s.card, card);
  assert.equal(s.turn, turn + 1);
  s.meters.fin = 20;
  assert.ok(steerMeter(s, 'fin'));
  assert.equal(s.meters.fin, 35);
  s.meters.sil = 45;
  steerMeter(s, 'sil');
  assert.equal(s.meters.sil, 50, 'nikdy přes střed');
  const t = newGame({ mode: 'dejiny' }, 3);
  assert.equal(skipCard(t), false, 'úvod přeskočit nejde');
});

test('mudrc radí napůl dobře, posun ukazatele nepustí na kraj', () => {
  let good = 0, n = 0;
  for (let i = 0; i < 200; i++) {
    const s = newGame({}, 500 + i);
    choose(s, 'left');
    const h = sageHint(s);
    assert.ok(DIRS.includes(h));
    if (h === bestDir(s)) good++;
    n++;
  }
  assert.ok(good / n < 0.9, 'mudrc není neomylný');
  const s = newGame({}, 3); choose(s, 'left');
  s.meters.fin = 12;
  assert.ok(shiftMeter(s, 'fin', -1));
  assert.equal(s.meters.fin, 5);
  assert.ok(!shiftMeter(s, 'fin', -1), 'pod 5 % nejde');
  assert.ok(shiftMeter(s, 'fin', 1));
  assert.equal(s.meters.fin, 20);
});
