import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

import '../../models/input_entry.dart';
import '../../models/pdf_options.dart';
import '../../services/pdf_tools_service.dart';
import '../../services/share_service.dart';
import '../../localization/app_lang.dart';
import '../../ui/common_widgets.dart';
import '../pdf_tools/pdf_tools_page.dart';
import '../preview/pdf_preview_page.dart';

const _kRed = Color(0xFFE53935);
const _kRedTint = Color(0xFFFCE9E8);
const _kField = Color(0xFFF1F2F5);
const _kText = Color(0xFF1A1B1F);
const _kTextDim = Color(0xFF6E7077);

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _pdfTools = PdfToolsService();
  final _shareService = ShareService();

  final List<InputEntry> _items = [];
  final Set<int> _selected = {};

  bool _isBusy = false;

  final TextEditingController _fileNameCtrl = TextEditingController();
  PageSize _size = PageSize.a4;
  PdfOrientation _orientation = PdfOrientation.portrait;
  double _marginMm = 10.0;

  File? _currentPdf;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureLanguageSelectedOnce());
  }

  Future<void> _ensureLanguageSelectedOnce() async {
    final lang = AppLang.of(context);
    if (!lang.initialized) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    if (!mounted) return;
    if (!lang.hasUserChoice) {
      await _showLanguageDialog(firstRun: true);
    }
  }

  @override
  void dispose() {
    _fileNameCtrl.dispose();
    super.dispose();
  }

  // --- WORKFLOWS (Import) ---

  Future<void> _addFromCamera() async {
    final img = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 2000,
      maxHeight: 2000,
      imageQuality: 85,
    );
    if (img == null || !mounted) return;
    setState(() => _items.add(InputEntry(ItemType.image, img.path, img.name)));
  }

  Future<void> _addFromGallery() async {
    final imgs = await ImagePicker().pickMultiImage(
      maxWidth: 2000,
      maxHeight: 2000,
      imageQuality: 85,
    );
    if (imgs.isEmpty || !mounted) return;
    setState(() {
      for (final x in imgs) {
        _items.add(InputEntry(ItemType.image, x.path, x.name));
      }
    });
  }

  Future<void> _addFromFiles() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (res == null || res.files.isEmpty || !mounted) return;
    setState(() {
      for (final f in res.files) {
        if (f.path != null) {
          _items.add(InputEntry(ItemType.image, f.path!, f.name));
        }
      }
    });
  }

  Future<void> _addPdfFromDevice({bool openToolsAfter = false}) async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowMultiple: false,
      allowedExtensions: ['pdf'],
    );
    if (res == null || res.files.isEmpty) return;
    final f = res.files.first;
    if (f.path == null) return;

    final file = File(f.path!);
    setState(() {
      _items.add(InputEntry(ItemType.pdf, file.path, f.name));
      _currentPdf = file;
    });

    if (!mounted) return;
    if (openToolsAfter && _currentPdf != null) {
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PdfToolsPage(
          currentPdf: _currentPdf!,
          onCurrentChanged: (f) => setState(() => _currentPdf = f),
          onProtect: _protectCurrentPdf,
          onReorder: _reorderCurrentPdf,
          onDeletePages: _deletePagesCurrentPdf,
          onCompress: _compressCurrentPdf,
          onHeaderFooter: _headerFooterCurrentPdf,
          onShare: _shareCurrentPdf,
        ),
      ));
    }
  }

  void _removeAt(int index) {
    setState(() {
      _items.removeAt(index);
      _selected.remove(index);
      final updated = <int>{};
      for (final i in _selected) {
        updated.add(i > index ? i - 1 : i);
      }
      _selected
        ..clear()
        ..addAll(updated);
    });
  }

  String _stripExt(String name) {
    final base = p.basenameWithoutExtension(name.trim());
    return base.isEmpty ? 'create_to_pdf' : base;
  }

  String _desiredOutputName(List<int> useIndices) {
    final manual = _fileNameCtrl.text.trim();
    if (manual.isNotEmpty) return _stripExt(manual);

    if (useIndices.isNotEmpty) {
      final first = _items[useIndices.first];
      final candidate = first.name.isNotEmpty ? first.name : p.basename(first.path);
      return _stripExt(candidate);
    }
    if (_items.isNotEmpty) {
      final candidate =
          _items.first.name.isNotEmpty ? _items.first.name : p.basename(_items.first.path);
      return _stripExt(candidate);
    }
    return 'create_to_pdf';
  }

  Future<File> _renameToDesiredName(File file, String baseNameWithoutExt) async {
    final dir = file.parent;
    final target = File(p.join(dir.path, '$baseNameWithoutExt.pdf'));
    if (target.path == file.path) return file;
    try {
      if (await target.exists()) await target.delete();
      return await file.rename(target.path);
    } catch (_) {
      await file.copy(target.path);
      await file.delete();
      return target;
    }
  }

  Future<void> _openPreview() async {
    final tr = AppLang.of(context).t;
    final useIndices =
        _selected.isEmpty ? List.generate(_items.length, (i) => i) : (_selected.toList()..sort());
    if (useIndices.isEmpty) {
      _toast(tr('no_selection'));
      return;
    }
    setState(() => _isBusy = true);
    try {
      final opts = PdfOptions(size: _size, orientation: _orientation, marginMm: _marginMm);
      final mixed = <MixedInput>[];
      for (final i in useIndices) {
        final it = _items[i];
        mixed.add(it.isImage ? MixedInput.image(it.path) : MixedInput.pdf(it.path));
      }
      final tmp = await _pdfTools.composeMixedPdf(
        mixed,
        options: opts,
        baseName: 'preview_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PdfPreviewPage(file: tmp),
        fullscreenDialog: true,
      ));

      try {
        if (await tmp.exists()) await tmp.delete();
      } catch (_) {}
    } catch (e) {
      _toast('${tr('preview_failed')}: $e');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _buildAndSharePdf() async {
    final tr = AppLang.of(context).t;
    final useIndices =
        _selected.isEmpty ? List.generate(_items.length, (i) => i) : (_selected.toList()..sort());
    if (useIndices.isEmpty) {
      _toast(tr('no_selection'));
      return;
    }

    setState(() => _isBusy = true);
    try {
      final opts = PdfOptions(size: _size, orientation: _orientation, marginMm: _marginMm);
      final mixed = <MixedInput>[];
      for (final i in useIndices) {
        final it = _items[i];
        mixed.add(it.isImage ? MixedInput.image(it.path) : MixedInput.pdf(it.path));
      }

      final desiredBase = _desiredOutputName(useIndices);
      final tmpFile =
          await _pdfTools.composeMixedPdf(mixed, options: opts, baseName: desiredBase);
      final finalFile = await _renameToDesiredName(tmpFile, desiredBase);

      _currentPdf = finalFile;
      await _shareService.shareFile(finalFile, text: tr('generated_pdf_text'));
    } catch (e) {
      if (e.toString().contains('Out of Memory')) {
        _toast(tr('out_of_memory'));
      } else {
        _toast('${tr('error')}: $e');
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  // --- PDF-Tools-Callbacks ---

  Future<void> _shareCurrentPdf() async {
    if (_currentPdf != null) {
      await _shareService.shareFile(_currentPdf!, text: AppLang.of(context).t('pdf'));
    }
  }

  Future<File?> _protectCurrentPdf() async {
    final tr = AppLang.of(context).t;
    final userPwd = await _promptString(title: tr('set_password'), label: tr('user_password'));
    if (userPwd == null || userPwd.isEmpty || _currentPdf == null || !mounted) return null;
    final ownerPwd =
        await _promptString(title: tr('set_password'), label: tr('owner_password_optional'));

    try {
      final out = await _pdfTools.protectPdf(
        _currentPdf!,
        userPassword: userPwd,
        ownerPassword: ownerPwd,
        baseName: _fileNameCtrl.text.isEmpty ? 'protected' : _fileNameCtrl.text,
      );
      _currentPdf = out;
      _toast(tr('password_set'));
      return out;
    } catch (e) {
      _toast('${tr('encryption_failed')}: $e');
      return null;
    }
  }

  Future<File?> _reorderCurrentPdf() async {
    final tr = AppLang.of(context).t;
    if (_currentPdf == null) return null;
    try {
      final count = await _pdfTools.pageCount(_currentPdf!);
      if (!mounted) return null;
      final order = await Navigator.of(context).push<List<int>>(
        MaterialPageRoute(builder: (_) => PageReorderPage(pageCount: count)),
      );
      if (order == null) return null;

      final out = await _pdfTools.reorderPages(
        _currentPdf!,
        order,
        baseName: _fileNameCtrl.text.isEmpty ? 'reordered' : _fileNameCtrl.text,
      );
      _currentPdf = out;
      _toast(tr('reorder_done'));
      return out;
    } catch (e) {
      _toast('${tr('reorder_failed')}: $e');
      return null;
    }
  }

  Future<File?> _deletePagesCurrentPdf() async {
    final tr = AppLang.of(context).t;
    if (_currentPdf == null) return null;
    try {
      final count = await _pdfTools.pageCount(_currentPdf!);
      if (!mounted) return null;
      final del = await Navigator.of(context).push<List<int>>(
        MaterialPageRoute(builder: (_) => PageDeletePage(pageCount: count)),
      );
      if (del == null || del.isEmpty) return null;

      final out = await _pdfTools.deletePages(
        _currentPdf!,
        del,
        baseName: _fileNameCtrl.text.isEmpty ? 'trimmed' : _fileNameCtrl.text,
      );
      _currentPdf = out;
      _toast(tr('pages_deleted'));
      return out;
    } catch (e) {
      _toast('${tr('delete_failed')}: $e');
      return null;
    }
  }

  Future<File?> _compressCurrentPdf() async {
    final tr = AppLang.of(context).t;
    if (_currentPdf == null) return null;
    try {
      final out = await _pdfTools.compressPdf(
        _currentPdf!,
        baseName: _fileNameCtrl.text.isEmpty ? 'optimized' : _fileNameCtrl.text,
      );
      _currentPdf = out;
      _toast(tr('pdf_compressed'));
      return out;
    } catch (e) {
      _toast('${tr('compress_failed')}: $e');
      return null;
    }
  }

  Future<File?> _headerFooterCurrentPdf() async {
    final lang = AppLang.of(context);
    final tr = lang.t;
    if (_currentPdf == null) return null;

    final header = await _promptString(title: tr('header_title'), label: tr('header_label'));
    if (!mounted) return null;
    final footer = await _promptString(title: tr('footer_title'), label: tr('footer_label'));
    if (!mounted) return null;

    final withPages = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('show_page_numbers_q')),
        content: Text(tr('show_page_numbers_desc')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('no'))),
          ElevatedButton(onPressed: () => Navigator.pop(c, true), child: Text(tr('yes'))),
        ],
      ),
    );

    try {
      final out = await _pdfTools.addHeaderFooter(
        _currentPdf!,
        headerText: header,
        footerLeft: footer,
        showPageNumber: withPages ?? true,
        pageNumberFormat: tr('page_x_of_y'),
        baseName: _fileNameCtrl.text.isEmpty ? 'header_footer' : _fileNameCtrl.text,
      );
      _currentPdf = out;
      _toast(tr('header_footer_set'));
      return out;
    } catch (e) {
      _toast('${tr('header_footer_failed')}: $e');
      return null;
    }
  }

  Future<String?> _promptString(
      {required String title, required String label, String? hint, String? initial}) async {
    final tr = AppLang.of(context).t;
    final ctrl = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(labelText: label, hintText: hint),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(tr('cancel'))),
          ElevatedButton(onPressed: () => Navigator.pop(c, ctrl.text), child: Text(tr('ok'))),
        ],
      ),
    );
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _showLanguageDialog({bool firstRun = false}) async {
    final lang = AppLang.of(context);
    final tr = lang.t;
    await showDialog<void>(
      context: context,
      barrierDismissible: !firstRun,
      builder: (c) => AlertDialog(
        title: Text(tr('language_select_title')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in const [
              ('de', 'german'),
              ('en', 'english'),
              ('fr', 'french'),
              ('pt', 'portuguese'),
            ])
              ListTile(
                leading: const Icon(Icons.language),
                title: Text(tr(entry.$2)),
                onTap: () async {
                  await lang.setLanguage(entry.$1);
                  if (mounted) Navigator.pop(c);
                },
              ),
          ],
        ),
        actions: firstRun
            ? null
            : [TextButton(onPressed: () => Navigator.pop(c), child: Text(tr('cancel')))],
      ),
    );
  }

  // --- Optionen als Bottom-Sheet (modern, hält die Startseite aufgeräumt) ---
  Future<void> _openOptionsSheet() async {
    final tr = AppLang.of(context).t;

    InputDecoration decor(String label) => InputDecoration(
          labelText: label,
          filled: true,
          fillColor: _kField,
          labelStyle: const TextStyle(color: _kTextDim),
          floatingLabelStyle: const TextStyle(color: _kRed),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(color: _kRed, width: 1.5),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: BorderSide.none,
          ),
        );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                  20, 12, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD8D9DD),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      const Icon(Icons.tune, color: _kRed, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        tr('options'),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: _kText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _fileNameCtrl,
                    decoration: decor(tr('file_name_optional'))
                        .copyWith(prefixIcon: const Icon(Icons.edit_note_outlined)),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<PageSize>(
                          value: _size,
                          decoration: decor(tr('page_size')),
                          borderRadius: BorderRadius.circular(13),
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(value: PageSize.a4, child: Text('A4')),
                            DropdownMenuItem(value: PageSize.letter, child: Text('Letter')),
                          ],
                          onChanged: (v) {
                            setState(() => _size = v ?? PageSize.a4);
                            setSheet(() {});
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<PdfOrientation>(
                          value: _orientation,
                          decoration: decor(tr('orientation')),
                          borderRadius: BorderRadius.circular(13),
                          isExpanded: true,
                          items: [
                            DropdownMenuItem(
                                value: PdfOrientation.portrait, child: Text(tr('portrait'))),
                            DropdownMenuItem(
                                value: PdfOrientation.landscape, child: Text(tr('landscape'))),
                          ],
                          onChanged: (v) {
                            setState(() => _orientation = v ?? PdfOrientation.portrait);
                            setSheet(() {});
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: _marginMm.toStringAsFixed(0),
                    decoration: decor(tr('margin_mm')),
                    keyboardType: TextInputType.number,
                    onChanged: (v) {
                      final parsed = double.tryParse(v.replaceAll(',', '.'));
                      if (parsed != null && parsed >= 0 && parsed <= 50) _marginMm = parsed;
                    },
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(tr('done')),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLang.of(context).t;
    final canGenerate = !_isBusy && _items.isNotEmpty;

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            titleSpacing: 16,
            title: AppTitle(text: tr('app_title')),
            actions: [
              IconButton(
                tooltip: tr('options'),
                icon: const Icon(Icons.tune),
                onPressed: _openOptionsSheet,
              ),
              IconButton(
                tooltip: tr('language'),
                icon: const Icon(Icons.translate),
                onPressed: () => _showLanguageDialog(firstRun: false),
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: SafeArea(
            top: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: _buildActionTiles(tr),
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Row(
                    children: [
                      Text(
                        tr('files').toUpperCase(),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                          color: _kTextDim,
                        ),
                      ),
                      if (_items.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _kRedTint,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_items.length}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _kRed,
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (_items.isNotEmpty)
                        TextButton.icon(
                          onPressed: canGenerate ? _openPreview : null,
                          icon: const Icon(Icons.visibility_outlined, size: 18),
                          label: Text(tr('preview')),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _items.isEmpty
                      ? EmptyState(text: tr('no_items'))
                      : _buildReorderableList(tr),
                ),
              ],
            ),
          ),
          bottomNavigationBar: _buildBottomBar(tr, canGenerate),
        ),
        if (_isBusy) _buildBusyOverlay(tr),
      ],
    );
  }

  Widget _buildActionTiles(String Function(String) tr) {
    return Row(
      children: [
        Expanded(
          child: ActionTile(
            icon: Icons.photo_camera_outlined,
            label: tr('camera'),
            primary: true,
            onTap: _addFromCamera,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ActionTile(
            icon: Icons.photo_library_outlined,
            label: tr('gallery'),
            onTap: _addFromGallery,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ActionTile(
            icon: Icons.picture_as_pdf_outlined,
            label: tr('pdf'),
            onTap: () => _addPdfFromDevice(openToolsAfter: false),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ActionTile(
            icon: Icons.build_outlined,
            label: tr('pdf_tools'),
            onTap: () => _addPdfFromDevice(openToolsAfter: true),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(String Function(String) tr, bool canGenerate) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.black.withOpacity(0.06))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              onPressed: canGenerate ? _buildAndSharePdf : null,
              icon: const Icon(Icons.ios_share_rounded, size: 20),
              label: Text(tr('generate_pdf')),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBusyOverlay(String Function(String) tr) {
    return Positioned.fill(
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 240),
        tween: Tween(begin: 0.0, end: 1.0),
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Container(
              color: Colors.black.withOpacity(0.40 * value),
              child: Center(
                child: SurfaceCard(
                  radius: 20,
                  padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 30,
                        height: 30,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        tr('generating_pdf'),
                        style: const TextStyle(
                          color: _kText,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        tr('please_wait'),
                        style: const TextStyle(color: _kTextDim, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildReorderableList(String Function(String) tr) {
    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final it = _items[index];
        final selected = _selected.contains(index);

        final tile = ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          leading: it.isImage
              ? ImageThumb(path: it.path)
              : Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: _kRedTint,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(Icons.picture_as_pdf_rounded, color: _kRed),
                ),
          title: Text(
            it.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5, color: _kText),
          ),
          subtitle: Text(
            it.isPdf ? 'PDF' : (it.isImage ? tr('gallery') : it.path),
            style: const TextStyle(color: _kTextDim, fontSize: 12.5),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) const Icon(Icons.check_circle, color: _kRed, size: 20),
              const SizedBox(width: 6),
              ReorderableDragStartListener(
                index: index,
                child: const Icon(Icons.drag_indicator, color: Color(0xFFB4B5BB)),
              ),
            ],
          ),
          onLongPress: () {
            if (_isBusy) return;
            setState(() {
              if (selected) {
                _selected.remove(index);
              } else {
                _selected.add(index);
              }
            });
          },
          onTap: () {
            if (_isBusy) return;
            if (_selected.isNotEmpty) {
              setState(() {
                if (selected) {
                  _selected.remove(index);
                } else {
                  _selected.add(index);
                }
              });
            }
          },
        );

        return Padding(
          key: ValueKey('item-${it.id}'),
          padding: const EdgeInsets.only(bottom: 10),
          child: Dismissible(
            key: ValueKey('dismiss-${it.id}'),
            direction: DismissDirection.endToStart,
            onDismissed: (_) => _removeAt(index),
            background: Container(
              decoration: BoxDecoration(
                color: _kRed,
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: const Icon(Icons.delete_outline, color: Colors.white),
            ),
            child: Container(
              decoration: BoxDecoration(
                color: selected ? _kRedTint : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? _kRed.withOpacity(0.45) : Colors.black.withOpacity(0.06),
                ),
              ),
              child: tile,
            ),
          ),
        );
      },
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (newIndex > oldIndex) newIndex -= 1;
          final item = _items.removeAt(oldIndex);
          _items.insert(newIndex, item);

          final moved = <int>{};
          for (final i in _selected) {
            if (i == oldIndex) {
              moved.add(newIndex);
            } else if (oldIndex < i && i <= newIndex) {
              moved.add(i - 1);
            } else if (newIndex <= i && i < oldIndex) {
              moved.add(i + 1);
            } else {
              moved.add(i);
            }
          }
          _selected
            ..clear()
            ..addAll(moved);
        });
      },
    );
  }
}