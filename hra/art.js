// Kresby: postavy bez obličeje (ve stylu Lapse) a ikony ukazatelů, které se plní odspodu. Vše jako SVG – ostré a lehké.

const hex = (h) => [1, 3, 5].map((i) => parseInt(h.slice(i, i + 2), 16));
const toHex = (c) => '#' + c.map((v) => Math.round(Math.max(0, Math.min(255, v))).toString(16).padStart(2, '0')).join('');
/** Smíchá dvě barvy (t = podíl druhé). */
export const mix = (a, b, t) => toHex(hex(a).map((v, i) => v + (hex(b)[i] - v) * t));

const SKIN = '#cdbba6';
const HAIR = '#2a2420';

/** Portrét postavy: silueta s doplňkem podle `look`. */
export function portrait(person) {
  const c = person.color;
  const bg = mix(c, '#efe6d6', 0.55);
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
        <path d="M100 52V36" stroke="#b9c3c9" stroke-width="4"/><circle cx="100" cy="32" r="6" fill="${c}"/>`, person);
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
    <rect x="${hx - 11}" y="${hy + hr - 6}" width="22" height="24" fill="${mix(SKIN, '#000000', 0.12)}"/>
    <circle cx="${hx}" cy="${hy}" r="${hr}" fill="${SKIN}"/>
    ${front}${scarf}`, person);
}

function frame(bg, inner, person) {
  return `<svg class="art" viewBox="0 0 200 220" preserveAspectRatio="xMidYMid slice" aria-hidden="true">
    <rect width="200" height="220" fill="${bg}"/>
    <circle cx="100" cy="230" r="120" fill="#ffffff" opacity=".12"/>
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
