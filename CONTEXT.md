# Miserend Flutter

A miserend.hu (templomok és miserendek) mobil kliense. Ugyanazt a templom-adatbázist jeleníti meg, mint a miserend.hu webapp — a két rendszer közötti fogalmi egyezés (vagy eltérés) számít.

## Language

**Felekezet (denomination)**:
Melyik egyházi hagyományhoz tartozik egy templom. A miserend.hu webapp ezt egy több-értékű mezőként kezeli (`roman_catholic` / `greek_catholic` / egyéb), és ez alapján színezi/választja a térképi marker-ikont. A Flutter `Church` modell (`lib/database/church.dart`) ezzel szemben egyetlen `isGreek: bool?` mezőt tárol — ez csak a görögkatolikus/nem-görögkatolikus különbséget tudja kifejezni, a webapp "egyéb" kategóriáját nem. Ha valaha a marker-stílust is egyeztetni kell a webapp-pal (ld. `docs/adr/0001-*`), ezt a modellkülönbséget előbb fel kell oldani.
_Avoid_: vallás (túl tág)

**Aktív templom (active church)**:
A webapp domain modellje megkülönbözteti az "aktív" (rendszeres szentmisékkel rendelkező) és "inaktív" (miséző hely rendszeres mise nélkül) templomokat (`active` mező, 0/1) — ez is befolyásolja a webes térkép marker-színét. A Flutter `Church` modellben jelenleg nincs ilyen mező.
_Avoid_: nyitva/zárva (ez nem erről szól, a templom fizikailag létezik, csak nincs rendszeres mise)

**Tile provider**:
A térkép alaprétegét szolgáltató csempe-CDN. A miserend.hu webapp és a Flutter app is a CARTO Voyager raszter-csempéit használja (`{s}.basemaps.cartocdn.com/rastertiles/voyager/...`), nem a nyers OpenStreetMap csempeszervert — az OSM Tile Usage Policy ugyanis production forgalomra tiltja a közvetlen `tile.openstreetmap.org` használatát.
_Avoid_: "OSM térkép" önmagában (a csempe-forrás CARTO, az adat OSM — a kettő nem ugyanaz)
