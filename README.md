# Miserend

A [miserend.hu](https://miserend.hu) mobilalkalmazása Androidra és iOS-re. Katolikus templomokat és miseidőpontokat lehet vele keresni név vagy település szerint, a közelben és térképen. A legtöbb képernyő kapcsolat nélkül is működik, a legutóbb letöltött adatokból.

Az app Flutterrel készült, és ugyanazt a templom-adatbázist jeleníti meg, mint a miserend.hu weboldal. Saját szervere nincs.

## Funkciók

- **Templomok fül:** a közeli templomok távolság szerint rendezve, a kedvenc templomok, és mindegyiknél a mai misék.
- **Misék fül:** a legközelebbi, még elérhető misék a környéken, időrendben, a kezdési időpont szerint csoportosítva, és mindegyiknél a mise jellemzői.
- **Térkép fül:** az összes templom a térképen, az egymást takaró jelölők csoportba rendezve, a jelölőre koppintva a templom kártyájával.
- **Keresés:** templomnév (az alternatív nevek is) vagy település alapján, kis-nagybetűtől és ékezettől függetlenül, már gépelés közben is kínál találatokat. A javaslatok aljáról nyílik a **Részletes kereső**, amely több feltétel együttesével keres: név, település, liturgikus nyelv, valamint hogy van-e miséje a templomnak egy adott napon és időablakban.
- **Templom adatlapja:** a mai és a vasárnapi misék, a következő napok miserendje, a templom helye a térképen, útvonaltervezés, és hibabejelentés a miserend.hu-nak.
- **Kedvencek:** csak a készüléken tárolódnak, fiók nincs.
- **Névjegy:** az alsó navigációból nyíló oldal. Legfelül egy gomb, amellyel e-mailben lehet visszajelzést küldeni az app fejlesztőinek; alatta a nap templom-ajánlata, majd az app kiadója és támogatása (1%), fejlesztője és verziója, a forráskód linkje, végül a miserend.hu webes változatának linkje.
- **Offline működés:** ha nincs kapcsolat, a képernyők a helyi gyorsítótárból dolgoznak, és jelzik, hogy az adat nem friss.

## Futtatás

Szükséges hozzá a [Flutter SDK](https://docs.flutter.dev/get-started/install) (Dart `^3.7.2`), valamint egy Android vagy iOS eszköz vagy emulátor.

```sh
flutter pub get
flutter run
```

Első indításkor az app letölti a miserend.hu teljes adatbázis-exportját, ehhez internetkapcsolat kell.

### Térképkulcs (nem kötelező)

A térkép a CARTO Voyager csempéit használja. Kulcs nélkül az ingyenes csempeszerverről tölt, ami fejlesztéshez elég. Saját kulcsot így lehet megadni:

```sh
flutter run --dart-define=CARTO_API_KEY=<kulcs>
```

## Tesztek és minőség

```sh
flutter test
dart format .
flutter analyze
```

A Dart-kód írásának szabályai a [CODING_STANDARDS.md](CODING_STANDARDS.md)-ben vannak.

A CI ([.github/workflows/ci.yml](.github/workflows/ci.yml)) minden PR-en és minden main-pushon lefuttatja ezt a három ellenőrzést, és az appot Androidra és iOS-re is lebuildeli. A Flutter-verzió a ci.yml-ben van rögzítve.

### App-ikon

Az ikon forrásképeit (`assets/icon/`) a [tool/app_icon/render_app_icon.swift](tool/app_icon/render_app_icon.swift) rajzolja, a platformonkénti méreteket a `flutter_launcher_icons` készíti. A lépések a [flutter_launcher_icons.yaml](flutter_launcher_icons.yaml) elején vannak.

## Hogyan épül fel?

**Adatforrások.** Két forrásból dolgozik az app, mindkettő a miserend.hu API v4-e:

- a naponta generált **SQLite export**, amelyet az app első indításkor egyszer letölt;
- az **API végpontjai** (például `Church`, `NearBy`, `NearbyMasses`), amelyek a friss adatot adják.

Részletek: [ADR-0002](docs/adr/0002-api-v4-mint-elsodleges-adatforras.md).

**Helyi gyorsítótár.** Az első letöltés után az app az exportból feltölti a gyorsítótárat: az összes templomot és a következő 30 nap miséit. A képernyők először mindig a gyorsítótárból rajzolnak, majd a háttérben meghívják az API-t, és a választ visszaírják a gyorsítótárba. Ha a hívás nem sikerül, a korábbi adat marad látható. Részletek: [ADR-0003](docs/adr/0003-offline-mukodes-helyi-gyorsitotarbol.md).

**Térkép.** `flutter_map` CARTO Voyager csempékkel, Google Maps helyett. Részletek: [ADR-0001](docs/adr/0001-cartodb-voyager-instead-of-google-maps.md).

**Kódszerkezet (`lib/`):**

| Mappa | Tartalom |
|---|---|
| `api/` | az API v4 kliense és a gyorsítótárba visszaíró réteg |
| `database/` | a letöltött export, a helyi gyorsítótár (`cache/`) és a kedvencek |
| `home/` | a főképernyő és a három fül (`churches/`, `masses/`, `map/`), a keresés és a Részletes kereső (`advanced_search/`) |
| `church_details/` | a templom adatlapja és a hibabejelentés |
| `about/` | a Névjegy oldal és a „Mai templom ajánlatunk” |
| `widgets/` | közös widgetek, például a térkép |

Az egyes képernyők pontos működését a [docs/FEATURE-COVERAGE.md](docs/FEATURE-COVERAGE.md) írja le.

## Hogyan dolgozunk?

- A feladatok a GitHub Issues-ban vannak. Egy nagyobb funkcióból előbb specifikáció készül a [docs/spec/](docs/spec/)-be, és csak utána a kód.
- Egy változás akkor kész, ha teljesíti a [CODING_STANDARDS.md](CODING_STANDARDS.md) „C. Kész” részének feltételeit, és a PR-en zöld a CI.
- A commit-üzenet magyar, és ezt a formát követi: `Terület: mi változott (#issue)`, például `Misék fül: időpont-blokkok (#36)`.
- Az issue-k kezelését és a címkéket a [docs/agents/](docs/agents/) írja le.

## További dokumentáció

- [CONTEXT.md](CONTEXT.md): a szakkifejezések szótára, és hogy miben egyezik vagy tér el a fogalomhasználat a miserend.hu weboldalétól.
- [docs/adr/](docs/adr/): az architektúra nehezen visszafordítható döntései.
- [docs/spec/](docs/spec/): az egyes funkciók specifikációi.
- [docs/FEATURE-COVERAGE.md](docs/FEATURE-COVERAGE.md): mit tud jelenleg az app, képernyőnként.

A fejlesztés részben AI-ügynökökkel folyik. Az ügynököknek szóló utasítások a [CLAUDE.md](CLAUDE.md)-ben és a [docs/agents/](docs/agents/) mappában vannak.
