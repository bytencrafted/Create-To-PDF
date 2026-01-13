import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'dart:math' as math;
import 'package:path/path.dart' as p;

import '../../models/pdf_options.dart';
import '../../services/image_service.dart';
import '../../services/pdf_service.dart';
import '../../services/share_service.dart';
import '../../services/pdf_tools_service.dart';
import '../../localization/app_lang.dart';

enum ItemType { image, pdf }

class InputEntry {
  final ItemType type;
  final String path;
  final String name;
  InputEntry(this.type, this.path, this.name);
  bool get isImage => type == ItemType.image;
  bool get isPdf => type == ItemType.pdf;
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  final _pdfService = PdfService();
  final _pdfTools = PdfToolsService();
  final _shareService = ShareService();

  final List<InputEntry> _items = [];
  final Set<int> _selected = {};

  bool _isBusy = false;    // PDF Generierung
  bool _isPicking = false; // Bilder Import

  final TextEditingController _fileNameCtrl = TextEditingController();
  PageSize _size = PageSize.a4;
  PdfOrientation _orientation = PdfOrientation.portrait;
  double _marginMm = 10.0;

  File? _currentPdf;

  late final AnimationController _pulse;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat(reverse: true);
    _glow = Tween<double>(begin: 0.35, end: 0.75).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
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
    _pulse.dispose();
    super.dispose();
  }

  // --- WORKFLOWS ---

  Future<void> _addFromCamera() async {
    final img = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 2000,
      maxHeight: 2000,
      imageQuality: 85,
    );

    if (img != null) {
      setState(() => _isPicking = true);
      // Kurze Verzögerung für UX (damit man das "Laden" kurz sieht und versteht, dass was passiert)
      await Future.delayed(const Duration(milliseconds: 400));

      if (mounted) {
        setState(() {
          _items.add(InputEntry(ItemType.image, img.path, img.name));
          _isPicking = false;
        });
      }
    }
  }

  Future<void> _addFromGallery() async {
    // 1. Bilder auswählen (UI wartet hier auf System-Picker)
    final List<XFile> imgs = await ImagePicker().pickMultiImage(
      maxWidth: 2000,
      maxHeight: 2000,
      imageQuality: 85,
    );

    // 2. Wenn Bilder da sind, Status auf "Picking" setzen -> Overlay erscheint
    if (imgs.isNotEmpty) {
      setState(() => _isPicking = true);

      // Künstliche Pause beim Start, damit das Overlay sicher gerendert wird und sichtbar ist
      await Future.delayed(const Duration(milliseconds: 100));

      for (final x in imgs) {
        _items.add(InputEntry(ItemType.image, x.path, x.name));
        // Kleine Pause pro Bild, damit der UI Thread atmen kann und der Spinner dreht
        await Future.delayed(const Duration(milliseconds: 50));
      }

      if (mounted) {
        setState(() => _isPicking = false);
      }
    }
  }

  Future<void> _addFromFiles() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );

    if (res != null && res.files.isNotEmpty) {
      setState(() => _isPicking = true);
      await Future.delayed(const Duration(milliseconds: 200));
      for (final f in res.files) {
        if (f.path != null) {
          _items.add(InputEntry(ItemType.image, f.path!, f.name));
        }
      }
      if (mounted) setState(() => _isPicking = false);
    }
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
      _items.add(InputEntry(ItemType.pdf, file.path, f.name ?? 'PDF'));
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
      _selected..clear()..addAll(updated);
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
      final candidate = _items.first.name.isNotEmpty ? _items.first.name : p.basename(_items.first.path);
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
    final useIndices = _selected.isEmpty ? List.generate(_items.length, (i) => i) : (_selected.toList()..sort());
    if (useIndices.isEmpty) {
      _toast('Keine Elemente ausgewählt.');
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
      _toast('Vorschau fehlgeschlagen: $e');
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _buildAndSharePdf() async {
    final useIndices = _selected.isEmpty ? List.generate(_items.length, (i) => i) : (_selected.toList()..sort());
    if (useIndices.isEmpty) {
      _toast('Keine Elemente ausgewählt.');
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
      final tmpFile = await _pdfTools.composeMixedPdf(
        mixed,
        options: opts,
        baseName: desiredBase,
      );
      final finalFile = await _renameToDesiredName(tmpFile, desiredBase);

      _currentPdf = finalFile;
      await _shareService.shareFile(finalFile, text: 'Mein erzeugtes PDF');
    } catch (e) {
      if (e.toString().contains("Out of Memory")) {
        _toast('Speicher voll. Versuche weniger Bilder.');
      } else {
        _toast('Fehler: $e');
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _shareCurrentPdf() async {
    if (_currentPdf != null) {
      await _shareService.shareFile(_currentPdf!, text: 'PDF');
    }
  }

  Future<File?> _protectCurrentPdf() async {
    final userPwd = await _promptString(title: 'Passwort setzen', label: 'User-Passwort');
    if (userPwd == null || userPwd.isEmpty || _currentPdf == null) return null;

    setState(() => _isBusy = true);
    try {
      final out = await _pdfTools.protectPdf(
        _currentPdf!,
        userPassword: userPwd,
        baseName: _fileNameCtrl.text.isEmpty ? 'protected' : _fileNameCtrl.text,
      );
      _currentPdf = out;
      _toast('Passwort gesetzt.');
      return out;
    } catch (e) {
      _toast('Verschlüsselung fehlgeschlagen: $e');
      return null;
    } finally {
      setState(() => _isBusy = false);
    }
  }

  Future<File?> _reorderCurrentPdf() async {
    if (_currentPdf == null) return null;
    final orderStr = await _promptString(
      title: 'Reihenfolge',
      label: 'Neue Reihenfolge (z. B. 1,3,2,4)',
      hint: '1-basierte Seitenindizes, alle Seiten angeben',
    );
    if (orderStr == null || orderStr.trim().isEmpty) return null;

    final parts = orderStr.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    final newOrder = <int>[];
    for (final p in parts) {
      final n = int.tryParse(p);
      if (n == null || n <= 0) {
        _toast('Ungültiger Wert: "$p"');
        return null;
      }
      newOrder.add(n - 1);
    }

    setState(() => _isBusy = true);
    try {
      final out = await _pdfTools.reorderPages(
        _currentPdf!, newOrder,
        baseName: _fileNameCtrl.text.isEmpty ? 'reordered' : _fileNameCtrl.text,
      );
      _currentPdf = out;
      _toast('Seitenreihenfolge geändert.');
      return out;
    } catch (e) {
      _toast('Reorder fehlgeschlagen: $e');
      return null;
    } finally {
      setState(() => _isBusy = false);
    }
  }

  Future<File?> _deletePagesCurrentPdf() async {
    if (_currentPdf == null) return null;
    final delStr = await _promptString(
      title: 'Seiten löschen',
      label: 'Zu löschende Seiten (z. B. 1,4,5)',
      hint: '1-basierte Indizes, beliebige Reihenfolge',
    );
    if (delStr == null || delStr.trim().isEmpty) return null;

    final parts = delStr.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    final del = <int>[];
    for (final p in parts) {
      final n = int.tryParse(p);
      if (n == null || n <= 0) {
        _toast('Ungültiger Wert: "$p"');
        return null;
      }
      del.add(n - 1);
    }

    setState(() => _isBusy = true);
    try {
      final out = await _pdfTools.deletePages(
        _currentPdf!, del,
        baseName: _fileNameCtrl.text.isEmpty ? 'trimmed' : _fileNameCtrl.text,
      );
      _currentPdf = out;
      _toast('Seiten gelöscht.');
      return out;
    } catch (e) {
      _toast('Löschen fehlgeschlagen: $e');
      return null;
    } finally {
      setState(() => _isBusy = false);
    }
  }

  Future<File?> _compressCurrentPdf() async {
    if (_currentPdf == null) return null;
    final q = await _promptString(
      title: 'Komprimieren',
      label: 'Qualität (0–100)',
      hint: 'Z. B. 60',
      initial: '60',
    );
    if (q == null) return null;
    final quality = int.tryParse(q) ?? 60;

    setState(() => _isBusy = true);
    try {
      final out = await _pdfTools.compressPdf(
        _currentPdf!, jpegQuality: quality,
        baseName: _fileNameCtrl.text.isEmpty ? 'compressed' : _fileNameCtrl.text,
      );
      _currentPdf = out;
      _toast('PDF komprimiert.');
      return out;
    } catch (e) {
      _toast('Komprimieren fehlgeschlagen: $e');
      return null;
    } finally {
      setState(() => _isBusy = false);
    }
  }

  Future<File?> _headerFooterCurrentPdf() async {
    if (_currentPdf == null) return null;
    final header = await _promptString(title: 'Kopfzeile', label: 'Text oben (optional)');
    final footer = await _promptString(title: 'Fußzeile', label: 'Text unten links (optional)');
    final withPages = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Seitenzahlen anzeigen?'),
        content: const Text('Soll „Seite X von Y“ in der Fußzeile stehen?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Nein')),
          ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('Ja')),
        ],
      ),
    );

    setState(() => _isBusy = true);
    try {
      final out = await _pdfTools.addHeaderFooter(
        _currentPdf!,
        headerText: header,
        footerLeft: footer,
        showPageNumber: withPages ?? true,
        baseName: _fileNameCtrl.text.isEmpty ? 'header_footer' : _fileNameCtrl.text,
      );
      _currentPdf = out;
      _toast('Kopf/Fußzeilen gesetzt.');
      return out;
    } catch (e) {
      _toast('Header/Footer fehlgeschlagen: $e');
      return null;
    } finally {
      setState(() => _isBusy = false);
    }
  }

  Future<String?> _promptString({required String title, required String label, String? hint, String? initial}) async {
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
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Abbrechen')),
          ElevatedButton(onPressed: () => Navigator.pop(c, ctrl.text), child: const Text('Ok')),
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
            ListTile(
              leading: const Text('🇩🇪', style: TextStyle(fontSize: 20)),
              title: Text(tr('german')),
              onTap: () async { await lang.setLanguage('de'); if (mounted) Navigator.pop(c); },
            ),
            ListTile(
              leading: const Text('🇬🇧', style: TextStyle(fontSize: 20)),
              title: Text(tr('english')),
              onTap: () async { await lang.setLanguage('en'); if (mounted) Navigator.pop(c); },
            ),
            ListTile(
              leading: const Text('🇫🇷', style: TextStyle(fontSize: 20)),
              title: Text(tr('french')),
              onTap: () async { await lang.setLanguage('fr'); if (mounted) Navigator.pop(c); },
            ),
            ListTile(
              leading: const Text('🇵🇹', style: TextStyle(fontSize: 20)),
              title: Text(tr('portuguese')),
              onTap: () async { await lang.setLanguage('pt'); if (mounted) Navigator.pop(c); },
            ),
          ],
        ),
        actions: firstRun ? null : [ TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')) ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final insets = MediaQuery.of(context).viewInsets;
    final kbOpen = insets.bottom > 0;
    const bottomPad = 0.0;
    final tr = AppLang.of(context).t;

    final bool canGenerate = !_isBusy && !_isPicking && _items.isNotEmpty;

    return Stack(
      children: [
        const _RedBlackBackground(),
        AnimatedBuilder(
          animation: _glow,
          builder: (context, _) {
            return _GlowBlob(
              size: 260,
              color: scheme.primary.withOpacity(_glow.value * 0.35),
              top: -40,
              left: -20,
              blur: 140,
            );
          },
        ),
        _GlowBlob(size: 220, color: scheme.primary.withOpacity(.22), bottom: 60, right: -30, blur: 120),
        SafeArea(
          child: Scaffold(
            resizeToAvoidBottomInset: false,
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              title: _AppTitle(text: tr('app_title')),
              actions: [
                IconButton(
                  tooltip: tr('language'),
                  icon: const Icon(Icons.translate),
                  onPressed: () => _showLanguageDialog(firstRun: false),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ElevatedButton.icon(
                    onPressed: canGenerate ? _buildAndSharePdf : null,
                    icon: const Icon(Icons.save_alt, size: 18),
                    label: Text(tr('generate_pdf')),
                  ),
                ),
              ],
            ),
            floatingActionButton: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: (kbOpen || _isPicking || _isBusy) ? const SizedBox.shrink() : _buildFab(context, scheme, tr),
            ),
            body: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, bottomPad),
              child: CustomScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  SliverToBoxAdapter(
                    child: GlassPanel(
                      borderRadius: BorderRadius.circular(28),
                      padding: const EdgeInsets.all(14),
                      child: _buildOptions(scheme, tr),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  if (_items.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          onPressed: canGenerate ? _openPreview : null,
                          icon: const Icon(Icons.visibility),
                          label: Text(tr('preview')),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ),
                  if (_items.isNotEmpty) const SliverToBoxAdapter(child: SizedBox(height: 8)),

                  // --- LISTE + IMPORT-OVERLAY ---
                  SliverFillRemaining(
                    hasScrollBody: true,
                    child: GlassPanel(
                      borderRadius: BorderRadius.circular(32),
                      padding: EdgeInsets.zero,
                      child: LayoutBuilder(
                        builder: (context, cons) {
                          if (_items.isEmpty && !_isPicking) {
                            return _EmptyState(text: tr('no_items'));
                          }
                          return Stack(
                            children: [
                              _buildReorderableList(tr),
                              // Hier kommt das "Bilder werden geladen" Overlay
                              if (_isPicking)
                                _buildPickingOverlay(scheme),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 14)),
                ],
              ),
            ),
          ),
        ),

        // --- PDF GENERATING OVERLAY (Global) ---
        if (_isBusy) _buildBusyOverlay(scheme),
      ],
    );
  }

  // --- OVERLAYS IMPLEMENTIERUNG ---

  // 1. Overlay für den Import in der Liste
  Widget _buildPickingOverlay(ColorScheme scheme) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          color: Colors.black.withOpacity(0.4),
          child: Center(
            // WICHTIG: Material Widget verhindert gelbe Unterstreichungen im Text!
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: scheme.primary),
                  const SizedBox(height: 20),
                  const Text(
                    "Bilder werden geladen...",
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 2. Overlay für die PDF-Erstellung (Vollbild)
  Widget _buildBusyOverlay(ColorScheme scheme) {
    return Positioned.fill(
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 300),
        tween: Tween(begin: 0.0, end: 1.0),
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10 * value, sigmaY: 10 * value),
              child: Container(
                color: Colors.black.withOpacity(0.6 * value),
                child: Center(
                  // WICHTIG: Material Widget für sauberen Text ohne gelbe Linien
                  child: Material(
                    type: MaterialType.transparency,
                    child: GlassPanel(
                      borderRadius: BorderRadius.circular(24),
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 32, height: 32,
                            child: CircularProgressIndicator(strokeWidth: 3),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            "PDF wird erzeugt",
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Bitte einen Moment Geduld...",
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 13
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // --- RESTLICHE UI WIDGETS ---

  Widget _buildFab(BuildContext context, ColorScheme scheme, String Function(String) tr) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _RoundFab(color: scheme.primary, icon: Icons.photo_camera, label: tr('camera'), onPressed: _addFromCamera),
        const SizedBox(height: 10),
        _RoundFab(
          color: Colors.white.withOpacity(.08),
          border: BorderSide(color: Colors.white.withOpacity(.16)),
          icon: Icons.photo_library,
          label: tr('gallery'),
          onPressed: _addFromGallery,
        ),
        const SizedBox(height: 10),
        _RoundFab(
          color: Colors.white.withOpacity(.08),
          border: BorderSide(color: Colors.white.withOpacity(.16)),
          icon: Icons.picture_as_pdf,
          label: tr('pdf'),
          onPressed: () => _addPdfFromDevice(openToolsAfter: false),
        ),
        const SizedBox(height: 10),
        _RoundFab(
          color: Colors.white.withOpacity(.08),
          border: BorderSide(color: Colors.white.withOpacity(.16)),
          icon: Icons.build_outlined,
          label: tr('pdf_tools'),
          onPressed: () => _addPdfFromDevice(openToolsAfter: true),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildOptions(ColorScheme scheme, String Function(String) tr) {
    final w = MediaQuery.of(context).size.width;
    final isNarrow = w < 380.0;
    final cappedMedia = MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0));

    InputDecoration _decor(String label) => InputDecoration(
      labelText: label,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
    );

    final sizeField = DropdownButtonFormField<PageSize>(
      value: _size,
      decoration: _decor(tr('page_size')),
      dropdownColor: Colors.black.withOpacity(.95),
      isExpanded: true,
      items: const [
        DropdownMenuItem(value: PageSize.a4, child: Text('A4')),
        DropdownMenuItem(value: PageSize.letter, child: Text('Letter')),
      ],
      onChanged: (v) => setState(() => _size = v ?? PageSize.a4),
    );

    final orientationField = DropdownButtonFormField<PdfOrientation>(
      value: _orientation,
      decoration: _decor(tr('orientation')),
      dropdownColor: Colors.black.withOpacity(.95),
      isExpanded: true,
      items: [
        DropdownMenuItem(value: PdfOrientation.portrait, child: Text(tr('portrait'))),
        DropdownMenuItem(value: PdfOrientation.landscape, child: Text(tr('landscape'))),
      ],
      onChanged: (v) => setState(() => _orientation = v ?? PdfOrientation.portrait),
    );

    final marginField = SizedBox(
      width: 118,
      child: TextFormField(
        initialValue: _marginMm.toStringAsFixed(0),
        style: const TextStyle(color: Colors.white),
        decoration: _decor(tr('margin_mm')),
        keyboardType: TextInputType.number,
        scrollPadding: const EdgeInsets.only(bottom: 120),
        onChanged: (v) {
          final parsed = double.tryParse(v.replaceAll(',', '.'));
          if (parsed != null && parsed >= 0 && parsed <= 50) _marginMm = parsed;
        },
      ),
    );

    return MediaQuery(
      data: cappedMedia,
      child: Column(
        children: [
          Row(children: [
            Expanded(
              child: TextField(
                controller: _fileNameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: _decor(tr('file_name_optional')).copyWith(prefixIcon: const Icon(Icons.edit_note)),
                scrollPadding: const EdgeInsets.only(bottom: 120),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          if (!isNarrow)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: sizeField),
                const SizedBox(width: 10),
                Expanded(child: orientationField),
                const SizedBox(width: 10),
                marginField,
              ],
            )
          else
            Column(
              children: [
                Row(
                  children: [
                    Expanded(child: sizeField),
                    const SizedBox(width: 10),
                    Expanded(child: orientationField),
                  ],
                ),
                const SizedBox(height: 10),
                Align(alignment: Alignment.centerLeft, child: marginField),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildReorderableList(String Function(String) tr) {
    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      padding: const EdgeInsets.all(12),
      itemBuilder: (context, index) {
        final it = _items[index];
        final selected = _selected.contains(index);

        final tile = ListTile(
          leading: it.isImage
              ? _Thumb(path: it.path)
              : CircleAvatar(
            backgroundColor: Colors.white.withOpacity(.08),
            child: const Icon(Icons.picture_as_pdf, color: Colors.white),
          ),
          title: Text(
            it.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            File(it.path).path,
            style: TextStyle(color: Colors.white.withOpacity(.6)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) const Icon(Icons.check_circle, color: Colors.lightGreenAccent),
              const SizedBox(width: 8),
              ReorderableDragStartListener(index: index, child: const Icon(Icons.drag_handle)),
            ],
          ),
          onLongPress: () {
            if (_isPicking || _isBusy) return;
            setState(() {
              if (selected) {
                _selected.remove(index);
              } else {
                _selected.add(index);
              }
            });
          },
          onTap: () {
            if (_isPicking || _isBusy) return;
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

        return Dismissible(
          key: ValueKey('${it.path}-$index'),
          background: Container(
            decoration: BoxDecoration(color: Colors.red.withOpacity(0.15), borderRadius: BorderRadius.circular(16)),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          direction: DismissDirection.endToStart,
          onDismissed: (_) => _removeAt(index),
          child: Card(
            key: ValueKey('card-${it.path}-$index'),
            color: selected ? Colors.white.withOpacity(.06) : null,
            child: tile,
          ),
        );
      },
      itemCount: _items.length,
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (newIndex > oldIndex) newIndex -= 1;
          final item = _items.removeAt(oldIndex);
          _items.insert(newIndex, item);

          final moved = <int>{};
          for (final i in _selected) {
            if (i == oldIndex) {
              moved.add(newIndex);
            } else if (oldIndex < i && i < newIndex) {
              moved.add(i - 1);
            } else if (newIndex <= i && i < oldIndex) {
              moved.add(i + 1);
            } else {
              moved.add(i);
            }
          }
          _selected..clear()..addAll(moved);
        });
      },
    );
  }
}

class _AppTitle extends StatelessWidget {
  final String text;
  const _AppTitle({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.picture_as_pdf),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
          ),
        ),
      ],
    );
  }
}

class FilePickPage extends StatelessWidget {
  final Future<void> Function() onPickImages;
  final Future<void> Function() onPickPdfs;

  const FilePickPage({super.key, required this.onPickImages, required this.onPickPdfs});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tr = AppLang.of(context).t;
    return Scaffold(
      appBar: AppBar(title: Text(tr('files')), leading: const BackButton()),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _ActionTile(
              icon: Icons.image,
              color: scheme.primary,
              title: tr('select_images'),
              subtitle: tr('images_hint'),
              onTap: () async { await onPickImages(); if (context.mounted) Navigator.pop(context); },
            ),
            const SizedBox(height: 12),
            _ActionTile(
              icon: Icons.picture_as_pdf,
              color: Colors.white.withOpacity(.8),
              title: tr('select_pdfs'),
              subtitle: tr('pdfs_hint'),
              onTap: () async { await onPickPdfs(); if (context.mounted) Navigator.pop(context); },
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------- SUB PAGES & WIDGETS -----------------

class PdfToolsPage extends StatefulWidget {
  final File currentPdf;
  final Future<File?> Function() onProtect;
  final Future<File?> Function() onReorder;
  final Future<File?> Function() onDeletePages;
  final Future<File?> Function() onCompress;
  final Future<File?> Function() onHeaderFooter;
  final VoidCallback onShare;
  final ValueChanged<File>? onCurrentChanged;

  const PdfToolsPage({
    super.key,
    required this.currentPdf,
    required this.onProtect,
    required this.onReorder,
    required this.onDeletePages,
    required this.onCompress,
    required this.onHeaderFooter,
    required this.onShare,
    this.onCurrentChanged,
  });

  @override
  State<PdfToolsPage> createState() => _PdfToolsPageState();
}

class _PdfToolsPageState extends State<PdfToolsPage> {
  late File _file;
  final List<File> _undoStack = <File>[];
  bool _busy = false;
  bool _showTools = false;
  Key _viewerKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _file = widget.currentPdf;
  }

  Future<void> _apply(Future<File?> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);

    final before = _file;
    final result = await action();

    if (!mounted) return;
    if (result != null) {
      _undoStack.add(before);
      _file = result;
      _viewerKey = UniqueKey();
      widget.onCurrentChanged?.call(result);
      setState(() {});
    }
    setState(() => _busy = false);
  }

  void _undo() {
    if (_busy || _undoStack.isEmpty) return;
    final prev = _undoStack.removeLast();
    _file = prev;
    _viewerKey = UniqueKey();
    widget.onCurrentChanged?.call(prev);
    setState(() {});
  }

  void _toggleTools() => setState(() => _showTools = !_showTools);
  void _hideTools() => setState(() => _showTools = false);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tr = AppLang.of(context).t;

    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF-Tools'),
        leading: const BackButton(),
        actions: [
          IconButton(
            tooltip: tr('undo'),
            onPressed: _undoStack.isEmpty ? null : _undo,
            icon: const Icon(Icons.undo),
          ),
          TextButton.icon(
            onPressed: widget.onShare,
            icon: const Icon(Icons.share),
            label: Text(tr('share')),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.onSurface),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _hideTools,
                child: SfPdfViewer.file(
                  key: _viewerKey,
                  _file,
                  canShowScrollHead: true,
                  canShowScrollStatus: true,
                  enableDoubleTapZooming: true,
                ),
              ),
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: _showTools
                    ? _SideToolsColumn(
                  key: const ValueKey('tools'),
                  scheme: scheme,
                  tr: tr,
                  onCloseRequested: _hideTools,
                  onProtect: () => _apply(widget.onProtect),
                  onReorder: () => _apply(widget.onReorder),
                  onDeletePages: () => _apply(widget.onDeletePages),
                  onCompress: () => _apply(widget.onCompress),
                  onHeaderFooter: () => _apply(widget.onHeaderFooter),
                )
                    : FloatingActionButton.extended(
                  key: const ValueKey('edit'),
                  onPressed: _busy ? null : _toggleTools,
                  icon: const Icon(Icons.edit),
                  label: Text(tr('edit')),
                ),
              ),
            ),
            if (_busy)
              const Positioned(
                right: 16,
                bottom: 86,
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SideToolsColumn extends StatelessWidget {
  final ColorScheme scheme;
  final String Function(String) tr;
  final VoidCallback onProtect;
  final VoidCallback onReorder;
  final VoidCallback onDeletePages;
  final VoidCallback onCompress;
  final VoidCallback onHeaderFooter;
  final VoidCallback onCloseRequested;

  const _SideToolsColumn({
    super.key,
    required this.scheme,
    required this.tr,
    required this.onProtect,
    required this.onReorder,
    required this.onDeletePages,
    required this.onCompress,
    required this.onHeaderFooter,
    required this.onCloseRequested,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(.12)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.45), blurRadius: 24, offset: const Offset(0, 16))],
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SideToolButton(icon: Icons.lock_outline, label: tr('password'), onTap: onProtect, color: scheme.primary),
          const SizedBox(height: 8),
          _SideToolButton(icon: Icons.swap_vert, label: tr('reorder'), onTap: onReorder),
          const SizedBox(height: 8),
          _SideToolButton(icon: Icons.delete_outline, label: tr('delete_pages'), onTap: onDeletePages),
          const SizedBox(height: 8),
          _SideToolButton(icon: Icons.compress, label: tr('compress'), onTap: onCompress),
          const SizedBox(height: 8),
          _SideToolButton(icon: Icons.text_fields, label: tr('header_footer'), onTap: onHeaderFooter),
          const SizedBox(height: 10),
          _SideToolButton(icon: Icons.close, label: tr('done'), onTap: onCloseRequested),
        ],
      ),
    );
  }
}

class _SideToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _SideToolButton({required this.icon, required this.label, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? Colors.white.withOpacity(.08),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({required this.icon, required this.title, required this.subtitle, required this.onTap, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color, child: Icon(icon, color: Colors.white)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final String path;
  const _Thumb({required this.path});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.file(
        File(path),
        width: 56,
        height: 56,
        cacheWidth: 150, // WICHTIG: Spart RAM für die Liste
        fit: BoxFit.cover,
        errorBuilder: (c, e, s) => Container(
          width: 56, height: 56, color: Colors.white.withOpacity(.06),
          alignment: Alignment.center, child: const Icon(Icons.broken_image),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String text;
  const _EmptyState({required this.text});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.collections, size: 84, color: scheme.primary.withOpacity(.8)),
            const SizedBox(height: 16),
            Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: Colors.white70)
            ),
            const SizedBox(height: 140),
          ],
        ),
      ),
    );
  }
}

class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;

  const GlassPanel({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding ?? const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: [Colors.white.withOpacity(.08), Colors.white.withOpacity(.04)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight
            ),
            // Die sichtbare Randlinie
            border: Border.all(color: Colors.white.withOpacity(.15), width: 1.2),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(.45), blurRadius: 24, offset: const Offset(0, 16))],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _RedBlackBackground extends StatelessWidget {
  const _RedBlackBackground();
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(center: Alignment(-.5, -.8), radius: 1.2, colors: [Color(0xFF0B0B0B), Color(0xFF000000)]),
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  final double size; final Color color; final double blur; final double? top, left, right, bottom;
  const _GlowBlob({required this.size, required this.color, required this.blur, this.top, this.left, this.right, this.bottom});
  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: size, height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: color, blurRadius: blur, spreadRadius: blur * .35)]),
    );
    return Positioned(top: top, left: left, right: right, bottom: bottom, child: IgnorePointer(child: box));
  }
}

class _RoundFab extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final BorderSide? border;

  const _RoundFab({required this.icon, required this.label, required this.onPressed, required this.color, this.border});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(vertical: 12),
          elevation: 8,
          shadowColor: Colors.black.withOpacity(.35),
          side: border,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon),
            const SizedBox(width: 8),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class PdfPreviewPage extends StatelessWidget {
  final File file;
  const PdfPreviewPage({super.key, required this.file, bool fullscreenDialog = false});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLang.of(context).t('preview')),
        actions: [
          IconButton(
            tooltip: AppLang.of(context).t('close'),
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