# Névjegy és impresszum

> Háttér és források: [docs/MENU-ES-IMPRESSZUM.md](../MENU-ES-IMPRESSZUM.md) (kutatás és a karbantartó 2026-09-18-i döntései)

## Problem Statement

Az alsó navigáció negyedik pontja „Menü” volt, hamburger ikonnal. A név túl általános, és az ikon oldalsó menüt (drawer) sejtet, ami az appban nincs. Az appban nem volt impresszum sem: nem derült ki belőle, ki adja ki és ki fejleszti, hogyan lehet támogatni, és hol a forráskód.

## Solution

- A pont neve **„Névjegy”**, ikonja ⓘ (`Icons.info_outline`). Viselkedése a régi: nem fül, `Navigator.push`-sal saját oldalt nyit, a kiválasztott fül nem változik (spec 0009, „Visszajelzés: belépési pont”).
- Az impresszum **nem külön oldal**: a Névjegy szakaszai. A Névjegy oldal fentről lefelé:
  1. **„Visszajelzés”** gomb (spec 0009, „Visszajelzés: a levél”).
  2. **„Mai templom ajánlatunk”** kártya (spec 0009, „Menü oldal”), változatlanul.
  3. **Kiadó:** Jézus Társasága Magyarországi Rendtartománya, 1085 Budapest, Horánszky u. 20., link: jezsuita.hu. Alatta a támogatás: „Ha támogatni szeretnéd munkánkat, ajánld fel adód 1%-át a Jézus Társasága Alapítványnak.” Adószám: **18064333-2-42**, másolás gombbal, „Adószám vágólapra másolva” SnackBarral.
  4. **Fejlesztő:** „Az alkalmazást a Szent József Hackathon fejleszti.”, alatta „Verzió: x.y.z (build)”.
  5. **Forráskód:** „Ha fejlesztenél valamit az alkalmazáson, itt találod a forráskódját:”, link a [github.com/szanatil/Miserend-Flutter](https://github.com/szanatil/Miserend-Flutter) repóra.
- Kimarad a korábbi miserend.hu csempe és a külön Verzió csempe (a verzió a Fejlesztő alá került).

A kiadó (Rendtartomány) és az 1%-os kedvezményezett (Alapítvány) két külön szervezet, két adószámmal. Az oldalon csak az Alapítványé szerepel, és csak az őt megnevező mondat mellett (kutatás, §2.5).

## Implementation Decisions

- A `lib/menu/` könyvtár `lib/about/` lett, a `MenuPage` `AboutPage`.
- A szakaszok `SectionCard`-ok, a lap a régi szürke hátterén.
- A külső linkek a `launchExternal`-on át nyílnak; az indító injektálható (K1).

## Testing Decisions

- **Névjegy oldal** (widget teszt, hamis link-indítóval, T6):
  - a cím „Névjegy”; a szakaszok sorrendje: Visszajelzés, Mai templom ajánlatunk, Kiadó, Fejlesztő, Forráskód;
  - megjelenik a kiadó neve és címe; a jezsuita.hu és a GitHub-link a helyes URL-t nyitja;
  - a fejlesztő mellett a verzió látszik;
  - a másolás gomb a vágólapra teszi az adószámot, és SnackBar jelzi;
  - a Visszajelzés gomb és a templomajánló a korábbi tesztjeivel.

## Out of Scope

- **Felhasznált licencek** oldala (`showLicensePage`): a karbantartó döntése szerint nem kell.
- **Adatkezelési tájékoztató** (link a miserend.hu/gdpr oldalra vagy saját tájékoztató): nyitott kérdés.
- **LICENSE fájl a repóban.** A „nyílt forráskódú” jelzőhez a repónak licenc kell; ez a karbantartó döntése, addig az oldal nem nevezi nyílt forráskódúnak az appot.
- **A pont áthelyezése** (valódi fül vagy AppBar-ikon), a [#52](https://github.com/szanatil/Miserend-Flutter/issues/52)-vel együtt.
