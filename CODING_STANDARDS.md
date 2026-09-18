# Kódolási szabályok

A Miserend Flutter kódjának írott szabályai: ezeket követi az új és a módosított kód, és ezekhez méri a `/code-review` a diffet. Minden szabálynak azonosítója van (pl. **K2**); a review ezzel hivatkozik rá.

Ami nem ide tartozik, annak megvan a saját forrása:

- **Formázás**: `dart format lib test`.
- **Lint**: `flutter analyze`, a szabályok az [analysis_options.yaml](analysis_options.yaml)-ban. Ami ott van, azt ez a fájl nem ismétli.
- **Fogalmak** (Nincs kapcsolat, Helyi gyorsítótár, Elérhető mise…): [CONTEXT.md](CONTEXT.md).
- **Döntések és indokaik**: [docs/adr/](docs/adr/), képernyőnként a [docs/spec/](docs/spec/).

Ha jó okkal térsz el egy szabálytól, ugyanabban a PR-ben módosítsd a szabályt.

## A. Adatáramlás

**A1 — A képernyő loaderen át kap adatot.** Egy lap vagy képernyő (`lib/home/**`, `lib/church_details/*_page.dart`) egy loadert hív; a `MiserendApiClient`-et és a `CacheDatabase`-t a loader használja. Minták: [ChurchListLoader](lib/home/churches/church_list_loader.dart), [ChurchScheduleLoader](lib/church_details/church_schedule_loader.dart), [NearestMassesLoader](lib/home/masses/nearest_masses_loader.dart).

**A2 — Gyorsítótár először.** A loader két lépést ad: az egyik (`load`, `loadCached`) azonnal a gyorsítótárból olvas, a `refresh` az API-t kérdezi, a választ a `CacheWriteThrough`-val a gyorsítótárba írja, és a listát onnan olvassa újra (ADR-0003). A képernyő az API válaszát a gyorsítótáron át kapja. A két kivételt (legközelebbi misék, gyóntatás) a CONTEXT.md, „Helyi gyorsítótár" sorolja fel.

**A3 — A sikertelen frissítés a mutatott sorokat hagyja meg.** A hiba okát (`ApiFailure`) a loader az eredmény-objektumban adja vissza (pl. `ChurchList.failure`); a képernyő ebből dönt a jelölésről, kivételt nem kap.

**A4 — A magyar mezőnevek a határon maradnak.** Az API JSON-kulcsai (`nev`, `misek`, `hianyzo`…) és a gyorsítótár oszlopai csak a [MiserendApiClient](lib/api/miserend_api_client.dart), a [CacheDatabase](lib/database/cache/cache_database.dart) és a [BootstrapImporter](lib/database/cache/bootstrap_importer.dart) kódjában szerepelnek. A többi kód angol nevű modelleken dolgozik: `ChurchDetails`, `ChurchListEntry`, `CachedMass`.

**A5 — Az API időpontja falióra-idő.** Mise- és szentségimádás-időpontot a `parseApiDateTime` olvas; az időzóna-eltolást levágja, nem számolja át.

## B. Kimenetek és hibák

**B1 — A várható kimenet típus, nem kivétel.** Ahol egy műveletnek több, a felhasználó számára eltérő kimenete van, az `sealed class` + `final class` alosztályok, és a hívó kimerítő `switch`-csel kezeli, `default` ág nélkül. Minták: `ApiResult` ([api_result.dart](lib/api/api_result.dart)), `PositionResult` ([location_provider.dart](lib/location_provider.dart)). A `NearestMassesLoader` kivételei (`LocationUnavailable`, `MassesUnavailable`) ennél a mintánál korábbiak, nem követendők.

**B2 — Az API-kliens minden hívása `ApiResult`-ot ad.** Ami a válasz megérkezése előtt romlik el, az `noConnection`; ami a válasszal, az `serverError`; az üres válasz `ApiSuccess`. Új végpont a `_post` és a `_map` segédfüggvényen át hív, így ezt a felosztást örökli.

**B3 — Mindent elkapó `catch` csak a peremen.** Ott, ahol a felhasználó újrapróbálhat, vagy a művelet csendes háttérmunka (kezdeti feltöltés, kedvencek előfrissítése, helymeghatározás). Mellette egy komment mondja meg, miért elfogadható a lenyelés, és `debugPrint` naplózza az okot. A napló az okot írja, nem az adatot: koordináta, API-válasz vagy kérés-törzs nem kerül bele, mert a `debugPrint` release buildben is kiír.

## K. Képernyők és widgetek

**K1 — A függőség konstruktorban cserélhető.** Loader, `LocationProvider`, óra: opcionális konstruktor-paraméter, a State-ben `late final _loader = widget.loader ?? ChurchListLoader();`. A paraméter doc-kommentje: `/// Injected by tests; the page builds its own otherwise.` Provideren át csak az app-szintű `FavoritesService` érkezik.

**K2 — `await` után a State még él?** Ha `await` után `setState` vagy `context` jön, előtte `mounted`-ellenőrzés áll. Az újratölthető lapok betöltésenként léptetett azonosítóval (`_loadId`, `current()`) vetik el a lassú, már elavult választ. Minta: `_load` a [near_churches_page.dart](lib/home/churches/near_churches_page.dart)-ban.

**K3 — Az idő injektált óra.** A „most"-ot `DateTime Function() clock = DateTime.now` mező adja, így a teszt tetszőleges időpontra állíthatja.

**K4 — Nyelvek.** A felhasználónak szóló szöveg magyarul, a widgetben helyben áll. Azonosítók, kommentek és tesztnevek angolul.

**K5 — Közös elem a közös helyen.** Több helyen használt szín a `CustomColors`-ban ([colors.dart](lib/colors.dart)). Több képernyő widgetje a [lib/widgets/](lib/widgets/)-ben, egy képernyőé a `<képernyő>/widgets/` alatt. Betöltés-, üres-, offline- és helyzet-állapotra a meglévők: `LoadingView`, `MessageView`, `PullableFill`, `OfflineBanner`, `OfflineInfoButton`, `PositionUnavailableView`.

## D. Dokumentációs kommentek

**D1 — A `///` a miértet mondja.** Minden publikus osztályon, és azon a mezőn, metóduson, amelynek jelentése nem nyilvánvaló a nevéből: mit jelent, és milyen szakmai ok miatt ilyen. A lépéseket a kód mondja el.

**D2 — Fogalomra és döntésre forrással hivatkozunk.** `(CONTEXT.md, „Nincs kapcsolat")`, `(ADR-0003)`, `(spec 0005, „Végpontok")`.

**D3 — Minden határérték nevesített konstans.** Időkorlát, limit, sugár, életkor: `static const`, doc-kommenttel az okáról. Minta: `callTimeout`, `_massLimit` a [MiserendApiClient](lib/api/miserend_api_client.dart)-ben, `maxPositionAge` a [LocationProvider](lib/location_provider.dart)-ben.

## M. Adatbázis-séma

**M1 — A séma csak előre lép, a meglévő adatot megtartva.** A `CacheDatabase` sémájának változásakor a `version` eggyel nő, az `onCreate` a teljes új sémát hozza létre, az `onUpgrade` pedig új `if (oldVersion < N)` ágat kap. A már kiadott ágakhoz nem nyúlunk: a telepített appok ezeken lépnek át. A frissítést teszt ellenőrzi, amely az előző verzió sémájával létrehozott fájlt nyit meg. Minta: `'upgrading from version 2 keeps the masses and marks their source'` a [cache_database_test.dart](test/database/cache_database_test.dart)-ban.

## T. Tesztek

**T1 — A `test/` a `lib/` szerkezetét tükrözi**: `lib/home/churches/x.dart` → `test/home/churches/x_test.dart`.

**T2 — A tesztnév viselkedést leíró angol mondat**, pl. `'a failed first import stops on an error with a retry'`. A `group` az esetet vagy állapotot nevezi meg.

**T3 — A hamis függőség kézzel írt alosztály.** `class _FakeLocation extends LocationProvider`, privátként a tesztfájlban. Ha több tesztfájl használja, saját fájlba kerül a tesztek mellé (minta: [fake_church_list_loader.dart](test/home/churches/fake_church_list_loader.dart)).

**T4 — HTTP: `MockClient` és rögzített válasz.** A `package:http/testing` `MockClient`-je élő API-ból rögzített JSON-t ad vissza a [test/fixtures/](test/fixtures/)-ből; a fájlnév a végpontot, a tárgyat és a rögzítés dátumát mondja (`nearby_budapest_2026-09-15.json`). Ez a [MiserendApiClient](lib/api/miserend_api_client.dart) leképezésének tesztjére vonatkozik. A loader- és a gyorsítótár-tesztek, amelyek pontosan beállított adatot várnak (azonosítók, mai misék, `hianyzo`), a `MockClient`-ből célzott, kézzel épített JSON-t is adhatnak; a mezők leképezését ott már nem ellenőrzik újra.

**T5 — Adatbázis: in-memory SQLite.** `sqfliteFfiInit()`, `databaseFactory = databaseFactoryFfi`, `CacheDatabase.create(path: inMemoryDatabasePath)`.

**T6 — A widget teszt azt keresi, amit a felhasználó lát.** A lapot hamis loaderrel pumpálja, és a magyar szövegre keres (`find.text`). Időkorlátot `testWidgets`-ben, `tester.pump(Duration)`-nel teszteljük: ott az óra hamis, a várakozás nem kerül időbe.

## R. Régi kód — befagyasztva

A SQLite export korából maradt, ma már csak a kezdeti feltöltést és néhány átadási pontot szolgáló kód:

- `Church` ([lib/database/church.dart](lib/database/church.dart)), `Mass` ([lib/database/mass.dart](lib/database/mass.dart))
- `MiserendDatabase`, `DatabaseManager`, `Preferences`, `MassFilter`

**R1 — Új kód a gyorsítótár modelljeire épül.** Új képernyő, loader vagy modell a `ChurchDetails` / `ChurchListEntry` / `CachedMass` típusokat és a `CacheDatabase`-t használja. Egy meglévő átadási pont, amely régi típust vár (pl. `ChurchDetailsPage(church:)`), használható úgy, ahogy van.

**R2 — Régi kódhoz nyúlni hibajavításért szabad**, és ilyenkor az átköltöztetés nem kötelező. A régi kód stílusa (pl. `_checkDatabase() async` visszatérési típus nélkül) nem minta.

## C. Kész

Egy változás akkor kész, ha mindegyik teljesül:

A C1–C3-at és az Android- meg iOS-buildet a CI ([.github/workflows/ci.yml](.github/workflows/ci.yml)) minden PR-en és a `main`-re érkező pushon ellenőrzi, az ott rögzített Flutter-verzióval.

**C1 — Formázva.** A `dart format --set-exit-if-changed lib test` nem jelez eltérést.

**C2 — Lint tiszta.** A `flutter analyze` hiba és figyelmeztetés nélkül fut le.

**C3 — A tesztek zöldek.** `flutter test`.

**C4 — Az új viselkedésnek van tesztje.** Az új vagy megváltozott viselkedést a T1–T6 szerinti teszt rögzíti. Hibajavításnál olyan teszt, amely a javítás előtt elbukott volna.

**C5 — A sémaváltozás az M1-et követi.**

**C6 — A dokumentáció követi a kódot.** Ha változott egy fogalom, az a [CONTEXT.md](CONTEXT.md)-be kerül; ha egy döntés, egy ADR-be; ha egy képernyő viselkedése, a [docs/spec/](docs/spec/)-be; ha a funkciólefedettség, a [docs/FEATURE-COVERAGE.md](docs/FEATURE-COVERAGE.md)-be.
