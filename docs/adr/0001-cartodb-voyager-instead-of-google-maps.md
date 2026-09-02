---
status: accepted
---

# CartoDB Voyager csempék Google Maps helyett

A Térkép tab (`GoogleMap` widget) és a templom-részletező helykártyája (Google Static Maps API) is a `google_maps_flutter` csomagra és egy kódba égetett, a repóban commitolt API kulcsra épült. A miserend.hu webapp már évek óta a CARTO Voyager raszter-csempéit (`{s}.basemaps.cartocdn.com/rastertiles/voyager/...`) használja Leaflet-tel — ez lett a mérce, hogy a két kliens vizuálisan és adatforrás szintjén is egyeztetett maradjon.

Döntés: a Google Maps SDK-t és a Static Maps API-t teljesen kivezetjük (natív iOS/Android API kulcs konfigurációval együtt), helyette a `flutter_map` csomag jeleníti meg ugyanazokat a CARTO Voyager csempéket (`subdomains: abcd`, `maxZoom: 19`, azonos attribúció-szöveg), mind a Térkép tabon, mind egy kicsi, beágyazott formában a helykártyán.

## Considered Options

- **Nyers `tile.openstreetmap.org`**: elvetve — az OSM Tile Usage Policy tiltja a production forgalmat, a webapp ezen már átment (#376: időszakos "Access blocked" hibák), ezért marad kikommentezve a webapp kódjában is, nem a default réteg.
- **`maplibre_gl` (vektoros csempék)**: elvetve — natív GL-renderelést és nagyobb komplexitást adna egy egyszerű, marker-alapú térképhez, miközben a webapp is raszteres Leaflet-csempét használ, nem vektorosat.

## Consequences

- A marker vizuális stílusa (webapp: felekezet + aktív/inaktív státusz szerint színezett SVG pin-ek) explicit **nem** része ennek a döntésnek — egyszerű pin marad. Ehhez előbb a `Church` modell hiányosságát kell feloldani (`isGreek: bool?` vs. webapp `denomination` + `active` mezői), ld. [CONTEXT.md](../../CONTEXT.md).
- A navigáció-választó (`map_launcher` jelenleg vakon az első telepített appot nyitja meg, iOS-en hiányzik az `LSApplicationQueriesSchemes`) kapcsolódó, de külön feladat, nem ennek a döntésnek a része.
- A kódba égetett Google Maps API kulcs a csere után az appban többé nem használt, de a Google Cloud Console-ban továbbra is érvényes marad — a rotálása/visszavonása emberi lépés, ez a döntés önmagában nem oldja meg.
