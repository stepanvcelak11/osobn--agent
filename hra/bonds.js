// Vztahy pro všechny postavy: komu dlouho škodíš, ten se rozzlobí a přijde s výčitkami (karta „zloba“),
// komu pomáháš, ten se ti odvděčí (karta „vděk“). Postavy, které mají vlastní ručně psané karty vztahů
// (generálka, ministr financí…), se přeskočí. Karty se skládají z postavy a toho, na čem jí záleží.

const HURT = {
  fin: 'naše zásoby a peníze', lid: 'obyčejní lidé', sil: 'naši bojovníci a stráže', ved: 'poznání a učenci',
  pri: 'příroda kolem nás', vir: 'víra a naše tradice', dip: 'naše vztahy se sousedy',
};
const OFFER = {
  fin: 'dám ti část svého bohatství', lid: 'přesvědčím lidi, aby tě podpořili', sil: 'moji lidé budou stát při tobě',
  ved: 'naučím tvé lidi všechno, co umím', pri: 'postarám se o pole a lesy', vir: 'budu za tebe mluvit před věřícími',
  dip: 'promluvím za tebe se sousedy',
};
const pick = (list, not) => list.find((x) => x !== not);

/**
 * @param cares  postava → ukazatel, na kterém jí záleží
 * @param ageOf  postava → doba, ve které žije (nebo undefined = budoucnost)
 * @param skip   postavy s vlastními kartami vztahů
 * @param loyal  práh věrnosti (nepřátelství je záporný práh)
 */
export function bondCards(cares, ageOf, skip, loyal) {
  const out = [];
  for (const [who, m] of Object.entries(cares)) {
    if (skip.includes(who)) continue;
    const age = ageOf[who];
    const a = pick(['lid', 'fin', 'dip'], m), b = pick(['sil', 'vir', 'fin'], m), c = pick(['fin', 'lid'], m), d = pick(['dip', 'vir'], m);
    out.push({
      id: `zloba_${who}`, who, age, generated: true, rel: [who, -loyal], weight: 1,
      text: `Myslíš, že zapomenu, co jsi mi udělal{a}? Kvůli tobě trpí ${HURT[m]}. Teď je řada na mně.`,
      opts: {
        left: { t: 'Omluvit se', e: { [m]: 5, [a]: -5 }, rel: { [who]: 2 } },
        right: { t: 'Pohrozit trestem', e: { [b]: 5, [m]: -5 }, rel: { [who]: -1 } },
        up: { t: 'Usmířit se dary', e: { [c]: -10 }, rel: { [who]: 3 } },
        down: { t: 'Nevšímat si', e: { [m]: -10 } },
      },
    });
    out.push({
      id: `vdek_${who}`, who, age, generated: true, rel: [who, loyal], weight: 1,
      text: `Na to, co jsi pro mě udělal{a}, nezapomenu. Chci ti to oplatit – ${OFFER[m]}.`,
      opts: {
        left: { t: 'S díky přijmout', e: { [m]: 10 } },
        right: { t: 'Ať pomůže lidem', e: { [a]: 10, [m]: -5 } },
        up: { t: 'Udělit poctu', e: { [d]: 5, [c]: -5 }, rel: { [who]: 1 } },
        down: { t: 'Nic nepotřebuji', e: { [m]: 5, [d]: -5 } },
      },
    });
  }
  return out;
}
