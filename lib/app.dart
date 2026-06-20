import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'features/home/home_page.dart';
import 'localization/app_lang.dart';

/// Zentrale Design-Tokens – ein Ort für das gesamte Farb-/Stilschema.
class AppColors {
  static const bg = Color(0xFFF4F5F7);
  static const surface = Color(0xFFFFFFFF);
  static const field = Color(0xFFF1F2F5);
  static const red = Color(0xFFE53935);
  static const redTint = Color(0xFFFCE9E8);
  static const text = Color(0xFF1A1B1F);
  static const textDim = Color(0xFF6E7077);
  static final border = Colors.black.withOpacity(0.07);
}

ThemeData buildAppTheme() {
  final base = ColorScheme.fromSeed(
    seedColor: AppColors.red,
    brightness: Brightness.light,
  );
  final scheme = base.copyWith(
    primary: AppColors.red,
    onPrimary: Colors.white,
    surface: AppColors.surface,
    onSurface: AppColors.text,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      foregroundColor: AppColors.text,
      titleTextStyle: const TextStyle(
        color: AppColors.text,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
      ),
      systemOverlayStyle: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    ),
    iconTheme: const IconThemeData(color: Color(0xFF3A3B40)),
    dividerTheme: DividerThemeData(color: AppColors.border, thickness: 1, space: 0),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.red),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.red,
        foregroundColor: Colors.white,
        disabledBackgroundColor: const Color(0xFFE7E8EB),
        disabledForegroundColor: const Color(0xFFB4B5BB),
        elevation: 0,
        shadowColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 15,
          letterSpacing: 0.1,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.text,
        backgroundColor: AppColors.surface,
        side: BorderSide(color: Colors.black.withOpacity(0.10)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.red,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF26272B),
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.all(16),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
    ),
  );
}

class CreateToPdfApp extends StatefulWidget {
  const CreateToPdfApp({super.key});

  @override
  State<CreateToPdfApp> createState() => _CreateToPdfAppState();
}

class _CreateToPdfAppState extends State<CreateToPdfApp> {
  final AppLangController _lang = AppLangController();
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initLang();
  }

  Future<void> _initLang() async {
    await _lang.init();
    if (mounted) setState(() => _initialized = true);
  }

  @override
  Widget build(BuildContext context) {
    return AppLang(
      controller: _lang,
      child: AnimatedBuilder(
        animation: _lang,
        builder: (context, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Convert to PDF',
            theme: buildAppTheme(),
            locale: _lang.locale,
            supportedLocales: const [
              Locale('de'),
              Locale('en'),
              Locale('fr'),
              Locale('pt'),
            ],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: !_initialized
                ? const _BootScreen()
                : (_lang.hasUserChoice
                    ? const HomePage()
                    : LanguageSetupScreen(lang: _lang)),
          );
        },
      ),
    );
  }
}

/// Sprachauswahl beim ersten Start.
class LanguageSetupScreen extends StatelessWidget {
  final AppLangController lang;
  const LanguageSetupScreen({super.key, required this.lang});

  @override
  Widget build(BuildContext context) {
    final entries = <_LangEntry>[
      _LangEntry(flag: '🇩🇪', code: 'de', label: 'Deutsch'),
      _LangEntry(flag: '🇬🇧', code: 'en', label: 'English'),
      _LangEntry(flag: '🇫🇷', code: 'fr', label: 'Français'),
      _LangEntry(flag: '🇵🇹', code: 'pt', label: 'Português'),
    ];

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Container(
              margin: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 30,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 26, 18, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.redTint,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(Icons.language, color: AppColors.red, size: 30),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Language / Sprache',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 20),
                    for (final e in entries) ...[
                      _LangTile(entry: e, onTap: () => lang.setLanguage(e.code)),
                      if (e != entries.last) const SizedBox(height: 8),
                    ],
                    const SizedBox(height: 6),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LangTile extends StatelessWidget {
  final _LangEntry entry;
  final VoidCallback onTap;
  const _LangTile({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.field,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Text(entry.flag, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 14),
              Expanded(
                child: Text(entry.label,
                    style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600)),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFFB4B5BB)),
            ],
          ),
        ),
      ),
    );
  }
}

class _LangEntry {
  final String flag;
  final String code;
  final String label;
  const _LangEntry({required this.flag, required this.code, required this.label});
}

class _BootScreen extends StatelessWidget {
  const _BootScreen();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Icon(Icons.picture_as_pdf_rounded, size: 72, color: AppColors.red),
      ),
    );
  }
}