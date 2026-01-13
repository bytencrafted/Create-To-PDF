import 'dart:io';

/// Abstrakte Strategie für DOCX->PDF.
abstract class DocxToPdfStrategy {
  Future<File> convert({required File docxFile, String? baseFileName});
}

/// Platzhalter für On-Device (Syncfusion).
/// -> Aktivierbar, wenn du die Pakete und Lizenzen setzt.
class DocxToPdfSyncfusionStrategy implements DocxToPdfStrategy {
  @override
  Future<File> convert({required File docxFile, String? baseFileName}) async {
    // TODO: Implementieren, sobald syncfusion_* eingebunden ist.
    // Hier würdest du das DOCX laden und nach PDF rendern.
    throw UnimplementedError(
      'Syncfusion-Strategie nicht aktiviert. Nutze RemoteStrategy oder binde Syncfusion ein.',
    );
  }
}

/// Remote-Strategie: Schickt die DOCX an einen HTTP-Endpunkt, der PDF zurückgibt.
/// Beispiel: Ein kleiner Service mit LibreOffice (unoconv) in Docker.
class DocxToPdfRemoteStrategy implements DocxToPdfStrategy {
  final Uri endpoint; // z. B. https://your-domain/convert/docx-to-pdf
  DocxToPdfRemoteStrategy(this.endpoint);

  @override
  Future<File> convert({required File docxFile, String? baseFileName}) async {
    // Implementierung in WordConvertService (wegen http dependency)
    throw UnimplementedError(
        'Wird im WordConvertService per http-Upload ausgeführt.');
  }
}
