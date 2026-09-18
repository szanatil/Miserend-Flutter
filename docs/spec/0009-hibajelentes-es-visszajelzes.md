# Hibajelentés és visszajelzés

> Tracker: [szanatil/Miserend-Flutter#33](https://github.com/szanatil/Miserend-Flutter/issues/33) (hibajelentés), [szanatil/Miserend-Flutter#34](https://github.com/szanatil/Miserend-Flutter/issues/34) (visszajelzés, Menü oldal)

## Problem Statement

Két hiányosság van:

- **A hibajelentés nem illik az apphoz, és hibásan működik.** A templom részletezőjén a „Hibajelentés” egy Material alapstílusú `AlertDialog` ([report_problem_popup.dart](../../lib/church_details/report_problem_popup.dart)): régi `DropdownButton`, aláhúzott mezők, a dialógusban szűkös szövegírás, és a billentyűzet összenyomja. Emellett:
  - A sikert a HTTP 200 alapján ítéli meg. A miserend.hu a hibát a törzsben, `error: 1`-gyel jelzi, így egy elutasított jelentésre is azt írhatja ki, hogy „Hibajelentés elküldve”.
  - Az „Egyéb” típus (`pid: 2`) mellé az API kötelezően szöveget vár, a popup ezt nem ellenőrzi.
  - A `dbdate` a kódba írt `'2025-04-18'`, pedig v4-ben kötelező, és az adat tényleges dátumát kellene tartalmaznia.
  - Küldés közben nincs töltésjelzés, így dupla koppintással kétszer is elmehet a jelentés.
  - A kapcsolat hiányát és a szerverhibát egyetlen „Hibajelentés sikertelen!” üzenet fedi.
- **Az appról nem lehet visszajelzést küldeni.** A felhasználó nem tudja jelezni, ha az app hibásan működik, és azt sem, ha új funkciót szeretne. A miserend.hu API egyik végpontja sem fogad ilyen üzenetet (a `Report` csak templomhoz kötve működik, `tid` kötelező), és az appnak saját szervere sincs.

## Solution

Két külön fogalom, két külön csatorna (CONTEXT.md, „Hibajelentés”, „Visszajelzés”):

- A **Hibajelentés** a templom adatairól szól, és továbbra is a miserend.hu `Report` végpontjára megy, de egy teljes képernyős oldalon, a fenti hibák nélkül. Csak kapcsolat mellett indítható.
- A **Visszajelzés** az appról szól (hiba, vélemény, funkciókérés), és e-mailben megy a Szent József Hackathon csapatához: **szentjozsefhackathon@jezsuita.hu**. A Visszajelzés az alsó navigáció új „Menü” pontjából nyíló oldalról indul, és közvetlenül a telefon levelezőprogramját nyitja meg egy előre kitöltött levéllel.
- Ugyanezen az oldalon látszik a miserend.hu webes változatának linkje és az app verziója.

## User Stories

1. Mint felhasználó, egy templom hibás adatát a templom oldalán szeretném jelezni, ahol egyértelmű, melyik templomról van szó.
2. Mint felhasználó, a hibajelentést kényelmesen szeretném megírni, a billentyűzet ne takarja el az űrlapot.
3. Mint felhasználó, csak akkor szeretnék „elküldve” üzenetet látni, ha a miserend.hu tényleg fogadta a jelentést.
4. Mint felhasználó, ha a küldés nem sikerül, ne vesszen el, amit beírtam, és tudjam, hogy a térerővel van-e baj vagy a miserend.hu-val.
5. Mint felhasználó, ne küldhessem el véletlenül kétszer ugyanazt a jelentést.
6. Mint felhasználó, ne kelljen minden jelentésnél újra beírnom az e-mail címemet.
7. Mint felhasználó, ha az app nem mutat friss adatot, ne kezdjek bele egy olyan jelentésbe, amely úgysem menne el.
8. Mint adatgondozó, minden jelentésből szeretném látni, mi a hiba, mert egy szöveg nélküli „rossz miseidőpont” alapján nem tudom, mit javítsak.
9. Mint felhasználó, szeretném jelezni az app fejlesztőinek, ha valami nem működik, vagy ha új funkciót szeretnék.
10. Mint fejlesztő, a visszajelzésből szeretném látni az app verzióját és a telefon rendszerét.
11. Mint felhasználó, szeretném megtudni, melyik verziót használom, ki készítette az appot, és honnan jönnek az adatok.

## Implementation Decisions

### Hibajelentés: belépési pont a részletezőn

- A „Hibajelentés” gomb a részletező műveletsorában marad ([church_details_page.dart](../../lib/church_details/church_details_page.dart), `_actionButtons`).
- **Aktív**, ha a részletező adata betöltődött (`_data != null`), és nincs rajta hibajelzés (`_data.failure == null`). Amíg az API nem válaszolt, a gomb aktív: csak egy *ismert* hiba tiltja le, ugyanaz, amelyet a felhasználó a képernyőn lát.
- **Tiltott**, amíg a részletező **Nincs kapcsolat** vagy **Szerverhiba** jelzést mutat. Az ikon és a felirat halványabb színű. Koppintásra SnackBar jelenik meg: „Hibát jelenteni csak kapcsolat mellett lehet. Amint a miserend.hu újra elérhető, a gomb magától visszajön.” Az oldal nem nyílik meg.
- A részletező meglévő újrapróbálkozása sikerrel törli a `failure`-t, így a gomb külön logika nélkül aktív lesz.
- Nincs sorba állított, később elküldött jelentés.

### Hibajelentés: az oldal

Új, teljes képernyős oldal (`lib/church_details/report_problem_page.dart`), `Navigator.push`-sal nyílik. A régi `report_problem_popup.dart` és a `_showReportPopup` törlődik.

- **AppBar:** az app témája szerinti lila, címe „Hibajelentés”.
- **Fejléc:** a templom neve (`titleMedium`), hogy látsszon, miről szól a jelentés.
- **Típus:** három választógomb (`RadioListTile`), alapból **egyik sincs kiválasztva**:

  | Felirat | `pid` |
  |---|---|
  | Rossz pozíció | 0 |
  | Rossz miseidőpont | 1 |
  | Egyéb | 2 |

- **Leírás:** többsoros, keretes (`OutlineInputBorder`) mező, **mindig kötelező**, minden típusnál. Az API csak a `pid: 2`-nél követeli meg, de az adatgondozó szöveg nélkül nem tudja, mit javítson.
- **E-mail cím:** keretes mező, „E-mail cím (nem kötelező)”. Ha ki van töltve, a formátumát egyszerű mintával ellenőrizzük. Sikeres küldés után a készüléken megjegyezzük (`shared_preferences`), és a következő jelentésnél előre kitöltjük. Ha a felhasználó kiürítve küldi el, az üres érték kerül mentésre.
- **Érvényesítés** a „Küldés” megnyomásakor, a mezők alatti hibaszöveggel:
  - nincs típus: „Válaszd ki, milyen hibát jelentesz.”
  - üres leírás (szóközök nélkül is): „Írd le, mi a hiba.”
  - hibás e-mail: „Ez nem e-mail cím.”
- **Küldés gomb:** az űrlap alján, teljes szélességű `FilledButton`. Küldés közben töltésjelzőt mutat, és nem koppintható, így egy jelentés csak egyszer mehet el.
- **Siker:** az oldal bezárul, a részletezőn SnackBar jelenik meg: „Hibajelentés elküldve”.
- **Sikertelen küldés:** az oldal nyitva marad, a beírt adatok megmaradnak, a gomb újra aktív lesz, és SnackBar jelenik meg:
  - `ApiFailure.noConnection`: „Nincs kapcsolat, a hibajelentés nem ment el. Próbáld újra, ha lesz térerő.”
  - `ApiFailure.serverError` (HTTP-hiba, értelmezhetetlen válasz vagy `error: 1`): „A miserend.hu most nem fogadta a hibajelentést. Próbáld újra később.” A szerver `text` mezőjét nem mutatjuk: fejlesztőknek szól, és angolul is jöhet.
  - A sikertelen küldés **nem** változtat a részletező állapotán: nem tesz ki hibajelzést, és nem tiltja le a gombot, mert a részletező jelzése a saját adatáról szól.
- **Vissza gomb** a beírt szöveggel: megerősítés nélkül bezárja az oldalt, ahogy ma a „Mégse”.

### Hibajelentés: a kérés

- Új metódus a [MiserendApiClient](../../lib/api/miserend_api_client.dart)-ben: `report(...)` → `ApiResult<void>`, a `_post`/`_map` segédfüggvényen át, végpont: `report` (B2). Az `error: 1` így `serverError` lesz.
- A törzs:

  | Mező | Érték |
  |---|---|
  | `tid` | a templom azonosítója |
  | `pid` | a választott típus (0/1/2) |
  | `text` | a leírás, levágott szóközökkel |
  | `email` | az e-mail cím, ha ki van töltve; különben nem kerül a törzsbe |
  | `dbdate` | `yyyy-MM-dd`, a részletező `ChurchPageData.dataAsOf` értékéből |

- A `dbdate` forrása a meglévő `dataAsOf`: a templom helyi szinkronja, ha nincs, a kezdeti feltöltés dátuma (CONTEXT.md, „Frissítve vs. helyi szinkron”). Ezt az oldal a részletezőtől kapja.
- Az oldal a küldést egy injektálható objektumon át végzi (K1), így a widget teszt hamis küldővel pumpálhatja. A napló a hiba okát írja, a leírást és az e-mail címet nem (B3).

### Visszajelzés: belépési pont

- A főképernyő alsó navigációjába ([home.dart](../../lib/home/home.dart)) negyedik pontként egy **„Menü”** kerül, hamburger ikonnal (`Icons.menu`). Nem fül: koppintásra `Navigator.push`-sal teljes új oldalt nyit (Menü oldal), a kiválasztott fül nem változik. Négy ponttól a navigáció `BottomNavigationBarType.fixed`, hogy megmaradjon a lila háttér és a feliratok.
- Az AppBarba nem kerül menü: a korábbi ⋮ `PopupMenuButton` nem illett az app elrendezésébe.
- A Visszajelzés nem utal a templomadat-hibákra, és nem irányít a részletezőre. A hibajelentés helye a részletező.

### Visszajelzés: a levél

- A „Visszajelzés” közvetlenül megnyitja a levelezőprogramot, **appon belüli űrlap nincs**. Kapcsolatot az app nem ellenőriz, az offline küldést a levelezőprogram kezeli.
- Címzett: `szentjozsefhackathon@jezsuita.hu`, egyetlen nevesített konstansként (D3). Ha később lesz rá miserend.hu-végpont, csak ez a csatorna cserélődik.
- Tárgy: „Miserend app – visszajelzés”.
- Szöveg: két üres sor a felhasználónak, alatta elválasztóval a diagnosztika:

  ```


  ---
  Miserend app 1.0.0 (1)
  android 14
  ```

  Tartalom: app verzió és build szám (`package_info_plus`, új függőség), `Platform.operatingSystem`, `Platform.operatingSystemVersion`. **Nem** kerül bele eszközmodell, helyzet vagy azonosító. A felhasználó küldés előtt látja és törölheti.
- A `mailto:` URI-t kézzel kell kódolni (`Uri.encodeComponent` a `subject`-re és a `body`-ra). A `Uri(queryParameters:)` a szóközt `+`-ként kódolja, amit több levelezőprogram szó szerint mutat.
- A levél összeállítása tiszta függvény (`(PackageInfo-szerű verzióadat, platform) → Uri`), hogy tesztelhető legyen.
- **Nincs levelezőprogram:** ha a `launchUrl` `false`-t ad vagy kivételt dob, SnackBar jelenik meg: „Nincs levelezőprogram a telefonon. Írj nekünk: szentjozsefhackathon@jezsuita.hu”. Az indítás injektálható (K1).
- Android 11+ alatt ellenőrizni kell, hogy a `launchUrl` megnyitja-e a `mailto:` linket a manifest `<queries>` bővítése nélkül. Ha nem, a `<queries>` blokkba egy `SENDTO`/`mailto` intent kerül. Ezt valódi eszközön kell kipróbálni. A `SENDTO`/`mailto` intent a megvalósításkor (#34) megelőzésként bekerült, mert a `url_launcher` dokumentációja Android 11+ alatt ezt ajánlja, és ártalmatlan; a valódi eszközös próba még hátravan.
- A Visszajelzés indítása közös helyre kerül (`lib/widgets/`, K5), hogy a Menü oldal widgetje ne maga építse a levelet.

### Menü oldal

> 2026-09-18: a pont neve „Névjegy” lett, ⓘ ikonnal, az oldal tartalma és sorrendje megváltozott: lásd [spec 0014](0014-nevjegy-es-impresszum.md). A fájlok `lib/about/` alá költöztek.

Új oldal (`lib/menu/menu_page.dart`), az alsó navigáció „Menü” pontjából nyílik. Lila AppBar, cím: „Menü”, ugyanazzal a szürke háttérrel, mint a Templomok és a Misék listái (`Colors.black12` a fehéren), a részletező kártyáinak margójával. Tartalma, fentről lefelé:

- **miserend.hu** csempe („A miserend webes változata”): a `https://miserend.hu` a böngészőben nyílik meg (`launchExternal`, injektálható).
- **„Mai templom ajánlatunk”** kártya (`SectionCard`), fentről lefelé: a templom **képe** (az első fotó), **neve**, **címe** (város, utca) és **leírásának** első négy sora; koppintásra megnyílik a részletezője.
  - Csak fotóval rendelkező templom jöhet szóba (`CacheDatabase.photographedChurchCount` / `photographedChurchAt`).
  - A `ChurchOfTheDayLoader` a napból képzett véletlen maggal 10 jelöltet választ, így egész nap ugyanaz a sor. Közülük az első leírással rendelkező nyer, ha egyiknek sincs, az első.
  - A kezdeti feltöltés nem hoz leírást. A kártya a gyorsítótárból azonnal megjelenik, majd egyetlen teljes `Church {"ids"}` hívás mind a 10 jelöltet a gyorsítótárba írja, és a választás onnan ismétlődik (ADR-0003); a nap későbbi megnyitásain így rögtön a leírásos templom látszik. Sikertelen hívásnál a gyorsítótárbeli választás marad, hibajelzés nélkül. Fotós templom nélkül a kártya nem jelenik meg.
- **Verzió** csempe: „1.0.0 (1)” (`package_info_plus`).
- **„Visszajelzés”** gomb (`FilledButton`): a fenti levelet nyitja meg.

A térkép forrásmegjelölése nem kerül ide, mert a térképen már szerepel (`MiserendMap`: „© OpenStreetMap contributors © CARTO”).

### Fájlok, amik érintettek

- törölve: `lib/church_details/report_problem_popup.dart`
- új: `lib/church_details/report_problem_page.dart`, a küldő
- `lib/church_details/church_details_page.dart`: a gomb aktív/tiltott állapota, a `dataAsOf` átadása, a popup megnyitásának törlése
- `lib/api/miserend_api_client.dart`: `report()`
- új: `lib/widgets/` alatt a Visszajelzés indítása és a levél összeállítása
- új: `lib/menu/menu_page.dart`, `lib/menu/church_of_the_day_loader.dart`; a `SectionCard` a `lib/widgets/`-be költözik (K5)
- `lib/home/home.dart`: „Menü” pont az alsó navigációban
- `pubspec.yaml`: `package_info_plus`
- esetleg `android/app/src/main/AndroidManifest.xml`: `mailto` a `<queries>`-ben
- `CONTEXT.md`: „Hibajelentés”, „Visszajelzés” (kész)
- `docs/FEATURE-COVERAGE.md`, `README.md`: az új funkciók (C6)

## Testing Decisions

- **`MiserendApiClient.report`** (`MockClient`, T4):
  - a törzsben ott a `tid`, `pid`, `text`, `dbdate`; üres e-mailnél nincs `email`;
  - `error: 0` → `ApiSuccess`;
  - `error: 1` → `serverError`;
  - HTTP 500 → `serverError`;
  - a kérés előtti kivétel (pl. `SocketException`) → `noConnection`.
- **Hibajelentő oldal** (widget teszt, hamis küldővel, T6):
  - megjelenik a templom neve, és egyik típus sincs kiválasztva;
  - üres űrlapnál a „Küldés” mindhárom hibaszöveget mutatja, és nem küld;
  - „Rossz miseidőpont” típusnál is kötelező a leírás;
  - hibás e-mail formátumnál „Ez nem e-mail cím.”, üres e-mailnél nincs hiba;
  - küldés közben töltésjelző látszik, és egy második koppintás nem indít második küldést;
  - siker → az oldal bezárul, „Hibajelentés elküldve” látszik;
  - `noConnection` → a kapcsolat-üzenet látszik, az oldal nyitva marad, a leírás megmarad;
  - `serverError` → a miserend.hu-üzenet látszik, a leírás megmarad;
  - sikeres küldés után újranyitva az e-mail előre ki van töltve (`SharedPreferences.setMockInitialValues`);
  - a küldő a `dataAsOf` napját kapja `dbdate`-ként.
- **Részletező** (a meglévő `church_details_page_test.dart`-ban):
  - hibajelzés mellett a Hibajelentés gombra koppintva a magyarázó SnackBar látszik, és az oldal nem nyílik meg;
  - hibajelzés nélkül az oldal megnyílik;
  - egy sikeres újrapróbálkozás után a gomb újra megnyitja az oldalt.
- **Visszajelzés:**
  - a levél URI-ja: a címzett, a tárgy és a szöveg `%20`-szal kódolva, `+` nélkül; a verzió, a build szám és a platform benne van;
  - sikertelen indításnál a „Nincs levelezőprogram…” SnackBar látszik (hamis indító).
- **Menü oldal:**
  - a verzió a saját csempéjén látszik (`PackageInfo.setMockInitialValues`);
  - a „Mai templom ajánlatunk” kártya azonnal a képet, a nevet és a címet mutatja, a frissítés után a leírást is; választott templom nélkül nincs kártya (hamis loader);
  - a `ChurchOfTheDayLoader` egy napon belül ugyanazt a templomot adja, más napokon mást, fotó nélkülit soha; a jelölteket egy hívással kéri, és a leírásosat választja, amelyet utána a gyorsítótárból is ad; sikertelen hívásnál a gyorsítótárbelit adja vissza;
  - a miserend.hu csempe a `https://miserend.hu`-t nyitja meg (hamis indító);
  - a „Visszajelzés” gomb a visszajelző levelet nyitja meg (hamis indító).
- **Főképernyő:** az alsó navigáció „Menü” pontját widget teszt nem fedi le, mert a `HomeScreen` fülei a valódi adatbázist és API-t érik el.

## Out of Scope

- **Új miserend.hu-végpont az app-visszajelzéshez.** Amíg nincs, e-mail a csatorna.
- **Sorba állított, később elküldött hibajelentés.**
- **Hibajelentés a templomkártyáról vagy a térképi kártyáról.** Csak a részletezőről indítható.
- **Bejelentkezett felhasználó `token`-je** a `Report` kérésben (fiók nincs az appban).
- **Új hibatípusok** (pl. gyóntatás-kapcsoló). Az API csak a három `pid`-et ismeri, a többi az „Egyéb”-be tartozik.
- **Képcsatolás** a hibajelentéshez vagy a visszajelzéshez.
- **Adatvédelmi tájékoztató és GitHub-link** a Menü oldalon, amíg nincs ilyen oldal. (A GitHub-link azóta a Névjegyre került: spec 0014.)

## Further Notes

- A `Report` végpont mezőit a [miserend.hu/apidocs](https://miserend.hu/apidocs) alapján ellenőriztük (2026-09-17): `tid` kötelező, `text` a `pid: 2`-nél kötelező, `dbdate` v4-ben kötelező, a válasz `{"error": 0|1, "text": ...}`. A 16 végpont közül egyik sem fogad templomhoz nem kötött üzenetet.
- A spec 0003 6. user storyja („a hibajelentés változatlanul működjön”) ezzel a spec-kel érvényét veszti.
