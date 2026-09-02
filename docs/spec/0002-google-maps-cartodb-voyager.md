# Google Maps lecserélése CartoDB Voyager (OSM) csempékre a Térkép tabon és a helykártyán

> Tracker: [szanatil/Miserend-Flutter#2](https://github.com/szanatil/Miserend-Flutter/issues/2)

## Problem Statement

A Térkép tab és a templom-részletező oldal helykártyája jelenleg a Google Maps SDK-ra (`google_maps_flutter`), illetve a Google Static Maps API-ra épül. Mindkettő egy kódba égetett, a repóban nyilvánosan commitolt API kulcsot használ — ez biztonsági kockázat, és a natív iOS/Android konfigurációt is Google Maps-hez köti. Emellett a testvér-webapp (miserend.hu) már évek óta CartoDB Voyager OpenStreetMap-csempéket használ, így a mobil és a webes kliens vizuálisan és technológiailag inkonzisztens.

## Solution

A Google Maps-alapú térképmegjelenítést lecseréljük egy `flutter_map` + CartoDB Voyager alapú megoldásra, mind a Térkép tabon, mind a templom-részletező helykártyáján, megtartva a jelenlegi funkcionalitást (markerek, koppintásra megnyíló templomkártya, saját pozíció gomb). A Google Maps natív SDK és API kulcs teljesen kikerül a projektből (Dart kód + iOS + Android natív konfiguráció).

## User Stories

1. Mint alkalmazás-felhasználó, szeretném látni az interaktív térképet a Térkép tabon, hogy vizuálisan lássam a környékbeli templomokat.
2. Mint felhasználó, szeretnék egy pin-t látni minden templomhoz a térképen, hogy azonosítani tudjam a helyüket.
3. Mint felhasználó, szeretnék egy templom pin-jére koppintani, hogy megnézzem az alapadatait (a jelenlegi `ChurchListItem` kártyát) anélkül, hogy elhagynám a térképet.
4. Mint felhasználó, szeretném, hogy a térkép a saját pozícióm közelében nyíljon meg (miután a helymeghatározási engedélyt megadtam), hogy ne kelljen kézzel odagörgetnem.
5. Mint felhasználó, akinek még nincs (vagy nem lesz) helymeghatározási engedélye, szeretném, hogy a térkép ekkor is egy ésszerű alapértelmezett nézetet (Magyarország-közép) mutasson, hogy ne legyen üres/hibás a képernyő.
6. Mint felhasználó, szeretnék egy "ugrás a pozíciómra" gombot, hogy igény szerint tudjak visszaközpontosítani.
7. Mint felhasználó, szeretném látni a CartoDB/OpenStreetMap attribúciót a térképen, hogy a felhasználási feltételek teljesüljenek.
8. Mint felhasználó, aki egy templom részletező oldalát nézi, szeretnék egy kis térkép-előnézetet látni a templom helyéről, hogy anélkül is legyen vizuális képem a helyéről, hogy elnavigálnék.
9. Mint felhasználó, szeretném, hogy a helykártya mini-térképén jól látszódjon a templom pontos helye (marker).
10. Mint felhasználó, szeretném, hogy a helykártya mini-térképe vizuálisan egyezzen a Térkép tab stílusával (ugyanaz a tile-forrás), hogy az app konzisztens hatást keltsen.
11. Mint fejlesztő, szeretnék egy megosztott térkép-widgetet, amit mind a Térkép tab, mind a helykártya használ, hogy a tile-/attribúció-konfiguráció ne duplikálódjon.
12. Mint fejlesztő, szeretném, hogy a Google Maps SDK, a Static Maps API hívás és a kapcsolódó API kulcsok (Dart, iOS, Android) teljesen kikerüljenek a kódbázisból, hogy az app ne függjön Google Maps-től vagy annak API-kulcs-kitettségétől.
13. Mint felhasználó, szeretném, hogy a helykártyára koppintva továbbra is megnyíljon a telepített térkép-alkalmazás (jelenlegi `map_launcher`-alapú viselkedés, változatlanul), hogy ez a csere ne okozzon regressziót a navigációban a következő, külön ticketig.
14. Mint fejlesztő, szeretném, hogy a nem használt `_getMarkerBitmap` holt kód eltűnjön a Térkép tab kódjából, hogy ne cipeljük tovább feleslegesen.
15. Mint karbantartó, szeretném, hogy a döntés indoklása (miért CartoDB Voyager és nem nyers OSM-csempe vagy vektoros térkép) dokumentálva legyen egy ADR-ben, hogy később ne kelljen újra átgondolni.
16. Mint biztonságtudatos karbantartó, szeretnék egy jelzést (nem kódváltoztatást) arra, hogy a kitett Google Maps API kulcsot rotálni/visszavonni kell a Google Cloud Console-ban, miután a kód már nem használja.
17. Mint fejlesztő, szeretném, hogy a térkép működéséhez ne kelljen semmilyen Google Maps API kulcs vagy Google-specifikus natív konfiguráció, hogy az app build-elhető és futtatható legyen Google-fiók/kulcs nélkül is.
18. Mint fejlesztő, szeretném, hogy a térkép-csempék betöltése a jelenlegihez hasonlóan hálózatot igényeljen (nincs offline cache bevezetve), hogy a hatókör ne nőjön feleslegesen.
19. Mint QA/tesztelő, szeretnék widget teszteket a megosztott térkép-widget körül (tile URL, attribúció, marker-renderelés, interaktivitás be/ki), hogy a regressziókat korán elkapjuk.
20. Mint fejlesztő, szeretném, hogy a `Church` adatmodell (`isGreek` mező, hiányzó "aktív" státusz) ebben a ticketben ne változzon, mert ez egy külön, a marker-stílus-egyeztetéshez kötött döntés.

## Implementation Decisions

- **Megosztott widget** (munkanév: `MiserendMap`) a `flutter_map` csomagra épül, egyetlen `TileLayer`-t definiál:
  - `urlTemplate`: `https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png`
  - `subdomains`: `['a', 'b', 'c', 'd']`
  - `maxZoom`: `19`
  - Attribúció: `© OpenStreetMap contributors © CARTO`, két megjelenítési móddal paraméterezve: teljes szöveg (Térkép tab) és tömör forma (helykártya).
  - Paraméterek: kezdő center/zoom, marker-lista, `interactive: bool` (pan/zoom engedélyezve vagy lezárva).
  - Ez az egyetlen hely, ahol a tile-URL és az attribúció szövege szerepel a kódban.
- **`MapPage`**: `MiserendMap(interactive: true)`-ra épül. Marker-adatok forrása változatlan (`MiserendDatabase.getAllChurches()`), koppintásra ugyanúgy megnyílik a `ChurchListItem` (jelenlegi `Stack` + alsó kártya elrendezés). Kezdő kameraállás és a betöltés utáni user-location-re ugrás logikája (Magyarország-közép zoom 8 → user location zoom 14) funkcionálisan változatlan marad. "Saját pozíció" gomb: egyszeri `geolocator`/`LocationProvider` lekérdezés + recenterezés/marker, nincs folyamatos GPS-tracking csomag. A nem használt `_getMarkerBitmap` metódus törlődik.
- **`ChurchDetailsPage`**: a `_mapCard()`-ban az `Image.network(_getStaticMapUrl(...))` lecserélődik `MiserendMap(interactive: false, ...)`-ra, egyetlen markerrel a templom helyén, tömör attribúcióval. A `_getStaticMapUrl` metódus törlődik. A `_showLocationOnMap` / `_showDirectionsOnMap` (`map_launcher`, jelenleg mindig az első telepített appot nyitja) **nem** változik ebben a ticketben.
- **`Church` modell** (`lib/database/church.dart`): a `location` getter `LatLng` típusa a `google_maps_flutter` csomagéról a `latlong2` csomagéra (a `flutter_map` ezt várja) vált át. A `Church` osztály mezői (beleértve az `isGreek`-et) nem változnak.
- **Függőségek**: `google_maps_flutter` törlődik a `pubspec.yaml`-ból; bekerül a `flutter_map` (aktuális stabil verzió) és tranzitív függősége, a `latlong2`.
- **Natív konfiguráció**: `ios/Runner/AppDelegate.swift`-ből törlődik a `import GoogleMaps` és a `GMSServices.provideAPIKey(...)` hívás; `android/app/src/main/AndroidManifest.xml`-ből törlődik a `com.google.android.geo.API_KEY` meta-data; ha az `ios/Podfile`/`Podfile.lock` tartalmaz Google Maps pod-függőséget, az is törlődik (`pod install` újrafuttatásával). macOS oldalon jelenleg nincs ismert Google Maps-specifikus konfiguráció — implementáció közben ellenőrizendő.
- Nincs offline tile cache bevezetve.
- A tile-forrás az ingyenes, publikus CARTO CDN marad (nincs saját hosztolás/fizetős tier).

## Testing Decisions

- **Egyetlen fő seam**: a megosztott `MiserendMap` widget, `flutter_test` widget-tesztekkel, közvetlenül pumpolva rögzített propokkal (nem a teljes `MapPage`/`ChurchDetailsPage`-en keresztül).
  - A `TileLayer` `urlTemplate`, `subdomains` és `maxZoom` értéke megegyezik a specifikált CartoDB Voyager konfigurációval.
  - Az attribúció szövege megjelenik, mindkét módban (teljes / tömör) a helyes tartalommal.
  - A megadott marker-listának megfelelő számú és pozíciójú `Marker` widget jelenik meg.
  - `interactive: false` esetén a pan/zoom gesztusok le vannak tiltva, `interactive: true` esetén engedélyezettek.
- **`MapPage` és `ChurchDetailsPage`**: csak vékony, füst-szintű widget teszt (az oldal lerenderelődik, a `MiserendMap` jelen van, a marker-lista a bemeneti adatból helyesen származtatva) — a tile-/attribúció-részleteket nem teszteljük itt újra, azt a `MiserendMap` tesztjei fedik.
- Csak a külsőleg megfigyelhető viselkedést teszteljük (renderelt widget-fa / propok), nem a belső segédmetódusokat — ez illeszkedik ahhoz, hogy a kódbázisban jelenleg sincs finomabb szemcsézettségű, tesztelhető réteg.
- A `map_launcher`/navigáció-logika nem változik, nem igényel új tesztet.
- Előzmény: a repóban jelenleg nincs releváns teszt-minta (`test/widget_test.dart` csak az alapértelmezett Flutter counter-smoke-test) — ez a seam adja az első valódi, térkép-specifikus teszt-mintát.

## Out of Scope

- Navigáció-választó: a `map_launcher` jelenleg vakon az első telepített térkép-appot nyitja meg, és iOS-en hiányzik az `LSApplicationQueriesSchemes` bejegyzés a megbízható appdetektáláshoz. **Külön, következő ticket.**
- Marker vizuális stílusának egyeztetése a webapp-pal (felekezet + aktív/inaktív státusz szerint színezett SVG pin-ek). Külön ticket, és előfeltétele a `Church` modell hiányosságának feloldása (`isGreek: bool?` vs. webapp `denomination` + `active` mezői) — ld. `CONTEXT.md`.
- Offline tile cache.
- A kitett Google Maps API kulcs rotálása/visszavonása a Google Cloud Console-ban — emberi/infra lépés, nem kódváltoztatás.
- A `customIcon` bekötése (jelenleg betöltött, de sosem használt bitmap a Térkép tabon) — a cserétől független, meglévő hiányosság.
- A kezdő kameraállás/fallback-koordináta webapp-hoz igazítása (a jelenlegi Flutter-logika funkcionálisan egyenértékű, marad változatlan).

## Further Notes

- Döntés-dokumentáció: [docs/adr/0001-cartodb-voyager-instead-of-google-maps.md](../adr/0001-cartodb-voyager-instead-of-google-maps.md)
- Domain-modell megjegyzés (felekezet/aktív-státusz eltérés a Flutter és a webapp `Church`/templom modellje között): [CONTEXT.md](../../CONTEXT.md)
- A tile URL, subdomain-lista és attribúció-szöveg szó szerint a miserend.hu webapp (`webapp/js/church-map.js`) mintáját követi, a vizuális/technológiai konzisztencia miatt.
