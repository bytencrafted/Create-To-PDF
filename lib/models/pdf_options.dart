/// Reine Datenklasse für die PDF-Optionen.
///
/// Hinweis: Die frühere `toFormat()`-Methode (Paket `pdf`) wurde entfernt –
/// sie war toter Code, weil die Komposition komplett über Syncfusion läuft.
/// Damit fällt auch die Abhängigkeit zum `pdf`-Paket weg.

enum PageSize { a4, letter }

enum PdfOrientation { portrait, landscape }

class PdfOptions {
  final PageSize size;
  final PdfOrientation orientation;
  final double marginMm; // in mm

  const PdfOptions({
    this.size = PageSize.a4,
    this.orientation = PdfOrientation.portrait,
    this.marginMm = 10.0,
  });

  /// Rand in PDF-Punkten (1 mm = 72/25.4 pt).
  double get marginPt => marginMm * 72.0 / 25.4;
}