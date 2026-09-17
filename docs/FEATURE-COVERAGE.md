# Feature Coverage — Miserend

Reverse-engineered from the current codebase (branch `V0.1`, commit `91ad952`). This is a description of **what the app currently does**, not a plan for what it should do — treat it as a snapshot, not a spec to build against once the code has moved on.

## What the app is

Miserend ("Mass Finder") is a Hungarian-language mobile app for finding Catholic churches and their Mass times, built with Flutter. Content comes from the `miserend.hu` API v4. Every screen draws from an on-device **local cache** (`lib/database/cache/cache_database.dart`), which a one-time import of the downloaded SQLite export fills and API responses keep updating row by row (ADR-0002, ADR-0003). The app has no backend of its own.

## Startup / data lifecycle

**Entry point:** `lib/main.dart` → `RouteSplash` (`lib/splash.dart`)

| Feature | Behavior |
|---|---|
| First-run bootstrap | On launch, checks whether the church/Mass database file exists on device. If not, blocks with a forced dialog ("Adatbázis nem található") — user must download to proceed; declining exits the app. |
| Version compatibility check | Compares the locally saved database version (in `SharedPreferences`) against the app's expected version (`_databaseVersion = 4`, `lib/database/database_manager.dart`). Mismatch triggers the same forced download dialog. |
| Database download | Fetches the SQLite export from the documented `https://miserend.hu/api/v4/sqlite` endpoint (following its redirect to the file) via `HttpClient` with a 30 s connection timeout, writes it to the app's database directory, and records the new version + download timestamp in `Preferences`. |
| Download failure | If an earlier export is on the device, shows an error snackbar and continues to the home screen with it. On a fresh install (no export) the splash shows an error message and an "Újrapróbálás" (retry) button instead of spinning forever. |
| Cache bootstrap | Once, after the first download, imports every church and the next **30 days** of masses from the export into the local cache (`BootstrapImporter`, behind the `AppStartup` seam). An export older than 182 days gives churches only, since its year-less `HHNN` dates would put masses on the wrong day. |
| Bootstrap failure | Until the first import succeeds the splash shows an error and an "Újrapróbálás" button instead of opening empty lists. |
| Favorites prefetch | After the splash, without holding up the home screen, at most once every 24 hours: one `Church {"ids"}` call for all favorites, then each favorite's 20-day schedule. Failures are silent and retried on the next start (`lib/favorites_prefetch.dart`). |

The export is only downloaded when it is missing or of the wrong version — there is no periodic re-download (ADR-0003).

**Cache-first lists:** Search results, Nearby, Favorites and the Map card draw from the cache at once, start one API call in the background, write its answer through to the cache and read it again (`ChurchListLoader`). An answer's `misek` replaces the church's cached rows for today, whatever their source — the details page's schedule included — and leaves the other days alone. Calls time out after 15 s (10 s to connect). A failed call keeps what is shown and marks it: **no connection** with an (i), **server error** with a tinted background and an (i); the (i) explains how old the data is and what to do. A church the `Church` endpoint reports in `hianyzo` is deleted from the cache and the favorites.

## Home shell

**File:** `lib/home/home.dart`

| Feature | Behavior |
|---|---|
| Bottom navigation | Three tabs: **Templomok** (Churches), **Misék** (Masses), **Térkép** (Map) — switches the body widget via local `_selectedIndex` state, no routing. |
| Search bar | A `SearchAnchor.bar` in the app bar. Live-updates suggestions as the user types, but only once the query is **longer than 2 characters** (`_onSearchChanged`). |
| Search suggestions | Combines up to 20 matching **churches** (by name, common name, alternative name or city) and any matching **cities** (distinct `varos` values), both ignoring case and accents (`searchText`), from the cache into one suggestion list, each rendered with its own tile type (`ChurchSuggestion`, `CitySuggestion`). No API call (`SearchSuggestions`). |
| Suggestion tap-through | Tapping a church suggestion opens `ChurchDetailsPage` directly; tapping a city suggestion opens `SearchResultsPage` scoped to that city. |
| Search submit | Pressing enter/search on a raw term (not from a suggestion) opens `SearchResultsPage` scoped to that free-text term. |
| ⋮ menu | Beside the search bar on every tab (`HomeMenuButton`): **Visszajelzés** (see Feedback) and **Az appról** (opens `AboutPage`). |

## Churches tab

**File:** `lib/home/churches/churches_page.dart` — a `TabBar` with two sub-tabs, both kept alive across tab switches (`AutomaticKeepAliveClientMixin`).

### Nearby (`near_churches_page.dart`)
- Needs the user's **position**: a last known position at most 5 minutes old, otherwise a fresh fix with a timeout (`LocationProvider`). Without one it shows the reason and a way out: allow the permission, open the app or location settings, or pull to retry (`PositionUnavailableView`).
- Lists **every** church of the cache, nearest first (squared distance with longitude scaled by latitude), each with today's masses.
- Background call: `NearBy`, 100 churches, `minimal` — new and corrected churches and today's masses are written through.

### Favorites (`favorite_churches.dart`)
- Reads favorite church IDs from `FavoritesService` (backed by the on-device `LocalDatabase`) and the churches from the cache, by name.
- Background call: `Church {"ids"}` in batches of 100, `minimal`. A favorite removed from miserend.hu silently disappears. A favorite toggled elsewhere re-reads the cache only.

### Search results (`search_results.dart`)
- Pushed from Home's search bar or a city suggestion.
- Two query modes: churches whose name, common name, alternative name or city contains a free-text term — case and accents ignored, by the same rule as the suggestions — or churches located in an exact city — never both at once (`SearchParams` is either-or).
- Background call: `Church {"ids"}` for the first 100 results; with no result in the cache, the API's `Search` instead, whose finds are written to the cache and read back by the local rule.
- States: loading, "Nincs találat", list.

### Shared list (`church_list_view.dart`, `church_card.dart`)
- Offline banner above the list after a failed refresh, and pull-to-refresh, which restarts the background call.
- Card showing the first cached photo (blurred placeholder otherwise), name, common name, **today's masses** as time chips — only masses: confession, adoration and other events are left out (`mass_kind.dart`) — and a favorite toggle wired to `FavoritesService`.
- Tapping the card opens `ChurchDetailsPage`.

## Masses tab

**File:** `lib/home/masses/near_masses_page.dart`

- Shows the **nearest masses** (see `CONTEXT.md`, spec 0004): live from API v4 `nearbymasses` around the user's position (a last known position older than 5 minutes is replaced by a fresh fix with a timeout), no cache or legacy-export fallback.
- `selectNearestMasses` (`nearest_masses.dart`) picks at most 10 nearest churches and lists every mass of theirs still reachable (started ≤ 10 minutes ago, up to tomorrow 00:00), one row per mass, masses only, in time order. A church with several masses left today appears several times.
- The API repeats items (the same mass up to three times); `MiserendApiClient` keeps each once, for this tab, the details page's schedule and the lists' masses of the day alike.
- Refetches on tab switch, app resume, pull-to-refresh and after midnight; re-selects from the last raw response every minute while visible.
- Loading, position-unavailable (by reason, with a button), API-error and empty states. Each `MassListItem` shows the cached thumbnail, church name, city, 24h start, distance ("1,2 km"), an "Épp most tart" badge and a non-"Szentmise" title; tapping opens `ChurchDetailsPage`.

## Map tab

**File:** `lib/home/map/map_page.dart`

- CARTO Voyager tiles (`MiserendMap`, ADR-0001), default camera centered on Hungary, moved to the user's position when one is available at opening.
- A marker for **every** church of the cache (no clustering, no viewport-based lazy loading).
- Tapping a marker shows that church's card from the cache at once and refreshes it with `Church {"ids": [tid]}` in full (photos and description too), marking the card after a failed call. A church removed from miserend.hu closes the card, loses its marker and is announced in a SnackBar.
- The my-position button explains a missing position in a SnackBar, with the matching action.

## Church details

**File:** `lib/church_details/church_details_page.dart`

| Feature | Behavior |
|---|---|
| Header | Collapsing `SliverAppBar` with the church photo (or blurred placeholder), name, and common name. |
| Favorite toggle | Heart icon button, delegates to `FavoritesService.toggle`. |
| Report a problem | Opens `ReportProblemPage` (see below). Greyed out while the page shows a **no connection** or **server error** mark; a tap then only explains why, and the button comes back by itself once a retry succeeds. |
| "Today" / "This Sunday" Mass chips | Two labeled rows of time chips inside a card, from the cached 20-day schedule. The page draws from the cache at once, then asks the API for the church (`Church {"ids": [tid]}`, full) and its 20-day schedule (`NearbyMasses`) and writes both through (`ChurchScheduleLoader`, spec 0003). A failed call marks the card: (i) for no connection, a tinted card and (i) for a server error. A church reported removed shows "Ez a templom már nem szerepel a miserend.hu-n." in place of the schedule. |
| Next 19 days schedule | A horizontally-scrolling row of day cards ("Holnap" for tomorrow, otherwise the Hungarian weekday name + date), one per day that has masses. |
| Location card | A non-interactive CARTO Voyager map (`MiserendMap`) centered on the church, with a pin; tapping it opens the location in the device's installed map app (`map_launcher`, always the **first** installed app — no chooser). |
| Getting-there text | Optional free-text directions field from the dataset (`gettingThere`), HTML-unescaped before display; hidden entirely if absent. |
| Directions button | "ÚTVONAL" — opens turn-by-turn directions in the same default map app. |

## Report a problem

**Files:** `lib/church_details/report_problem_page.dart`, `lib/church_details/problem_report_sender.dart`; spec 0009

- A full-screen page (purple AppBar "Hibajelentés") headed by the church's name. Three radio buttons (Rossz pozíció / Rossz miseidőpont / Egyéb), none chosen at first; a description that is always required; an optional email address, checked for shape when given.
- Sends `MiserendApiClient.report` → `POST https://miserend.hu/api/v4/report` with `tid`, `pid` (0/1/2), the trimmed `text`, `email` only when given, and `dbdate` = the day of the details page's `dataAsOf`. Success is read off the body: `error: 1` is a server error, not a sent report.
- While sending, the button shows a spinner and cannot be tapped again. A sent report closes the page with "Hibajelentés elküldve" and remembers the email (`shared_preferences`) for the next report. A failed one keeps the page and what was typed, with a message for **no connection** or for **server error**; the server's own text is not shown. No offline queue.

## Feedback and About

**Files:** `lib/widgets/feedback_mail.dart`, `lib/about/about_page.dart`, `lib/home/widgets/home_menu_button.dart`; spec 0009

- **Feedback** is about the app, not a church's data, and goes by mail to `szentjozsefhackathon@jezsuita.hu` — no API endpoint takes it. It opens the mail app directly, no in-app form: subject "Miserend app – visszajelzés", an empty space for the user, then `---` and the app version, build number and OS with its version (`package_info_plus`, `dart:io` `Platform`). No device model, location or identifier. The `mailto:` query is encoded by hand, spaces as `%20`. Without a mail app a snackbar gives the address instead.
- **Az appról** (purple AppBar): "Miserend", "Verzió: x.y.z (build)", "Az adatokat a miserend.hu szolgáltatja." (opens the site), "Készítette: Szent József Hackathon", a "Visszajelzés küldése" button and "Nyílt forrású licencek" (Flutter's `showLicensePage`).

## Favorites (cross-cutting)

**Files:** `lib/database/favorites_service.dart`, `lib/database/local_database.dart`, `lib/database/favorite.dart`

- Favorites are **local-only** — stored in a separate on-device SQLite file (`localdatabase.sqlite3`), never synced to any server or account. Uninstalling the app or clearing app data loses them.
- `FavoritesService` is the single app-wide `ChangeNotifier`, provided at the root (`main.dart`) — every screen that shows a favorite state (list items, details page) reads through it, so toggling anywhere updates everywhere without an explicit refresh.

## Permissions & platform capabilities in use

- **Location** (`ACCESS_FINE_LOCATION` on Android, `NSLocationWhenInUseUsageDescription` in `ios/Runner/Info.plist`) — for "nearby" churches/masses and initial map centering.
- **Internet** — database download, API v4 calls, map tiles, problem reports.
- **Storage** (`READ/WRITE_INTERNAL_STORAGE`, Android) — for the downloaded SQLite file (largely a no-op on modern Android scoped storage, but declared).

## Explicitly out of scope / not present

- No user accounts, login, or server-synced state of any kind.
- No offline map tiles — the CARTO Voyager tiles of the Map tab and of the location card on the details page require network.
- No localization — every string in the UI is a hardcoded Hungarian literal; there is no `intl` message catalog despite the `intl` package being a dependency (it's used only for date formatting).

## Tests

`test/` mirrors `lib/`: unit and widget tests for the API client, the cache and bootstrap import, the list and schedule loaders, the three tabs, the details page and the shared widgets. API responses are recorded JSON fixtures in `test/fixtures/`; location and favorites are faked (`fake_location_provider.dart`, `fake_favorites_service.dart`). Run with `flutter test`.
