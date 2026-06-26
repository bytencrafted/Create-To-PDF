# Convert to PDF

Eine Flutter-App für Android, die Bilder und vorhandene PDFs zu einem einzigen PDF zusammenführt – inklusive nützlicher PDF-Werkzeuge wie Passwortschutz, Seiten sortieren, Seiten löschen, Kopf-/Fußzeilen und Optimierung.

![Platform](https://img.shields.io/badge/platform-Android-3DDC84?logo=android&logoColor=white)
![Flutter](https://img.shields.io/badge/Flutter-stable-02569B?logo=flutter&logoColor=white)
![Languages](https://img.shields.io/badge/Sprachen-DE%20%7C%20EN%20%7C%20FR%20%7C%20PT-E53935)

---

## Inhalt

- [Funktionen](#funktionen)
- [Screenshots](#screenshots)
- [Tech-Stack](#tech-stack)
- [Projektstruktur](#projektstruktur)
- [Erste Schritte](#erste-schritte)
- [Release-Build (Play Store)](#release-build-play-store)
- [Lokalisierung](#lokalisierung)
- [Bekannte Einschränkungen](#bekannte-einschränkungen)
- [Datenschutz](#datenschutz)
- [Lizenz](#lizenz)

---

## Funktionen

- **Bilder → PDF**: Fotos aus Kamera oder Galerie aufnehmen/auswählen und zu einem PDF zusammenfügen.
- **PDFs zusammenführen**: Vorhandene PDFs importieren und mit Bildern in beliebiger Reihenfolge kombinieren.
- **Originalgröße bleibt erhalten**: Importierte PDF-Seiten werden ohne Beschneidung in ihrer Originalgröße übernommen.
- **Seitenoptionen**: Seitengröße (A4 / Letter), Hochformat/Querformat, Rand in mm und optionaler Dateiname.
- **Drag-&-Drop-Sortierung**: Eingangsliste und PDF-Seiten per Ziehen neu anordnen.
- **PDF-Werkzeuge**:
  - Passwortschutz (User- und Owner-Passwort)
  - Seiten neu anordnen (visuell)
  - Einzelne Seiten löschen (antippen zum Markieren)
  - Optimieren (strukturelle Komprimierung)
  - Kopf-/Fußzeilen inkl. echter Seitenzahlen („Seite X von Y")
- **Vorschau**: Erzeugtes PDF vor dem Teilen ansehen.
- **Teilen**: Fertiges PDF über das System-Teilen-Menü weitergeben.
- **Mehrsprachig**: Deutsch, Englisch, Französisch, Portugiesisch – beim ersten Start wählbar, später jederzeit umschaltbar.
- **Modernes Material-3-Design**: Helle, aufgeräumte Oberfläche mit rotem Markenakzent.

---

## Screenshots

> Lege deine Screenshots in `docs/screenshots/` ab und verlinke sie hier, z. B.:

| Start | Werkzeuge | Optionen |
|-------|-----------|----------|
| ![Start](docs/screenshots/home.png) | ![Tools](docs/screenshots/tools.png) | ![Options](docs/screenshots/options.png) |

---

## Tech-Stack

- **Flutter / Dart** (SDK `^3.8.1`)
- **syncfusion_flutter_pdf** – PDF-Erstellung und -Bearbeitung
- **syncfusion_flutter_pdfviewer** – PDF-Vorschau im Viewer
- **image_picker** – Kamera & Galerie
- **file_picker** – Bild-/PDF-Auswahl aus dem Dateisystem
- **share_plus** – Teilen des erzeugten PDFs
- **path_provider** – Zugriff auf App-Verzeichnisse
- **shared_preferences** – Persistente Sprachauswahl
- **flutter_localizations** – Lokalisierungs-Grundlagen

Schwere PDF-Operationen laufen über `Isolate.run` in einem Hintergrund-Isolate, damit die Oberfläche flüssig bleibt.

---

## Projektstruktur

```
lib/
├── main.dart                       # Einstiegspunkt
├── app.dart                        # App-Wurzel, zentrales Theme (AppColors)
├── localization/
│   └── app_lang.dart               # Übersetzungen (de/en/fr/pt) + Controller
├── models/
│   ├── input_entry.dart            # Listeneintrag (Bild oder PDF) mit stabiler ID
│   └── pdf_options.dart            # Seitengröße, Ausrichtung, Rand
├── services/
│   ├── pdf_tools_service.dart      # Komposition + alle PDF-Operationen
│   └── share_service.dart          # Teilen
├── ui/
│   └── common_widgets.dart         # Wiederverwendbare Widgets (Karten, Kacheln …)
└── features/
    ├── home/
    │   └── home_page.dart          # Startseite
    ├── pdf_tools/
    │   └── pdf_tools_page.dart      # Viewer + Werkzeuge, Sortieren/Löschen
    └── preview/
        └── pdf_preview_page.dart    # PDF-Vorschau
```

---

## Erste Schritte

Voraussetzungen: Ein eingerichtetes [Flutter-SDK](https://docs.flutter.dev/get-started/install) und Android Studio / Android-SDK.

```bash
# Repository klonen
git clone <dein-repository-url>
cd "Convert to PDF"

# Abhängigkeiten installieren
flutter pub get

# Im Debug-Modus starten (Gerät/Emulator angeschlossen)
flutter run
```

Vor dem Commit empfiehlt sich:

```bash
flutter analyze
```

---

## Release-Build (Play Store)

1. **Version erhöhen** in `pubspec.yaml`. Beispiel:
   ```yaml
   version: 1.2.0+7
   ```
   - Der Teil vor `+` ist der für Nutzer sichtbare *versionName*.
   - Die Zahl nach `+` ist der *versionCode* und **muss bei jedem Upload höher** sein als zuvor.

2. **App Bundle bauen:**
   ```bash
   flutter clean
   flutter pub get
   flutter build appbundle --release
   ```
   Ergebnis: `build/app/outputs/bundle/release/app-release.aab`

3. **In der Play Console** unter *Produktion* (oder einem Testtrack) einen neuen Release erstellen, die `.aab` hochladen, Versionshinweise eintragen und ausrollen.

> Hinweis: Das Release-Bundle muss mit dem Upload-Keystore signiert sein (Konfiguration in `android/key.properties` und `android/app/build.gradle`).

**Paketname:** `com.onikharutyunyan.converttopdf`

---

## Lokalisierung

Alle Texte liegen zentral in `lib/localization/app_lang.dart` als Schlüssel-Wert-Tabellen pro Sprache (`de`, `en`, `fr`, `pt`).

- Neuen Text ergänzen: Schlüssel in **alle** vier Sprach-Maps eintragen.
- Im Code abrufen: `AppLang.of(context).t('mein_key')`.
- Mit Platzhaltern: `AppLang.of(context).f('page_x_of_y', [1, 5])`.

Die zuletzt gewählte Sprache wird per `shared_preferences` gespeichert.

---

## Bekannte Einschränkungen

- **Optimieren** führt eine strukturelle Komprimierung durch (beste Objektkomprimierung, Aufräumen ungenutzter Objekte), rechnet aber **eingebettete Rasterbilder nicht in geringerer Qualität neu**. Echte Bildkomprimierung würde ein Rastern der Seiten oder einen Server-Schritt (z. B. Ghostscript) erfordern.
- Die App ist aktuell auf **Android** ausgelegt.
- Bei sehr vielen großen Bildern kann der Speicher knapp werden; die App fängt das ab und weist darauf hin.

---

## Datenschutz

Datenschutzerklärung: **https://bytencrafted.github.io/Create-To-PDF/**

Die App verarbeitet die ausgewählten Dateien lokal auf dem Gerät, um das PDF zu erzeugen.

---

## Lizenz

> Wähle eine Lizenz aus und trage sie hier ein (z. B. MIT). Lege dazu eine Datei `LICENSE` im Projekt an.

```
© 2026 Onik Harutyunyan. Alle Rechte vorbehalten.
```
