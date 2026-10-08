// Kresby: postavy bez obličeje (ve stylu Lapse) a ikony ukazatelů, které se plní odspodu. Vše jako SVG – ostré a lehké.

const hex = (h) => [1, 3, 5].map((i) => parseInt(h.slice(i, i + 2), 16));
const toHex = (c) => '#' + c.map((v) => Math.round(Math.max(0, Math.min(255, v))).toString(16).padStart(2, '0')).join('');
/** Smíchá dvě barvy (t = podíl druhé). */
export const mix = (a, b, t) => toHex(hex(a).map((v, i) => v + (hex(b)[i] - v) * t));

const SKIN = '#cdbba6';
const HAIR = '#2a2420';

/** Portrét postavy: silueta s doplňkem podle `look`. */
export function portrait(person, age = 7) {
  const c = person.color;
  const bg = mix(c, AGE_PAPER[age] ?? '#efe6d6', 0.55);
  const body = mix(c, '#000000', 0.25);
  const dark = mix(c, '#000000', 0.55);
  const look = person.look || 'hair';
  const child = look === 'child';
  const hx = 100, hy = child ? 104 : 88, hr = child ? 30 : 34;
  let back = '', front = '';
  const hairCap = `<path d="M${hx - hr} ${hy - 2}a${hr} ${hr} 0 0 1 ${hr * 2} 0c-8-14-20-20-${hr} -20s-26 6-${hr} 20z" fill="${HAIR}"/>`;
  switch (look) {
    case 'hair': case 'child': front = hairCap; break;
    case 'bald': front = ''; break;
    case 'cap':
      front = `<path d="M${hx - 38} ${hy - 14}h76l-6-22c-20-8-44-8-64 0z" fill="${dark}"/><rect x="${hx - 42}" y="${hy - 16}" width="84" height="7" rx="3" fill="${HAIR}"/><circle cx="${hx}" cy="${hy - 28}" r="4" fill="#e3b860"/>`;
      break;
    case 'glasses':
      front = hairCap + `<g fill="none" stroke="${HAIR}" stroke-width="4"><circle cx="${hx - 13}" cy="${hy + 2}" r="9"/><circle cx="${hx + 13}" cy="${hy + 2}" r="9"/><path d="M${hx - 4} ${hy + 2}h8"/></g>`;
      break;
    case 'bun':
      front = hairCap + `<circle cx="${hx}" cy="${hy - hr - 6}" r="13" fill="${HAIR}"/>`;
      break;
    case 'hood':
      back = `<path d="M${hx - hr - 14} ${hy + 46}V${hy}a${hr + 14} ${hr + 14} 0 0 1 ${(hr + 14) * 2} 0v46z" fill="${dark}"/>`;
      front = `<path d="M${hx - hr - 4} ${hy + 4}a${hr + 4} ${hr + 4} 0 0 1 ${(hr + 4) * 2} 0c-10-16-24-20-${hr + 4} -20s-${hr - 10} 4-${hr + 4} 20z" fill="${dark}"/>`;
      break;
    case 'beanie':
      front = `<path d="M${hx - hr - 2} ${hy - 4}a${hr + 2} ${hr + 2} 0 0 1 ${(hr + 2) * 2} 0z" fill="${c}"/><rect x="${hx - hr - 3}" y="${hy - 9}" width="${(hr + 3) * 2}" height="9" rx="4" fill="${dark}"/>`;
      break;
    case 'long':
      back = `<path d="M${hx - hr - 6} ${hy}c0-30 14-${hr + 10} ${hr + 6} -${hr + 10}s${hr + 6} ${hr - 20} ${hr + 6} ${hr + 10}v58h-${(hr + 6) * 2}z" fill="${HAIR}"/>`;
      front = hairCap;
      break;
    case 'robot':
      return frame(bg, `
        <rect x="56" y="140" width="88" height="80" rx="10" fill="${body}"/>
        <rect x="92" y="122" width="16" height="20" fill="${dark}"/>
        <rect x="64" y="52" width="72" height="72" rx="14" fill="#b9c3c9"/>
        <rect x="74" y="76" width="52" height="18" rx="9" fill="${HAIR}"/>
        <circle cx="88" cy="85" r="5" fill="${c}"/><circle cx="112" cy="85" r="5" fill="${c}"/>
        <path d="M100 52V36" stroke="#b9c3c9" stroke-width="4"/><circle cx="100" cy="32" r="6" fill="${c}"/>`, person, age);
    case 'shades':
      front = hairCap + `<rect x="${hx - 25}" y="${hy - 4}" width="50" height="12" rx="5" fill="${HAIR}"/>`;
      break;
    case 'straw':
      front = `<ellipse cx="${hx}" cy="${hy - 14}" rx="${hr + 26}" ry="9" fill="#d8b45f"/><path d="M${hx - 26} ${hy - 14}c0-22 52-22 52 0z" fill="#c9a24f"/><rect x="${hx - 26}" y="${hy - 20}" width="52" height="5" fill="${c}"/>`;
      break;
    case 'hoodie':
      back = `<path d="M${hx - hr - 12} ${hy + 50}V${hy}a${hr + 12} ${hr + 12} 0 0 1 ${(hr + 12) * 2} 0v50z" fill="${body}"/>`;
      front = `<path d="M${hx - hr - 2} ${hy + 2}a${hr + 2} ${hr + 2} 0 0 1 ${(hr + 2) * 2} 0c-10-14-22-18-${hr + 2} -18s-${hr - 8} 4-${hr + 2} 18z" fill="${body}"/>`;
      break;
    case 'tophat':
      front = `<rect x="${hx - 24}" y="${hy - 74}" width="48" height="46" rx="3" fill="${HAIR}"/><rect x="${hx - 24}" y="${hy - 40}" width="48" height="7" fill="${c}"/><rect x="${hx - 40}" y="${hy - 30}" width="80" height="8" rx="4" fill="${HAIR}"/>`;
      break;
    case 'scarf':
      front = hairCap;
      break;
    case 'halo':
      back = `<ellipse cx="${hx}" cy="${hy - hr - 10}" rx="30" ry="8" fill="none" stroke="#f0d070" stroke-width="5"/>`;
      front = `<path d="M${hx - hr} ${hy - 6}a${hr} ${hr} 0 0 1 ${hr * 2} 0c-10-8-22-10-${hr} -10s-24 2-${hr} 10z" fill="#e8dcc0"/>`;
      break;
  }
  const scarf = look === 'scarf' ? `<path d="M${hx - 28} 134h56l4 14h-64z" fill="${c}"/><rect x="${hx + 8}" y="144" width="14" height="34" rx="4" fill="${c}"/>` : '';
  const shoulders = child ? 'M52 220c0-38 21-62 48-62s48 24 48 62z' : 'M34 220c0-46 29-78 66-78s66 32 66 78z';
  return frame(bg, `
    ${back}
    <path d="${shoulders}" fill="${body}"/>
    ${child ? '' : outfit(age, c, body, dark)}
    <rect x="${hx - 11}" y="${hy + hr - 6}" width="22" height="24" fill="${mix(SKIN, '#000000', 0.12)}"/>
    <circle cx="${hx}" cy="${hy}" r="${hr}" fill="${SKIN}"/>
    ${front}${scarf}`, person, age);
}

/// Barva „papíru“ pozadí podle doby (pravěk = okrová skála … budoucnost = chladná).
const AGE_PAPER = { 1: '#c99a66', 2: '#e6cf9c', 3: '#b9b2a4', 4: '#e8d9bb', 5: '#d8d2c4', 6: '#e9eef2', 7: '#efe6d6' };

/** Pozadí karty podle doby: jeskyně, sloupy, gotické okno, rám obrazu, art deco, město, obvody budoucnosti. */
function scenery(age, bg) {
  const ink = mix(bg, '#000000', 0.32), soft = mix(bg, '#000000', 0.14), light = mix(bg, '#ffffff', 0.35);
  switch (age) {
    case 1: return `
      <path d="M0 0h200v40c-30 10-60-6-100 4S20 30 0 46z" fill="${soft}"/>
      <path d="M-4 220c10-40 0-90 14-130S4 20 0 0h-4zM204 220c-12-36-2-80-16-120s10-70 12-100h4z" fill="${soft}"/>
      <g fill="#8a3a22" opacity=".55" transform="translate(14 0) scale(.9)">
        <path d="M22 70c4-8 16-10 24-6 4-4 10-4 12 0l-2 4c3 2 3 6 0 8h-4l-2 8h-3l-1-7h-14l-2 7h-3l-1-8c-4-1-5-4-4-6z"/>
        <path d="M150 58l10 0 6-6 2 3-5 5h8l4-5 2 2-4 5c2 2 2 5 0 7l-2 8h-3l-1-6h-12l-2 6h-3l-1-8c-2-2-2-5 0-6z"/>
        <path d="M168 104c-3 0-5 2-5 5v9c0 4 3 7 7 7s7-3 7-7v-12c0-2-1-3-2-3s-2 1-2 3v4l-1-7c0-2-1-3-2-3s-2 1-2 3v5z"/>
      </g>`;
    case 2: return `
      <rect x="0" y="0" width="200" height="14" fill="${soft}"/>
      <path d="M0 10h10V4h10v6h10V4h10v6h10V4h10v6h10V4h10v6h10V4h10v6h10V4h10v6h10V4h10v6h10V4h10v6h10V4h10v6h10" fill="none" stroke="${ink}" stroke-width="2"/>
      <g fill="${light}">
        <rect x="24" y="22" width="24" height="8"/><rect x="27" y="30" width="18" height="190"/><rect x="152" y="22" width="24" height="8"/><rect x="155" y="30" width="18" height="190"/>
      </g>
      <g stroke="${soft}" stroke-width="2"><path d="M31 32v188M36 32v188M41 32v188M159 32v188M164 32v188M169 32v188"/></g>`;
    case 3: return `
      <g stroke="${soft}" stroke-width="1.5" fill="none">
        <path d="M0 30h200M0 60h200M0 90h200M0 120h200M0 150h200M0 180h200M0 210h200"/>
        <path d="M40 0v30M120 0v30M80 30v30M160 30v30M40 60v30M120 60v30M80 90v30M160 90v30M40 120v30M120 120v30M80 150v30M160 150v30M40 180v30M120 180v30"/>
      </g>
      <path d="M48 220V96c0-34 22-60 52-74 30 14 52 40 52 74v124z" fill="${mix(bg, '#1a2440', 0.55)}"/>
      <path d="M48 220V96c0-34 22-60 52-74 30 14 52 40 52 74v124" fill="none" stroke="${light}" stroke-width="5"/>
      <path d="M100 26v194M48 120h104" stroke="${light}" stroke-width="2" opacity=".5"/>`;
    case 4: return `
      <g fill="${soft}" opacity=".7">${[10, 40, 70, 100, 130, 160, 190].map((x) => `<rect x="${x - 6}" y="0" width="12" height="220"/>`).join('')}</g>
      <ellipse cx="100" cy="104" rx="70" ry="92" fill="${mix(bg, '#3a2a1a', 0.35)}"/>
      <ellipse cx="100" cy="104" rx="70" ry="92" fill="none" stroke="#c9a24f" stroke-width="7"/>
      <ellipse cx="100" cy="104" rx="62" ry="84" fill="none" stroke="#e8c97a" stroke-width="2"/>`;
    case 5: return `
      <g stroke="${soft}" stroke-width="4">${Array.from({ length: 13 }, (_, i) => { const a = Math.PI * (i / 12); return `<path d="M100 230L${(100 - Math.cos(a) * 260).toFixed(0)} ${(230 - Math.sin(a) * 260).toFixed(0)}"/>`; }).join('')}</g>
      <path d="M0 14h200M0 20h200" stroke="#b8963c" stroke-width="2"/>
      <path d="M86 0l14 10 14-10" fill="none" stroke="#b8963c" stroke-width="2"/>`;
    case 6: return `
      <g fill="${soft}">${Array.from({ length: 9 }, (_, i) => Array.from({ length: 10 }, (_, j) => `<circle cx="${10 + j * 20}" cy="${10 + i * 20}" r="1.3"/>`).join('')).join('')}</g>
      <path d="M0 220v-70h18v-24h16v40h14v-56h20v40h10v-22h18v52h16v-34h14v-16h12v50h14v-30h16v-12h14v82z" fill="${mix(bg, '#5a6a7a', 0.35)}"/>`;
    default: return `
      <g fill="none" stroke="${soft}" stroke-width="1.5" opacity=".8">
        <path d="M0 40h30l10 10h20M200 60h-26l-10-10h-22M0 150h22l12-12h18M200 170h-30l-8 8h-14"/>
        <circle cx="62" cy="50" r="3"/><circle cx="140" cy="50" r="3"/><circle cx="54" cy="138" r="3"/><circle cx="146" cy="178" r="3"/>
      </g>
      <circle cx="100" cy="90" r="58" fill="none" stroke="${mix(bg, '#6fd0e0', 0.5)}" stroke-width="2" opacity=".7"/>`;
  }
}

/** Oblečení podle doby (přes ramena). */
function outfit(age, c, body, dark) {
  switch (age) {
    case 1: return `<path d="M44 176l10-12 8 10 8-14 10 12 10-14 10 14 10-14 10 14 10-12 8 14 10-10 8 12c-10-14-30-26-66-26s-56 12-66 26z" fill="#8a6a46"/>`;
    case 2: return `<path d="M60 160c30 6 60 30 80 60h-26c-14-24-34-42-60-50z" fill="#efe6d6" opacity=".9"/>`;
    case 3: return `<path d="M70 150c10 10 50 10 60 0l6 6c-12 14-60 14-72 0z" fill="${dark}"/><circle cx="100" cy="162" r="6" fill="#d9b25a"/>`;
    case 4: return `<path d="M92 146c-6 10-6 22 8 34 14-12 14-24 8-34z" fill="#f4efe6"/><path d="M96 152h8M95 160h10" stroke="#d8cfc0" stroke-width="2"/>`;
    case 5: return `<path d="M84 146l16 30 16-30" fill="#f2efe8"/><path d="M84 146l-14 74h12l18-44zM116 146l14 74h-12l-18-44z" fill="${dark}"/><path d="M100 160l-5 8 5 40 5-40z" fill="${mix(c, '#8a1a1a', 0.5)}"/>`;
    case 6: return `<path d="M86 146c4 8 24 8 28 0" fill="none" stroke="${mix(body, '#ffffff', 0.3)}" stroke-width="4"/>`;
    default: return `<path d="M78 150c12 10 32 10 44 0" fill="none" stroke="#6fd0e0" stroke-width="3" opacity=".9"/>`;
  }
}

function frame(bg, inner, person, age = 7) {
  return `<svg class="art" viewBox="0 0 200 220" preserveAspectRatio="xMidYMid slice" aria-hidden="true">
    <rect width="200" height="220" fill="${bg}"/>
    ${scenery(age, bg)}
    <circle cx="100" cy="230" r="120" fill="#ffffff" opacity=".1"/>
    ${inner}
  </svg>`;
}

// Ikony ukazatelů (24×24). `lines` = jemné detaily v barvě pozadí nad výplní.
const ICONS = {
  fin: { d: 'M12 2.5c-4.7 0-8 1.5-8 3.3v12.4c0 1.8 3.3 3.3 8 3.3s8-1.5 8-3.3V5.8c0-1.8-3.3-3.3-8-3.3z', lines: 'M4 9.6c0 1.8 3.3 3.3 8 3.3s8-1.5 8-3.3M4 13.8c0 1.8 3.3 3.3 8 3.3s8-1.5 8-3.3' },
  lid: { d: 'M8.5 11.2a3.6 3.6 0 1 0 0-7.2 3.6 3.6 0 0 0 0 7.2zM16.3 10.4a2.9 2.9 0 1 0 0-5.8 2.9 2.9 0 0 0 0 5.8zM1.5 21c0-4.2 3.1-7.6 7-7.6s7 3.4 7 7.6zM15.6 21c0-2.7-.8-5-2.2-6.6.9-.5 1.8-.8 2.9-.8 3.4 0 6.2 2.9 6.2 6.6v.8z' },
  sil: { d: 'M12 2l8.5 3.2v6.2c0 5.2-3.6 9.3-8.5 10.6-4.9-1.3-8.5-5.4-8.5-10.6V5.2z', lines: 'M12 5v14' },
  ved: { d: 'M8.5 2h7v2h-1.2v5.2l5.9 9.7A2.1 2.1 0 0 1 18.4 22H5.6a2.1 2.1 0 0 1-1.8-3.1l5.9-9.7V4H8.5z', lines: 'M6.5 15.5h11' },
  pri: { d: 'M20.5 3.5C11 3 4.5 7.5 4.5 14.5c0 1.9.5 3.5 1.3 4.7L3.5 21.5l1 1 2.3-2.3c1.2.8 2.8 1.3 4.6 1.3 6.6 0 10.4-6.5 9.1-18z', lines: 'M6.8 20.2C10 14 13.5 10.5 17 8' },
  vir: { d: 'M12 1c1.3 4.6 7.2 7.4 7.2 14a7.2 7.2 0 0 1-14.4 0c0-4 2.3-6.3 2.8-9.6 2.1 1.3 3.7 3.8 3.7 6.6 1.8-2.7 1.9-6.9.7-11z' },
  dip: { d: 'M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20z', lines: 'M2.5 12h19M12 2.3c-2.8 2.7-4.3 6-4.3 9.7s1.5 7 4.3 9.7M12 2.3c2.8 2.7 4.3 6 4.3 9.7s-1.5 7-4.3 9.7' },
};

export function meterIcon(id) {
  const i = ICONS[id];
  return `<svg class="micon" viewBox="0 0 24 24" aria-hidden="true">
    <defs><clipPath id="clip-${id}"><rect class="lvl" data-l="${id}" x="0" y="0" width="24" height="24"/></clipPath></defs>
    <path d="${i.d}" class="base"/>
    <path d="${i.d}" class="full" clip-path="url(#clip-${id})"/>
    ${i.lines ? `<path d="${i.lines}" class="lines"/>` : ''}
  </svg>`;
}

/** Ukazatel bez plnění (do seznamů). */
export function glyph(id, cls = 'glyph') {
  const i = ICONS[id];
  return `<svg class="${cls}" viewBox="0 0 24 24" aria-hidden="true"><path d="${i.d}" class="full"/>${i.lines ? `<path d="${i.lines}" class="lines"/>` : ''}</svg>`;
}

// Kreslené ikony (tahy, 24×24) – typy vůdců, zákony, nálady, tajné konce.
const LINE = {
  vize: '<path d="M2 12s3.8-7 10-7 10 7 10 7-3.8 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3.2"/>',
  krize: '<circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="4"/><path d="M5.6 5.6l3.6 3.6M18.4 5.6l-3.6 3.6M5.6 18.4l3.6-3.6M18.4 18.4l-3.6-3.6"/>',
  odklad: '<path d="M4 6l7 6-7 6zM11 6l7 6-7 6z"/><path d="M20.5 5.5v13"/>',
  kormidlo: '<circle cx="12" cy="12" r="6.5"/><circle cx="12" cy="12" r="1.6"/><path d="M12 2v4M12 18v4M2 12h4M18 12h4M4.9 4.9l2.8 2.8M16.3 16.3l2.8 2.8M4.9 19.1l2.8-2.8M16.3 7.7l2.8-2.8"/>',
  rada: '<path d="M4 5.5h16a1.5 1.5 0 0 1 1.5 1.5v8a1.5 1.5 0 0 1-1.5 1.5h-9l-5 4v-4H4A1.5 1.5 0 0 1 2.5 15V7A1.5 1.5 0 0 1 4 5.5z"/><path d="M8 11h.01M12 11h.01M16 11h.01" stroke-width="2.6"/>',
  law: '<path d="M7 3.5h10.5a2 2 0 0 1 2 2V17"/><path d="M5 7.5v11a2 2 0 0 0 2 2h9.5a2 2 0 0 0 2-2V17H7.5"/><path d="M5 7.5a2 2 0 1 1 2-2v2zM9.5 9h6M9.5 12.5h6"/>',
  task: '<circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="5"/><circle cx="12" cy="12" r="1.2"/>',
  era: '<path d="M12 3v2.5M12 18.5V21M3 12h2.5M18.5 12H21M5.6 5.6l1.8 1.8M16.6 16.6l1.8 1.8M5.6 18.4l1.8-1.8M16.6 7.4l1.8-1.8"/><circle cx="12" cy="12" r="4"/>',
  people: '<circle cx="9" cy="8" r="3.2"/><path d="M3 20c0-3.6 2.7-6.2 6-6.2s6 2.6 6 6.2"/><circle cx="17" cy="9" r="2.5"/><path d="M16.5 13.8c2.6 0 4.5 2.2 4.5 5.2"/>',
  key: '<circle cx="8" cy="15" r="4"/><path d="M11 12l8-8M16 7l2.5 2.5M18.5 4.5L21 7"/>',
  kontakt: '<ellipse cx="12" cy="13" rx="10" ry="3.5"/><path d="M6.5 11.5a5.5 5.5 0 0 1 11 0"/><path d="M8 18l-1.5 3M16 18l1.5 3M12 17v4"/>',
  podzemi: '<path d="M3 18h18l-1.5-10-4.5 4-3-6-3 6-4.5-4z"/><path d="M4.5 21h15"/>',
  pravda: '<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3c-2.6 2.6-4 5.6-4 9s1.4 6.4 4 9M12 3c2.6 2.6 4 5.6 4 9s-1.4 6.4-4 9"/>',
  // další typy vůdců
  zachrance: '<path d="M12 3l7 3v5c0 4.6-3 8.3-7 10-4-1.7-7-5.4-7-10V6z"/><path d="M12 8v6M9 11h6"/>',
  charisma: '<path d="M12 3l2.6 5.6 6 .7-4.5 4.1 1.2 6L12 16.4 6.7 19.4l1.2-6L3.4 9.3l6-.7z"/>',
  prorok: '<circle cx="12" cy="10" r="6.5"/><path d="M7 19h10M8.5 16.2L7 19M15.5 16.2L17 19"/><path d="M9.5 8.5a3 3 0 0 1 2.5-1.5"/>',
  byro: '<rect x="5" y="3" width="14" height="18" rx="2"/><path d="M8.5 8h7M8.5 12h7M8.5 16h4"/>',
  hazard: '<rect x="4" y="4" width="16" height="16" rx="3"/><circle cx="8.5" cy="8.5" r=".9" fill="currentColor"/><circle cx="15.5" cy="15.5" r=".9" fill="currentColor"/><circle cx="12" cy="12" r=".9" fill="currentColor"/><circle cx="15.5" cy="8.5" r=".9" fill="currentColor"/><circle cx="8.5" cy="15.5" r=".9" fill="currentColor"/>',
  reform: '<path d="M14.5 4.5l5 5M12 7l5 5M4 20l8.5-8.5M10 9.5l4.5 4.5"/><path d="M13 3.5l7.5 7.5-2.5 2.5L10.5 6z"/>',
  // výhody, volby, krize, čas, statistiky
  book: '<path d="M4 5.5A2.5 2.5 0 0 1 6.5 3H20v15H6.5A2.5 2.5 0 0 0 4 20.5z"/><path d="M4 20.5A2.5 2.5 0 0 0 6.5 23H20v-5M8 7.5h8M8 11h6"/>',
  help: '<circle cx="12" cy="12" r="9"/><path d="M9.6 9.3a2.5 2.5 0 0 1 4.8.9c0 1.7-2.4 2.2-2.4 3.8M12 17.2v.3"/>',
  sound: '<path d="M4 9.5h3.5L12 5.5v13l-4.5-4H4z"/><path d="M15.5 9a4.5 4.5 0 0 1 0 6M18 6.5a8 8 0 0 1 0 11"/>',
  mute: '<path d="M4 9.5h3.5L12 5.5v13l-4.5-4H4z"/><path d="M16 9.5l5 5M21 9.5l-5 5"/>',
  home: '<path d="M3.5 11L12 4l8.5 7"/><path d="M6 9.5V20h12V9.5M10 20v-5.5h4V20"/>',
  play: '<path d="M8 5.5v13l10.5-6.5z"/>',
  chev: '<path d="M9.5 6l6 6-6 6"/>',
  globe: '<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3c-2.6 2.6-4 5.6-4 9s1.4 6.4 4 9M12 3c2.6 2.6 4 5.6 4 9s-1.4 6.4-4 9"/>',
  sun: '<rect x="3.5" y="5" width="17" height="15.5" rx="2.5"/><path d="M3.5 10h17M8 3v4M16 3v4"/><circle cx="12" cy="15" r="1.6" fill="currentColor"/>',
  perk: '<path d="M12 3v4M12 17v4M3 12h4M17 12h4M6 6l2.5 2.5M15.5 15.5L18 18M18 6l-2.5 2.5M8.5 15.5L6 18"/>',
  vote: '<path d="M4 12h16v8H4z"/><path d="M8 12V5h8v7M10 8.5l1.5 1.5L14.5 7"/>',
  crisis: '<path d="M12 3.5L21.5 20h-19z"/><path d="M12 10v4.5M12 17.2v.3"/>',
  timer: '<circle cx="12" cy="13.5" r="7.5"/><path d="M12 13.5V9.5M10 2.5h4M18.5 6.5l1.5-1.5"/>',
  stats: '<path d="M4 20h16M7 20v-6M12 20V6M17 20v-10"/>',
  trophy: '<path d="M7 4h10v4a5 5 0 0 1-10 0z"/><path d="M7 6H4.5a2.5 2.5 0 0 0 2.8 3.4M17 6h2.5a2.5 2.5 0 0 1-2.8 3.4M12 13v4M8.5 20.5h7M9.5 20.5c0-2 1-3.5 2.5-3.5s2.5 1.5 2.5 3.5"/>',
  rescue: '<circle cx="12" cy="12" r="8.5"/><circle cx="12" cy="12" r="3.5"/><path d="M6 6l3.5 3.5M18 6l-3.5 3.5M6 18l3.5-3.5M18 18l-3.5-3.5"/>',
};
export function icon(name, cls = 'ico') {
  return `<svg class="${cls}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${LINE[name]}</svg>`;
}
/** Nálada postavy: věrná (srdce) / nepřátelská (blesk). */
export function mood(rel, loyal) {
  if (rel >= loyal) return '<svg class="mood good" viewBox="0 0 24 24" aria-label="věrný"><path d="M12 20.5S3 15 3 9a4.5 4.5 0 0 1 9-1.6A4.5 4.5 0 0 1 21 9c0 6-9 11.5-9 11.5z"/></svg>';
  if (rel <= -loyal) return '<svg class="mood bad" viewBox="0 0 24 24" aria-label="nepřátelský"><path d="M13.5 2L5 13.5h6L9.5 22 19 9.5h-6z"/></svg>';
  return '';
}
