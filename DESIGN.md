# Design-szabályok

A Miserend Flutter felhasználói felületének írott szabályai: szín, tipográfia, térköz, forma, mélység, elrendezés, navigáció, platformkülönbségek, ikonok, mozgás, komponensek, akadálymentesség és szövegezés. Minden UI-szabály itt áll, a [CODING_STANDARDS.md](CODING_STANDARDS.md)-ben egy sem. Minden szabálynak azonosítója van (pl. **SZ3**), a review ezzel hivatkozik rá.

A dokumentum a **célt** írja elő, nem a kód mai állapotát. A szabály **pontos** egyezést kér: a 10-es lekerekítés a 12 helyett, a „majdnem ugyanaz a lila", a 14-es térköz a 16 helyett eltérés, és minden eltérés **bug**. Ahol a kód még nem követi a szabályt, a szabály alatt „_Ismert eltérés: #issue_" sor áll; az ilyen hely az issue lezárásáig tűrt, új eltérés nem.

Ha jó okkal térsz el egy szabálytól, ugyanabban a PR-ben módosítsd a szabályt.

Kapcsolódó források: fogalmak a [CONTEXT.md](CONTEXT.md)-ben, a platformstratégia indoka az [ADR-0004](docs/adr/0004-kozos-material-3-alap-platformhu-adaptiv-elemekkel.md)-ben, képernyőnként a viselkedés a [docs/spec/](docs/spec/)-ben.

## Szótár

| Szó | Jelentés |
|---|---|
| **Token** | Egy nevesített design-érték (szín-szerep, térköz, lekerekítés, időtartam). A widget csak tokent használ, nyers számot vagy színt nem. |
| **Szerep** | Egy szín jelentése (`primary`, `surfaceContainerLow`, `occasionTime`…), nem az értéke. Világos és sötét módban más az értéke, a szerepe ugyanaz. |
| **Kártya** | Egy önálló tartalmi egység a listán (alkalomkártya, templomkártya, térképi kártya). |
| **Alkalomkártya** | Egy **alkalom** (CONTEXT.md, „Alkalom") kártyája; a **misekártya** ennek a mise fajtájú változata. |
| **Csempe** | Angolul *tile*: egy soros, koppintható listaelem (Flutterben `ListTile`, nálunk a `*Tile` widgetek, pl. `ExpandableInfoTile`). |
| **Chip** | **Adatot** hordozó kis elem egy kártyán vagy sorban: időpont, távolság, a mise jellemzője, nyelv. Lehet interaktív (pl. szűrő-chip). |
| **Badge** | **Állapotot** jelző elem: valami *most* más, mint általában, vagy figyelmet kér. Soha nem interaktív. Ld. KO6. |
| **Időblokk** | Az alkalom idejének vizuális formája (kezdés vagy időablak). A formáját külön spec rögzíti; addig az időpont-chip (KO3) áll a helyén. |
| **Szalag** | A lista vagy a képernyő tetején, teljes szélességben álló állapotsáv (nincs kapcsolat, szerverhiba, helyzet nem elérhető). |
| **Lebegő elem** | A tartalom fölött, attól elválva megjelenő elem: térképi kártya, FAB, menü. |
| **Modális elem** | A fülek fölé nyíló, a navigációt eltakaró elem: dialógus, sheet, teljes képernyős fotó, feladatfolyamat-űrlap, nyitóképernyő. |
| **Adaptív elem** | Olyan elem, amely Androidon és iOS-en mást mutat vagy másképp viselkedik (PL2). |

## AL. Alapelvek

Ha egy eset nincs szabályban, ezek döntenek, ebben a sorrendben.

**AL1 — Egy pillantás.** A következő elérhető alkalom ideje és helye azonnal látszik, görgetés és koppintás nélkül.

**AL2 — Bővíthető építőelemek.** Egy új alkalomfajta (szentségimádás, gyóntatás…) a meglévő komponensekből áll össze, nem új képernyőtípusból. A kártya felépítése fajtafüggetlen: időblokk, a fajta ikonja és felirata, hely, jellemzők.

**AL3 — Őszinte állapot.** A **nincs kapcsolat**, a **szerverhiba** és az elavult adat mindig látszik, de nem ijesztget: szalag és (i) jelzés, nem piros riasztás.

**AL4 — Közös funkció, platformhű kézérzet.** Ugyanaz a funkció, ugyanaz a képernyőszerkezet mindkét platformon; a rendszerszintű interakciók platformhűek (PL).

**AL5 — Csendes és méltó.** Nincs harsány szín, felesleges animáció, reklámszerű elem. A szín jelöl, nem díszít: egy szín egy jelentés.

**AL6 — Mindenkinek használható.** Kontraszt, méret, felirat és képernyőolvasó előbb jön, mint a díszítés (AM).

## TO. Tokenek helye

**TO1 — Minden token a `lib/theme/` alatt él.**

- `miserend_theme.dart`: a `ThemeData` világos és sötét változata.
- `miserend_colors.dart`: a `MiserendColors` `ThemeExtension` (SZ3).
- `tokens.dart`: a `Spacing` (TK1) és a `Radii` (FO1) osztály.
- `adaptive.dart`: az adaptív elemek segédfüggvényei (PL3).

A `lib/theme/`-on kívül nem áll `Color(…)`, `Colors.*` (kivéve `Colors.transparent`), `fontSize:`, nyers számú `BorderRadius.circular(…)`, `Radius.circular(…)`, nyers számú `EdgeInsets` vagy `SizedBox` térköz, és nyers `Duration` animációhoz.

_Ismert eltérés: a `lib/theme/` még nem létezik; a téma a `lib/main.dart`-ban, a színek a `lib/colors.dart`-ban állnak (#54). Nyers színek, térközök, lekerekítések a widgetekben: #57, #58, #59._

## SZ. Szín

**SZ1 — A séma a lilából generálódik.** `ColorScheme.fromSeed(seedColor: Color(0xFF5C27AE), dynamicSchemeVariant: DynamicSchemeVariant.fidelity, brightness: …)`, világos és sötét változatban. Világos módban a `primary` pontosan `#5C27AE`; ha a generálás eltér, a `primary` `copyWith`-szel rögzített. Más seed, `ColorScheme.fromSwatch` és kézzel összerakott `ColorScheme` nincs.

**SZ2 — Nincs dinamikus szín.** Az Android 12+ háttérkép-palettáját (`dynamic_color`) nem használjuk: a márkaszín mindkét platformon ugyanaz.

**SZ3 — Az app saját szerepei a `MiserendColors`-ban.** `ThemeExtension<MiserendColors>`, világos és sötét értékkel; a widget `Theme.of(context).extension<MiserendColors>()!`-ral éri el.

| Szerep | Világos | Sötét | Mire |
|---|---|---|---|
| `occasionTime` | `#FF8C00` | `#FF8C00` | Telt narancs háttér: az épp most tartó alkalom időpontja |
| `onOccasionTime` | `#2E1500` | `#2E1500` | Szöveg és ikon `occasionTime`-on |
| `occasionTimeContainer` | `#FFDCC2` | `#6E3900` | Az időpont-chip háttere |
| `onOccasionTimeContainer` | `#2E1500` | `#FFDCC2` | Szöveg `occasionTimeContainer`-en |
| `serverErrorContainer` | `#FFE0B2` | `#5A3300` | A szerverhiba szalagjának, kártyájának háttere |
| `onServerErrorContainer` | `#2E1500` | `#FFDCC2` | Szöveg `serverErrorContainer`-en |
| `serverErrorIcon` | `#B45309` | `#FFB870` | A szerverhiba ikonja `serverErrorContainer`-en |
| `userLocation` | `#1A73E8` | `#1A73E8` | A saját helyzet pöttye a térképen (spec 0006) |
| `onUserLocation` | `#FFFFFF` | `#FFFFFF` | A saját helyzet pöttyének gyűrűje |
| `mapOverlay` | `surface` 70%-os átlátszatlansággal | `surface` 70%-os átlátszatlansággal | A térkép forrásmegjelölésének háttere (KO17) |

A szöveges párok kontrasztja legalább 4,5:1, az ikoné (`serverErrorIcon`) és a nem szöveges jelölésé (`userLocation`) legalább 3:1 (AM1).

_Ismert eltérés: a `CustomColors` (`lib/colors.dart`) fix, csak világos színeket tart (#54)._

**SZ4 — Egy szín, egy jelentés.**

| Információ | Szerep |
|---|---|
| Alkalom időpontja | `occasionTimeContainer` / `onOccasionTimeContainer`; épp most tartónál `occasionTime` / `onOccasionTime` |
| Mise jellemzője | `secondaryContainer` / `onSecondaryContainer` |
| Távolság, nyelv és más kiegészítő adat | `surfaceContainerHighest` / `onSurfaceVariant` |
| Gomb, link, kiválasztás, fókusz, navigációs indikátor | `primary` és családja (`primaryContainer`, `secondaryContainer` az M3 alapértelmezése szerint) |
| Nincs kapcsolat, helyzet nem elérhető | `surfaceContainerHighest` / `onSurfaceVariant` |
| Szerverhiba | `serverErrorContainer` / `onServerErrorContainer` / `serverErrorIcon` |
| Űrlaphiba | `error` / `onErrorContainer` |
| Saját helyzet a térképen | `userLocation` / `onUserLocation` |
| Templom a térképen | a miserend.hu pinje, csoportja `primary` / `onPrimary` (KO17) |

A narancs **csak** időpontot jelöl: gomb, link, ikon vagy díszítés nem narancs. A narancs szövegként felületen (`surface`, `surfaceContainer*`) nem állhat, mert ott nem éri el az AA kontrasztot; az időpont mindig a saját konténerében áll.

**SZ5 — Felületek.** Az oldal háttere `surface`, a kártyáé `surfaceContainerLow`, a keresősávé `surfaceContainerHigh`, az elválasztóé `outlineVariant`. Szöveg: elsődleges `onSurface`, másodlagos `onSurfaceVariant`. Átlátszósággal halványított szöveg (`withAlpha`, `withOpacity`) nincs.

**SZ6 — Sötét mód a rendszer szerint.** `MaterialApp(theme: …, darkTheme: …, themeMode: ThemeMode.system)`. Az appban nincs témaválasztó. Minden képernyő mindkét módban használható; fix fehér vagy fekete háttér nincs.

_Ismert eltérés: nincs `darkTheme` (#54); több `Scaffold(backgroundColor: Colors.white)` (#56, #58)._

## TI. Tipográfia

**TI1 — Rendszerfont.** Androidon Roboto, iOS-en SF Pro, ahogy a Flutter `Typography` adja. Saját vagy letöltött betűtípus nincs.

**TI2 — Csak a `TextTheme` szerepei.** A szövegstílus `Theme.of(context).textTheme.<szerep>`. `copyWith` csak `fontWeight`-et, `fontFeatures`-t és szerep-színt (SZ) állíthat; `fontSize`-ot, `height`-ot, `letterSpacing`-et nem.

| Mire | Szerep |
|---|---|
| Képernyőcím (címsor) | `titleLarge` |
| Szakaszcím a lapon | `titleMedium`, `FontWeight.w600` |
| Templom neve kártyán | `titleMedium` |
| Alkalom időpontja kártyán, csoportfejlécben | `titleLarge`, `FontWeight.w600`, `FontFeature.tabularFigures()` |
| Hosszabb olvasnivaló (leírás, névjegy) | `bodyLarge` |
| Kártya másodlagos sorai (hely, cím) | `bodyMedium`, `onSurfaceVariant` |
| Chip felirata | `labelLarge` |
| Hátralévő idő | `labelMedium` |
| Badge felirata | `labelSmall` |
| Lábjegyzet, az adat kora | `bodySmall`, `onSurfaceVariant` |
| Gomb felirata | a gomb témájának alapértelmezése (`labelLarge`) |

**TI3 — Az időpont a kártya legerősebb eleme** (AL1). Ugyanazon a kártyán nincs nála nagyobb vagy vastagabb szöveg.

**TI4 — Számjegyek egymás alatt.** Minden időpont és távolság `FontFeature.tabularFigures()`-szel áll, hogy a listán egymás alá igazodjanak.

_Ismert eltérés: a kártyák, a csoportfejléc és a `SectionCard` szövegszerepei (#57); szakaszcímek `titleLarge`/`titleSmall`-lal, `fontSize` a térképen (#59)._

## TK. Térköz

**TK1 — A skála.** `Spacing.xs = 4`, `s = 8`, `m = 12`, `l = 16`, `xl = 24`, `xxl = 32`. Más érték nincs; a `2` csak ikon és szöveg optikai igazítására, kommenttel.

**TK2 — Hol melyik.**

| Hely | Token |
|---|---|
| A képernyő vízszintes széle | `l` |
| Kártyák között a listán | `s` |
| Kártyán belül, a széltől | `l` |
| Kártyán belül, sorok között | `s` |
| Chipek között | `s` |
| Ikon és felirata között | `s` |
| Chip belső térköze | vízszintesen `s`, függőlegesen `xs` |
| Szakaszok között a lapon | `xl` |
| Űrlapmezők között | `l` |
| Állapotnézet elemei között (KO8) | `l` |

## FO. Forma

**FO1 — A skála.** `Radii.xs = 4`, `s = 8`, `m = 12`, `l = 16`, `xl = 28`, és `full` (`StadiumBorder`). Más érték nincs.

**FO2 — Hol melyik.**

| Elem | Token |
|---|---|
| Kártya a listán | `m` |
| Térképi kártya | `l` |
| Chip | `s` |
| Badge | `full` |
| Szövegmező | `s` |
| Gomb, keresősáv | `full` |
| Bottom sheet felső sarkai | `xl` |
| Dialógus (Android) | `xl` (iOS-en a rendszer rajzolja) |
| Menü, snackbar | `xs` |
| Fotó a részletező lap fejlécében | nincs lekerekítés |
| Fotó a galériában | `m` |
| Bélyegkép csempében (pl. a keresési javaslat fotója, ikonja) | `s` |
| Szalag | nincs lekerekítés |

## MÉ. Mélység és árnyék

**MÉ1 — A mélységet tónus adja, nem árnyék.** A kártya `elevation: 0`, és a `surfaceContainerLow` színnel válik el a `surface` háttértől.

**MÉ2 — Árnyékot csak a lebegő elem kap**, az M3 alapértelmezésével: térképi kártya és FAB `3`, menü `2`. Más elem `elevation`-je `0`. Kivétel a térképi csoport és a saját helyzet jelölője: ezek a spec 0006/0012 szerinti finom árnyékot kapnak (KO17), amelynek értéke a `lib/theme/`-ben áll.

**MÉ3 — A címsor görgetéskor tónust kap.** `elevation: 0`, `scrolledUnderElevation: 3` (M3 alapértelmezés), árnyék nélkül.

## EL. Elrendezés

**EL1 — Telefonra optimalizált, 320 dp-től.** A legkisebb támogatott szélesség 320 dp; a tervezési alap 360–393 dp; a nagy telefon 430 dp felett. Egyik szélességen sem vágódik le és nem lóg ki semmi.

**EL2 — Nincs fix szélesség.** Szöveget, chipet, gombot tartalmazó elemnek nincs rögzített szélessége; ami nem fér el egy sorban, az tördel (`Wrap`, több soros `Text`), nem `overflow: ellipsis`-szel vész el. Kivételek:

- A templom neve a kártyán legfeljebb 2 sor, utána `ellipsis`.
- A templomkártya mise-chipjei egy sorban állnak; ami nem fér ki, azt a sor végén egy `…` chip jelzi (spec 0007). A részletező minden misét mutat.
- A mise jellemzőjének buborékja a misekártyán egy sorban, `ellipsis`-szel áll; koppintásra a teljes szöveg látszik (spec 0011).

**EL3 — Széles képernyőn korlátozott tartalom.** 600 dp feletti szélességen (tablet, fekvő tájolás) a lista és az űrlap tartalma legfeljebb **640** dp széles, középre igazítva. A térkép és a fotó kitölti a teljes szélességet. Kétpaneles elrendezés nincs.

**EL4 — Biztonságos terület.** Tartalom nem kerül a notch, a status bar, a home indicator vagy a navigációs gesztussáv alá (`SafeArea` vagy a `Scaffold` beépített kezelése). A térkép kitöltheti, de a rajta lévő vezérlők és lebegő elemek nem.

**EL5 — Fekvő tájolás.** Minden képernyő használható fekvő tájolásban is, levágás nélkül.

## NA. Navigáció

**NA1 — Az alsó navigáció mindig látszik.** Minden lapon, amely egy fülről nyílik (templom-részletező, keresési találatok, részletes kereső, Névjegy, Impresszum), a fülsáv látható. Ehhez minden fülnek saját navigációs verme van. Csak a modális elem takarhatja el: dialógus, bottom sheet, action sheet, teljes képernyős fotónézegető, feladatfolyamat-űrlap (pl. Hibajelentés), nyitóképernyő.

_Ismert eltérés: a részletező, a keresési találatok és a Névjegy `Navigator.push`-sal a fülsáv fölé nyílik; a Hibajelentés nem modális (#55)._

**NA2 — Feladatfolyamat-űrlap.** Ami egy befejezendő vagy elvetendő folyamat (pl. Hibajelentés), az modálisan nyílik: iOS-en modális lap, Androidon teljes képernyős dialógus (`fullscreenDialog: true`), „Mégse" kilépéssel.

**NA3 — Vissza.** A vissza gomb, a vissza-gesztus és az iOS élről húzás a fül saját vermében lép vissza. Androidon egy fül gyökeréről az első fülre (Templomok) visz, onnan kilép az appból. Minden mélyebb lapon van vissza gomb a címsorban.

**NA4 — Az aktív fülre újra koppintva** a fül a gyökerére ugrik, ha mélyebb lap van nyitva; ha már a gyökéren van, a lista elejére görget.

**NA5 — Fülváltáskor** minden fül megtartja a saját vermét és görgetési helyét.

**NA6 — A fülek.** Legfeljebb 5 fül. A felirat főnév, mindig látszik, és a fül tartalmát fedi. Külön „Kezdőlap" gomb nincs: az alsó navigáció a kezdőlap.

**NA7 — Legfeljebb 3 szint mély** egy fül verme (pl. lista → templom-részletező → galéria).

## PL. Platformok

**PL1 — Közös alap.** Mindkét platformon Material 3 widgetek, közös képernyőszerkezettel és funkcióval (ADR-0004). Teljes Cupertino-felület nincs.

**PL2 — Az adaptív elemek listája.** Csak ezek térnek el; ami nincs a listán, az mindkét platformon M3.

| Elem | Android | iOS |
|---|---|---|
| Lapátmenet | `PredictiveBackPageTransitionsBuilder` | `CupertinoPageTransitionsBuilder` (élről húzható) |
| Görgetés | clamping, stretch | bouncing |
| Dialógus | M3 `AlertDialog` | `CupertinoAlertDialog` (`AlertDialog.adaptive`) |
| Műveletválasztó (pl. a liturgikus nyelv választója) | M3 `showModalBottomSheet` | `CupertinoActionSheet` |
| Dátum- és időválasztó | M3 `showDatePicker` / `showTimePicker` | `CupertinoDatePicker` sheetben |
| Kapcsoló, pipa, rádiógomb | M3 | `.adaptive` konstruktor |
| Töltésjelző | `CircularProgressIndicator` | `CircularProgressIndicator.adaptive` |
| Pull-to-refresh | `RefreshIndicator` | `RefreshIndicator.adaptive` |
| Alsó navigáció | M3 `NavigationBar` | `CupertinoTabBar`, aktív szín `primary` |
| Címsor igazítása | balra | középre (a `centerTitle` nincs beállítva, a Flutter platform-alapértelmezése dönt) |
| Rendszerikonok: vissza, megosztás, továbbiak, bezárás | Material (`Icons.*_rounded`) | `CupertinoIcons` |
| Érintési visszajelzés | ripple (`InkSparkle`) | halvány kiemelés, ripple nélkül (`NoSplash.splashFactory`) |
| Haptika | csak ahol a rendszer is ad | `HapticFeedback.lightImpact()` kapcsolónál és választónál |

**PL3 — Az elágazás egy helyen.** A platformfüggő döntés a `lib/theme/adaptive.dart` segédfüggvényeiben (pl. `showMiserendDialog`, `showMiserendActionSheet`, `pickMiserendDate`) és a témában áll; a képernyő kódja nem ágazik el platformonként. A platformot `Theme.of(context).platform` adja, nem a `dart:io` `Platform`, így a teszt felülírhatja.

_Ismert eltérés: iOS-en is minden Material — dialógus, sheet, választók, kapcsoló, rádiógomb, töltésjelző, pull-to-refresh, átmenet, érintés, rendszerikonok (#60)._

## IK. Ikonok

**IK1 — Beépített lekerekített ikonok.** Tartalmi ikon: `Icons.*_rounded` (külső ikoncsomag nincs). Egy képernyőn nem keveredik a sima és a lekerekített változat. Kivétel: az app saját képi ikonjai (pl. a kehely) és a liturgikus nyelvek zászlói.

**IK2 — Kitöltött csak kiválasztva.** Kiválasztott állapotban (aktív fül, kedvenc) a kitöltött változat, egyébként a körvonalas (`*_outline_rounded`, `*_border_rounded`), ahol van ilyen.

_Ismert eltérés: egyetlen ikon sem `_rounded` (#61; a kártyák és chipek ikonjai: #57; a fülsáv: #66; a rendszerikonok: #60)._

**IK3 — Méret.** Alapértelmezés `24`, chipben és szalagban `18`, állapotnézetben (KO8) `48`; a méret az `IconTheme`-ből vagy a komponens témájából jön.

**IK4 — Az ikon színe szerep**: `onSurfaceVariant` alapból, `primary` kiválasztva, a konténer `on…` szerepe konténeren.

## MO. Mozgás

**MO1 — Időtartamok.** Kis állapotváltás `Durations.short3` (150 ms), elem be- és kilépése `Durations.medium1` (250 ms), képernyőnyi átmenet `Durations.medium3` (350 ms). Más időtartam nincs.

**MO2 — Görbék.** Belépés `Easing.emphasizedDecelerate`, kilépés `Easing.emphasizedAccelerate`, helyben maradó állapotváltás `Easing.standard`.

**MO3 — Csökkentett mozgás.** Ha `MediaQuery.disableAnimationsOf(context)` igaz, nincs csúszás és átméretezés: a váltás azonnali, vagy legfeljebb 150 ms áttűnés.

_Ismert eltérés: nyers időtartamok és görbék, a `FadeInImage` alapértelmezett áttűnései, a csökkentett mozgás nincs kezelve (#64)._

**MO4 — Takarékos mozgás** (AL5). Hero animáció csak a fotónál (fejléc → galéria). Nincs skeleton: a lista a helyi gyorsítótárból szinte azonnal kész, a betöltést a `LoadingView` (KO8) mutatja. Nincs dekoratív, ismétlődő vagy figyelemfelkeltő animáció. Egyetlen kivétel a fotófejléc automatikus diavetítése (spec 0003, KO19).

## KO. Komponensek

**KO1 — Kártya** (alkalomkártya, misekártya, templomkártya). `Card.filled` vagy `Card(elevation: 0)`, szín `surfaceContainerLow`, forma `Radii.m`, belső térköz `Spacing.l`, kártyák között `Spacing.s`. Az egész kártya koppintható; a képernyőolvasó egy egységként olvassa fel (AM5).

**KO2 — Címsor.** Háttér `surface`, előtér `onSurface`, cím `titleLarge`, `elevation: 0`, `scrolledUnderElevation: 3`. Lila vagy más színes háttér nincs.

_Ismert eltérés: a téma `appBarTheme`-je és a szakaszsáv lila hátteret és fehér előteret ad (#56)._

**KO3 — Időpont-chip.** Háttér `occasionTimeContainer`, szöveg `onOccasionTimeContainer`, épp most tartó alkalomnál `occasionTime` / `onOccasionTime`. Forma `Radii.s`, `labelLarge` `w600`, táblázatos számjegyek. Az időblokk végleges formáját külön spec rögzíti.

_Ismert eltérés: az időpont-chip narancs háttéren fehér szöveget mutat, kontraszt kb. 2,4:1; az adat-chipek és a kártyák színe, formája sem a KO1/KO4 szerinti (#57)._

**KO4 — Adat-chip** (távolság, nyelv, jellemző). Távolság és nyelv: `surfaceContainerHighest` / `onSurfaceVariant`; jellemző: `secondaryContainer` / `onSecondaryContainer`. Forma `Radii.s`, felirat `labelLarge`, ikon `18`. Nem interaktív chip nem kap `onTap`-et és ripple-t.

**KO5 — Szűrő-chip** (interaktív). M3 `FilterChip` / `ChoiceChip` az alapértelmezett témával, legalább 48 dp érintési területtel (AM3).

**KO6 — Badge.** Állapotot jelez, soha nem interaktív. Két alakja van:

- **Ikon-badge**: pont vagy szám egy ikon sarkán (M3 `Badge`). A szám legfeljebb „99+".
- **Állapot-badge**: szöveges, a kártyán (pl. „Épp most tart"). Forma `Radii.full`, `labelSmall`, telt háttér a jelzett állapot szerepével (épp most tartó alkalomnál `occasionTime` / `onOccasionTime`).

Egy kártyán legfeljebb egy állapot-badge. Minden badge-nek magyar szemantikai címkéje van („Épp most tart", „3 új").

_Ismert eltérés: az „Épp most tart" badge `primaryContainer` háttérrel, 12-es lekerekítéssel, `labelMedium` felirattal (#57)._

**KO7 — Szalag** (nincs kapcsolat, szerverhiba, helyzet nem elérhető). Teljes szélesség, lekerekítés nélkül, belső térköz vízszintesen `Spacing.l`, függőlegesen `Spacing.s`. Ikon `18` és `bodyMedium` szöveg; mellette (i) gomb, ha van bővebb tájékoztatás. Színek: SZ4.

**KO8 — Állapotnézetek** (betöltés, üres, hiba). Betöltés: középre igazított `CircularProgressIndicator.adaptive`. Üres és hiba: ikon `48` `onSurfaceVariant`, alatta `titleMedium` cím, `bodyMedium` magyarázat (SV2), és ha van teendő, egy `FilledButton.tonal` („Újra"). Elemek között `Spacing.l`. A meglévő `LoadingView`, `MessageView`, `PositionUnavailableView` ezt valósítja meg.

**KO9 — Gombok.** Képernyőnként legfeljebb egy `FilledButton` (a fő teendő); utána `FilledButton.tonal`, majd `TextButton`. `ElevatedButton` nincs. Forma `Radii.full`. Felirat ige (SV3).

**KO10 — Csempe** (`ListTile` és a `*Tile` widgetek). Legalább 56 dp magas; vezető ikon `24`, `onSurfaceVariant`; cím `bodyLarge`, alcím `bodyMedium` `onSurfaceVariant`. Csempék között elválasztó csak ott, ahol a csoportosítás nem egyértelmű: `Divider` `outlineVariant` színnel, `Spacing.l` behúzással.

**KO11 — Keresősáv.** `SearchAnchor.bar`, forma `Radii.full`, háttér `surfaceContainerHigh`, legalább 48 dp magas.

**KO12 — Szövegmező.** `OutlineInputBorder`, forma `Radii.s`; keret alapból `outline`, fókuszban `primary` 2 dp, hibánál `error`. Címke a mezőben (M3 lebegő címke), hibaüzenet a mező alatt (SV2).

_Ismert eltérés: kézi `inputDecorationTheme` nyers színekkel, lekerekítés nélkül (#56)._

**KO13 — Bottom sheet és action sheet.** A PL2 szerint adaptív. Androidon felső sarkai `Radii.xl`, fogantyúval (`showDragHandle: true`).

**KO14 — Dialógus.** A PL2 szerint adaptív, `showMiserendDialog`-gal. Legfeljebb két gomb, igei felirattal; „OK" csak puszta tudomásulvételre.

**KO15 — Snackbar.** Háttér `inverseSurface`, szöveg `onInverseSurface`, akció `inversePrimary`, `SnackBarBehavior.floating`, forma `Radii.xs`, 4 s.

_Ismert eltérés: a `snackBarTheme` lila hátteret ad (#56)._

**KO16 — Alsó navigáció.** A PL2 szerint adaptív, felirat mindig látszik. Androidon `NavigationBar` az M3 alap színeivel (háttér `surfaceContainer`, indikátor `secondaryContainer`); iOS-en `CupertinoTabBar`, aktív szín `primary`, inaktív `onSurfaceVariant`.

_Ismert eltérés: `BottomNavigationBar` lila háttérrel, mindkét platformon (#66)._

**KO17 — Térkép: jelölő, csoport, saját helyzet, forrásmegjelölés.**

- **Templom-pin**: a miserend.hu pinje (`assets/images/map_pin.png`, alapszíne a `primary` világos értéke, spec 0006). Kép, ezért sötét módban sem vált színt. A kijelölt pin 1,3×-os, nem más színű.
- **Csoport** (spec 0012): kör `primary` háttérrel, `onPrimary` szegéllyel és `onPrimary` `labelLarge` `FontWeight.w700` számmal, finom árnyékkal (MÉ2).
- **Saját helyzet** (spec 0006): `userLocation` pötty `onUserLocation` gyűrűvel, finom árnyékkal (MÉ2).
- **Forrásmegjelölés**: háttér `mapOverlay`, szöveg `labelSmall` `onSurface`.

_Ismert eltérés: a csoport, a saját helyzet és a forrásmegjelölés nyers színekkel és betűmérettel (#58, #59)._

**KO18 — Térképi kártya.** Lebegő elem: `surfaceContainerLow`, forma `Radii.l`, `elevation: 3`, a képernyő szélétől és a biztonságos területtől `Spacing.l`.

**KO19 — Fotófejléc.** Teljes szélesség, lekerekítés nélkül, Hero animációval a galériába (MO4). Több fotónál automatikus diavetítés: 4 s-onként lapoz, `Durations.medium3` és `Easing.emphasizedDecelerate` görbével; kézi lapozásra véglegesen leáll, és leáll, ha a fejléc összecsukódik vagy az app háttérbe kerül (spec 0003). Csökkentett mozgásnál (MO3) el sem indul. A fotón álló szöveg vagy ikon alatt sötét átmenet biztosítja az AA kontrasztot.

**KO20 — Lebegő számláló** (pl. a részletes kereső „8 / 42 találat" felirata, spec 0010). Nem badge (nem állapot) és nem chip (nem egy elem adata), hanem a lista egészéről szóló, ideiglenes lebegő felirat. Alul középen, a biztonságos területtől `Spacing.l`-re; háttér `inverseSurface`, szöveg `onInverseSurface` `labelLarge`, táblázatos számjegyekkel, forma `Radii.full`, belső térköz vízszintesen `Spacing.l`, függőlegesen `Spacing.s`. Görgetés közben látszik, a görgetés vége után 1,5 s-mal `Durations.medium1` alatt elhalványul. Nem interaktív, árnyéka nincs.

_Ismert eltérés: félig átlátszó fekete kapszula fehér szöveggel, 300 ms-os halványulás (#58, #64)._

## AM. Akadálymentesség

**AM1 — WCAG 2.2 AA.** Szöveg kontrasztja legalább 4,5:1, nagy szövegé (`titleLarge` és felette) és ikoné legalább 3:1, világos és sötét módban is.

**AM2 — Nem csak szín.** Információt szín egyedül nem hordoz: az állapotnak felirata vagy ikonja is van (pl. „Épp most tart" badge, nem csak narancs háttér).

**AM3 — Érintési terület legalább 48 × 48 dp**, mindkét platformon (az iOS 44 pt-os minimumát is fedi).

**AM4 — Szövegnagyítás.** A rendszer szövegméretét követjük, nem korlátozzuk (`textScaler` nincs lezárva). 2,0-s nagyításnál, 320 dp szélességen sem vágódik le és nem lóg ki tartalom.

**AM5 — Képernyőolvasó.** Minden ikongombnak magyar `tooltip`-je vagy `Semantics` címkéje van. A kártya egy egységként, értelmes sorrendben olvasódik fel (`MergeSemantics`), pl. „18:30, Szent István-bazilika, 1,2 km". Díszítő kép és ikon `excludeFromSemantics`.

_Ismert eltérés: nincs `MergeSemantics` a kártyákon, a koppintható időpont-chip 48 dp-nél kisebb, nincsenek guideline-tesztek (AM3–AM5, #62); fix templomkártya-magasság, egysoros vágások, nincs 640 dp-s korlát, nincsenek méret-tesztek (EL1–EL3, #67)._

**AM6 — Gesztus csak kényelmi.** Minden funkció koppintással is elérhető; a húzás, hosszú nyomás csak gyorsítás.

**AM7 — Csökkentett mozgás**: MO3.

## SV. Szöveg és hangnem

**SV1 — Tegezés.** Rövid, cselekvő mondatok. Nincs felkiáltójel, nincs csupa nagybetű.

**SV2 — Hibaüzenet: mi történt + mit tehetsz.** „Nincs internetkapcsolat. Próbáld újra, ha lesz térerő."

**SV3 — A gomb felirata ige**: „Újra", „Küldés", „Megnyitás". „OK" csak puszta tudomásulvételre.

_Ismert eltérés (SV1, SV3, SV4): a nyitóképernyő dialógusa magáz, „Igen" / „Nem" gombokat mutat, és a szövegei a kerülendő „adatbázis" szót használják (#63)._

**SV4 — A domain szavai a CONTEXT.md-ből jönnek** (pl. „Részletes kereső", „Épp most tart"), az ott kerülendő szavak a felületen sem szerepelnek.

## FM. Formátumok

**FM1 — Idő:** 24 órás, `H:mm` („7:30", „18:05").

**FM2 — Dátum:** `yyyy. MM. dd.` („2026. 10. 07."); rövid formában „okt. 7., kedd".

**FM3 — Távolság:** tizedesvesszővel, 1 km felett egy tizedesig („1,2 km"), alatta egész méterben („850 m").

**FM4 — Hátralévő idő:** a CONTEXT.md „Hátralévő idő" szerint („25 perc múlva", „1 óra 5 perc múlva").

**FM5 — Tartomány:** nagykötőjellel, szóköz nélkül („9:00–18:00").

_Ismert eltérés: az időformázás kétjegyű órát ad („07:30"), a nem friss adat dátumáról hiányzik a záró pont, a szentségimádás tartománya szóközzel áll (#63)._

## EH. Ellenőrzés

**EH1 — Minden eltérés bug.** A review a DESIGN.md-től való minden eltérést bugként jelez, pontos egyezéssel: a hasonló érték nem elég.

**EH2 — Gépi ellenőrzés.** A `test/design_rules_test.dart` a teljes `lib/`-re lefut, és hibát jelez a TO1-ben felsorolt nyers értékekre a `lib/theme/`-on kívül. Kivétellistája csak az „Ismert eltérés" helyeit tartalmazza, issue-számmal; új kivétel nem kerülhet bele.

**EH3 — Platform és mód a tesztben.** Az adaptív elemet (PL2) érintő widget teszt Android és iOS platformon (`debugDefaultTargetPlatformOverride` vagy `ThemeData(platform: …)`), a színt érintő világos és sötét módban is lefut.

**EH4 — Méret a tesztben.** Új vagy megváltozott képernyő és kártya tesztje 320 és 430 dp szélességen, 1,0-s és 2,0-s szövegnagyítással is lefut, overflow nélkül (AM4, EL1).

## Átállás állapota

A dokumentum első változata (2026-10-07) a meglévő appból indult, és a célt rögzíti. A kód auditja ugyanekkor készült: az eltéréseket a #54–#64, a #66 és a #67 issue-k viszik (a #54 a téma-alap, a többi erre épül; minden eltérésért pontosan egy issue felel), és a `test/design_rules_test.dart` kivétellistája ezekre mutat.
