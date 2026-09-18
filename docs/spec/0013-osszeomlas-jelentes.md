# Összeomlás-jelentés

> Tracker: [szanatil/Miserend-Flutter#38](https://github.com/szanatil/Miserend-Flutter/issues/38)

## Problem Statement

Ha az app a felhasználónál összeomlik vagy váratlan hibába fut, a fejlesztők erről csak akkor tudnak, ha a felhasználó **visszajelzést** ír — ami ritkán történik meg, és ritkán tartalmazza, mi történt. A Flutter app az Android app frissítéseként egyszerre sok, sokféle készüléken futó felhasználóhoz jut el; az átírás gyerekbetegségei így rejtve maradnának.

A régi Android app Firebase Crashlyticsszel jelentette az összeomlásokat. Az a Firebase-projekt nem a mostani fejlesztőké.

## Solution

Az app a **release buildben** a nem kezelt hibákat és az összeomlásokat automatikusan jelenti a Firebase Crashlyticsnek, egy új, a fejlesztők kezelésében lévő Firebase-projektbe, Androidon és iOS-en. A jelentés nem tartalmaz személyes adatot és helyzetet. A felhasználónak nincs teendője, a Névjegy oldalon nincs kapcsoló; az adatkezelési tájékoztató megemlíti.

## User Stories

1. Mint fejlesztő, értesülni szeretnék minden összeomlásról, amely a felhasználóknál történik, hogy javíthassam.
2. Mint fejlesztő, a nem kezelt Flutter-hibákról (pl. build- vagy layout-hiba) is jelentést szeretnék, nem csak a teljes összeomlásról.
3. Mint fejlesztő, az aszinkron, sehol el nem kapott hibákról is jelentést szeretnék.
4. Mint fejlesztő, a natív (Android, iOS) összeomlásokról is jelentést szeretnék.
5. Mint fejlesztő, látni szeretném, melyik app-verzión és milyen operációs rendszeren történt a hiba, hogy tudjam, melyik kiadást érinti.
6. Mint fejlesztő, olvasható hívási láncot szeretnék, obfuszkált build esetén is.
7. Mint fejlesztő, fejlesztés közben (debug build) nem szeretném a saját hibáimmal teleszemetelni a jelentéseket.
8. Mint fejlesztő, a tesztek futása közben nem szeretnék Firebase-függőséget.
9. Mint felhasználó, nem szeretném, hogy a hibajelentés az adataimat (e-mail, helyzet, kedvencek, beírt szöveg) elküldje.
10. Mint felhasználó, nem szeretném, hogy a hibajelentés miatt lassabban induljon az app.
11. Mint felhasználó, ha nincs kapcsolat, azt szeretném, hogy az app ugyanúgy működjön; a jelentés később menjen el.
12. Mint felhasználó, az adatkezelési tájékoztatóból szeretném megtudni, hogy az app hibajelentést küld, és mit tartalmaz.
13. Mint fejlesztő, a várt, kezelt hibákat (Nincs kapcsolat, Szerverhiba) nem szeretném összeomlásként látni: ezek nem az app hibái.

## Implementation Decisions

- **Előfeltétel (emberi lépés)**: új Firebase-projekt létrehozása, az Android és az iOS app regisztrálása (az Android csomagazonosító a Play Áruház-azonosság nyitott kérdésétől függ, ld. Further Notes), a konfigurációs fájlok beszerzése. A spec többi része ezek nélkül is megírható és tesztelhető.
- Csomagok: `firebase_core` és `firebase_crashlytics` (5.x, ellenőrizve pub.dev, 2026-09-17), a FlutterFire által generált platformkonfigurációval.
- **Összeomlás-jelentő interfész**: egy kis modul, amelyet az app indítása kap meg. Két dolgot tud: nem végzetes hibát jelenteni, végzetes hibát jelenteni. Két megvalósítása van: a Crashlytics-es és egy semmit sem tevő. A `main` a release buildben a Crashlytics-est, egyébként a semmit sem tevőt kapja.
- **Bekötés**: a Flutter keretrendszer hibakezelője (`FlutterError.onError`) végzetes hibaként, a platform-dispatcher nem kezelt aszinkron hibái szintén végzetesként jutnak el a jelentőhöz. A natív összeomlásokat a Crashlytics maga kezeli.
- **Mi nem kerül bele**: felhasználói azonosító, e-mail cím, helyzet, keresési szöveg, templomazonosító. Egyedi kulcsokat, naplósorokat a jelentő nem kap.
- **Kezelt hibák**: a Nincs kapcsolat és a Szerverhiba az API-rétegben kezelt állapot, nem kerül a jelentőhöz.
- **Obfuszkáció**: ha a release build obfuszkált, a szimbólumfájlok feltöltése a kiadási folyamat része.
- Az indítás nem vár a Firebase-re tovább, mint amennyi az inicializáláshoz szükséges; ha az inicializálás hibára fut, az app jelentés nélkül indul tovább.
- Az **adatkezelési tájékoztató** szövegének bővítése a kiadás feltétele, de nem kódfeladat.

## Testing Decisions

- Jó teszt azt nézi, hogy **egy hiba eljut-e a jelentőhöz**, és hogy debug buildben nem — nem a Firebase SDK-t.
- **Határ: az app indítása** a jelentő interfészével, hamis jelentővel. Esetek: egy widget build-hibája a hamis jelentőhöz jut; egy el nem kapott aszinkron hiba a hamis jelentőhöz jut; nem release buildben a semmit sem tevő jelentő kerül be; a Nincs kapcsolat és a Szerverhiba nem jut a jelentőhöz.
- A Crashlytics-es megvalósítás vékony adapter, nem kap egységtesztet; a működését a Firebase-konzolban egy szándékos teszt-összeomlással ellenőrizzük a release build első kiadása előtt.
- Előzmény: az app indításának meglévő tesztje, a hamis szolgáltatások (visszajelzés-indító, kedvencek) mintája.

## Out of Scope

- Analitika, képernyőkövetés (Firebase Analytics).
- Hozzájárulás-kérés, ki-/bekapcsoló a Névjegy oldalon.
- Teljesítménymérés (Firebase Performance), távoli konfiguráció.
- A régi Android app Firebase-projektjének átvétele.
- Az adatkezelési tájékoztató szövegének megírása.

## Further Notes

- A Firebase Android-app regisztrációja a csomagazonosítóhoz kötött. A Play Áruház-azonosság (a régi `com.frama.miserend.hu` átvétele vagy a mai `com.frama.miserend.hu.miserend` megtartása) nyitott kérdés; ha később változik az azonosító, az Android appot a Firebase-projektben újra kell regisztrálni, és a konfigurációs fájlt cserélni.
- Az emberi lépésekhez a `/wizard` skill készíthet végigvezető szkriptet.
