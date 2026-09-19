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

**SQLite export**:
A miserend.hu naponta generált, teljes adatbázis-pillanatképe (templomok, misék, képek), amely az API v4 `Sqlite` végpontján érhető el. A **kezdeti feltöltés** forrása, és ebből olvasnak a még API-ra át nem állított képernyők. A v3 export már nem támogatott.
_Avoid_: "az adatbázis" önmagában; "v3 export" (megszűnt); a letöltött fájl neve (a végpont mögött, átirányítással változhat).

**Helyi gyorsítótár (local cache)**:
Az eszközön tárolt templom- és mise-adatok, amelyek a v4 API válaszait tükrözik, és az app **egyetlen offline adatforrásai**. Első indításkor a **SQLite exportból** töltődnek fel egyszeri **kezdeti feltöltéssel**, utána kizárólag API-hívások írják felül soronként — a SQLite exportot többé nem töltjük le. Az API v4 a tekintélyelvű forrás, a gyorsítótár a tükre — a listaképernyők viszont online is a gyorsítótárat mutatják, és az API válasza a gyorsítótáron át jut el hozzájuk. Ha az API nem válaszol (akár mert a felhasználó nem engedélyezi az adatkapcsolatot, akár mert nincs lefedettség), a képernyő a gyorsítótár állapotánál marad, és ezt jelzi. Ha a felhasználó soha többé nem kapcsolódik, a kezdeti feltöltés állapota marad meg. Kivétel: a **legközelebbi misék** és a **gyóntatás** jelzése soha nem jön a gyorsítótárból (ld. `docs/adr/0002-*`).
_Avoid_: "az adatbázis" önmagában — korábban ez a teljes, letöltött SQLite fájlt jelentette; most az API részleges, esetlegesen elavult tükrözése.

**Kezdeti feltöltés (bootstrap import)**:
Az első indításkor lezajló egyszeri művelet: a **SQLite export** letöltése és a régi séma szerinti sorok átalakítása (mappelése) az API-alakú helyi sémára — beleértve a régi visszatérési-szabály oszlopok (`nap`, `periodus`, `datumtol`, `datumig`) egyszeri kiszámítását konkrét mise-időpontokra. Minden templomot átvesz, miséket a telepítés napjától **30 napra** — ennyi ideig mutat teljes miserendet egy soha többé nem kapcsolódó készülék is. Ezután többé nem fut le; nem tévesztendő össze a folyamatos, API-alapú frissítéssel.
_Avoid_: "adatbázis-frissítés" / "sync" erre a lépésre — az a folyamatos, API-alapú frissítést jelenti, nem az egyszeri importot.

**Nincs kapcsolat (no connection)**:
Az API-kérés el sem jutott a szerverig: a felhasználó nem engedélyezte az appnak az adatkapcsolatot, nincs lefedettség, repülőgép-üzemmód van, vagy a kérés időtúllépéssel leállt. Ezeket az app nem különbözteti meg egymástól (Androidon nem is tudná megbízhatóan). A képernyő a **helyi gyorsítótárból** dolgozik, a misék mellett (i) jelzés áll, amely koppintásra elmondja, mikori az adat, és mit tehet a felhasználó. Az állapot **átmeneti**: amíg a jelzés áll, a képernyő magától kérdez újra, és az első sikeres válasszal a jelzés eltűnik — a felhasználónak nincs teendője azon túl, hogy a kapcsolatot helyreállítja.
_Avoid_: "offline mód" (nem a felhasználó kapcsolja be); "nincs internet" (a tiltás nem a hálózat hiánya); a jelzést állandó állapotnak tekinteni, amelyből csak kézi frissítés vezet ki.

**Szerverhiba (server error)**:
A szerver elérhető volt, de hibás választ adott (HTTP-hiba, `error: 1`, értelmezhetetlen válasz). A képernyő a **helyi gyorsítótár** állapotát mutatja, és **eltérő színnel** jelzi, hogy nem online adatot mutat — ez a felhasználó számára váratlan, hiszen van térereje. Az (i) jelzés itt is megjelenik, a miserend.hu elérhetetlenségére szabott szöveggel. A **Nincs kapcsolat**-hoz hasonlóan ez is átmeneti: a képernyő magától kérdez újra, amíg a jelzés áll.
_Avoid_: "offline" (a telefon online); a sikeres, de üres válasz ("ezen a napon nincs mise") nem szerverhiba.

**Helyzet (position)**:
A felhasználó földrajzi helyzete, amelyhez képest a közeli templomok és a **legközelebbi misék** rendeződnek, és ahová a Térkép „helyzetem" gombja ugrik. A Térkép fülön a helyzet **látható jelölés** is, nem csak kameracél — a jelölés mutatja, merre és nagyjából milyen messze van egy templom; a pontos számot a **légvonal-távolság** írja ki. Csak friss helyzet számít: legfeljebb 5 perce rögzített pozíció, különben új helymeghatározás, időkorláttal. Egy régebbi pozíció nem helyzet — lehet, hogy egy másik városban rögzült, ezért a jelölés is csak addig látszik, amíg a helyzet ismert: sikertelen helymeghatározás után eltűnik.
_Avoid_: "utolsó ismert pozíció" a helyzet szinonimájaként; "GPS" (a helymeghatározás nem csak műholdas).

**Helyzet nem elérhető (position unavailable)**:
Az app nem tudja a felhasználó **helyzetét**. Négy oka van, és a felhasználónak mindegyiknél mást kell tennie: **engedély megtagadva** (az app újra kérheti), **engedély véglegesen megtagadva** (csak a telefon beállításaiban adható meg), **helymeghatározás kikapcsolva** (a telefon beállításaiban kapcsolható be), **nincs friss helyzet időben** (újrapróbálható). A helyzethez kötött listák ilyenkor nem jelennek meg, helyettük az okhoz tartozó tájékoztató áll; a Térkép az ország nézetében marad. Független a **Nincs kapcsolat** állapottól: a helymeghatározás adatkapcsolat nélkül is működik, és a két állapot egyszerre is fennállhat.
_Avoid_: "helyadat" állapotként (az az engedély neve); "GPS-hiba" (az ok legtöbbször az engedély vagy a kikapcsolt helymeghatározás).

**Légvonal-távolság (straight-line distance)**:
A templom és a **helyzet** közti távolság a földfelszínen, egyenes vonalban — nem az út hossza és nem a menetidő. Az app nem tudja, gyalog vagy autóval indul a felhasználó, és útvonaltervezője sincs (ugyanaz a korlát, mint az **Elérhető mise**-nél). Tíz méterre kerekítve áll ki, mert a helymeghatározás és a templom koordinátája sem pontosabb ennél. Csak ott látszik, ahol a helyzet ismert és a templomnak van érvényes koordinátája; különben nincs kiírva — nem nulla, hanem ismeretlen.
_Avoid_: „távolság" önmagában, ha az útvonal is szóba jöhet; „messze/közel" mértékként; „menetidő".

**Napi miserend (daily masses)**:
Egy adott templom aznapi miséinek listája — ennek forrása a v4 API `Church`, `Search` és `NearBy` végpontjainak `misek` mezője (`idopont`/`informacio` párokként). A mező a nevével ellentétben nem csak misét ad (ld. **Mise vs. egyéb liturgikus esemény**): a napi miserendbe csak a misék tartoznak. A listákon a templomsor mise-időpontjai a napi miserendet mutatják.
_Avoid_: a `misek` mezőt "a miserend"-nek nevezni — csak a mai napra vonatkozik, nem a kiterjesztett listára.

**Kiterjesztett miserend (extended schedule)**:
A templom-részletező oldal több napra (ma / következő vasárnap / 19 nap) kiterjedő miselistája egy adott templomhoz, szemben a napi miserenddel. Egyetlen v4 végpont sem adja ezt vissza közvetlenül, egy adott templomra szűkítve — előállítása a `NearbyMasses` végpont kombinálásával történik (ld. `docs/adr/0002-*`, `docs/spec/0003-*`).
_Avoid_: "miserend" önmagában, ha a hatókör (egy nap vs. több nap) számít.

**Mise vs. egyéb liturgikus esemény**:
A v4 API `NearbyMasses` végpontja nevével ellentétben nem csak miséket ad vissza, hanem minden, a miserendben rögzített eseményt, amelyeket csak a `title` szövege különböztet meg. **Mise**: *Szentmise*, *Szent Liturgia* (a görögkatolikus szentmise — a neve nem árulja el, de mise), *Régi rítusú szentmise*. **Nem mise**: *Vecsernye*, *Utrenye* (görögkatolikus imaórák), *Igeliturgia* (pap és áldozás nélküli szertartás), *Gyóntatás*, *Szentségimádás*, *Rózsafüzér*, *Litánia*. Ismeretlen cím nem számít misének, amíg valaki fel nem veszi. **Ellenőrizve**: nyolc helyszín két napján (2026-09-19/20, 50 km) ezek voltak az előforduló címek. Ugyanez igaz a `Church`/`Search`/`NearBy` válasz `misek` mezőjére, ahol az esemény fajtáját az `informacio` szöveg eleje hordozza, felekezeti előtaggal és a vessző után jellemzőkkel (pl. „Római katolikus Szentmise, Csendes", „Római katolikus Gyóntatás") — a fajta itt is a fenti listával dől el. **Ellenőrizve** (2026-09-15, Budapest-keresés és tid 1515).
_Avoid_: a `NearbyMasses` vagy a `misek` elemeit válogatás nélkül "misének" nevezni.

**Legközelebbi misék (nearest masses)**:
A Misék fül listája: a felhasználó pozíciójához **térben** legközelebbi (legfeljebb 10) templom **összes** mai, még **elérhető** miséje — egy misének egy sor, így egy több misét tartó templom többször is szerepel. Nem egy templomhoz tartozik (szemben a napi miserenddel), hanem a felhasználó helyzetéhez. A "legközelebbi" **a templomok kiválasztására** vonatkozik (térbeli közelség); a lista viszont **időrendben** áll, azonos kezdésnél a közelebbi templom elöl. Csak **misét** tartalmaz, más liturgikus eseményt nem, és csak a mai nap miséit. A "mai nap" két szélén van egy-egy kivétel: egy tegnap késő este kezdődött, még elérhető mise is benne van, és a **holnap pontban 00:00-kor** kezdődő mise is — az éjféli mise (karácsony, újév) a felhasználó fejében az előző estéhez tartozik. A 10-es korlát a templomokra vonatkozik, nem a sorokra: a lista hossza attól függ, hány miséjük van még aznap.
_Avoid_: "közeli miserend" (a "miserend" egy templom miséit jelenti); "következő misék" (azt sugallja, hogy a kiválasztás is időbeli).

**Elérhető mise (reachable mass)**:
Olyan mise, amelyre a felhasználó még érvényesen odaérhet: a kezdése óta legfeljebb **10 perc** telt el. A határ liturgikus eredetű — aki a mise elejéről 10–15 percnél többet késik, már nem áldozhat —, és a biztonságos alsó értéket használjuk. Nem számol menetidővel: az app nem tudja, gyalog vagy autóval érkezik-e a felhasználó, és útvonaltervezője sincs; az elérhetőség tehát csak az órán múlik, a távolságon nem.
_Avoid_: "még nem kezdődött el" (a néhány perce kezdődött mise is elérhető); "odaérhető" (menetidő-számítást sugall, ami nincs).

**Épp most tartó mise (ongoing mass)**:
Olyan elérhető mise, amely már elkezdődött (legfeljebb 10 perce) — a listán ezzel jelölve jelenik meg. Nem azt jelenti, hogy a mise bármikor a befejezéséig "tart" a lista szempontjából: 10 perc után kikerül, mert onnantól nem elérhető.
_Avoid_: "folyamatban lévő mise" általánosságban — a mise még tarthat, csak már nem elérhető.

**Hátralévő idő (time until start)**:
Mennyi idő van még egy **elérhető** mise kezdéséig, a kezdés pontos időpontja mellett kiírva („25 perc múlva", „1 óra 5 perc múlva"), percre pontosan. Csak **2 órán belül** kezdődő misénél látszik — azon túl a pontos időpont önmagában elég. Az **épp most tartó misénél** nincs hátralévő idő, és az eltelt percek sincsenek kiírva: a helyén az „Épp most tart" jelölés áll, mert a lista nem a mise hosszát követi, hanem az elérhetőséget. Nem menetidő-becslés: azt mondja meg, mikor kezdődik a mise, nem azt, hogy mikor kell elindulni.
_Avoid_: "visszaszámlálás" (másodpercre pontos, élő órát sugall — percenként frissül); "indulásig hátralévő idő" (menetidővel nem számolunk).

**Misekártya vs. templomkártya (mass card vs. church card)**:
A **misekártya** a Misék fül egy sora: egy konkrét mise-alkalom, amelyben az időpont áll elöl, és a templom csak a helyét mondja meg. Egy templom annyi misekártyán szerepel, ahány miséje van a listán. A **templomkártya** egy templomot mutat (Templomok fül listái, térképi kártya), a **napi miserendjével** együtt. A két kártya egy családba tartozik, ezért könnyű a Misék fül kártyáját is „templomkártyának" hívni — de amiről szól, az a mise.
_Avoid_: "templomkártya" a Misék fül soraira; "misesor".

**Mise jellemzője (mass detail)**:
Ami egy mise leírásában a fajtája után áll: „Csendes", „latin nyelven", „(Mária-kápolnában)", „(adventben 6:00)". **Szabad szöveg** — a miserend.hu adatgondozói írják, és a helyszínt vagy időszakos eltérést is hordozhat. Egy része viszont zárt készlet: a **misetípusok** (Családos/mocorgós, Diák, Egyetemista/ifjúsági, Gitáros, Orgonás, Csendes, Énekes), amelyeket a misekártya ikonként mutat (spec 0011). Csak egy templom napi miserendjének leírásában érkezik; a legközelebbi misék forrása csak a mise fajtáját adja, a jellemzőt nem. **Ellenőrizve** (2026-09-17, Budapest belváros, 20 templom mai miséi).
_Avoid_: "címke" / "tag" a teljes jellemzőre (zárt készletet sugall — csak a misetípusok azok); a jellemzőt a mise fajtájának tekinteni (a „Szentmise, Csendes" fajtája szentmise).

**Részletes kereső (advanced search)**:
**Templomok** keresése több feltétel együttesével: név, település (szövegrészre, így a „Buda" Budakeszit is hozza), liturgikus nyelv, és hogy van-e **miséje** — csak misének, más liturgikus esemény nem számít — egy adott napon és időablakban. A megadott feltételek **mindegyikének** teljesülnie kell; részleges egyezés nem találat. A találat templom, nem mise-alkalom. A név a régi Android appból jön, ahol ugyanott, a keresősáv javaslatainak alján volt — a frissítéssel érkező felhasználók így ismerik fel. Nem azonos a keresősáv egyszerű keresésével (egy szöveg, nap nélkül), és nem a **legközelebbi misék** kibővítése (az mindig ma és a helyzet körül).
_Avoid_: "misekereső" (a találat templom); "szűrő" (a lista nem egy meglévő lista szűkítése); "összetett keresés".

**Gyóntatás (confession)**:
Nem miserend-adat és nem nyitvatartás, hanem egy **pillanatnyi állapot**: a miserend.hu gyóntatószékekbe szerelt fizikai kapcsolókat üzemeltet, amelyek LoRaWAN-on jelentik, hogy éppen van-e gyónási lehetőség (`POST /api/v4/lorawan`, tokenhez kötött, a `/apidocs` szerint kísérleti). A v4 `Church` válasz `gyontatas` mezője ennek a kapcsolónak az **aktuális** állása. **Ellenőrizve**: a mező puszta bool, és nem különbözteti meg a *kikapcsolt kapcsolót* a *nem létező kapcsolótól* — mindkettő `false`, miközben a webapp harmadik állapotként külön kiírja, hogy "Ezen a misézőhelyen nincs gyóntatást jelző kapcsoló". Élő mintavétel (2026-09-11, id 1–400): 338 válaszból 338 `false`. Következmény: a kliens csak a `true` esetet jeleníti meg, és csak friss API-válaszból — gyorsítótárazott értékből soha (ld. `docs/adr/0002-*`).
_Avoid_: "gyóntatási rend" / "gyóntatási időpontok" (azt sugallja, hogy menetrend, pedig egy kapcsoló állása); "van-e gyóntatás" (a `false` erre nem válasz).

**Frissítve (`frissitve`) vs. helyi szinkron (`local_synced_at`)**:
Két különböző tény, amelyeket könnyű összekeverni. A **frissítve** azt mondja meg, mikor szerkesztették utoljára az adatot **a miserend.hu oldalán** — ez a felhasználónak mutatott érték. A **helyi szinkron** azt, mikor beszélt **ez a készülék** utoljára az API-val az adott templomról (`null`, ha a sor csak a kezdeti feltöltésből származik). Alapból nem látszik; csak akkor jelenik meg, amikor a képernyő nem online adatot mutat, és a felhasználó az (i) tájékoztatót megnyitja — ott ez a „mikori az adat". Egy templomot mutató képernyőn (részletező, térképi kártya) a templom helyi szinkronja; egy listán a lista utolsó sikeres frissítése, mert a sorok eltérő korúak lehetnek. Ha még nem volt ilyen, a kezdeti feltöltés dátuma.
_Avoid_: "frissítve" önmagában, ha nem egyértelmű, melyik oldalról van szó.

**Liturgikus nyelv jelölése (`nyelvek`)**:
Annak a nyelvnek a jelölése, amelyen a templomban misézni szoktak — **templom-szintű** adat, nem mise-szintű (a v4 API az egyes misékhez nem ad nyelvet, ld. `docs/spec/0003-*`). A mező **saját, zárt szókincset** használ, amely **se nem ISO 639 nyelvkód, se nem ISO 3166 országkód**, hanem a miserend.hu zászlókészletének kódja: az értékkészlet pontosan az `assets/flags/` fájlnevekkel egyezik. Ahol a nyelvhez nincs ország, ott saját jelkép áll: **`va`** (Vatikán zászlaja) = **latin**, **`cu`** (zöld mezőben arany hármas kereszt) = **ószláv**, **`rue`** (ruszin zászló) = **ruszin**. Ahol van ország, ott is az országkód áll a nyelv helyett: **`ua`** = ukrán (nem `uk`), **`gr`** = görög (nem `el`), **`si`** = szlovén (nem `sl`), **`tl`** = tagalog. **Ellenőrizve**: 500 templomot lekérdezve 12 kód fordul elő (`hu, va, en, de, fr, es, it, pl, sk, hr, ua, tl`), és mindegyikhez létezik zászló. **Csapda**: ISO 639-ként olvasva a kódok némán elromlanak — az `la` ebben a készletben *Laosz*, nem a latin.
_Avoid_: "nyelvkód" önmagában (azt sugallja, hogy ISO 639); "országkód" (a `va`/`cu`/`rue` nem ország).

**Hibajelentés (problem report)**:
Egy **templom adatairól** szóló jelzés a miserend.hu adatgondozóinak: rossz pozíció, rossz misei adat vagy egyéb hiba. Mindig egy templomhoz kötődik, ezért csak a templom részletezőjéről indítható, és a miserend.hu-hoz jut el, nem az app fejlesztőihez. Csak kapcsolat mellett küldhető: amíg a részletező **Nincs kapcsolat** vagy **Szerverhiba** jelzést mutat, a hibajelentés nem indítható, és a jelzés eltűnésével magától újra elérhető. Sorba állított, később elküldött hibajelentés nincs.
_Avoid_: "visszajelzés" erre (az az appról szól); "hibabejelentés" az app működési hibájára.

**Visszajelzés (feedback)**:
Az **appról** szóló üzenet az app fejlesztőinek (Szent József Hackathon): az app hibája, vélemény vagy új funkció kérése. Nem kötődik templomhoz, és nem a miserend.hu adatgondozóihoz jut el. Ha a felhasználó egy templom adatait látja hibásnak, az **hibajelentés**, nem visszajelzés — annak a helye a templom részletezője, ahol egyértelmű, melyik templomról van szó; a visszajelzés erre nem utal és nem irányít át.
_Avoid_: "funkciókérés" külön fogalomként (a visszajelzés egyik fajtája); "hibajelentés" az app hibájára.

**Névjegy (about page)**:
Az alsó navigáció negyedik pontjából nyíló oldal: a **visszajelzés**, a „Mai templom ajánlatunk”, az app **impresszuma** és a webes változat linkje, egy lapon. Nem fül, hanem a fülek fölé nyíló oldal. Korábbi neve „Menü” volt.
_Avoid_: "Menü" (oldalsó menüt sejtet, ami nincs); "Beállítások" (beállítás nincs rajta).

**Impresszum (impressum)**:
Az app **fejlesztője** (Szent József Hackathon) és verziója, és a forráskód helye. Nem külön oldal: a Névjegy szakaszai. Kiadó és támogatási (1%-os) felhívás nincs rajta.
_Avoid_: a miserend.hu üzemeltetőjével azonosítani (a webet a Szent József Hackathon közössége tartja fenn).

**Szentségimádás (adoration)**:
Dátumozott időablakok listája (`kezdete`/`vege`/`fajta`/opcionális `info`), nem visszatérési szabály és nem mise. Ugyanarra a napra **átfedő** bejegyzések is érkezhetnek (pl. egy `00:00–23:59` és egy `09:00–18:00`); ezek nem hibák, és nem vonhatók össze, mert a teljes napos ablak jelenthet valódi örökimádást is.
_Avoid_: "adoráció-rend" / "szentségimádás miserendje" (nem menetrendi adat, és nem a `misek` mezőből jön).
