# Térképi jelölések — templom-pin, saját helyzet, sűrűség-küszöb

> Tracker: [szanatil/Miserend-Flutter#24](https://github.com/szanatil/Miserend-Flutter/issues/24)

## Problem Statement

A Térkép fül adatforrása rendben van (spec 0005, ADR-0003, #18), a **megjelenítése** viszont három sebből vérzik:

- **Rossz jelölés.** Minden templomot egy piros `Icons.location_pin` glyph jelöl. A miserend.hu-nak van saját templom-pinje (`assets/images/map_pin.png`: lila alap, fehér templom), ami a webappal is egyezteti a két klienst — a Flutter app ezt nem használja.
- **Elcsúszott markerek.** A `flutter_map` `Marker`-ének alapértelmezett mérete 30×30 (`marker.dart:60-61`), és a layer ezt tight constraintként adja át (`marker_layer.dart:140-145`). A jelenlegi `Icon(size: 40)` ebbe nem fér bele, de `TextOverflow.visible` miatt nem is vágódik le (`icon.dart:329`) — kilóg. Következmény: **minden pin ~5 px-szel jobbra és lefelé csúszik** a valódi koordinátájától, és a culling is a 30×30-as dobozzal számol, így a képernyő szélén egy marker eltűnhet, miközben még látszania kéne.
- **Nincs saját helyzet.** A **helyzetet** (CONTEXT.md, „Helyzet") az app csak kameracélra használja: a „helyzetem" gomb odaugrik, de a felhasználó nem látja, hol van. Így a térképről nem olvasható le az, amiért a felhasználó megnyitja: milyen messze van tőle egy templom.

Van egy negyedik, a fentiekből következő gond: a térkép a 8-as kezdő zoomon az egész országot mutatja, tehát **mind az ~5000 templom** egyszerre látszik. 40 px-es pinekkel ez összefüggő massza, amiből semmi nem olvasható ki — és a részletesebb, színes pinnel ez rosszabb lesz, nem jobb.

## Solution

A `MiserendMap` a miserend.hu templom-pinjét rajzolja, helyes horgonyzással és explicit marker-mérettel; a Térkép fül kirajzolja a felhasználó **helyzetét** egy kék pöttyel; a sűrűséget pedig zoom-küszöb kezeli, nem klaszterezés: közeli nézetben teljes pin, távoliban apró pötty.

Ettől a térkép arra a kérdésre válaszol, amiért megnyitják: „hol vagyok én, és hol vannak hozzám képest a templomok".

## User Stories

1. Mint felhasználó, szeretném, hogy a templomokat a miserend.hu saját templom-pinje jelölje, hogy ránézésre felismerjem, mit látok, és hogy a mobil és a web ugyanúgy nézzen ki.
2. Mint felhasználó, szeretném, hogy a pin hegye pontosan a templom koordinátáján álljon, hogy a térkép ne hazudjon nekem néhány méternyit.
3. Mint felhasználó, szeretném **látni a saját helyzetemet** a térképen, hogy megbecsüljem, milyen messze van tőlem egy templom.
4. Mint felhasználó, szeretném, hogy a saját jelölésem egyértelműen elkülönüljön a templomokétól, hogy ne keverjem össze magam egy templommal.
5. Mint felhasználó, aki országos nézetben nézi a térképet, szeretném látni, hol sűrűsödnek a templomok, anélkül hogy a jelölések egymást takarnák.
6. Mint felhasználó, aki országos nézetben egy sűrű területre bök, szeretném, hogy a térkép odaközelítsen, mert ilyenkor a környék érdekel, nem egy konkrét templom.
7. Mint felhasználó, aki megnyitott egy templomkártyát, szeretném a térképen is látni, **melyik** pinről szól a kártya, akkor is, ha közben kizoomoltam.
8. Mint felhasználó, akinek nincs (vagy megszűnt) a helymeghatározása, szeretném, hogy **ne** lássak kék pöttyöt, mert az azt hazudná, hogy tudjuk, hol vagyok.
9. Mint felhasználó, aki közelre zoomolt, szeretném, hogy a „helyzetem" gomb odavigyen, de **ne zoomoljon ki** — a közelítést én állítottam be.
10. Mint fejlesztő, szeretném, hogy a saját helyzet ne a templom-markerek listájában utazzon, hogy egy helyzet-frissítés ne kényszerítse ki mind az 5000 marker újraépítését.

## Implementation Decisions

### Templom-pin

- Forrás: `assets/images/map_pin.png`, 111×171 px, RGBA. Domináns szín **`#5C27AE`** (a 8652 legátlátszatlanabb pixel), a templom-ikon fehér.
- Megjelenített méret: **40 px magas**, arányos szélességgel (111/171 × 40 ≈ **26 px**). A `Marker` `width`/`height`-ja **explicit** ez a két érték — ez javítja az elcsúszást és a hibás cullingot is.
- Horgonyzás: `Alignment.topCenter` marad. **Ellenőrizve** (`marker_layer.dart:109-114`, `144-145`): ez a gyerek **alsó** élét teszi a koordinátára, vagyis a pin hegyét — pin-hez ez a helyes.
- Felbontás: a PNG egyetlen változatban van (nincs `2.0x`/`3.0x`, és SVG sincs). 3x-es kijelzőn 40 px-hez 120×185 fizikai pixel kellene, a meglévő 111×171 ez alatt van — a pin enyhén lágy lesz. Egy ~26 px széles jelölésen ez nem észrevehető; ha később előkerül az SVG, cseréje egyetlen widgetet érint.
- Mindkét térkép ugyanezt kapja: a Térkép fül és a templom-részletező helykártyája. Ugyanaz a fogalom, ugyanaz a jelölés.
- Felekezet/aktív szerinti színezés **nincs**: az ADR-0001 ezt a `Church` modell hiányának (`isGreek: bool?` vs. webapp `denomination` + `active`) feloldásáig elhalasztotta, és ez a döntés azon nem változtat.

### Sűrűség-küszöb

> **Felülírva** a spec 0012 által ([Csoportosítás a térképen](0012-csoportositas-a-terkepen.md)): a pöttyös nézet és a 12-es küszöb megszűnt, a térkép minden zoomon csoportosít. A kiválasztott templom kiemelt tűje megmaradt.

- **`_pinMinZoom = 12`**, inkluzív: zoom **≥ 12** → teljes pin; zoom **< 12** → **8 px** átmérőjű, `#5C27AE` pötty, gyűrű nélkül.
- A pötty **nem nyit kártyát**: koppintásra a térkép a pötty koordinátájára **zoom 12-re közelít**. Országos zoomon tucatnyi pötty fedi egymást, és egy 8 px-es cél a 44 px-es minimális érintési terület töredéke — egy kártya itt találomra kiválasztott templomot mutatna. A koppintás valódi jelentése ilyenkor „ez a környék érdekel".
- A **kiválasztott** templom (amelyiknek nyitva a kártyája) **minden zoomon teljes pin**, **1,3×**-esre nagyítva, és a többi marker **fölé** rajzolva. Enélkül egy kizoomolás után a kártya és a térkép elveszítik egymást. A kiválasztott pinre koppintás nem nyit új kártyát — az övé már nyitva van.
- A küszöb átlépése a `MapController` kamera-eseményeiből derül ki; a markerlista csak akkor épül újra, amikor a küszöb **oldalt vált** (vagy a kiválasztás változik), nem minden zoom-lépésnél.

### Saját helyzet

- **18 px** átmérőjű kék pötty, **fehér gyűrűvel** és finom árnyékkal, **minden zoomon azonos méretben** — a méret nem ugrálhat zoomolás közben.
- Három jel különbözteti meg a templom-pöttytől: **szín** (kék vs. `#5C27AE`), **méret** (18 vs. 8 px), **gyűrű** (van vs. nincs).
- A templomok **fölötti** rétegben rajzolódik: külön `MarkerLayer`, a templomoké után.
- **Pontossági kör nincs.** A `Position.accuracy` rendelkezésre áll, de egy nagy, szürke korong a 8-as zoomú országnézetben inkább zavar, mint tájékoztat.
- **Csak a Térkép fülön.** A helykártya 17-es zoomú, a templomra centrált kivágat; a felhasználó helyzete onnan a legtöbbször kilóg, a kivágat tágítása pedig pont azt venné el, amiért a kártya ott van (hol áll a templom az utcában). A távolságot ott szöveg adja meg (#25).
- **Pillanatkép, nem élő követés** (CONTEXT.md, „Helyzet"): a pötty a meglévő `currentPosition()` hívásokból frissül. Nincs `getPositionStream`, nincs új állapotgép, nincs folyamatos akkumulátor-fogyasztás.

### Mikor ellenőrizzük újra a helyzetet

A helyzet a térkép háta mögött is megváltozhat: a felhasználó a telefon beállításaiban engedélyezi, miközben egy másik fül van elöl. A térkép ezért **négy** alkalommal kérdez:

| Alkalom | Sáv hibánál | Kamera |
|---|---|---|
| A fül első megnyitása (`initState`) | nem | követ |
| „helyzetem" gomb | **igen** | **mindig követ** |
| Visszalépés a Térkép fülre (`isActive` false → true) | nem | csak ha nincs még pötty |
| Visszatérés az appba (`resumed`), ha a Térkép az aktív fül | nem | csak ha nincs még pötty |

- A kamera-szabály egyetlen mondatban: **a kamera akkor követ, amíg a felhasználó nem látja magát** — az első helymeghatározásnál, vagy az elsőnél azután, hogy a helyzet elveszett. Ha a pötty már a képernyőn van, egy fül-váltás nem ránthatja el a térképet onnan, ahova a felhasználó navigált. A gomb kivétel: az mindig követ.
- A sáv **magától soha nem jön fel**; csak akkor, ha a felhasználó a gombbal kérte. Egy már fent lévő sáv fent marad, amíg egy sikeres helymeghatározás el nem tünteti.
- A feltétel **állapot-alapú, nem „ki küldte" alapú**: a `resumed` ág nem azt nézi, hogy a felhasználót a térkép saját sávja küldte-e a beállításokba. Ugyanez a szabály él a `near_churches_page.dart`-ban is. (Az eredeti hiba pont ez volt: a térkép csak a saját sávjából indított útra reagált, ezért a Templomok fül gombjáról engedélyezett helyadatot nem vette észre.)
- A `MapPage` ezért kap `isActive`-ot a `home.dart`-tól, ahogy a `NearMassesPage` — az `IndexedStack` életben tartja a fület, a lap magától nem tudja, hogy elöl van-e.
- **Sikertelen lekérés után eltűnik**, amíg egy sikeres vissza nem hozza. Egy megmaradó pötty a `PositionUnavailableBanner` mellett a képernyőn mondana ellent önmagának, és a „Helyzet" szócikknek is („Egy régebbi pozíció nem helyzet — lehet, hogy egy másik városban rögzült").

### `MiserendMap` API

- A saját helyzet **külön paraméter**: `LatLng? userPosition`, nem a `markers` listában egy `kind` mezővel.
  - Fogalmilag más: a `MiserendMapMarker`-nek templom-`id`-ja és `onTap`-je van, a helyzetnek egyiknek sincs értelme.
  - Gyakorlatilag: a widget a markerlista **azonosságához** köti az újraépítést (`didUpdateWidget`). Egy listába tett pötty minden helyzet-frissítéskor újragyártaná mind az 5000 markert.
- A kiválasztás szintén külön paraméter (`Object? selectedMarkerId`), ugyanezért.
- **Ellenőrizve** (`marker_layer.dart:122-133`, `54-65`): a `MarkerLayer` kullozza a képernyőn kívüli markereket, és gyorsítótárazza a vetített pontokat — az 5000 raszter-pin önmagában nem teljesítmény-probléma, amíg a lista nem épül újra képkockánként.

### „helyzetem" gomb

- A gomb odamozgat, de **nem zoomol ki**: a cél-zoom `max(jelenlegi zoom, 14)`. Egy „vigyél a helyzetemhez" gomb ne vegyen el közelítést, amit a felhasználó szándékosan állított be. 14-nél távolabbról továbbra is 14-re hoz.

### Fájlok, amik érintettek

- `lib/widgets/miserend_map.dart` — pin, pötty, küszöb, `userPosition`, `selectedMarkerId`
- `lib/home/map/map_page.dart` — helyzet eltárolása és továbbadása, kiválasztás, gomb-zoom, pötty-koppintás, `isActive` és az újraellenőrzés
- `lib/home/home.dart` — `isActive` a Térkép fülnek
- `lib/home/map/widgets/position_unavailable_banner.dart` — az `onSentToSettings` visszahívás elhagyása (feleslegessé vált)
- `CONTEXT.md` — „Helyzet" szócikk
- `test/widgets/miserend_map_test.dart`, `test/home/map/map_page_test.dart`

## Testing Decisions

- A jelölés fajtáját a teszt a widgetfáról olvassa (pin: `Image` az `assets/images/map_pin.png`-nel; pötty: méret és szín szerint), nem képernyőképből.
- A zoom-küszöböt `MapController.move`-val állítjuk be a teszt előtt, és a marker-gyerekek típusát ellenőrizzük a két oldalon.
- A helyzet-pötty tesztje a meglévő `_FakeLocation` mintát használja (T3), sikeres és sikertelen lekéréssel is.
- A „helyzetem" gomb zoom-viselkedését a `MapController.camera.zoom` értékéből olvassuk, két kiindulási zoomról.
- Az újraellenőrzés négy esetét külön csoport fedi (`coming back to the map`): visszatérés az appba a sávval a képernyőn, visszalépés a fülre, sikertelen ellenőrzés (nem jön fel sáv), és hogy a kamera a helyén marad, ha már van pötty. A fül-váltást a lap `isActive`-cal való újrapumpálása modellezi.

## Out of Scope

- **Távolság szöveges kiírása** a templomkártyán — #25. Három képernyőt érintene ugyanazon a widgeten át, saját kérdésekkel (kell-e a kedvenceknél, mi legyen helyzet nélkül, m/km váltás).
- **Rajzolt távolság-jelzés** (vonal a pöttytől a pinig, 1/5/10 km-es körök) — elvetve: mindkettő vizuális zaj 5000 pin fölött, és a légvonal-távolság rajzban félrevezetőbb, mint számban. Az app nem tervez útvonalat (ugyanaz a korlát, mint az „Elérhető mise" fogalmánál).
- **Marker-klaszterezés** (számozott, szétnyíló buborékok) — itt elvetve a zoom-küszöb javára; a spec 0012 később bevezette. Új függőséget hozna (`flutter_map_marker_cluster`) vagy saját rács-alapú összevonást, cserébe elveszne az, amit a mostani térkép jól csinál: hogy országos nézetben ránézésre látszik a templomok **eloszlása**. Egy klaszter-buborék ezt számokká alakítja. Az apró pötty ugyanazt a sűrűség-információt adja, kevesebb kóddal és takarás nélkül.
- **Felekezet/aktív szerinti színezés** — ADR-0001 szerint a `Church` modell hiányának feloldásáig áll.
- **Pontossági kör** a saját helyzet körül — ld. fent.
- **Élő helyzet-követés** (`getPositionStream`) — a „Helyzet" fogalma pillanatkép; egy folyam új állapotgépet és akkumulátor-költséget hozna olyan képernyőre, ahol a felhasználó tájékozódik, nem navigál.

## Further Notes

- Az `assets/images/map_pin.png` egyetlen felbontásban van a repóban. Ha a miserend.hu készletéből előkerül az **SVG** (vagy `2.0x`/`3.0x` PNG), a csere egyetlen widgetet érint — érdemes megkérdezni.
- A #18 („Térkép a gyorsítótárból…") kódja **be van commitolva** (`66ba0fd` és három utókövetés), de az issue nyitva állt e spec írásakor. Egy eltérés van benne: az issue SnackBart ír a „helyzetem" gomb hibáira, a kód `52b9268` óta **saját sávot** (`PositionUnavailableBanner`) használ — szándékos csere, nem regresszió.
- A **#22** refaktor is a térképet és a gyorsítótáras listákat érinti; párhuzamos futásnál ütközésre kell számítani.
