import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../localization/app_lang.dart';

class PdfPreviewPage extends StatelessWidget {
  final File file;
  const PdfPreviewPage({super.key, required this.file});

  @override
  Widget build(BuildContext context) {
    final tr = AppLang.of(context).t;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('preview')),
        actions: [
          IconButton(
            tooltip: tr('close'),
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: SfPdfViewer.file(
        file,
        canShowScrollHead: true,
        canShowScrollStatus: true,
        enableDoubleTapZooming: true,
      ),
    );
  }
}