---
status: accepted
---

# Offline működés: a helyi gyorsítótár mint egyetlen offline forrás

Az ADR-0002 az API v4-et tette tekintélyelvű adatforrássá, és kimondta, hogy a SQLite exportot az onboardingon túl nem töltjük le újra. A kód ennek ellenére 7 naponként felajánlotta a teljes export újraletöltését, mert a még át nem állított képernyők (Keresés, Térkép, Közeli templomok, Kedvencek) ebből olvastak — és ez adta az app offline működését is. A v4 API-ban nincs tömeges szinkronra alkalmas végpont (`Church` legfeljebb 100 ismert azonosító, `Search` kötelező keresőszóval, `NearbyMasses` legfeljebb 100 elem, `Updated` csak igen/nem, `Table` automatizált használatra nem ajánlott), így az offline adat nem tartható frissen API-ból a teljes adatkészletre.

Döntés: az app **egyetlen offline adatforrása a helyi gyorsítótár**. A SQLite exportot csak az első indításkor, a **kezdeti feltöltéshez** töltjük le (a dokumentált `https://miserend.hu/api/v4/sqlite` végpontról), a heti újraletöltés megszűnik. A kezdeti feltöltés minden templomot és a telepítéstől számított **30 nap** miséit tölti a gyorsítótárba — egy soha többé nem kapcsolódó készülék ezt az állapotot látja. A listaképernyők (Keresés, Közeli templomok, Kedvencek, Térkép) **online is a gyorsítótárból rajzolnak**: a lista azonnal megjelenik, a háttérben futó API-hívás válasza soronként a gyorsítótárba íródik (új, javított és megszűnt templomok is így jutnak el a készülékre), és a lista ezután egyszer újraolvassa a gyorsítótárat. Ha az API nem ad választ (15 s-os időkorláton belül), a képernyő a gyorsítótár állapotánál marad, és két, egymástól megkülönböztetett állapotot jelez (ld. [CONTEXT.md](../../CONTEXT.md)): **Nincs kapcsolat** esetén (i) jelzést a misék mellett, **Szerverhiba** esetén eltérő színt és (i) jelzést. A kedvenc templomok 20 napos miserendje alkalmazásinduláskor, ha van kapcsolat, naponta legfeljebb egyszer előre frissül.

## Considered Options

- **A SQLite export rendszeres (heti) újraletöltése offline forrásként.** Elvetve: ellentmond az ADR-0002-nek, és a régi séma évszám nélküli (`HHNN`) dátumai miatt egy frissítés nélkül maradt export fél év után csendben rossz napra teszi a miséket. A megszüntetés az átállás befejezése előtt, azonnal történik (explicit felhasználói döntés) — a még exportból olvasó képernyők addig egy lejárati védelmet kapnak: 182 napnál régebbi exportból nem mutatnak misét.
- **A teljes export (182 nap) betöltése a kezdeti feltöltésben.** Elvetve: ~280 ezer mise-sor egyszeri importja telefonon, miközben a részletező oldal 20 napot mutat; a 30 nap ezt tartalékkal fedi, az import költségének kb. hatodáért.
- **Az "adatkapcsolat nem engedélyezett az appnak" állapot külön felismerése.** Elvetve ebben a fázisban: Androidon nincs rá megbízható nyilvános API, a gyártói alkalmazásonkénti tiltás kívülről ugyanúgy néz ki, mint a lefedettség hiánya. Az app ahhoz köti a jelzést, amit lát (a kérés eljutott-e a szerverig); iOS-re egy célzott szöveg később ráépíthető a fogalmak változtatása nélkül.
- **"Utoljára frissítve: {dátum}" felirat minden gyorsítótárból mutatott miserenden.** Elvetve UX-okokból: az adat kora koppintásra, az (i) tájékoztatóban érhető el.
- **Online az élő API válasza a lista, a gyorsítótár csak hiba esetén.** Elvetve: a v4 válaszideje 3–5 s, így minden lista ennyit pörögne akkor is, ha a gyorsítótárban jó adat van, gyenge lefedettségnél pedig az időkorlátig semmit nem mutatna. A `Search` végpont ráadásul rosszabbul keres, mint a helyi lekérdezés (az `ismertnev`-ben nem keres, értelmezhetetlen szóra fix listát ad), és a gyorsítótár a kezdeti feltöltés óta minden templomot tartalmaz. A választott változat a templom-részletező (spec 0003) és az ADR-0002 „stale-while-revalidate" szabályával is egyezik; ára, hogy a lista az API-válasz után egyszer módosulhat.
- **Térképi markerek élő `NearBy` hívásból.** Elvetve: a 100-as korlát sűrű területen hiányos térképet adna; a markerek mindig a gyorsítótárból jönnek.

## Consequences

- A **legközelebbi misék** és a **gyóntatás** jelzése továbbra sem jön a gyorsítótárból (spec 0004, ADR-0002): ezek offline nem működnek, szándékosan.
- A gyorsítótárban lévő templom-adat csak API-válasz hatására változik. Egy soha meg nem nyitott, keresésben/közelben fel nem bukkant templom javított koordinátája vagy megszűnése nem jut el a készülékre; a `Church` válasz `hianyzo` listájában szereplő templom a miséivel együtt törlődik.
- Az API-kliensnek szét kell választania a hálózati hibát (Nincs kapcsolat), a hibás választ (Szerverhiba) és a sikeres, de üres választ ("nincs mise") — ma mindhárom `null` vagy üres lista.
- A telepítés 30. napja után a soha nem kapcsolódó készüléken a miserend üres; ezt az "Nincs adat erről a napról" szöveg és az (i) tájékoztató fedi.
