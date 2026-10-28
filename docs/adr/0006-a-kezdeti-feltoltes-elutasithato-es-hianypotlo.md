---
status: accepted
---

# A kezdeti feltöltés egyszer elutasítható, és utólag hiánypótlóként futtatható

Az ADR-0003 úgy számolt, hogy a kezdeti feltöltés minden első indításkor lefut. Az App Store a 3.0.0 (40) iOS buildet a 4.2.3(ii) pont alapján visszautasította: egy működéshez szükséges letöltés előtt közölni kell a méretét, és a felhasználónak választania kell. Az export ma ~22 MB.

Döntés: a kezdeti feltöltést az app **első induláskor, a méret megadásával felajánlja**, és a felhasználó **elutasíthatja**. Az elutasítás **tudatos választás a korlátozott működés mellett**: az app többé nem ajánlja fel, és nem is győzködi. Három feltevésre épül: (1) a felajánlás elég információt ad ahhoz, hogy a felhasználó tudja, mit választ; (2) ha meggondolja magát, a **Névjegyen** maga indíthatja el a pótlást — egyetlen helyen, az első sikeres lefutásig; (3) az app alapfunkciói az API-ra épülnek (a Közeli templomok, a Misék fül, a keresés és a részletező online e nélkül is működik), így aki elég sokáig használja online, annak a fontos templomok és misék idővel a **helyi gyorsítótárba** kerülnek.

Döntésnek a „Most nem” és a letöltés megszakítása (Mégse) számít. Ha a felajánlás el sem jutott a felhasználóhoz (a méretlekérdezés 5 s alatt nem sikerült), vagy a letöltés, illetve az import hibára futott vagy az app közben bezárult, a következő induláskor újra felajánljuk: ezekben az esetekben a felhasználó nem döntött a letöltés ellen.

Elutasítás után a képernyők, amelyek csak a gyorsítótárból dolgoznak (keresési javaslatok, Részletes kereső, Térkép), **nem ajánlják fel a letöltést**. Ha nem tudnak mit mutatni, csak megmondják, mi lehet az ok, és hol indítható a letöltés.

A kezdeti feltöltés **csak a hiányt pótolja**: hiányzó templomot beír, meglévő templomnak csak az üres mezőit tölti ki, misét csak olyan templom–nap párra ír, amelyre a gyorsítótárban még nincs alkalom. Az API-adat így mindig erősebb az exportnál, és a futás idempotens: megszakadás után elölről indul, a félbemaradt állapot vizsgálata nélkül. A letöltött fájl a futás végén vagy megszakadásakor törlődik.

## Considered Options

- **Minden olyan induláskor újra felajánljuk, amikor a szerver elérhető, és a hiányos képernyőkön egy letöltés-gombos sáv is áll, az első sikeres lefutásig.** Ez volt a spec 0015 első változata. Elvetve: a felhasználó egyszer már döntött, és a folyamatos felajánlás ezt a döntést nem tiszteli; a hiányt idővel az API-használat is pótolja.
- **Az utólagos futás felülírja a gyorsítótárat.** Elvetve: a felhasználó addig az API-ból friss adatot gyűjtött; egy export felülírná a templomok javított adatait és a már API-ból ismert miserendet.
- **Megszakadt futás folytatása.** Elvetve: a hiánypótló, idempotens import elölről futtatva ugyanoda jut, az állapot követése pedig felesleges bonyolítás.
- **A keresési javaslatok az API `search` végpontjából.** Elvetve: 3–5 s válaszidő, a közismert névben nem keres, értelmezhetetlen szóra fix listát ad (spec 0005).
- **Az export beépítése az app csomagjába.** Nem választottuk: +22 MB a telepítőben, és a beépített miserend a kiadás napjától öregszik.

## Consequences

- Aki elutasította, annak a keresési javaslatok, a Részletes kereső és a Térkép tartósan csak a közeli és a már megnézett templomokat ismeri. Ez elfogadott: ezt választotta, és a pótlás a Névjegyen elérhető.
- Elutasítás után offline az app nem tud mit mutatni; minden képernyőn a meglévő offline figyelmeztetés áll. Ez elfogadott: az app eleve online-ra épül.
- A "Kilépés" gomb megszűnik (iOS-en `SystemNavigator.pop()` hatástalan), és a régi "korábban letöltött adatokkal folytatjuk" tartalék is.
