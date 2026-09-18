# A mise jellemzői a misekártyán

> Tracker: [szanatil/Miserend-Flutter#36](https://github.com/szanatil/Miserend-Flutter/issues/36)

## Problem Statement

A Misék fül **misekártyája** a mise fajtáját mutatja („Szentmise", „Szent Liturgia"), de azt nem, hogy **milyen** mise: csendes, latin nyelvű, a templom egy kápolnájában tartják, vagy adventben más időpontban van. Aki gyerekkel, csendes misére vagy idegen nyelvű misére menne, csak a templom részletezőjén, chipről chipre kattintva tudja meg — a Misék fülön, ahol épp a következő misét választja, nem.

A régi Android app a mise-chipekről egy dialógusban megmutatta ezeket a részleteket. A Flutter app az Android app frissítéseként jelenik meg, és ez az információ a Misék fülön ma hiányzik.

## Solution

A misekártya „település · mise címe" sora kiegészül a **mise jellemzőjével**, úgy, ahogy a miserend.hu adatgondozói leírták: „Pécs · latin nyelven (Mária-kápolnában)". A jellemző szabad szöveg, de a benne szereplő **misetípusok** (Csendes, Gitáros, Diák…) a szó helyett ikonként jelennek meg, és az ikonra bökve a szó az ikon fölött kiíródik; ha a sor nem fér ki, a végén ellipszissel levágódik. Ha a jellemzőt nem sikerül lekérni, a kártya úgy jelenik meg, mint ma — hibajelzés nélkül.

## User Stories

1. Mint hívő, a Misék fülön szeretném látni, ha egy mise csendes, hogy eszerint választhassak.
2. Mint idegen nyelvű hívő, a Misék fülön szeretném látni, ha egy mise latin, angol vagy más nyelven van.
3. Mint hívő, szeretném látni, ha a mise nem a templom főterében, hanem egy kápolnában van, hogy jó helyre menjek.
4. Mint hívő, szeretném látni az időszakos eltérésre utaló megjegyzést (pl. „adventben 6:00"), hogy ne érjen meglepetés.
5. Mint felhasználó, a jellemzőt pontosan úgy szeretném olvasni, ahogy a miserend.hu-n szerepel, hogy ne vesszen el belőle részlet.
6. Mint felhasználó, egy átlagos misénél nem szeretnék felesleges szöveget látni: ha nincs jellemző, a sor ugyanaz, mint ma.
7. Mint felhasználó, a „Római katolikus" felekezeti előtagot nem szeretném a kártyán ismételve látni.
8. Mint felhasználó, szeretném, hogy a kártya magassága ne változzon a jellemző miatt, és a lista egyenletesen görögjön.
9. Mint felhasználó, ha a sor nem fér ki, szeretném, hogy a vége ellipszissel vágódjon le, és a település az elején mindig látszódjon.
10. Mint felhasználó, a Misék fül listáját ugyanolyan gyorsan szeretném látni, mint ma; a jellemzők miatt ne várjak tovább a listára.
11. Mint felhasználó, ha a jellemzők lekérése nem sikerül, a listát jellemzők nélkül, de hibaüzenet nélkül szeretném látni.
12. Mint felhasználó, ha egy templomban két mise van egymás után, mindkét kártyán a saját miséjének jellemzőjét szeretném látni, ne a másikét.
13. Mint görögkatolikus hívő, a „Szent Liturgia" címet továbbra is szeretném látni, és mellette a jellemzőt.

## Implementation Decisions

- **Forrás**: a Misék fül forrása (a `NearbyMasses` végpont) csak a mise fajtáját adja, jellemzőt nem (**ellenőrizve** élő hívással, 2026-09-17). A jellemző csak a `Church` végpont mai `misek` listájának `informacio` szövegében van („Római katolikus Szentmise, Csendes (Mária-kápolnában)"). Ezért a legközelebbi misék betöltője a listán szereplő (legfeljebb 10) templomra **egy** plusz `Church` hívást indít (a meglévő, több azonosítót fogadó hívással), és a mai miséket **templom + kezdési időpont** szerint párosítja a listaelemekhez.
- A plusz hívás **nem tartja vissza a listát**: a lista a mai módon jelenik meg, és a jellemzők a válasz megérkezése után egészítik ki a kártyákat (ugyanúgy, ahogy a bélyegkép sem tartja vissza a listát, spec 0004). Ha a hívás nem sikerül, nincs jelzés, nincs újrapróbálás.
- A `Church` válasz a meglévő szabály szerint a gyorsítótárba is íródik (write-through).
- **Szétbontás**: egy tiszta függvény az esemény fajtáját eldöntő szabály mellett a leírásból kiadja a **jellemzőt**: a felekezeti előtag és a fajta levágása után maradó szöveg, a vezető vesszővel és szóközzel együtt eltávolítva („Római katolikus Szentmise, Csendes" → „Csendes"; „Római katolikus Szentmise latin nyelven" → „latin nyelven"; „Római katolikus Szentmise (adventben 6:00)" → „(adventben 6:00)"; „Római katolikus Szentmise" → nincs). Ugyanazokat a határolókat ismeri (vessző, szóköz, zárójel), mint a fajta szabálya.
- **Megjelenés** (módosítva 2026-09-18): a jellemző a település sora alatt **saját sorba** kerül, részenként külön **sárga buborékba**: a típus ikonnal és a szavával, a nyelv és a zárójeles megjegyzés szövegként. A buborékra bökve tooltip mutatja a teljes szövegét, a kártya bökése nélkül. A buborékok annyi sorba tördelődnek, amennyi kell, és a kártya ennyivel magasabb lesz; csak a kártyánál szélesebb megjegyzés vágódik le ellipszissel a saját buborékában. Egy sor minden kártyán le van foglalva, így a legtöbbször egysoros, a lista után érkező jellemző nem tolja le a kártyákat. *Az eredeti döntés:* a misekártya középső sávjának alsó sora „település · mise címe · jellemző". A spec 0008 szabálya a címre változatlan (ha a cím „Szentmise", nem íródik ki); ekkor „település · jellemző". Egy sor, ellipszissel. A kártya fix magassága nem változik.
- **Misetípus-ikonok** (döntés 2026-09-17, a felhasználó kérésére; **módosítva 2026-09-18**: a típus buborékában az ikon mellett a szó is látszik, bökésre a buborék teljes szövege jelenik meg tooltipben, ld. „Megjelenés”; az alábbi „a szó helyett” és „a sor szövegszínére színezve” megszűnt): a jellemzőt a miserend.hu így rakja össze: „[nyelv nyelven][, típus, típus][ (megjegyzés)]" (miserend.hu forrás: `webapp/classes/eloquent/church.php`, `toAPIArray`). A típusok **zárt készletből** jönnek, a miserend.hu `webapp/i18n/hu.json` szerinti szóval: Családos/mocorgós, Diák, Egyetemista/ifjúsági, Gitáros, Orgonás, Csendes, Énekes — mindegyiknek van ikonja az `assets/types/`-ban. A kártyán a típus a szó **helyett** ikon (a sor szövegszínére színezve, betűméretnyi); bökésre a szó az ikon **fölött** buborékban jelenik meg, és a bökés nem nyitja meg a templomot; képernyőolvasó a szót olvassa. A nyelv, a zárójeles megjegyzés (akkor is, ha típusnév van benne) és az ismeretlen szó szövegként marad. Egy tiszta függvény bontja részekre a jellemzőt: a megjegyzés az első zárójelnél kezdődik, előtte vesszőnként típus vagy szöveg.
- **Párosítás**: templom + kezdési időpont egyezés. Ha egy templomnál ugyanarra az időpontra több `informacio` érkezik, az a jellemző kerül a kártyára, amelynek fajtája megegyezik a listaelem címével; ha így sem egyértelmű, nincs jellemző.

## Testing Decisions

- Jó teszt a külső viselkedést nézi: milyen elemeket ad a betöltő, milyen jellemzővel, és mit ír ki a kártya — nem a párosítás belső lépéseit.
- **A legközelebbi misék betöltője**: hamis HTTP klienssel és élő API-ból mentett fixture-ökkel (`NearbyMasses` + `Church`). Esetek: jellemző párosítása időpont szerint; két mise ugyanabban a templomban; nincs jellemző; a `Church` hívás hibája → elemek jellemző nélkül, hiba nélkül; a lista megjelenése nem vár a jellemzőkre.
- **Szétbontó függvény**: táblázatos teszt az élő mintából vett leírásokkal (vessző, szóköz, zárójel, görögkatolikus előtag, jellemző nélküli).
- **Misekártya widget-teszt**: a sor tartalma címmel és cím nélkül, jellemzővel és anélkül; hosszú szöveg ellipszissel, a kártya magassága nem változik nagyobb betűmérettel és ikonokkal sem; a típus ikonként jelenik meg a szó helyett, és az ikonra bökve a szó fölötte látszik, a kártya bökése nélkül.
- **Jellemző szétbontása részekre**: táblázatos teszt (típusok, nyelv, megjegyzés, típusnév a megjegyzésben, ismeretlen szó).
- Előzmény: a legközelebbi misék betöltőjének, a mise fajtáját eldöntő szabálynak és a misekártyának a meglévő tesztjei.

## Out of Scope

- Jellemzők a **templomkártya** chipjein (Templomok fül, térképi kártya): nincs rájuk hely.
- A templom-részletező chipjei: azok alsó lapja már ma is a teljes leírást mutatja.
- Szűrés jellemzőre vagy misetípusra.
- Felekezet- és rítusikonok (`greek_catholic`, `roman_catholic`, `traditional`): a cím már mondja.
- Mise-szintű nyelv, periódus („csak páros heteken"), időszak: az API v4 ezeket nem adja.
- Jellemző a Részletes kereső találatain (spec 0010).

## Further Notes

- Élő minta (2026-09-17, Budapest belváros, 20 templom mai miséi): „Római katolikus Szentmise, Csendes", „Római katolikus Szentmise latin nyelven", „Római katolikus Szentmise, Csendes (Mária-kápolnában)", „Római katolikus Szentmise (adventben 6:00)". A 34 miséből 28 jellemző nélküli.
- Fogalmak: CONTEXT.md, „Mise jellemzője", „Misekártya vs. templomkártya", „Mise vs. egyéb liturgikus esemény", „Legközelebbi misék". Kártya elrendezése: spec 0008.
