# Névjegy és Impresszum

> Háttér és források: [docs/MENU-ES-IMPRESSZUM.md](../MENU-ES-IMPRESSZUM.md) (kutatás és a karbantartó 2026-09-18-i döntései)

## Problem Statement

Az alsó navigáció negyedik pontja „Menü” volt, hamburger ikonnal. A név túl általános, és az ikon oldalsó menüt (drawer) sejtet, ami az appban nincs. Az appban nem volt Impresszum sem: nem derült ki belőle, ki adja ki és ki fejleszti, hogyan lehet támogatni, hol a forráskód, és milyen licencű csomagokra épül. A licencek oldala a korábbi „Az appról” oldal törlése óta nem volt elérhető.

## Solution

- A pont neve **„Névjegy”**, ikonja ⓘ (`Icons.info_outline`). Viselkedése a régi: nem fül, `Navigator.push`-sal saját oldalt nyit, a kiválasztott fül nem változik (spec 0009, „Visszajelzés: belépési pont”).
- A Névjegy oldal tartalma a Menü oldalé (spec 0009, „Menü oldal”), a „Mai templom ajánlatunk” marad. A Verzió után új **Impresszum** csempe nyitja az Impresszum oldalt.
- Az **Impresszum** oldal, fentről lefelé:
  - **Kiadó:** Jézus Társasága Magyarországi Rendtartománya, 1085 Budapest, Horánszky u. 20., link: jezsuita.hu.
  - **Fejlesztő:** a Szent József Hackathon.
  - **Támogatás:** „Ha támogatni szeretnéd munkánkat, ajánld fel adód 1%-át a Jézus Társasága Alapítványnak.” Adószám: **18064333-2-42**, másolás gombbal, „Adószám vágólapra másolva” SnackBarral.
  - **Forráskód:** „Ha fejlesztenél valamit az alkalmazáson, itt találod a forráskódját”, link a [github.com/szanatil/Miserend-Flutter](https://github.com/szanatil/Miserend-Flutter) repóra.
  - **Felhasznált licencek:** a Flutter beépített licencoldala (`showLicensePage`).

A kiadó (Rendtartomány) és az 1%-os kedvezményezett (Alapítvány) két külön szervezet, két adószámmal. Az oldalon csak az Alapítványé szerepel, és csak az őt megnevező mondat mellett (kutatás, §2.5).

## Implementation Decisions

- A `lib/menu/` könyvtár `lib/about/` lett, a `MenuPage` `AboutPage`. Az Impresszum: `lib/about/impressum_page.dart`, `ImpressumPage`.
- Az oldal a Névjegy oldal külsejét követi: lila AppBar, szürke háttér, `SectionCard` szakaszok.
- A külső linkek a `launchExternal`-on át nyílnak; az indító injektálható (K1), a Névjegy oldal a sajátját adja tovább.

## Testing Decisions

- **Impresszum oldal** (widget teszt, hamis link-indítóval, T6): megjelenik a kiadó neve és címe, és a fejlesztő; a jezsuita.hu és a GitHub-link a helyes URL-t nyitja; a másolás gomb a vágólapra teszi az adószámot, és SnackBar jelzi; a licencek csempe a `LicensePage`-et nyitja.
- **Névjegy oldal:** a cím „Névjegy”; az Impresszum csempe az Impresszum oldalt nyitja.

## Out of Scope

- **Adatkezelési tájékoztató** (link a miserend.hu/gdpr oldalra vagy saját tájékoztató): nyitott kérdés.
- **LICENSE fájl a repóban.** A „nyílt forráskódú” jelzőhez a repónak licenc kell; ez a karbantartó döntése, addig az oldal nem nevezi nyílt forráskódúnak az appot.
- **A pont áthelyezése** (valódi fül vagy AppBar-ikon), a [#52](https://github.com/szanatil/Miserend-Flutter/issues/52)-vel együtt.
