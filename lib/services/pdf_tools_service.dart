import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../models/pdf_options.dart';

/// Einfache Datenträgerklasse für den gemischten Build:
/// isImage=true => path zeigt auf Bild; sonst auf PDF.
class MixedInput {
  final bool isImage;
  final String path;
  const MixedInput.image(this.path) : isImage = true;
  const MixedInput.pdf(this.path) : isImage = false;
}

/// Utility-Service für PDF-Operationen.
class PdfToolsService {
  /// Speichert Bytes als Datei im App-Dokumentenordner.
  /// (Plattformkanal -> muss auf dem Main-Isolate laufen.)
  Future<File> _saveBytes(List<int> bytes, {required String baseName}) async {
    final dir = await getApplicationDocumentsDirectory();
    final file =
        File('${dir.path}/${baseName}_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<PdfDocument> _loadDoc(File file) async {
    final bytes = await file.readAsBytes();
    return PdfDocument(inputBytes: bytes);
  }

  /// Anzahl Seiten eines PDFs (für die visuellen Reorder-/Delete-Dialoge).
  Future<int> pageCount(File pdf) async {
    final doc = await _loadDoc(pdf);
    final c = doc.pages.count;
    doc.dispose();
    return c;
  }

  /// Merge mehrerer PDFs zu einem – behält Originalseitengrößen.
  Future<File> mergePdfs(List<File> pdfFiles, {String baseName = 'merged'}) async {
    if (pdfFiles.isEmpty) throw ArgumentError('Keine PDFs gewählt.');
    if (pdfFiles.length == 1) return pdfFiles.first;

    final out = PdfDocument();
    for (final f in pdfFiles) {
      final src = await _loadDoc(f);
      for (int i = 0; i < src.pages.count; i++) {
        _appendPagePreservingSize(out, src.pages[i]);
      }
      src.dispose();
    }
    final bytes = await out.save();
    out.dispose();
    return _saveBytes(bytes, baseName: baseName);
  }

  /// Passwort setzen. Ohne Owner-Passwort ist die Verschlüsselung praktisch
  /// wirkungslos -> wenn keins angegeben, nehmen wir das User-Passwort.
  Future<File> protectPdf(
    File pdf, {
    required String userPassword,
    String? ownerPassword,
    String baseName = 'protected',
  }) async {
    final doc = await _loadDoc(pdf);
    doc.security.userPassword = userPassword;
    doc.security.ownerPassword =
        (ownerPassword != null && ownerPassword.isNotEmpty) ? ownerPassword : userPassword;

    doc.security.permissions
      ..add(PdfPermissionsFlags.print)
      ..remove(PdfPermissionsFlags.copyContent);

    final bytes = await doc.save();
    doc.dispose();
    return _saveBytes(bytes, baseName: baseName);
  }

  /// Seitenreihenfolge ändern: 0-basierte Indizes, behält Originalgrößen.
  Future<File> reorderPages(File pdf, List<int> newOrder,
      {String baseName = 'reordered'}) async {
    final src = await _loadDoc(pdf);
    if (newOrder.length != src.pages.count) {
      src.dispose();
      throw ArgumentError('Anzahl in newOrder muss ${src.pages.count} sein.');
    }
    final out = PdfDocument();
    for (final idx in newOrder) {
      if (idx < 0 || idx >= src.pages.count) {
        src.dispose();
        out.dispose();
        throw ArgumentError('Ungültiger Index $idx');
      }
      _appendPagePreservingSize(out, src.pages[idx]);
    }
    final bytes = await out.save();
    src.dispose();
    out.dispose();
    return _saveBytes(bytes, baseName: baseName);
  }

  /// Seiten löschen: 0-basierte Indizes.
  Future<File> deletePages(File pdf, List<int> removeIndices,
      {String baseName = 'trimmed'}) async {
    final doc = await _loadDoc(pdf);
    final toRemove = removeIndices.toSet().toList()..sort((a, b) => b.compareTo(a));
    for (final idx in toRemove) {
      if (idx >= 0 && idx < doc.pages.count) {
        doc.pages.removeAt(idx);
      }
    }
    final bytes = await doc.save();
    doc.dispose();
    return _saveBytes(bytes, baseName: baseName);
  }

  /// Strukturelle Optimierung: bestmögliche Objektkompression + Rebuild
  /// (entfernt ungenutzte Objekte).
  ///
  /// WICHTIG / EHRLICH: Diese Methode rechnet eingebettete Raster-Bilder NICHT
  /// in geringerer Qualität neu. Echtes "JPEG-Quality runter" bräuchte ein
  /// Rastern der Seiten oder einen Server-Schritt (LibreOffice/Ghostscript).
  /// Deshalb gibt es hier bewusst KEINEN Quality-Slider mehr, der nichts tut.
  Future<File> compressPdf(File pdf, {String baseName = 'optimized'}) async {
    final src = await _loadDoc(pdf);
    src.compressionLevel = PdfCompressionLevel.best;

    final out = PdfDocument();
    out.compressionLevel = PdfCompressionLevel.best;

    for (int i = 0; i < src.pages.count; i++) {
      _appendPagePreservingSize(out, src.pages[i]);
    }

    final bytes = await out.save();
    src.dispose();
    out.dispose();
    return _saveBytes(bytes, baseName: baseName);
  }

  /// Kopf-/Fußzeilen. [pageNumberFormat] enthält die lokalisierten
  /// Platzhalter, z. B. "Seite {0} von {1}".
  Future<File> addHeaderFooter(
    File pdf, {
    String? headerText,
    String? footerLeft,
    bool showPageNumber = true,
    String pageNumberFormat = 'Page {0} of {1}',
    String baseName = 'header_footer',
  }) async {
    final doc = await _loadDoc(pdf);

    if (headerText != null && headerText.isNotEmpty) {
      final header = PdfPageTemplateElement(const ui.Rect.fromLTWH(0, 0, 500, 40));
      header.graphics.drawString(
        headerText,
        PdfStandardFont(PdfFontFamily.helvetica, 12, style: PdfFontStyle.bold),
        brush: PdfBrushes.black,
        bounds: const ui.Rect.fromLTWH(12, 10, 480, 20),
      );
      doc.template.top = header;
    }

    final footer = PdfPageTemplateElement(const ui.Rect.fromLTWH(0, 0, 500, 40));
    if (footerLeft != null && footerLeft.isNotEmpty) {
      footer.graphics.drawString(
        footerLeft,
        PdfStandardFont(PdfFontFamily.helvetica, 10),
        brush: PdfBrushes.black,
        bounds: const ui.Rect.fromLTWH(12, 10, 300, 20),
      );
    }

    if (showPageNumber) {
      // Echte automatische Felder statt eines literalen "{0}/{1}"-Strings.
      final font = PdfStandardFont(PdfFontFamily.helvetica, 10);
      final composite = PdfCompositeField(
        font: font,
        brush: PdfBrushes.black,
        text: pageNumberFormat,
        fields: <PdfAutomaticField>[
          PdfPageNumberField(font: font, brush: PdfBrushes.black),
          PdfPageCountField(font: font, brush: PdfBrushes.black),
        ],
      );
      composite.draw(footer.graphics, const ui.Offset(350, 12));
    }
    doc.template.bottom = footer;

    final bytes = await doc.save();
    doc.dispose();
    return _saveBytes(bytes, baseName: baseName);
  }

  // ---------- Gemischte Komposition (Bilder + PDFs) ----------

  /// Baut ein PDF aus einer gemischten Reihenfolge.
  /// Die schwere Arbeit läuft in einem Hintergrund-Isolate, damit die UI
  /// nicht blockiert (Syncfusion-PDF ist reines Dart und isolate-tauglich).
  ///
  /// Falls Isolate.run auf einer Plattform Probleme macht, einfach die
  /// Zeile auf `await _composeMixedBytes(items, options)` umstellen.
  Future<File> composeMixedPdf(
    List<MixedInput> items, {
    required PdfOptions options,
    String baseName = 'mixed',
  }) async {
    if (items.isEmpty) {
      throw ArgumentError('Keine Eingaben übergeben.');
    }
    final Uint8List bytes =
        await Isolate.run(() => _composeMixedBytes(items, options));
    return _saveBytes(bytes, baseName: baseName);
  }

  // ---------- Helfer ----------

  /// Hängt eine Quellseite 1:1 (Originalgröße) an das Ziel-Dokument an.
  /// Über eine eigene Section pro Seite werden gemischte Seitengrößen
  /// korrekt erhalten – kein Clipping mehr durch eine fixe Dokumentgröße.
  static void _appendPagePreservingSize(PdfDocument out, PdfPage srcPage) {
    final ui.Size size = srcPage.size;
    final template = srcPage.createTemplate();

    final section = out.sections!.add();
    section.pageSettings.size = size;
    section.pageSettings.margins.all = 0;

    final page = section.pages.add();
    page.graphics.drawPdfTemplate(template, const ui.Offset(0, 0));
  }
}

/// Läuft im Hintergrund-Isolate. Liest Dateien, baut das PDF und gibt die
/// Bytes zurück (das Schreiben passiert wegen Plattformkanal im Main-Isolate).
Future<Uint8List> _composeMixedBytes(
    List<MixedInput> items, PdfOptions options) async {
  ui.Size sizeFromOptions() {
    switch (options.size) {
      case PageSize.a4:
        return options.orientation == PdfOrientation.portrait
            ? const ui.Size(595.28, 841.89)
            : const ui.Size(841.89, 595.28);
      case PageSize.letter:
        return options.orientation == PdfOrientation.portrait
            ? const ui.Size(612.0, 792.0)
            : const ui.Size(792.0, 612.0);
    }
  }

  final ui.Size sz = sizeFromOptions();
  final double marginPt = options.marginPt;

  final out = PdfDocument();

  for (final it in items) {
    if (it.isImage) {
      final bytes = await File(it.path).readAsBytes();

      // Eigene Section mit gewählter Seitengröße + Rand für Bilder.
      final section = out.sections!.add();
      section.pageSettings.size = sz;
      section.pageSettings.margins.all = marginPt;
      final page = section.pages.add();

      final client = page.getClientSize();
      final img = PdfBitmap(bytes);

      final imgRatio = img.width / img.height;
      final boxRatio = client.width / client.height;

      double w, h, x, y;
      if (imgRatio > boxRatio) {
        w = client.width;
        h = w / imgRatio;
        x = 0;
        y = (client.height - h) / 2;
      } else {
        h = client.height;
        w = h * imgRatio;
        x = (client.width - w) / 2;
        y = 0;
      }
      page.graphics.drawImage(img, ui.Rect.fromLTWH(x, y, w, h));
    } else {
      // PDF-Seiten 1:1 in Originalgröße übernehmen.
      final src = PdfDocument(inputBytes: await File(it.path).readAsBytes());
      for (int i = 0; i < src.pages.count; i++) {
        final srcPage = src.pages[i];
        final template = srcPage.createTemplate();
        final section = out.sections!.add();
        section.pageSettings.size = srcPage.size;
        section.pageSettings.margins.all = 0;
        final page = section.pages.add();
        page.graphics.drawPdfTemplate(template, const ui.Offset(0, 0));
      }
      src.dispose();
    }
  }

  final bytes = await out.save();
  out.dispose();
  return Uint8List.fromList(bytes);
}