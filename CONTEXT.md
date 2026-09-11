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

**Gyóntatás (confession)**:
Nem miserend-adat és nem nyitvatartás, hanem egy **pillanatnyi állapot**: a miserend.hu gyóntatószékekbe szerelt fizikai kapcsolókat üzemeltet, amelyek LoRaWAN-on jelentik, hogy éppen van-e gyónási lehetőség (`POST /api/v4/lorawan`, tokenhez kötött, a `/apidocs` szerint kísérleti). A v4 `Church` válasz `gyontatas` mezője ennek a kapcsolónak az **aktuális** állása. **Ellenőrizve**: a mező puszta bool, és nem különbözteti meg a *kikapcsolt kapcsolót* a *nem létező kapcsolótól* — mindkettő `false`, miközben a webapp harmadik állapotként külön kiírja, hogy "Ezen a misézőhelyen nincs gyóntatást jelző kapcsoló". Élő mintavétel (2026-09-11, id 1–400): 338 válaszból 338 `false`. Következmény: a kliens csak a `true` esetet jeleníti meg, és csak friss API-válaszból — gyorsítótárazott értékből soha (ld. `docs/adr/0002-*`).
_Avoid_: "gyóntatási rend" / "gyóntatási időpontok" (azt sugallja, hogy menetrend, pedig egy kapcsoló állása); "van-e gyóntatás" (a `false` erre nem válasz).

**Frissítve (`frissitve`) vs. helyi szinkron (`local_synced_at`)**:
Két különböző tény, amelyeket könnyű összekeverni. A **frissítve** azt mondja meg, mikor szerkesztették utoljára az adatot **a miserend.hu oldalán** — ez a felhasználónak mutatott érték. A **helyi szinkron** azt, mikor beszélt **ez a készülék** utoljára az API-val az adott templomról (`null`, ha a sor csak a kezdeti feltöltésből származik) — ez belső, diagnosztikai mező, a UI nem mutatja.
_Avoid_: "frissítve" önmagában, ha nem egyértelmű, melyik oldalról van szó.

**Liturgikus nyelv jelölése (`nyelvek`)**:
Annak a nyelvnek a jelölése, amelyen a templomban misézni szoktak — **templom-szintű** adat, nem mise-szintű (a v4 API az egyes misékhez nem ad nyelvet, ld. `docs/spec/0003-*`). A mező **saját, zárt szókincset** használ, amely **se nem ISO 639 nyelvkód, se nem ISO 3166 országkód**, hanem a miserend.hu zászlókészletének kódja: az értékkészlet pontosan az `assets/flags/` fájlnevekkel egyezik. Ahol a nyelvhez nincs ország, ott saját jelkép áll: **`va`** (Vatikán zászlaja) = **latin**, **`cu`** (zöld mezőben arany hármas kereszt) = **ószláv**, **`rue`** (ruszin zászló) = **ruszin**. Ahol van ország, ott is az országkód áll a nyelv helyett: **`ua`** = ukrán (nem `uk`), **`gr`** = görög (nem `el`), **`si`** = szlovén (nem `sl`), **`tl`** = tagalog. **Ellenőrizve**: 500 templomot lekérdezve 12 kód fordul elő (`hu, va, en, de, fr, es, it, pl, sk, hr, ua, tl`), és mindegyikhez létezik zászló. **Csapda**: ISO 639-ként olvasva a kódok némán elromlanak — az `la` ebben a készletben *Laosz*, nem a latin.
_Avoid_: "nyelvkód" önmagában (azt sugallja, hogy ISO 639); "országkód" (a `va`/`cu`/`rue` nem ország).

**Szentségimádás (adoration)**:
Dátumozott időablakok listája (`kezdete`/`vege`/`fajta`/opcionális `info`), nem visszatérési szabály és nem mise. Ugyanarra a napra **átfedő** bejegyzések is érkezhetnek (pl. egy `00:00–23:59` és egy `09:00–18:00`); ezek nem hibák, és nem vonhatók össze, mert a teljes napos ablak jelenthet valódi örökimádást is.
_Avoid_: "adoráció-rend" / "szentségimádás miserendje" (nem menetrendi adat, és nem a `misek` mezőből jön).
