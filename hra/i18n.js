// Jazyk hry: čeština (výchozí) a angličtina. Překlad je slovník „český text → anglický text“:
// – obsah (karty, konce, postavy…) se překládá při dosazení textu (fill v game.js) a při zobrazení,
// – rozhraní se překládá přímo v zobrazené stránce (každý nový text se dohledá ve slovníku),
// – složené věty s čísly a jmény řeší vzory (PATTERNS) – zachycené části se překládají znovu.
const KEY = 'rovnovaha.lang';
export const LANGS = { cs: 'Čeština', en: 'English' };
export let lang = (() => {
  try { const v = localStorage.getItem(KEY); if (v && LANGS[v]) return v; } catch { /* nic */ }
  return 'cs';
})();
export function setLang(l) {
  if (!LANGS[l]) return;
  try { localStorage.setItem(KEY, l); } catch { /* nic */ }
  location.reload();
}

const DICT = new Map();
const PATTERNS = [];
/** Přidá slovník (objekt cz → en) a vzory [[RegExp, náhrada], …]. */
export function addDict(obj, patterns = []) {
  for (const [k, v] of Object.entries(obj)) if (v) DICT.set(norm(k), v);
  for (const p of patterns) PATTERNS.push(p);
}
const norm = (s) => String(s).replace(/\s+/g, ' ').trim();

/** Překlad jednoho textu (beze změny, když překlad chybí nebo je hra česky). */
export function tr(s) {
  if (lang === 'cs' || s == null) return s;
  const raw = String(s), k = norm(raw);
  if (!k || !/[A-Za-zÀ-ž]/.test(k)) return raw;
  const hit = DICT.get(k);
  if (hit != null) return keepSpaces(raw, hit);
  for (const [re, rep] of PATTERNS) {
    const m = k.match(re);
    if (!m) continue;
    const out = typeof rep === 'function' ? rep(m, tr) : rep.replace(/\$(\d)/g, (_, i) => tr(m[i] ?? ''));
    return keepSpaces(raw, out);
  }
  return raw;
}
const keepSpaces = (raw, t) => (/^\s/.test(raw) ? ' ' : '') + t + (/\s$/.test(raw) ? ' ' : '');

// ── Překlad zobrazené stránky ────────────────────────
const ATTRS = ['aria-label', 'title', 'placeholder'];
const SKIP = new Set(['SCRIPT', 'STYLE']);
function walk(node) {
  if (node.nodeType === 3) {
    const t = node.nodeValue, n = tr(t);
    if (n !== t) node.nodeValue = n;
    return;
  }
  if (node.nodeType !== 1 || SKIP.has(node.nodeName)) return;
  for (const a of ATTRS) { const v = node.getAttribute?.(a); if (v) { const n = tr(v); if (n !== v) node.setAttribute(a, n); } }
  for (const c of node.childNodes) walk(c);
}
/** Spustí průběžný překlad stránky (jen v angličtině). */
export function startTranslating(root = document.body) {
  if (lang === 'cs') return;
  document.documentElement.lang = lang;
  walk(root);
  new MutationObserver((list) => {
    for (const m of list) {
      if (m.type === 'characterData') walk(m.target);
      else for (const n of m.addedNodes) walk(n);
      if (m.type === 'attributes') walk(m.target);
    }
  }).observe(root, { childList: true, subtree: true, characterData: true, attributes: true, attributeFilter: ATTRS });
}
