---
status: accepted
---

# Közös Material 3 alap, platformhű adaptív elemekkel

Az app Android- és iOS-felhasználóknak ugyanazt a funkciót adja, de az iOS-felhasználó más rendszerszintű interakciókhoz szokott (dialógus, műveletlap, dátumválasztó, vissza-gesztus, ikonok). Döntés: **egyetlen, Material 3 alapú widgetfa** közös képernyőszerkezettel, és egy **rögzített listán** (DESIGN.md, PL2) platformhű adaptív elemek. Ami nincs a listán, az iOS-en is M3. A platformfüggő elágazás a `lib/theme/` alatt, egy helyen áll, a képernyők kódja nem ágazik el.

## Considered Options

- **Mindenhol Material, adaptáció nélkül** (a korábbi állapot). Elvetve: egy kódút, de az iOS-felhasználó pont a rendszerszintű interakcióknál érzi idegennek az appot.
- **Külön Cupertino UI iOS-re.** Elvetve: kétszeres képernyőkód és tesztkészlet, a két változat funkcióban szétcsúszik, ami ellentéte a közös funkció céljának. A Flutter Cupertino-könyvtára ráadásul nem követi az iOS aktuális kinézetét, így a „natív" ígéret úgysem teljesülne.

## Consequences

- Az iOS-változat hibrid: a kártyáknak, chipeknek és a keresősávnak nincs Cupertino párja, ezek M3-ként jelennek meg iOS-keretben.
- Minden adaptív elemet mindkét platformon tesztelni kell (DESIGN.md, EH3); a platformot `Theme.of(context).platform` adja, hogy a teszt felülírhassa.
- Új adaptív elem csak a PL2 lista bővítésével kerülhet be.
