// Události: roční období, krajní stavy ukazatelů, soupeřící sousední národ a zrádce ve vlastních řadách.
// Postavy '@kraj', '@rada', '@vysetr' a '@zradce' dosadí hra podle doby, proto jsou texty nadčasové.
// 'riv' je vyslanec sousedního národa (jméno dosadí hra podle doby).

const o = ([t, e, more = {}]) => ({ t, e, ...more });
const k = (id, who, text, l, r, u, d, extra = {}) => ({ id, who, text, opts: { left: o(l), right: o(r), up: o(u), down: o(d) }, ...extra });

// ── Roční období ───────────────────────────────────────
export const SEASON_CARDS = [
  // zima
  k('ses_zima_1', '@kraj', 'Sněhová bouře zavála cesty, {osl}. Odlehlé osady jsou odříznuté a docházejí jim zásoby i dřevo.',
    ['Poslat pomoc', { lid: 10, fin: -10 }], ['Ať si poradí', { lid: -5, fin: 10 }], ['Vykácet háj na topení', { lid: 10, pri: -5 }], ['Čekat, až to přejde', { vir: -5, lid: -5 }], { season: 'zima' }),
  k('ses_zima_2', '@rada', 'Zima je dlouhá a lidé se nudí. Po večerech se hádají a mladí se perou. Čím je zaměstnat, {osl}?',
    ['Zimní slavnost', { lid: 10, fin: -5 }], ['Učit se u ohně', { ved: 5, lid: 5 }], ['Výcvik se zbraní', { sil: 5, lid: -5 }], ['Výprava k sousedům', { dip: 5, fin: -5 }], { season: 'zima' }),
  k('ses_zima_3', '@kraj', 'Hladoví vlci a lišky se v mrazu odvažují až k zásobárnám. Lidé chtějí zvěř vybít.',
    ['Vybít je', { pri: -5, fin: 5 }], ['Postavit ohrady', { fin: -5, pri: 5 }], ['Krmit je odpadky', { pri: 5, lid: -5 }], ['Hlídky ve dne v noci', { sil: 5, fin: -5, lid: -5 }], { season: 'zima' }),
  // jaro
  k('ses_jaro_1', '@kraj', 'Jarní povodeň, {osl}! Řeka se vylila z břehů a strhla pole i obydlí u vody.',
    ['Stavět hráze', { fin: -10, lid: 5, pri: -5 }], ['Odejít výš', { lid: -5, pri: 5 }], ['Obětovat řece', { vir: 5, fin: -5 }], ['Požádat sousedy', { dip: 5, fin: 5, sil: -5 }], { season: 'jaro' }),
  k('ses_jaro_2', '@rada', 'Přišlo jaro a je čas setí. Máme zasít víc než loni, i za cenu nových polí v lese?',
    ['Vyklučit les', { fin: 10, pri: -10 }], ['Sít jako vždy', { pri: 5, fin: -5 }], ['Zkusit nové plodiny', { ved: 5, fin: 5, vir: -5 }], ['Požehnat setí', { vir: 5, ved: -5 }], { season: 'jaro' }),
  k('ses_jaro_3', '@kraj', 'Na jaře se rodí mnoho dětí a mladí se chtějí brát. Chybí ale místo, kde by žili.',
    ['Nové osady', { lid: 10, pri: -5, fin: -5 }], ['Velká svatební slavnost', { lid: 5, vir: 5, fin: -10 }], ['Ať se usadí u sousedů', { dip: 10, lid: -5 }], ['Ať počkají', { lid: -10, fin: 5 }], { season: 'jaro' }),
  // léto
  k('ses_leto_1', '@kraj', 'Sucho, {osl}. Měsíc nepršelo, studny vysychají a úroda na polích žloutne.',
    ['Kopat nové studny', { fin: -10, lid: 5, pri: -5 }], ['Šetřit vodou', { lid: -10, pri: 5 }], ['Prosit o déšť', { vir: 10, ved: -5, lid: -5 }], ['Vzít vodu sousedům', { fin: 5, dip: -10 }], { season: 'leto' }),
  k('ses_leto_2', '@rada', 'Blesk zapálil les na kraji země. Požár se šíří a vítr ho žene k osadám.',
    ['Všichni hasit', { lid: -5, pri: 5, fin: -5 }], ['Vypálit pruh země', { ved: 5, pri: -5, sil: -5 }], ['Nechat les hořet', { pri: -15, fin: 5, lid: 5 }], ['Vojáci ať hasí', { sil: -10, pri: 10 }], { season: 'leto' }),
  k('ses_leto_3', '@kraj', 'Léto je teplé a dlouhé. Poutníci a obchodníci táhnou krajem a ptají se, jestli smějí zůstat.',
    ['Přivítat je', { dip: 10, vir: -5 }], ['Vybírat od nich dávky', { fin: 10, dip: -5 }], ['Ať naučí naše lidi', { ved: 5, lid: 5 }], ['Zavřít hranice', { sil: 5, dip: -10 }], { season: 'leto' }),
  // podzim
  k('ses_podzim_1', '@kraj', 'Dožínky, {osl}! Sklizeň se vydařila a lidé chtějí slavit, jak se patří.',
    ['Velké dožínky', { lid: 10, fin: -10 }], ['Uložit vše do zásob', { fin: 10, lid: -5 }], ['Díky bohům a předkům', { vir: 5, fin: -5 }], ['Poslat dar sousedům', { dip: 10, fin: -10 }], { season: 'podzim' }),
  k('ses_podzim_2', '@rada', 'Úroda je slabá. Zásoby na zimu nevystačí, pokud něco nevymyslíme, {osl}.',
    ['Přídělový systém', { fin: 5, lid: -10 }], ['Lovit a sbírat v lesích', { fin: 10, pri: -5 }], ['Vyměnit u sousedů', { fin: 5, dip: 5, sil: -5 }], ['Uchovat jídlo lépe', { ved: 5, fin: -5 }], { season: 'podzim' }),
  k('ses_podzim_3', '@kraj', 'Podzimní deště rozbahnily cesty i pole. Lidé prosí, aby se letos nevybíraly dávky ze sklizně.',
    ['Odpustit dávky', { lid: 10, fin: -10 }], ['Vybrat polovinu', { lid: -5, fin: 5 }], ['Vybrat vše', { fin: 10, lid: -10, sil: 5 }], ['Ať pomohou opravit cesty', { fin: 5, lid: -5, pri: 5 }], { season: 'podzim' }),
];

// ── Krajní stavy ukazatelů ─────────────────────────────
const st = { weight: 0 };
export const STATE_CARDS = [
  k('stav_fin_low', '@rada', 'Sýpky a zásobárny jsou prázdné, {osl}. Lidé mají hlad a nemáme čím zaplatit nikomu, kdo nám slouží.',
    ['Vybrat dávky', { fin: 15, lid: -10 }], ['Prodat lesy a půdu', { fin: 10, pri: -10 }], ['Prosit sousedy o pomoc', { fin: 10, dip: -10 }], ['Velká hostina pro útěchu', { fin: -10, lid: 10 }], st),
  k('stav_fin_high', '@kraj', 'Bohatství se hromadí u pár mocných rodin. Sýpky přetékají, zatímco chudí žebrají u bran.',
    ['Rozdělit zásoby lidu', { fin: -15, lid: 10 }], ['Stavět pro všechny', { fin: -10, ved: 5 }], ['Dary chrámům', { fin: -10, vir: 5 }], ['Hromadit dál', { fin: 10, lid: -10 }], st),
  k('stav_lid_low', '@kraj', 'Lid je na pokraji vzpoury, {osl}. Na návsích se šeptá o tom, kdo by vládl lépe.',
    ['Rozdat zásoby', { lid: 15, fin: -10 }], ['Vyslyšet stížnosti', { lid: 10, sil: -10 }], ['Velký svátek', { lid: 10, fin: -5, vir: -5 }], ['Tvrdě zakročit', { lid: -10, sil: 10 }], st),
  k('stav_lid_high', '@rada', 'Lid tě zbožňuje, {osl}, a čeká od tebe zázraky. Kdo nesouhlasí, je umlčen davem.',
    ['Říct lidem pravdu', { lid: -10, ved: 5 }], ['Zvýšit dávky', { lid: -10, fin: 10 }], ['Zakázat oslavy', { lid: -5, vir: -5 }], ['Slíbit ještě víc', { lid: 10, fin: -10 }], st),
  k('stav_sil_low', '@rada', 'Nemáme kým bránit hranice ani udržet pořádek, {osl}. Lupiči si dělají, co chtějí.',
    ['Najmout bojovníky', { sil: 15, fin: -10 }], ['Povinná služba', { sil: 10, lid: -10 }], ['Spolehnout se na sousedy', { sil: 5, dip: -10 }], ['Rozpustit zbytek stráží', { sil: -10, fin: 10 }], st),
  k('stav_sil_high', '@kraj', 'Vojáci se cítí nad zákonem, {osl}. Berou, co chtějí, a velitelé už neposlouchají rady.',
    ['Propustit část vojska', { sil: -15, lid: 5 }], ['Poslat je stavět', { sil: -10, fin: 5 }], ['Postavit je před soud', { sil: -10, vir: 5, lid: 5 }], ['Dát jim ještě víc', { sil: 10, lid: -10 }], st),
  k('stav_ved_low', '@rada', 'Nikdo už neumí to, co znali naši předkové, {osl}. Řemesla upadají a děti se nemají od koho učit.',
    ['Zřídit učiliště', { ved: 15, fin: -10 }], ['Pozvat cizí učence', { ved: 10, dip: -5, vir: -5 }], ['Odměny za objevy', { ved: 10, fin: -5 }], ['Stará moudrost stačí', { ved: -10, vir: 10 }], st),
  k('stav_ved_high', '@kraj', 'Učenci se nikoho neptají a zkoušejí věci, kterým nikdo nerozumí. Lidé se bojí, co z toho vzejde.',
    ['Stanovit hranice', { ved: -10, vir: 5 }], ['Poslat je mezi lid', { ved: -5, lid: 5 }], ['Zabavit jejich zásoby', { ved: -10, fin: 10 }], ['Ať bádají dál', { ved: 10, pri: -10 }], st),
  k('stav_pri_low', '@kraj', 'Řeky jsou kalné, lesy vykácené a zvěř zmizela, {osl}. Půda už skoro nic nerodí.',
    ['Vysazovat lesy', { pri: 15, fin: -10 }], ['Zakázat lov a těžbu', { pri: 10, lid: -10 }], ['Hledat lepší způsoby', { pri: 10, ved: 5, fin: -10 }], ['Vytěžit, co zbylo', { pri: -10, fin: 10 }], st),
  k('stav_pri_high', '@rada', 'Divočina se vrací, {osl}. Les pohlcuje pole, zvěř ničí úrodu a cesty zarůstají.',
    ['Vyklučit nová pole', { pri: -15, fin: 10 }], ['Velký hon', { pri: -10, lid: 5 }], ['Stavět cesty', { pri: -10, dip: 5 }], ['Les je posvátný', { pri: 10, vir: 5, fin: -10 }], st),
  k('stav_vir_low', '@kraj', 'Lidé už v nic nevěří, {osl}. Nikdo nedodrží slib a mladí se ptají, proč by se měli snažit.',
    ['Obnovit svátky', { vir: 15, fin: -10 }], ['Postavit svatyni', { vir: 10, fin: -5, pri: -5 }], ['Dát lidem společný cíl', { vir: 10, lid: -5 }], ['Víra je přežitek', { vir: -10, ved: 10 }], st),
  k('stav_vir_high', '@rada', 'Fanatici chodí po osadách, {osl}. Kdo nevěří jako oni, je štván a jeho dům pálen.',
    ['Zatknout kazatele', { vir: -15, sil: 5, lid: -5 }], ['Rozpustit bratrstva', { vir: -10, lid: -5 }], ['Podporovat učence', { vir: -10, ved: 10, fin: -5 }], ['Postavit se do čela', { vir: 10, dip: -10 }], st),
  k('stav_dip_low', '@rada', 'Žádný soused s námi nemluví, {osl}. Obchod ustal a kolem hranic se stahují cizí bojovníci.',
    ['Poslat dary', { dip: 15, fin: -10 }], ['Nabídnout sňatek', { dip: 10, vir: -5, lid: -5 }], ['Otevřít trhy', { dip: 10, fin: 5, lid: -10 }], ['Zbrojit ještě víc', { dip: -10, sil: 10 }], st),
  k('stav_dip_high', '@kraj', 'Cizí vyslanci tu rozhodují víc než ty, {osl}. Naše zvyky mizí a zásoby odvážejí za hranice.',
    ['Vypovědět smlouvy', { dip: -15, fin: 5 }], ['Vlastní stráž na hranicích', { dip: -10, sil: 5, fin: -5 }], ['Vrátit se k tradicím', { dip: -10, vir: 5 }], ['Ustoupit ještě víc', { dip: 10, lid: -10 }], st),
  k('zlaty_vek', '@rada', 'Zlatý věk, {osl}! Všeho je tak akorát, lidé jsou spokojeni a země vzkvétá. Jak tu chvíli využijeme?',
    ['Velká slavnost', { lid: 5, vir: 5, fin: -5 }], ['Postavit něco trvalého', { fin: -5, ved: 5, dip: 5 }], ['Bádání a učení', { ved: 10, fin: -5 }], ['Odpočinek pro zemi', { pri: 10, fin: -5 }], { weight: 0 }),
];

// ── Soupeřící sousední národ ───────────────────────────
const past = { pastOnly: true };
export const RIVAL_CARDS = [
  k('riv_obchod', 'riv', 'Přicházím od sousedů, {osl}. Nabízíme výměnu zásob a volný průchod našich obchodníků vaší zemí.',
    ['Přijmout obchod', { fin: 10, dip: 5, pri: -5 }, { rel: { riv: 2 }, power: 5 }], ['Jen za lepších podmínek', { fin: 5, dip: -5 }, { rel: { riv: -1 } }], ['Odmítnout', { dip: -10, vir: 5 }, { rel: { riv: -2 } }], ['Vyměnit i znalosti', { ved: 10, dip: 5, fin: -5 }, { rel: { riv: 1 }, power: 10 }], past),
  k('riv_hranice', 'riv', 'Naši pastevci tvrdí, že údolí za řekou odjakživa patří nám. Vaši lidé tam nemají co dělat.',
    ['Údolí je naše', { sil: 5, dip: -10 }, { rel: { riv: -2 }, power: -5 }], ['Rozdělit ho napůl', { dip: 5, fin: -5 }, { rel: { riv: 1 } }], ['Přenechat jim ho', { dip: 10, lid: -10 }, { rel: { riv: 2 }, power: 10 }], ['Vyhlásit válku', { sil: 5, lid: -5, dip: -10 }, { rel: { riv: -3 }, war: true }], past),
  k('riv_tribut', 'riv', 'Jsme silnější, {osl}, a oba to víme. Každý rok nám odvedete díl zásob – a budete žít v míru.',
    ['Platit tribut', { fin: -10, dip: 5, lid: -5 }, { rel: { riv: 2 }, power: 10 }], ['Smlouvat o menší', { fin: -5, dip: -5 }, { power: 5 }], ['Odmítnout', { lid: 5, dip: -10 }, { rel: { riv: -2 } }], ['Raději válka', { sil: -5, lid: 5, dip: -10 }, { rel: { riv: -3 }, war: true }], { ...past, rivalMin: 60 }),
  k('riv_spojenectvi', 'riv', 'Naše národy si rozumějí, {osl}. Pojďme uzavřít spojenectví a bránit se navzájem proti všem.',
    ['Uzavřít spojenectví', { dip: 10, sil: 5, vir: -5 }, { rel: { riv: 3 }, power: 5 }], ['Jen obranné', { dip: 5, sil: -5 }, { rel: { riv: 1 } }], ['Zůstat sami', { dip: -10, lid: 5 }, { rel: { riv: -1 } }], ['Využít jejich důvěru', { fin: 10, dip: -10, vir: -5 }, { rel: { riv: -3 }, power: -10 }], { ...past, rel: ['riv', 3] }),
  k('riv_hrozba', 'riv', 'Naši bojovníci stojí na hranici, {osl}. Jedno slovo a vtrhnou do vaší země. Co nám nabídnete?',
    ['Bohaté dary', { fin: -10, dip: 10 }, { rel: { riv: 2 } }], ['Posílit hranice', { sil: 5, fin: -10 }, { rel: { riv: -1 } }], ['Udeřit první', { sil: -5, dip: -10, lid: 5 }, { rel: { riv: -2 }, war: true }], ['Hledat spojence', { dip: 5, vir: -5, fin: -5 }, { power: -5 }], { ...past, rel: ['riv', -3] }),
  k('riv_svatba', 'riv', 'Náš vládce nabízí sňatek mezi našimi rody, {osl}. Krev spojí, co meč rozdělil.',
    ['Přijmout sňatek', { dip: 10, vir: 5, lid: -5 }, { rel: { riv: 3 }, power: 5 }], ['Jen mírová smlouva', { dip: 5, fin: -5 }, { rel: { riv: 1 } }], ['Uraženě odmítnout', { lid: 5, dip: -10 }, { rel: { riv: -2 } }], ['Žádat věno', { fin: 10, dip: -5, vir: -5 }, { rel: { riv: -1 }, power: -5 }], past),
  k('riv_spion', 'riv', 'Chytili jsme jednoho z vašich lidí u nás, {osl}. Tvrdí, že jen obchoduje. My víme své.',
    ['Přiznat a omluvit se', { dip: 5, lid: -5, vir: -5 }, { rel: { riv: 1 } }], ['Zapřít ho', { dip: -5, sil: 5 }, { rel: { riv: -1 } }], ['Vyměnit za jejich zvěda', { dip: 5, sil: -5, ved: 5 }, { rel: { riv: 1 }, power: -5 }], ['Vykoupit ho', { fin: -10, ved: 5 }, { power: 5 }], past),
  k('riv_pohlceni', 'riv', 'Náš národ je zlomený, {osl}. Hlad, nemoci a rozbroje. Mnozí z nás by raději žili pod tvou vládou.',
    ['Přijmout je za své', { lid: 5, dip: 5, fin: 10 }, { absorb: true }], ['Poslat pomoc', { fin: -5, dip: 10, vir: 5 }, { rel: { riv: 3 }, power: 10 }], ['Vzít si jejich zemi', { sil: 5, pri: -5, dip: -10 }, { rel: { riv: -3 }, war: true }], ['Nechat je být', { fin: 5, vir: -5 }, { power: -5 }], { ...past, rivalMax: 25 }),
];

// ── Zrádce ─────────────────────────────────────────────
export const TRAITOR_CARDS = [
  k('zrada_hledat', '@vysetr', 'Někdo z tvého nejbližšího okolí vynáší tajemství, {osl}. Sousedé vědí o našich plánech dřív než my.',
    ['Vyšetřit potichu', { fin: -10, ved: 5 }, { expose: true }], ['Nastražit past', { dip: -5, sil: 5, fin: -5 }, { expose: true }], ['Zatknout podezřelé', { lid: -10, sil: 5 }, { expose: true }], ['Nevěřím na zradu', { lid: 5, dip: -10 }], { traitor: 'hunt', weight: 1 }),
  k('zrada_trest', '@zradce', 'Ano, {osl}, tvá tajemství odcházela k cizím přese mě. Mám k tomu své důvody. Teď je můj osud v tvých rukou.',
    ['Vyhnat ze země', { dip: -5, sil: 5 }], ['Odpustit', { lid: 5, sil: -10 }], ['Dvojitý agent', { dip: 10, vir: -5, sil: -5 }], ['Veřejný soud', { vir: 5, lid: 5, fin: -5 }], { traitor: 'punish', weight: 0 }),
];
