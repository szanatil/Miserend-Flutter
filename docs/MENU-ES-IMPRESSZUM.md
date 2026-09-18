# A „Menü” pont elnevezése és az Impresszum tartalma: kutatási jegyzet

Ez a jegyzet két kérdés forrásait gyűjti össze. Az egyik: mi legyen a „Menü” alsó navigációs pont neve, vagy kell-e egyáltalán alsó navigációs pont. A másik: mi kerüljön ennek az appnak az Impresszumába. A jegyzet nem dönt. A döntést igénylő pontok a végén, a „Nyitott kérdések” alatt vannak.

Vizsgált állapot: `szanatil/Miserend-Flutter`, `main`, commit `5f27cd1fdc21f177bd3da0f4cc840b712d9ba201` (2026-09-18). A külső oldalakat 2026-09-18-án olvastam. A GitHub-hivatkozások a lent megadott commitokra vannak rögzítve.

---

## 1. Mi van ma az appban

### 1.1 A „Menü” pont

- Az alsó navigáció negyedik eleme `Icons.menu` (hamburger) ikonnal és „Menü” felirattal: [`lib/home/home.dart:385`](../lib/home/home.dart). A navigáció `BottomNavigationBarType.fixed`, mert négy elemnél a Flutter „shifting” stílusra váltana: `lib/home/home.dart:387-389`.
- **Nem fül.** A koppintás `Navigator.push`-sal teljes új oldalt nyit (`MenuPage`), a kiválasztott fül nem változik: `lib/home/home.dart:185-187`, `:231-238`. Az új oldal az alsó navigációt is eltakarja. Ugyanezt a jelenséget írja le a nyitott [#52](https://github.com/szanatil/Miserend-Flutter/issues/52), amely rá is kérdez: „a Menü oldal ide tartozik-e”.
- A döntés a spec 0009-ben van: [`docs/spec/0009-hibajelentes-es-visszajelzes.md:93-97`](spec/0009-hibajelentes-es-visszajelzes.md). A rögzített ok: „Az AppBarba nem kerül menü: a korábbi ⋮ `PopupMenuButton` nem illett az app elrendezésébe.” Az AppBar címhelyét ma a keresősáv tölti ki: `lib/home/home.dart:304-343`.
- Előzmény: a 8651750-es commit még ⋮ menüt és egy „Az appról” oldalt vezetett be. Ez az oldal mutatta a verziót, azt, hogy „Az adatokat a miserend.hu szolgáltatja.”, a „Készítette: Szent József Hackathon” sort, a „Visszajelzés küldése” gombot és a „Nyílt forrású licencek” gombot (`showLicensePage`); lásd `git show 8651750:lib/about/about_page.dart`. Kilenc perccel később az 55ca07c-s commit mindkettőt törölte, és a „Menü” pont váltotta fel őket. A [#34](https://github.com/szanatil/Miserend-Flutter/issues/34) lezáró kommentje ugyanezt rögzíti.

### 1.2 A Menü oldal tartalma

[`lib/menu/menu_page.dart`](../lib/menu/menu_page.dart), fentről lefelé:

| Elem | Hely |
|---|---|
| AppBar-cím: „Menü” | `:83` |
| **miserend.hu** csempe, „A miserend webes változata”, külső link | `:91-104`, URL: `:45` |
| **„Mai templom ajánlatunk”** kártya | `:105`, `:140-183` |
| **Verzió** csempe, „x.y.z (build)” | `:106-125` |
| **„Visszajelzés”** gomb | `:126-133` |

**Impresszum ma nincs az appban.** A `lib/` alatt nincs „Impresszum” szöveg, és nincs ilyen oldal. A spec 0009 „Out of Scope” része kifejezetten kihagyta: „Adatvédelmi tájékoztató és GitHub-link a Menü oldalon, amíg nincs ilyen oldal.” (`docs/spec/0009-…md:191`). A kérés szerint a Menüben „csak a Visszajelzés és az Impresszum” van. Ez sem a kóddal, sem a dokumentációval nem egyezik (lásd Nyitott kérdések, 1.). Az 55ca07c óta a **nyílt forrású licencek** oldala sem érhető el az appból.

### 1.3 A Visszajelzés

- Levél a `szentjozsefhackathon@jezsuita.hu` címre, „Miserend app – visszajelzés” tárggyal: [`lib/widgets/feedback_mail.dart:10`](../lib/widgets/feedback_mail.dart), `:12`.
- A fogalom a [`CONTEXT.md:107-108`](../CONTEXT.md) sorokban: a Visszajelzés az „app fejlesztőinek (Szent József Hackathon)” szól, és nem a miserend.hu adatgondozóinak. A CONTEXT.md-ben **nincs** fogalombejegyzés a „Menü” pontra vagy az „Impresszum”-ra.

### 1.4 Kapcsolódó dokumentumok

- `README.md:15`, `README.md:74`, `docs/FEATURE-COVERAGE.md:33`, `:40`, `:127`: mindegyik „Menü”-ként írja le a pontot.
- `docs/ANDROID-OSSZEHASONLITAS.md:53`, `:175`: a `lib/home/home.dart:166-173` hivatkozás elavult, a kód ma a `:231-238` sorokban van.
- A `test/menu/menu_page_test.dart:108` a „Menü” címet ellenőrzi, így átnevezésnél a teszt is változik.

---

## 2. Mit csinálnak a többi Miserend-kliens és a minta forrása

### 2.1 A minta képernyő forrása: az Ignáci imák app, nem Miserend

A képernyőképen látott Impresszum **szó szerint** a `szentjozsefhackathon/ignaci_imak` Flutter app kódjából származik: [`lib/settings/impressum_page.dart` @31403bb](https://github.com/szentjozsefhackathon/ignaci_imak/blob/31403bb7bc8f809eceada0dfb9c1a3a1914bfba3/lib/settings/impressum_page.dart).

- Szöveg és adatok: `:8` (adószám konstans `18064333-2-42`), `:9-10` (projekt-URL: `https://github.com/szentjozsefhackathon/ignaci_imak`), `:28-43` (szervezet, cím, linkek, 1%-os mondat), `:51-62` (vágólapra másolás, „Adószám vágólapra másolva” SnackBar), `:73-77` („Felújítva 2025-ben, a Szent József Hackathon keretein belül.” és a forráskód-link).
- **Hol érhető el:** az Ignáci imákban az Impresszum nem alsó navigációs pont. A főoldal AppBarjában egy fogaskerék ikon van („Beállítások” tooltip) ([`lib/menu/prayer_groups_page.dart:100-113`](https://github.com/szentjozsefhackathon/ignaci_imak/blob/31403bb7bc8f809eceada0dfb9c1a3a1914bfba3/lib/menu/prayer_groups_page.dart)). Ez a Beállítások oldalt nyitja, és ennek a listájának a végén áll a „Visszajelzés” és az „Impresszum” ([`lib/settings/settings_page.dart:24`, `:130-137`](https://github.com/szentjozsefhackathon/ignaci_imak/blob/31403bb7bc8f809eceada0dfb9c1a3a1914bfba3/lib/settings/settings_page.dart)). Az útvonalak: `/beallitasok`, `/beallitasok/impresszum` ([`lib/routes.dart:24-26`](https://github.com/szentjozsefhackathon/ignaci_imak/blob/31403bb7bc8f809eceada0dfb9c1a3a1914bfba3/lib/routes.dart)).
- **Következmény:** az „Ignáci Pedagógiai Műhely” és az `ignacipedagogia.hu` link az Ignáci imákhoz tartozik, **erre az appra nem vonatkozik**. Ugyanígy a „Felújítva 2025-ben” sor és a projekt-URL sem.

### 2.2 miserend.hu (webapp)

- Az oldal alján „Impresszum” link van ([`webapp/templates/footer.twig:14` @45db1a0](https://github.com/szentjozsefhackathon/miserend.hu/blob/45db1a049dc411af80ada431c7aaf25b97c5edc5/webapp/templates/footer.twig)). Útvonal: `impresszum` → `staticpage/impressum`.
- Tartalom ([`webapp/templates/staticpage/impressum.twig:6-20`](https://github.com/szentjozsefhackathon/miserend.hu/blob/45db1a049dc411af80ada431c7aaf25b97c5edc5/webapp/templates/staticpage/impressum.twig)), élőben is ugyanez: [miserend.hu/impresszum](https://miserend.hu/impresszum).
  - „2026-tól a miserendet a Szent József Hackathon közössége tartja fenn és fejleszeti tovább önkéntes alapon.” Előtte a Felebarátok Egyesülete (2020-tól), azelőtt a Virtuális Plébánia Alapítvány üzemeltette.
  - „Oldalunkat önkéntesek szerkesztik. […] Bevételünk nincs.” / „Legtöbbet úgy segíthet nekünk, ha önkéntesként vállalja templomok adatainak rendszeres karbantartását.”
  - Elérhetőség: programozás: Elek László SJ (JTMR); Android app: Maczák Balázs; iOS app: Horony Csaba; tartalmi ügyek: `info@miserend.hu`.
  - Link: „Adatkezelési tájékoztató (GDPR)” → [miserend.hu/gdpr](https://miserend.hu/gdpr). Ebben adatkezelőként a Szent József Hackathon önkéntes közössége szerepel, `info@miserend.hu` címmel. Székhely, nyilvántartási szám vagy adószám nincs benne.
- A lábléc GitHub-linkje (`borazslo/miserend.hu`) ma a `szentjozsefhackathon/miserend.hu` repóra irányít át (`gh api repos/borazslo/miserend.hu` → `szentjozsefhackathon/miserend.hu`).
- **Tanulság:** a miserend.hu **üzemeltetője a Szent József Hackathon közössége**, amely önkéntes közösség, nem jogi személy, és nem az Ignáci Pedagógiai Műhely. A webapp nem kér 1%-ot. Támogatásként önkéntes adatgondozást kér.

### 2.3 Hivatalos Android app (`com.frama.miserend.hu`)

- Az alsó navigációban három pont van: Templomok, Misék, Térkép ([`home_navigation_menu.xml` @77bf87b](https://github.com/bmaczak/Miserend-Android/blob/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3/app/src/main/res/menu/home_navigation_menu.xml)). Negyedik pont, névjegy vagy impresszum nincs. A [`strings.xml`](https://github.com/bmaczak/Miserend-Android/blob/77bf87b6fe6d50a1e8f5c3b625fb49be1744e2c3/app/src/main/res/values/strings.xml) fájlban nincs „Impresszum”, „Névjegy” vagy „Menü” szöveg.
- A Flutter upstream (`bmaczak/Miserend-Flutter` @91ad952) `lib/` könyvtárában sincs menü- vagy névjegyoldal.

### 2.4 Hivatalos iOS app (App Store id967827488)

- Az [App Store-oldal](https://apps.apple.com/hu/app/miserend/id967827488) szerint az utolsó frissítés a 0.2-es verzió (2015-06-23). **Szolgáltatóként (seller) „Jézus Társasága Magyarországi Rendtartománya”** szerepel, a copyright „© Csaba Horony”, a visszajelzési cím `horony.csaba@gmail.com`.
- Nyilvános forráskódot nem találtam: a `gh search repos miserend` Swift- és Objective-C-szűréssel nem adott találatot. Az app fül- és menüszerkezetét ezért nem tudtam ellenőrizni.

### 2.5 A minta adatainak ellenőrzése

| Állítás a mintában | Ellenőrzés | Forrás |
|---|---|---|
| „Jézus Társasága Magyarországi Rendtartománya”, **1085 Budapest, Horánszky u. 20.** | ✅ A JTMR címe „1085 Budapest, Horánszky utca 20.”, nyilvántartási száma 00001/2012-055, **adószáma 19014056-2-42** | [JTA adatkezelési tájékoztató](https://jta.jezsuita.hu/rolunk/atlathatosag/adatkezelesi-tajekoztato/) |
| „Ignáci Pedagógiai Műhely”, ugyanez a cím | ✅ „1085 Budapest, Horánszky u. 20.”, `ignacipedagogia@jezsuita.hu` (de ❗ erre az appra nem vonatkozik) | [ignacipedagogia.hu/kapcsolat](https://ignacipedagogia.hu/kapcsolat/) |
| `ignacipedagogia.hu`, `jezsuita.hu` | ✅ Mindkettő él. A `jezsuita.hu` JavaScript-alkalmazás, a szövegét nem tudtam kiolvasni | közvetlen lekérés |
| **Adószám 18064333-2-42** | ✅ Ez a **Jézus Társasága Alapítvány** adószáma, **nem a Rendtartományé**. Székhely: 1085 Budapest, Mária u. 25.; nyilvántartási szám: 01-01-0002369 | [jta.jezsuita.hu – 1%](https://jta.jezsuita.hu/tamogatas/1-tudatos-rendelkezes/), [JTA adatkezelési tájékoztató](https://jta.jezsuita.hu/rolunk/atlathatosag/adatkezelesi-tajekoztato/), [adjukossze.hu](https://adjukossze.hu/szervezet/jezus-tarsasaga-alapitvany-2816) |
| A NAV 1%-os kedvezményezetti listája | ⚠️ Nem ellenőriztem: a NAV listáját nem nyitottam meg | — |
| „Szent József Hackathon” | ✅ Keresztény programozói hétvége, a szegedi Szent József jezsuita templom szervezi. A projektek listája a GitHubon van: [github.com/szentjozsefhackathon](https://github.com/szentjozsefhackathon) | [szentjozsef.jezsuita.hu/szent-jozsef-hackathon](https://szentjozsef.jezsuita.hu/szent-jozsef-hackathon/) |
| „Felújítva 2025-ben” | ❗ Az Ignáci imákra igaz. Ennek az appnak a munkája 2026-os (`git log`: a commitok 2026-09-ből valók) | `git log` |
| Nyílt forráskódú projekt linkje | ❗ A minta az `ignaci_imak` repóra mutat. Ennek az appnak a repója a `szanatil/Miserend-Flutter` (nyilvános, fork, szülője a `bmaczak/Miserend-Flutter`). **A repóban nincs LICENSE fájl** (`gh api repos/szanatil/Miserend-Flutter` → nincs `license`) | `gh api` |

A mintában egy félrevezető rész van. A cím a **Rendtartományt** nevezi meg, az adószám viszont a **Jézus Társasága Alapítványé**. A mondat („ajánld fel adód 1%-át a Jézus Társasága Alapítványnak”) ezt helyesen mondja, de a kettőt könnyű összekeverni.

---

## 3. A pont elnevezése

### 3.1 Platformirányelvek

- **Apple HIG, Tab bars** ([forrás](https://developer.apple.com/design/human-interface-guidelines/tab-bars)):
  - „Use a tab bar to support navigation, not to provide actions. […] If you need to provide controls that act on elements in the current view, use a toolbar instead.”
  - „Make sure the tab bar is visible when people navigate to different sections of your app. If you hide the tab bar, people can forget which area of the app they're in. The exception is when a modal view covers the tab bar […]”
  - „Include tab labels to help with navigation. […] clearly describing the type of content or functionality the tab contains. Use single words whenever possible.”
  - „Avoid overflow tabs.” Az iOS maga is „More” fület készít, ha nem fér ki minden, de ez „makes it harder for people to reach and notice content”.
- **Android, Navigation bar** ([forrás](https://developer.android.com/develop/ui/compose/components/navigation-bar)): „You should use navigation bars for: Three to five destinations of equal importance […] Consistent destinations across app screens”. A Material Components Android dokumentációja szerint a navigációs sáv célja a „top-level views” közti váltás, és 3–5 célpontot tartalmaz ([BottomNavigation.md](https://github.com/material-components/material-components-android/blob/60ff09436d5d477a4b9d02940f31eb01e1250620/docs/components/BottomNavigation.md)).
- **Flutter**, `NavigationBar`: „Navigation bars offer a persistent and convenient way to switch between primary destinations in an app.” ([api.flutter.dev](https://api.flutter.dev/flutter/material/NavigationBar-class.html)). A Material 3 weboldalát (m3.material.io) nem tudtam kiolvasni, mert JavaScriptet igényel. Ezért nem idézem.

**A mai „Menü” pont két irányelvvel is ütközik.** (1) Nem célpont, hanem **akció**, mert új oldalt tol fel, és a kijelölt fül nem változik (`home.dart:231-238`). (2) A megnyitott oldal **eltakarja az alsó navigációt**. A „Menü” felirat hamburger ikonnal ráadásul oldalsó menüt (drawer) sejtet. A Flutter magyar fordítása is ezt a jelentést használja: `openAppDrawerTooltip`: „Navigációs menü megnyitása”, `drawerLabel`: „Navigációs menü” (`flutter/packages/flutter_localizations/lib/src/l10n/material_hu.arb:4`, `:41`, Flutter 3.47.1, `6655482`).

### 3.2 Magyar felirat-jelöltek

Mérvadó, első kézből származó forrásként csak a platformok saját fordításait találtam. Más magyar appok fülfeliratait nem tudtam megbízhatóan ellenőrizni. A GitHub-kódkeresés csak szórványos, nem összehasonlítható találatokat adott.

| Jelölt | Ikon | Mire illik | Forrás / megjegyzés |
|---|---|---|---|
| **Továbbiak** | `Icons.more_horiz` | vegyes, másodlagos tartalom; bővíthető (beállítások stb.) | Az iOS „More” fül mintája (HIG, fent). Konvencionális, de szintén általános. |
| **Több** | `Icons.more_horiz` | ugyanaz | A Flutter magyar fordítása a „more” gombra: `moreButtonTooltip`: „Több” (`material_hu.arb:57`). Fülfeliratnak kevésbé beszédes. |
| **Névjegy** | `Icons.info_outline` | ha a pont csak az appról szól (verzió, visszajelzés, impresszum, licencek) | A Flutter magyar About-szövege: `aboutListTileTitle`: „A(z) $applicationName névjegye” (`material_hu.arb:15`). Egyetlen szó, ahogy a HIG kéri. A „Mai templom ajánlatunk” kártya nem illik alá. |
| **Az appról** | `Icons.info_outline` | ugyanaz | Ez volt a 8651750-es commit oldalcíme. Két szó. |
| **Egyéb** | — | — | Nem ajánlott. Az app a hibajelentésben már használja („Egyéb” hibatípus: spec 0009, Android `report_other`), ez összeolvadna vele. |
| **Rólunk** | — | — | A fejlesztő csapatról szól, nem az appról. A visszajelzést és a webes változatot nem fedi. |

### 3.3 A pont áthelyezése

- **AppBar-ikon, az Ignáci imák mintájára** (§2.1). Egy fogaskerék vagy ⓘ ikon a keresősáv mellett, amely a Beállítások vagy Névjegy oldalt nyitja. Ez megfelel a HIG „nem akció a tab barban” elvének, és felszabadítja a navigációt a három valódi fülre. Hátránya: a spec 0009 szerint a ⋮ menü „nem illett az app elrendezésébe”, mert az AppBart a keresősáv (`SearchAnchor.bar`) tölti ki. Egy ikon kevesebb helyet kér, mint egy ⋮ menü, de a keresősáv szélessége csökken.
- **Kapcsolat a #52-vel.** Ha a fülenkénti navigáció megvalósul, a pont igazi fül is lehet, saját `Navigator`-ral, az alsó navigáció fölött. Ezzel megszűnne a HIG „tab bar legyen látható” ütközése.

### 3.4 Ajánlás

1. **Rövid távon, a mai tartalommal:** a pont neve legyen **„Továbbiak”**, `Icons.more_horiz` ikonnal. Ma ez egy vegyes lap: webes változat, napi templomajánlat, verzió, visszajelzés és leendő impresszum. Erre a platformok általánosan elfogadott gyűjtőszava a „Továbbiak”, amely nem sejtet drawert, mint a hamburger ikon. Ha a lap új elemekkel bővül (beállítások, értesítések, nyelv, kedvencek kezelése), a név akkor is igaz marad.
2. **Ha a lap a névjegyre szűkül** (a „Mai templom ajánlatunk” máshová kerül, pl. a Templomok fülre), akkor **„Névjegy”** (ⓘ) a pontosabb és kevésbé általános név. Ez illik a felhasználó „túl általános” kifogására is.
3. **Hosszabb távon** érdemes a #52-vel együtt eldönteni, hogy maradjon-e alsó navigációs pont. A HIG és az Android-irányelv szerint a másodlagos, alkalmanként használt tartalom (impresszum, licencek, visszajelzés) inkább AppBar-ikon vagy beállításoldal mögé való. Ha viszont több, gyakran használt elem is jön (pl. beállítások, kedvencek), akkor a negyedik pont indokolt, de igazi fülként (#52).

---

## 4. Javasolt Impresszum-tartalom ennek az appnak

### 4.1 Mezők

| # | Mező | Javasolt tartalom | Állapot |
|---|---|---|---|
| 1 | Kiadó / üzemeltető (az app szolgáltatója) | pl. **Jézus Társasága Magyarországi Rendtartománya**, 1085 Budapest, Horánszky u. 20. | ❓ **Megerősítendő.** Forrásokkal ellenőrzött: a régi iOS app szolgáltatója a JTMR ([App Store](https://apps.apple.com/hu/app/miserend/id967827488)), és a hackathont egy jezsuita templom szervezi. Az viszont nem ellenőrzött, hogy a Play Áruházban és az App Store-ban **melyik fejlesztői fiók** adja ki ezt az appot. A Play-oldalt nem tudtam kiolvasni. |
| 2 | Fejlesztő | „Fejlesztette a Szent József Hackathon közössége, 2026-ban” | ✅ A fejlesztő (CONTEXT.md:108, miserend.hu impresszum). ❓ Az évszám és a megfogalmazás a karbantartóra tartozik. |
| 3 | Kapcsolat az appról | `szentjozsefhackathon@jezsuita.hu` (ugyanaz, mint a Visszajelzés) | ✅ `lib/widgets/feedback_mail.dart:10` |
| 4 | Adatforrás és tartalmi kapcsolat | „Az adatokat a miserend.hu szolgáltatja”, link; tartalmi ügyek: `info@miserend.hu` | ✅ [miserend.hu/impresszum](https://miserend.hu/impresszum). A templomadatok hibájára a Hibajelentés való (CONTEXT.md:103-108). |
| 5 | Térkép-forrásmegjelölés | nem kell ide, a térképen már szerepel | ✅ spec 0009, „Menü oldal” utolsó bekezdése |
| 6 | Adatkezelés | link a [miserend.hu/gdpr](https://miserend.hu/gdpr) oldalra, vagy saját app-tájékoztató | ❓ Megerősítendő. A miserend.hu tájékoztatója a webről szól. Az app a hibajelentéssel e-mail-címet küldhet az API-nak (spec 0009), és összeomlás-jelentés is tervben van (#38, #48–#50). |
| 7 | Támogatás | A: a miserend.hu mintája: önkéntes adatgondozásra hívás; B: 1% a **Jézus Társasága Alapítványnak**, adószám **18064333-2-42**, másolás gombbal | ✅ Mindkét adat ellenőrzött (§2.2, §2.5). ❓ Hogy legyen-e ilyen rész, és melyik, az a karbantartó döntése. A miserend.hu azt írja: „Bevételünk nincs”, és 1%-ot nem kér. |
| 8 | Nyílt forráskód | „Ha fejlesztenél valamit az alkalmazáson, itt találod a projektet” → a repó URL-je | ❓ Melyik repó a kanonikus (`szanatil/…`, `bmaczak/…`, vagy később `szentjozsefhackathon/…`)? A repóban **nincs licenc**, így a „nyílt forráskódú” jelző jogilag nem egyértelmű. |
| 9 | Verzió | már a lapon van | ✅ `menu_page.dart:106-125` |
| 10 | Nyílt forrású licencek | `showLicensePage` gomb (a törölt „Az appról” oldalon megvolt) | ✅ A Flutter beépített oldala. Ma nem érhető el (§1.2). |

A mintából **nem** átvehető: „Ignáci Pedagógiai Műhely”, `ignacipedagogia.hu`, „Felújítva 2025-ben”, a projekt-URL (§2.1, §2.5).

### 4.2 Jogi háttér (Ekertv. 4. §), csak tájékoztatásul

A 2001. évi CVIII. törvényt (Ekertv.) a Nemzeti Jogszabálytárban olvastam ([njt.jog.gov.hu/jogszabaly/2001-108-00-00](https://njt.jog.gov.hu/jogszabaly/2001-108-00-00), hatályos szöveg, 2026-09-18).

- **4. §**: „A szolgáltató köteles elektronikus úton közvetlenül és folyamatosan, könnyen hozzáférhető módon legalább a következő adatokat közzétenni:
  - a) a szolgáltató nevét,
  - b) a szolgáltató székhelyét, telephelyét, ennek hiányában lakcímét,
  - c) a szolgáltató elérhetőségére vonatkozó adatokat, különösen az igénybe vevőkkel való kapcsolattartásra szolgáló, rendszeresen használt elektronikus levelezési címét,
  - d) [nyilvántartásba vételhez kötött szolgáltatónál] a nyilvántartásba bejegyző bíróság vagy hatóság megnevezését, és a szolgáltató nyilvántartásba vételi számát,
  - e) [engedélyköteles tevékenységnél az engedély adatait],
  - f) ha a szolgáltató az általános forgalmi adó alanya, a szolgáltató adószámát;
  - g) [szabályozott szakmáknál a kamarát stb.],
  - h) a szolgáltató részére a tárhelyet biztosító […] szolgáltató székhelyét, telephelyét, az elérhetőségére vonatkozó adatokat […]”
- **2. § 11. pont**: információs társadalommal összefüggő szolgáltatás az „elektronikus úton, távollevők részére, **rendszerint ellenszolgáltatás fejében** nyújtott szolgáltatás, amelyhez a szolgáltatás igénybe vevője egyedileg fér hozzá”. **2. § 20. pont**: szolgáltató az ilyen szolgáltatást nyújtó „természetes, illetve jogi személy vagy jogi személyiség nélküli szervezet”.

Megjegyzések (ez nem jogi vélemény):
- Hogy egy ingyenes, offline is működő app „rendszerint ellenszolgáltatás fejében nyújtott” szolgáltatásnak számít-e, arról ebben a jegyzetben nem foglalok állást. Ha a törvény vonatkozik rá, az a)–c) pont (név, székhely, e-mail) a lényeg, a d) és f) pont csak a feltételeik teljesülésekor.
- Az f) pont szerinti adószám **a szolgáltatóé**, és csak akkor, ha az ÁFA alanya. Az 1%-os adószám (18064333-2-42) **nem** ez: az egy támogatható alapítvány adószáma. Az impresszumban a kettőt külön kell kezelni (lásd §2.5).
- A miserend.hu saját impresszuma a jogi személy nevét és székhelyét nem adja meg, csak a Szent József Hackathon közösségét és e-mail-címeket (§2.2).

---

## Döntések (2026-09-18, karbantartó)

| Kérdés | Döntés |
|---|---|
| A pont neve | **„Névjegy”** (javasolt ikon: `Icons.info_outline`). |
| „Mai templom ajánlatunk” | **Marad** a Névjegy lapon. |
| Kiadó | **Jézus Társasága Magyarországi Rendtartománya**, link: [jezsuita.hu](https://jezsuita.hu). A cím (1085 Budapest, Horánszky u. 20.) a §2.5 szerint ellenőrzött. |
| Fejlesztő | **Szent József Hackathon**. |
| Forráskód | [github.com/szanatil/Miserend-Flutter](https://github.com/szanatil/Miserend-Flutter). |
| Támogatás | 1% a **Jézus Társasága Alapítványnak**, adószám 18064333-2-42, másolás gombbal. |
| Licencek | ~~A lapon legyen elérhető a használt licencek listája.~~ Később visszavonva: **nem kell**. |
| Elrendezés (később) | **Nincs külön Impresszum oldal**: minden a Névjegyen van, fentről lefelé: Mai templom ajánlatunk, Kiadó + támogatás, Fejlesztő + verzió, Forráskód, miserend.hu csempe. A Visszajelzés lebegő gomb a képernyő alján. |

Így a §2.5 buktatója megoldott: kiadóként a Rendtartomány szerepel, az adószám pedig kifejezetten az Alapítványhoz tartozó 1%-os mondat mellett áll.

## Nyitott kérdések

A fenti döntések a 2., 3. és 6. kérdést (a navigáció helyén kívül) és a 4. kérdés repó-részét lezárják.

1. **Mit lát a felhasználó?** A kérés szerint a Menüben „Visszajelzés és Impresszum” van, a kódban viszont miserend.hu link, „Mai templom ajánlatunk”, Verzió és Visszajelzés, Impresszum nélkül (§1.2). Más buildről vagy tervről van szó?
2. **Ki az app kiadója** a Play Áruházban és az App Store-ban, és ki szerepeljen üzemeltetőként: a JTMR, a Szent József Hackathon közössége, vagy magánszemély? Ettől függ az Impresszum 1. mezője és az Ekertv. szerinti adatok köre.
3. **Legyen-e 1%-os felhívás**, és ha igen, a Jézus Társasága Alapítványé (18064333-2-42)? Vagy inkább a miserend.hu mintája szerint az önkéntes adatgondozásra hívjunk?
4. **Melyik repó a kanonikus nyílt forrású projekt**, és milyen licenc alatt? Ma nincs LICENSE fájl.
5. **Adatkezelés:** elég a miserend.hu/gdpr, vagy kell saját app-tájékoztató (hibajelentés e-mail-címe, tervezett összeomlás-jelentés)?
6. **Navigáció:** marad-e a negyedik alsó pont („Továbbiak” vagy „Névjegy”), vagy AppBar-ikon lesz belőle? A választás a #52 döntésével együtt a legésszerűbb. Hova kerül a „Mai templom ajánlatunk”, ha a lap „Névjegy”-re szűkül?
7. A döntés után a C6 szerint frissítendő: a `CONTEXT.md` (új fogalom: a pont neve és az Impresszum), a spec 0009 „Menü oldal” része (vagy új spec), a `docs/FEATURE-COVERAGE.md`, a `README.md` és a `docs/ANDROID-OSSZEHASONLITAS.md` elavult sorhivatkozásai.
