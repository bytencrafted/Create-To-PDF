import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'features/home/home_page.dart';
import 'localization/app_lang.dart';

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
    // Initialisiert die Sprach-Einstellungen (z.B. aus SharedPrefs)
    await _lang.init();
    if (mounted) {
      setState(() {
        _initialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Der AppLang Wrapper stellt den Sprach-Status bereit
    return AppLang(
      controller: _lang,
      child: AnimatedBuilder(
        animation: _lang,
        builder: (context, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Convert to PDF',
            theme: ThemeData(
              brightness: Brightness.dark,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFFE53935),
                brightness: Brightness.dark,
              ),
              useMaterial3: true,
            ),
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
            // Routing-Logik:
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

/// Startbildschirm zur Sprachauswahl (nur beim ersten Mal)
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
      body: Stack(
        children: [
          const _BootBackground(),
          SafeArea(
            child: Center(
              child: Card(
                elevation: 8,
                margin: const EdgeInsets.all(24),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 12),
                      const Text(
                        'Language / Sprache',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      for (final e in entries) ...[
                        ListTile(
                          leading: Text(e.flag, style: const TextStyle(fontSize: 22)),
                          title: Text(e.label),
                          onTap: () async {
                            await lang.setLanguage(e.code);
                            // Nach Auswahl wird durch den AnimatedBuilder in app.dart
                            // automatisch die HomePage geladen.
                          },
                        ),
                        if (e != entries.last) const Divider(height: 0),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
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
      body: Stack(
        children: [
          _BootBackground(),
          Center(
            child: Icon(Icons.picture_as_pdf, size: 80, color: Color(0xFFE53935)),
          ),
        ],
      ),
    );
  }
}

class _BootBackground extends StatelessWidget {
  const _BootBackground();
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(-.5, -.8),
          radius: 1.2,
          colors: [Color(0xFF0B0B0B), Color(0xFF000000)],
        ),
      ),
    );
  }
}