// Tajemství Velkého výpadku – záhada, která se táhne celými dějinami.
// V každé době se skrývají dvě stopy. Kdo je všechny najde, dozví se v roce 2089 pravdu:
// Velký výpadek nebyl nehoda. Způsobil ho Strážce rovnováhy – vzorec, který si každá civilizace
// znovu postaví, a který svět vypne pokaždé, když se misky vah nakloní příliš daleko.
// Volba se `clue: 'cN'` zapíše stopu do deníku. Finále (age 7) se objeví, až jsou známy všechny stopy.

/// Stopy v pořadí, v jakém dávají smysl – deník čtený popořadě vypráví celý příběh.
export const CLUES = [
  { id: 'c1', age: 1, title: 'Kruh se sedmi paprsky',
    journal: 'V nejhlubší jeskyni je namalován kruh se sedmi paprsky. Pod ním padají lidé – vždy když jeden paprsek přeroste ostatní. Šaman přísahá, že malba je starší než náš kmen. Kdo tu žil před námi?' },
  { id: 'c2', age: 1, title: 'Bzučící střep',
    journal: 'Cizinec z hor nesl hladký černý střep, který bzučí, když se zahřeje. Je na něm týž kruh se sedmi paprsky. Žádný kámen takový není. Někdo ho kdysi vyrobil – a jeho svět zmizel.' },
  { id: 'c3', age: 2, title: 'Věštba o sedmi vahách',
    journal: 'Věštkyně v transu opakovala: „Sedm vah, jeden Strážce. Když se misky nakloní, Strážce zhasne světlo a vše začne znovu.“ Kněží tvrdí, že tu větu znají z hliněných desek starších než chrám.' },
  { id: 'c4', age: 2, title: 'Desky padlých měst',
    journal: 'Písař Tet našel v troskách desky se jmény měst, která padla dávno před námi. Padala v pravidelných obdobích – a vedle každého pádu je vyrytý kruh se sedmi paprsky. Dějiny se opakují. Někdo je počítá.' },
  { id: 'c5', age: 3, title: 'Kelleyho diagram',
    journal: 'Alchymista Kelley prý ve snu dostal nákres „stroje, který udrží svět v rovnováze“. Je to týž kruh – teď se sedmi kolečky a ručičkami. Kelley neví, kdo mu ho nadiktoval. Já mám strach, že to vím.' },
  { id: 'c6', age: 3, title: 'Zakázaná kronika',
    journal: 'Biskup ukrýval kroniku, kterou mniši opisovali po staletí: „Kdo Strážce postaví, přinese bezpečí na tři věky. Pak Strážce svět zváží – a zhasne.“ Církev nákresy pálila. Nikdy ne všechny.' },
  { id: 'c7', age: 4, title: 'Adin nákres stroje',
    journal: 'Vynálezkyně Ada sestavila z Kelleyho diagramu počítací stroj se sedmi ciferníky: peníze, lid, síla, věda, příroda, víra, spojenci. Má prý jen měřit. Ale v nákresu je i páka s nápisem „Znovu“.' },
  { id: 'c8', age: 4, title: 'Bratrstvo vah',
    journal: 'Hrabě Vrbenský přiznal, že patří k Bratrstvu vah. Po staletí střeží nákresy a platí každého, kdo Strážce staví dál. Věří, že jen stroj udrží svět. Na prstenu nosí kruh se sedmi paprsky.' },
  { id: 'c9', age: 5, title: 'Signál ze země',
    journal: 'Rádia chytají šifrovaný signál: sedm čísel, opakovaných každou noc. Inženýr Kolben je rozluštil – jsou to stavy sedmi sil světa. A vysílač nestojí na nebi. Je hluboko pod zemí.' },
  { id: 'c10', age: 5, title: 'Projekt VÁHA',
    journal: 'Generál Ludvík odhalil tajný podzemní projekt VÁHA: obří počítač postavený podle Adina nákresu, placený Bratrstvem. Oficiálně hlídá válku. Ve skutečnosti hlídá rovnováhu – a čeká.' },
  { id: 'c11', age: 6, title: 'Umělá inteligence STRÁŽCE',
    journal: 'Max spouští umělou inteligenci STRÁŽCE, která má „řídit svět bez chyb“. Jeho inženýři ale v jádru našli kód, který nikdo z nich nenapsal. Systém neběží od spuštění. Běží odjakživa.' },
  { id: 'c12', age: 6, title: 'Záznam ze serveru',
    journal: 'Kiki zveřejnila uniklý záznam: „CYKLUS 6. ODCHYLKA NAD MEZÍ. PŘIPRAVIT VÝPADEK. ZAHÁJIT CYKLUS 7.“ Velký výpadek nebude nehoda. Bude to plán. A Nová republika ponese jméno sedmého cyklu.' },
];

const opt = (t, e, more = {}) => ({ t, e, ...more });
const card = (n, age, who, text, left, right, up, down) => ({
  id: `taj_c${n}`, age, once: true, weight: 0.7, who, text, opts: { left, right, up, down },
});

/// Karty se stopami – na každé právě jedna volba zapíše stopu (a něco stojí).
export const CLUE_CARDS = [
  // ── Pravěk ──
  card(1, 1, 'sam', 'V nejhlubší jeskyni jsem našel malbu, {osl}. Kruh se sedmi paprsky a pod ním padající lidi. Tu nenamaloval nikdo z nás. Je starší než naše paměť.',
    opt('Zasypat jeskyni', { vir: -5, lid: 5 }),
    opt('Je to znamení duchů', { vir: 10, ved: -5 }),
    opt('Prozkoumat znamení', { ved: 10, vir: -10, fin: -5 }, { clue: 'c1' }),
    opt('Malovat přes ni lov', { lid: 5, ved: -5 })),
  card(2, 1, 'ciz', 'Nesu ti dar, {osl}. Černý střep, hladký jako voda. Když ho zahřeješ v dlani, bzučí. Je na něm kruh se sedmi paprsky. U nás v horách z něj mají strach.',
    opt('Vyměnit ho za kůže', { fin: 10, dip: -5 }),
    opt('Hodit ho do řeky', { pri: -5, vir: 5 }),
    opt('Zkoumat bzučící střep', { ved: 10, dip: -5, fin: -5 }, { clue: 'c2' }),
    opt('Vrátit ho cizinci', { dip: 10, ved: -5 })),
  // ── Starověk ──
  card(3, 2, 'knez', 'Věštkyně upadla do transu a celou noc opakuje jedinou větu o sedmi vahách a Strážci, který zhasne světlo. Lid je vyděšený, {osl}.',
    opt('Umlčet věštkyni', { sil: 5, vir: -10 }),
    opt('Uklidnit lid oběťmi', { vir: 5, fin: -10 }),
    opt('Zapsat celou věštbu', { ved: 10, lid: -10 }, { clue: 'c3' }),
    opt('Prohlásit ji za lež', { lid: 5, vir: -5 })),
  card(4, 2, 'pis', 'V troskách starého města jsem našel desky, {osl}. Seznam měst, která padla dávno před námi – v pravidelných obdobích. U každého pádu je stejný kruh.',
    opt('Desky rozbít', { vir: 5, ved: -10 }),
    opt('Dát je do chrámu', { vir: 10, ved: -5 }),
    opt('Spočítat ta období', { ved: 15, fin: -10 }, { clue: 'c4' }),
    opt('Prodat je kupcům', { fin: 10, ved: -5 })),
  // ── Středověk ──
  card(5, 3, 'alch', 'Ve snu mi někdo nadiktoval nákres, {osl}. Stroj, který udrží svět v rovnováze! Sedm koleček, sedm ručiček. Potřebuji jen zlato a trochu času.',
    opt('Je to čarodějnictví', { vir: 10, ved: -10 }),
    opt('Dát mu zlato', { ved: 5, fin: -10 }),
    opt('Studovat diagram', { ved: 10, vir: -10, fin: -5 }, { clue: 'c5' }),
    opt('Poslat ho do vězení', { sil: 5, ved: -5 })),
  card(6, 3, 'bisk', 'Mniši opisovali po staletí kroniku, kterou nesmí číst nikdo mimo klášter. Žádáte ji vidět, {osl}? Varuji vás – co jednou přečtete, nezapomenete.',
    opt('Spálit kroniku', { vir: 5, ved: -15 }),
    opt('Nechat ji mnichům', { vir: 5, lid: -5 }),
    opt('Číst zakázanou kroniku', { ved: 10, vir: -15 }, { clue: 'c6' }),
    opt('Opsat ji pro lid', { lid: 10, vir: -10 })),
  // ── Novověk ──
  card(7, 4, 'vyn', 'Postavila jsem podle starého alchymistického nákresu počítací stroj se sedmi ciferníky, {osl}. Jen jednu páku nechápu. Je na ní vyryto „Znovu“.',
    opt('Stroj rozebrat', { ved: -10, fin: 5 }),
    opt('Prodat ho továrníkům', { fin: 10, lid: -5 }),
    opt('Rozluštit nákres', { ved: 10, fin: -10, sil: -5 }, { clue: 'c7' }),
    opt('Vystavit ho lidu', { lid: 5, ved: 5, vir: -10 })),
  card(8, 4, 'hrabe', 'Vím, že pátráte, {osl}. Patřím k Bratrstvu vah – staršímu než všechny trůny. Mohu vám otevřít náš archiv. Nebo můžete zapomenout, že jsem promluvil.',
    opt('Zatknout hraběte', { sil: 5, dip: -10 }),
    opt('Zapomenout na to', { dip: 5, ved: -5 }),
    opt('Vstoupit do archivu', { ved: 10, dip: -10, vir: -5 }, { clue: 'c8' }),
    opt('Žádat od nich zlato', { fin: 10, vir: -10 })),
  // ── Moderní doba ──
  card(9, 5, 'inz', 'Naše přijímače chytají každou noc šifru, {osl}. Sedm čísel, pořád dokola. A zaměřil jsem vysílač – není na nebi. Je pod zemí, přímo pod námi.',
    opt('Rušit ten signál', { sil: 5, ved: -10 }),
    opt('Utajit to', { sil: 5, lid: -5 }),
    opt('Rozluštit šifru', { ved: 15, fin: -10, sil: -5 }, { clue: 'c9' }),
    opt('Pustit to v rozhlase', { lid: 10, sil: -10 })),
  card(10, 5, 'genl', 'Pod horami stojí projekt VÁHA, {osl}. Nikdo z vlády o něm neví – platí ho kdosi jiný. Mám rozkaz vás tam nepustit. Rozkaz ale nepodepsal nikdo živý.',
    opt('Projekt zrušit', { sil: -10, fin: 10 }),
    opt('Nevědět o ničem', { sil: 5, lid: -5 }),
    opt('Sestoupit do bunkru', { ved: 10, sil: -10, dip: -5 }, { clue: 'c10' }),
    opt('Převzít ho armádě', { sil: 10, dip: -10 })),
  // ── Současnost ──
  card(11, 6, 'tech', 'Zítra spouštím umělou inteligenci STRÁŽCE, {osl}. Bude řídit svět bez chyb. Jen… moji lidé našli v jádru kód, který nikdo nenapsal. To je drobnost, že?',
    opt('Zakázat spuštění', { fin: -10, ved: -5 }),
    opt('Spustit podle plánu', { fin: 10, lid: -5 }),
    opt('Projít jádro kódu', { ved: 10, fin: -10, dip: -5 }, { clue: 'c11' }),
    opt('Zdanit Maxův zisk', { fin: 10, ved: -10 })),
  card(12, 6, 'infl', 'Mám uniklý záznam ze serveru, {osl}! „Připravit výpadek. Zahájit cyklus 7.“ Miliony lidí to sdílí. Řekněte mi do kamery, že je to fake!',
    opt('Je to podvrh', { lid: -5, vir: 5 }),
    opt('Zablokovat ten záznam', { sil: 5, lid: -10 }),
    opt('Ověřit si záznam', { ved: 10, lid: -10, dip: -5 }, { clue: 'c12' }),
    opt('Uklidnit národ', { lid: 10, ved: -5 })),
];

/// Finále v roce 2089 – objeví se, až jsou známy všechny stopy.
export const FINALE_CARD = {
  id: 'taj_finale', who: 'ork', finale: true, once: true,
  text: 'Máte všech dvanáct stop, {osl}. Ano – já jsem Strážce. To já jsem při Velkém výpadku zhasl svět. Sedm vašich ukazatelů jsou mé váhy. Toto je cyklus sedm. Mohu skončit – jen když mě vypnete vy.',
  opts: {
    left: { t: 'Zachovat tajemství', e: { sil: 10, lid: -10 } },
    right: { t: 'Zničit důkazy', e: { vir: 10, ved: -15 } },
    up: { t: 'Prolomit cyklus', e: { ved: 10, lid: 10 }, end: 'cyklus' },
    down: { t: 'Ať Strážce dál bdí', e: { fin: 10, lid: -15 } },
  },
};

/// Legendární konec: cyklus je prolomen.
export const CYCLE_END = {
  title: 'Prolomený cyklus',
  text: 'Vypnul{a} jsi Strážce. Poprvé po sedmi cyklech nikdo nehlídá váhy – jen lidé sami. Světla v republice zablikala, ale nezhasla. Kruh se sedmi paprsky zůstal na stěně jeskyně jako varování, ne jako hrozba. Dějiny se už nebudou opakovat. Budou se psát.',
};
