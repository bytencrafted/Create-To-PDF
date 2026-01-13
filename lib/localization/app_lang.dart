import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Einfache, appweite Sprachverwaltung mit Persistenz.
class AppLangController extends ChangeNotifier {
  static const _kCodeKey = 'app_lang_code';

  Locale _locale = const Locale('de');
  bool _initialized = false;
  SharedPreferences? _prefs;

  Locale get locale => _locale;
  bool get initialized => _initialized;

  /// Wurde bereits eine Sprache bewusst gewählt?
  bool get hasUserChoice => _prefs?.containsKey(_kCodeKey) ?? false;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    final code = _prefs!.getString(_kCodeKey);
    if (code != null && code.isNotEmpty) {
      _locale = Locale(code);
    } else {
      _locale = const Locale('de'); // Default
    }
    _initialized = true;
    notifyListeners();
  }

  Future<void> setLanguage(String code) async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setString(_kCodeKey, code);
    _locale = Locale(code);
    notifyListeners();
  }

  // --- Übersetzungen ---
  static const Map<String, Map<String, String>> _dict = {
    'de': {
      'app_title': 'Convert to PDF',
      'generate_pdf': 'PDF erzeugen',
      'language': 'Sprache',
      'language_select_title': 'Sprache auswählen',
      'german': 'Deutsch',
      'english': 'Englisch',
      'french': 'Französisch',
      'portuguese': 'Portugiesisch',

      'no_items': 'Noch keine Dateien.\nFüge Bilder oder PDFs über die Buttons hinzu.',
      'camera': 'Kamera',
      'gallery': 'Galerie',
      'pdf': 'PDF',
      'pdf_tools': 'PDF-Tools',

      'files': 'Dateien',
      'select_images': 'Bilder auswählen',
      'images_hint': 'JPG, PNG, HEIC, WebP …',
      'select_pdfs': 'PDF(s) auswählen',
      'pdfs_hint': 'Eine oder mehrere PDFs laden/zusammenführen',

      'share': 'Teilen',
      'edit': 'Bearbeiten',
      'password': 'Passwort',
      'reorder': 'Reihenfolge',
      'delete_pages': 'Seiten löschen',
      'compress': 'Komprimieren',
      'header_footer': 'Kopf/Fuß',
      'done': 'Fertig',

      'page_size': 'Seitengröße',
      'orientation': 'Ausrichtung',
      'portrait': 'Hochformat',
      'landscape': 'Querformat',
      'margin_mm': 'Rand (mm)',
      'file_name_optional': 'Dateiname (optional)',

      // Vorschau
      'preview': 'Vorschau',
      'close': 'Schließen',

      // NEU für Undo
      'undo': 'Rückgängig',
    },
    'en': {
      'app_title': 'Convert to PDF',
      'generate_pdf': 'Create PDF',
      'language': 'Language',
      'language_select_title': 'Choose language',
      'german': 'German',
      'english': 'English',
      'french': 'French',
      'portuguese': 'Portuguese',

      'no_items': 'No files yet.\nAdd images or PDFs using the buttons.',
      'camera': 'Camera',
      'gallery': 'Gallery',
      'pdf': 'PDF',
      'pdf_tools': 'PDF Tools',

      'files': 'Files',
      'select_images': 'Select images',
      'images_hint': 'JPG, PNG, HEIC, WebP …',
      'select_pdfs': 'Select PDF(s)',
      'pdfs_hint': 'Load/merge one or more PDFs',

      'share': 'Share',
      'edit': 'Edit',
      'password': 'Password',
      'reorder': 'Reorder',
      'delete_pages': 'Delete pages',
      'compress': 'Compress',
      'header_footer': 'Header/Footer',
      'done': 'Done',

      'page_size': 'Page size',
      'orientation': 'Orientation',
      'portrait': 'Portrait',
      'landscape': 'Landscape',
      'margin_mm': 'Margin (mm)',
      'file_name_optional': 'Filename (optional)',

      'preview': 'Preview',
      'close': 'Close',

      // NEW
      'undo': 'Undo',
    },
    'fr': {
      'app_title': 'Convertir en PDF',
      'generate_pdf': 'Créer PDF',
      'language': 'Langue',
      'language_select_title': 'Choisir la langue',
      'german': 'Allemand',
      'english': 'Anglais',
      'french': 'Français',
      'portuguese': 'Portugais',

      'no_items': 'Aucun fichier.\nAjoutez des images ou des PDF via les boutons.',
      'camera': 'Caméra',
      'gallery': 'Galerie',
      'pdf': 'PDF',
      'pdf_tools': 'Outils PDF',

      'files': 'Fichiers',
      'select_images': 'Sélectionner des images',
      'images_hint': 'JPG, PNG, HEIC, WebP …',
      'select_pdfs': 'Sélectionner des PDF',
      'pdfs_hint': 'Charger/fusionner un ou plusieurs PDF',

      'share': 'Partager',
      'edit': 'Modifier',
      'password': 'Mot de passe',
      'reorder': 'Réorganiser',
      'delete_pages': 'Supprimer des pages',
      'compress': 'Compresser',
      'header_footer': 'En-tête/Pied de page',
      'done': 'Terminer',

      'page_size': 'Taille de page',
      'orientation': 'Orientation',
      'portrait': 'Portrait',
      'landscape': 'Paysage',
      'margin_mm': 'Marge (mm)',
      'file_name_optional': 'Nom de fichier (facultatif)',

      'preview': 'Aperçu',
      'close': 'Fermer',

      // NOUVEAU
      'undo': 'Annuler',
    },
    'pt': {
      'app_title': 'Converter para PDF',
      'generate_pdf': 'Criar PDF',
      'language': 'Idioma',
      'language_select_title': 'Escolher idioma',
      'german': 'Alemão',
      'english': 'Inglês',
      'french': 'Francês',
      'portuguese': 'Português',

      'no_items': 'Nenhum ficheiro.\nAdicione imagens ou PDFs com os botões.',
      'camera': 'Câmara',
      'gallery': 'Galeria',
      'pdf': 'PDF',
      'pdf_tools': 'Ferramentas PDF',

      'files': 'Ficheiros',
      'select_images': 'Selecionar imagens',
      'images_hint': 'JPG, PNG, HEIC, WebP …',
      'select_pdfs': 'Selecionar PDF(s)',
      'pdfs_hint': 'Carregar/unir um ou mais PDFs',

      'share': 'Partilhar',
      'edit': 'Editar',
      'password': 'Palavra-passe',
      'reorder': 'Reordenar',
      'delete_pages': 'Eliminar páginas',
      'compress': 'Comprimir',
      'header_footer': 'Cabeçalho/Rodapé',
      'done': 'Concluir',

      'page_size': 'Tamanho da página',
      'orientation': 'Orientação',
      'portrait': 'Retrato',
      'landscape': 'Paisagem',
      'margin_mm': 'Margem (mm)',
      'file_name_optional': 'Nome do ficheiro (opcional)',

      'preview': 'Pré-visualização',
      'close': 'Fechar',

      // NOVO
      'undo': 'Anular',
    },
  };

  String t(String key) {
    final code = _locale.languageCode;
    final table = _dict[code] ?? _dict['en']!;
    return table[key] ?? key;
  }
}

/// InheritedWidget, um den Controller bequemer aus dem BuildContext zu holen.
class AppLang extends InheritedWidget {
  final AppLangController controller;

  const AppLang({
    super.key,
    required this.controller,
    required Widget child,
  }) : super(child: child);

  static AppLangController of(BuildContext context) {
    final w = context.dependOnInheritedWidgetOfExactType<AppLang>();
    assert(w != null, 'AppLang not found in context');
    return w!.controller;
  }

  @override
  bool updateShouldNotify(covariant AppLang oldWidget) => controller != oldWidget.controller;
}
