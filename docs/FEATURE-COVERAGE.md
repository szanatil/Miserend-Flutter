# Feature Coverage — Miserend

Reverse-engineered from the current codebase (branch `V0.1`, commit `91ad952`). This is a description of **what the app currently does**, not a plan for what it should do — treat it as a snapshot, not a spec to build against once the code has moved on.

## What the app is

Miserend ("Mass Finder") is a Hungarian-language mobile app for finding Catholic churches and their Mass times, built with Flutter. All content (church list, addresses, Mass schedules) is sourced from a single downloaded SQLite dataset published by `miserend.hu` — the app itself has no backend of its own beyond that download and a problem-report endpoint.

## Startup / data lifecycle

**Entry point:** `lib/main.dart` → `RouteSplash` (`lib/splash.dart`)

| Feature | Behavior |
|---|---|
| First-run bootstrap | On launch, checks whether the church/Mass database file exists on device. If not, blocks with a forced dialog ("Adatbázis nem található") — user must download to proceed; declining exits the app. |
| Version compatibility check | Compares the locally saved database version (in `SharedPreferences`) against the app's expected version (`_databaseVersion = 4`, `lib/database/database_manager.dart`). Mismatch triggers the same forced download dialog. |
| Staleness check | If the dataset hasn't been refreshed in 7 days (`_databaseCheckPeriodInMillis`), shows a *non-forced* "Frissítés elérhető" dialog — user may decline and continue with the existing data. |
| Database download | Fetches `https://miserend.hu/fajlok/sqlite/miserend_v4.sqlite3` via `HttpClient`, writes it to the app's database directory, and records the new version + timestamp in `Preferences`. Shows a success/failure snackbar. |

No incremental sync — a "database update" is always a full-file replacement.

## Home shell

**File:** `lib/home/home.dart`

| Feature | Behavior |
|---|---|
| Bottom navigation | Three tabs: **Templomok** (Churches), **Misék** (Masses), **Térkép** (Map) — switches the body widget via local `_selectedIndex` state, no routing. |
| Search bar | A `SearchAnchor.bar` in the app bar. Live-updates suggestions as the user types, but only once the query is **longer than 2 characters** (`_onSearchChanged`). |
| Search suggestions | Combines up to 20 matching **churches** (by name or common name, `LIKE` match) and any matching **cities** (distinct `varos` values) into one suggestion list, each rendered with its own tile type (`ChurchSuggestion`, `CitySuggestion`). |
| Suggestion tap-through | Tapping a church suggestion opens `ChurchDetailsPage` directly; tapping a city suggestion opens `SearchResultsPage` scoped to that city. |
| Search submit | Pressing enter/search on a raw term (not from a suggestion) opens `SearchResultsPage` scoped to that free-text term. |

## Churches tab

**File:** `lib/home/churches/churches_page.dart` — a `TabBar` with two sub-tabs, both kept alive across tab switches (`AutomaticKeepAliveClientMixin`).

### Nearby (`near_churches_page.dart`)
- Requests device location (`LocationProvider`, permission flow via `geolocator`).
- Loads **all** churches with their masses, sorted by squared-distance from the current position (`getCloseChurchesWithMasses` — no true great-circle distance, a flat Euclidean approximation on lat/lng).
- Renders each as a `ChurchListItem` card (image, name, common name, today's Mass times as chips, favorite toggle).

### Favorites (`favorite_churches.dart`)
- Reads favorite church IDs from `FavoritesService` (backed by the on-device `LocalDatabase`).
- Loads full church+Mass records for just those IDs and re-loads automatically whenever `FavoritesService` notifies a change (e.g. a favorite toggled elsewhere in the app).

### Search results (`search_results.dart`)
- Pushed from Home's search bar or a city suggestion.
- Two query modes: churches whose name/common name matches a free-text term, or churches located in an exact city — never both at once (`SearchParams` is either-or).
- Same `ChurchListItem` rendering as Nearby/Favorites.

### Shared list item (`church_list_item.dart`)
- Card showing church photo (network image with a blurred placeholder/error fallback asset), name, common name, **today's** Mass times (filtered client-side via `MassFilter`), and a favorite toggle button wired to `FavoritesService`.
- Tapping the card opens `ChurchDetailsPage`.

## Masses tab

**File:** `lib/home/masses/near_masses_page.dart`

- Requests device location, then queries the **500 closest individual Mass records** to the user (`getCloseMasses`, again squared-distance ordering, hard `LIMIT 500`).
- Filters that list down to masses actually happening **today** (`MassFilter.filterMassWithChurchListForDay`).
- Renders each as a `MassListItem`: church thumbnail, church name, Mass time (24h format) — no favorite toggle, no Mass detail drill-down (tapping does nothing; there's no `onTap`).

## Map tab

**File:** `lib/home/map/map_page.dart`

- Google Map (`google_maps_flutter`), default camera centered on Hungary, re-centered on the user's location once available.
- Loads **every** church in the dataset and drops a marker for each (no clustering, no viewport-based lazy loading).
- Tapping a marker fetches that church's full Mass schedule and shows a `ChurchListItem` card docked to the bottom of the screen (`selectedChurch`) — tapping the card opens full `ChurchDetailsPage`.
- Includes an unused/dead `_getMarkerBitmap` helper (draws a custom circular pin with optional text) — not currently wired to any marker.

## Church details

**File:** `lib/church_details/church_details_page.dart`

| Feature | Behavior |
|---|---|
| Header | Collapsing `SliverAppBar` with the church photo (or blurred placeholder), name, and common name. |
| Favorite toggle | Heart icon button, delegates to `FavoritesService.toggle`. |
| Report a problem | Opens `ReportPopup` (see below). |
| "Today" / "This Sunday" Mass chips | Two labeled rows of time chips inside a card, computed via `MassFilter` for offset 0 (today) and the offset to the coming Sunday. |
| Next 19 days schedule | A horizontally-scrolling row of day cards ("Holnap" for tomorrow, otherwise the Hungarian weekday name + date), each listing that day's Mass times — computed by re-running `MassFilter` for every day offset from 1–19 (not paginated or lazy; all computed upfront in `loadMasses`). |
| Location card | A static Google Maps image (Static Maps API, hardcoded API key in source) centered on the church, with a pin overlay; tapping it opens the location in the device's installed map app (`map_launcher`, always the **first** installed app — no chooser). |
| Getting-there text | Optional free-text directions field from the dataset (`gettingThere`), HTML-unescaped before display; hidden entirely if absent. |
| Directions button | "ÚTVONAL" — opens turn-by-turn directions in the same default map app. |

## Report a problem

**File:** `lib/church_details/report_problem_popup.dart`

- Modal with a problem-type dropdown (Rossz pozíció / Rossz miseidőpont / Egyéb), free-text description, and an optional email field.
- `POST`s to `https://miserend.hu/api/v4/report` as JSON (`tid`, `pid`, `text`, `email`, plus a hardcoded `dbdate` literal — `'2025-04-18'`, not derived from the actual downloaded database version). Shows a success/failure snackbar; no retry or offline queue.

## Favorites (cross-cutting)

**Files:** `lib/database/favorites_service.dart`, `lib/database/local_database.dart`, `lib/database/favorite.dart`

- Favorites are **local-only** — stored in a separate on-device SQLite file (`localdatabase.sqlite3`), never synced to any server or account. Uninstalling the app or clearing app data loses them.
- `FavoritesService` is the single app-wide `ChangeNotifier`, provided at the root (`main.dart`) — every screen that shows a favorite state (list items, details page) reads through it, so toggling anywhere updates everywhere without an explicit refresh.

## Permissions & platform capabilities in use

- **Location** (`ACCESS_FINE_LOCATION`, Android) — for "nearby" churches/masses and initial map centering. Note: no `NSLocationWhenInUseUsageDescription` (or similar) was found in `ios/Runner/Info.plist` — iOS will silently deny the permission prompt without one, which would break "nearby" features on iOS as currently configured.
- **Internet** — database download, static map images, problem reports.
- **Storage** (`READ/WRITE_INTERNAL_STORAGE`, Android) — for the downloaded SQLite file (largely a no-op on modern Android scoped storage, but declared).

## Explicitly out of scope / not present

- No user accounts, login, or server-synced state of any kind.
- No offline map tiles — the Map tab requires network for Google Maps; the static map image on the details page likewise requires network.
- No localization — every string in the UI is a hardcoded Hungarian literal; there is no `intl` message catalog despite the `intl` package being a dependency (it's used only for date formatting).
- No automated tests exercise any of the above — `test/widget_test.dart` is unmodified Flutter counter-app boilerplate and does not reference any feature described here.
