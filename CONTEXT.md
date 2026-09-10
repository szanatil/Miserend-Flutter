# Miserend Flutter

A miserend.hu (templomok és miserendek) mobil kliense. Ugyanazt a templom-adatbázist jeleníti meg, mint a miserend.hu webapp — a két rendszer közötti fogalmi egyezés (vagy eltérés) számít.

## Language

**Felekezet (denomination)**:
Melyik egyházi hagyományhoz tartozik egy templom. A miserend.hu webapp ezt egy több-értékű mezőként kezeli (`roman_catholic` / `greek_catholic` / egyéb), és ez alapján színezi/választja a térképi marker-ikont. A Flutter `Church` modell (`lib/database/church.dart`) ezzel szemben egyetlen `isGreek: bool?` mezőt tárol — ez csak a görögkatolikus/nem-görögkatolikus különbséget tudja kifejezni, a webapp "egyéb" kategóriáját nem. Ha valaha a marker-stílust is egyeztetni kell a webapp-pal (ld. `docs/adr/0001-*`), ezt a modellkülönbséget előbb fel kell oldani. **Ellenőrizve**: a v4 API `Church`/`Search`/`NearBy` válasza sem tartalmaz felekezet-mezőt (ld. `docs/adr/0002-*`) — az API v4-re állás nem oldja meg ezt a hiányt.
_Avoid_: vallás (túl tág)

**Aktív templom (active church)**:
A webapp domain modellje megkülönbözteti az "aktív" (rendszeres szentmisékkel rendelkező) és "inaktív" (miséző hely rendszeres mise nélkül) templomokat (`active` mező, 0/1) — ez is befolyásolja a webes térkép marker-színét. A Flutter `Church` modellben jelenleg nincs ilyen mező. **Ellenőrizve**: a v4 API válaszai sem tartalmazzák ezt a mezőt (ld. `docs/adr/0002-*`).
_Avoid_: nyitva/zárva (ez nem erről szól, a templom fizikailag létezik, csak nincs rendszeres mise)

**Tile provider**:
A térkép alaprétegét szolgáltató csempe-CDN. A miserend.hu webapp és a Flutter app is a CARTO Voyager raszter-csempéit használja (`{s}.basemaps.cartocdn.com/rastertiles/voyager/...`), nem a nyers OpenStreetMap csempeszervert — az OSM Tile Usage Policy ugyanis production forgalomra tiltja a közvetlen `tile.openstreetmap.org` használatát.
_Avoid_: "OSM térkép" önmagában (a csempe-forrás CARTO, az adat OSM — a kettő nem ugyanaz)

**Helyi gyorsítótár (local cache)**:
Az eszközön tárolt SQLite tábla(k), amelyek a v4 API válaszait tükrözik. Első indításkor a régi `miserend_v4.sqlite3` exportból töltődnek fel egyszeri **kezdeti feltöltéssel**, utána kizárólag API-hívások írják felül soronként. Nem önálló, tekintélyelvű adatforrás — az API v4 az (ld. `docs/adr/0002-*`).
_Avoid_: "az adatbázis" önmagában — korábban ez a teljes, letöltött SQLite fájlt jelentette; most már csak az API részleges, esetlegesen elavult tükrözése.

**Kezdeti feltöltés (bootstrap import)**:
Az első indításkor lezajló egyszeri művelet: a `miserend_v4.sqlite3` letöltése és a régi séma szerinti sorok átalakítása (mappelése) az API-alakú helyi sémára — beleértve a régi visszatérési-szabály oszlopok (`nap`, `periodus`, `datumtol`, `datumig`) egyszeri kiszámítását konkrét mise-időpontokra. Ezután többé nem fut le; nem tévesztendő össze a folyamatos, API-alapú frissítéssel.
_Avoid_: "adatbázis-frissítés" / "sync" erre a lépésre — az a folyamatos, API-alapú frissítést jelenti, nem az egyszeri importot.

**Napi miserend (daily masses)**:
Egy adott templom aznapi miséinek listája — ezt adja vissza közvetlenül a v4 API `Church`, `Search` és `NearBy` végpontjainak `misek` mezője (`idopont`/`informacio` párokként).
_Avoid_: a `misek` mezőt "a miserend"-nek nevezni — csak a mai napra vonatkozik, nem a kiterjesztett listára.

**Kiterjesztett miserend (extended schedule)**:
A templom-részletező oldal több napra (ma / következő vasárnap / 19 nap) kiterjedő miselistája egy adott templomhoz, szemben a napi miserenddel. Egyetlen v4 végpont sem adja ezt vissza közvetlenül, egy adott templomra szűkítve — előállítása a `NearbyMasses` végpont kombinálásával történik (ld. `docs/adr/0002-*`, `docs/spec/0003-*`).
_Avoid_: "miserend" önmagában, ha a hatókör (egy nap vs. több nap) számít.
