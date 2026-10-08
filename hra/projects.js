// Velké projekty: na začátku vlády si vůdce může vybrat dlouhodobý cíl. Stavba stojí každý měsíc
// trochu zásob; po dokončení drží svůj ukazatel u rovnováhy (jako div světa). Nedokončenou stavbu
// zdědí nástupce.

export const PROJECT_MONTHS = 18;
export const PROJECTS = {
  chram: { name: 'Velký chrám', m: 'vir' },
  zahrady: { name: 'Zahrady a lesy', m: 'pri' },
  skola: { name: 'Velká škola', m: 'ved' },
  hradby: { name: 'Hradby', m: 'sil' },
  trziste: { name: 'Velké tržiště', m: 'fin' },
  snem: { name: 'Sněmovní síň', m: 'lid' },
  posel: { name: 'Síť poslů a cest', m: 'dip' },
};

const o = (t, project, e = {}) => ({ t, e, ...(project ? { project } : {}) });
/** Nabídka projektu – vylosují se tři různé stavby + možnost nestavět nic. */
export const PROJECT_CARDS = [
  { id: 'projekt_a', who: '@rada', queueOnly: true, text: 'Nastal čas zanechat po sobě něco velkého, {osl}. Stavba potrvá roky a bude stát zásoby každý měsíc – ale až bude hotová, bude zemi sloužit navždy.',
    opts: { left: o('Velký chrám', 'chram', { vir: 5 }), right: o('Zahrady a lesy', 'zahrady', { pri: 5 }), up: o('Velká škola', 'skola', { ved: 5 }), down: o('Nic nestavět', null, { fin: 10, lid: -5 }) } },
  { id: 'projekt_b', who: '@rada', queueOnly: true, text: 'Stavitelé čekají na tvé slovo, {osl}. Co postavíme? Každý měsíc to spolkne kus zásob, ale dílo přežije nás všechny.',
    opts: { left: o('Hradby', 'hradby', { sil: 5 }), right: o('Velké tržiště', 'trziste', { fin: 5 }), up: o('Sněmovní síň', 'snem', { lid: 5 }), down: o('Teď ne', null, { fin: 10, vir: -5 }) } },
  { id: 'projekt_c', who: '@rada', queueOnly: true, text: 'Lidé se ptají, čím se tvá vláda zapíše do paměti, {osl}. Stavitelé mají tři návrhy.',
    opts: { left: o('Síť poslů a cest', 'posel', { dip: 5 }), right: o('Velký chrám', 'chram', { vir: 5 }), up: o('Hradby', 'hradby', { sil: 5 }), down: o('Šetřit zásoby', null, { fin: 10, ved: -5 }) } },
];
