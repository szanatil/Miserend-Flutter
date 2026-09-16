# Légvonal-távolság és a templomkártya szövegei

> Tracker: [szanatil/Miserend-Flutter#25](https://github.com/szanatil/Miserend-Flutter/issues/25)

## Problem Statement

Két gond van, és ugyanazt a widgetet érinti:

- **A templomkártya nem írja ki a távolságot.** A #24 óta a Térkép mutatja a **helyzetet**, így a felhasználó látja, merre van egy templom, de csak becsülni tudja, milyen messze. A Közelben lista távolság szerint rendez, de a számot nem mutatja. A Misék listán ma is van távolság, de mindig km-ben (`0,3 km`), és sima szövegként az időpont mellett.
- **A templomkártya levágja a szöveget.** A kártya fix 176 px magas (`church_card.dart:34`), de a tartalma 185 px-t kér: kétsoros név (68), egysoros ismertnév (32), mise-chipek (36), elválasztó (1), szív (48). A hiányzó 9 px-t az ismertnév `Expanded`-je veszi el. Kétsoros névnél az ismertnévnek 15 px marad egy 24 px-es sorra, ezért a sor **függőlegesen félbevágva** látszik („Alsóvárosi templom, Ferences"). Sem a névnek, sem az ismertnévnek nincs `maxLines`-a. A mise-chipek `Wrap`-je sincs korlátozva, így egy sok misés templomnál második sorba törik, és a kártya túlcsordul.

## Solution

A templomkártya és a Misék sor egy közös távolság-chipet kap, amely a **légvonal-távolságot** (CONTEXT.md) írja ki: 10 m-re kerekítve, 1 km alatt méterben, fölötte km-ben. Ahol nincs helyzet, vagy a templomnak nincs érvényes koordinátája, a chip nem jelenik meg.

A templomkártya 192 px magas lesz. A név és az ismertnév fix sorszámot kap ellipszissel, a mise-chipek egyetlen sorban férnek el, és ami nem fér ki, azt egy `…` chip jelzi. A kártya így a korábbi (Android-os) mintát követi.

## User Stories

1. Mint felhasználó, a Közelben listán szeretném látni, milyen messze van tőlem egy templom, hogy ne csak a sorrendből kelljen kitalálnom.
2. Mint felhasználó, a térképen megnyitott templomkártyán szeretném látni a távolságot, hogy ne a térképről kelljen becsülnöm.
3. Mint felhasználó, szeretném, hogy a távolság a Misék listán és a templomkártyán ugyanúgy nézzen ki és ugyanúgy legyen kiírva.
4. Mint felhasználó, akinek nincs helyzete, szeretném, hogy a kártyán ne legyen se távolság, se helyőrző, mert az nulla vagy hiba volna, nem „ismeretlen".
5. Mint felhasználó, szeretném, hogy egy hosszú templomnév és az ismertnév olvashatóan, ne félbevágva álljon a kártyán.
6. Mint felhasználó, szeretném, hogy a mise-időpontok, az elválasztó és a szív minden kártyán ugyanabban a magasságban álljon, hogy a lista könnyen átfutható legyen.
7. Mint felhasználó, akinek a templomában ma sok mise van, szeretném látni, hogy több is van, mint amennyi kifér, hogy tudjam: a részletezőn érdemes megnézni.
8. Mint vidéki felhasználó, a Misék listán továbbra is szeretném látni a városnevet, mert a falumban lévő egyetlen templom neve önmagában nem mondja meg, melyik faluról van szó.

## Implementation Decisions

### Hol jelenik meg a távolság

| Képernyő | Távolság | A távolság forrása |
|---|---|---|
| Templomok → Közelben | **igen** | helyben számolva a lista kéréséhez használt helyzetből (`NearChurchesQuery.lat/lon`) |
| Térkép → templomkártya | **igen** | helyben számolva a `_userPosition`-ből (`map_page.dart:72`) |
| Misék | **igen** (ma is) | az API `distance_km`-je, változatlanul |
| Templomok → Kedvencek | nem | — |
| Keresés találatai | nem | — |

- A `ChurchCard` négy helyen jelenik meg (a ticket hármat említ): a `ChurchListView`-n át a Közelben, a Kedvencek és a Keresés oldalon, valamint a térképen. A kártya egy **nullázható** helyzetet kap. A kártya nem kér helyzetet, csak megkapja. Ahol a helyzet null, ott nincs chip. A `ChurchListView` ezt továbbadja, és csak a Közelben oldal tölti ki.
- A Kedvencek és a Keresés **nem kér helyzetet**. Ott a helymeghatározás új mellékhatás volna (egy „Budapest" keresés után megjelenő engedélykérő ablak), és a sorrend sem távolság-alapú. Ha később mégis kell, az oldalt kell módosítani, a kártyát nem.
- A térképi kártya a `_userPosition` aktuális értékét kapja a `build`-ben. Ha a helyzet nyitott kártya mellett elveszik vagy frissül, a chip ezzel együtt eltűnik vagy frissül.

### Érvényes koordináta

- A chip csak akkor jelenik meg, ha a templom `lat` és `lon` értéke nem null, és nem `(0, 0)`. Ugyanezt a szabályt használja a `CacheDatabase.churchLocations` (`cache_database.dart:430`) és a `nearChurches`. A `churchesByIds` (Kedvencek, **térképi kártya**) nem szűr, és egy `(0, 0)` templom ~1800 km-es távolságot kapna.
- A szabály egy helyen nevesítve él, hogy a térképi jelölés és a távolság ne válhasson el egymástól.

### Számítás és formátum

- **Helyben** a gömbi távolság (haversine) a `latlong2` `Distance`-szel vagy a `Geolocator.distanceBetween`-nel számolódik. Mindkettő már függőség, új csomag nem kell.
- A **Misék** lista az API `distance_km`-jét használja. Az két tizedessel érkezik, vagyis eleve 10 m-es felbontású. A kiválasztás és a rendezés (`nearest_masses.dart`) nem változik.
- A kerekítés miatt a kétféle forrás ugyanarra a templomra általában ugyanazt adja, de ez nem garantált. Ezt vállaljuk.
- `formatDistance(double km)` saját fájlba költözik a `mass_list_item.dart`-ból, a küszöbökkel együtt (D3):
  1. Előbb **10 m-re** kerekítünk.
  2. **1000 m alatt** méterben írjuk ki: `300 m`.
  3. **1000 m-től** km-ben, **egy tizedessel, a `,0` elhagyásával**, magyar tizedesvesszővel: `1 km`, `1,2 km`, `12 km`, `12,5 km`.
  4. A határon a kerekítés dönt: 995 m → 1000 m → `1 km`. `1000 m` soha nem jelenik meg.
- A tizedesjegy lebegőpontos kerekítés helyett egész számú százméterekből készül, hogy a `toStringAsFixed` lebegőpontos határesetei ne ronthassák el.

### Távolság-chip

- Közös widget, félig áttetsző sötét pirula, fehér `bodyMedium` felirattal. Fehér alapon (Misék sor) szürkének, fotón sötétítésnek látszik. A fotó tetszőleges világos lehet, ezért kell a sötét alap.
- **Templomkártya:** a fotó **jobb alsó sarkában**, 8 px-re a szélektől, a fotóra rétegezve (`Stack`). A helyőrző kép (`church_blurred.png`) fölött is ugyanígy jelenik meg. A szövegoszlopban nem foglal helyet, így a hiánya semmit nem mozdít el.
- **Misék sor:** a sor **jobb szélén**, a szövegoszlopon kívül. Az időpont mellől kikerül. A városnév, a templomnév színe, az „Épp most tart" jelzés és a cím változatlan marad.

### Templomkártya-elrendezés

- Magasság: **192 px**, nevesített, publikus konstans. A térképen a „helyzetem" gomb eltolása ma kézzel beírt `192` (`map_page.dart:160`). Ez a konstansból számolódik: `magasság + 16` (a kártya 8–8 px-es paddingje). A kártya 192-re nőtt, ezért a gomb 208-ra kerül.
- A 48 px-es szív `IconButton` marad. Kisebbre véve a Material minimális érintési felülete alá esne, és ez a kártya egyetlen gombja.
- **Név:** `titleLarge`, legfeljebb **2 sor**, ellipszissel.
- **Ismertnév:** `titleMedium`, **szürke**, legfeljebb **1 sor**, ellipszissel.
- A név és az ismertnév helye **fix**: rövid névnél és hiányzó ismertnévnél is ugyanannyi. A mise-chipek, az elválasztó és a szív így minden kártyán ugyanabban a magasságban áll. Az `Expanded` a szövegek körül megszűnik.
- **Mise-chipek:** legfeljebb **egy sor**. Ha nem fér ki mind, a sor végén egy narancs `TimeChip`-stílusú `…` chip áll a kimaradók helyett. Hogy hány fér ki, azt a tényleges szélesség dönti el (`LayoutBuilder`), nem egy rögzített darabszám, mert a kártya szélessége képernyőnként más.
- A `…` chipnek nincs saját koppintása: az egész kártya a részletezőt nyitja, és ott minden mise látszik.

### Fájlok, amik érintettek

- `lib/home/churches/church_card.dart`: elrendezés, távolság-chip, magasság-konstans
- `lib/home/churches/church_list_view.dart`: a helyzet továbbadása
- `lib/home/churches/near_churches_page.dart`: helyzet a listának
- `lib/home/map/map_page.dart`: helyzet a kártyának, a gomb eltolása a konstansból
- `lib/home/masses/mass_list_item.dart`: a chip jobbra kerül, a `formatDistance` kiköltözik
- új: a `formatDistance` és a küszöbök fájlja, a távolság-chip widget, az érvényes koordináta szabálya
- `lib/database/cache/cache_database.dart`: az érvényes koordináta szabálya a közös helyről
- `CONTEXT.md`: „Légvonal-távolság" szócikk (kész), „Helyzet" pontosítás (kész)

## Testing Decisions

- **`formatDistance` unit tesztek:** `0 → 0 m`, `0,296 → 300 m`, `0,994 → 990 m`, `0,995 → 1 km`, `1,23 → 1,2 km`, `1,25 → 1,3 km`, `12 → 12 km`, `12,46 → 12,5 km`, `12,96 → 13 km`. A mostani tesztek (`near_masses_page_test.dart:719`) ide költöznek és átíródnak.
- **Érvényes koordináta:** null `lat`, null `lon` és `(0, 0)` → nincs chip.
- **Templomkártya widget tesztek:**
  - helyzettel → a chip a várt szöveggel;
  - helyzet nélkül → nincs chip, a többi elem a helyén;
  - érvénytelen koordinátával → nincs chip;
  - háromsoros hosszúságú névvel és hosszú ismertnévvel → nincs túlcsordulás (`tester.takeException()` null), és mindkét szöveg `maxLines`-szal áll;
  - rövid és hosszú névvel → a chipsor és a szív `top` értéke ugyanaz;
  - sok misével, keskeny kártyán → megjelenik a `…`, és a chipek egy sorban vannak.
- **Közelben:** a sorokon megjelenik a távolság a fake helyzetből (T3 `FakeLocationProvider`). **Kedvencek, Keresés:** nincs chip.
- **Térkép:** helyzettel nyitott kártyán van chip. Ha a helyzet elveszik, a chip eltűnik. A „helyzetem" gomb alja a kártya magasság-konstansából jön (a `map_page_test.dart:554` környéki elrendezés-teszt igazodik).
- **Misék sor:** a mostani „shows the city and the distance with a decimal comma" teszt a városnevet és az új formátumot ellenőrzi (`1,2 km`), és azt, hogy a chip a sor jobb szélén áll.

## Out of Scope

- **Távolság a Kedvencek és a Keresés listán:** új helymeghatározást és „helyzet nem elérhető" ágat hozna olyan képernyőkre, amelyek ma nem kérnek helyzetet. A kártya úgy készül, hogy később csak az oldalt kelljen módosítani.
- **Menetidő, útvonalhossz:** a „Légvonal-távolság" és az „Elérhető mise" szócikk szerint az appnak nincs útvonaltervezője.
- **Élő frissülés mozgás közben:** a helyzet pillanatkép (CONTEXT.md, „Helyzet"). A chip a képernyő meglévő helyzet-lekéréseivel frissül.
- **A Misék sor további átszabása a minta szerint** (városnév nélkül, szürke templomnévvel): a városnév vidéken az egyetlen megkülönböztető adat.
- **Háromsoros név:** a harmadik sor az ismertnév helyét venné el. A teljes név a részletezőn olvasható.

## Further Notes

- A mintaképek (`296 m`) méterre pontos számot mutatnak. A 10 m-es kerekítés tudatos eltérés: az API távolsága is ilyen felbontású, a helymeghatározás és a templom koordinátája pedig sem pontosabb ennél.
- A 192 px-es kártyával a listán kártyánként 16 px-szel kevesebb fér a képernyőre.
