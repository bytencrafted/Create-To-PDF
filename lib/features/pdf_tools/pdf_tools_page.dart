import 'dart:io';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../localization/app_lang.dart';

const _kRed = Color(0xFFE53935);
const _kRedTint = Color(0xFFFCE9E8);
const _kField = Color(0xFFF1F2F5);
const _kText = Color(0xFF1A1B1F);
const _kTextDim = Color(0xFF6E7077);

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
    File? result;
    try {
      result = await action();
    } finally {
      if (mounted) {
        if (result != null) {
          _undoStack.add(before);
          _file = result;
          _viewerKey = UniqueKey();
          widget.onCurrentChanged?.call(result);
        }
        setState(() => _busy = false);
      }
    }
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
    final tr = AppLang.of(context).t;

    return Scaffold(
      backgroundColor: const Color(0xFFEDEEF1),
      appBar: AppBar(
        title: Text(tr('pdf_tools')),
        leading: const BackButton(),
        actions: [
          IconButton(
            tooltip: tr('undo'),
            onPressed: _undoStack.isEmpty ? null : _undo,
            icon: const Icon(Icons.undo),
          ),
          TextButton.icon(
            onPressed: widget.onShare,
            icon: const Icon(Icons.share_outlined),
            label: Text(tr('share')),
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
                        backgroundColor: _kRed,
                        foregroundColor: Colors.white,
                        onPressed: _busy ? null : _toggleTools,
                        icon: const Icon(Icons.edit_outlined),
                        label: Text(tr('edit')),
                      ),
              ),
            ),
            if (_busy)
              const Positioned(
                right: 16,
                bottom: 86,
                child: SizedBox(
                  width: 34,
                  height: 34,
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
  final String Function(String) tr;
  final VoidCallback onProtect;
  final VoidCallback onReorder;
  final VoidCallback onDeletePages;
  final VoidCallback onCompress;
  final VoidCallback onHeaderFooter;
  final VoidCallback onCloseRequested;

  const _SideToolsColumn({
    super.key,
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
      width: 200,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SideToolButton(
              icon: Icons.lock_outline, label: tr('password'), onTap: onProtect, primary: true),
          const SizedBox(height: 8),
          _SideToolButton(icon: Icons.swap_vert, label: tr('reorder'), onTap: onReorder),
          const SizedBox(height: 8),
          _SideToolButton(icon: Icons.delete_outline, label: tr('delete_pages'), onTap: onDeletePages),
          const SizedBox(height: 8),
          _SideToolButton(icon: Icons.compress, label: tr('compress'), onTap: onCompress),
          const SizedBox(height: 8),
          _SideToolButton(icon: Icons.text_fields, label: tr('header_footer'), onTap: onHeaderFooter),
          const Divider(height: 18),
          _SideToolButton(icon: Icons.check, label: tr('done'), onTap: onCloseRequested),
        ],
      ),
    );
  }
}

class _SideToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  const _SideToolButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Align(alignment: Alignment.centerLeft, child: Text(label)),
        style: ElevatedButton.styleFrom(
          backgroundColor: primary ? _kRed : _kField,
          foregroundColor: primary ? Colors.white : _kText,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

/// Visuelles Umsortieren per Drag & Drop. Liefert die neue Reihenfolge als
/// 0-basierte Indizes.
class PageReorderPage extends StatefulWidget {
  final int pageCount;
  const PageReorderPage({super.key, required this.pageCount});

  @override
  State<PageReorderPage> createState() => _PageReorderPageState();
}

class _PageReorderPageState extends State<PageReorderPage> {
  late List<int> _order;

  @override
  void initState() {
    super.initState();
    _order = List<int>.generate(widget.pageCount, (i) => i);
  }

  @override
  Widget build(BuildContext context) {
    final tr = AppLang.of(context).t;
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('reorder_pages_title')),
        leading: const BackButton(),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop<List<int>>(_order),
              icon: const Icon(Icons.check, size: 18),
              label: Text(tr('apply')),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(tr('drag_to_reorder'), style: const TextStyle(color: _kTextDim)),
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: _order.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex -= 1;
                  final v = _order.removeAt(oldIndex);
                  _order.insert(newIndex, v);
                });
              },
              itemBuilder: (context, i) {
                final original = _order[i];
                return Container(
                  key: ValueKey('page-$original'),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.black.withOpacity(0.06)),
                  ),
                  child: ListTile(
                    leading: Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _kRedTint,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('${i + 1}',
                          style: const TextStyle(
                              color: _kRed, fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                    title: Text('${tr('page_label')} ${original + 1}',
                        style: const TextStyle(fontWeight: FontWeight.w600, color: _kText)),
                    trailing: ReorderableDragStartListener(
                      index: i,
                      child: const Icon(Icons.drag_indicator, color: Color(0xFFB4B5BB)),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Visuelles Löschen: Seiten antippen zum Markieren.
class PageDeletePage extends StatefulWidget {
  final int pageCount;
  const PageDeletePage({super.key, required this.pageCount});

  @override
  State<PageDeletePage> createState() => _PageDeletePageState();
}

class _PageDeletePageState extends State<PageDeletePage> {
  final Set<int> _selected = {};

  @override
  Widget build(BuildContext context) {
    final tr = AppLang.of(context).t;

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('delete_pages_title')),
        leading: const BackButton(),
        actions: [
          TextButton(
            onPressed: () => setState(() {
              if (_selected.length == widget.pageCount) {
                _selected.clear();
              } else {
                _selected
                  ..clear()
                  ..addAll(List.generate(widget.pageCount, (i) => i));
              }
            }),
            child: Text(_selected.length == widget.pageCount ? tr('clear') : tr('select_all')),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 10, left: 4),
            child: ElevatedButton.icon(
              onPressed: _selected.isEmpty
                  ? null
                  : () => Navigator.of(context).pop<List<int>>(_selected.toList()..sort()),
              icon: const Icon(Icons.delete_outline, size: 18),
              label: Text(tr('apply')),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(tr('tap_to_select_delete'), style: const TextStyle(color: _kTextDim)),
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: .8,
              ),
              itemCount: widget.pageCount,
              itemBuilder: (context, i) {
                final sel = _selected.contains(i);
                return InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => setState(() {
                    if (sel) {
                      _selected.remove(i);
                    } else {
                      _selected.add(i);
                    }
                  }),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: sel ? _kRed : Colors.black.withOpacity(0.08),
                        width: sel ? 2 : 1,
                      ),
                      color: sel ? _kRedTint : Colors.white,
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.description_outlined, size: 32, color: _kTextDim),
                              const SizedBox(height: 8),
                              Text('${tr('page_label')} ${i + 1}',
                                  style: const TextStyle(fontWeight: FontWeight.w500, color: _kText)),
                            ],
                          ),
                        ),
                        if (sel)
                          const Positioned(
                            top: 8,
                            right: 8,
                            child: Icon(Icons.check_circle, color: _kRed, size: 20),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}