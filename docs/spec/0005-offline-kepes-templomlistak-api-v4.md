# Offline-képes templomlisták — a Keresés, a Közeli templomok, a Kedvencek és a Térkép API v4-re állítása

> **Állapot: kész, ticketekre bontandó.** Két grillezés (2026-09-15) döntései rögzítve; nyitott döntés nincs. Egy eszközön ellenőrizendő kockázat: ld. [Eszközön ellenőrizendő](#eszközön-ellenőrizendő).

## Problem Statement

Az ADR-0002 az API v4-et tette tekintélyelvű adatforrássá, és az 1. csomag (ld. „Further Notes") megszünteti a SQLite export heti újraletöltését. A Keresés (`lib/home/home.dart`, `lib/home/churches/search_results.dart`), a Közeli templomok (`near_churches_page.dart`), a Kedvencek (`favorite_churches.dart`) és a Térkép (`lib/home/map/map_page.dart`) viszont még mindig közvetlenül a letöltött exportot olvassa (`MiserendDatabase`). Ennek következményei:

- Újraletöltés nélkül ezeken a képernyőkön az adat befagy: új templom soha nem jelenik meg, javított koordináta vagy megszűnt templom nem jut el a készülékre.
- A mise-adat a régi séma évszám nélküli (`HHNN`) dátumaira épül; az 1. csomag lejárati védelme 182 nap után elrejti a miséket, vagyis ezek a képernyők fél év alatt mise nélkülivé válnak.
- A képernyők nem tudják jelezni, hogy amit mutatnak, nem online adat — nincs se hiba-, se offline-állapotuk (a Keresés találati listájának betöltés- és üres állapota sincs), és nincs mód újrapróbálásra.
- A kedvenc templomok miserendje offline csak akkor van meg, ha a felhasználó nemrég megnyitotta a részletezőt.
- Helyadat nélkül a Közeli templomok egyetlen, bármilyen hibára ugyanazt mondó szöveget mutat, gomb nélkül; a Térkép „helyzetem" gombja csendben nem csinál semmit (kezeletlen hiba, `map_page.dart:78-81`); a Misék fül szintén csak egy szöveget ad. A felhasználó egyik helyen sem tudja meg, mit tehet. A Közeli templomok ráadásul bármilyen régi utolsó ismert pozíciót elfogad, akár egy másik városból.

## Solution

A négy képernyő **mindig a helyi gyorsítótárból rajzol**, online is: a lista azonnal megjelenik, a háttérben egy API v4 hívás fut, amelynek válasza soronként a gyorsítótárba íródik, és a lista ezután egyszer újraolvassa a gyorsítótárat (ld. ADR-0003). Ha a háttérhívás 15 s-on belül nem ad választ, a képernyő a gyorsítótár állapotánál marad, és jelzi, hogy nem online adatot mutat — **Nincs kapcsolat** esetén (i) jelzéssel, **Szerverhiba** esetén eltérő színnel és (i) jelzéssel (ld. [CONTEXT.md](../../CONTEXT.md)). A listák lehúzással újrapróbálhatók. A napi miserend a listaválaszokból a gyorsítótárba íródik, a csipek csak misét mutatnak. A kedvenc templomok adatai és 20 napos miserendje naponta legfeljebb egyszer, induláskor előre frissül. A **Helyzet nem elérhető** állapot okonként mondja meg, mit tehet a felhasználó, és egy gombot ad hozzá — a Közeli templomokon, a Térképen és a Misék fülön egyformán. A képernyők a letöltött exportot többé nem olvassák; az export kizárólag a kezdeti feltöltés forrása marad.

## User Stories

1. Mint felhasználó, egy új, a miserend.hu-ra nemrég felvett templomot is szeretnék megtalálni keresésben és a közeli templomok között.
2. Mint felhasználó, lefedettség nélküli helyen is szeretnék templomot keresni név vagy település szerint, és látni a közeli templomokat — várakozás nélkül, ugyanúgy, mint online.
3. Mint felhasználó, offline is szeretném látni a térképen a templomokat, és egy markerre bökve a templom adatait.
4. Mint felhasználó, ha a lista nem online adatot mutat, szeretném ezt látni, és egy koppintással megtudni, mikori az adat és mit tehetek.
5. Mint felhasználó, akinek van térereje, de a miserend.hu nem válaszol, szeretném, hogy az app ne hibaüzenetet mutasson, hanem a tárolt adatot, feltűnően jelölve, hogy nem friss.
6. Mint felhasználó, a kedvenc templomom miserendjét hetekkel az utolsó megnyitása után, térerő nélkül is szeretném látni.
7. Mint felhasználó, ha egy általam megnyitott, kedvencnek jelölt vagy a térképen megbökött templom megszűnt, ne küldjön oda az app — se online, se offline.
8. Mint felhasználó, ha egy templom helyét a miserend.hu-n kijavították, a javított helyet szeretném látni a térképen és a közeli templomok között.
9. Mint felhasználó, aki soha nem engedélyezi az appnak az adatkapcsolatot, a telepítéskor betöltött templomokat és miséket szeretném látni, hibaüzenetek helyett egy tájékoztató jelzéssel.
10. Mint felhasználó, ha bekapcsoltam az adatkapcsolatot, a listát lehúzva szeretném frissíteni, anélkül, hogy el kellene hagynom a képernyőt.
11. Mint felhasználó, aki nem engedélyezte a helyadatot vagy kikapcsolta a helymeghatározást, szeretném megtudni, hogy ezért nem látom a közeli templomokat és a legközelebbi miséket, és egy gombbal pótolni tudni.
12. Mint felhasználó, a templomsorokon csak misék időpontjait szeretném látni, gyóntatást vagy szentségimádást nem.

## Implementation Decisions

### Rögzített döntések (grillezés, 2026-09-15)

**Betöltés**

- **A listák mindig a gyorsítótárból rajzolnak.** Megjelenéskor a képernyő a gyorsítótárból azonnal kirajzol, a háttérben elindítja a képernyő API-hívását, a válasz write-through a gyorsítótárba íródik, majd a lista egyszer újraolvassa a gyorsítótárat. A lista ekkor egyszer módosulhat (javított sor, új templom, megszűnt templom eltűnik). Ez a templom-részletező (spec 0003, `ChurchScheduleLoader`) és az ADR-0002 „stale-while-revalidate" szabályának folytatása. Az elvetett „online az API válasza a lista" változat indoklása az ADR-0003-ban.
- **Háttérhívás képernyőnként:**

  | Képernyő | Háttérhívás | Mit hoz |
  |---|---|---|
  | Keresés — javaslatok | nincs | — |
  | Keresés — találati lista | `Church {"ids": [a helyi találatok első ≤100 eleme]}`, `minimal` | javított adat, megszűnés, napi miserend a látott templomokra |
  | Keresés — találati lista, **0 helyi találat** | `Search {"q", "limit": 100}`, `minimal` | új templom |
  | Közeli templomok | `NearBy {"lat", "lon", "limit": 100}`, `minimal` | új és javított templom a közelben, napi miserend |
  | Kedvencek | `Church {"ids": [...]}`, 100-as kötegekben, `minimal` | javított adat, megszűnés, napi miserend |
  | Térkép — templomkártya | `Church {"ids": [tid]}`, `full` | a teljes templom, fotókkal (a részletezőt is előmelegíti) |

- **A helyi keresés a mai viselkedést viszi át** a gyorsítótárra: `nev`/`ismertnev` részszó, település szerint a település. A kis-nagybetű- és ékezetfüggetlen keresés: #12.
- **A Közeli templomok helyi listája korlátlan** (az összes templom távolság szerint), ahogy ma; a `NearBy` 100-as korlátja csak a frissítésre vonatkozik.
- **Időkorlát**: minden API-hívás legfeljebb 15 s, a kapcsolódás legfeljebb 10 s. Az időtúllépés **Nincs kapcsolat** (CONTEXT.md). Ma a kliensnek nincs időkorlátja.
- **Újrapróbálás**: a Keresés találati listáján, a Közeli templomokon és a Kedvenceken lehúzásos frissítés (`RefreshIndicator`, a Misék fül mintájára); a háttérhívást újraindítja. A Térképen a kártya újranyitása frissít.

**Templom-sorok frissítése és törlése**

- Minden API-válasz felülírja a templom sorát (koordináta-javítás is így érkezik), a hiányzó mezők kivételével (ld. Gyorsítótár-írás).
- A megszűnést **csak** a `Church {"ids"}` `hianyzo` listája jelzi; a `Search`/`NearBy` a megszűnt templomot egyszerűen kihagyja, ebből nem törlünk. Egy megszűnt templom tehát csak akkor tűnik el a készülékről, ha az app a `Church` végponton lekérdezte (találati lista első 100 eleme, kedvenc, térképi kártya, részletező). Minden más megszűnt templom a gyorsítótárban és a Térképen marad (ADR-0003, Consequences).
- **Megszűnt kedvenc**: a kedvencek közül is csendben törlődik (a helyi adatbázis kedvenc-rekordja is), nincs „megszűnt" sor.
- **Megnyitott megszűnt templom**: ha a részletező vagy a térképi kártya `Church` hívásának `hianyzo` listájában épp a megnyitott templom van, a templom törlődik a gyorsítótárból és a kedvencek közül. A részletezőn a miserend helyén „Ez a templom már nem szerepel a miserend.hu-n." áll, az oldal nem lép vissza magától. A térképi kártya bezárul, a marker eltűnik, és ugyanez a szöveg SnackBarban jelenik meg.

**Offline-jelölés**

- Két állapot, ahhoz kötve, amit az app lát:
  - **Nincs kapcsolat** (a kérés nem jutott el a szerverig — tiltott adatkapcsolat, nincs lefedettség, repülőgép-üzemmód, időtúllépés): (i) jelzés.
  - **Szerverhiba** (HTTP-hiba, `error: 1`, értelmezhetetlen válasz): eltérő szín **és** (i) jelzés.
- Listaképernyőn a jelölés **egyszer, a lista fölötti sávban** jelenik meg, nem soronként. A **térképi templomkártyán** a kártyán, ha a kártya hívása elbukik. A részletező oldalon (spec 0003) a listákéval azonos sáv, a fejléc alatt rögzítve; a „húzd le a listát" helyett „nyisd meg újra a templomot" (kézi teszt, 2026-09-15: a misék csempéjén álló (i) nem volt észrevehető).
- Az (i) koppintásra részletes tájékoztatót ad: mikori az adat, és mit tehet a felhasználó.
  - Nincs kapcsolat: „Az adatok a telefonon tárolt, {dátum}-i állapotot mutatják. Frissítéshez kapcsold be az adatkapcsolatot, vagy ellenőrizd, hogy a Miserend használhat-e mobilnetet a telefon beállításaiban, majd húzd le a listát."
  - Szerverhiba: „A miserend.hu jelenleg nem elérhető, az adatok {dátum}-i állapotot mutatnak."
  - A térképi kártyán a „húzd le a listát" helyett „nyisd meg újra a templomot".
- Az "utoljára frissítve" dátum **nem** jelenik meg alapból a képernyőn (UX-döntés), csak az (i) tájékoztatóban.
- **A {dátum} jelentése** (CONTEXT.md, „helyi szinkron"): listaképernyőn az adott lista utolsó sikeres háttérfrissítésének ideje, képernyőnként tárolva; a részletezőn és a térképi kártyán a templom helyi szinkronja (`local_synced_at`). Ha még nem volt ilyen, a kezdeti feltöltés dátuma.
- Betöltés és háttérhívás közben nincs jelölés; csak a sikertelen API-kísérlet után. Sikeres újrapróbálás után a sáv eltűnik.
- Aki soha nem kapcsolódik, annál a sáv **mindig** megjelenik — tájékoztatás, nem hibaüzenet; nincs bezárás és nincs munkamenetenkénti elrejtés.
- Helyzet nélkül nincs `NearBy` hívás, így a Közeli templomokon ilyenkor offline-sáv sincs; a **Helyzet nem elérhető** állapot áll helyette.

**Egyéb**

- **A legközelebbi misék és a gyóntatás** továbbra sem jön a gyorsítótárból (spec 0004, ADR-0002).

### API-kliens: a három kimenet szétválasztása

A `MiserendApiClient._post` ma a hálózati hibát, a HTTP-hibát és az `error: 1` választ egyaránt `null`-lal jelzi, a `fetchMassesForChurch` hibánál üres listát ad. Minden hívásnak meg kell tudnia különböztetni:

- **siker** (akár üres eredménnyel — "ezen a napon nincs mise", "nincs találat"),
- **Nincs kapcsolat** (`SocketException`, DNS-hiba, `TimeoutException` a 15 s-os / 10 s-os korlátból, TLS-kapcsolódási hiba),
- **Szerverhiba** (nem 200-as státusz, `error: 1`, értelmezhetetlen JSON).

Ez a spec 0003 részletező oldalát is érinti: a `ChurchScheduleLoader` "üres válasz = nem friss" heurisztikája (`church_schedule_loader.dart:54-58`) helyére a tényleges kimenet kerül, a részletező is megkapja a két jelölést, és a templomot `{"ids": [tid]}` alakban kéri (ld. Végpontok).

### Végpontok

**Élő API-hívással ellenőrzött tények** (2026-09-15):

- `POST /api/v4/search {"q", "limit" ≤ 100, "offset", "response_length"}` — a válasz `templomok` tömbje ugyanaz a templom-alak, mint a `Church` válaszé, benne a **mai** `misek`. A `q` nem az `ismertnev`-ben keres (a „Mátyás-templom" nem található), értelmezhetetlen keresőszóra fix listát ad, a sorrend nem relevancia szerinti, a `sum` értelmezhetetlen. Ezért csak 0 helyi találatnál használjuk.
- `minimal` válasz mezői: `id, nev, ismertnev, varos, lat, lon, koordinatak, links, misek, adoraciok, gyontatas, frissitve, orszag, tavolsag`. **`photos` csak `full` esetén** van. Méret 100 templomra: `minimal` ~41 KB, `full` ~311 KB.
- `POST /api/v4/nearby {"lat", "lon", "limit" ≤ 100 (alapértelmezés 10), "response_length"}` — távolság szerint rendezett, `tavolsag` **méterben**. Budapest belvárosában 100 templom ~7,3 km-t fed le. Méret 100 templomra: `minimal` ~58 KB (~3,9 s), `full` ~563 KB (~5,3 s).
- `POST /api/v4/church {"ids": [...≤100]}` — a nem létező azonosítók a **`hianyzo`** listában jönnek, a kérés nem bukik el. **Egyetlen `id` esetén viszont a nem létező templom `error: 1`-et ad** („Nem létezik misézőhely ezzel az asonosítóval.") — ez Szerverhibának látszana. Ezért **mindig az `ids` alakot használjuk**, a részletező és a térképi kártya egyetlen templomára is.
- A `misek` elemei `{"idopont", "informacio"}` párok, **azonosító nélkül**. Az `informacio` eleje az esemény fajtája, felekezeti előtaggal, vessző után jellemzőkkel: „Római katolikus Szentmise, Csendes" (tid 1515), „Római katolikus Gyóntatás", „Szentségimádás", „Igeliturgia", „Litánia" (Budapest-keresés).
- A válaszidők 3–5 s körüliek.

### Gyorsítótár-írás

- Egy `Search`/`NearBy`/`Church` válasz templomai `upsertChurch`-csel íródnak (a `gorog` megmarad, ld. spec 0003). A `minimal` válaszban hiányzó mezők (pl. `photos`, `leiras`, `names`, `alternative_names`) **nem írhatják felül** a gyorsítótárban meglévő értéket — a mai `upsertChurch` a teljes sort írja, ezt a részleges válaszokhoz igazítani kell.
- A `hianyzo` listában szereplő templomok törlődnek (`churches_cache` sor és a `masses_cache` sorai), és ha kedvencek, a kedvenc-rekordjuk is.
- **Napi miserend beírása.** A listaválaszok `misek` mezője a templom **mai napjának** sorait cseréli — de **csak akkor**, ha a mai napra nincs `NearbyMasses`-ből (a részletező 20 napos miserendjéből) származó sor. Ha van, a mai nap változatlan marad, mert az a pontosabb forrás. A mai `replaceMassesForChurch` a templom összes miséjét cseréli; ehhez egy napra szűkített művelet kell.
- **A mise-sor forrása** a gyorsítótárban tárolandó, mert az `informacio` forrásonként mást jelent, és az `api_mass_id` nem különbözteti meg őket (a listaválasz elemeinek sincs azonosítója):

  | Forrás | `informacio` tartalma | Mise-e (csipként) |
  |---|---|---|
  | kezdeti feltöltés | a régi `megjegyzes` (pl. „gitáros") | mindig misének számít |
  | `NearbyMasses` (részletező, kedvencek előfrissítése) | `title` (pl. „Szentmise", „Gyóntatás") | a CONTEXT.md mise-listája szerint |
  | listaválasz `misek` | „Római katolikus Szentmise, Csendes" | a fajta-rész (felekezeti előtag nélkül, a vessző előtt) a CONTEXT.md mise-listája szerint |

  Sémaváltozás a `masses_cache`-ben; a migráció szükségességét az implementáció dönti el (kiadott build még nincs, ld. #11).

### Képernyők

- **Keresés — javaslatok** (`home.dart`, gépelés közben, 250 ms debounce): templomnév + település a gyorsítótárból, API-hívás nélkül.
- **Keresés — találati lista** (`search_results.dart`, név vagy település szerint): helyi keresés a gyorsítótáron; háttérben `Church {"ids"}` az első 100 találatra, 0 találatnál `Search`. Állapotok: betöltés, üres („Nincs találat"), a két offline-jelölés. Lehúzásos frissítés.
- **Közeli templomok**: a **helyzet** (CONTEXT.md) alapján a gyorsítótárból távolság szerint, korlátlanul; háttérben `NearBy`. Állapotok: betöltés, **Helyzet nem elérhető** (okonként, ld. lent), üres, a két offline-jelölés. Lehúzásos frissítés — helyzet nélkül a helymeghatározást is újrapróbálja.
- **Kedvencek**: a kedvencek a gyorsítótárból; háttérben `Church {"ids"}`. Lehúzásos frissítés.
- **Térkép**: markerek mindig a gyorsítótárból (`churches_cache`, minden templom koordinátája); új templom akkor kerül a térképre, amikor bármely API-válasz beírta. Markerre bökve a kártya a gyorsítótárból azonnal megjelenik, a háttérben `Church {"ids": [tid]}` `full` fut, és a kártya újraolvas; hiba esetén a kártyán a két jelölés. Helyzet nélkül a térkép az ország nézetében marad (`MiserendMap.defaultInitialCenter`).
- **Templomsor időpont-csipjei**: a mai nap **misei** a gyorsítótárból (ld. a forrás-táblázat); gyóntatás, szentségimádás és más nem-mise esemény nem jelenik meg.
- **Bélyegképek**: a listák a gyorsítótárban lévő első fotót mutatják (a spec 0004 mintájára), mert a `minimal` válasz nem hoz képet. Egy új templomnak addig nincs bélyegképe, amíg a részletezője vagy a térképi kártyája nem töltötte be a `full` választ.
- **Lista-elem modell**: a `ChurchListItem` ma a régi `Church`/`ChurchWithMasses`/`Mass` modellt és a `MassFilter`-t használja (napra szűrés `HHNN` dátumokon). Az új forrás konkrét időpontokat ad (`CachedMass`), a napi szűrés dátum-összehasonlítás lesz.

### Helyzet nem elérhető

Közös állapot (szöveg + gomb) a **Közeli templomokon**, a **Térképen** és a **Misék fülön** (spec 0004). A fogalmakat a CONTEXT.md „Helyzet" és „Helyzet nem elérhető" szócikke rögzíti.

- **A helyzet szabálya mindenhol azonos**: legfeljebb 5 perces utolsó ismert pozíció, különben friss helymeghatározás időkorláttal (a Misék fül mai szabálya, `NearestMassesLoader.maxPositionAge`). A Közeli templomok és a Térkép is erre áll; ma bármilyen régi pozíciót elfogadnak.
- **A `LocationProvider` az okot adja vissza**, nem szöveges hibát; a hívók ma mindent egyetlen hibaként kezelnek (`location_provider.dart:21-47`).

| Ok | Szöveg (Közeli templomok; a Misék fülön „legközelebbi misék") | Gomb |
|---|---|---|
| Engedély megtagadva | „A közeli templomokhoz engedélyezd a helyadatot." | **Engedélyezés** — újra kéri az engedélyt |
| Engedély véglegesen megtagadva | „A közeli templomokhoz engedélyezd a helyadatot a telefon beállításaiban." | **Beállítások megnyitása** — `Geolocator.openAppSettings()` |
| Helymeghatározás kikapcsolva | „A közeli templomokhoz kapcsold be a helymeghatározást." | **Beállítások megnyitása** — `Geolocator.openLocationSettings()` |
| Nincs friss helyzet időben | „Nem sikerült meghatározni a helyzetedet." | nincs; lehúzásos frissítés |

- A gombok a `geolocator` meglévő hívásai, új függőség nem kell.
- Amikor a felhasználó a beállításokból visszatér az appba, a képernyő újrapróbálja a helymeghatározást.
- **Térkép**: a „helyzetem" gomb helyzet nélkül SnackBarban adja az okhoz tartozó szöveget és gombot (időtúllépésnél gomb nélkül). A kezeletlen hiba megszűnik. **Felülírva** (kézi teszt, 2026-09-16): a SnackBar nem jó hordozó ennek. A Flutter a gombbal rendelkező SnackBart alapból véglegesre állítja (`SnackBar.persist` alapértéke `action != null`), így a csík magától soha nem tűnt el; a gyökér `ScaffoldMessenger` tartotta, ezért a tabváltást is túlélte, és a Közeli templomok fülön a saját, teljes képernyős Helyzet nem elérhető állapota mellett duplán látszott. Helyette a térkép **saját, a lap alján ülő sávja** áll, az offline-sáv vizuális mintájára — a térkép része, tehát más fülön nem látszik, és magától eltűnik, amint van helyzet.
- **Misék fül**: a mai egyetlen helymeghatározási szöveg (`near_masses_page.dart:188-191`) helyére ugyanez az okonkénti állapot kerül; minden más változatlan (spec 0004).

### Kedvencek előfrissítése

- Induláskor (a splash után, a főképernyő megjelenését nem blokkolva), ha van kapcsolat, és **a legutóbbi sikeres előfrissítés óta legalább 24 óra eltelt** (a kedvencek `local_synced_at` értéke alapján). Naponta legfeljebb egyszer fut.
- Egy `Church {"ids": [...]}` hívás az összes kedvencre (≤100 kötegenként) — templom-adat, megszűnés, napi miserend —, majd kedvencenként a spec 0003 `NearbyMasses` 20 napos miserend-hívása.
- Hiba esetén csendben kimarad; a kimenetet nem jelzi a UI, a következő induláskor újra próbálkozik.

### A régi export kivezetése

A négy képernyő átállása után a `MiserendDatabase` egyetlen olvasója a `BootstrapImporter` marad. A lekérdező metódusok (`getChurchesForSearchTerm`, `getCitiesForSearchTerm`, `getChurchesWithMassesFor*`, `getChurches`, `getCloseChurches*`, `getAllChurches`, `getMassesForChurch`), a `ChurchWithMasses`, és — ha már senki nem használja — a `MassFilter` és a régi `Church`/`Mass` modell eltávolíthatók. Az 1. csomag 182 napos lejárati védelme ezzel okafogyottá válik, és szintén eltávolítandó.

### Fájlok, amik érintettek

- `lib/api/miserend_api_client.dart` — kimenet-szétválasztás, időkorlát; új `search`, `nearby`, `churches(ids)` hívások; a `misek` leképezése.
- `lib/database/cache/cache_database.dart` — részleges upsert, templom-törlés, egy napra szűkített mise-csere, mise-sor forrása, keresés/közeli/kedvencek lekérdezések a gyorsítótáron.
- `lib/database/favorites_service.dart`, `lib/database/local_database.dart` — megszűnt kedvenc törlése.
- `lib/home/home.dart`, `lib/home/churches/search_results.dart`, `near_churches_page.dart`, `favorite_churches.dart`, `church_list_item.dart`, `lib/home/map/map_page.dart`.
- `lib/home/masses/near_masses_page.dart`, `nearest_masses_loader.dart` — okonkénti Helyzet nem elérhető állapot.
- `lib/location_provider.dart` — ok visszaadása, egységes 5 perces szabály.
- `lib/church_details/church_schedule_loader.dart`, `church_details_page.dart` — kimenet-alapú jelölés, `ids` alakú `Church` hívás.
- Új: közös offline-jelölés widget (sáv + (i) tájékoztató), közös Helyzet nem elérhető widget, lista-betöltő (gyorsítótár → háttérhívás → újraolvasás), kedvencek előfrissítése, mise-szűrő (a CONTEXT.md mise-listája a három forrásra).
- `android/app/src/main/AndroidManifest.xml` — ld. Eszközön ellenőrizendő.
- `lib/database/miserend_database.dart`, `lib/database/church_with_masses.dart`, `lib/mass_filter.dart`, `lib/database/church.dart`, `lib/database/mass.dart` — kivezetés.

## Testing Decisions

- **API-kliens**: fixture JSON-nel (élő `search_*`, `nearby_*`, `church_ids_hianyzo_*` válaszokból) a leképezés; a három kimenet (siker-üres, Nincs kapcsolat, Szerverhiba) megkülönböztetése hamis HTTP-klienssel, beleértve a 15 s-os időtúllépést és az `error: 1`-et.
- **Gyorsítótár** (in-memory SQLite, a spec 0003 mintájára): részleges upsert nem törli a `photos`-t/`leiras`-t; `hianyzo` templom és miséi törlődnek; a `gorog` megmarad; a napi miserend a mai napot cseréli, ha nincs rá `NearbyMasses`-sor, és nem nyúl hozzá, ha van; a többi nap érintetlen; keresés/közeli/kedvencek lekérdezések a gyorsítótáron.
- **Mise-szűrő** (tiszta függvény): a három forrás példáival — kezdeti feltöltés „gitáros" → mise; `NearbyMasses` „Gyóntatás" → nem; listaválasz „Római katolikus Szentmise, Csendes" → mise; „Római katolikus Gyóntatás" → nem; ismeretlen fajta → nem.
- **Lista-betöltő** (hamis API + in-memory gyorsítótár): a gyorsítótár tartalma a háttérhívás előtt megérkezik; siker → write-through és egy újraolvasás, jelölés nélkül; Nincs kapcsolat → a gyorsítótár-állapot marad + (i); Szerverhiba → + szín; a találati lista legfeljebb 100 azonosítót küld; 0 helyi találat → `Search`; megszűnt kedvenc eltűnik a kedvencek közül.
- **Helyzet**: a `LocationProvider` az engedély/beállítás négy esetét okként adja vissza (hamis geolocator-platformmal); 5 percnél régebbi utolsó ismert pozíció nem helyzet.
- **Lapok**: könnyű widget tesztek hamis betöltővel: betöltés, üres, a négy Helyzet nem elérhető ok a szövegével és gombjával, a két offline-jelölés, az (i) tájékoztató megnyitása, lehúzásos frissítés; a térképi „helyzetem" gomb sávja, beleértve, hogy helyzet nélkül megjelenik, helyzettel eltűnik, és más fülre nem szivárog át.
- **Kedvencek előfrissítése**: hívásszám (egy `ids` köteg + kedvencenként egy miserend-hívás); 24 órán belül másodszor nem fut; hiba esetén csendes kimaradás.

## Out of Scope

- **Legközelebbi misék (Misék fül)** — spec 0004, offline nem működik. Ebből a specből csak a Helyzet nem elérhető állapotot kapja.
- **Gyóntatás jelzése** — csak élő API-válaszból (ADR-0002).
- **Tömeges szinkron** (a teljes templomlista vagy minden templom miserendjének rendszeres frissítése) — a v4 API-ban nincs rá végpont, az export újraletöltését az ADR-0003 elveti.
- **Megszűnt templomok teljes felismerése** (a Térképen és a meg nem nyitott templomoknál) — csak a `Church` végpont jelzi, ld. Templom-sorok frissítése és törlése.
- **Kis-nagybetű- és ékezetfüggetlen, alternatív nevekben is kereső helyi keresés** — #12.
- **Kézzel választott hely** a Közeli templomokhoz helyzet helyett — a Keresés település szerinti találati listája fedi.
- **Automatikus újrapróbálás, amikor a kapcsolat visszajön** (`connectivity_plus`) — a lehúzásos frissítés fedi.
- **A "nem engedélyezett adatkapcsolat" natív felismerése iOS-en** — később ráépíthető (ADR-0003).
- **Térképi markerek `NearBy`-ból** — elvetve (ADR-0003).
- **Felekezet / aktív templom** modellhiány (CONTEXT.md) — változatlanul nyitott.
- **API v5** — ADR-0002 szerint későbbi fázis.

## Eszközön ellenőrizendő

- **Android helyadat-engedély.** Az `AndroidManifest.xml` csak `ACCESS_FINE_LOCATION`-t deklarál, `ACCESS_COARSE_LOCATION`-t nem. Android 12+ célverziónál (`targetSdk = flutter.targetSdkVersion`) a rendszer a csak pontos helyadatot kérő engedélykérést figyelmen kívül hagyhatja, és a „hozzávetőleges hely" választás sem kínálható. Android 12+ eszközön ki kell próbálni az engedélykérést; ha a párbeszédablak nem jelenik meg, vagy a hozzávetőleges hely engedélyezése után nincs helyzet, az `ACCESS_COARSE_LOCATION` deklarálása és a hozzávetőleges helyzet elfogadása a Helyzet nem elérhető állapot része.

## Further Notes

- Domain-fogalmak: [CONTEXT.md](../../CONTEXT.md) — „SQLite export", „Helyi gyorsítótár", „Kezdeti feltöltés", „Nincs kapcsolat", „Szerverhiba", „Helyzet", „Helyzet nem elérhető", „Napi miserend", „Mise vs. egyéb liturgikus esemény".
- Döntések: [ADR-0002](../adr/0002-api-v4-mint-elsodleges-adatforras.md) (API mint forrás), [ADR-0003](../adr/0003-offline-mukodes-helyi-gyorsitotarbol.md) (offline működés, gyorsítótárból rajzoló listák).
- **1. csomag** (#11, e spec előfeltétele): letöltés a `/api/v4/sqlite` végpontról, a heti újraletöltés megszüntetése, az offline elakadó indítás javítása, 30 napos kezdeti feltöltés, 182 napos lejárati védelem a még exportból olvasó képernyőkön.
- Az élő API-ellenőrzések a grillezés során, 2026-09-15-én történtek.
