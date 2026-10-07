# Instalace Pocket Realm na iPhone – krok za krokem

Aplikace není v App Storu, takže se instaluje „bokem“ (sideload) s tvým vlastním Apple ID.
Je to zdarma, potřebuješ jen počítač (Windows nebo Mac) a USB kabel k iPhonu.

**Potřebuješ:** iPhone s iOS 17 nebo novějším (iPhone 14 Pro je ideální), aspoň **4 GB volného místa**,
počítač, kabel, Apple ID a Wi-Fi.

---

## 1. Stáhni hru

1. V počítači otevři stránku vydání: **https://github.com/stepanvcelak11/osobn--agent/releases/latest**
2. V části *Assets* stáhni soubor **`PocketRealm-unsigned.ipa`** (asi 5 MB).

## 2. Připrav počítač

**Windows**
1. Nainstaluj **iTunes** a **iCloud** ve verzi **z webu Applu, ne z Microsoft Store** – Sideloadly s verzemi
   ze Storu nefunguje. Správné odkazy najdeš na https://sideloadly.io hned u tlačítka Download
   („iTunes … and iCloud … are required“).
2. Restartuj počítač.

**Mac** – nic dalšího není potřeba.

**Na obou:** stáhni a nainstaluj **Sideloadly** z https://sideloadly.io (tlačítko Download).

## 3. Připoj iPhone

1. Připoj iPhone kabelem k počítači a odemkni ho.
2. Na iPhonu se objeví „Důvěřovat tomuto počítači?“ → **Důvěřovat** a zadej kód telefonu.

## 4. Nainstaluj hru přes Sideloadly

1. Spusť Sideloadly.
2. Přetáhni do okna soubor `PocketRealm-unsigned.ipa` (nebo klikni na ikonu IPA a vyber ho).
3. V poli **iDevice** musí být tvůj iPhone.
4. Do pole **Apple account** napiš své Apple ID (e-mail).
   Tip: klidně si založ druhé, „herní“ Apple ID – funguje stejně.
5. Klikni na **Start**, zadej heslo k Apple ID a případně ověřovací kód, který přijde na telefon.
6. Počkej, až dole uvidíš **Done**. Ikona Pocket Realm se objeví na ploše iPhonu.

## 5. Povol aplikaci v iPhonu

1. **Nastavení → Obecné → VPN a správa zařízení** → pod „Aplikace pro vývojáře“ klepni na své Apple ID → **Důvěřovat**.
2. **Nastavení → Soukromí a zabezpečení → Režim pro vývojáře** (úplně dole) → zapnout → iPhone se restartuje
   → po restartu potvrď **Zapnout**.
   (Bez režimu pro vývojáře iOS aplikaci nainstalovanou bokem nespustí.)

## 6. První spuštění

1. Připoj se k **Wi-Fi** a otevři Pocket Realm.
2. Hra sama začne stahovat vypravěče (**Gemma 3 4B, asi 2,5 GB**) a pak hlasové ovládání (asi 550 MB).
   Stav vidíš na titulní obrazovce. Stahuje se i na pozadí; když se přeruší, pokračuje, kde skončilo.
3. Mezitím už můžeš hrát – do dokončení stahování vypráví jednodušší záložní vypravěč.
4. Až uvidíš **„Vypravěč připraven“**, vše běží **úplně offline**. Internet už hra nepotřebuje.
5. Při první hře s osadou se hra zeptá na **oznámení** (hrozby, dokončené stavby) – povol, pokud chceš.

## 7. Každých 7 dní: obnovit podpis

S bezplatným Apple ID platí podpis aplikace **7 dní**. Potom se hra nespustí – **nic se ale neztratí**
(uložené hry ani stažený vypravěč).

- Připoj iPhone k počítači, v Sideloadly znovu nainstaluj **stejný** soubor `.ipa` se **stejným** Apple ID.
- Pohodlněji: v Sideloadly zaškrtni u aplikace automatické obnovování (*Auto-refresh*) – pak stačí, aby byl
  počítač zapnutý a iPhone na stejné Wi-Fi.
- S placeným vývojářským účtem Applu (99 USD/rok) platí podpis rok.

## 8. Nová verze hry

Stáhni nový `PocketRealm-unsigned.ipa` z https://github.com/stepanvcelak11/osobn--agent/releases/latest
a nainstaluj ho přes Sideloadly **stejně jako poprvé a se stejným Apple ID**. Hra se přepíše,
**uložené hry i stažený vypravěč zůstanou**.

---

## Když něco nejde

| Problém | Řešení |
|---|---|
| Sideloadly nevidí iPhone | Odemkni telefon, zkus jiný kabel/port, na Windows zkontroluj, že je iTunes z webu Applu. |
| „Untrusted developer“ / aplikace nejde otevřít | Krok 5.1 – důvěřovat Apple ID ve Správě zařízení. |
| Aplikace spadne hned po otevření | Zapni Režim pro vývojáře (krok 5.2). Nebo vypršel 7denní podpis – krok 7. |
| Chyba přihlášení v Sideloadly | Zkontroluj heslo; u účtů s dvoufázovým ověřením zadej kód z telefonu. |
| Stahování vypravěče stojí | Zkontroluj Wi-Fi a volné místo (aspoň 4 GB), na titulní obrazovce klepni na „Zkusit znovu“. |
| Tah trvá dlouho | První tah po spuštění načítá model do paměti (desítky sekund). Pak bývá tah 10–25 s; text se píše průběžně. |
| Zasekl se tah | Klepni na ⏹ vpravo dole. Po 100 s se vyprávění ukončí samo a hra pokračuje. |

**Alternativa k Sideloadly:** AltStore (https://altstore.io) – nainstaluj AltServer do počítače, přes něj AltStore
do iPhonu a pak v AltStoru otevři soubor `.ipa` (např. z aplikace Soubory).
