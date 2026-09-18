# Miserend-Flutter és Miserend-Android: funkcionális összehasonlítás

Ez a dokumentum azt írja le, **mit csinál ma** a két app a kódjuk alapján. Nem javasol fejlesztést. Minden állítás forrása a két repó kódja: a Flutter-hivatkozások ennek a repónak relatív útvonalai (`fájl:sor`), az Android-hivatkozások a lent megadott commitra rögzített GitHub-linkek. A fogalmak a `CONTEXT.md` szótárát követik (pl. **helyi gyorsítótár**, **kezdeti feltöltés**, **legközelebbi misék**, **hibajelentés**, **visszajelzés**, **Nincs kapcsolat**, **Szerverhiba**).

Vizsgált állapot:

- **Flutter**: `szanatil/Miserend-Flutter`, `main` ág, commit `11cff4443ae9d5588bf38d5147934a54611e5955` (2026-09-17).
- **Android**: `bmaczak/Miserend-Android`, alapértelmezett `master` ág, commit [`77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3`][a-commit] (2019-05-17).

---

## 1. Rövid összefoglaló

| | Flutter (App A) | Android (App B) |
|---|---|---|
| Jelleg | Hibrid, **API-elsődleges** kliens. Első indításkor egyszer letölti az SQLite exportot, és feltölti belőle a **helyi gyorsítótárat**. Utána a képernyők a gyorsítótárból rajzolnak, a háttérben a v4 API-t hívják, és a választ visszaírják a gyorsítótárba. | Tisztán **offline, export-alapú** kliens. Minden képernyő a letöltött SQLite exportot kérdezi le (Room). Az API-t csak frissítés-ellenőrzésre és hibajelentésre használja. |
| Platform | Android + iOS (Flutter, Dart SDK ^3.7.2): `pubspec.yaml`, `ios/Runner/Info.plist` | Csak Android. Java, minSdk 16, target/compileSdk 27, Support Library, Room, Dagger, RxJava2, Retrofit: [build.gradle L5-L10, L33-L92][a-gradle] |
| Verzió | `1.0.0+1` (`pubspec.yaml:19`) | `versionName "2.3.4"`, `versionCode 21` ([build.gradle L9-L10][a-gradle-ver]). A GitHub utolsó release-e `v2.2.2` (2018-07-27). A README a Play Áruház oldalára mutat ([README.md][a-readme]). |
| Csomagazonosító | `com.frama.miserend.hu.miserend` (`android/app/build.gradle.kts:28`) | `com.frama.miserend.hu` ([build.gradle L7][a-gradle-ver]). A két azonosító eltér, így a két app külön alkalmazásként települ. |
| Adatforrás | Az SQLite export az `https://miserend.hu/api/v4/sqlite` címről jön (`lib/database/database_manager.dart:14`), egyszer, a **kezdeti feltöltéshez**. Utána az API v4 `church`, `search`, `nearby`, `nearbymasses` és `report` végpontjait hívja HTTPS-en (`lib/api/miserend_api_client.dart:51`, `:103`, `:127`, `:140`, `:209`, `:253`, `:307`). | Az SQLite export a `http://miserend.hu/fajlok/sqlite/miserend_v4.sqlite3` címről jön ([DatabaseManager.java L22-L26][a-dbman-url]). Hívott API v4 végpontok: `GET api/v4/updated/{date}` és `POST api/v4/report` ([MiserendApi.java L19-L23][a-api]), sima `http://` alapcímmel ([ApiModule.java L19][a-apimodule]). |
| Adatfrissítés | Az exportot nem tölti le újra (ADR-0003, `lib/database/database_manager.dart:35-37`). A frissítés képernyőnként, API-hívásokkal történik. | Hetente legfeljebb egyszer megkérdezi az `updated` végpontot. Ha van újabb export, felajánlja a teljes adatbázis újraletöltését ([DatabaseManager.java L27, L75-L84][a-dbman-upd]). |
| Karbantartottság | Aktív fejlesztés alatt: 96 commit, az első 2022-09-03-i, a legutóbbi 2026-09-17-i (`git log`). | Nem karbantartott. A `master` utolsó commitja 2019-05-17-i, a legutolsó push 2019-10-20-i, a `feature/kotlin` ágon (Kotlin-átírás, ott az adatbázis URL-je már `https`). A `develop` utolsó commitja 2018-09-26-i. 5 nyitott issue van (#6, #7, #8, #12, #17, pl. „Image upload”, „Database downloader should use coroutines…”). A repó nincs archiválva. (`gh repo view`, `gh api …/commits/<ág>`, `gh issue list`) |

Megjegyzés: a Flutter app egyes elnevezései az Android appéit követik. Ilyen az adatbázisfájl neve (`miserend.sqlite3`, `localdatabase.sqlite3`), a `DATABASE_LAST_UPDATED` és `SAVED_DATABASE_VERSION` preferenciakulcs, valamint a letöltést kérő dialógus szövege. Összevetés: `lib/database/database_manager.dart:9-10`, `lib/database/local_database.dart:6`, `lib/preferences.dart:4-6`, `lib/splash.dart:80-81`, illetve [DatabaseManager.java L22-L23][a-dbman-url], [DatabaseModule.java L50-L54][a-dbmodule], [Preferences.java L15-L17][a-prefs], [strings.xml L30-L31][a-strings-db].

A `docs/FEATURE-COVERAGE.md` részben elavult. A fejléce egy `V0.1` ági commitot (`91ad952`) nevez meg. A templom-részletezőről szóló szakaszából hiányzik a szentségimádás, a gyóntatás, az elérhetőség, a leírás, az akadálymentesség, a nyelvek, a közösségek, a „Frissítve” lábléc, a miserendi megjegyzés és a fotógaléria (vö. `lib/church_details/church_details_page.dart:107-122`). Ez a dokumentum ezért a kódból dolgozik, nem abból.

---

## 2. Funkciómátrix

Jelölések: ✅ van · ❌ nincs · ◐ részben vagy eltérően (lásd a Megjegyzés oszlopot és a 3. szakaszt).

### Indulás és adatkezelés

| Funkció | Flutter | Android | Megjegyzés |
|---|---|---|---|
| Kötelező export-letöltés első indításkor (dialógus, elutasításkor kilépés) | ✅ | ✅ | Flutter: `lib/splash.dart:75-100`, `:245-271`. Android: [HomeScreenActivity L121-L165, L213-L219][a-home-db] |
| Verzióeltérés miatti újraletöltés (v4) | ✅ | ✅ | Flutter: `lib/database/database_manager.dart:30-33`. Android: [DatabaseManager L60-L65][a-dbman-state] |
| Sérült adatbázis felismerése | ❌ | ✅ | Android: ha a templomok száma 0 vagy `SQLiteDatabaseCorruptException` jön, „Sérült adatbázis” dialógus jelenik meg ([DatabaseManager L53-L59][a-dbman-state], [HomeViewModel L51-L58][a-homevm]) |
| Periodikus export-frissítés (heti ellenőrzés, újraletöltés felajánlása) | ❌ | ✅ | Android-only, lásd 3.1 |
| **Kezdeti feltöltés** a helyi gyorsítótárba (30 nap mise) | ✅ | ❌ | `lib/splash.dart:27-40`, `lib/database/cache/bootstrap_importer.dart:18` |
| Élő API-frissítés a képernyőkön, visszaírással | ✅ | ❌ | Flutter-only, lásd 3.2 |
| **Nincs kapcsolat** / **Szerverhiba** jelölés, automatikus újrapróbálás | ✅ | ❌ | `lib/widgets/stale_data_retry.dart:26` (20 mp) |
| Letöltési hiba kezelése | ◐ | ◐ | Flutter: van „Újrapróbálás” képernyő, vagy a korábbi exporttal megy tovább (`lib/splash.dart:117-139`, `:194-199`). Android: sikertelen letöltés után újra a „nem található” állapotba kerül ([HomeViewModel L71-L78][a-homevm-dl]) |
| Kedvencek napi háttér-előtöltése | ✅ | ❌ | `lib/favorites_prefetch.dart:17`, `lib/home/home.dart:157-164` |

### Navigáció és keresés

| Funkció | Flutter | Android | Megjegyzés |
|---|---|---|---|
| Alsó navigáció: Templomok / Misék / Térkép | ✅ | ✅ | Flutter: `lib/home/home.dart:376-397`. Android: [home_navigation_menu.xml][a-navmenu] |
| Negyedik menüpont („Névjegy” oldal) | ✅ | ❌ | `lib/home/home.dart:231-238`, `lib/about/about_page.dart` |
| Templomok fül: „Közeli” és „Kedvencek” alfül | ✅ | ✅ | Flutter: `lib/home/churches/churches_page.dart:5`. Android: [ChurchesPagerAdapter L24-L41][a-pager] („Közelben”/„Kedvencek”) |
| Keresősáv javaslatokkal (3. karaktertől) | ✅ | ✅ | Eltérő tartalommal, lásd 3.3 |
| Templom- és településjavaslat | ✅ | ✅ | |
| Korábbi keresések javaslatként | ❌ | ◐ | Android: van rá tábla és lekérdezés, de a mentés a kód alapján nem fut le, lásd 3.1 |
| „Részletes kereső” (név + település + dátum + időablak) | ✅ | ✅ | Flutter: templomokat listáz, nyelvvel is szűr (spec 0010); Android: miséket listáz, lásd 3.1 |
| Kis- és nagybetű- meg ékezetfüggetlen keresés, alternatív nevekben is | ✅ | ❌ | Flutter: `lib/database/cache/search_text.dart:10-18`, `lib/database/cache/cache_database.dart:402-423`. Android: SQL `LIKE` a `nev`/`ismertnev` oszlopon ([ChurchDao L23-L27][a-churchdao]) |
| API-os keresés, ha a gyorsítótárban nincs találat | ✅ | ❌ | `lib/home/churches/church_list_loader.dart:134` |

### Templomlisták

| Funkció | Flutter | Android | Megjegyzés |
|---|---|---|---|
| Közeli templomok (összes templom, távolság szerint) | ✅ | ✅ | Flutter: `lib/database/cache/cache_database.dart:375-391`. Android: [ChurchWithMassesDao L21-L22][a-cwmdao], 20-as lapozással ([MiserendRepository L51-L53][a-repo-near]) |
| Légvonal-távolság a kártyán | ◐ | ◐ | Flutter: a Közeli listán és a térképi kártyán, 10 m-re kerekítve (`CONTEXT.md`, `lib/home/churches/church_card.dart:36-39`). Android: Közeli listán és Misék listán, „m”/„0.00 km” formában ([ChurchViewHolder L71-L76, L108-L114][a-chvh]) |
| Kártyán a mai misék időpontjai | ✅ | ✅ | Flutter csak misét mutat (`lib/mass_kind.dart:6-10`), a helyhiányt „…” chip jelzi (`lib/widgets/time_chip.dart:13-19`). Android: a nap összes `misek` sora ([ChurchViewHolder L68-L70][a-chvh]) |
| Mise-chipre koppintva mise-részletek | ◐ | ✅ | Android: a listakártya chipje is megnyitja a „Mise részletei” dialógust ([ChurchViewHolder L80-L87][a-chvh-mass]). Flutter: a listakártya chipje nem koppintható (`lib/home/churches/church_card.dart:263`), csak a részletezőn az, lásd 3.3 |
| Kedvenc kapcsoló a kártyán | ✅ | ✅ | Flutter: `lib/home/churches/church_card.dart:128-143`. Android: [ChurchViewHolder L116-L119][a-chvh-fav] |
| Húzással frissítés | ✅ | ❌ | `lib/home/churches/church_list_view.dart:40` |
| Engedély / helymeghatározás hiányának állapota gombbal | ✅ (4 ok) | ✅ (2 ok) | Flutter: `lib/location_provider.dart:60-77`, `:114-116`. Android: `PERMISSION` / `COULD_NOT_RETRIEVE` ([LocationError][a-locerr], [NearChurchesFragment L85-L109][a-near-loc]) |

### Misék fül

| Funkció | Flutter | Android | Megjegyzés |
|---|---|---|---|
| Közeli mai misék listája | ◐ | ◐ | Más kiválasztás, rendezés, forrás és koppintási cél, lásd 3.3 |
| „Épp most tart” jelölés, hátralévő idő | ✅ | ❌ | `lib/home/masses/nearest_masses.dart:64-95`, `lib/home/masses/mass_card.dart:271` |
| Percenkénti önfrissítés | ✅ | ❌ | `lib/home/masses/near_masses_page.dart:55-66` |

### Térkép

| Funkció | Flutter | Android | Megjegyzés |
|---|---|---|---|
| Az összes templom a térképen | ✅ | ✅ | Flutter: CARTO Voyager csempék (`lib/widgets/miserend_map.dart:67-69`). Android: Google Maps SDK ([ChurchesMapFragment L110-L121][a-map-ready]) |
| Csoportosítás (clustering) | ❌ | ✅ | Android: `google-maps-clustering`, a csoportra koppintva ráközelít ([L123-L153][a-map-cluster]). Flutter: 12-es zoom alatt pöttyök, fölötte tűk (`lib/widgets/miserend_map.dart:39-42`) |
| Templomkártya jelölőre koppintva | ✅ | ✅ | Android: a kártyán a mai misék, kedvenc és mise-dialógus ([L155-L199][a-map-card]). Flutter: API-frissítéssel (`lib/home/map/map_page.dart:185-199`, `:213`) |
| Saját helyzet a térképen, ráugrás | ✅ | ◐ | Flutter: saját pötty és „helyzetem” gomb (`lib/home/map/map_page.dart:163-170`). Android: `setMyLocationEnabled(true)`, ha van engedély, és nyitáskor a helyzetre ugrik 14-es zoommal ([L118-L120, L181-L184][a-map-loc]) |

### Templom-részletező

| Funkció | Flutter | Android | Megjegyzés |
|---|---|---|---|
| Fotók a fejlécben, lapozható | ✅ | ✅ | Flutter: 4 mp-enként magától lapoz (`lib/church_details/widgets/photo_header.dart:31`, `:79-92`). Android: ViewPager pöttyjelzővel ([ChurchDetailsActivity L129-L135][a-det-gal]) |
| Teljes képernyős galéria | ✅ | ✅ | Flutter: `photo_gallery_page.dart:34-65`, „n / m” számlálóval. Android: [GalleryActivity L28-L40][a-gallery] |
| Név, ismert név | ✅ | ✅ | |
| Cím | ◐ | ◐ | Flutter: település + utca, koppintva térképappot nyit (`church_details_page.dart:136-191`). Android: a `geocim` HTML-ként megjelenítve ([L143][a-det-bind]) |
| Kedvencekhez | ✅ | ✅ | |
| Hibajelentés | ✅ | ✅ | Eltérő űrlappal és hibakezeléssel, lásd 3.3 |
| „Ma” és „Most vasárnap” mise-chipek | ✅ | ✅ | Flutter vasárnap nem ismétli (`church_details_page.dart:283-300`) |
| Következő napok miserendje | ◐ | ◐ | Flutter: vízszintes sáv, csak a misés napokkal. Android: függőleges lista 19 nappal, üres napokkal is ([L154-L170][a-det-masses]) |
| Mise-részletek (megjegyzés, periódus, jellemzők) | ◐ | ✅ | Lásd 3.3 |
| Megközelítés: térképkép + szöveg + „Útvonal” | ✅ | ✅ | Flutter: nem interaktív CARTO térkép. Android: Google Static Maps kép ([strings.xml L23][a-strings-static]) |
| Miserendi megjegyzés | ✅ | ❌ | `church_details_page.dart:282`, `:301-310` |
| Szentségimádás | ✅ | ❌ | `lib/church_details/widgets/adoration_card.dart:13-27` |
| „Most gyóntatnak!” (élő kapcsoló) | ✅ | ❌ | `lib/church_details/widgets/confession_tile.dart:12-37` |
| Elérhetőség (e-mail, linkek, plébánia) | ✅ | ❌ | `lib/church_details/widgets/contact_card.dart:48-83` |
| Leírás, akadálymentesség, nyelvek (zászló), közösségek | ✅ | ❌ | `church_details_page.dart:451-469`, `lib/church_details/widgets/church_info_tiles.dart:12-20`, `:88`, `:177` |
| „Frissítve: …” lábléc | ✅ | ❌ | `church_details_page.dart:475-489` |
| Megszűnt templom kezelése | ✅ | ❌ | `church_details_page.dart:273-280` |

### Egyéb

| Funkció | Flutter | Android | Megjegyzés |
|---|---|---|---|
| Kedvencek csak helyben (külön SQLite) | ✅ | ✅ | Flutter: `lib/database/local_database.dart:6`. Android: [LocalDatabase L14][a-localdb] |
| **Visszajelzés** e-mailben | ✅ | ❌ | `lib/widgets/feedback_mail.dart:10`, `:28-32` |
| Névjegy: „Mai templom ajánlatunk”, kiadó és 1%, fejlesztő és verzió, forráskód, miserend.hu link | ✅ | ❌ | `lib/about/about_page.dart` |
| Analitika (képernyőkövetés) | ❌ | ✅ | Firebase Analytics ([Analytics.java L16-L28][a-analytics]) |
| Összeomlás-jelentés | ❌ | ✅ | Crashlytics, csak release buildben ([AndroidManifest L46-L48][a-manifest-crash], [build.gradle L14-L21][a-gradle-crash]) |
| Fiók / bejelentkezés | ❌ | ❌ | Egyik kódban sincs ilyen |
| Értesítés, emlékeztető, widget, megosztás | ❌ | ❌ | Az Android manifestben nincs receiver, service vagy widget ([AndroidManifest][a-manifest]). A kódban nincs `ACTION_SEND`, `Notification` vagy `AppWidget` (grep). A Flutter függőségei között sincs ilyen csomag (`pubspec.yaml`) |
| Lokalizáció | ❌ (csak magyar) | ❌ (csak magyar) | Android: csak `res/values/strings.xml` van, `values-xx` nincs |
| Képernyő-tájolás | szabad | csak álló | Android: `screenOrientation="portrait"` ([AndroidManifest L20, L30-L37][a-manifest-orient]). Flutter: nincs zárolás (`android/app/src/main/AndroidManifest.xml`, `ios/Runner/Info.plist:58-63`) |

---

## 3. Részletek

### 3.1 Csak az Android appban

**Periodikus export-frissítés.** Indításkor a `DatabaseManager.getDatabaseState()` hét naponta legfeljebb egyszer meghívja a `GET api/v4/updated/{utolsó letöltés napja}` végpontot. Ha a válasz `1`, „Frissítés elérhető – Elérhető frisebb adatbázis. Letölti most?” dialógus jelenik meg Igen/Nem gombbal. „Nem” esetén a régi adatokkal megy tovább, „Igen” esetén a teljes SQLite fájlt letölti újra, nem megszakítható „Adatbázis letöltése” folyamatjelző alatt. Források: [DatabaseManager.java L27, L75-L88][a-dbman-upd], [HomeScreenActivity L127-L130, L139-L142, L162-L165, L213-L219][a-home-db], [DatabaseUpdateAvailableDialogFragment L36-L47][a-upddlg], [strings.xml L36-L41][a-strings-db].

**Sérült adatbázis felismerése.** Ha az export megvan, de a `templomok` tábla üres, vagy a lekérdezés `SQLiteDatabaseCorruptException`-t dob, „Sérült adatbázis” dialógus kéri az újraletöltést. Egyéb hibánál, ha a fájl létezik, a meglévő adatokkal megy tovább. Források: [DatabaseManager L53-L59][a-dbman-state], [HomeViewModel L50-L59][a-homevm], [HomeScreenActivity L131-L134, L157-L160][a-home-db].

**Részletes kereső.** A keresősáv javaslatlistájának utolsó eleme mindig a „Részletes kereső” ([SuggestionViewModel L45-L64][a-suggvm]). Ez külön képernyőt nyit a következő mezőkkel: „Templom neve”, „Város” (automatikus kiegészítés az összes település nevéből, 1 karaktertől) és egy „Keresés misére” jelölőnégyzet. Ha a négyzet be van jelölve, megjelenik egy dátumválasztó (alapértéke „ez a vasárnap”), egy „Egész nap” jelölőnégyzet és egy időablak (alapértéke 07:00–20:00). Források: [AdvancedSearchActivity L86-L141][a-adv], [AdvancedSearchViewModel L39-L43][a-advvm], [activity_advanced_search.xml L10-L90][a-advlayout].
- „Keresés misére” nélkül templomlistát ad (név és település részszövegre, `LIMIT 999`), kedvenc kapcsolóval ([SearchResultActivity L40-L46][a-searchres], [ChurchWithMassesDao L36-L39][a-cwmdao]).
- „Keresés misére” mellett **mise-listát** ad az adott napra: a hét napjára szűr SQL-ben, majd a dátumtartományra és az időablakra Java-ban ([MiserendRepository L92-L101][a-repo-mass], [MassesDao L22-L26][a-massesdao], [MassFilter L38-L70][a-massfilter]). Egy sorra koppintva a Google navigáció indul, a bélyegképre koppintva a templom-részletező nyílik ([SearchResultMassListFragment L50-L58][a-resmass]).

**Korábbi keresések.** Van `recent_searches` tábla. A javaslatok között legfeljebb 5 korábbi keresés jelenne meg, üres vagy rövid (≤ 2 karakter) beírásnál csak ezek ([RecentSearchesDao L23][a-recentdao], [SuggestionViewModel L56-L62][a-suggvm]). A mentő metódus viszont csak létrehoz egy `Thread`-et, és nem indítja el (`new Thread(() -> …);` `start()` nélkül). A kód alapján tehát beküldéskor semmi nem kerül a táblába ([SuggestionViewModel L103-L105][a-suggvm-add]). Ezt futtatással nem ellenőriztem.

**Térképi csoportosítás.** A Google Maps térképen a jelölők csoportokba (clusterekbe) rendeződnek, lila háttérrel és egyedi tűikonnal. Egy csoportra koppintva a kamera a csoport elemeire közelít ([ChurchesMapFragment L123-L153][a-map-cluster]).

**Mise-részletek dialógus a listákról és a térképi kártyáról.** A mise-chip minden templomkártyán (Közeli, Kedvencek, keresési találat, térképi kártya) megnyitja a „Mise részletei” dialógust. A chipen „i” ikon jelzi, ha van megjegyzés, jellemző vagy nem heti periódus ([ChurchViewHolder L80-L87][a-chvh-mass], [ViewUtils L44-L47][a-viewutils], [Mass.java L157-L158][a-mass-hasinfo]). A dialógus tartalmát a 3.3 szakasz írja le.

**Analitika és összeomlás-jelentés.** A Firebase Analytics minden fő képernyőn rögzíti a képernyő nevét: „Near churches”, „Favorite churches”, „Masses”, „Map”, „Church details”, „Advanced search”, „Search results” ([Analytics.java L16-L28][a-analytics], pl. [ChurchDetailsActivity L105-L109][a-det-analytics]). Release buildben a Crashlytics is be van kapcsolva ([build.gradle L14-L21][a-gradle-crash], [AndroidManifest L46-L48][a-manifest-crash]).

**Helyengedély kérése már induláskor.** A főképernyő `onCreate`-je azonnal felugró ablakban kéri a helyengedélyt, ha még nincs meg ([HomeScreenActivity L112-L114][a-home-perm]). A Flutter app csak akkor kéri, amikor egy képernyőnek helyzet kell (`lib/location_provider.dart:60-77`).

**Álló tájolás rögzítése.** Minden activity `portrait`, kivéve a galériát ([AndroidManifest L17-L40][a-manifest-orient]).

### 3.2 Csak a Flutter appban

**Helyi gyorsítótár API-frissítéssel.** Első indításkor egyszer lefut a **kezdeti feltöltés**: minden templom és 30 napnyi mise kerül a gyorsítótárba (`lib/splash.dart:27-40`, `:159-184`, `lib/database/cache/bootstrap_importer.dart:18`). Utána minden lista a gyorsítótárból rajzol azonnal, és a háttérben meghívja az API-t: a Közeli lista a `nearby`, a Kedvencek a `church {ids}`, a keresés a `church {ids}` vagy `search`, a térképi kártya a `church {ids}` (full) végpontot. A választ visszaírja, majd újraolvas (`lib/home/churches/church_list_loader.dart:78`, `:98`, `:126-135`, `:171`). A hívások időkorlátja 15 mp, a kapcsolódásé 10 mp (`lib/api/miserend_api_client.dart:55-58`). Ha a miserend.hu egy templomot hiányzónak jelez, az app törli a gyorsítótárból és a kedvencek közül (`lib/home/churches/search_results.dart:54-55`, `lib/church_details/church_details_page.dart:273-280`, `:590`).

**Nincs kapcsolat / Szerverhiba jelölés és önjavítás.** Sikertelen frissítés után a lista fölött sáv (`lib/home/churches/church_list_view.dart:34`), a részletezőn `OfflineBanner` (`church_details_page.dart:93-98`), a térképi kártyán (i) jelzés jelenik meg (`lib/home/map/map_page.dart:185-199`). Amíg a jelölés látszik, a képernyő 20 másodpercenként magától újra próbálkozik (`lib/widgets/stale_data_retry.dart:26`).

**Kedvencek előtöltése.** Indítás után, 24 óránként legfeljebb egyszer, a háttérben letölti az összes kedvenc templomot és 20 napos miserendjüket (`lib/favorites_prefetch.dart:17`, `:101`, `lib/home/home.dart:157-164`).

**Legközelebbi misék élő API-ból.** A Misék fül a `nearbymasses` végpontot hívja 200 km-es sugárral (`lib/api/miserend_api_client.dart:74`, `:247-259`). A választ helyben szűri: csak **misék**, amelyek még **elérhetők** (legfeljebb 10 perce kezdődtek), holnap 00:00-ig, a 10 legközelebbi templomból. A lista időrendben áll (`lib/home/masses/nearest_masses.dart:7-45`). Megjelenik rajta az „Épp most tart” jelölés, 2 órán belüli kezdésnél pedig a hátralévő idő („25 perc múlva”) (`nearest_masses.dart:64-95`). A lista percenként újraszűr, és újra letölt fülváltáskor, az app előtérbe kerülésekor és éjfél után (`lib/home/masses/near_masses_page.dart:15-22`, `:55-66`).

**Templom-részletező bővebb tartalommal** (`lib/church_details/church_details_page.dart:107-122`):
- miserendi megjegyzés kinyitható szövegként (`:282`, `:301-310`);
- **Szentségimádás** kártya (`widgets/adoration_card.dart:13-27`);
- „Most gyóntatnak!” kártya, csak friss `true` API-értéknél (`widgets/confession_tile.dart:12-37`, `CONTEXT.md` „Gyóntatás”);
- „Elérhetőség”: koppintható e-mail (`mailto:`), a templom saját linkjei hosztnévvel, plébánia szövege (`widgets/contact_card.dart:48-122`);
- „Leírás”, „Akadálymentesség” (kerekesszékes megközelíthetőség), „Nyelvek” (zászlókkal), „Közösségek” (`church_details_page.dart:451-469`, `widgets/church_info_tiles.dart:12-20`, `:88-135`, `:177-188`);
- „Frissítve: <dátum>” lábléc a miserend.hu szerkesztési dátumával (`:475-489`);
- „Ez a templom már nem szerepel a miserend.hu-n.” a megszűnt templomoknál (`:273-280`);
- a mise-chipnél megkülönbözteti a „nincs mise” és a „nincs adat” esetet (`:321-347`).

**Hibajelentés tiltása kapcsolat nélkül.** Amíg a részletező Nincs kapcsolat vagy Szerverhiba jelölést mutat, a „Hibajelentés” gomb szürke. Koppintásra csak egy magyarázó SnackBar jelenik meg (`church_details_page.dart:224-251`).

**Névjegy oldal és visszajelzés.** Az alsó navigáció negyedik eleme a „Névjegy” oldalt nyitja (`lib/home/home.dart:231-238`). Rajta, fentről lefelé (`lib/about/about_page.dart`):
- „Visszajelzés” gomb: e-mail a `szentjozsefhackathon@jezsuita.hu` címre, az app verziójával és az OS-sel (`lib/widgets/feedback_mail.dart:10`, `:28-32`, `:54-59`);
- „Mai templom ajánlatunk” kártya: fényképes templom dátumhoz kötött választással, fotóval, címmel és 4 soros leírással; koppintásra a részletező nyílik (`lib/about/church_of_the_day_loader.dart`);
- „Kiadó”: a Rendtartomány, jezsuita.hu link, 1% a Jézus Társasága Alapítványnak másolható adószámmal;
- „Fejlesztő”: Szent József Hackathon, a verzióval;
- „Forráskód”: a GitHub-repó linkje;
- miserend.hu link a böngészőbe.

**iOS-támogatás.** Van `ios/` célplatform helyengedély-szöveggel (`ios/Runner/Info.plist:29-30`).

**Húzással frissítés** a templomlistákon (`lib/home/churches/church_list_view.dart:40`) és a Misék fülön (`near_masses_page.dart`, lásd a fájl fejkommentjét, `:15-22`).

**Ékezetfüggetlen keresés alternatív nevekben is**, név szerinti találatok elöl (`lib/database/cache/cache_database.dart:393-423`, `lib/database/cache/search_text.dart:1-18`).

### 3.3 Mindkettőben, de eltérően

**Keresősáv és javaslatok.**
- *Flutter*: a keresősáv az AppBar-ban van. 3 karaktertől, 250 ms-os késleltetéssel legfeljebb 20 templomot és a hozzájuk illő településeket javasolja a gyorsítótárból, API-hívás nélkül (`lib/home/home.dart:262-291`, `lib/home/search_suggestions.dart:17-30`). Beküldéskor név, alternatív név vagy település részszövegére keres (`lib/home/churches/search_results.dart:24-27`, `lib/database/cache/cache_database.dart:402-423`). Településjavaslatra koppintva **pontos** településnévre szűr (`cache_database.dart:426-439`). A találati lista húzással frissíthető, és a háttérben az API-t is hívja.
- *Android*: lebegő `MaterialSearchBar`, legfeljebb 5 javaslattal ([activity_home.xml L40-L52][a-home-layout]). 3 karaktertől templomot (`nev`/`ismertnev` `LIKE`), települést és korábbi keresést javasol, a lista végén mindig ott a „Részletes kereső” ([SuggestionViewModel L45-L64][a-suggvm], [ChurchDao L23-L27][a-churchdao]). Beküldéskor csak névre és ismert névre keres, településre nem ([MiserendRepository L67-L73][a-repo-search], [ChurchWithMassesDao L32-L34][a-cwmdao]). Településjavaslatra koppintva `varos LIKE '%…%'`, vagyis részszöveges egyezés ([ChurchWithMassesDao L36-L39][a-cwmdao]).

**Misék fül.**
- *Flutter*: élő API, a 10 legközelebbi templom összes még elérhető mai miséje **időrendben**. A lista csak misét tartalmaz, és mutatja az „Épp most tart” jelölést és a hátralévő időt. Egy sorra koppintva a **templom-részletező** nyílik (`lib/home/masses/near_masses_page.dart:265`, `:291-296`, és 3.2).
- *Android*: offline, az exportból dolgozik. A mai nap miséi közül azokat veszi, amelyek **még nem kezdődtek el** (`isAfter(now)`), legfeljebb 500 (templom, mise) sort a legközelebbi templomoktól, **távolság szerint** rendezve ([MiserendRepository L75-L90][a-repo-rec], [MassesDao L18-L20][a-massesdao], [MassComparator L22-L26][a-masscomp]). Egy sorra koppintva **Google Maps navigáció** indul, a bélyegképre koppintva a templom-részletező nyílik ([MassesFragment L111-L119][a-masses-click]). A kártyán kép, templomnév, időpont és távolság látszik ([MassesAdapter L91-L110][a-massesadapter]). Az SQL a `nap = <a hét napja>` sorokat kéri le, a Java-szűrő viszont a `nap = 0` értéket is elfogadná ([MassesDao L19][a-massesdao], [MassFilter L52-L54][a-massfilter]). Hogy ez kihagy-e miséket, a kódból nem dönthető el (lásd 4.).

**Közeli templomok.**
- *Flutter*: helyzetnek csak a legfeljebb 5 perces pozíció számít, egyébként új helymeghatározás jön 15 mp-es időkorláttal (`lib/location_provider.dart:42-45`). A helyzet hiányának négy okát különbözteti meg, mindegyikhez saját gombbal. A lista a gyorsítótár összes templomát mutatja, és a háttérben `nearby` API-hívás frissíti (lásd 3.2).
- *Android*: a `FusedLocationProviderClient.getLastLocation()` eredményét használja, frissességi feltétel nélkül. Két hibaállapotot ismer: „Pozíció nem elérhető…” a Beállítások gombbal, illetve „A közeli templomok megjelenítéséhez…” az Engedélyezés gombbal ([LocationRepository L38-L54][a-loc], [LocationPermissionHelper L29-L52][a-locperm], [strings.xml L43-L47][a-strings-loc]). A lista 20-as lapokban tölt ([MiserendRepository L51-L53][a-repo-near]).

**Kedvencek.** Mindkét app csak helyben tárolja őket, külön SQLite fájlban. *Flutter*: név szerint rendez, a háttérben `church {ids}` API-hívással frissít, és a miserend.hu-ról eltűnt kedvencet magától eltávolítja (`lib/home/churches/church_list_loader.dart:82-99`, `lib/database/cache/cache_database.dart:454-471`, `lib/home/churches/favorite_churches.dart:29`). Üres állapot: „Még nincsenek kedvenc templomaid.” (`lib/home/churches/favorite_churches.dart:74`). *Android*: `SELECT … WHERE tid IN (…)` explicit rendezés nélkül ([ChurchWithMassesDao L24-L26][a-cwmdao]). Üres állapot: „Még nincs kedvencekhez adott templom” ([strings.xml L49][a-strings-fav]).

**Térkép.**
- *Flutter*: CARTO Voyager csempék, Magyarország-nézetből indul, és a helyzetre ugrik, ha az ismert. 12-es zoom alatt pöttyök, fölötte tűk, a kiválasztott tű nagyobb (`lib/widgets/miserend_map.dart:36-54`). A kártyát a gyorsítótárból azonnal mutatja, majd full API-hívással frissíti. A „helyzetem” gomb SnackBar-ban magyarázza el, ha nincs helyzet (`lib/home/map/map_page.dart:140-199`).
- *Android*: Google Maps SDK csoportosítással. Csak a nem 0,0 koordinátájú templomokat mutatja ([ChurchDao L20-L21][a-churchdao]). Helyzetnél 14-es zoommal odaugrik. A jelölőre koppintva a kártya úgy jelenik meg, hogy a kamera a kártya fölé igazítja a pontot, a térképre koppintva a kártya eltűnik ([ChurchesMapFragment L133, L155-L184][a-map-card]).

**Templom-részletező: miserend-nézet.**
- *Flutter*: „Ma” és „Most vasárnap” chipek (vasárnap csak „Ma”), alattuk vízszintesen görgethető napkártyák, csak a misés napokkal („Holnap” / hét napja + dátum). Az adat a gyorsítótárból jön, 20 napos API-frissítéssel (`church_details_page.dart:272-420`, `lib/church_details/church_schedule_loader.dart:15`).
- *Android*: „Ma” és „Most vasárnap” flexbox-chipek, alattuk **függőleges** lista a következő 19 napról, a mise nélküli napokkal együtt. Ha a templomhoz egyáltalán nincs mise: „A templomhoz nem tartozik mise” ([ChurchDetailsActivity L154-L188][a-det-masses], [activity_church_details.xml L159-L209][a-detlayout]).

**Mise-részletek.**
- *Flutter*: csak a részletező chipjein koppintható, és csak ha az `informacio` nem általános („Szentmise”, „Római katolikus szentmise” stb.). Alsó lapon az időpontot és az információs szöveget mutatja (`lib/church_details/widgets/mass_info.dart:11-49`).
- *Android*: dialógus a megjegyzéssel, a nem magyar nyelvvel („Nyelv: …”), a periódussal („Minden héten”, „Csak páros heteken”, „Csak páratlan heteken”, „Csak utolsó heteken”, „Csak a hónap N. hetén”), az időszakkal (`idoszak`) és a jellemzőkkel. A jellemzők: Gitáros, Csendes, Családos / gyerek, Diák, Egyetemista / ifjúsági, Igeliturgia, Szentségimádás, Utrenye, Vecsernye, Görögkatolikus, Római katolikus, Régi rítusú; számmal jelölve „minden N. héten”. Források: [MassDetailsDialogFragment L58-L87][a-massdlg], [MassTag L14-L45][a-masstag], [strings.xml L63-L75][a-strings-tags]. Az adat mise-szintű mezőkből jön (`nyelv`, `milyen`, `periodus`, `idoszak`, `megjegyzes`: [Mass.java L27-L55][a-mass]).

**Megközelítés és útvonal.**
- *Flutter*: nem interaktív CARTO térkép tűvel. A térképre vagy a címre koppintva, illetve az „ÚTVONAL” gombra a készülék **első telepített** térképalkalmazása nyílik (`map_launcher`), választó nélkül. Ha nincs térképapp, SnackBar jelenik meg (`church_details_page.dart:491-541`, `:599-640`).
- *Android*: Google Static Maps kép (az API-kulcs a `strings.xml`-ben van). Koppintásra `geo:` intent megy ki, így a rendszer választja ki a kezelő appot. Az „Útvonal” gomb `https://maps.google.com/maps?f=d&daddr=lat,lon` URL-t nyit ([Router L51-L64][a-router], [strings.xml L23, L77][a-strings-static], [ChurchDetailsActivity L209-L217][a-det-nav]).

**Hibajelentés.** Mindkét app a `POST api/v4/report` végpontot hívja `tid`, `pid` (0 = rossz pozíció, 1 = rossz miseidőpont, 2 = egyéb), `text`, `email` és `dbdate` mezőkkel.
- *Flutter*: teljes képernyős oldal a templom nevével. Kezdetben nincs kiválasztott típus, és a típust kötelező választani. A leírás kötelező, az e-mail formátumát ellenőrzi. Küldés közben pörgő jelzés látszik. Siker után „Hibajelentés elküldve” üzenet jön, és az app megjegyzi az e-mail címet a következő jelentéshez. Hibánál az oldal és a beírt szöveg megmarad, a Nincs kapcsolat és a Szerverhiba külön üzenetet kap. A `dbdate` a részletező adatainak kora. Források: `lib/church_details/report_problem_page.dart:41`, `:90-164`, `:200-255`, `lib/api/miserend_api_client.dart:299-312`.
- *Android*: dialógus. Alapból a „Rossz pozíció” van kiválasztva, a leírás és az e-mail nincs ellenőrizve, és az app nem jegyzi meg őket. Az „ok” gomb azonnal bezárja a dialógust, a szerver `text` válasza Toast-ban jelenik meg. A `subscribe` hívás nem kap hibakezelőt. A `dbdate` az export utolsó letöltésének napja. Források: [dialog_report.xml L15-L45][a-reportlayout], [ReportDialogFragment L80-L120][a-report], [ReportProblemBody L11-L20][a-reportbody].

**Hely-engedély és -beállítások.** Mindkét app megnyitja az alkalmazás- és a helybeállításokat. *Android*: ha a rendszer már nem mutat magyarázatot, az app a beállításokat nyitja, és visszatéréskor újraolvassa a pozíciót ([LocationPermissionHelper L29-L52][a-locperm], [HomeScreenActivity L191-L205][a-home-perm2]). *Flutter*: `lib/location_provider.dart:60-77`, `:114-116`. A Térkép fül visszatéréskor újra ellenőriz (`lib/home/map/map_page.dart:106-130`).

**Fotók.** *Flutter*: a fejléc 4 másodpercenként magától lapoz, amíg a felhasználó hozzá nem nyúl. A galéria sötét, „n / m” számlálóval (`photo_header.dart:9-12`, `:79-92`, `photo_gallery_page.dart:34-65`). *Android*: ViewPager pöttyjelzővel, automatikus lapozás nélkül. A galéria teljes képernyős, és mindig az első képnél nyílik, mert a kattintott kép indexe nem jut át ([ChurchDetailsActivity L219-L226][a-det-gal2], [GalleryActivity L28-L40][a-gallery]).

---

## 4. Nyitott kérdések és bizonytalanságok

1. **Az Android Play Áruházas változata.** A README a Play Áruházra mutat, de hogy ott ma melyik build érhető el, és egyáltalán elérhető-e még, azt nem ellenőriztem. A GitHub utolsó release-e (`v2.2.2`) régebbi, mint a kódban álló `2.3.4`.
2. **`feature/kotlin` ág.** 18 commit előnyben van a `master`-hez képest (2019-03 és 2019-10 között). Az ág főleg Kotlin-átírás, az utolsó commitok egyike az adatbázis URL-jét `https`-re állítja (`gh api …/compare/master...feature/kotlin`). Funkcionális eltérést nem vizsgáltam, ez a dokumentum a `master`-t írja le.
3. **Az Android export-URL-je működik-e még.** A kód a `http://miserend.hu/fajlok/sqlite/miserend_v4.sqlite3` címet és a `GET api/v4/updated/{date}` végpontot használja. Hogy ezek ma válaszolnak-e, nem ellenőriztem. A Flutter a dokumentált `api/v4/sqlite` végpontot hívja.
4. **Korábbi keresések Androidon.** A kód szerint a `Thread` nem indul el, így a mentés nem történik meg ([SuggestionViewModel L103-L105][a-suggvm-add]). Az app nem futott, a viselkedés nincs megfigyelve.
5. **Hibajelentés hibaága Androidon.** A `subscribe(this::onReportSent)` nem kap hibakezelőt ([ReportDialogFragment L112-L115][a-report]). Hogy hálózati hibánál mi történik (néma hiba vagy összeomlás), az RxJava globális hibakezelőjétől függ. Ezt nem vizsgáltam.
6. **`nap = 0` misék Androidon.** A `MassFilter` a `nap == 0` értéket minden napra érvényesnek veszi, a Misék fül és a részletes kereső SQL-je viszont csak `nap = <a hét napja>` sorokat kér le ([MassFilter L52-L54][a-massfilter], [MassesDao L19, L25][a-massesdao]). Hogy az export tartalmaz-e `nap = 0` sort, és mit jelent, nem ellenőriztem.
7. **„Egész nap” alapállapot Androidon.** A layoutban az „Egész nap” jelölőnégyzet `checked="true"`, a ViewModelben az `allDay` alapértéke `false` ([activity_advanced_search.xml L45-L49][a-advlayout], [AdvancedSearchViewModel L27-L31][a-advvm-fields]). Hogy a ButterKnife `@OnCheckedChanged` a kezdőállapotra is lefut-e, így melyik érvényes a kereséskor, futtatás nélkül nem egyértelmű.
8. **Android saját-helyzet gomb a térképen.** A `setMyLocationEnabled(true)` a Google Maps SDK-ban alapból „my location” gombot is ad. A kód nem kapcsolja ki, de a megjelenést nem ellenőriztem.
9. **Akadálymentesség (képernyőolvasó).** Az Android layoutokban nincs `contentDescription` (grep: 0 találat). A Flutter kódban 5 `Tooltip`/`semanticLabel` előfordulás van. A tényleges képernyőolvasós használhatóságot egyik appnál sem mértem.
10. **Távolság számítása.** Az Android `Location.distanceTo` eredményét méterben vagy „%.2f km” formában írja ki. A kódban nincs rögzítve, hogy a tizedesjel pont vagy vessző: a `String.format` alapértelmezett locale-t használ ([ChurchViewHolder L108-L114][a-chvh]).

---

<!-- Android hivatkozások, a 77bf87b commitra rögzítve -->
[a-commit]: https://github.com/bmaczak/Miserend-Android/tree/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3
[a-readme]: https://github.com/bmaczak/Miserend-Android/blob/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3/README.md
[a-gradle]: https://github.com/bmaczak/Miserend-Android/blob/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3/app/build.gradle#L5-L92
[a-gradle-ver]: https://github.com/bmaczak/Miserend-Android/blob/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3/app/build.gradle#L5-L10
[a-gradle-crash]: https://github.com/bmaczak/Miserend-Android/blob/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3/app/build.gradle#L14-L21
[a-manifest]: https://github.com/bmaczak/Miserend-Android/blob/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3/app/src/main/AndroidManifest.xml
[a-manifest-orient]: https://github.com/bmaczak/Miserend-Android/blob/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3/app/src/main/AndroidManifest.xml#L17-L40
[a-manifest-crash]: https://github.com/bmaczak/Miserend-Android/blob/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3/app/src/main/AndroidManifest.xml#L42-L48
[a-api]: https://github.com/bmaczak/Miserend-Android/blob/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3/app/src/main/java/com/frama/miserend/hu/api/MiserendApi.java#L19-L23
[a-apimodule]: https://github.com/bmaczak/Miserend-Android/blob/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3/app/src/main/java/com/frama/miserend/hu/application/di/ApiModule.java#L19
[a-dbman-url]: https://github.com/bmaczak/Miserend-Android/blob/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3/app/src/main/java/com/frama/miserend/hu/database/miserend/manager/DatabaseManager.java#L22-L27
[a-dbman-state]: https://github.com/bmaczak/Miserend-Android/blob/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3/app/src/main/java/com/frama/miserend/hu/database/miserend/manager/DatabaseManager.java#L50-L73
[a-dbman-upd]: https://github.com/bmaczak/Miserend-Android/blob/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3/app/src/main/java/com/frama/miserend/hu/database/miserend/manager/DatabaseManager.java#L75-L88
[a-dbmodule]: https://github.com/bmaczak/Miserend-Android/blob/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3/app/src/main/java/com/frama/miserend/hu/di/modules/DatabaseModule.java#L43-L54
[a-upddlg]: https://github.com/bmaczak/Miserend-Android/blob/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3/app/src/main/java/com/frama/miserend/hu/database/dialog/DatabaseUpdateAvailableDialogFragment.java#L36-L47
[a-prefs]: https://github.com/bmaczak/Miserend-Android/blob/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3/app/src/main/java/com/frama/miserend/hu/preferences/Preferences.java#L15-L17
[a-home-db]: https://github.com/bmaczak/Miserend-Android/blob/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3/app/src/main/java/com/frama/miserend/hu/home/view/HomeScreenActivity.java#L121-L219
[a-home-perm]: https://github.com/bmaczak/Miserend-Android/blob/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3/app/src/main/java/com/frama/miserend/hu/home/view/HomeScreenActivity.java#L112-L114
[a-home-perm2]: https://github.com/bmaczak/Miserend-Android/blob/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3/app/src/main/java/com/frama/miserend/hu/home/view/HomeScreenActivity.java#L191-L205
[a-home-layout]: https://github.com/bmaczak/Miserend-Android/blob/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3/app/src/main/res/layout/activity_home.xml#L40-L52
[a-homevm]: https://github.com/bmaczak/Miserend-Android/blob/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3/app/src/main/java/com/frama/miserend/hu/home/viewmodel/HomeViewModel.java#L46-L61
[a-homevm-dl]: https://github.com/bmaczak/Miserend-Android/blob/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3/app/src/main/java/com/frama/miserend/hu/home/viewmodel/HomeViewModel.java#L63-L81
[a-navmenu]: https://github.com/bmaczak/Miserend-Android/blob/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3/app/src/main/res/menu/home_navigation_menu.xml
[a-pager]: https://github.com/bmaczak/Miserend-Android/blob/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3/app/src/main/java/com/frama/miserend/hu/home/pages/churches/view/ChurchesPagerAdapter.java#L24-L41
[a-suggvm]: https://github.com/bmaczak/Miserend-Android/blob/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3/app/src/main/java/com/frama/miserend/hu/search/suggestions/viewmodel/SuggestionViewModel.java#L45-L64
[a-suggvm-add]: https://github.com/bmaczak/Miserend-Android/blob/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3/app/src/main/java/com/frama/miserend/hu/search/suggestions/viewmodel/SuggestionViewModel.java#L103-L105
[a-recentdao]: https://github.com/bmaczak/Miserend-Android/blob/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3/app/src/main/java/com/frama/miserend/hu/database/local/dao/RecentSearchesDao.java#L23
[a-churchdao]: https://github.com/bmaczak/Miserend-Android/blob/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3/app/src/main/java/com/frama/miserend/hu/database/miserend/dao/ChurchDao.java#L20-L30
[a-cwmdao]: https://github.com/bmaczak/Miserend-Android/blob/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3/app/src/main/java/com/frama/miserend/hu/database/miserend/dao/ChurchWithMassesDao.java#L20-L39
[a-massesdao]: https://github.com/bmaczak/Miserend-Android/blob/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3/app/src/main/java/com/frama/miserend/hu/database/miserend/dao/MassesDao.java#L18-L26
[a-repo-near]: https://github.com/bmaczak/Miserend-Android/blob/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3/app/src/main/java/com/frama/miserend/hu/repository/MiserendRepository.java#L51-L53
[a-repo-search]: https://github.com/bmaczak/Miserend-Android/blob/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3/app/src/main/java/com/frama/miserend/hu/repository/MiserendRepository.java#L67-L73
[a-repo-rec]: https://github.com/bmaczak/Miserend-Android/blob/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3/app/src/main/java/com/frama/miserend/hu/repository/MiserendRepository.java#L75-L90
[a-repo-mass]: https://github.com/bmaczak/Miserend-Android/blob/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3/app/src/main/java/com/frama/miserend/hu/repository/MiserendRepository.java#L92-L101
[a-adv]: https://github.com/bmaczak/Miserend-Android/blob/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3/app/src/main/java/com/frama/miserend/hu/search/advanced/AdvancedSearchActivity.java#L86-L141
[a-advvm]: https://github.com/bmaczak/Miserend-Android/blob/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3/app/src/main/java/com/frama/miserend/hu/search/advanced/AdvancedSearchViewModel.java#L39-L59
[a-advvm-fields]: https://github.com/bmaczak/Miserend-Android/blob/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3/app/src/main/java/com/frama/miserend/hu/search/advanced/AdvancedSearchViewModel.java#L27-L43
[a-advlayout]: https://github.com/bmaczak/Miserend-Android/blob/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3/app/src/main/res/layout/activity_advanced_search.xml#L10-L90
[a-searchres]: https://github.com/bmaczak/Miserend-Android/blob/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3/app/src/main/java/com/frama/miserend/hu/search/result/view/SearchResultActivity.java#L40-L46
[a-resmass]: https://github.com/bmaczak/Miserend-Android/blob/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3/app/src/main/java/com/frama/miserend/hu/search/result/mass/view/SearchResultMassListFragment.java#L50-L58
[a-massfilter]: https://github.com/bmaczak/Miserend-Android/blob/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3/app/src/main/java/com/frama/miserend/hu/home/pages/churches/filter/MassFilter.java#L38-L70
[a-chvh]: https://github.com/bmaczak/Miserend-Android/blob/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3/app/src/main/java/com/frama/miserend/hu/home/pages/churches/view/ChurchViewHolder.java#L59-L114
[a-chvh-mass]: https://github.com/bmaczak/Miserend-Android/blob/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3/app/src/main/java/com/frama/miserend/hu/home/pages/churches/view/ChurchViewHolder.java#L80-L87
[a-chvh-fav]: https://github.com/bmaczak/Miserend-Android/blob/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3/app/src/main/java/com/frama/miserend/hu/home/pages/churches/view/ChurchViewHolder.java#L116-L119
[a-viewutils]: https://github.com/bmaczak/Miserend-Android/blob/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3/app/src/main/java/com/frama/miserend/hu/utils/ViewUtils.java#L44-L47
[a-near-loc]: https://github.com/bmaczak/Miserend-Android/blob/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3/app/src/main/java/com/frama/miserend/hu/home/pages/churches/near/NearChurchesFragment.java#L85-L109
[a-locerr]: https://github.com/bmaczak/Miserend-Android/blob/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3/app/src/main/java/com/frama/miserend/hu/location/LocationError.java#L3-L5
[a-loc]: https://github.com/bmaczak/Miserend-Android/blob/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3/app/src/main/java/com/frama/miserend/hu/location/LocationRepository.java#L38-L54
[a-locperm]: https://github.com/bmaczak/Miserend-Android/blob/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3/app/src/main/java/com/frama/miserend/hu/location/LocationPermissionHelper.java#L29-L52
[a-localdb]: https://github.com/bmaczak/Miserend-Android/blob/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3/app/src/main/java/com/frama/miserend/hu/database/local/LocalDatabase.java#L14
[a-masses-click]: https://github.com/bmaczak/Miserend-Android/blob/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3/app/src/main/java/com/frama/miserend/hu/home/pages/masses/view/MassesFragment.java#L111-L119
[a-massesadapter]: https://github.com/bmaczak/Miserend-Android/blob/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3/app/src/main/java/com/frama/miserend/hu/home/pages/masses/view/MassesAdapter.java#L91-L120
[a-masscomp]: https://github.com/bmaczak/Miserend-Android/blob/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3/app/src/main/java/com/frama/miserend/hu/home/pages/masses/model/MassComparator.java#L22-L26
[a-map-ready]: https://github.com/bmaczak/Miserend-Android/blob/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3/app/src/main/java/com/frama/miserend/hu/home/pages/map/view/ChurchesMapFragment.java#L110-L121
[a-map-cluster]: https://github.com/bmaczak/Miserend-Android/blob/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3/app/src/main/java/com/frama/miserend/hu/home/pages/map/view/ChurchesMapFragment.java#L123-L153
[a-map-card]: https://github.com/bmaczak/Miserend-Android/blob/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3/app/src/main/java/com/frama/miserend/hu/home/pages/map/view/ChurchesMapFragment.java#L133-L199
[a-map-loc]: https://github.com/bmaczak/Miserend-Android/blob/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3/app/src/main/java/com/frama/miserend/hu/home/pages/map/view/ChurchesMapFragment.java#L118-L184
[a-det-gal]: https://github.com/bmaczak/Miserend-Android/blob/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3/app/src/main/java/com/frama/miserend/hu/churchdetails/view/ChurchDetailsActivity.java#L129-L135
[a-det-gal2]: https://github.com/bmaczak/Miserend-Android/blob/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3/app/src/main/java/com/frama/miserend/hu/churchdetails/view/ChurchDetailsActivity.java#L219-L226
[a-det-bind]: https://github.com/bmaczak/Miserend-Android/blob/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3/app/src/main/java/com/frama/miserend/hu/churchdetails/view/ChurchDetailsActivity.java#L137-L147
[a-det-masses]: https://github.com/bmaczak/Miserend-Android/blob/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3/app/src/main/java/com/frama/miserend/hu/churchdetails/view/ChurchDetailsActivity.java#L154-L188
[a-det-nav]: https://github.com/bmaczak/Miserend-Android/blob/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3/app/src/main/java/com/frama/miserend/hu/churchdetails/view/ChurchDetailsActivity.java#L199-L217
[a-det-analytics]: https://github.com/bmaczak/Miserend-Android/blob/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3/app/src/main/java/com/frama/miserend/hu/churchdetails/view/ChurchDetailsActivity.java#L105-L109
[a-detlayout]: https://github.com/bmaczak/Miserend-Android/blob/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3/app/src/main/res/layout/activity_church_details.xml#L159-L209
[a-gallery]: https://github.com/bmaczak/Miserend-Android/blob/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3/app/src/main/java/com/frama/miserend/hu/gallery/GalleryActivity.java#L28-L40
[a-massdlg]: https://github.com/bmaczak/Miserend-Android/blob/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3/app/src/main/java/com/frama/miserend/hu/massdetails/view/MassDetailsDialogFragment.java#L58-L87
[a-masstag]: https://github.com/bmaczak/Miserend-Android/blob/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3/app/src/main/java/com/frama/miserend/hu/massdetails/model/MassTag.java#L14-L45
[a-mass]: https://github.com/bmaczak/Miserend-Android/blob/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3/app/src/main/java/com/frama/miserend/hu/database/miserend/entities/Mass.java#L27-L55
[a-mass-hasinfo]: https://github.com/bmaczak/Miserend-Android/blob/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3/app/src/main/java/com/frama/miserend/hu/database/miserend/entities/Mass.java#L157-L158
[a-router]: https://github.com/bmaczak/Miserend-Android/blob/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3/app/src/main/java/com/frama/miserend/hu/router/Router.java#L51-L70
[a-report]: https://github.com/bmaczak/Miserend-Android/blob/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3/app/src/main/java/com/frama/miserend/hu/report/view/ReportDialogFragment.java#L80-L120
[a-reportlayout]: https://github.com/bmaczak/Miserend-Android/blob/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3/app/src/main/res/layout/dialog_report.xml#L15-L45
[a-reportbody]: https://github.com/bmaczak/Miserend-Android/blob/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3/app/src/main/java/com/frama/miserend/hu/report/model/ReportProblemBody.java#L11-L20
[a-analytics]: https://github.com/bmaczak/Miserend-Android/blob/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3/app/src/main/java/com/frama/miserend/hu/firebase/Analytics.java#L16-L28
[a-strings-db]: https://github.com/bmaczak/Miserend-Android/blob/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3/app/src/main/res/values/strings.xml#L30-L41
[a-strings-loc]: https://github.com/bmaczak/Miserend-Android/blob/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3/app/src/main/res/values/strings.xml#L43-L47
[a-strings-fav]: https://github.com/bmaczak/Miserend-Android/blob/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3/app/src/main/res/values/strings.xml#L49
[a-strings-static]: https://github.com/bmaczak/Miserend-Android/blob/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3/app/src/main/res/values/strings.xml#L23
[a-strings-tags]: https://github.com/bmaczak/Miserend-Android/blob/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3/app/src/main/res/values/strings.xml#L63-L75
