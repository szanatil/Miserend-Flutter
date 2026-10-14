---
status: accepted
---

# A meglévő Play-lista átvétele (`com.frama.miserend.hu`)

A Flutter app eddig `com.frama.miserend.hu.miserend` csomagazonosítóval épült, ez a csomag viszont nincs fent a Play Áruházban. Az éles Android-kiadás ezért a fastlane feltöltésnél `Google Api Error: Invalid request - Package not found: com.frama.miserend.hu.miserend` hibával állt meg. A boltban a Miserend app a régi, natív Android-alkalmazás néven él, `com.frama.miserend.hu` azonosítóval (utolsó frissítés 2019, 10 000+ letöltés).

Döntés: a Flutter app **átveszi a meglévő Play-listát**. Az `applicationId`, a `namespace`, a `MainActivity` csomagja és a fastlane Appfile `package_name`-je `com.frama.miserend.hu` lesz, így a kiadás a meglévő felhasználókhoz frissítésként megy, nem külön alkalmazásként jelenik meg. Az iOS bundle-azonosító külön kérdés, ezt a döntés nem érinti.

## Considered Options

- **A `com.frama.miserend.hu.miserend` megtartása és új Play-lista létrehozása.** Elvetve: a boltban két Miserend app lenne, és a meglévő 10 000+ felhasználó nem kapná frissítésként az új klienst; az első feltöltést kézzel, Play Console-ból kellene indítani.
- **A meglévő `com.frama.miserend.hu` lista átvétele** (ez a döntés). A frissítés a régi felhasználókhoz megy; cserébe a feltöltést a meglévő app érvényes aláíró kulcsával kell aláírni.

## Consequences

- Az azonosító egy helyen, az Android-konfigurációban él: `android/app/build.gradle.kts` (`namespace`, `applicationId`), `android/app/src/main/kotlin/com/frama/miserend/hu/MainActivity.kt` és `android/fastlane/Appfile`.
- A Play-feltöltést a **meglévő app kulcsával** kell aláírni. Ha a régi appon be van kapcsolva a Play App Signing, a feltöltési kulcsot regisztrálni (szükség esetén a Play Console-ban resetelni) kell; ha nincs, a régi aláíró kulcs kell. A `PLAY_STORE_JSON_KEY` service accountjának is joga kell legyen a listához („Release to testing tracks” / „Release to production”).
- A `versionCode`-nak meg kell haladnia a listán eddig feltöltött legnagyobbat (a régi appé 21 volt); a pipeline build-szám-emelése ezt biztosítja.
- Az összeomlás-jelentéshez (spec 0013) az Android appot a Firebase-projektben `com.frama.miserend.hu` néven kell regisztrálni.
- A `docs/ANDROID-OSSZEHASONLITAS.md` 2026-09-17-i pillanatképe a régi azonosítót írja le; az a dokumentum a vizsgált commit állapotát rögzíti, ezért nem íródik át.
