# Misekártya

> Tracker: [szanatil/Miserend-Flutter#27](https://github.com/szanatil/Miserend-Flutter/issues/27)

## Problem Statement

A Misék fül sorai (`mass_list_item.dart`) két dologban térnek el attól, amire a felhasználónak szüksége van:

- **Nem hasonlítanak a Templomok fül kártyáira.** A sor csak egy `InkWell` a sima háttéren: nincs `Card`, nincs árnyék, nincs `black12` szürke háttér. Ezt a fület a két lista közül bármelyikről érkezve más alkalmazásnak érezni.
- **A legfontosabb adat nincs elöl.** Ezen a fülön az a kérdés, hogy *mikor* kezdődik a mise. Mégis a templom képe áll a bal szélen, az időpont pedig a név és a település alatt, a harmadik sorban. Azt, hogy el kell-e már indulni, fejben kell kiszámolni.

## Solution

*(Módosítva 2026-09-18: az idősáv megszűnt, a kezdés a blokkfejlécbe került, ld. „Elrendezés”.)* A sor helyére **misekártya** kerül, a templomkártya testvére: ugyanaz a kártyacsalád, de saját, az időpontra épülő, tömörebb belső elrendezéssel. Három sávja van: balra az **idő** (nagy kezdés, alatta a **hátralévő idő** vagy az „Épp most tart" jelölés), középen a **templom** (név, település · mise címe), jobbra egy keskeny **fotósáv**, rajta a távolsággal.

A templom képe marad, mert segít gyorsan felismerni, melyik templomról van szó, de az időpontnál kisebb szerepet kap.

## User Stories

1. Mint felhasználó, egy pillantással szeretném látni, mikor kezdődik a mise, mert ezen a fülön ez dönt.
2. Mint felhasználó, szeretném látni, mennyi idő van még a kezdésig, hogy ne kelljen fejben kiszámolnom, el kell-e már indulnom.
3. Mint felhasználó, szeretném, hogy a hátralévő idő ne legyen zaj: egy este hétkor kezdődő miséhez délelőtt nem kell „7 óra 40 perc múlva".
4. Mint felhasználó, szeretném, hogy a hátralévő idő a telefonom órájával együtt váltson, ne egy perccel utána.
5. Mint felhasználó, a templom képéről szeretném gyorsan felismerni, melyik templomban lesz a mise.
6. Mint felhasználó, szeretném, hogy a Misék és a Templomok fül kártyái egy családba tartozzanak: ugyanaz a forma, árnyék, háttér, és ugyanott a távolság.
7. Mint felhasználó, a lista lefelé görgetésekor az időpontokat egy függőleges oszlopban szeretném végigfutni, hogy a név hossza ne tolja el őket.
8. Mint görögkatolikus vagy régi rítusú misét kereső felhasználó, továbbra is szeretném látni, ha egy mise „Szent Liturgia" vagy „Régi rítusú szentmise".
9. Mint vidéki felhasználó, továbbra is szeretném látni a települést, mert a falum egyetlen templomának neve nem mondja meg, melyik faluról van szó.

## Implementation Decisions

### Kártyacsalád (egyezés a templomkártyával)

- `Card` az app alapértelmezett árnyékával. **A templomkártya árnyéka nem változik**, a téma `cardTheme`-jét nem kell bővíteni.
- A lista `Colors.black12` háttéren áll, mint a Templomok fül listái, 8 px-es `ListView` paddinggel (ma is ennyi).
- Ugyanaz a `DistanceChip`, ugyanaz a fotó-helykitöltő (`church_blurred.png`), ugyanazok a `PhotoDecode` szabályok.
- **Nincs kedvenc-gomb.** A kártya egy konkrét, rövidesen lejáró alkalomról szól, a kedvenc pedig a templomra vonatkozik. Kedvencnek jelölni a részletezőn és a Templomok fülön lehet.
- Az egész kártya koppintásra a részletezőt nyitja (a mostani `onTap`, változatlanul).
- Szerverhiba-árnyalás nincs: a Misék fülnek nincs gyorsítótár-tartaléka (spec 0004), hiba esetén üzenet jelenik meg lista helyett.

### Elrendezés

**Fix magasság**, nevesített konstansként, a tartalomhoz nem igazodik. A tömörebb kártya a cél (irányérték ~100–110 px, a tényleges értéket a tartalom adja, ld. alább), hogy a legfeljebb 10 kártyából minél több férjen a képernyőre.

| Sáv | Tartalom |
|---|---|
> **Módosítva (2026-09-18, a #36 tesztelése után):** a kezdés és a hátralévő idő lekerült a kártyáról. Az azonos időpontban kezdődő misék blokkot alkotnak: a blokk fejléce (`MassStartHeader`) a kezdés, mellette a hátralévő idő vagy az „Épp most tart", alatta egy vonal, alatta a kártyák. A kártyán nincs idősáv; a mise jellemzője a település alatti saját sorba került (spec 0011). A Misék fül a keresősáv alatt a Templomok fül lila sávját kapja „Mai misék" felirattal, a Térkép fül „Térkép" felirattal (`SectionBar`).

| **Idő** (bal, fix szélesség) — *megszűnt, ld. fent* | Kezdés 24 órás formában, nagy (`headlineMedium` körül), **félkövér**, `CustomColors.accent` színnel. Ugyanez a szín jelöli a mise-időpontokat a templomkártyán is. Alatta kisebb (`bodySmall`), szürke szöveggel a **hátralévő idő**, vagy **helyette** az „Épp most tart" jelölés (a mostani `_OngoingBadge`). A két elem kizárja egymást. 2 órán túli misénél a hely üres marad. |
| **Templom** (közép, `Expanded`) | **Név**: legfeljebb **2 sor**, ellipszissel. A két sor helye rövid névnél is le van foglalva (a templomkártya `_LineSlot` mintája), így ami alatta van, minden kártyán ugyanott áll. **Alatta 1 sor**: település és mise címe, `·`-vel elválasztva („Nyíregyháza · Szent Liturgia"). Ha nincs cím, vagy a cím „Szentmise", csak a település áll. Ha nincs település, csak a cím. Ha nem fér ki, a sor vége ellipszissel levágódik. A **mise jellemzője** ez alatt, saját sorban, sárga buborékokban áll (spec 0011, módosítva 2026-09-18). |
| **Kép** (jobb) | Keskeny, **teljes magasságú** fotósáv (~96 px széles), a kártya széléig kifuttatva (`Clip.antiAlias` a kártyán, mint a templomkártyán). A `DistanceChip` a kép **jobb alsó sarkában** áll, 8 px-re a szélektől, a templomkártyával egyezően. |

- A fix magasság a legmagasabb tartalomból adódik: kétsoros név + egy sor alatta a középső sávban, illetve kezdés + jelölés az időoszlopban. Nagyobb betűméretnél sem csordulhat túl, ezt teszt ellenőrzi.
- **Ismert kockázat:** hosszú településnévnél a mise címe esik ki. Vállaljuk, mert a cím ritka, egy mindig lefoglalt, de szinte mindig üres külön sor pedig a tömörséget rontaná.
- A bélyegkép továbbra is a `thumbnailUrl` jövőből jön, és amíg nem oldódik fel, a helykitöltő látszik (spec 0004: a kép nem tartja vissza a listát). A dekódolási méret a fotósáv magasságából számolódik, a templomkártyához hasonlóan `tight: true`-val.

### Hátralévő idő

A fogalom a CONTEXT.md „Hátralévő idő" szócikkében van. A szabály:

- Tiszta függvény: `(start, now) → String?`. Ha nincs mit kiírni, `null`.
- A számítás **percre pontos, másodpercek nélkül**: a `now` egész percre levágva, a különbség `start − now` percekben. (Példa: 18:00-s mise 17:35:40-kor → 17:35 → 25 perc.)
- Az épp most tartó misénél (`start ≤ now`, `isOngoing`) nincs hátralévő idő, a helyén az „Épp most tart" jelölés áll. Ez a függvényen kívül dől el, a meglévő `isOngoing`-gal.
- Formák:
  - **1–59 perc** → „N perc múlva"
  - **egész óra** → „N óra múlva"
  - **egyébként** → „N óra M perc múlva"
- **Nincs „most kezdődik" forma.** A kezdés egész percre esik (`start_date` másodperc nélkül), ezért egész percre levágott `now` mellett a nem tartó mise legalább 1 percre van: 17:59:59-kor „1 perc múlva", 18:00:00-tól a mise már tartó. Ha mégis másodperces kezdés érkezne, a 0 perc „1 perc múlva"-ként jelenik meg (a különbség alsó korlátja 1).
- **Felső határ: 120 perc, zárt**. A 2 órán belül kezdődő misénél ki van írva („2 óra múlva"), 121 perctől nem.

### Ticker igazítása egész percekhez

- A lap percenkénti újraszámolása (`near_masses_page.dart`, `_reselectEvery`) ma a lap megnyitásának másodpercétől indul, így a hátralévő idő akár 59 másodpercet késhet a telefon órájához képest.
- A ticker **a következő egész perchez igazodik**: az első ütemig a perc hátralévő részét várja, utána percenként ismétel. Ez a lejárt misék kikerülését is az órához igazítja.
- A `clock` injektálható marad, a tesztek az időt továbbra is kívülről léptetik.

### Fájlok, amik érintettek

- `lib/home/masses/mass_list_item.dart`: új kártya-elrendezés (a fájl és az osztály átnevezhető `MassCard`-ra, a `ChurchCard` párjaként)
- `lib/home/masses/near_masses_page.dart`: `black12` háttér a lista alatt, a ticker igazítása
- új: a hátralévő idő függvénye (pl. `lib/home/masses/nearest_masses.dart` mellé, az elérhetőségi szabályok közelébe)
- `CONTEXT.md`: „Hátralévő idő" szócikk (kész)

## Testing Decisions

- **Hátralévő idő, unit tesztek** rögzített `start`/`now` értékekkel:
  - az utolsó másodperc: 17:59:59 → 18:00 = „1 perc múlva"
  - másodperces kezdés ugyanabban a percben (18:00:30 kezdés, 18:00:10 most) → „1 perc múlva"
  - 1 perc, 59 perc, 60 perc („1 óra múlva"), 65 perc („1 óra 5 perc múlva"), 120 perc („2 óra múlva"), 121 perc (`null`)
  - a másodpercek levágása: 17:35:40 → 18:00 = „25 perc múlva"
  - éjfélen átnyúló kezdés (23:30-kor a holnap 00:00-s mise → „30 perc múlva")
- **Misekártya widget tesztek:**
  - megjelenik a kezdés, és 2 órán belül a hátralévő idő;
  - tartó misénél „Épp most tart" látszik, hátralévő idő nem;
  - 2 órán túli misénél egyik sincs;
  - a „Szentmise" cím nem jelenik meg, a „Szent Liturgia" a település sorában jelenik meg („Település · Szent Liturgia");
  - a távolság-chip a képsávban áll (a képsáv jobb alsó sarkában);
  - nincs kedvenc-gomb;
  - hosszú névvel, hosszú településsel és címmel, nagy szövegmérettel nincs túlcsordulás (`tester.takeException()` null);
  - rövid és hosszú névvel az alsó sor `top` értéke ugyanaz.
- **Lap:** a meglévő `near_masses_page_test.dart` tesztjei a kártyához igazodnak. A városnév és a „Szent Liturgia" ellenőrzése az egyesített sor szövegére változik. Új teszt: egy perc léptetése után a hátralévő idő eggyel kevesebb.
- A ticker igazítása `fake_async`-kel ellenőrizhető: a lap 17:35:40-kor nyílik, az első újraszámolás 17:36:00-kor fut.

## Out of Scope

- **A templomkártya árnyékának vagy elrendezésének változtatása.**
- **App-ikon** (`mise.png`): külön issue, [#28](https://github.com/szanatil/Miserend-Flutter/issues/28).
- **Kedvencnek jelölés a misekártyáról.**
- **Menetidő, „mikor induljak"**: az app nem tud menetidőt (CONTEXT.md, „Elérhető mise").
- **„Most kezdődik" felirat**: egész perces kezdésnél nem fordulhat elő (ld. Hátralévő idő).
- **Eltelt percek a tartó misénél** („4 perce kezdődött"): azt sugallná, hogy a lista a mise hosszát követi.
- **A kiválasztási szabály** (spec 0004) nem változik.

## Further Notes

- A spec 0004 „Megjelenítés" szakaszát ez a spec váltja fel: a tartalom ugyanaz (kép, név, település, kezdés, távolság, „Épp most tart", cím), csak az elrendezés és a hátralévő idő új.
- Az `accent` narancs. Ha a nagy, félkövér narancs időpont fehér kártyán gyengén olvasható (kontraszt), ez a megvalósításkor jelzendő, nem csendben átszínezendő.
