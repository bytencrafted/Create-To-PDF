import 'package:pdf/pdf.dart';

enum PageSize { a4, letter }
enum PdfOrientation { portrait, landscape }

class PdfOptions {
  final PageSize size;
  final PdfOrientation orientation;
  final double marginMm; // mm

  const PdfOptions({
    this.size = PageSize.a4,
    this.orientation = PdfOrientation.portrait,
    this.marginMm = 20.0,
  });

  PdfPageFormat toFormat() {
    PdfPageFormat fmt = switch (size) {
      PageSize.a4 => PdfPageFormat.a4,
      PageSize.letter => PdfPageFormat.letter,
    };

    if (orientation == PdfOrientation.landscape) {
      // Breite/Höhe tauschen für Querformat
      fmt = PdfPageFormat(fmt.height, fmt.width);
    }

    final marginPt = marginMm * 72.0 / 25.4; // mm -> pt
    return fmt.copyWith(
      marginLeft: marginPt,
      marginRight: marginPt,
      marginTop: marginPt,
      marginBottom: marginPt,
    );
  }
}
