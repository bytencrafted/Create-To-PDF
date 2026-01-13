import 'dart:io';
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

/// Utility-Service für PDF-Operationen (merge, encrypt, pages, compress, headers/footers, compose).
class PdfToolsService {
  /// Speichert Bytes als Datei im App-Dokumentenordner.
  Future<File> _saveBytes(List<int> bytes, {required String baseName}) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/${baseName}_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Lädt ein PDF aus File.
  Future<PdfDocument> _loadDoc(File file) async {
    final bytes = await file.readAsBytes();
    return PdfDocument(inputBytes: bytes);
  }

  /// Merge mehrerer PDFs zu einem.
  Future<File> mergePdfs(List<File> pdfFiles, {String baseName = 'merged'}) async {
    if (pdfFiles.isEmpty) throw ArgumentError('Keine PDFs gewählt.');
    if (pdfFiles.length == 1) return pdfFiles.first;

    final out = PdfDocument();
    for (final f in pdfFiles) {
      final src = await _loadDoc(f);
      for (int i = 0; i < src.pages.count; i++) {
        final tpl = src.pages[i].createTemplate();
        final page = out.pages.add();
        page.graphics.drawPdfTemplate(tpl, const ui.Offset(0, 0));
      }
      src.dispose();
    }
    final bytes = await out.save();
    out.dispose();
    return _saveBytes(bytes, baseName: baseName);
  }

  /// Passwort setzen (userPwd/ownerPwd optional).
  Future<File> protectPdf(
      File pdf, {
        required String userPassword,
        String? ownerPassword,
        String baseName = 'protected',
      }) async {
    final doc = await _loadDoc(pdf);
    doc.security.userPassword = userPassword;
    if (ownerPassword != null && ownerPassword.isNotEmpty) {
      doc.security.ownerPassword = ownerPassword;
    }
    // Beispiel-Berechtigungen:
    doc.security.permissions
      ..add(PdfPermissionsFlags.print)
      ..remove(PdfPermissionsFlags.copyContent);

    final bytes = await doc.save();
    doc.dispose();
    return _saveBytes(bytes, baseName: baseName);
  }

  /// Seitenreihenfolge ändern: Liste neuer Indizes (0-basiert).
  Future<File> reorderPages(File pdf, List<int> newOrder, {String baseName = 'reordered'}) async {
    final src = await _loadDoc(pdf);
    if (newOrder.length != src.pages.count) {
      throw ArgumentError('Anzahl in newOrder muss ${src.pages.count} sein.');
    }
    final out = PdfDocument();
    for (final idx in newOrder) {
      if (idx < 0 || idx >= src.pages.count) {
        throw ArgumentError('Ungültiger Index $idx');
      }
      final tpl = src.pages[idx].createTemplate();
      final page = out.pages.add();
      page.graphics.drawPdfTemplate(tpl, const ui.Offset(0, 0));
    }
    final bytes = await out.save();
    src.dispose();
    out.dispose();
    return _saveBytes(bytes, baseName: baseName);
  }

  /// Seiten löschen: Indizes 0-basiert übergeben.
  Future<File> deletePages(File pdf, List<int> removeIndices, {String baseName = 'trimmed'}) async {
    final doc = await _loadDoc(pdf);
    final toRemove = removeIndices.toSet().toList()..sort((a, b) => b.compareTo(a)); // absteigend
    for (final idx in toRemove) {
      if (idx >= 0 && idx < doc.pages.count) {
        doc.pages.removeAt(idx);
      }
    }
    final bytes = await doc.save();
    doc.dispose();
    return _saveBytes(bytes, baseName: baseName);
  }

  /// Einfache Komprimierung (Objektkompression + Rebuild).
  Future<File> compressPdf(File pdf, {int jpegQuality = 60, String baseName = 'compressed'}) async {
    final src = await _loadDoc(pdf);
    src.compressionLevel = PdfCompressionLevel.best;

    final out = PdfDocument();
    out.compressionLevel = PdfCompressionLevel.best;

    for (int i = 0; i < src.pages.count; i++) {
      final tpl = src.pages[i].createTemplate();
      final page = out.pages.add();
      page.graphics.drawPdfTemplate(tpl, const ui.Offset(0, 0));
    }

    final bytes = await out.save();
    src.dispose();
    out.dispose();
    return _saveBytes(bytes, baseName: baseName);
  }

  /// Kopf-/Fußzeilen hinzufügen.
  Future<File> addHeaderFooter(
      File pdf, {
        String? headerText,
        String? footerLeft,
        bool showPageNumber = true,
        String baseName = 'header_footer',
      }) async {
    final doc = await _loadDoc(pdf);

    // Header
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

    // Footer
    final footer = PdfPageTemplateElement(const ui.Rect.fromLTWH(0, 0, 500, 40));
    if (footerLeft != null && footerLeft.isNotEmpty) {
      footer.graphics.drawString(
        footerLeft,
        PdfStandardFont(PdfFontFamily.helvetica, 10),
        bounds: const ui.Rect.fromLTWH(12, 10, 300, 20),
      );
    }
    if (showPageNumber) {
      footer.graphics.drawString(
        'Seite {0} von {1}',
        PdfStandardFont(PdfFontFamily.helvetica, 10),
        bounds: const ui.Rect.fromLTWH(350, 10, 140, 20),
        format: PdfStringFormat(alignment: PdfTextAlignment.right),
      );
    }
    doc.template.bottom = footer;

    final bytes = await doc.save();
    doc.dispose();
    return _saveBytes(bytes, baseName: baseName);
  }

  // ---------- Gemischte Komposition (Bilder + PDFs in Reihenfolge) ----------

  /// Baut ein PDF aus einer gemischten Reihenfolge (Bilder & PDFs).
  /// Bilder werden als Seiten mit vorgegebenem Format/Marge gerendert,
  /// PDFs werden seitenweise übertragen. Die Reihenfolge der [items] bleibt erhalten.
  Future<File> composeMixedPdf(
      List<MixedInput> items, {
        required PdfOptions options,
        String baseName = 'mixed',
      }) async {
    if (items.isEmpty) {
      throw ArgumentError('Keine Eingaben übergeben.');
    }

    // Seitengröße in pt passend zu PdfOptions:
    ui.Size _sizeFromOptions() {
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

    final ui.Size sz = _sizeFromOptions();
    final double marginPt = options.marginMm * 72.0 / 25.4;

    final out = PdfDocument();

    // Seitengröße setzen
    out.pageSettings.size = ui.Size(sz.width, sz.height);

    // Margins robust setzen (per Properties)
    final margins = PdfMargins();
    margins.left = marginPt;
    margins.right = marginPt;
    margins.top = marginPt;
    margins.bottom = marginPt;
    out.pageSettings.margins = margins;

    for (final it in items) {
      if (it.isImage) {
        final bytes = await File(it.path).readAsBytes();
        final page = out.pages.add();
        final client = page.getClientSize();
        final img = PdfBitmap(bytes);

        // Bild proportional innerhalb des Clientbereichs zeichnen:
        final imgRatio = img.width / img.height;
        final boxRatio = client.width / client.height;

        double w, h, x, y;
        if (imgRatio > boxRatio) {
          // Breiter als Box -> an Breite anpassen
          w = client.width;
          h = w / imgRatio;
          x = 0;
          y = (client.height - h) / 2;
        } else {
          // Höher -> an Höhe anpassen
          h = client.height;
          w = h * imgRatio;
          x = (client.width - w) / 2;
          y = 0;
        }
        page.graphics.drawImage(img, ui.Rect.fromLTWH(x, y, w, h));
      } else {
        // PDF: Seiten übertragen
        final src = await _loadDoc(File(it.path));
        for (int i = 0; i < src.pages.count; i++) {
          final tpl = src.pages[i].createTemplate();
          final page = out.pages.add();
          page.graphics.drawPdfTemplate(tpl, const ui.Offset(0, 0));
        }
        src.dispose();
      }
    }

    final bytes = await out.save();
    out.dispose();
    return _saveBytes(bytes, baseName: baseName);
  }
}
