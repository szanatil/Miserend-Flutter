# Részletes kereső

> Tracker: [szanatil/Miserend-Flutter#35](https://github.com/szanatil/Miserend-Flutter/issues/35)

## Problem Statement

A felhasználó nem tudja megkérdezni az apptól, hogy **hol lesz mise egy adott helyen, egy adott napon, egy adott időben** — például „Pécsen vasárnap 9 és 12 között", vagy „hol van latin nyelvű mise Budapesten". A keresősáv egyetlen szövegre keres, nap nélkül; a Misék fül mindig a mai napot és a felhasználó **helyzetét** mutatja (**legközelebbi misék**). Aki utazás előtt tervez, vagy nem a saját környékén keres, nem kap választ.

A régi Android app (`bmaczak/Miserend-Android`) ezt a „Részletes kereső" képernyővel tudta. A Flutter app az Android app frissítéseként jelenik meg, így a régi felhasználók ezt a funkciót elveszítenék.

## Solution

A keresősáv javaslatlistájának alján mindig ott áll a **Részletes kereső** sor. Megnyitja a Részletes keresőt a főképernyőn belül — a keresősáv és az alsó navigáció a helyén marad —, ahol a felhasználó egyszerre több feltételt adhat meg: a templom nevét, a települést, a liturgikus nyelvet, és hogy a templomnak **legyen miséje** egy adott napon, egy adott időablakban. A találat a feltételeknek **mind** megfelelő templomok listája, templomkártyákon. A lista fölött egy összegző sor mutatja, milyen feltételekre keresett, a kártyákon pedig látszik, mivel felel meg a templom: a keresett időablak miséi.

A lista görgetés közben töltődik: a névre, településre és nyelvre szűrt jelöltek a **helyi gyorsítótárból** jönnek, és az API-t csak akkor és csak annyi templomra hívja az app, amennyit a felhasználó legörget, és csak ha van nap-feltétel.

## User Stories

1. Mint utazást tervező hívő, meg szeretném keresni, hol van mise egy másik településen egy adott vasárnap délelőtt, hogy előre tudjam, hová menjek.
2. Mint a régi Android app felhasználója, a Részletes keresőt ugyanott és ugyanazon a néven szeretném megtalálni, ahol megszoktam: a keresősáv javaslatainak alján.
3. Mint felhasználó, a keresősávba már beírt szöveget nem szeretném újra begépelni, amikor a Részletes keresőre váltok: kerüljön a név mezőbe.
4. Mint felhasználó, a templom nevének egy részletére szeretnék keresni, ékezetek és kis-nagybetű nélkül is, ahogy a keresősávban.
5. Mint felhasználó, a település nevének egy részletére szeretnék keresni („Buda"), és elfogadom, hogy ez Budakeszit is hozza.
6. Mint felhasználó, gépelés közben szeretnék településjavaslatokat kapni a létező településnevekből, hogy ne írjam el.
7. Mint budapesti felhasználó, a „Budapest" beírásával minden kerület templomát szeretném megtalálni, mert a kerületek külön településnévként szerepelnek.
8. Mint idegen nyelvű vagy latin misét kereső felhasználó, egy liturgikus nyelvet szeretnék választani egy listából, zászlóval és magyar névvel.
9. Mint felhasználó, a nyelvlistában csak olyan nyelveket szeretnék látni, amelyhez van is templom, hogy ne keressek feleslegesen.
10. Mint felhasználó, a magyar nyelvet nem szeretném a listában látni, mert szinte minden templomra igaz, és nem szűkít.
11. Mint felhasználó, egy koppintással szeretném megadni a napot: Ma, Holnap, Vasárnap.
12. Mint felhasználó, ezeken túl egy tetszőleges dátumot is szeretnék választani.
13. Mint felhasználó, ha napot választok, alapból az egész napra szeretnék keresni, és csak ha akarom, szűkíteni időablakra.
14. Mint felhasználó, időablakot szeretnék megadni (pl. 9:00–12:00), és egy 12:00-kor kezdődő misét is találatnak szeretnék látni.
15. Mint felhasználó, nap megadása nélkül is szeretnék keresni, csak névre, településre vagy nyelvre.
16. Mint felhasználó, csak misét szeretnék találatként látni az időpont-feltételnél: a gyóntatás, a vecsernye vagy a szentségimádás nem számít.
17. Mint felhasználó, csak olyan templomot szeretnék a találatok között látni, amely **minden** megadott feltételnek megfelel.
18. Mint felhasználó, ha nem adtam meg sem nevet, sem települést, és az app sem tudja a helyzetemet, szeretném érteni, miért nem kereshetek még: a Keresés gomb inaktív, és alatta rövid magyarázat áll.
19. Mint felhasználó, ha csak nyelvet és napot adok meg, a környékemen szeretnék keresni, a hozzám legközelebbi templomokkal elöl.
20. Mint felhasználó, a találati lista fölött szeretném látni, milyen feltételekre kerestem („Pécs · vasárnap 9–12 · latin"), hogy tudjam, mit nézek.
21. Mint felhasználó, az összegző sorra koppintva szeretném újra kinyitni és módosítani a feltételeket, oldalváltás nélkül.
22. Mint felhasználó, keresés után a feltételeket összecsukva szeretném látni, hogy a találatoknak több hely jusson.
23. Mint felhasználó, minden találati kártyán látni szeretném a keresett időablakba eső miséket, hogy ne kelljen a részletezőt megnyitnom.
24. Mint felhasználó, görgetés közben látni szeretném, hányadik találatnál tartok és hány van összesen, hogy tudjam, mennyi van még hátra.
25. Mint felhasználó, ha adtam meg települést, a találatokat település, azon belül név szerint rendezve szeretném látni.
26. Mint felhasználó, ha nem adtam meg települést, de a helyzetem ismert, légvonal-távolság szerint szeretném a találatokat, a kártyán a távolsággal.
27. Mint felhasználó, ha se település, se helyzet nincs, név szerinti sorrendet szeretnék.
28. Mint felhasználó, egy találatra koppintva a templom részletezőjét szeretném megnyitni.
29. Mint felhasználó, a találati kártyán ugyanúgy szeretném kedvencnek jelölni a templomot, mint a többi listán.
30. Mint felhasználó, gyorsan szeretném látni az első találatokat, és görgetés közben a továbbiakat, ne várjak az egész országra.
31. Mint mobilnetet spóroló felhasználó, azt szeretném, hogy az app csak annyi adatot töltsön le, amennyit megnézek.
32. Mint felhasználó, ha egy lap templomai közül kevés felel meg, szeretném, hogy a lista magától hozzon továbbiakat, és ne álljon meg félig üres képernyővel.
33. Mint felhasználó, látni szeretném, ha a lista még tölt, és azt is, ha a végére értem.
34. Mint felhasználó, ha nincs egyetlen találat sem, ezt világos üzenettel szeretném látni, a feltételek módosításának lehetőségével.
35. Mint kapcsolat nélküli felhasználó, a gyorsítótárban tárolt miserend alapján is szeretnék találatokat kapni, és tudni szeretném, hogy nem friss adatot látok (**Nincs kapcsolat**).
36. Mint felhasználó, ha a miserend.hu hibás választ ad, a gyorsítótár alapján szeretnék találatokat, **Szerverhiba** jelzéssel.
37. Mint felhasználó, ha a kapcsolat helyreáll, szeretném, hogy a jelzés magától eltűnjön, ahogy a többi listán.
38. Mint felhasználó, ha nap-feltétel nélkül keresek, azonnali, API nélküli találatokat szeretnék.
39. Mint felhasználó, a keresősáv egyszerű keresését továbbra is ugyanúgy szeretném használni; a Részletes kereső sor ne tolja ki a javaslatokat.
40. Mint felhasználó, a Részletes keresőben is látni szeretném az alsó navigációt, hogy ne érezzem, hogy kiléptem az appból, és egy koppintással visszajussak bármelyik fülre.
41. Mint felhasználó, egy új keresésnél nem szeretném viszontlátni az előző keresés feltételeit.
42. Mint felhasználó, a feltételek kitöltése közben a billentyűzet csak addig legyen nyitva, amíg írok, hogy a feltételeket át tudjam látni.
43. Mint felhasználó, ha egy találat részletezőjéből visszalépek, ugyanott szeretném folytatni, ahol abbahagytam.

## Implementation Decisions

### Belépés

- A keresősáv javaslatnézetének alján mindig ott áll a „Részletes kereső" sor, **rögzített láblécként**: fölötte vékony elválasztó, a javaslatok fölötte görögnek, így sok javaslatnál sem kerül ki a látható részből. Akkor is ott áll, ha a beírt szöveg rövidebb a javaslatok 3 karakteres küszöbénél, és akkor is, ha nincs javaslat. Megjelenése a javaslatsoroké: `ListTile`, a kezdő 40 px-es helyen `Icons.manage_search` ikon (ahol a településjavaslat `location_city` ikonja áll). Más belépési pont nincs (a Templomok fülön sincs külön ikon).
- A sorra koppintva a keresősávba írt szöveg a **név** mezőbe kerül.
- **Új keresés, üres feltételekkel**: a keresősávból indított **bármelyik** keresés — a Részletes kereső sor, egy templom- vagy településjavaslat, vagy az egyszerű keresés beküldése — törli a Részletes kereső korábbi feltételeit és találatait. A Részletes kereső sor akkor is üres feltételekkel (és a beírt névvel) indul, ha a Részletes kereső már nyitva volt; az egyszerű keresés és a javaslatok a Részletes keresőt bezárják, így a találati oldalról visszalépve a fül jön.
- **A keresősáv kiürül**: bármelyik keresés indításakor a sáv szövege és a javaslatok törlődnek, a sáv legközelebb üresen nyílik. A Részletes kereső sor a beírt szöveget a törlés előtt veszi át a név mezőbe.

### Keret

- A Részletes kereső **a főképernyőn belül** jelenik meg, a fül tartalmának helyén: a keresősáv és az alsó navigáció a helyén marad, hogy a felhasználó ne érezze, hogy kilépett az appból. A törzs tetején a fülek lila `SectionBar` sávja áll, „Részletes kereső" címmel és bal oldalt vissza nyíllal.
- Az alsó navigáción az a fül marad kijelölve, amelyikről a felhasználó a keresősávot megnyitotta. **Bármelyik** fülre koppintva (a kijelöltre is) a Részletes kereső bezárul, és a fül jelenik meg; a vissza nyíl és a rendszer vissza gombja ugyanígy. Nem marad félbehagyott keresés a fülek mögött.
- A keresősáv nyitott Részletes kereső mellett is ugyanúgy működik, mint máshol.
- Egy találatra koppintva a részletező úgy nyílik meg, mint mindenhol (teljes képernyőn, alsó navigáció nélkül — a navigáció megtartása a részletezőn külön issue, #52). Onnan visszalépve a Részletes kereső **változatlanul** fogad: ugyanazok a feltételek, ugyanaz a görgetési hely, a már betöltött lapok, újratöltés nélkül; a közben váltott kedvencjelölés a kártyán is látszik.

### Oldal

- **Egy oldal**: fent a feltételek, alattuk a találatok. Megnyitáskor a feltételek ki vannak nyitva, találat még nincs.
- Keresés után a feltételek egy **összegző kártyává** csukódnak („Pécs · vasárnap 9–12 · latin", előtte szűrő ikon, jobb szélen lefelé nyíl), amely a lista fölött **rögzítve** marad; a lista alatta görög. Az összegző kártya egyben a „milyen feltételekre kerestem" jelzése. Alatta áll, ha van, a Nincs kapcsolat / Szerverhiba csík, alatta a lista.
- Az összegző kártyára koppintva a feltételek kinyílnak, és **a teljes törzset** elfoglalják: a régi találatok és a darabszám-jelvény nem látszanak. A Keresés gomb újra összecsukja és új listát tölt. A kinyitott feltételek tetején felfelé nyíl csukja össze keresés nélkül: ekkor a módosítás **elvész**, és visszajön a legutóbbi keresés feltételei és találatai — az összegző kártya mindig azt mutatja, amire a lista ténylegesen keresett.
- A feltételek egy `SectionCard`-ban állnak, a részletező szakaszainak megjelenésével:
  - **Név**: szövegmező (a Hibajelentés oldal mezőinek stílusával). Szövegrész, ékezet- és kis-nagybetű-független, a név, az ismert név és az alternatív nevek között — ugyanaz a szabály, mint a keresősáv beküldött keresésénél.
  - **Település**: szövegmező. Szövegrész (nem pontos egyezés), ékezet- és kis-nagybetű-független. Gépelés közben javaslatlista a mező alatt, a gyorsítótár településneveiből; a választott javaslat is szövegrészként szűr.
  - **Liturgikus nyelv**: egy választás, egy „Nyelv: bármelyik" sorral; rákoppintva alsó lap (bottom sheet) nyílik zászló + magyar név sorokkal, legfelül „Bármelyik". A lista a gyorsítótárban ténylegesen előforduló `nyelvek` kódokból áll, a magyar nélkül (CONTEXT.md, „Liturgikus nyelv jelölése" — a kódok nem ISO 639 kódok).
  - **Nap**: alapból nincs. Egy sor választó chip: Ma / Holnap / Vasárnap / Dátum…; a kijelölt chipre újra koppintva a kijelölés megszűnik. A Dátum… chipen választás után a dátum áll („okt. 4."). Vasárnapon a „Vasárnap" a mait jelenti (ugyanúgy, mint a részletező „Ma" chipje vasárnap).
  - **Időablak**: csak nap mellett látszik. Alapból bekapcsolt „Egész nap" kapcsoló; kikapcsolva két időpontmező (-tól / -ig), a rendszer időválasztójával.
  - **Keresés**: teljes szélességű gomb a feltételek alján.
- **Kötelező**: legalább egy a következők közül: név, település, vagy ismert **helyzet**. Ha egyik sincs, a Keresés gomb inaktív, alatta rövid, szürke magyarázat.
- **Billentyűzet**: csak szövegmezőre koppintva nyílik, megnyitáskor nem. Eltűnik, ha a felhasználó a mezőn kívül bárhová koppint, a Kész gombot nyomja, vagy településjavaslatot választ — hogy a feltételek újra átláthatók legyenek. A név mező billentyűzet-gombja „Tovább" (a település mezőre ugrik), a településé „Kész". A keresés nem a billentyűzetről indul, csak a Keresés gombbal.

### Egyezés

- **ÉS kapcsolat**: minden megadott feltételnek teljesülnie kell; részleges egyezés nem találat.
- Nap-feltételnél a templomnak legyen legalább egy **miséje** (CONTEXT.md, „Mise vs. egyéb liturgikus esemény" — ugyanaz a szabály, mint a templomkártya chipjeinél), amelynek **kezdése** az időablakba esik, **mindkét vége zárt** (9:00 és 12:00 is benne van).

### Találatok

- **Templomkártyák**, a templomkártya meglévő megjelenésével. A chipeken a napi miserend helyett a **keresett nap, időablakba eső miséi**; nap-feltétel nélkül a napi miserend, ahogy más listákon. A kártyán **nincs nyelvzászló**: nyelvfeltételnél minden találat ugyanazt a nyelvet hordaná, ez nem mond semmit; a nyelv az összegző kártyán látszik.
- **Sorrend**: van település-feltétel → település, azon belül név szerint; nincs település, de ismert a helyzet → légvonal-távolság, a kártyán a távolsággal; egyébként név szerint.
- **Darabszám-jelvény**: alul középen, sötét, félig átlátszó kapszulában, fehér szöveggel; görgetés közben látszik, és kb. 1,5 mp-cel a görgetés vége után elhalványul (nem takar ki állandóan a kártyákból, és nem ül a fotó sarkában álló távolságra). Alakja „8 / 42 találat", ahol az első szám az utolsó teljesen látható kártya sorszáma. Nap-feltétel nélkül az összes pontos. Nap-feltétellel a találatok száma csak a jelöltek végignézése után ismert, ezért amíg van még lap, „8 / 12+ találat" (az eddig talált, „+" jellel); a végére érve a „+" eltűnik. Az összeset nem kérdezzük le csak a számért (31. történet).
- **Lista alja**: új lap töltése közben kis forgó töltésjelző; a jelöltek végén szürke, középre igazított „Nincs több találat · 15 találat". Az első keresés alatt „Keresés..." töltőnézet. Üres találatnál „Nincs találat", alatta „Feltételek módosítása" gomb, amely kinyitja a feltételeket.

### Betöltés (lapozás)

- Új **betöltő** modul a meglévő templomlista-betöltő mellé, mély interfésszel: bemenete a feltételek és a kért lap, kimenete a találatok lapja — templomonként a megfelelés bizonyítékával (az időablak miséi) —, hogy van-e még lap, a jelenlegi találatszám és hogy az végleges-e (a darabszám-jelvényhez), és a lap Nincs kapcsolat / Szerverhiba állapota az adatok korával. A képernyő ezen túl semmit nem tud a gyorsítótárról vagy az API-ról.
- A **jelöltek** (név, település, nyelv szerint szűrve, a fenti sorrendben) a helyi gyorsítótárból jönnek, lapokban (irányérték: 20 templom).
- **Nap-feltétel nélkül** nincs API-hívás; a lapok azonnal a gyorsítótárból jönnek.
- **Nap-feltétellel** a betöltő egy lap jelöltjeinek csak a keresett napi miserendjét kéri az API-tól — ugyanazzal a hívással, amellyel a templom-részletező a kiterjesztett miserendet állítja elő (ADR-0002, spec 0003) —, a választ visszaírja a gyorsítótárba, és a jelöltek közül csak a megfelelőket adja vissza. Az API-t csak akkor hívja, amikor a lista a görgetés miatt új lapot kér.
- Ha egy lap után a megjelenített találatok nem töltik meg a képernyőt, a lista magától kéri a következő lapot, amíg meg nem telik, vagy el nem fogynak a jelöltek.
- **Hiba esetén** (Nincs kapcsolat, Szerverhiba) a betöltő a gyorsítótár miseadataiból szűr, és a lap jelzést kap; a lista fölött ugyanaz a jelölés áll, ugyanazzal az (i) magyarázattal és önjavító újrapróbálással, mint a Templomok fül listáin. Egy templom, amelynek a keresett napra nincs gyorsítótárazott miseadata, hiba esetén nem találat.
- Ha az API egy jelöltet **hiányzónak** jelez, az a meglévő szabály szerint kikerül a gyorsítótárból és a kedvencek közül, és nem találat.
- A hiányzó templomot csak a `Church` végpont jelzi, a `NearbyMasses` nem. Ezért nap-feltételnél a betöltő a lap jelöltjeire előbb egy `Church {"ids"}` hívást tesz (`minimal`), és csak utána kéri a jelöltek napi miséit. Pozíció nélküli templom miséit a `NearbyMasses` nem tudja lekérni: ennél a gyorsítótár dönt.

## Testing Decisions

- Jó teszt a **külső viselkedést** nézi: adott feltételekre, adott gyorsítótár-tartalomra és API-válaszra milyen templomok jönnek, milyen sorrendben, milyen bizonyítékkal és állapottal — nem azt, milyen SQL fut vagy hány belső lépés történik. Az API-hívások számát csak ott ellenőrizzük, ahol az a felhasználónak ígért viselkedés (nap-feltétel nélkül nincs hívás; lapot csak kérésre).
- **Fő határ: az új betöltő.** Valódi, memóriabeli SQLite gyorsítótárral (sqflite ffi) és hamis HTTP klienssel, az élő API-ból mentett fixture-ökkel. Esetek: ÉS kapcsolat; szövegrész-egyezés településre („Buda", „Budapest" a kerületekre); ékezetfüggetlen név; nyelvszűrés; időablak zárt végei; nem-mise esemény nem ad találatot; a három sorrend; nap nélkül nincs API-hívás; lapozás és „van még lap"; kevés találatnál a következő lap; Nincs kapcsolat és Szerverhiba gyorsítótár-tartalékkal; hiányzó templom.
- **Widget-tesztek, kevés**: a javaslatnézet láblécében mindig ott a Részletes kereső, és viszi a beírt szöveget; a Részletes kereső mellett látszik az alsó navigáció, és fülre koppintva bezárul; új keresés a keresősávból törli a korábbi feltételeket; a Keresés gomb inaktív állapota és magyarázata; keresés után összecsukódó feltételek és összegző kártya; keresés nélküli összecsukás visszaállítja a legutóbbi feltételeket; görgetésre új lap; a darabszám „+" jele nap-feltétellel, amíg van még lap. Hamis betöltővel.
- Előzmény: a templomlista-betöltő tesztje, a keresési találatok widget-tesztje és hamis betöltője, a javaslatlista és a keresési javaslatok tesztjei, a templomkártya tesztje.

## Out of Scope

- Keresés **mise jellemzőjére** (Csendes, Gitáros, Diák) és **akadálymentességre**.
- Több nyelv egyszerre.
- **Misék listája** találatként (mise-alkalmanként egy sor): a találat templom.
- Térképes találati nézet.
- A keresési feltételek megjegyzése, korábbi keresések.
- A keresősáv egyszerű keresésének bármilyen változása a Részletes kereső sor hozzáadásán túl. (Hogy a sáv keresés után nem ürül, és a régi javaslatok visszajönnek, külön hibajegy: #51.)
- Belépési pont a Templomok fülről.
- Az alsó navigáció megtartása a részletezőn és az egyszerű keresés találati oldalán (fülenkénti navigáció) — külön issue: #52.
- Nyelvzászló a találati kártyán.

## Further Notes

- A funkció a régi Android app „Részletes kereső"-jének utódja, de szándékosan eltér tőle: ott a mise-feltétel mise-listát adott, a település pontos kiválasztás nélkül szövegrészre illeszkedett (ezt megtartjuk), és a nap alapból „ez a vasárnap" volt (nálunk nincs alapértelmezett nap). Összehasonlítás: `docs/ANDROID-OSSZEHASONLITAS.md`.
- A Dátum… választó tartománya nincs megbeszélve; javasolt alapérték: a mai naptól 90 napig.
- **Nyitott kérdés — nyelvi adat a gyorsítótárban.** A `nyelvek` mezőt sem a kezdeti feltöltés, sem a listák `minimal` válasza nem hozza; csak a teljes (`full`) válasz, vagyis a részletező és a térképi kártya frissítése. Így a nyelvlista és a nyelvszűrés csak a már megnyitott templomokat ismeri. Megoldásához döntés kell (pl. `full` válasz a lapok `Church` hívásához, vagy egyszeri nyelvi feltöltés).
- Fogalmak: CONTEXT.md, „Részletes kereső", „Helyi gyorsítótár", „Nincs kapcsolat", „Szerverhiba", „Légvonal-távolság", „Mise vs. egyéb liturgikus esemény", „Liturgikus nyelv jelölése".
