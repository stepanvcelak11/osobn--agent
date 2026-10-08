// Živá scéna: panorama říše pod kartou. Bez čísel ukazuje, jak na tom země je – město roste s Financemi,
// lesy s Přírodou, chrám s Vírou, hradby se Silou, lidé s Lidem; kouř a ohně při hrozbách, sníh v zimě.
// Stavby se mění podle doby (chýše → kamenné domy → továrny → mrakodrapy).
const W = 360, H = 64, GROUND = 50;
const r1 = (i) => ((Math.sin(i * 127.1 + 311.7) * 43758.5453) % 1 + 1) % 1; // pevná „náhoda“ podle pozice
const mixc = (a, b, t) => {
  const p = (h) => [1, 3, 5].map((i) => parseInt(h.slice(i, i + 2), 16));
  const [x, y] = [p(a), p(b)];
  return `#${x.map((v, i) => Math.round(v + (y[i] - v) * t).toString(16).padStart(2, '0')).join('')}`;
};

function building(x, w, h, age, i, lit) {
  const y = GROUND - h;
  if (age === 1) return `<path d="M${x} ${GROUND}l${w / 2} ${-h}l${w / 2} ${h}z" class="b"/>`;
  if (age <= 3) {
    const roof = `<path d="M${x - 1} ${y}l${w / 2 + 1} ${-w * 0.45}l${w / 2 + 1} ${w * 0.45}z" class="roof"/>`;
    return `<rect x="${x}" y="${y}" width="${w}" height="${h}" class="b"/>${roof}${lit ? `<rect x="${x + w / 2 - 1}" y="${y + h * 0.35}" width="2" height="2.4" class="win"/>` : ''}`;
  }
  if (age <= 5) {
    const chim = i % 2 === 0 ? `<rect x="${x + w - 3}" y="${y - 7}" width="2.2" height="7" class="b"/>${lit ? `<g class="smoke" style="animation-delay:${(i % 5) * 0.7}s"><circle cx="${x + w - 2}" cy="${y - 9}" r="2"/><circle cx="${x + w}" cy="${y - 13}" r="2.6"/></g>` : ''}` : '';
    return `<rect x="${x}" y="${y}" width="${w}" height="${h}" class="b"/>${chim}${lit ? Array.from({ length: Math.floor(h / 6) }, (_, k) => `<rect x="${x + 2}" y="${y + 3 + k * 6}" width="${w - 4}" height="1.4" class="win"/>`).join('') : ''}`;
  }
  // současnost a budoucnost: věže s okny, budoucnost s kopulemi
  const top = age === 7 && i % 3 === 0 ? `<path d="M${x} ${y}a${w / 2} ${w / 2} 0 0 1 ${w} 0z" class="b dome"/>` : `<rect x="${x + w / 2 - 0.4}" y="${y - 5}" width="0.8" height="5" class="b"/>`;
  const wins = lit ? Array.from({ length: Math.floor(h / 4) }, (_, k) => r1(i * 7 + k) > 0.35 ? `<rect x="${x + 1.5 + (k % 2) * (w / 2 - 1)}" y="${y + 2 + k * 4}" width="${w / 2 - 2.5}" height="1.6" class="win"/>` : '').join('') : '';
  return `<rect x="${x}" y="${y}" width="${w}" height="${h}" class="b"/>${top}${wins}`;
}
function tree(x, s, age, burnt) {
  if (burnt) return `<path d="M${x} ${GROUND}v${-6 * s}M${x} ${GROUND - 4 * s}l${-2 * s} ${-2 * s}M${x} ${GROUND - 3 * s}l${2 * s} ${-2 * s}" class="dead"/>`;
  return age >= 6 && s < 1 ? `<circle cx="${x}" cy="${GROUND - 4 * s}" r="${2.6 * s}" class="tree"/><rect x="${x - 0.4}" y="${GROUND - 2 * s}" width="0.8" height="${2 * s}" class="trunk"/>`
    : `<path d="M${x} ${GROUND - 9 * s}l${3 * s} ${7 * s}h${-6 * s}z" class="tree"/><rect x="${x - 0.5}" y="${GROUND - 2 * s}" width="1" height="${2 * s}" class="trunk"/>`;
}

/** Celé panorama jako SVG (vrací řetězec). */
export function sceneSVG(state) {
  const m = state.meters, age = state.age ?? 7, season = (() => { const x = (state.turn % 12) + 1; return x === 12 || x <= 2 ? 'zima' : x <= 5 ? 'jaro' : x <= 8 ? 'leto' : 'podzim'; })();
  const out = [];
  // obloha a kopce
  const sky = { zima: ['#1b2230', '#2c3445'], jaro: ['#1d2a2a', '#33463c'], leto: ['#22261c', '#4a4a2c'], podzim: ['#2a1f18', '#4a3426'] }[season];
  out.push(`<defs><linearGradient id="sk" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${sky[0]}" stop-opacity="0"/><stop offset="1" stop-color="${sky[1]}"/></linearGradient></defs>
    <rect width="${W}" height="${GROUND}" fill="url(#sk)"/>`);
  if (age === 7 || season === 'zima') for (let i = 0; i < 14; i++) out.push(`<circle cx="${r1(i) * W}" cy="${4 + r1(i + 40) * 22}" r="${0.35 + r1(i + 9) * 0.4}" class="star" style="animation-delay:${(r1(i + 3) * 4).toFixed(1)}s"/>`);
  out.push(`<path d="M0 ${GROUND - 10} Q 50 ${GROUND - 24} 110 ${GROUND - 12} T 230 ${GROUND - 14} T ${W} ${GROUND - 18} V ${GROUND} H 0 Z" class="hill far"/>`);
  // země podle Přírody (a ročního období)
  const g = m.pri / 100;
  let ground = mixc('#5a4630', '#3f6b34', Math.min(1, g * 1.4));
  if (season === 'podzim') ground = mixc(ground, '#7a5a2a', 0.35);
  if (season === 'zima') ground = mixc(ground, '#aab0b8', 0.5);
  out.push(`<rect y="${GROUND}" width="${W}" height="${H - GROUND}" fill="${ground}"/>`);
  // les (vlevo a vpravo) – počet podle Přírody
  const trees = Math.round(m.pri / 7), burnt = m.pri < 18;
  for (let i = 0; i < trees; i++) {
    const left = i % 2 === 0, x = left ? 6 + r1(i) * 100 : 268 + r1(i + 50) * 86;
    out.push(tree(x, 0.8 + r1(i + 20) * 0.6, age, burnt && i % 3 === 0));
  }
  if (burnt) for (let i = 0; i < 3; i++) out.push(`<g class="fire" style="animation-delay:${i * 0.3}s"><path d="M${40 + i * 90} ${GROUND} q2 -6 0 -9 q4 4 3 9z"/></g>`);
  // hradby (Síla)
  if (m.sil >= 30) {
    const broken = m.sil < 40, hh = 3 + m.sil / 25;
    out.push(`<rect x="118" y="${GROUND - hh}" width="124" height="${hh}" class="wall${broken ? ' broken' : ''}"/>`);
    for (const x of [116, 176, 238]) out.push(`<rect x="${x}" y="${GROUND - hh - 4}" width="6" height="${hh + 4}" class="wall"/>${m.dip >= 60 ? `<path d="M${x + 3} ${GROUND - hh - 4}v-6l5 1.5-5 1.5" class="flag"/>` : ''}`);
  }
  // město (Finance): počet a výška domů; doba určuje styl
  const n = 3 + Math.round(m.fin / 12), lit = m.fin > 15;
  for (let i = 0; i < n; i++) {
    const w = age >= 6 ? 7 + r1(i + 70) * 5 : 8 + r1(i + 70) * 6, x = 126 + (i * 108) / n, base = age >= 6 ? 14 : age >= 4 ? 9 : 6;
    out.push(building(x, w, base + r1(i + 90) * (age >= 6 ? 20 : 10) * (0.5 + m.fin / 100), age, i, lit));
  }
  // chrám (Víra)
  if (m.vir >= 15) {
    const th = 8 + m.vir / 5, x = 244;
    out.push(age === 1 ? `<path d="M${x} ${GROUND}v${-th}M${x + 6} ${GROUND}v${-th * 0.8}M${x - 1} ${GROUND - th}h8" class="temple"/>`
      : `<rect x="${x}" y="${GROUND - th * 0.55}" width="12" height="${th * 0.55}" class="temple"/><path d="M${x - 1} ${GROUND - th * 0.55}l7 -${th * 0.45}l7 ${th * 0.45}z" class="temple"/>`);
  }
  // věda: věž s anténou / observatoř
  if (m.ved >= 55 && age >= 3) out.push(`<path d="M106 ${GROUND}v-${10 + m.ved / 8}" class="sci"/><circle cx="106" cy="${GROUND - 11 - m.ved / 8}" r="2.2" class="sci glow"/>`);
  // lidé (Lid): postavičky; při nízkém Lidu pochodně (vzpoura)
  const people = Math.round(m.lid / 9), angry = m.lid < 25;
  for (let i = 0; i < people; i++) {
    const x = 120 + r1(i + 200) * 130, y = GROUND + 3 + r1(i + 230) * 9;
    out.push(`<g class="man${angry ? ' angry' : ''}" style="animation-delay:${(r1(i) * 3).toFixed(1)}s"><circle cx="${x}" cy="${y - 3.2}" r="1"/><path d="M${x} ${y - 2.2}v2.6"/></g>`);
    if (angry && i % 2 === 0) out.push(`<circle cx="${x + 1.2}" cy="${y - 5}" r="0.9" class="torch"/>`);
  }
  // hrozby v krajích: kouř na obzoru; odtržené kraje: tmavší okraj
  const threats = Object.values(state.prov ?? {}).filter((p) => p.threat && p.threat.type !== 'treasure').length;
  for (let i = 0; i < threats; i++) out.push(`<g class="smoke big" style="animation-delay:${i * 1.1}s"><circle cx="${i ? 330 : 30}" cy="${GROUND - 14}" r="3"/><circle cx="${i ? 334 : 26}" cy="${GROUND - 20}" r="4"/></g>`);
  const lost = Object.values(state.prov ?? {}).filter((p) => p.lost).length;
  if (lost) out.push(`<rect width="${W}" height="${H}" fill="url(#lostv)"/><defs><linearGradient id="lostv"><stop offset="0" stop-color="#000" stop-opacity="${0.25 * lost}"/><stop offset=".3" stop-color="#000" stop-opacity="0"/><stop offset=".7" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity="${0.25 * lost}"/></linearGradient></defs>`);
  // sníh
  if (season === 'zima') for (let i = 0; i < 18; i++) out.push(`<circle cx="${r1(i + 300) * W}" cy="${r1(i + 330) * GROUND}" r="0.6" class="snow" style="animation-delay:${(r1(i + 360) * 5).toFixed(1)}s"/>`);
  return `<svg class="scene-svg" viewBox="0 0 ${W} ${H}" preserveAspectRatio="xMidYMax slice" aria-hidden="true">${out.join('')}</svg>`;
}
