import 'dart:io';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';

import '../models/pdf_options.dart';

class PdfService {
  Future<File> buildPdfFromImages({
    required List<XFile> images,
    String? baseFileName,
    PdfOptions options = const PdfOptions(),
    pw.BoxFit fit = pw.BoxFit.contain,
  }) async {
    if (images.isEmpty) {
      throw ArgumentError('Keine Bilder übergeben.');
    }

    final pdf = pw.Document();
    final pageFormat = options.toFormat();

    for (final x in images) {
      final bytes = await File(x.path).readAsBytes();
      final img = pw.MemoryImage(bytes);
      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          build: (ctx) => pw.Center(
            child: pw.FittedBox(
              fit: fit,
              child: pw.Image(img),
            ),
          ),
        ),
      );
    }

    final Uint8List pdfBytes = await pdf.save();
    final dir = await getApplicationDocumentsDirectory();
    final fileName =
        '${(baseFileName?.trim().isNotEmpty ?? false) ? baseFileName!.trim() : 'create_to_pdf'}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(pdfBytes, flush: true);
    return file;
  }
}
