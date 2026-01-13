import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

class ImageService {
  final ImagePicker _picker = ImagePicker();

  Future<XFile?> pickFromCamera() async {
    return _picker.pickImage(source: ImageSource.camera);
  }

  Future<List<XFile>> pickFromGallery() async {
    final list = await _picker.pickMultiImage();
    return list;
  }

  /// Bisher: Bilder. Jetzt: PDFs auswählen (als Dateien, nicht XFile).
  /// -> Diese Methode bleibt für Bilder; PDF-Picking machen wir direkt in HomePage mit FilePicker.
  Future<List<XFile>> pickFromFiles() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowMultiple: true,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'heic', 'bmp'],
    );
    if (res == null || res.files.isEmpty) return [];
    return res.files
        .where((f) => f.path != null)
        .map((f) => XFile(f.path!))
        .toList();
  }
}
