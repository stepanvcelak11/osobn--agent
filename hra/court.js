// Dvůr a rod: pověst vůdce, děti a dědicové, osobní ambice a tituly dynastie. Jen data – engine (game.js)
// a obrazovky (ui.js) z nich čtou.

/// Pověst: podle rozhodnutí si lidé o vůdci udělají obrázek. Za každou volbu, která sedí, bod;
/// pověst platí, když má aspoň REP_MIN bodů a vede. Tlumí, nebo zesiluje změny ukazatelů.
export const REP_MIN = 8;
export const REPS = {
  tyran: { name: 'Tyran', text: 'Bojí se tě: frakce se zlobí o polovinu pomaleji, ale Lid tě nemiluje (jeho růst je o pětinu menší).' },
  dobry: { name: 'Dobrotivý', f: 'Dobrotivá', text: 'Lid ti odpouští: jeho pokles je o čtvrtinu menší.' },
  lakomec: { name: 'Lakomec', f: 'Lakomá', text: 'Pokladna drží: pokles Financí je o čtvrtinu menší, ale Lid se zlobí rychleji.' },
  ucenec: { name: 'Učenec', f: 'Učenka', text: 'Učenci tě hájí: pokles Vědy je o čtvrtinu menší, Víra ale klesá rychleji.' },
  zbozny: { name: 'Zbožný', f: 'Zbožná', text: 'Kněží tě hájí: pokles Víry je o čtvrtinu menší, Věda ale klesá rychleji.' },
};
/** Co volba vypovídá o vůdci (podle skutečných změn ukazatelů). */
export function repOf(d) {
  const out = [];
  if ((d.sil ?? 0) > 0 && (d.lid ?? 0) < 0) out.push('tyran');
  if ((d.lid ?? 0) > 0 && (d.fin ?? 0) < 0) out.push('dobry');
  if ((d.fin ?? 0) > 0 && (d.lid ?? 0) < 0) out.push('lakomec');
  if ((d.ved ?? 0) > 0 && (d.vir ?? 0) <= 0) out.push('ucenec');
  if ((d.vir ?? 0) > 0 && (d.ved ?? 0) <= 0) out.push('zbozny');
  return out;
}
/** Násobek změny ukazatele k (o velikosti d) podle pověsti. */
export function repMult(rep, k, d) {
  if (!rep || !d) return 1;
  if (rep === 'tyran' && k === 'lid' && d > 0) return 0.8;
  if (rep === 'dobry' && k === 'lid' && d < 0) return 0.75;
  if (rep === 'lakomec' && d < 0) return k === 'fin' ? 0.75 : k === 'lid' ? 1.15 : 1;
  if (rep === 'ucenec' && d < 0) return k === 'ved' ? 0.75 : k === 'vir' ? 1.15 : 1;
  if (rep === 'zbozny' && d < 0) return k === 'vir' ? 0.75 : k === 'ved' ? 1.15 : 1;
  return 1;
}

/// Děti vůdce: vlastnost od narození, výchova (ukazatel), z dětí se vybírá dědic.
export const TRAITS = {
  statecny: { name: 'Statečný', f: 'Statečná', perk: 'brzda' },
  moudry: { name: 'Moudrý', f: 'Moudrá', perk: 'nahled' },
  laskavy: { name: 'Laskavý', f: 'Laskavá', perk: 'sarm' },
  vytrvaly: { name: 'Vytrvalý', f: 'Vytrvalá', perk: 'stabilita' },
  bystry: { name: 'Bystrý', f: 'Bystrá', perk: 'nabiti' },
};
export const EDU = { sil: 'vojenská', vir: 'církevní', ved: 'učená', dip: 'dvorská' };
export const KIDS_MAX = 3;
export const HEIR_DAMP = 0.8; // výchova: dědicův ukazatel se mění o pětinu méně

/// Královská rada: až tři rádci z lidí, kteří ti věří. Každý tlumí pokles „svého“ ukazatele.
export const COUNCIL_MAX = 3;
export const COUNCIL_MIN_REL = 2; // jmenovat jde jen toho, kdo má k vládě aspoň takový vztah
export const COUNCIL_DAMP = 0.8;

/// Osobní ambice: tajný cíl každého vůdce. Splnění = body a zápis do kroniky.
export const AMBITIONS = [
  { id: 'a_vira', type: 'hold', m: 'vir', min: 65, n: 12, text: 'Drž Víru nad 65 % celý rok.' },
  { id: 'a_veda', type: 'hold', m: 'ved', min: 70, n: 12, text: 'Drž Vědu nad 70 % celý rok.' },
  { id: 'a_sila', type: 'hold', m: 'sil', min: 65, n: 12, text: 'Drž Sílu nad 65 % celý rok.' },
  { id: 'a_lid', type: 'hold', m: 'lid', min: 65, n: 12, text: 'Drž Lid nad 65 % celý rok.' },
  { id: 'a_pokl', type: 'hold', m: 'fin', min: 65, n: 12, text: 'Drž Finance nad 65 % celý rok.' },
  { id: 'a_klid', type: 'calm', n: 18, text: 'Drž všech 7 ukazatelů mezi 30 a 70 % rok a půl.' },
  { id: 'a_pratele', type: 'friends', n: 3, text: 'Získej 3 věrné lidi.' },
  { id: 'a_stavba', type: 'built', text: 'Dokonči velkou stavbu.' },
  { id: 'a_rod', type: 'kids', n: 2, text: 'Měj 2 děti.' },
  { id: 'a_dlouho', type: 'months', n: 60, text: 'Vládni 5 let.' },
];
export const AMB_POINTS = 2;

/// Tituly dynastie: trvalé přídomky za milníky (statistiky hráče). Jeden aktivní dává malý bonus.
export const TITLES = {
  stavitele: { name: 'Rod Stavitelů', need: 'Dokonči 5 velkých staveb.', stat: 'built', n: 5, text: 'Stavby trvají o čtvrtinu kratší dobu.' },
  mirotvurci: { name: 'Rod Mírotvůrců', need: 'Uzavři 3 sňatky nebo obchodní smlouvy se sousedy.', stat: 'pacts', n: 3, text: 'Sousední rod tě má na začátku vlády o 2 radši.' },
  valecnici: { name: 'Rod Válečníků', need: 'Vyhraj 5 válek.', stat: 'wars', n: 5, text: 'Ve válce máš navíc 10 Síly.' },
  otcove: { name: 'Rod Otců národa', need: 'Korunuj 3 dědice z vlastního rodu.', stat: 'heirs', n: 3, text: 'Frakce se zlobí o čtvrtinu pomaleji.' },
  zlati: { name: 'Rod Zlatého věku', need: 'Zažij 3 zlaté věky.', stat: 'golden', n: 3, text: 'Zlatý věk přijde už po 5 klidných měsících.' },
  kronikari: { name: 'Rod Kronikářů', need: 'Dokonči 5 příběhů.', stat: 'arcs', n: 5, text: 'Za splněnou ambici dostaneš bod navíc.' },
};
