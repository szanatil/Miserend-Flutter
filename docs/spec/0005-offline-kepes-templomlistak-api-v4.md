# Offline-képes templomlisták — a Keresés, a Közeli templomok, a Kedvencek és a Térkép API v4-re állítása

> **Állapot: vázlat.** A grillezés (2026-09-15) döntései rögzítve vannak; az élő API-ellenőrzés során felmerült kérdések a [Nyitott kérdések](#nyitott-kérdések) szakaszban várnak döntésre, implementálás előtt tovább bontandó.

## Problem Statement

Az ADR-0002 az API v4-et tette tekintélyelvű adatforrássá, és az 1. csomag (ld. „Further Notes") megszünteti a SQLite export heti újraletöltését. A Keresés (`lib/home/home.dart`, `lib/home/churches/search_results.dart`), a Közeli templomok (`near_churches_page.dart`), a Kedvencek (`favorite_churches.dart`) és a Térkép (`lib/home/map/map_page.dart`) viszont még mindig közvetlenül a letöltött exportot olvassa (`MiserendDatabase`). Ennek következményei:

- Újraletöltés nélkül ezeken a képernyőkön az adat befagy: új templom soha nem jelenik meg, javított koordináta vagy megszűnt templom nem jut el a készülékre.
- A mise-adat a régi séma évszám nélküli (`HHNN`) dátumaira épül; az 1. csomag lejárati védelme 182 nap után elrejti a miséket, vagyis ezek a képernyők fél év alatt mise nélkülivé válnak.
- A képernyők nem tudják jelezni, hogy amit mutatnak, nem online adat — nincs se hiba-, se offline-állapotuk (a Keresés találati listájának betöltés- és üres állapota sincs).
- A kedvenc templomok miserendje offline csak akkor van meg, ha a felhasználó nemrég megnyitotta a részletezőt.

## Solution

A négy képernyő a spec 0003 részletező oldalával azonos rétegre áll: **online az élő API v4** a forrás, és minden válasz soronként a **helyi gyorsítótárba** íródik; ha az API nem ad választ, a képernyő **a gyorsítótárból** dolgozik, és jelzi, hogy nem online adatot mutat — **Nincs kapcsolat** esetén (i) jelzéssel, **Szerverhiba** esetén eltérő színnel és (i) jelzéssel (ld. [CONTEXT.md](../../CONTEXT.md), ADR-0003). A Térkép markerei mindig a gyorsítótárból jönnek. Az app induláskor, ha van kapcsolat, előre frissíti a kedvenc templomok 20 napos miserendjét. A képernyők a letöltött exportot többé nem olvassák; az export kizárólag a kezdeti feltöltés forrása marad.

## User Stories

1. Mint felhasználó, egy új, a miserend.hu-ra nemrég felvett templomot is szeretnék megtalálni keresésben és a közeli templomok között.
2. Mint felhasználó, lefedettség nélküli helyen is szeretnék templomot keresni név vagy település szerint, és látni a közeli templomokat.
3. Mint felhasználó, offline is szeretném látni a térképen a templomokat, és egy markerre bökve a templom adatait.
4. Mint felhasználó, ha a lista nem online adatot mutat, szeretném ezt látni, és egy koppintással megtudni, mikori az adat és mit tehetek.
5. Mint felhasználó, akinek van térereje, de a miserend.hu nem válaszol, szeretném, hogy az app ne hibaüzenetet mutasson, hanem a tárolt adatot, feltűnően jelölve, hogy nem friss.
6. Mint felhasználó, a kedvenc templomom miserendjét hetekkel az utolsó megnyitása után, térerő nélkül is szeretném látni.
7. Mint felhasználó, ha egy templom megszűnt, ne küldjön oda az app — se online, se offline.
8. Mint felhasználó, ha egy templom helyét a miserend.hu-n kijavították, a javított helyet szeretném látni a térképen és a közeli templomok között.
9. Mint felhasználó, aki soha nem engedélyezi az appnak az adatkapcsolatot, a telepítéskor betöltött templomokat és miséket szeretném látni, hibaüzenetek nélkül.

## Implementation Decisions

### Rögzített döntések (grillezés, 2026-09-15)

- **Adatforrás (Q9)**: online élő API, a válasz write-through a gyorsítótárba; offline ugyanez a lekérdezés a gyorsítótáron fut. Nem cache-first: a találati lista nem "ugrik" az API-válasz után.
- **Térkép (Q12)**: a markerek mindig a gyorsítótárból (`churches_cache`, minden templom koordinátája). Markerre bökve a templomkártya online a `Church` API-ból töltődik (write-through), offline a gyorsítótárból. Új templom akkor kerül a térképre, amikor bármely API-válasz beírta a gyorsítótárba.
- **Templom-sorok frissítése és törlése (Q13)**: minden API-válasz felülírja a templom sorát (koordináta-javítás is így érkezik). Ha az API szerint a templom nem létezik, a templom és a miséi törlődnek a gyorsítótárból.
- **Offline-jelölés (Q11, Q16, Q17, Q19)**: két állapot, ahhoz kötve, amit az app lát:
  - **Nincs kapcsolat** (a kérés nem jutott el a szerverig — tiltott adatkapcsolat, nincs lefedettség, repülőgép-üzemmód, időtúllépés): (i) jelzés.
  - **Szerverhiba** (HTTP-hiba, `error: 1`, értelmezhetetlen válasz): eltérő szín **és** (i) jelzés.
  - Listaképernyőn a jelölés **egyszer, a lista fölötti sávban** jelenik meg, nem soronként. A részletező oldalon (spec 0003) a misék csempéjénél.
  - Az (i) koppintásra részletes tájékoztatót ad: mikori az adat, és mit tehet a felhasználó. Nincs kapcsolat esetén pl. „Az adatok a telefonon tárolt, {dátum}-i állapotot mutatják. Frissítéshez kapcsold be az adatkapcsolatot, vagy ellenőrizd, hogy a Miserend használhat-e mobilnetet a telefon beállításaiban." Szerverhiba esetén: „A miserend.hu jelenleg nem elérhető, az adatok {dátum}-i állapotot mutatnak."
  - Az "utoljára frissítve" dátum **nem** jelenik meg alapból a képernyőn (UX-döntés), csak az (i) tájékoztatóban.
  - Betöltés közben nincs jelölés; csak a sikertelen API-kísérlet után.
- **Kedvencek előfrissítése (Q20)**: alkalmazásinduláskor, ha van kapcsolat, a kedvenc templomok adatai és 20 napos miserendje frissül; hiba esetén csendben kimarad.
- **A legközelebbi misék és a gyóntatás** továbbra sem jön a gyorsítótárból (spec 0004, ADR-0002).

### API-kliens: a három kimenet szétválasztása

A `MiserendApiClient._post` ma a hálózati hibát, a HTTP-hibát és az `error: 1` választ egyaránt `null`-lal jelzi, a `fetchMassesForChurch` hibánál üres listát ad. Minden hívásnak meg kell tudnia különböztetni:

- **siker** (akár üres eredménnyel — "ezen a napon nincs mise", "nincs találat"),
- **Nincs kapcsolat** (`SocketException`, DNS-hiba, `TimeoutException`, TLS-kapcsolódási hiba),
- **Szerverhiba** (nem 200-as státusz, `error: 1`, értelmezhetetlen JSON).

Ez a spec 0003 részletező oldalát is érinti: a `ChurchScheduleLoader` "üres válasz = nem friss" heurisztikája (`church_schedule_loader.dart:54-58`) helyére a tényleges kimenet kerül, és a részletező is megkapja a két jelölést.

### Végpontok

**Élő API-hívással ellenőrzött tények** (2026-09-15):

- `POST /api/v4/search {"q", "limit" ≤ 100, "offset", "response_length"}` — a válasz `templomok` tömbje ugyanaz a templom-alak, mint a `Church` válaszé, benne a **mai** `misek` (`idopont`/`informacio`). `offset` megadásakor a válasz `limit`/`offset`/`sum` kulcsokat is ad, de a **`sum` értelmezhetetlen** (`"Budapest"` → 193 623, miközben lapozva 164 templom jön).
- `minimal` válasz mezői: `id, nev, ismertnev, varos, lat, lon, koordinatak, links, misek, adoraciok, gyontatas, frissitve, orszag, tavolsag`. **`photos` csak `full` esetén** van. Méret 100 templomra: `minimal` ~41 KB, `full` ~311 KB.
- `POST /api/v4/nearby {"lat", "lon", "limit" ≤ 100 (alapértelmezés 10), "response_length"}` — távolság szerint rendezett, `tavolsag` **méterben**. Budapest belvárosában 100 templom ~7,3 km-t fed le. Méret 100 templomra: `minimal` ~58 KB (~3,9 s), `full` ~563 KB (~5,3 s).
- `POST /api/v4/church {"ids": [...≤100]}` — a nem létező azonosítók a **`hianyzo`** listában jönnek, a kérés nem bukik el. **Egyetlen `id` esetén viszont a nem létező templom `error: 1`-et ad** („Nem létezik misézőhely ezzel az asonosítóval.") — ez a kimenet-szétválasztás szerint Szerverhibának látszana. Ezért **a megszűnés felismeréséhez mindig az `ids` alakot kell használni**, a részletező oldal egyetlen templomára is (`{"ids": [<tid>]}`).
- A válaszidők 3–5 s körüliek.

### Gyorsítótár-írás

- Egy `Search`/`NearBy`/`Church` válasz templomai `upsertChurch`-csel íródnak (a `gorog` megmarad, ld. spec 0003). A `minimal`/`medium` válaszban hiányzó mezők (pl. `photos`, `leiras`) **nem írhatják felül** a gyorsítótárban meglévő értéket — a mai `upsertChurch` a teljes sort írja, ezt a részleges válaszokhoz igazítani kell.
- A `hianyzo` listában szereplő templomok törlődnek (`churches_cache` sor és a `masses_cache` sorai).
- A mai misék beírása: ld. Nyitott kérdések 3.

### Képernyők

- **Keresés — javaslatok** (`home.dart`, gépelés közben, 250 ms debounce) és **találati lista** (`search_results.dart`, név vagy település szerint): ld. Nyitott kérdések 1–2.
- **Közeli templomok**: online `NearBy` a felhasználó pozíciójával; offline a gyorsítótárból távolság szerint. A lista hossza: ld. Nyitott kérdések 5. Állapotok: betöltés, helymeghatározási hiba, üres, és a két offline-jelölés.
- **Kedvencek**: online `Church {"ids": [...]}` a kedvencekre; offline a gyorsítótárból. A mai misék a kedvencek előfrissítése miatt offline is jellemzően megvannak.
- **Térkép**: markerek a gyorsítótárból; templomkártya online `Church {"ids": [tid]}`, offline gyorsítótár.
- **Bélyegképek**: a listák a gyorsítótárban lévő első fotót mutatják (a spec 0004 mintájára), mert a `minimal` válasz nem hoz képet. Egy új templomnak addig nincs bélyegképe, amíg a részletezője nem töltötte be a `full` választ.
- **Lista-elem modell**: a `ChurchListItem` ma a régi `Church`/`ChurchWithMasses`/`Mass` modellt és a `MassFilter`-t használja (napra szűrés `HHNN` dátumokon). Az új forrás konkrét időpontokat ad (`CachedMass`), a napi szűrés dátum-összehasonlítás lesz.

### Kedvencek előfrissítése

- Induláskor (a splash után, a főképernyő megjelenését nem blokkolva), ha van kapcsolat.
- Egy `Church {"ids": [...]}` hívás az összes kedvencre (≤100 kötegenként) — templom-adat és megszűnés —, majd kedvencenként a spec 0003 `NearbyMasses` 20 napos miserend-hívása.
- Hiba esetén csendben kimarad; a kimenetet nem jelzi a UI.

### A régi export kivezetése

A négy képernyő átállása után a `MiserendDatabase` egyetlen olvasója a `BootstrapImporter` marad. A lekérdező metódusok (`getChurchesForSearchTerm`, `getCitiesForSearchTerm`, `getChurchesWithMassesFor*`, `getChurches`, `getCloseChurches*`, `getAllChurches`, `getMassesForChurch`), a `ChurchWithMasses`, és — ha már senki nem használja — a `MassFilter` és a régi `Church`/`Mass` modell eltávolíthatók. Az 1. csomag 182 napos lejárati védelme ezzel okafogyottá válik, és szintén eltávolítandó.

### Fájlok, amik érintettek

- `lib/api/miserend_api_client.dart` — kimenet-szétválasztás; új `search`, `nearby`, `churches(ids)` hívások.
- `lib/database/cache/cache_database.dart` — részleges upsert, templom-törlés, keresés/közeli/kedvencek lekérdezések a gyorsítótáron, napi misék beírása.
- `lib/home/home.dart`, `lib/home/churches/search_results.dart`, `near_churches_page.dart`, `favorite_churches.dart`, `church_list_item.dart`, `lib/home/map/map_page.dart`.
- `lib/church_details/church_schedule_loader.dart`, `church_details_page.dart` — kimenet-alapú jelölés, `ids` alakú `Church` hívás.
- Új: közös offline-jelölés widget (sáv + (i) tájékoztató), kedvencek előfrissítése.
- `lib/database/miserend_database.dart`, `lib/database/church_with_masses.dart`, `lib/mass_filter.dart`, `lib/database/church.dart`, `lib/database/mass.dart` — kivezetés.

## Testing Decisions

- **API-kliens**: fixture JSON-nel (élő `search_*`, `nearby_*`, `church_ids_hianyzo_*` válaszokból) a leképezés; a három kimenet (siker-üres, Nincs kapcsolat, Szerverhiba) megkülönböztetése hamis HTTP-klienssel, beleértve az időtúllépést és az `error: 1`-et.
- **Gyorsítótár** (in-memory SQLite, a spec 0003 mintájára): részleges upsert nem törli a `photos`-t/`leiras`-t; `hianyzo` templom és miséi törlődnek; a `gorog` megmarad; a keresés/közeli/kedvencek lekérdezések a gyorsítótáron.
- **Betöltők** (hamis API + in-memory gyorsítótár): online siker → API-adat és write-through; Nincs kapcsolat → gyorsítótár + (i) állapot; Szerverhiba → gyorsítótár + színjelölés.
- **Lapok**: könnyű widget tesztek hamis betöltővel: betöltés, üres, helymeghatározási hiba, a két offline-jelölés, az (i) tájékoztató megnyitása.
- **Kedvencek előfrissítése**: hívásszám (egy `ids` köteg + kedvencenként egy miserend-hívás), hiba esetén csendes kimaradás.

## Out of Scope

- **Legközelebbi misék (Misék fül)** — spec 0004, offline nem működik.
- **Gyóntatás jelzése** — csak élő API-válaszból (ADR-0002).
- **Tömeges szinkron** (a teljes templomlista vagy minden templom miserendjének rendszeres frissítése) — a v4 API-ban nincs rá végpont, az export újraletöltését az ADR-0003 elveti.
- **A "nem engedélyezett adatkapcsolat" natív felismerése iOS-en** — később ráépíthető (ADR-0003).
- **Térképi markerek `NearBy`-ból** — elvetve (Q12).
- **Felekezet / aktív templom** modellhiány (CONTEXT.md) — változatlanul nyitott.
- **API v5** — ADR-0002 szerint későbbi fázis.

## Nyitott kérdések

Az élő API-ellenőrzés (2026-09-15) olyan tényeket hozott, amelyek a rögzített döntések részleteit érintik. Implementálás előtt eldöntendők:

1. **A `Search` API minősége a helyi kereséshez képest.** A `q` nem az `ismertnev`-ben keres: a „Mátyás-templom" (tid 1515, `ismertnev`) nem található, helyette nógrádi templomok jönnek (Szanda, Cserhátsurány…); ugyanezek jönnek a „Sz" keresésre is — úgy tűnik, értelmezhetetlen keresőszóra a szerver egy fix listát ad. A „Mátyás" az `Mátyásdomb` települést és a „St. Matthias" templomot adja. A találatok sorrendje nem relevancia szerinti. A helyi export `nev LIKE` keresése a „Mátyás"-ra 0 találatot ad, az `ismertnev`-ben kettőt. Kérdés: a találati lista online tényleg az API-ra álljon-e, vagy a gyorsítótár helyi keresése maradjon elsődleges (az API csak write-through forrás), esetleg a kettő összefésülve?
2. **Javaslatok gépelés közben.** API-ból 3–5 s válaszidővel, billentyűleütésenként (250 ms debounce után) nem használható. Javaslat: a javaslatlista (templomnév + település) mindig a gyorsítótárból jön, online is. Döntendő, és hogy ez összefér-e az 1. kérdésre adott válasszal.
3. **A `Search`/`NearBy` mai miséinek beírása a gyorsítótárba.** A `replaceMassesForChurch` a templom *összes* miséjét cseréli, ami a részletező 20 napos miserendjét törölné (ld. spec 0004). Kell egy „egy templom egy napjának miséit cseréli" művelet, vagy a mai misék ne íródjanak be?
4. **Nem-mise események a listákon.** A `Search`/`NearBy` `misek` mezője nem csak misét ad: Budapest-keresésben „Római katolikus Gyóntatás", „Szentségimádás", „Igeliturgia", „Litánia" is előfordul. Az `informacio` más alakú, mint a `NearbyMasses` `title`-je („Római katolikus Szentmise, Orgonás" vs. „Szentmise"), így a CONTEXT.md mise-engedélyezőlistája nem alkalmazható egy az egyben. Szűrjük-e a listák időpont-chipjeit misékre, és ha igen, milyen szabállyal?
5. **A Közeli templomok lista hossza.** Ma korlátlan (az összes templom távolság szerint); az API legfeljebb 100-at ad. Online 100, offline korlátlan legyen, vagy mindkettő azonos (pl. 100)?
6. **Időtúllépés.** A 3–5 s-os válaszidő mellett mekkora időkorlát után számít egy kérés Nincs kapcsolatnak (pl. 15 s)? Egy túl rövid korlát jó lefedettség mellett is offline jelölést adna.
7. **Megszűnt kedvenc.** Ha a `hianyzo` szerint egy kedvenc templom megszűnt, a gyorsítótárból törlődik — a kedvencek közül is (a felhasználó tudta nélkül), vagy maradjon egy „ez a templom megszűnt" sor?
8. **Templomkártya a Térképen `full` válasszal?** A `minimal` nem hoz fotót; a kártya ma az export `kep` mezőjét mutatja. `full` (~5 KB/templom) vagy `minimal` + gyorsítótár-fotó?

## Further Notes

- Domain-fogalmak: [CONTEXT.md](../../CONTEXT.md) — „SQLite export", „Helyi gyorsítótár", „Kezdeti feltöltés", „Nincs kapcsolat", „Szerverhiba", „Napi miserend", „Mise vs. egyéb liturgikus esemény".
- Döntések: [ADR-0002](../adr/0002-api-v4-mint-elsodleges-adatforras.md) (API mint forrás), [ADR-0003](../adr/0003-offline-mukodes-helyi-gyorsitotarbol.md) (offline működés).
- **1. csomag** (#11, e spec előfeltétele): letöltés a `/api/v4/sqlite` végpontról, a heti újraletöltés megszüntetése, az offline elakadó indítás javítása, 30 napos kezdeti feltöltés, 182 napos lejárati védelem a még exportból olvasó képernyőkön.
- Az élő API-ellenőrzések a grillezés során, 2026-09-15-én történtek.
