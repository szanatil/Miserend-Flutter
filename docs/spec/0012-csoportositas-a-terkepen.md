# Csoportosítás a térképen

> Tracker: [szanatil/Miserend-Flutter#37](https://github.com/szanatil/Miserend-Flutter/issues/37)

## Problem Statement

A Térkép fül a 12-es zoom alatt minden templomot apró pöttyként mutat, fölötte tűként (spec 0006). Ország- és megyenézetben a pöttyök egymásra folynak, és nem mondják meg, hol hány templom van; a pötty túl kicsi ahhoz, hogy rá lehessen koppintani. 12-es zoom fölött egy sűrű belvárosban a tűk egymásra csúsznak, és nehéz eltalálni a keresettet. Két, ugyanazon a ponton álló templom (pl. templom és kápolnája) egyik zoomon sem választható szét.

A régi Android app csoportosította a jelölőket, és a csoportra koppintva ráközelített. A Flutter app az Android app frissítéseként jelenik meg.

## Solution

A térkép **minden zoomszinten csoportosít**, amíg a tűk átfednék egymást: a csoport egy számmal ellátott kör, amely megmondja, hány templom van benne. A csoportra koppintva a térkép rá közelít, amíg a csoport szét nem bomlik. A pöttyös nézet megszűnik. A **kiválasztott templom** tűje mindig külön marad, csoportba nem olvad. Az egy ponton álló templomok a legnagyobb zoomon a csoportra koppintva **körben szétnyílnak**, és egyenként koppinthatók.

## User Stories

1. Mint felhasználó, országnézetben szeretném látni, merre hány templom van, hogy tudjam, hová közelítsek.
2. Mint felhasználó, egy csoportra koppintva szeretnék rá közelíteni, hogy ne kelljen csípéssel keresgélnem.
3. Mint felhasználó, egy csoport számából szeretném tudni, hány templom van benne.
4. Mint felhasználó, egy sűrű belvárosban is különálló, koppintható tűket szeretnék látni, ne egymásra csúszottakat.
5. Mint felhasználó, ha a tűk már nem fednék egymást, egyenként szeretném látni őket, csoport nélkül.
6. Mint felhasználó, egy templomot kiválasztva szeretném, hogy a tűje kiemelve, külön maradjon akkor is, ha kizoomolok.
7. Mint felhasználó, a kiválasztott templom kártyája és tűje ne veszítse el egymást zoomolás közben.
8. Mint felhasználó, ha két templom ugyanazon a ponton áll, a legnagyobb zoomon a csoportra koppintva szét szeretném nyitni őket, és bármelyiket kiválasztani.
9. Mint felhasználó, a szétnyílt tűk közül egyre koppintva a templomkártyát szeretném látni, ahogy egy egyszerű tűnél.
10. Mint felhasználó, a térkép üres részére koppintva szeretném, hogy a szétnyílt tűk visszacsukódjanak.
11. Mint felhasználó, a saját helyzetem jelölését soha nem szeretném csoportba olvadva látni.
12. Mint felhasználó, szeretném, hogy a térkép az összes (~5000) templommal is folyamatosan mozogjon zoomolás és görgetés közben.
13. Mint felhasználó, a csoportok színét és formáját az app többi részéhez illőnek szeretném látni.
14. Mint felhasználó, a csoport szövegét nagy betűmérettel is olvashatónak szeretném látni.

## Implementation Decisions

- A térképi widget (`MiserendMap`) jelölő-rétege csoportosító rétegre cserélődik; a widget interfésze (jelölők, kiválasztott jelölő, saját helyzet, koppintás) **nem változik**, így a Térkép fül és a templom-részletező kis térképe változatlanul használja.
- Csomag: `flutter_map_marker_cluster` (a 8.2.x a használt `flutter_map` 8-as verziójához készült; ellenőrizve pub.dev, 2026-09-17). Ha a csomag az alábbiak valamelyikét nem tudja, saját csoportosítás a tartalék.
- **Pöttyös nézet megszűnik**: a 12-es küszöb (spec 0006, „Sűrűség-küszöb") és a pötty-jelölő kikerül. Minden zoomon tűk vagy csoportok.
- **Csoportosítás**: a csoport akkor bomlik szét, amikor a tűk már nem fednék egymást (a tű mérete szerinti sugár). A legnagyobb zoomon is egyben maradó csoport koppintásra **szétnyílik** (spiderfy); a térképre koppintva visszacsukódik.
- **Csoport megjelenése**: kör az app lila színével, fehér számmal; nagyobb számnál nagyobb kör, néhány lépcsőben.
- **Koppintás a csoportra**: a kamera a csoport elemeit befoglaló területre közelít.
- **Kiválasztott templom**: a csoportosításból kimarad, saját, kiemelt tűként külön rétegben rajzolódik (a mai viselkedés folytatása: „a kiválasztott tű minden zoomon megmarad").
- **Saját helyzet**: külön réteg, soha nem csoportosul.
- **A kis térkép** a templom-részletezőn egyetlen tűt mutat; ott a csoportosítás nem látható, de nem is okozhat eltérést.

### Megvalósítás közben pontosítva

- A `flutter_map_marker_cluster` a `latlong2` 0.9-es sorát kéri; az app `^0.10.1`-ről `^0.9.1`-re lépett vissza. A 0.10 újdonságaiból (`hashCode`, `isValid`) az app semmit nem használ.
- **Legnagyobb zoom**: a térkép a csempék határáig, **19**-ig közelít (előtte nem volt határ, 19 fölött csak nagyított csempék jöttek). Így a „legnagyobb zoom", ahol a szétnyílás történik, egyértelmű.
- **Szétnyílás**: az a csoport nyílik szét, amely a legnagyobb zoomon sem bomlana szét — ez nem csak 19-es zoomon lehet. Egy elszigetelt, egy ponton álló pár már távolabbról is koppintásra szétnyílik, mert a ráközelítés semmin nem változtatna.
- **Visszacsukás a térképre koppintva**: a csomag ezt nem kínálja, ezért a csoport-réteg ilyenkor újraépül. Csak akkor, ha csoportra koppintottak, és azóta nem zoomoltak kézzel (az magától visszacsukja). A csoportra koppintás kameramozgása nem számít: csípés után a térkép előbb egész zoomra lép, és csak utána nyílik szét a csoport.
- **Sugár**: 40 px, egy tű magassága. **Kör**: 36 / 42 / 48 / 56 px (1+ / 10+ / 100+ / 1000+ templom), nagy betűméretnél legfeljebb 1,6-szorosra nő, azon túl a szám zsugorodik a körbe.

## Testing Decisions

- Jó teszt a térkép **látható viselkedését** nézi: adott jelölőkre és zoomra hány csoport és tű látszik, milyen számmal, és mi történik koppintásra — nem a csomag belső osztályait.
- **Határ: a térképi widget**, widget-tesztben, ahogy a meglévő térképtesztek. Esetek: sok közeli jelölő kis zoomon egy csoport a helyes számmal; nagy zoomon különálló tűk; csoportra koppintva nő a zoom; egy ponton álló két templom legnagyobb zoomon szétnyílik, és az egyik koppintva kiválasztható; a kiválasztott jelölő kis zoomon is külön tűként látszik, és nem számít bele a csoportba; a saját helyzet jelölése látszik és nem csoportosul; a pötty-jelölő nincs többé.
- A Térkép fül meglévő tesztjei (kártya megnyitása tűre koppintva, helyzetem gomb) változatlanul zöldek maradnak.
- Előzmény: a térképi widget és a Térkép fül meglévő tesztjei.

## Out of Scope

- A tűk kinézetének, a templomkártyának vagy a helyzetem gombnak a változása.
- Szűrés a térképen (pl. csak kedvencek), keresés a térképről.
- A csoport tartalmának listás megjelenítése koppintásra.
- Google Maps vagy más csempeszolgáltató (ADR-0001).

## Further Notes

- Ez a spec felülírja a spec 0006 „Sűrűség-küszöb" szakaszát.
- Az Android app csoportjai lila háttérrel és egyedi tűikonnal jelentek meg; a csoportra koppintva a csoport elemeire közelített (`docs/ANDROID-OSSZEHASONLITAS.md`, „Térképi csoportosítás").
