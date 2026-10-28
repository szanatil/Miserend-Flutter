# A kezdeti feltöltés a méret megadásával, elutasíthatóan

## Problem Statement

Az App Store a 3.0.0 (40) iOS buildet a 4.2.3(ii) pont alapján visszautasította (2026-10-26, iPad Air 11"). Első indításkor az app a templomok és misék adatait (a **SQLite exportot**, ma ~21,8 MB) letölti a **kezdeti feltöltéshez**, de nem mondja meg, mekkora a letöltés. A felhasználó így nem tud megalapozottan dönteni. Ha mégsem kérné, nem tud mit választani: a „Kilépés” gomb iOS-en nem csinál semmit (`SystemNavigator.pop()`), és az app nem is lenne felkészülve arra, hogy kezdeti feltöltés nélkül induljon.

A kezdeti feltöltés azért kell, hogy az app ne üres **helyi gyorsítótárral** induljon. A listák és a csempék ebből rajzolnak azonnal, és az API válasza egy lépésben frissíti őket. Kezdeti feltöltés nélkül:
- a keresési javaslatok, a Részletes kereső és a Térkép csak azokat a templomokat ismeri, amelyeket más képernyő már betöltött;
- a Közeli templomok egy pillanatra azt írja, hogy „Nem találhatóak közeli templomok.”, holott csak az API válasza nem jött még meg.

## Solution

Az első indításkor, ha a szerver elérhető, az app egy párbeszédablakban felajánlja a letöltést, a méretével együtt:

> **Templomok és misék letöltése**
> A jobb élményhez töltsd le egyszer a templomok és misék adatait (21,8 MB). Nélküle az app csak korlátozottan működik. A letöltést később a Névjegyen is elindíthatod.
> [Most nem] [Letöltés]

A megoldás három feltevésre épül:
1. a párbeszédablak elég információt ad ahhoz, hogy a felhasználó tudja, mit választ;
2. ha meggondolja magát, a Névjegyen maga indíthatja el a letöltést;
3. az app alapfunkciói az API-ra épülnek, így aki elég sokáig használja online, annak a fontos templomok és misék idővel így is a készülékre kerülnek.

**Letöltés esetén:**
- egy folyamatjelző képernyő két lépésben mutatja a haladást: **Letöltés** (megabájtokkal) és **Import**;
- a letöltés alatt a Mégse gombbal megállítható;
- a végén az app a főképernyővel folytatódik.

**„Most nem” esetén** a felhasználó tudatosan a korlátozott működést választja:
- az app azonnal indul, és az API-ból, használat közben tölti a gyorsítótárat;
- az app a letöltést **többé nem ajánlja fel**, és egyik képernyőn sem kínál rá gombot;
- a letöltés egyetlen helyen, a **Névjegyen** indítható el;
- ahol egy képernyő nem tud mit mutatni (keresési javaslatok, Részletes kereső, Térkép), ott csak elmondja, hogy ennek a letöltés hiánya is lehet az oka, és hogy a letöltést a Névjegyen találja.

**Döntésnek** a „Most nem” és a letöltés megszakítása (Mégse) számít. Ha a felajánlás nem jelent meg (nem volt kapcsolat), vagy a letöltés, illetve az import hibára futott vagy az app közben bezárult, a következő induláskor újra megjelenik.

**Az első sikeres kezdeti feltöltés után** az app soha többé nem ajánlja fel, és a Névjegy csempéje, valamint a tájékoztató üzenetek is eltűnnek.

**Ha valaki utólag tölti le**, a kezdeti feltöltés csak a hiányt pótolja: amit addig az API beírt a gyorsítótárba, azt nem írja felül.

**Ha az API válasza még nem jött meg**, és a gyorsítótárban nincs adat, a listák töltésjelzőt mutatnak, nem hamis „nincs találat” üzenetet.

## User Stories

1. Mint új felhasználó, első indításkor látni szeretném, mekkora adatot tölt le az app, hogy a mobilnetem keretéről dönthessek.
2. Mint új felhasználó, szeretném eldönteni, hogy most töltöm-e le az adatokat, hogy ne kényszerítsen rá az app.
3. Mint új felhasználó, szeretném tudni, hogy letöltés nélkül az app csak korlátozottan működik, hogy tudjam, mit választok.
4. Mint új felhasználó, szeretném tudni, hogy a letöltést később is elindíthatom, és hol, hogy a „Most nem” ne tűnjön végleges döntésnek.
5. Mint új felhasználó, ha a „Most nem”-et választom, azonnal használni szeretném az appot, hogy ne kelljen várnom.
6. Mint új felhasználó, ha a „Most nem”-et választom, ne lépjen ki az app, hogy ne kelljen újraindítanom.
7. Mint felhasználó, aki a „Most nem”-et választotta, nem szeretném, hogy az app újra és újra rábeszéljen a letöltésre, hogy a döntésemet tiszteletben tartsa.
8. Mint felhasználó, aki a „Letöltés”-t választotta, látni szeretném, hol tart a letöltés (hány MB a 21,8-ból), hogy tudjam, mennyit kell még várnom.
9. Mint felhasználó, látni szeretném, hogy a letöltés után még az adatok feldolgozása (Import) is fut, hogy ne higgyem azt, hogy az app lefagyott.
10. Mint felhasználó, a letöltés közben meg szeretném tudni szakítani, ha mégis rossz pillanatban kezdtem, hogy ne fogyjon tovább az adatkeretem.
11. Mint felhasználó, aki megszakította a letöltést, utána is használni szeretném az appot, hogy a megszakítás ne zárjon ki.
12. Mint felhasználó, aki megszakította a letöltést, nem szeretném, hogy a következő induláskor újra felajánlja, mert meggondoltam magam.
13. Mint felhasználó, akinek a letöltése hibára futott, a következő induláskor újra fel szeretném kapni a felajánlást, mert én le akartam tölteni.
14. Mint felhasználó, akinek a letöltése vagy feldolgozása félbemaradt (pl. bezártam az appot), azt szeretném, hogy legközelebb rendben, elölről fusson le, hogy ne maradjon félkész adat.
15. Mint felhasználó, aki offline indítja először az appot, nem szeretnék felajánlást látni, amit úgysem tudnék elfogadni, és nem szeretnék sokáig várni az indulásra; online induláskor viszont meg szeretném kapni, hiszen még nem döntöttem.
16. Mint felhasználó, gyenge térerőnél sem szeretnék 5 másodpercnél tovább várni a splash-en a felajánlás miatt, hogy az app gyorsan elinduljon.
17. Mint felhasználó, aki egyszer sikeresen letöltötte az adatokat, soha többé nem szeretném látni a felajánlást, hogy ne zavarjon.
18. Mint felhasználó, aki nem töltötte le az adatokat, de meggondolta magát, a Névjegyen meg szeretném találni a letöltést, a méretével és egy magyarázattal, hogy tudjam, mit nyerek vele.
19. Mint felhasználó, ha a Névjegyről indítom a letöltést, a végén oda szeretnék visszatérni, hogy folytathassam, amit csináltam.
20. Mint felhasználó, aki nem töltötte le az adatokat, a keresési javaslatoknál és a Részletes keresőben „Nincs találat” esetén tudni szeretném, hogy ennek a letöltés hiánya is lehet az oka, és hol tölthetem le, hogy megértsem, mi történik.
21. Mint felhasználó, aki nem töltötte le az adatokat, a Térképen, ha a látott területen nincs templom, tudni szeretném, hogy ennek a letöltés hiánya is lehet az oka, és hol tölthetem le.
22. Mint felhasználó, aki letöltötte az adatokat, a Térképen egy templom nélküli területen nem szeretném azt olvasni, hogy a letöltés hiánya lehet az ok, mert az félrevezető.
23. Mint felhasználó, aki utólag töltötte le az adatokat, nem szeretném, hogy a már frissen látott templomadatok és miserendek régebbiekre cserélődjenek, hogy pontos adatot lássak.
24. Mint felhasználó, aki utólag töltötte le az adatokat, azt szeretném, hogy a még nem látott templomok és a hiányzó miserendek bekerüljenek, hogy a kereső, a Részletes kereső és a Térkép teljes legyen.
25. Mint felhasználó, aki nem töltötte le az adatokat, a Közeli templomokon töltésjelzőt szeretnék látni az első API-válaszig, ne azt, hogy „Nem találhatóak közeli templomok.”, hogy ne higgyem, hogy nincs templom a közelemben.
26. Mint felhasználó, aki nem töltötte le az adatokat, a keresés találati oldalán töltésjelzőt szeretnék látni az API válaszáig, ne azt, hogy „Nincs találat”.
27. Mint felhasználó, aki korábbi verzióról frissített, és még nincsenek letöltött adataim, ugyanazt a felajánlást szeretném kapni, mint egy új felhasználó, hogy egyértelmű legyen, mi történik.
28. Mint felhasználó, aki nem töltötte le az adatokat és offline van, a megszokott offline figyelmeztetést szeretném látni, ne a letöltésről szóló tájékoztatást.
29. Mint felhasználó, nem szeretném, hogy a letöltött nyers fájl foglalja a tárhelyemet, ha már nincs rá szükség.
30. Mint App Store-bíráló, a méretet és a választást látni szeretném a letöltés előtt, hogy az app megfeleljen a 4.2.3(ii) pontnak.
31. Mint App Store-bíráló, a „Most nem” után működő appot szeretnék látni, hogy az app ne tűnjön hiányosnak.

## Implementation Decisions

- **Új, mély modul: a kezdeti feltöltés.** Ez váltja ki a splash mostani `AppStartup` seamjét. A teljes folyamat az övé, a felülete kicsi:
  - **méretlekérdezés:** HEAD kérés a dokumentált export-végpontra, az átirányítás követésével, 5 s-os időkorláttal. Az eredmény a bájtokban mért méret, vagy „nem elérhető”. Ez dönti el azt is, hogy online vagyunk-e: külön kapcsolatfigyelő nincs;
  - **futtatás:** folyamatállapotokat ad ki: letöltés (letöltött és teljes bájtszám), import, kész, hiba, megszakítva;
  - **megszakítás:** csak a letöltés alatt hat;
  - **kész-e:** figyelhető jelzés arról, hogy volt-e már sikeres kezdeti feltöltés. Erre épül a Névjegy csempéje és a tájékoztató üzenetek;
  - **döntött-e:** a felhasználó elutasította-e a felajánlást. A „Most nem” és a megszakítás állítja be; a hiba és a félbemaradás nem. Erre épül a splash.
  - A modul törli a letöltött fájlt a sikeres import után és minden megszakadáskor is.
  - Félbemaradt futást nem folytat: a következő futás elölről indul, újra letöltve az exportot.
  - A „sikeres volt” jelző a meglévő preferencia marad; a „döntött” jelző új preferencia mellette. A letöltött export verziójára vonatkozó régi ellenőrzés és az „Elavultak a miserendek” ág megszűnik.
- **Letöltés folyamatjelzéssel**: a meglévő, darabonkénti 30 s-os csendkorlát marad, a teljes méret a válasz `content-length`-éből jön.
- **Hiánypótló import (`BootstrapImporter`)**:
  - **templomok:** amelyik nincs a gyorsítótárban, az teljes sorként bekerül. Meglévő templomnál csak az üres (null) mezők töltődnek ki, kitöltött mező nem íródik felül;
  - **misék:** a futás napjától számított 30 napon belül csak olyan templom–nap párra kerül mise, amelyre a gyorsítótárban még nincs alkalom;
  - az import idempotens.
  - A meglévő `upsertChurch` erre nem használható, mert felülír. A gyorsítótárnak kell egy „beszúrás, ha hiányzik” és egy „csak az üres mezők kitöltése” művelet.
  - A **frissítve** és a **helyi szinkron** jelentése nem változik.
  - A „kezdeti feltöltés ideje” (`bootstrappedAt`) a sikeres futás idejét jelzi; utólagos futásnál a mostani értéket kapja.
- **Splash**:
  - ha a kezdeti feltöltés már sikeres volt, vagy a felhasználó már döntött, rögtön a főképernyőre lép, méretlekérdezés nélkül;
  - különben lekérdezi a méretet. Ha nem sikerül, a főképernyőre lép; ha sikerül, megmutatja a párbeszédablakot;
  - a „Most nem” beállítja a „döntött” jelzőt, és a főképernyőre lép;
  - a „Letöltés” után a folyamatjelző képernyőt nyitja, és siker, hiba vagy megszakítás után is a főképernyő következik;
  - a mostani újrapróbálás-képernyők és a „korábban letöltött adatokkal folytatjuk” tartalék megszűnik.
- **Folyamatjelző képernyő**:
  - teljes képernyő, folyamatjelző sávval és kétlépéses listával (Letöltés: „8,4 / 21,8 MB”, Import), az aktuális lépés kiemelve;
  - Mégse csak a letöltés alatt; hiba esetén rövid üzenet, utána bezárul;
  - az első indításkor és a Névjegyről is ezt használjuk. A Névjegyről indítva bezárás után a Névjegy tér vissza.
- **Méretformázás**: MB, egy tizedes, tizedesvessző (pl. „21,8 MB”). Ha a méret nem ismert, „kb. 22 MB”.
- **Névjegy csempéje** (prototípus: `prototype/0015-nevjegy-letoltes-csempe` ág, „A” változat):
  - `SectionCard` „Templomok és misék letöltése” címmel, **legfelül**, a „Mai templom ajánlatunk” fölött;
  - szöveg: „Letöltés nélkül csak a közeli és a már megnézett templomok érhetők el a keresésben, a Részletes keresőben és a Térképen. Ha meggondoltad magad, itt egyszer letöltheted az összes templom és mise adatait.”;
  - alatta a csempe közepére igazított `FilledButton` letöltés ikonnal: „Letöltés (21,8 MB)”. A méretet a Névjegy megnyitásakor élő méretlekérdezés adja; ha az nem sikerül, „Letöltés (kb. 22 MB)”, és a gomb akkor is indítható (a hibát a folyamatjelző képernyő kezeli);
  - csak akkor látszik, ha nincs sikeres kezdeti feltöltés; a „kész” jelző igazra váltásakor eltűnik;
  - a lista alján a meglévő hely marad, így a lebegő Visszajelzés gomb a csempét sem takarja.
- **Tájékoztatás a hiányos képernyőkön**: gomb nélkül, csak akkor, ha nincs sikeres kezdeti feltöltés, a képernyő nem tud mit mutatni, és nem jelez **Nincs kapcsolat** vagy **Szerverhiba** állapotot (az offline jelzés elsőbbséget kap):
  - **keresési javaslatok:** ha a beírt szóra nincs sem templom, sem város;
  - **Részletes kereső:** ha a gyorsítótárban nincs a név, a város és a nyelv szerinti jelölt. Ha van jelölt, de az API szerint az adott napon nincs alkalmuk, az nem a letöltés hiánya: ott a meglévő „Nincs találat” áll;
  - mindkettőnél az üres állapot (KO8): cím „Nincs találat”, magyarázat „Lehet, hogy azért, mert nem töltötted le az összes templom adatait. A letöltést a Névjegyen indíthatod el.”;
  - **Térkép:** ha a látható területen nincs marker, egy **tájékoztató szalag** (DESIGN.md KO7) jelenik meg: „Itt most nincs megjeleníthető templom. Lehet, hogy azért, mert nem töltötted le az összes templom adatait; a letöltést a Névjegyen indíthatod el.” Nincs bezáró gombja: a látható területet követi, eltűnik, amint marker látszik, és újra megjelenik, ha a felhasználó üres területre megy. Sikeres kezdeti feltöltés után soha nem jelenik meg.
- **Töltésjelző üres gyorsítótárnál**: ha a gyorsítótár olvasása üres, és a háttérbeli API-hívás még fut, a lista töltésjelzőt mutat. Az üres üzenet csak a hívás sikeres, üres válasza után jelenik meg; hiba esetén a meglévő offline jelölés áll. Érinti a Közeli templomokat, a keresés találati oldalát és a Kedvenceket.
- **A keresési javaslatok** továbbra is csak a gyorsítótárból jönnek (ld. ADR-0006, Considered Options).
- A döntés hátterét az [ADR-0006](../adr/0006-a-kezdeti-feltoltes-elutasithato-es-hianypotlo.md) rögzíti; a fogalmakat a `CONTEXT.md` **Kezdeti feltöltés** szócikke.

## Testing Decisions

- **Mitől jó egy teszt:** kívülről látható viselkedést ellenőriz (mit lát a felhasználó, mi van a gyorsítótárban), nem belső hívási sorrendet. Minden UI-teszt a DESIGN.md EH3–EH4 szerint fut: iOS és Android, világos és sötét téma, 320 és 430 dp szélesség, 2.0-s szövegméret.
- **Kezdeti feltöltés modul** (hamis HTTP-kliens, ideiglenes könyvtár, memóriabeli gyorsítótár):
  - a méretlekérdezés követi az átirányítást, és 5 s után „nem elérhető”;
  - a futás folyamatállapotai a várt sorrendben jönnek;
  - a megszakítás leállítja a letöltést, a fájlt törli, a „kész” jelző hamis marad, a „döntött” jelző igaz lesz;
  - hiba után a fájl törlődik, és a „döntött” jelző nem változik;
  - siker után a fájl törlődik, és a „kész” jelző igaz.
- **`BootstrapImporter`** (a meglévő `bootstrap_importer_test` mintájára, memóriabeli régi és új adatbázissal):
  - üres gyorsítótárba mindent beír;
  - meglévő templom kitöltött mezőjét nem írja felül, az üreset kitölti;
  - API-ból ismert templom–nap misét nem bánt, az üres napot kitölti;
  - kétszer futtatva ugyanaz az eredmény.
- **Splash** (a meglévő `splash_test` mintájára, a modul hamis változatával):
  - sikertelen méretlekérdezésnél nincs párbeszédablak, megjelenik a főképernyő, és a következő induláskor újra van méretlekérdezés;
  - a párbeszédablak a méretet mutatja („21,8 MB”), és a Névjegyre utal;
  - „Most nem” → főképernyő, letöltés nélkül; a következő induláskor nincs méretlekérdezés és nincs párbeszédablak;
  - „Letöltés” → folyamatjelző képernyő → főképernyő;
  - Mégse után a következő induláskor nincs párbeszédablak; hiba után van;
  - sikeres kezdeti feltöltés után nincs méretlekérdezés és nincs párbeszédablak;
  - a „Kilépés” gomb nincs többé.
- **Folyamatjelző képernyő**: a két lépés és az MB-állás megjelenik; a Mégse a letöltés alatt látszik, az import alatt nem; hiba után bezárul.
- **Névjegy** (a meglévő `about_page_test` mintájára): a csempe legfelül áll, a mai templom fölött; a gomb az élő méretet mutatja, sikertelen lekérdezésnél „kb. 22 MB”-ot; a gomb a folyamatjelző képernyőt nyitja, bezárása után a Névjegy tér vissza; a „kész” jelző igazra váltásakor a csempe eltűnik; görgetve a csempe gombja kikerül a Visszajelzés gomb alól.
- **Tájékoztatás** (a meglévő oldal-tesztek mintájára):
  - keresési javaslatok és Részletes kereső: üres eredménynél kezdeti feltöltés nélkül a bővített „Nincs találat” áll, sikeres feltöltés után a megszokott; jelöltekkel, de alkalom nélkül a megszokott; Nincs kapcsolat állapotban az offline jelzés áll;
  - Térkép: marker nélküli területen kezdeti feltöltés nélkül a szalag látszik, markeres területre lépve eltűnik, vissza üresre újra megjelenik; sikeres kezdeti feltöltés után marker nélküli területen sem látszik; offline nem látszik.
- **Töltésjelző** (a meglévő hamis lista-betöltőkkel): üres gyorsítótár és futó hívás mellett töltésjelző; üres sikeres válasz után az üres üzenet; hiba után az offline jelölés.

## Out of Scope

- A letöltés ismételt felajánlása a „Most nem” vagy a Mégse után: sem induláskor, sem a hiányos képernyőkön. A felhasználó döntött; a pótlás a Névjegyen elérhető.
- Offline működés kezdeti feltöltés nélkül. Az app eleve online-ra épül; ilyenkor a meglévő offline figyelmeztetés áll.
- A keresési javaslatok vagy a Részletes kereső API-ból való kiszolgálása.
- A Térkép saját API-hívása a markerekhez.
- Az export beépítése az app csomagjába.
- Mobilnet és Wi-Fi megkülönböztetése a felajánlásnál.
- A felajánlás angol nyelvű változata (az app magyar). Az App Review angol magyarázatot kap a válaszban.
- A gyorsítótár rendszeres frissítése exportból (ADR-0003 marad).

## Further Notes

- **Kiadás:**
  - build ≥41;
  - kézi próba iPad és iPhone szimulátoron, friss telepítéssel: elfogadás; elutasítás, majd újraindítás (nincs felajánlás); elutasítás, majd letöltés a Névjegyről; offline első indítás, majd online indítás (van felajánlás);
  - képernyőképek a párbeszédablakról, a „Most nem” utáni állapotról és a Névjegy csempéjéről.
- **Válasz az App Review-nak** (App Store Connect, angolul): az app első induláskor megmutatja az egyszeri adatletöltés méretét (~22 MB, templomok és miserendek), és megerősítést kér. A „Most nem” (Not now) után az app letöltés nélkül is használható, korlátozott tartalommal, a letöltés pedig később bármikor elindítható a Névjegy (About) oldalról. Mellé a párbeszédablak és a Névjegy csempéjének képernyőképe, a szöveg fordításával.
- Az export naponta generálódik a szerveren (a `Last-Modified` 2026-10-26 19:12 volt); a méret ezért változhat, ezért kérdezzük le élőben.
