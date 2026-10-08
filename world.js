// Hloubka světa Rovnováhy: vztahy postav, zákony, úkoly vůdců, éry, podmíněné volby a tajné příběhy.
// Nové vlastnosti voleb:  law = zavede zákon, repeal = zruší zákon, rel = {postava: ±n} změna vztahu,
//   need = {m, min|max} volba je dostupná jen při splnění podmínky (jinak platí `alt`), end = tajný konec.
// Nové vlastnosti karet:  era = od které éry, seals = kolik splněných úkolů je potřeba,
//   rel = [postava, práh] (záporný práh = nepřátelská, kladný = věrná).

/// Na čem kterému člověku záleží – volby, které „jeho“ ukazatel zvednou, mu udělají radost.
export const CARES = {
  fin: 'fin', gen: 'sil', ved: 'ved', eko: 'pri', kaz: 'vir', vel: 'dip', odb: 'lid', med: 'fin', ork: 'ved', stin: 'sil',
  far: 'pri', lek: 'lid', soud: 'lid', stud: 'ved', sport: 'lid', nula: 'ved', fed: 'dip', pou: 'vir', vrana: 'fin', upr: 'lid', dite: 'lid', prorok: 'vir', starosta: 'dip',
};
export const REL_MAX = 5;
export const REL_LOYAL = 3;

/// Zákony: dokud platí, každý měsíc posouvají ukazatele (po malých krocích).
export const LAWS = {
  dan_bohati: { age: 3, name: 'Daň z bohatství', icon: '💰', per: { fin: 0.5, dip: -0.25 } },
  brannost: { age: 2, name: 'Branná povinnost', icon: '🪖', per: { sil: 0.5, lid: -0.5 } },
  ochrana_lesu: { age: 4, name: 'Ochrana lesů', icon: '🌲', per: { pri: 0.5, fin: -0.5 } },
  statni_cirkev: { age: 2, name: 'Státní církev', icon: '⛪', per: { vir: 0.5, ved: -0.5 } },
  otevrene_hranice: { age: 5, name: 'Otevřené hranice', icon: '🛂', per: { dip: 0.5, sil: -0.5 } },
  robotizace: { age: 7, name: 'Robotizace průmyslu', icon: '🤖', per: { ved: 0.5, fin: 0.25, lid: -0.5 } },
  zakladni_prijem: { age: 6, name: 'Základní příjem', icon: '🍞', per: { lid: 0.5, fin: -0.5 } },
  cenzura: { age: 3, name: 'Cenzura tisku', icon: '🔇', per: { vir: 0.25, lid: -0.25, ved: -0.25, sil: 0.25 } },
  volny_trh: { age: 4, name: 'Volný trh', icon: '📈', per: { fin: 0.5, pri: -0.5 } },
  skolstvi: { age: 4, name: 'Školy zdarma', icon: '🎓', per: { ved: 0.5, fin: -0.5 } },
};

/// Úkoly vůdců. Splněný úkol = pečeť; pečetě otevírají další éry a tajné příběhy.
export const TASKS = [
  { id: 'tri_roky', text: 'Vládni alespoň 3 roky.', type: 'months', n: 36 },
  { id: 'klid', text: 'Udrž všech sedm ukazatelů mezi 30 a 70 % celý rok v kuse.', type: 'calm', n: 12 },
  { id: 'zakony', text: 'Měj zároveň v platnosti 3 zákony.', type: 'laws', n: 3 },
  { id: 'armada', text: 'Získej věrnost generálky Horákové.', type: 'rel', who: 'gen', n: REL_LOYAL },
  { id: 'odbory', text: 'Získej věrnost odborů Franty Rybáře.', type: 'rel', who: 'odb', n: REL_LOYAL },
  { id: 'pratele', text: 'Měj tři lidi, kteří jsou ti věrní.', type: 'friends', n: 3 },
  { id: 'veda', text: 'Dostaň Vědu nad 75 % – a přežij to.', type: 'reach', m: 'ved', min: 75 },
  { id: 'vira', text: 'Dostaň Víru nad 75 % – a přežij to.', type: 'reach', m: 'vir', min: 75 },
  { id: 'priroda', text: 'Drž Přírodu nad 55 % celý rok v kuse.', type: 'hold', m: 'pri', min: 55, n: 12 },
  { id: 'pokladna', text: 'Drž Finance nad 45 % dva roky v kuse.', type: 'hold', m: 'fin', min: 45, n: 24 },
  { id: 'orakl', text: 'Svěř ORÁKLU elektrickou síť.', type: 'flag', flag: 'orakl_sit' },
  { id: 'vrana', text: 'Zbav se Barona Vrány.', type: 'flag', flag: 'vrana_konec' },
  { id: 'raketa', text: 'Vypusť první raketu od Velkého výpadku.', type: 'flag', flag: 'raketa', era: 2 },
];

/// Éry světa – svět se mění s časem a se splněnými úkoly.
export const ERAS = [
  { n: 1, name: 'Obnova' },
  { n: 2, name: 'Rozmach', total: 60 },
  { n: 3, name: 'Nové hranice', total: 150, seals: 2 },
];

/// Tajné konce – nejsou to katastrofy, ale legendy.
export const SPECIAL = {
  kontakt: { title: 'Ke hvězdám', icon: '🛸',
    text: 'Vstoupil{a} jsi do světla jako první člověk, který opustil Zemi s návštěvníky z hvězd. Republika vytesala tvé jméno do kamene. Nikdo neví, jestli se někdy vrátíš.' },
  podzemi: { title: 'Vládce podzemí', icon: '👑',
    text: 'Usedl{a} jsi na trůn v hlubinách a lidé z bunkru tě přijali za svého panovníka. Nahoře po tobě zůstalo prázdné křeslo a legenda o tom, jak {ty} sestoupil{a} pod zem.' },
  pravda: { title: 'Rada národů', icon: '🌍',
    text: 'Odhalil{a} jsi pravdu o Velkém výpadku a svět tě zvolil do čela Rady národů. Republiku jsi opustil{a} jako hrdina – a poprvé po desetiletích lidé věřili, že budoucnost bude lepší.' },
};

/// Výhody: po splněném úkolu si vůdce vybere jednu ze tří (platí do konce jeho vlády).
export const PERKS = {
  tlumic: { name: 'Tlumič', text: 'Všechny změny ukazatelů jsou o pětinu menší.' },
  brzda: { name: 'Brzda', text: 'Žádný ukazatel se jedním rozhodnutím nepohne o víc než 12 bodů.' },
  nahled: { name: 'Zvědové', text: 'Vidíš, které ukazatele ovlivní další karta.' },
  smer: { name: 'Čtení lidí', text: 'Při tažení vidíš, kterým směrem se ukazatele pohnou.' },
  sance: { name: 'Druhá šance', text: 'Jednou tě ukazatel na kraji nesesadí – odrazí se na 15, nebo 85 %.' },
  sarm: { name: 'Šarm', text: 'Vztahy s lidmi se zlepšují dvakrát rychleji.' },
  nabiti: { name: 'Rychlé nabíjení', text: 'Tvoje schopnost se nabíjí dvakrát rychleji.' },
  stabilita: { name: 'Stabilita', text: 'Každý rok se všechny ukazatele posunou o 3 body k rovnováze.' },
};

/// Prohrané volby – konec vlády, který nezpůsobil žádný ukazatel na kraji.
export const ELECTION = {
  title: 'Prohrané volby',
  text: 'Lidé šli k urnám a rozhodli. Získal{a} jsi jen {v} % hlasů. Předal{a} jsi klíče od paláce a poprvé po letech jsi šel{a} domů pěšky.',
};

/// Víceměsíční krize: karty jdou po sobě (ob jeden měsíc). Volby s ok: 1 krizi zvládají.
/// Kdo zvládne aspoň `good` kroků, dostane odměnu, jinak přijde trest.
export const CRISES = {
  epidemie: { name: 'Epidemie', steps: ['epi1', 'epi2', 'epi3'], good: 2,
    win: { text: 'nákaza je zažehnána a lidé ti věří víc než dřív.', e: { lid: 10, ved: 5 } },
    lose: { text: 'nákaza si vybrala krutou daň. Země truchlí.', e: { lid: -12, fin: -8 } } },
  povoden: { name: 'Povodeň', steps: ['vod1', 'vod2', 'vod3'], good: 2,
    win: { text: 'republika vodu přestála a nový přístav je pýchou země.', e: { lid: 5, fin: 5, pri: 5 } },
    lose: { text: 'voda po sobě nechala bídu a hněv.', e: { fin: -10, lid: -10 } } },
  sit: { name: 'Útok na síť', steps: ['sit1', 'sit2', 'sit3'], good: 2,
    win: { text: 'útok jsi ustál{a} a síť je odolnější než kdy dřív.', e: { ved: 5, dip: 5, lid: 5 } },
    lose: { text: 'země byla měsíce bez proudu. Lidé vzpomínají na Velký výpadek.', e: { fin: -10, lid: -8, ved: -5 } } },
};

const crisisCards = [
  { id: 'epi1', who: 'lek', crisis: 'epidemie', weight: 0.7, text: 'Na jihu se šíří neznámá horečka, {osl}. Za pár týdnů může být všude. Začíná krize.',
    opts: {
      left: { t: 'Hlavně nepanikařit', e: { lid: -5, fin: 5 } },
      right: { t: 'Uzavřít oblast', e: { fin: -10, lid: -5, sil: 5 }, ok: 1 },
      up: { t: 'Vědci, najděte lék', e: { ved: 10, fin: -10 }, ok: 1 },
      down: { t: 'Modlit se', e: { vir: 10, lid: -5 } },
    } },
  { id: 'epi2', who: 'lek', crisis: 'epidemie', weight: 0, text: 'Nemocnice jsou plné. Lékaři padají únavou a lidé se bojí vycházet z domu.',
    opts: {
      left: { t: 'Povolat armádu', e: { sil: 5, lid: -5, fin: -5 }, ok: 1 },
      right: { t: 'Polní nemocnice', e: { fin: -10, lid: 10 }, ok: 1 },
      up: { t: 'Kostely jako útočiště', e: { vir: 10, lid: -5 } },
      down: { t: 'Zamlčet čísla', e: { lid: -10, vir: 5 } },
    } },
  { id: 'epi3', who: 'ved', crisis: 'epidemie', weight: 0, text: 'Máme vakcínu, {osl}! Jenže zatím jen pro polovinu země. Kdo ji dostane první?',
    opts: {
      left: { t: 'Děti a staří', e: { lid: 10, fin: -5 }, ok: 1 },
      right: { t: 'Kdo zaplatí', e: { fin: 15, lid: -15 } },
      up: { t: 'Lékaři a vojáci', e: { sil: 10, lid: -5 }, ok: 1 },
      down: { t: 'Losovat', e: { lid: -5, vir: 5 } },
    } },
  { id: 'vod1', who: 'starosta', crisis: 'povoden', weight: 0.7, text: 'Prší už třetí týden, {osl}. Řeka u přístavu stoupá a staré hráze nevydrží. Začíná krize.',
    opts: {
      left: { t: 'Hráze vydrží', e: { fin: 5, lid: -5 } },
      right: { t: 'Evakuovat přístav', e: { lid: 5, fin: -10 }, ok: 1 },
      up: { t: 'Stavět nové hráze', e: { fin: -10, pri: -5, sil: 5 }, ok: 1 },
      down: { t: 'Nechat to přírodě', e: { pri: 10, lid: -10 } },
    } },
  { id: 'vod2', who: 'far', crisis: 'povoden', weight: 0, text: 'Voda vzala pole i úrodu. Bez pomoci budou lidé v zimě hladovět.',
    opts: {
      left: { t: 'Otevřít státní sklady', e: { lid: 10, fin: -10 }, ok: 1 },
      right: { t: 'Dovézt obilí', e: { dip: 5, fin: -10 }, ok: 1 },
      up: { t: 'Ať si poradí sami', e: { fin: 5, lid: -10 } },
      down: { t: 'Vybrat sbírku v kostelích', e: { vir: 5, lid: -5 } },
    } },
  { id: 'vod3', who: 'starosta', crisis: 'povoden', weight: 0, text: 'Voda opadla. Přístav je v troskách. Postavíme ho znovu stejně, nebo jinak?',
    opts: {
      left: { t: 'Stejně jako dřív', e: { fin: -5 } },
      right: { t: 'Přesunout město výš', e: { fin: -15, lid: 5, pri: 5 }, ok: 1 },
      up: { t: 'Vrátit řece luhy', e: { pri: 15, fin: -10 }, ok: 1 },
      down: { t: 'Nechat ruiny', e: { lid: -10, fin: 5 } },
    } },
  { id: 'sit1', who: 'nula', crisis: 'sit', weight: 0.7, text: 'Někdo napadl elektrickou síť, {osl}. Polovina země je bez proudu. Začíná krize.',
    opts: {
      left: { t: 'Hledat viníka', e: { sil: 5, ved: -5 } },
      right: { t: 'Záložní zdroje', e: { fin: -10, ved: 5 }, ok: 1 },
      up: { t: 'Najmout hackery', e: { ved: 10, vir: -5 }, ok: 1 },
      down: { t: 'Vyhlásit stav nouze', e: { sil: 10, lid: -10 } },
    } },
  { id: 'sit2', who: 'stin', crisis: 'sit', weight: 0, text: 'Stopy útoku vedou za hranice. Nejspíš Federace – jenže důkazy nemáme.',
    opts: {
      left: { t: 'Veřejně je obvinit', e: { dip: -15, sil: 5 } },
      right: { t: 'Tiše vyjednávat', e: { dip: 5, fin: -5 }, ok: 1 },
      up: { t: 'Odvetný útok', e: { sil: 10, dip: -10 } },
      down: { t: 'Posílit obranu sítě', e: { ved: 5, fin: -10 }, ok: 1 },
    } },
  { id: 'sit3', who: 'ved', crisis: 'sit', weight: 0, text: 'Síť znovu běží. Můžeme ji postavit odolnější – ale něco to bude stát.',
    opts: {
      left: { t: 'Je dobrá, jak je', e: { fin: 5 } },
      right: { t: 'Místní solární sítě', e: { pri: 10, fin: -10 }, ok: 1 },
      up: { t: 'Svěřit ji ORÁKLU', e: { ved: 10, vir: -10 }, ok: 1 },
      down: { t: 'Ať ji hlídá armáda', e: { sil: 10, lid: -5 } },
    } },
];

/// Všední starosti republiky – další karty pro pestřejší hru.
const everyday = [
  { id: 'soud1', who: 'soud', text: 'Ústavní soud přezkoumává tvé poslední nařízení, {osl}. Když ho zruší, budeš vypadat slabě.',
    opts: {
      left: { t: 'Respektovat soud', e: { lid: 5, sil: -5 } },
      right: { t: 'Vyměnit soudce', e: { sil: 10, lid: -10, dip: -5 } },
      up: { t: 'Požádat o odklad', e: { fin: -5, vir: 5 } },
      down: { t: 'Nařízení stáhnout', e: { lid: -5, dip: 5 } },
    } },
  { id: 'soud2', who: 'soud', text: 'Bývalý ministr je obviněn z korupce. Je to tvůj starý přítel a prosí o pomoc.',
    opts: {
      left: { t: 'Ať rozhodne soud', e: { lid: 10, vir: -5 } },
      right: { t: 'Udělit milost', e: { lid: -15, fin: 5 } },
      up: { t: 'Urychlit proces', e: { lid: 5, dip: 5, fin: -5 } },
      down: { t: 'Tajně ho varovat', e: { sil: -5, fin: 10 } },
    } },
  { id: 'stud1', who: 'stud', text: 'Studenti obsadili univerzitu. Chtějí, aby vláda konečně brala vážně změny klimatu.',
    opts: {
      left: { t: 'Vyklidit budovu', e: { sil: 5, lid: -10, ved: -5 } },
      right: { t: 'Pozvat je k jednání', e: { lid: 5, pri: 5, fin: -5 } },
      up: { t: 'Místo ve vládě', e: { lid: 10, sil: -5, vir: -5 } },
      down: { t: 'Nevšímat si jich', e: { lid: -5, ved: -5, fin: 5 } },
    } },
  { id: 'stud2', who: 'stud', text: 'Chci studovat v zahraničí, ale stipendia jste zrušili. Mladí odcházejí a už se nevracejí.',
    opts: {
      left: { t: 'Obnovit stipendia', e: { ved: 10, fin: -10 } },
      right: { t: 'Zakázat odchod', e: { lid: -15, sil: 5 } },
      up: { t: 'Výměnné pobyty', e: { dip: 10, ved: 5, fin: -5 } },
      down: { t: 'Ať si jdou', e: { ved: -10, fin: 5 } },
    } },
  { id: 'sport1', who: 'sport', text: 'Náš tým postoupil na mistrovství světa! Potřebujeme peníze na cestu i trénink.',
    opts: {
      left: { t: 'Ani korunu', e: { lid: -10, fin: 5 } },
      right: { t: 'Zaplatit všechno', e: { lid: 10, fin: -10 } },
      up: { t: 'Najít sponzora', e: { fin: 5, lid: 5, vir: -5 } },
      down: { t: 'Uspořádat ho doma', e: { dip: 10, fin: -15, lid: 5 } },
    } },
  { id: 'sport2', who: 'sport', text: 'Hráči odmítají nastoupit proti týmu Federace. Prý kvůli politice.',
    opts: {
      left: { t: 'Musí hrát', e: { dip: 5, lid: -5 } },
      right: { t: 'Podpořit bojkot', e: { dip: -10, lid: 5, sil: 5 } },
      up: { t: 'Zápas za mír', e: { dip: 10, vir: 5, sil: -5 } },
      down: { t: 'Rozpustit tým', e: { lid: -10, fin: 5 } },
    } },
  { id: 'film', who: 'med', text: 'Natočila jsem film o tvé vládě, {osl}. Moc lichotivý není. Premiéra je zítra.',
    opts: {
      left: { t: 'Zakázat premiéru', e: { lid: -10, vir: 5, sil: 5 } },
      right: { t: 'Přijít na premiéru', e: { lid: 10, sil: -5 } },
      up: { t: 'Natočit vlastní film', e: { fin: -10, vir: 10 } },
      down: { t: 'Koupit práva', e: { fin: -15, sil: 5 } },
    } },
  { id: 'kobylky', who: 'far', text: 'Kobylky! Mračna hmyzu se valí přes jižní pole a žerou všechno zelené.',
    opts: {
      left: { t: 'Postřik z letadel', e: { pri: -15, fin: -5 } },
      right: { t: 'Počkat, až odletí', e: { fin: -10, lid: -5 } },
      up: { t: 'Přírodní nepřátelé', e: { ved: 5, pri: 5, fin: -10 } },
      down: { t: 'Jíst je (bílkoviny!)', e: { lid: -5, vir: -5, fin: 5 } },
    } },
  { id: 'zazrak', who: 'kaz', text: 'V kapli prý pláče socha. Poutníci proudí ze všech koutů republiky.',
    opts: {
      left: { t: 'Je to zázrak!', e: { vir: 15, ved: -10 } },
      right: { t: 'Poslat vědce', e: { ved: 10, vir: -10 } },
      up: { t: 'Vybírat vstupné', e: { fin: 10, vir: -5, lid: -5 } },
      down: { t: 'Nechat lidi věřit', e: { vir: 5, lid: 5 } },
    } },
  { id: 'datacentrum', who: 'fed', text: 'Federace u vás chce postavit obří datové centrum. Zaplatí dobře – ale bude chtít přístup k vaší síti.',
    opts: {
      left: { t: 'Odmítnout', e: { dip: -10, ved: 5 } },
      right: { t: 'Přijmout', e: { fin: 15, sil: -10 } },
      up: { t: 'Jen pod naší kontrolou', e: { fin: 5, ved: 5, dip: -5 } },
      down: { t: 'Postavit vlastní', e: { ved: 10, fin: -15 } },
    } },
  { id: 'kral', who: 'vel', text: 'Přijede sousední král a čeká velkolepé přivítání. Jeho přízeň se hodí.',
    opts: {
      left: { t: 'Skromná večeře', e: { fin: 5, dip: -10 } },
      right: { t: 'Vojenská přehlídka', e: { sil: 10, dip: 5, fin: -10 } },
      up: { t: 'Lidová slavnost', e: { lid: 10, dip: 5, fin: -10 } },
      down: { t: 'Nechat ho čekat', e: { dip: -15, vir: 5 } },
    } },
  { id: 'algoritmus', who: 'ork', text: 'Spočítal jsem, že rozpočet by řídil algoritmus o 31 % lépe. Smím ho převzít?',
    opts: {
      left: { t: 'Nikdy', e: { ved: -5, vir: 5 } },
      right: { t: 'Jen rozpočet', e: { fin: 10, lid: -5, ved: 5 } },
      up: { t: 'Zkušební měsíc', e: { ved: 10, vir: -5, fin: -5 } },
      down: { t: 'Vypnout ORÁKL', e: { ved: -15, vir: 10 } },
    } },
  { id: 'dopis', who: 'dite', text: 'Holčička ti přinesla dopis: „Proč je v naší ulici pořád tma a nikdo neuklízí?“',
    opts: {
      left: { t: 'Opravit čtvrť', e: { lid: 10, fin: -10 } },
      right: { t: 'Poslat dobrovolníky', e: { lid: 5, vir: 5, fin: -5 } },
      up: { t: 'Pozvat ji do paláce', e: { lid: 5, dip: 5, fin: -5 } },
      down: { t: 'Neodpovídat', e: { lid: -10 } },
    } },
  { id: 'vrak', who: 'starosta', text: 'Rybáři našli na dně moře vrak plný beden ze starého světa.',
    opts: {
      left: { t: 'Prozkoumat ho', e: { ved: 10, fin: -5 } },
      right: { t: 'Prodat obsah', e: { fin: 10, ved: -5 } },
      up: { t: 'Otevřít muzeum', e: { vir: 5, lid: 5, fin: -5 } },
      down: { t: 'Nechat ho na dně', e: { pri: 5, ved: -5 } },
    } },
  { id: 'dron', who: 'gen', text: 'Na hranici zmizel náš průzkumný dron. Federace tvrdí, že ho sestřelila.',
    opts: {
      left: { t: 'Omluvit se', e: { dip: 10, sil: -10 } },
      right: { t: 'Žádat náhradu', e: { dip: -5, fin: 5 } },
      up: { t: 'Vyslat další', e: { sil: 10, dip: -10, ved: 5 } },
      down: { t: 'Mlčet', e: { sil: -5, lid: -5 } },
    } },
  { id: 'mraz', who: 'upr', text: 'Zima je krutá a tábor uprchlíků mrzne. Potřebujeme stany, deky a teplé jídlo.',
    opts: {
      left: { t: 'Otevřít školy', e: { lid: -5, dip: 10 } },
      right: { t: 'Deky od armády', e: { sil: -5, dip: 5, fin: -5 } },
      up: { t: 'Ubytovat v rodinách', e: { lid: -10, vir: 10, dip: 5 } },
      down: { t: 'Tábor zavřít', e: { dip: -15, sil: 5 } },
    } },
];

const lawCard = (id, who, text, law, opts) => ({ id, who, text, not: [`zakon_${law}`], opts: { ...opts, right: { t: 'Uzákonit', ...opts.right, law } } });

const repealCards = Object.entries(LAWS).map(([id, l]) => ({
  id: `zrus_${id}`, who: 'tajemnik', req: [`zakon_${id}`], weight: 0.5,
  text: `Lidé podepsali petici za zrušení zákona „${l.name}“. Prý už splnil, co měl – nebo naopak nikdy.`,
  opts: {
    left: { t: 'Zákon zůstane', e: { lid: -5, vir: 5 } },
    right: { t: 'Zrušit ho', e: { lid: 5, vir: -5 }, repeal: id },
    up: { t: 'Vypsat referendum', e: { lid: 5, fin: -5 }, repeal: id },
    down: { t: 'Petici skartovat', e: { lid: -10, sil: 5 } },
  },
}));

export const EXTRA = [
  ...crisisCards,
  ...everyday,
  // ── Návrhy zákonů ────────────────────────────────────
  lawCard('zakon_dan', 'fin', 'Navrhuji trvalou daň z bohatství, {osl}. Peníze by tekly každý měsíc – jen boháči budou zuřit.', 'dan_bohati', {
    left: { t: 'Bohaté nechte být', e: { fin: -5, dip: 5 } },
    right: { e: { fin: 5, lid: 5 } },
    up: { t: 'Jednorázová sbírka', e: { fin: 10, dip: -5 } },
    down: { t: 'Zdaňte Vránu', e: { fin: 10, lid: 5, dip: -5 }, rel: { vrana: -2 } },
  }),
  lawCard('zakon_brannost', 'gen', 'Armáda nemá dost vojáků. Chci zákon o branné povinnosti pro všechny mladé.', 'brannost', {
    left: { t: 'Nikdy', e: { sil: -5, lid: 5 } },
    right: { e: { sil: 5, lid: -5 } },
    up: { t: 'Jen dobrovolníci', e: { sil: 5, fin: -5 } },
    down: { t: 'Žoldnéři z ciziny', e: { sil: 10, fin: -10, dip: -5 } },
  }),
  lawCard('zakon_lesy', 'eko', 'Lesy mizí rychleji, než rostou. Potřebujeme zákon, který je ochrání navždy.', 'ochrana_lesu', {
    left: { t: 'Dřevo potřebujeme', e: { pri: -5, fin: 5 } },
    right: { e: { pri: 5, fin: -5 } },
    up: { t: 'Vysaďte nové', e: { pri: 10, fin: -10 } },
    down: { t: 'Les patří lidem', e: { pri: -5, lid: 5 } },
  }),
  lawCard('zakon_cirkev', 'kaz', 'Udělejte z víry státní církev, {osl}. Národ potřebuje společnou duši.', 'statni_cirkev', {
    left: { t: 'Stát je světský', e: { vir: -5, ved: 5 } },
    right: { e: { vir: 5, lid: -5 } },
    up: { t: 'Svoboda vyznání', e: { vir: 5, sil: -5 } },
    down: { t: 'Zdaňte kostely', e: { fin: 10, vir: -10 } },
  }),
  lawCard('zakon_hranice', 'vel', 'Otevřete hranice. Obchod, lidé i nápady budou proudit volně.', 'otevrene_hranice', {
    left: { t: 'Hranice zavřít', e: { dip: -10, sil: 5 } },
    right: { e: { dip: 5, fin: 5 } },
    up: { t: 'Jen pro obchod', e: { dip: 5, fin: 5, lid: -5 } },
    down: { t: 'Jen pro uprchlíky', e: { dip: 5, lid: -5, vir: 5 } },
  }),
  lawCard('zakon_roboti', 'ved', 'Roboti by mohli převzít práci v továrnách natrvalo. Chce to jen zákon.', 'robotizace', {
    left: { t: 'Práce patří lidem', e: { lid: 5, ved: -5 } },
    right: { e: { ved: 5, fin: 5 } },
    up: { t: 'Jen v dolech', e: { ved: 5, lid: 5, fin: -5 } },
    down: { t: 'Zakázat roboty', e: { ved: -10, lid: 5 } },
  }),
  lawCard('zakon_prijem', 'odb', 'Každý občan by měl dostávat základní příjem. Natrvalo a bez podmínek.', 'zakladni_prijem', {
    left: { t: 'Nemáme na to', e: { lid: -5, fin: 5 } },
    right: { e: { lid: 5, fin: -5 } },
    up: { t: 'Jen pro nejchudší', e: { lid: 5, fin: -10 } },
    down: { t: 'Místo peněz práce', e: { lid: 5, pri: -5, fin: -5 } },
  }),
  lawCard('zakon_cenzura', 'stin', 'Noviny šíří paniku. Dejte mi zákon a já je zkrotím.', 'cenzura', {
    left: { t: 'Svoboda slova', e: { sil: -5, lid: 5 } },
    right: { e: { sil: 5, ved: -5 } },
    up: { t: 'Jen v době krize', e: { sil: 5, lid: -5 } },
    down: { t: 'Zakažte jen lži', e: { ved: 5, sil: -5, vir: 5 } },
  }),
  lawCard('zakon_trh', 'vrana', 'Zrušte všechny regulace. Volný trh vyřeší všechno – a já vám rád pomůžu.', 'volny_trh', {
    left: { t: 'Trh potřebuje pravidla', e: { fin: -5, pri: 5 } },
    right: { e: { fin: 5, lid: -5 } },
    up: { t: 'Jen pro malé firmy', e: { fin: 5, lid: 5, dip: -5 } },
    down: { t: 'Vyveďte ho', e: { fin: -5, lid: 5, dip: -5 }, rel: { vrana: -2 } },
  }),
  lawCard('zakon_skoly', 'nula', 'Univerzity by měly být zdarma. Pro každého a navždy. Chytré hlavy jsou jediné bohatství, co nám zbylo.', 'skolstvi', {
    left: { t: 'Kdo chce, ať platí', e: { ved: -5, fin: 5 } },
    right: { e: { ved: 5, lid: 5 } },
    up: { t: 'Stipendia pro nadané', e: { ved: 5, fin: -5 } },
    down: { t: 'Řemesla místo škol', e: { ved: -5, lid: 5, pri: 5 } },
  }),
  ...repealCards,

  // ── Postavy si pamatují ──────────────────────────────
  { id: 'gen_zla', who: 'gen', rel: ['gen', -REL_LOYAL], text: 'Armáda vám přestává věřit, {osl}. Někteří důstojníci si šeptají o „jiném řešení“.',
    opts: {
      left: { t: 'Vyhoďte je', e: { sil: -10, lid: 5 }, rel: { gen: -1 } },
      right: { t: 'Přidám armádě peníze', e: { sil: 10, fin: -10 }, rel: { gen: 3 } },
      up: { t: 'Promluvím s nimi', e: { sil: 5, lid: -5 }, rel: { gen: 2 },
        need: { m: 'vir', min: 60 }, alt: { t: 'Promluvím s nimi', e: { sil: 5, lid: -5 }, rel: { gen: 2 } } },
      down: { t: 'Ať je Stín sleduje', e: { sil: -5, vir: -5 }, rel: { stin: 2, gen: -1 } },
    } },
  { id: 'gen_verna', who: 'gen', rel: ['gen', REL_LOYAL], text: 'Ať se stane cokoli, {osl}, armáda stojí za vámi. Stačí říct.',
    opts: {
      left: { t: 'Snad nebude třeba', e: { sil: -5, lid: 5 } },
      right: { t: 'Pošlete vojáky na stavby', e: { sil: -5, fin: 10, lid: 5 } },
      up: { t: 'Pomozte při povodních', e: { pri: 5, lid: 5, sil: -5 } },
      down: { t: 'Hlídejte hranice', e: { sil: 5, dip: -5 } },
    } },
  { id: 'fin_zly', who: 'fin', rel: ['fin', -REL_LOYAL], text: 'Už nemám sílu hasit vaše výdaje, {osl}. Zvažuji rezignaci.',
    opts: {
      left: { t: 'Tak jděte', e: { fin: -10, lid: 5 } },
      right: { t: 'Škrtejte, co chcete', e: { fin: 10, lid: -10 }, rel: { fin: 3 } },
      up: { t: 'Zvýším vám plat', e: { fin: -5, lid: -5 }, rel: { fin: 2 } },
      down: { t: 'Najdu lepšího', e: { fin: -5, ved: 5 } },
    } },
  { id: 'fin_verny', who: 'fin', rel: ['fin', REL_LOYAL], text: 'Našel jsem skryté rezervy po starém režimu. Patří vám, {osl}. Co s nimi?',
    opts: {
      left: { t: 'Do státní pokladny', e: { fin: 15 } },
      right: { t: 'Rozdejte je lidem', e: { lid: 5, fin: 5 } },
      up: { t: 'Na výzkum', e: { ved: 10, fin: 5 } },
      down: { t: 'Na obnovu krajiny', e: { pri: 5, fin: 5 } },
    } },
  { id: 'ved_zla', who: 'ved', rel: ['ved', -REL_LOYAL], text: 'Vědci odcházejí do Federace. Říkají, že tady jejich práci nikdo neváží.',
    opts: {
      left: { t: 'Ať jdou', e: { ved: -15, fin: 5 } },
      right: { t: 'Granty pro všechny', e: { ved: 10, fin: -10 }, rel: { ved: 3 } },
      up: { t: 'Nová laboratoř', e: { ved: 5, fin: -5 }, rel: { ved: 2 } },
      down: { t: 'Zakažte jim odjezd', e: { ved: -5, sil: 5, dip: -5 } },
    } },
  { id: 'ved_verna', who: 'ved', rel: ['ved', REL_LOYAL], text: 'Pro vás jsme pracovali i po nocích, {osl}. Máme průlom – levnou energii ze slunce.',
    opts: {
      left: { t: 'Utajte to', e: { sil: 5, ved: -5 } },
      right: { t: 'Pro celou zemi', e: { ved: 10, pri: 5, fin: -5 } },
      up: { t: 'Prodejte patent', e: { fin: 10, dip: 5 } },
      down: { t: 'Darujte to světu', e: { dip: 10, ved: 5, fin: -5 } },
    } },
  { id: 'kaz_zly', who: 'kaz', rel: ['kaz', -REL_LOYAL], text: 'Ve svých kázáních říkám to, co si lidé myslí: vaše vláda je trestem za hříchy národa.',
    opts: {
      left: { t: 'Ať si mluví', e: { vir: -5, lid: -5 } },
      right: { t: 'Daruji kostelu zvon', e: { vir: 10, fin: -5 }, rel: { kaz: 3 } },
      up: { t: 'Pozvu ho na čaj', e: { vir: 5, lid: 5 }, rel: { kaz: 2 } },
      down: { t: 'Zakažte mu kázat', e: { vir: -10, sil: 5 } },
    } },
  { id: 'kaz_verny', who: 'kaz', rel: ['kaz', REL_LOYAL], text: 'Za vaši vládu se modlí celé kláštery, {osl}. Lidé říkají, že vás vede prozřetelnost.',
    opts: {
      left: { t: 'Žádná prozřetelnost', e: { vir: -5, lid: 5 } },
      right: { t: 'Děkuji za modlitby', e: { vir: 10 } },
      up: { t: 'Pomozte chudým', e: { lid: 10, vir: 5, fin: -5 } },
      down: { t: 'Ať kážou o práci', e: { fin: 5, vir: 5 } },
    } },
  { id: 'odb_zly', who: 'odb', rel: ['odb', -REL_LOYAL], text: 'Vyhlásili jsme generální stávku. Celá země stojí, dokud nás nezačnete poslouchat.',
    opts: {
      left: { t: 'Rozežeňte je', e: { lid: -10, sil: 5 } },
      right: { t: 'Vyhovím všem', e: { lid: 10, fin: -15 }, rel: { odb: 3 } },
      up: { t: 'Sednu si k jednání', e: { lid: 5, fin: -5 }, rel: { odb: 2 },
        need: { m: 'lid', min: 60 }, alt: { t: 'Sednu si k jednání', e: { lid: 5, fin: -5 }, rel: { odb: 2 } } },
      down: { t: 'Najmu stávkokaze', e: { fin: -5, lid: -10 } },
    } },
  { id: 'odb_verny', who: 'odb', rel: ['odb', REL_LOYAL], text: 'Dělníci vám věří, {osl}. Nabízejí, že o víkendech opraví mosty zadarmo.',
    opts: {
      left: { t: 'To nemohu přijmout', e: { lid: -5, vir: 5 } },
      right: { t: 'S díky přijímám', e: { fin: 10 } },
      up: { t: 'Ať opraví nemocnici', e: { lid: 5, fin: 5 } },
      down: { t: 'Ať vysadí stromy', e: { pri: 5, lid: 5 } },
    } },
  { id: 'vel_zly', who: 'vel', rel: ['vel', -REL_LOYAL], text: 'Odjíždím, {osl}. Cítím se tu ponížený a moje vláda „přehodnocuje vztahy“.',
    opts: {
      left: { t: 'Šťastnou cestu', e: { dip: -15 } },
      right: { t: 'Omluvím se', e: { dip: 10, vir: -5 }, rel: { vel: 3 } },
      up: { t: 'Slavnostní večeře', e: { dip: 5, fin: -5 }, rel: { vel: 2 } },
      down: { t: 'Vyhostíme i ostatní', e: { dip: -10, sil: 5, lid: 5 } },
    } },
  { id: 'vel_verny', who: 'vel', rel: ['vel', REL_LOYAL], text: 'Jste přítel, {osl}. Mohu vám zařídit obchodní smlouvu s půlkou kontinentu.',
    opts: {
      left: { t: 'Nechci být dlužník', e: { dip: -5, vir: 5 } },
      right: { t: 'Zařiďte to', e: { dip: 10, fin: 10 } },
      up: { t: 'Raději výměnu studentů', e: { dip: 5, ved: 5 } },
      down: { t: 'Raději lékaře', e: { dip: 5, lid: 5 } },
    } },
  { id: 'eko_zla', who: 'eko', rel: ['eko', -REL_LOYAL], text: 'Moji lidé obsadili těžební stroje. Neodejdeme, dokud těžba nepřestane.',
    opts: {
      left: { t: 'Ať je policie odnese', e: { pri: -5, sil: 5, lid: -5 } },
      right: { t: 'Zastavte těžbu', e: { pri: 10, fin: -10 }, rel: { eko: 3 } },
      up: { t: 'Vyjednávejte', e: { pri: 5, fin: -5 }, rel: { eko: 2 } },
      down: { t: 'Těžte jinde', e: { pri: -5, fin: 5, dip: -5 } },
    } },
  { id: 'eko_verna', who: 'eko', rel: ['eko', REL_LOYAL], text: 'Díky vám se do řek vrátili bobři a čistá voda. Lidé chtějí národní park.',
    opts: {
      left: { t: 'Na to nemáme', e: { pri: -5, fin: 5 } },
      right: { t: 'Vyhlašte ho', e: { pri: 10, fin: -5 } },
      up: { t: 'S turistickými stezkami', e: { pri: -5, fin: 10 } },
      down: { t: 'Pro vědecký výzkum', e: { pri: 5, ved: 5 } },
    } },
  { id: 'vrana_zly', who: 'vrana', rel: ['vrana', -REL_LOYAL], text: 'Moje noviny o vás teď píšou každý den, {osl}. A nebude to nic hezkého.',
    opts: {
      left: { t: 'Ignorovat', e: { lid: -10 } },
      right: { t: 'Usmířím se s ním', e: { fin: 5, lid: -5 }, rel: { vrana: 3 } },
      up: { t: 'Zažaluji ho', e: { lid: 5, fin: -5 } },
      down: { t: 'Zabavte mu majetek', e: { fin: 15, dip: -10 }, set: 'vrana_konec', rel: { vrana: -2 } },
    } },
  { id: 'vrana_verny', who: 'vrana', rel: ['vrana', REL_LOYAL], text: 'Posílám vám malý dárek, {osl}. Kufr plný peněz. Nic za to nechci. Zatím.',
    opts: {
      left: { t: 'Vraťte to', e: { fin: -5, vir: 5 }, rel: { vrana: -2 } },
      right: { t: 'Do pokladny', e: { fin: 15, vir: -5, lid: -5 } },
      up: { t: 'Pro sirotčince', e: { lid: 10, fin: 5, vir: -5 } },
      down: { t: 'Předejte to policii', e: { sil: 5, lid: 5 }, rel: { vrana: -3 } },
    } },

  // ── Éry ──────────────────────────────────────────────
  { id: 'era2', who: 'tajemnik', weight: 0, once: true,
    text: 'Ulice se znovu rozsvítily, továrny jedou a lidé plánují budoucnost. Začíná éra Rozmachu, {osl}. Přijdou nové příležitosti – i nové hrozby.',
    opts: {
      left: { t: 'Opatrně', e: { sil: 5 } },
      right: { t: 'Konečně!', e: { lid: 5 } },
      up: { t: 'Investujme do vědy', e: { ved: 5 } },
      down: { t: 'Myslete na přírodu', e: { pri: 5 } },
    } },
  { id: 'era3', who: 'tajemnik', weight: 0, once: true,
    text: 'Republika se změnila k nepoznání. Mluví se o letech ke hvězdám, o strojích, které myslí, a o tom, co se doopravdy stalo při Velkém výpadku. Začíná éra Nových hranic.',
    opts: {
      left: { t: 'Ke hvězdám', e: { ved: 5 } },
      right: { t: 'Ať lidé žijí v míru', e: { lid: 5 } },
      up: { t: 'Chci znát pravdu', e: { vir: 5 }, next: 'pravda1', in: 3 },
      down: { t: 'Posilme hranice', e: { sil: 5 } },
    } },

  // ── Éra Rozmachu ─────────────────────────────────────
  { id: 'vesmir1', who: 'ved', era: 2, not: ['raketa'], text: 'Máme plány na první raketu od Velkého výpadku. Chcete, aby republika znovu dobyla vesmír?',
    opts: {
      left: { t: 'Máme jiné starosti', e: { ved: -5, lid: 5 } },
      right: { t: 'Startujeme!', e: { ved: 10, fin: -10, vir: 5 }, set: 'raketa', next: 'vesmir2', in: 6 },
      up: { t: 'Se Severní federací', e: { ved: 10, dip: 10, fin: -5 }, set: 'raketa', next: 'vesmir2', in: 6,
        need: { m: 'dip', min: 60 }, alt: { t: 'Půjčíme si rakety', e: { ved: 5, fin: -10, dip: 5 } } },
      down: { t: 'Satelity pro zemědělce', e: { ved: 5, pri: 5, fin: -5 } },
    } },
  { id: 'vesmir2', who: 'ved', weight: 0, req: ['raketa'], text: 'Raketa stojí na rampě. Celá země sleduje odpočítávání. Kdo poletí?',
    opts: {
      left: { t: 'Odložte start', e: { ved: -5, lid: -5 } },
      right: { t: 'Nejlepší pilotka', e: { ved: 10, lid: 10 } },
      up: { t: 'Robot', e: { ved: 10, vir: -10 } },
      down: { t: 'Poletím osobně', e: { lid: 10, sil: -10, vir: 5 } },
    } },
  { id: 'megamesto', who: 'med', era: 2, text: 'Postavme megaměsto ze skla a oceli. Milion lidí pod jednou střechou!',
    opts: {
      left: { t: 'Raději malá města', e: { pri: 5, lid: 5, fin: -5 } },
      right: { t: 'Stavte', e: { fin: 10, pri: -15 } },
      up: { t: 'Se zahradami na střechách', e: { fin: 5, pri: -5, ved: 5 } },
      down: { t: 'Podzemní město', e: { ved: 10, pri: 5, fin: -5 },
        need: { m: 'ved', min: 60 }, alt: { t: 'Satelitní města', e: { fin: -5, pri: -5, lid: 5 } } },
    } },
  { id: 'roboti_prava', who: 'nula', era: 2, text: 'Továrních robotů je tolik, že se začali organizovat. Chtějí práva. Jako lidé.',
    opts: {
      left: { t: 'Jsou to stroje', e: { ved: -5, vir: 5 } },
      right: { t: 'Ať mají práva', e: { ved: 5, lid: -10, vir: -5 } },
      up: { t: 'Ať mají dny volna', e: { ved: 5, fin: -5 } },
      down: { t: 'Přeprogramovat', e: { ved: -10, fin: -5 } },
    } },
  { id: 'valka_sousedu', who: 'fed', era: 2, text: 'Dva vaši sousedé spolu válčí. Federace chce, abyste se přidali na její stranu.',
    opts: {
      left: { t: 'Zůstaneme neutrální', e: { dip: -5, sil: 5 } },
      right: { t: 'Přidáme se', e: { dip: 10, sil: -10, lid: -5 } },
      up: { t: 'Zprostředkujeme mír', e: { dip: 10, vir: 5, fin: -5 },
        need: { m: 'dip', min: 60 }, alt: { t: 'Nabídneme mír', e: { dip: 5, vir: 5, fin: -5 } } },
      down: { t: 'Prodáme zbraně oběma', e: { fin: 15, dip: -10, vir: -5 } },
    } },
  { id: 'maso', who: 'far', era: 2, text: 'Vědci umí vypěstovat maso v laboratoři. My farmáři se bojíme o živobytí.',
    opts: {
      left: { t: 'Zakázat', e: { ved: -5, pri: -5, lid: 5 } },
      right: { t: 'Povolit', e: { ved: 5, pri: 5, lid: -10 } },
      up: { t: 'Jen pro armádu', e: { ved: 5, sil: 5, fin: -5 } },
      down: { t: 'Dotace farmářům', e: { lid: 5, fin: -10, pri: -5 } },
    } },

  // ── Tajný příběh: Signál ─────────────────────────────
  { id: 'signal1', who: 'ork', era: 2, req: ['orakl'], once: true, text: 'Zachytil jsem signál. Nepřichází ze Země. Opakuje se každých sedmnáct minut. Mám odpovědět?',
    opts: {
      left: { t: 'Mlč', e: { ved: -5, sil: 5 } },
      right: { t: 'Odpověz', e: { ved: 5, vir: -5 }, set: 'signal', next: 'signal2', in: 4 },
      up: { t: 'Nejdřív ho rozlušti', e: { ved: 5, fin: -5 }, set: 'signal', next: 'signal2', in: 7 },
      down: { t: 'Řekni to světu', e: { dip: 10, vir: 5, sil: -5 } },
    } },
  { id: 'signal2', who: 'ork', weight: 0, req: ['signal'], text: 'Odpověděli. Jsou na cestě. Ptají se, kdo mluví za lidstvo.',
    opts: {
      left: { t: 'Nikdo', e: { vir: -5, ved: -5 }, unset: 'signal' },
      right: { t: 'Já', e: { vir: 10, dip: -10 }, next: 'signal3', in: 5 },
      up: { t: 'Celá Země spolu', e: { dip: 15, sil: -5 }, next: 'signal3', in: 6 },
      down: { t: 'Připravte armádu', e: { sil: 15, ved: -5 }, next: 'signal3', in: 4 },
    } },
  { id: 'signal3', who: 'tajemnik', weight: 0, req: ['signal'], text: 'Nad hlavním městem visí světlo. Návštěvníci chtějí vzít jednoho člověka s sebou – zástupce lidstva.',
    opts: {
      left: { t: 'Odmítněte je', e: { sil: 5, vir: -10 }, unset: 'signal' },
      right: { t: 'Poletím', e: { vir: 10 }, end: 'kontakt' },
      up: { t: 'Ať letí ORÁKL', e: { ved: -15, vir: 5 }, unset: 'signal' },
      down: { t: 'Ať letí dítě z ulice', e: { lid: 5, vir: 10 }, unset: 'signal' },
    } },

  // ── Tajný příběh: Podzemí (začíná u hřbitova) ────────
  { id: 'podzemi1', who: 'ved', weight: 0, req: ['podzemi'], text: 'Pod hřbitovem jsme našli bunkr z doby před Velkým výpadkem. Je obydlený. Žijí tam lidé, kteří o nás nevědí.',
    opts: {
      left: { t: 'Zazděte vchod', e: { ved: -5, vir: 5 }, unset: 'podzemi' },
      right: { t: 'Navažte kontakt', e: { ved: 10, lid: 5 }, next: 'podzemi2', in: 4 },
      up: { t: 'Pošlete vojáky', e: { sil: 10, lid: -5 }, next: 'podzemi2', in: 4 },
      down: { t: 'Utajte to', e: { sil: 5, vir: -5 }, next: 'podzemi2', in: 8 },
    } },
  { id: 'podzemi2', who: 'pou', weight: 0, req: ['podzemi'], text: 'Jsem z bunkru. Žijeme tam už tři generace. Máme stroje, které vy neumíte postavit. A máme z vás strach.',
    opts: {
      left: { t: 'Vraťte se dolů', e: { ved: -5, lid: 5 }, unset: 'podzemi' },
      right: { t: 'Vítejte mezi námi', e: { ved: 10, lid: -5, vir: 5 }, next: 'podzemi3', in: 5 },
      up: { t: 'Vyměňme si znalosti', e: { ved: 15, fin: -5 }, next: 'podzemi3', in: 5 },
      down: { t: 'Zabavte ty stroje', e: { ved: 10, vir: -10 }, unset: 'podzemi' },
    } },
  { id: 'podzemi3', who: 'pou', weight: 0, req: ['podzemi'], text: 'V nejhlubším patře je trůn a na něm prázdná koruna. Podle našeho zákona patří tomu, kdo k nám první přišel v míru. Tobě.',
    opts: {
      left: { t: 'Odmítám', e: { vir: 5, lid: 5 }, unset: 'podzemi' },
      right: { t: 'Usednu na trůn', e: { vir: 5 }, end: 'podzemi' },
      up: { t: 'Korunu do muzea', e: { vir: -5, ved: 5, lid: 5 }, unset: 'podzemi' },
      down: { t: 'Ať si zvolí vůdce', e: { dip: 5, lid: 5 }, unset: 'podzemi' },
    } },

  // ── Éra Nových hranic ────────────────────────────────
  { id: 'mesic', who: 'ved', era: 3, text: 'Můžeme založit první osadu na Měsíci. Potřebujeme ale celý rozpočet na deset let.',
    opts: {
      left: { t: 'Země má přednost', e: { lid: 5, ved: -5 } },
      right: { t: 'Letíme', e: { ved: 10, fin: -15 } },
      up: { t: 'S celým světem', e: { ved: 10, dip: 10, fin: -5 },
        need: { m: 'dip', min: 60 }, alt: { t: 'Sami a pomalu', e: { ved: 5, fin: -10 } } },
      down: { t: 'Pošleme jen roboty', e: { ved: 5, fin: -5, vir: -5 } },
    } },
  { id: 'stit', who: 'eko', era: 3, text: 'Klima se znovu otepluje. Vědci navrhují zastínit Slunce obřím štítem na oběžné dráze.',
    opts: {
      left: { t: 'Je to šílenství', e: { pri: -5, ved: -5 } },
      right: { t: 'Postavte ho', e: { ved: 5, pri: 5, fin: -15 },
        need: { m: 'ved', min: 60 }, alt: { t: 'Zkusme to', e: { ved: 5, pri: -10, fin: -10 } } },
      up: { t: 'Raději sázet lesy', e: { pri: 10, fin: -5 } },
      down: { t: 'Ať to platí Federace', e: { dip: -10, pri: 5 } },
    } },
  { id: 'ai_volby', who: 'nula', era: 3, text: 'Moje umělá inteligence chce kandidovat ve volbách. Nemá zájmy, ego ani strach. A ústava o strojích nic neříká.',
    opts: {
      left: { t: 'Změňte ústavu', e: { ved: -10, vir: 5 } },
      right: { t: 'Ať kandiduje', e: { ved: 15, lid: -10, vir: -5 } },
      up: { t: 'Ať je mým rádcem', e: { ved: 5, fin: 5 } },
      down: { t: 'Vypněte ji', e: { ved: -15, vir: 10 } },
    } },
  { id: 'nesmrtelnost', who: 'lek', era: 3, text: 'Našli jsme způsob, jak zastavit stárnutí. Je drahý – stačil by pro tisíc lidí.',
    opts: {
      left: { t: 'Zničte vzorec', e: { ved: -10, vir: 5 } },
      right: { t: 'Pro nejlepší mozky', e: { ved: 5, lid: -10 } },
      up: { t: 'Levná verze pro všechny', e: { ved: 5, lid: 10, fin: -10 },
        need: { m: 'ved', min: 60 }, alt: { t: 'Loterie pro všechny', e: { lid: 5, vir: -5, fin: -5 } } },
      down: { t: 'Nejdřív pro mě', e: { lid: -15, vir: -5, fin: 5 } },
    } },
  { id: 'sjednoceni', who: 'fed', era: 3, text: 'Federace navrhuje sjednocení. Jeden stát, jedna měna, jedna vláda. Vy byste získal{a} vysoký úřad.',
    opts: {
      left: { t: 'Nikdy', e: { dip: -10, vir: 5 } },
      right: { t: 'Souhlasím', e: { dip: 15, fin: 10, vir: -10 } },
      up: { t: 'Jen společný trh', e: { dip: 5, fin: 10 } },
      down: { t: 'Referendum', e: { lid: 5, dip: -5, vir: 5 },
        need: { m: 'lid', min: 60 }, alt: { t: 'Referendum', e: { lid: -5, dip: -5, vir: 5 } } },
    } },

  // ── Tajný příběh: Pravda o Velkém výpadku ────────────
  { id: 'pravda1', who: 'stin', era: 3, seals: 2, once: true, not: ['pravda'], text: 'V archivu tajné služby jsem našel složku „Výpadek“. Velký výpadek nebyla nehoda. Chcete vědět, kdo ho způsobil?',
    opts: {
      left: { t: 'Spalte ji', e: { sil: 5, vir: -5 } },
      right: { t: 'Chci to vědět', e: { sil: -5, ved: 5 }, set: 'pravda', next: 'pravda2', in: 3 },
      up: { t: 'Jen pro mé oči', e: { sil: 5, ved: 5 }, set: 'pravda', next: 'pravda2', in: 5 },
      down: { t: 'Zveřejněte ji', e: { lid: 10, sil: -10, dip: -5 }, set: 'pravda', next: 'pravda2', in: 2 },
    } },
  { id: 'pravda2', who: 'fed', weight: 0, req: ['pravda'], text: '„Ta složka je podvrh. A jestli ne – pak jsme to byli my, kdo vypnul svět. Abychom ho mohli poskládat znovu, podle sebe.“',
    opts: {
      left: { t: 'Mlčme o tom', e: { dip: 5, vir: -10 }, unset: 'pravda' },
      right: { t: 'Žádám omluvu', e: { dip: -10, vir: 10 }, next: 'pravda3', in: 4 },
      up: { t: 'Žádám odškodnění', e: { fin: 15, dip: -10 }, next: 'pravda3', in: 4 },
      down: { t: 'Vyhlašuji válku', e: { sil: 10, dip: -20 }, unset: 'pravda' },
    } },
  { id: 'pravda3', who: 'tajemnik', weight: 0, req: ['pravda'], text: 'Celý svět zná pravdu. Národy se scházejí v našem hlavním městě a chtějí nový začátek – bez Federace. Navrhují tě do čela Rady národů.',
    opts: {
      left: { t: 'Zůstanu doma', e: { lid: 5 }, unset: 'pravda' },
      right: { t: 'Přijímám', e: { dip: 10 }, end: 'pravda' },
      up: { t: 'Ať vede někdo nestranný', e: { dip: 10, vir: 5 }, unset: 'pravda' },
      down: { t: 'Rada je zbytečná', e: { dip: -10, sil: 5 }, unset: 'pravda' },
    } },
];
