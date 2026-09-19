# Névjegy és impresszum

> Háttér és források: [docs/MENU-ES-IMPRESSZUM.md](../MENU-ES-IMPRESSZUM.md) (kutatás és a karbantartó 2026-09-18-i döntései)

## Problem Statement

Az alsó navigáció negyedik pontja „Menü” volt, hamburger ikonnal. A név túl általános, és az ikon oldalsó menüt (drawer) sejtet, ami az appban nincs. Az appban nem volt impresszum sem: nem derült ki belőle, ki fejleszti, és hol a forráskód.

## Solution

- A pont neve **„Névjegy”**, ikonja ⓘ (`Icons.info_outline`). Viselkedése a régi: nem fül, `Navigator.push`-sal saját oldalt nyit, a kiválasztott fül nem változik (spec 0009, „Visszajelzés: belépési pont”).
- A **„Visszajelzés”** (spec 0009, „Visszajelzés: a levél”) **lebegő gomb** a képernyő alján, középen (`FloatingActionButton.extended`, `centerFloat`): görgetés nélkül, minden telefonon látszik. A lista alján annyi hely marad, hogy az utolsó csempe is kigördülhessen alóla.
- Az impresszum **nem külön oldal**: a Névjegy szakaszai. A Névjegy oldal fentről lefelé:
  1. **„Mai templom ajánlatunk”** kártya (spec 0009, „Menü oldal”), változatlanul.
  2. **Fejlesztő:** „Az alkalmazást a Szent József Hackathon fejleszti.”, alatta „Verzió: x.y.z (build)”.
  3. **Forráskód:** „Ha fejlesztenél valamit az alkalmazáson, itt találod a forráskódját:”, link a [github.com/szanatil/Miserend-Flutter](https://github.com/szanatil/Miserend-Flutter) repóra.
  4. **miserend.hu** csempe („A miserend webes változata”), a böngészőben nyílik meg (spec 0009, „Menü oldal”).
- Kimarad a külön Verzió csempe: a verzió a Fejlesztő alá került.
- Kimarad a **Kiadó** csempe (a Rendtartomány, jezsuita.hu, 1% a Jézus Társasága Alapítványnak adószámmal): a karbantartó 2026-09-19-én törölte.

## Implementation Decisions

- A `lib/menu/` könyvtár `lib/about/` lett, a `MenuPage` `AboutPage`.
- A szakaszok `SectionCard`-ok, a lap a régi szürke hátterén.
- A külső linkek a `launchExternal`-on át nyílnak; az indító injektálható (K1).

## Testing Decisions

- **Névjegy oldal** (widget teszt, hamis link-indítóval, T6):
  - a cím „Névjegy”; a szakaszok sorrendje: Mai templom ajánlatunk, Fejlesztő, Forráskód, miserend.hu; Kiadó csempe nincs;
  - kis telefonon (320×568) a Visszajelzés gomb görgetés nélkül a képernyő alsó felén látszik, és a lista végére görgetve az utolsó csempe nem marad alatta;
  - keskeny képernyőn a linkek nem csordulnak túl;
  - a GitHub-link és a miserend.hu csempe a helyes URL-t nyitja;
  - a fejlesztő mellett a verzió látszik;
  - a Visszajelzés gomb és a templomajánló a korábbi tesztjeivel.

## Out of Scope

- **Felhasznált licencek** oldala (`showLicensePage`): a karbantartó döntése szerint nem kell.
- **Adatkezelési tájékoztató** (link a miserend.hu/gdpr oldalra vagy saját tájékoztató): nyitott kérdés.
- **LICENSE fájl a repóban.** A „nyílt forráskódú” jelzőhez a repónak licenc kell; ez a karbantartó döntése, addig az oldal nem nevezi nyílt forráskódúnak az appot.
- **A pont áthelyezése** (valódi fül vagy AppBar-ikon), a [#52](https://github.com/szanatil/Miserend-Flutter/issues/52)-vel együtt.
