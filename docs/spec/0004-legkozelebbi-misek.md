# Legközelebbi misék — a Misék fül javítása és API v4-re állítása

## Problem Statement

A Misék fül (`lib/home/masses/near_masses_page.dart`) a felhasználó körüli templomok miséit listázza, de a gyakorlatban használhatatlan arra, amire való — hogy a felhasználó megtalálja, hová érhet még oda misére:

- A lista a régi SQLite exportból a mai nap **összes** miséjét adja vissza, távolság szerint rendezve és 500 sorra vágva (`MiserendDatabase.getCloseMasses`). Időpont szerint nem szűr, így délután 2-kor a reggel 7-es mise is látszik.
- A távolság szerinti rendezés miatt az időpontok összekeverednek (18:00, 17:00, 19:15, 16:00…), a lista úgy hat, mintha nem csak a mai miséket mutatná.
- Nincs sugár vagy darabszám-korlát, a lista gyakorlatilag végtelen.
- A lista egyszer, `initState`-ben töltődik be, és `AutomaticKeepAlive` tartja életben — egy reggel megnyitott app délután is a reggeli listát mutatja.
- A listaelemre bökve nem történik semmi.
- Nincs betöltés-, hiba- vagy üres állapot; ha a helymeghatározás hibát dob, a lista csendben üres marad.
- A "távolság" fokok négyzetösszege, nem km.

## Solution

A Misék fül a **legközelebbi miséket** mutatja (ld. [CONTEXT.md](../../CONTEXT.md)): a felhasználóhoz térben legközelebbi legfeljebb 10 templomot, azok minden mai, még **elérhető** miséjével — misénként egy sorral —, időrendben. (Eredetileg templomonként egy sor volt; a #30 módosította.) Az adat élő API v4 `NearbyMasses` hívásból jön; a képernyő a régi SQLite exportot többé nem olvassa. Egy sorra bökve a templom-részletező nyílik meg.

Ez a képernyő saját API-migrációs fázisa (ld. ADR-0002, spec 0003 „Out of Scope"), de eltér a spec 0003 stale-while-revalidate mintájától: **nincs gyorsítótár-tartalék** — ld. „Adatforrás".

## User Stories

1. Mint felhasználó, délután 2-kor megnyitva a Misék fület, nem szeretném látni a reggel 7-es misét, mert arra már nem érek oda.
2. Mint felhasználó, aki 14:05-kor nézi a listát, szeretném látni a 400 méterre lévő templom 14:00-kor kezdődött miséjét „Épp most tart" jelöléssel, mert 10 percen belüli késéssel még érvényesen részt vehetek rajta (áldozhatok).
3. Mint felhasználó, 14:15-kor nem szeretném látni a 14:00-kor kezdődött misét, mert arról már lekéstem — ugyanannak a templomnak a későbbi miséi viszont maradjanak.
4. Mint felhasználó, egy rövid, véges listát szeretnék a hozzám legközelebbi templomokból, nem az egész ország miséit.
5. Mint felhasználó, időrendben szeretném látni a miséket, hogy azonnal lássam, mi kezdődik legkorábban; azonos időpontnál a közelebbi templom álljon elöl.
6. Mint felhasználó, egy templom minden mai, még elérhető miséjét szeretném látni a listán, időrendben a többi templom miséi között.
7. Mint felhasználó, egy misére bökve a templom részletes adatait szeretném látni.
8. Mint felhasználó, csak misét szeretnék látni a Misék fülön — gyóntatást, szentségimádást, vecsernyét, rózsafüzért nem.
9. Mint görögkatolikus vagy régi rítusú misét kereső felhasználó, szeretném látni a sorban, ha egy mise „Szent Liturgia" vagy „Régi rítusú szentmise".
10. Mint felhasználó, aki karácsony este 23:40-kor keres misét, szeretném látni az éjféli (25-én 00:00-kor kezdődő) misét is.
11. Mint felhasználó, aki 00:05-kor nézi a listát, szeretném látni a tegnap 23:55-kor kezdődött misét, ha még elérhető.
12. Mint felhasználó, ha nyitva hagyom a képernyőt, szeretném, hogy a lejárt misék maguktól eltűnjenek.
13. Mint felhasználó, ha az app a háttérből visszajön, vagy visszaváltok a Misék fülre, szeretném, hogy a lista az aktuális időhöz és helyzetemhez frissüljön; lehúzással kézzel is frissíthessem.
14. Mint felhasználó internetkapcsolat nélkül, őszinte hibaüzenetet szeretnék látni elavult lista helyett, és lehúzással újrapróbálhassam.
15. Mint felhasználó, ha a helyzetem nem határozható meg, erről szóló üzenetet szeretnék látni üres képernyő helyett.
16. Mint felhasználó, ha a közelben ma már nincs elérhető mise, erről szóló üzenetet szeretnék látni.
17. Mint felhasználó, az utolsó ismert helyzetem helyett a mostanit szeretném alapul venni, ha az utolsó ismert már régi (pl. egy másik városból származik).

## Implementation Decisions

### Adatforrás

- `POST /api/v4/nearbymasses` a felhasználó pozíciójával:
  `{"lat": <lat>, "lon": <lon>, "radius": 200, "from": "<most − 10 perc, ÉÉÉÉ-HH-NN ÓÓ:PP>", "until": "<holnap> 00:00", "limit": 100}`.
- **Nincs visszaesés** a régi SQLite exportra vagy a `masses_cache`-re (explicit felhasználói döntés). A lista „most elérhető" miséket ígér; egy elavult tartalék rosszabb, mint az őszinte hiba — ugyanaz a logika, ami a `gyontatas` mezőt kivonja a gyorsítótárból (ADR-0002).
- **Nincs gyorsítótár-írás.** A `CacheDatabase.replaceMassesForChurch` egy templom *összes* gyorsítótárazott miséjét lecseréli; a „ma, most után" részhalmaz beírása a részletező 7 napos miserendjét törölné. A válasz csak memóriában él.
- A régi `MiserendDatabase.getCloseMasses` és a `MassWithChurch` modell a Misék fül számára feleslegessé válik; ha máshol sem használja semmi, eltávolítható.

**Élő API-hívással ellenőrzött tények** (2026-09-14):

- A `from` **időpontot is elfogad** (`"2026-09-14 14:00"`), a szerver ez alapján szűr — a „most − 10 perc" alsó határ szerveroldalon érvényesül.
- Az `until` a megadott napot **nem** számolja bele: `from = until = "2026-09-14"` üres választ ad. A felső határ ezért `"<holnap> 00:00"`.
- A `limit` legfeljebb 100, a `radius` legfeljebb 200 km (`radius: 300` → `"Field 'radius' should be at most 200."`). A `sum` az összes találat száma.
- A válasz **távolság szerint rendezett**, a tételenkénti `distance_km` mező szerint (km, két tizedesre).
- Egy tétel alakja: `{id, start_date: "2026-09-14T18:00:00+02:00", title, distance_km, church: {id, name, city, lat, lon}}`. **Kép nincs benne.** A `start_date` a meglévő `parseApiDateTime`-mal olvasandó (fali óra, időzóna-konverzió nélkül).
- A válasz **nem csak misét** tartalmaz (ld. „Mi számít misének").
- **Duplikátumok előfordulnak**: ugyanaz a templom, időpont és cím kétszer (pl. tid 37, két „Szentmise" 18:00-kor); 2026-09-16-án már azonos `id`-vel háromszor is (tid 1155). Az `id` az ismétlődő miséé, nem az alkalomé: minden napon ugyanaz. Az API-kliens ezért `id` + templom + kezdés + cím szerint vonja össze őket (#29).
- A 100-as limit a legsűrűbb esetben sem akadály: budapesti vasárnap reggel (06:50-től) 100 tétel 29 templomot fed le (max. 2,33 km). Ha mégis 10-nél kevesebb templom jön ki, azt elfogadjuk. Azóta, hogy a lista templomonként minden misét mutat (#30), is elég: budapesti hétköznap, 06:00-tól, háromszorozott tételekkel (2026-09-16) a 100 tétel 60 templomot fed le; a 10. templom 1,49 km-re, az utolsó tétel 6,5 km-re van, így a 10 templom minden miséje benne van.
- Átlagos napon **nincs 00:00-s tétel** — az „ismeretlen időpont = 00:00" a régi export sajátossága volt. Ünnepeken viszont **valódi éjféli misék** jönnek 00:00-val (Budapest 200 km: 2026-12-25 00:00 × 8, 2027-01-01 00:00 × 6), illetve 23:59-cel (2026-12-24 23:59 × 16). **A 00:00-s tételeket ezért nem szűrjük.**

### Mi számít misének

Pontos, `title`-alapú engedélyezőlista (ld. [CONTEXT.md](../../CONTEXT.md), „Mise vs. egyéb liturgikus esemény"):

- **Mise**: `Szentmise`, `Szent Liturgia`, `Régi rítusú szentmise`.
- Minden más kimarad — az ismert nem-mise címek (`Vecsernye`, `Utrenye`, `Igeliturgia`, `Gyóntatás`, `Szentségimádás`, `Rózsafüzér`, `Litánia`) és bármely ismeretlen cím is.

Élő mintavétel (8 helyszín × 2 nap, 50 km): Szentmise 1212, Szent Liturgia 110, Vecsernye 37, Utrenye 20, Gyóntatás 15, Szentségimádás 3, Régi rítusú szentmise 2, Rózsafüzér 1, Litánia 1, Igeliturgia 1.

### Kiválasztási szabály

Tiszta függvény a nyers API-tételekből és a `now` időpontból, ebben a sorrendben:

1. **Csak misék** (engedélyezőlista).
2. **Elérhetőség**: `start ≥ now − 10 perc` és `start ≤ holnap 00:00` (a határt is beleértve). Az alsó határ átnyúlhat a tegnapi napra (00:05-kor a tegnap 23:55-ös mise benne van). Menetidővel nem számolunk — a távolság az elérhetőséget nem befolyásolja.
3. **Legfeljebb 10 templom**, `distance_km` szerint a legközelebbiek azok közül, amelyeknek maradt elérhető miséjük; azonos távolságnál a kisebb templom-id.
4. **A kiválasztott templomok minden elérhető miséje** egy-egy tétel — a 10-es korlát templomokra vonatkozik, nem tételekre. (Így 14:05-kor a 14:00-s és a 18:30-as mise is a listán van; 14:15-kor már csak a 18:30-as.)
5. **Rendezés**: kezdés szerint növekvő, azonos kezdésnél `distance_km` szerint növekvő.

A duplikátumokat az API-kliens már a beolvasáskor kiszűri, a szabálynak nem kell velük foglalkoznia.

Egy tétel **épp most tart**, ha `start ≤ now`.

A 10 perces határ liturgikus eredetű (aki 10–15 percnél többet késik, már nem áldozhat); a biztonságos alsó értéket használjuk. Egyetlen, elnevezett konstans legyen.

### Frissítés

- **Új API-hívás**: a képernyő első megjelenésekor; amikor az app előtérbe kerül (`AppLifecycleState.resumed`), és éppen a Misék fül látszik; amikor a felhasználó a Misék fülre vált; lehúzásra (`RefreshIndicator`); valamint ha az újraszámolás közben a naptári nap megváltozott (éjfél után a felső határ elavul).
- **Percenkénti újraszámolás hálózat nélkül**: amíg a képernyő látszik, percenként a **memóriában tartott teljes, nyers utolsó válaszból** fut újra a kiválasztási szabály. Ezért a nyers tételeket kell megtartani, nem a leszűkített 10 sort: ha egy templom miséje lejár, a templom kiesik, amint nincs több elérhető miséje, és a helyére a 11. legközelebbi templom kerülhet.
- A `home.dart` `IndexedStack`-je miatt a tabváltásról a lapnak külön értesítést kell kapnia (pl. a kiválasztott index átadásával vagy callbackkel).

### Pozíció

- Az utolsó ismert pozíció használható, ha **5 percnél nem régebbi** (`Position.timestamp`); különben friss helymeghatározás, **időkorláttal**. Időtúllépés vagy engedélyhiány esetén a helymeghatározási hibaüzenet jelenik meg.
- A változás a `LocationProvider`-ben történjen úgy, hogy a többi hívó (Közeli templomok, Térkép) viselkedése ne romoljon; ha ez nem egyértelmű, a friss-pozíció logika a Misék fül saját paramétere legyen.

### Megjelenítés

Egy sor:

- **Bélyegkép**: a helyi gyorsítótárból templom-id alapján (`CacheDatabase.getChurch(id)`, első fotó); ha nincs, a meglévő `church_blurred.png` helykitöltő. A kép hiánya vagy lassú betöltése nem befolyásolja a lista megjelenését.
- **Templom neve** és **település** (`church.name`, `church.city`).
- **Kezdés** 24 órás formában.
- **Távolság**, magyar tizedesvesszővel: „1,2 km".
- **„Épp most tart"** jelölés, ha `start ≤ now`.
- **A mise címe**, ha nem „Szentmise" (pl. „Szent Liturgia").

Bökésre: `ChurchDetailsPage(church: …)` nyílik meg, egy API-tételből felépített `Church` objektummal (id, név, település, lat/lon) — a részletező az adatait egyébként is id alapján tölti.

Állapotok (a `NearChurchesPage` mintájára, `LoadingView` / `MessageView`):

- Betöltés: „Legközelebbi misék betöltése…"
- Helymeghatározási hiba: „Nem sikerült meghatározni a helyzetedet, ezért a legközelebbi misék nem jeleníthetőek meg."
- API-hiba / offline: „Nem sikerült betölteni a miséket. Ellenőrizd az internetkapcsolatot."
- Üres: „A közelben ma már nincs elérhető mise."

Hiba- és üres állapotban is működjön a lehúzásos frissítés.

### Fájlok, amik érintettek

- `lib/api/miserend_api_client.dart` — új metódus a pozíció körüli `NearbyMasses` híváshoz, amely a nyers tételeket (templom-id, név, település, lat/lon, `distance_km`, kezdés, cím) adja vissza; hiba esetén a meglévő konvenció szerint üres/null eredmény, de a hívónak **meg kell tudnia különböztetni** a hibát az üres választól (a kettőhöz más üzenet tartozik).
- Új: a kiválasztási szabály tiszta, önállóan tesztelhető egysége (pl. `lib/home/masses/nearest_masses.dart`).
- `lib/home/masses/near_masses_page.dart` — állapotok, frissítési események, percenkénti újraszámolás.
- `lib/home/masses/mass_list_item.dart` — új sortartalom és `onTap`.
- `lib/location_provider.dart` — pozíció-frissesség.
- `lib/home/home.dart` — tabváltás jelzése a Misék fülnek.
- `lib/database/miserend_database.dart`, `lib/database/mass_with_church.dart` — a `getCloseMasses` és a `MassWithChurch` eltávolítható, ha nincs más hívója.

## Testing Decisions

- **Kiválasztási szabály**: unit tesztek rögzített `now` időpontokkal, tiszta függvényen, hálózat és adatbázis nélkül. Kötelező esetek:
  - nem-mise címek és ismeretlen cím kiesnek; a „Szent Liturgia" és a „Régi rítusú szentmise" marad;
  - 14:05-kor a 14:00-s mise marad és „épp most tart"; 14:10:00-kor még marad; 14:10:01-kor kiesik (a határ pontosan 10 perc);
  - egy templom minden elérhető miséje a listán van, időrendben a többi templom miséi között;
  - a 10-es korlát templomokat számol, nem tételeket;
  - legfeljebb 10 templom, a legközelebbiek — a 11. legközelebbi templom akkor sem kerül be, ha korábbi a miséje;
  - időrend, azonos kezdésnél távolság szerint;
  - 23:40-kor a holnap 00:00-s mise benne van, a holnap 00:01-es nincs;
  - 00:05-kor a tegnap 23:55-ös mise benne van, a tegnap 23:50-es nincs;
  - percenkénti újraszámolásnál egy lejárt mise kiesik, ugyanazon templom későbbi miséje marad.
- **API-kliens**: fixture JSON-nel (új, élő válaszból rögzített `nearbymasses_*.json`) a tétel-leképezés és a kérés-payload (`from` időponttal, `until` holnap 00:00, `radius` 200, `limit` 100); hibaválasz és üres válasz megkülönböztetése.
- **Lap**: könnyű widget teszt hamis betöltővel (a spec 0003-ban rögzített ok miatt nem valódi adatbázissal/hálózattal): betöltés-, hiba-, üres állapot; a sorra bökés a részletezőt nyitja.

## Out of Scope

- **Menetidő-becslés és útvonaltervezés.** Explicit felhasználói döntés: az elérhetőség csak az órán múlik. Útvonaltervező szolgáltatás nincs (a Google-t az ADR-0001 kivezette, a nyilvános OSRM demó éles forgalomra nem használható).
- **Gyalog/autó mód választása.** Az előzővel együtt elvetve.
- **A megbökött mise kiemelése a részletezőn.** A részletező oldal változatlan.
- **Offline tartalék** a régi exportból vagy a gyorsítótárból.
- **Gyorsítótár-írás** a `NearbyMasses` válaszból.
- **Nem-mise események** (gyóntatás, szentségimádás, imaórák) megjelenítése bármilyen formában.
- **A Templomok és a Térkép fül** API-ra állítása — külön ticketek.

## Further Notes

- Domain-fogalmak: [CONTEXT.md](../../CONTEXT.md) — „Legközelebbi misék", „Elérhető mise", „Épp most tartó mise", „Mise vs. egyéb liturgikus esemény".
- Adatforrás-irány: [docs/adr/0002-api-v4-mint-elsodleges-adatforras.md](../adr/0002-api-v4-mint-elsodleges-adatforras.md). Új ADR nem készült: a döntések visszafordíthatók, az API-irányt az ADR-0002 már rögzíti.
- A spec 0003 „Out of Scope" szakasza a Közeli misék képernyőt még a gyorsítótárra hagyta; ez a spec ezt a pontot váltja fel, a gyorsítótár-tartalék elvetésével.
- A kiinduló hibajelentés négy pontja és megoldásuk: (1) csak mai misék → az ablak felső határa holnap 00:00; (2) csak még elérhető misék → 10 perces szabály; (3) csak közeli misék → legközelebbi 10 templom (eredetileg templomonként egy sorral, a #30 óta minden elérhető miséjükkel); (4) bökésre részletező → `onTap`.
- Az élő API-ellenőrzések a grillezés során, 2026-09-14-én történtek; a régi export profilozása a `miserend_v4.sqlite3` aznapi példányán (minden `misek` sor konkrét előfordulás, `nap = 0`, `datumtol = datumig`, 182 napos ablak).
