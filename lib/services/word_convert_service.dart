import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'word_convert_strategies.dart';

class WordConvertService {
  DocxToPdfStrategy strategy;

  WordConvertService({required this.strategy});

  /// Remote-Konvertierung (Multipart Upload).
  /// Wenn strategy DocxToPdfRemoteStrategy ist, wird hier hochgeladen.
  Future<File> convertDocxToPdfRemote({
    required File docxFile,
    required Uri endpoint,
    String? baseFileName,
  }) async {
    final req = http.MultipartRequest('POST', endpoint);
    req.files.add(await http.MultipartFile.fromPath('file', docxFile.path));
    final resp = await req.send();

    if (resp.statusCode != 200) {
      final body = await resp.stream.bytesToString();
      throw Exception('Konvertierung fehlgeschlagen (${resp.statusCode}): $body');
    }

    final bytes = await resp.stream.toBytes();
    final dir = await getApplicationDocumentsDirectory();
    final fileName =
        '${(baseFileName?.trim().isNotEmpty ?? false) ? baseFileName!.trim() : 'docx_to_pdf'}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final out = File('${dir.path}/$fileName');
    await out.writeAsBytes(bytes, flush: true);
    return out;
  }
}
