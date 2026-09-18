# Feature Coverage — Miserend

Reverse-engineered from the codebase and kept up to date with it. This is a description of **what the app currently does**, not a plan for what it should do — treat it as a snapshot, not a spec to build against once the code has moved on.

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
| Bottom navigation | Three tabs: **Templomok** (Churches), **Misék** (Masses), **Térkép** (Map) — switches the body widget via local `_selectedIndex` state, no routing — and a fourth item, **Névjegy** (below). |
| Search bar | A `SearchAnchor.bar` in the app bar. Live-updates suggestions as the user types, but only once the query is **longer than 2 characters** (`_onSearchChanged`). |
| Search suggestions | Combines up to 20 matching **churches** (by name, common name, alternative name or city) and any matching **cities** (distinct `varos` values), both ignoring case and accents (`searchText`), from the cache into one suggestion list, each rendered with its own tile type (`ChurchSuggestion`, `CitySuggestion`). No API call (`SearchSuggestions`). |
| Suggestion tap-through | Tapping a church suggestion opens `ChurchDetailsPage` directly; tapping a city suggestion opens `SearchResultsPage` scoped to that city. |
| Search submit | Pressing enter/search on a raw term (not from a suggestion) opens `SearchResultsPage` scoped to that free-text term. |
| Részletes kereső row | The last row of the suggestions, always — also below 3 characters and with no suggestion — pinned under them. Opens the **Részletes kereső** in the tab's place, with the typed text as the name; the search bar and the bottom navigation stay. Any tab, the back arrow and the system back close it; a search or suggestion from the bar closes it too, and the row always opens it afresh. |
| Clearing the bar | After a search, a church or city suggestion, or the Részletes kereső row, the bar's text and suggestions are cleared, so old suggestions do not come back; the Részletes kereső takes the typed name before the clearing. |
| Névjegy | A fourth bottom navigation item with an ⓘ icon. Not a tab: it pushes `AboutPage` and the selected tab stays. |

## Részletes kereső

**Files:** `lib/home/advanced_search/advanced_search_page.dart`, `advanced_search_loader.dart` (spec 0010)

- Conditions: a part of the name (name, common name, alternative names), a part of the city with suggestions from the cache, one liturgical language (those occurring in the cache, Hungarian left out), a day (Ma / Holnap / Vasárnap / Dátum…, up to 90 days ahead) and, with a day, a closed time window or the whole day. Every condition given has to hold. A name, a city or a known position is required; otherwise the Keresés button is off with an explanation.
- A day condition matches a church with at least one **mass** (not confession, vespers…) starting in the window.
- Results are church cards, whose chips show the matching masses of the searched day (today's without a day). Order: by city and name with a city; nearest first, with the distance on the card, with a known position; by name otherwise.
- After a search the conditions fold into a pinned summary („Pécs · vasárnap 8–12 · latin"); tapping it opens them again, and folding them without a search restores the last search's conditions.
- Paging by 20 candidates from the cache. Without a day, no API call. With a day, each page asks `Church {"ids"}` (for removed churches) and each located candidate's masses on that day (`NearbyMasses`, 0.1 km), writes them through, and filters. A page that does not fill the screen asks for the next by itself. A count badge („8 / 12+ találat") shows while scrolling.
- A failed call decides from the cached masses and shows the usual Nincs kapcsolat / Szerverhiba banner, which retries by itself.

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
- Loading, position-unavailable (by reason, with a button), API-error and empty states.
- Under a purple "Mai misék" section bar (`SectionBar`, shared with the Templomok tab and the Map's "Térkép"). Masses starting at the same time are grouped under one header (`MassStartHeader`, spec 0008): the 24h start, large and bold, then the time until it or "Épp most tart", and a line under them.
- Each `MassCard` shows the cached thumbnail, church name (the church card's size), city, distance ("1,2 km") and a non-"Szentmise" title; the start is on the header, not the card. Tapping it opens `ChurchDetailsPage`.
- **Mass details** (spec 0011): once the list is shown, one `Church {"ids"}` call (`minimal`, written through) for the churches on it; the detail after the kind in today's `informacio` of the mass starting at the same time goes into its own row under the city, each part in a yellow bubble, wrapping as needed. The seven mass types (Csendes, Gitáros, Diák…) get their icon from `assets/types/` beside the word (`mass_detail.dart`). Tapping a bubble shows its full text in a tooltip, without opening the church. A failed call shows the cards without details, unmarked.

## Map tab

**File:** `lib/home/map/map_page.dart`

- CARTO Voyager tiles (`MiserendMap`, ADR-0001), default camera centered on Hungary, moved to the user's position when one is available at opening.
- A marker for **every** church of the cache (no viewport-based lazy loading), grouped while the pins would overlap: a purple circle with the count, which zooms in on a tap; churches on one spot open out in a circle. The selected church and the user's position are never grouped (spec 0012).
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

## Névjegy and feedback

**Files:** `lib/widgets/feedback_mail.dart`, `lib/about/about_page.dart`, `lib/about/impressum_page.dart`, `lib/about/church_of_the_day_loader.dart`; spec 0009, spec 0014

- **Feedback** is about the app, not a church's data, and goes by mail to `szentjozsefhackathon@jezsuita.hu` — no API endpoint takes it. It opens the mail app directly, no in-app form: subject "Miserend app – visszajelzés", an empty space for the user, then `---` and the app version, build number and OS with its version (`package_info_plus`, `dart:io` `Platform`). No device model, location or identifier. The `mailto:` query is encoded by hand, spaces as `%20`. Without a mail app a snackbar gives the address instead.
- **Névjegy page** (purple AppBar "Névjegy", on the same grey as the Templomok and Misék lists): a **miserend.hu** tile that opens the web version in the browser, a **Mai templom ajánlatunk** card, a **Verzió** tile ("x.y.z (build)"), an **Impresszum** tile, and a **Visszajelzés** button that opens the feedback mail.
- **Impresszum page:** the publisher (Jézus Társasága Magyarországi Rendtartománya, 1085 Budapest, Horánszky u. 20., link to jezsuita.hu), the developer (Szent József Hackathon), the 1% offer to the Jézus Társasága Alapítvány with its tax number and a copy button, a link to the GitHub repository, and **Felhasznált licencek**, which opens Flutter's licence page.
- **Mai templom ajánlatunk:** a card with the church's photo, name, address and the first four lines of its description; a tap opens its details page. Only churches with a photo are picked (`CacheDatabase.photographedChurchCount` / `photographedChurchAt`). Ten candidates are drawn from a date-seeded random sequence, so the day keeps its choice; the first with a description wins. The bootstrap import carries no description, so the card shows from the cache at once, then one full `Church {"ids"}` call writes all ten through and the pick is made again — later openings that day show the described church straight away. A failed call keeps the cached pick, unmarked.

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
