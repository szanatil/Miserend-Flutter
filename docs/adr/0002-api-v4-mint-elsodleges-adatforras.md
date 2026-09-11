---
status: accepted
---

# API v4 mint elsődleges adatforrás, a helyi SQLite mint gyorsítótár

Az app ma egy naponta generált, statikus SQLite exportot (`miserend_v4.sqlite3`) tölt le és használ egyetlen adatforrásként. A miserend.hu backend időközben egy valódi, verziózott JSON API-t épített ki (`/api/v4`), és minden új funkció (szentségimádás, gyóntatás, fotók, egyházmegye/plébánia adatok stb.) ezen készül — a SQLite export ezekkel a mezőkkel nem bővül, csak visszamenőlegesen kompatibilis marad.

Döntés: az API v4 lesz az elsődleges, tekintélyelvű adatforrás minden olvasáshoz és a már ma is API-n keresztül működő íráshoz (`Report`); a helyi SQLite szerepe megváltozik — már nem önálló, teljes adatbázis, hanem az API válaszainak írás-áteresztő gyorsítótára. Első indításkor letöltjük és a régi sémáról átalakítjuk (mappeljük) az API-alakú helyi sémára — ez egy egyszeri **kezdeti feltöltés**, nem ismétlődő szinkronizáció. Ezután a helyi gyorsítótár tartalma kizárólag API-hívásokból frissül, soronként, ahogy az egyes képernyők API-hívásokra állnak át; a letöltött SQLite fájlt az onboardingon túl többé nem töltjük le újra és nem használjuk frissítésre. A bevezetés fokozatos, képernyőnként — elsőként a templom-részletező oldal (ld. `docs/spec/0003-*`).

## Considered Options

- **Helyi SQLite marad a fő adatforrás, API csak új funkciókhoz.** Elvetve: az API-n megjelenő új mezők (fotók, leírás, egyházmegye stb.) sosem kerülnének be a helyi sémába, a két rendszer tartósan szétválna.
- **API v5 (RRULE-alapú miserend-modell) azonnali bevezetése.** Elvetve: a dokumentáció szerint a mezőszerkezet még változhat ("data structure still evolving") — ez load-bearing függőség lenne egy zökkenőmentesnek szánt migráció első fázisában. Hipotézisként rögzítve egy jövőbeli fázishoz.
- **Teljes autentikáció (Login/Signup/szerveroldali Favorites/Upload) bevezetése ebben a fázisban.** Elvetve: a 15 perces, refresh endpoint nélküli API token jelentős UX-komplexitást adna hozzá. Hipotézisként rögzítve egy jövőbeli fázishoz.
- **A kezdeti SQLite-importot rendszeresen (pl. naponta) újra lefuttatni, a jelenlegi mechanizmushoz hasonlóan.** Elvetve — explicit felhasználói döntés: az onboardingon túl a SQLite export többé nem szerepel a frissítési útvonalban, a "kiterjesztett miserend" hiányát is API-only megoldással kell feloldani (ld. Consequences).

## Consequences

- A "kiterjesztett miserend" (ma/vasárnap/19 nap nézet) nem kérhető le közvetlenül egyetlen v4 végponttól sem, egy adott templomra szűkítve — a `Church` végpont `misek` mezője csak a **mai** miséket adja vissza. Ezt a `NearbyMasses` végpont dátumtartomány-szűrésével, a templom saját koordinátáira szűkített minimális (0.1 km) sugárral és utólagos, kliensoldali `church.id` szűréssel kell előállítani (ld. `docs/spec/0003-*`). Ez egy API-specifikus munkakörüli megoldás, nem egy natívan támogatott lekérdezés — ha a v4 API bővül egy dedikált, egy templomra szűkített többnapos miserend-végponttal, ezt érdemes lecserélni.
- A `Church`/**Felekezet**/**Aktív templom** modellhiány (ld. [CONTEXT.md](../../CONTEXT.md)) ezzel a döntéssel **nem** oldódik meg: a v4 API `Church`/`Search`/`NearBy` válasza sem tartalmaz felekezet- vagy aktív-státusz mezőt (ellenőrizve élő API-hívással). Ez továbbra is nyitott, külön probléma marad.
- Az onboarding utáni SQLite-letöltés véglegesen kikerül a folyamatból — offline-first indítás csak a kezdeti feltöltésre támaszkodik. Ha az API hosszabb ideig elérhetetlen, az app adatai befagynak azon a ponton, ahol utoljára sikerült szinkronizálni (nincs többé napi automatikus teljes újratöltés, mint korábban).
- Amíg a bevezetés fokozatos, a helyi gyorsítótár vegyes frissességű: a már migrált képernyőn (templom-részletező) megnyitott templomok API-frissek, a még nem migrált képernyők (Keresés, Térkép, Közeli templomok/misék) a kezdeti feltöltésből származó, vagy alkalomszerűen (egy korábbi részletező-látogatásból) frissült adatot mutatják.
- A "stale-while-revalidate" alapszabály (a gyorsítótár tartalmát mutatjuk, amíg az API válasza meg nem érkezik) alól **a `gyontatas` mező kivételt képez**: ez egy fizikai kapcsoló pillanatnyi állása (ld. [CONTEXT.md](../../CONTEXT.md), „Gyóntatás"), nem a templom tartós tulajdonsága, ezért a UI kizárólag az adott munkamenetben érkezett API-válaszból jeleníti meg, a gyorsítótárból soha. A mező továbbra is *tárolódik* a gyorsítótárban (a sor teljes leképezése miatt), csak nem *olvasható vissza* megjelenítésre. Egy elavult „Most gyóntatnak!" rosszabb, mint a jelzés hiánya: elküldené a felhasználót a templomba.
