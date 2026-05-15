import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'l10n/app_localizations.dart';
import 'services/api_client.dart';
import 'pages/onboarding_page.dart';
import 'pages/home_screen.dart';
import 'pages/splash_screen.dart';

const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://zephyr-api-wr1s.onrender.com',
);

const String googleServerClientId = String.fromEnvironment(
  'GOOGLE_SERVER_CLIENT_ID',
  defaultValue: '',
);

void main() {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final ZephyrApiClient _apiClient = ZephyrApiClient(baseUrl: apiBaseUrl);
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _tokenKey = 'access_token';
  static const String _themeModeKey = 'theme_mode';
  String? _accessToken;
  bool _restoringSession = true;
  ThemeMode _themeMode = ThemeMode.dark;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    FlutterNativeSplash.remove(); // Show Flutter splash immediately
    final Future<void> minDelay = Future<void>.delayed(const Duration(seconds: 2));
    try {
      final String? saved = await _storage.read(key: _tokenKey);
      if (saved != null && saved.isNotEmpty) {
        try {
          await _apiClient.getMe(saved);
          if (mounted) setState(() => _accessToken = saved);
        } catch (_) {
          await _storage.delete(key: _tokenKey);
        }
      }
      final String? savedTheme = await _storage.read(key: _themeModeKey);
      if (savedTheme != null && mounted) {
        setState(() {
          _themeMode = switch (savedTheme) {
            'light' => ThemeMode.light,
            'system' => ThemeMode.system,
            _ => ThemeMode.dark,
          };
        });
      }
    } catch (_) {
      // Storage unavailable — proceed to login
    } finally {
      await minDelay;
      if (mounted) setState(() => _restoringSession = false);
    }
  }

  void _onLoginSuccess(String accessToken) {
    _storage.write(key: _tokenKey, value: accessToken);
    setState(() => _accessToken = accessToken);
  }

  void _onLogout() {
    _storage.delete(key: _tokenKey);
    setState(() => _accessToken = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_restoringSession) {
      return const MaterialApp(
        home: SplashScreen(),
      );
    }
    return MaterialApp(
      title: 'Zephyr',
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('ar'),
        Locale('pt'),
        Locale('es'),
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF8F00)),
        useMaterial3: true,
      ),
      darkTheme: ThemeData.dark(useMaterial3: true),
      themeMode: _themeMode,
      home: _accessToken == null
          ? OnboardingScreen(
              apiClient: _apiClient,
              onLoginSuccess: _onLoginSuccess,
            )
          : HomeScreen(
              apiClient: _apiClient,
              accessToken: _accessToken!,
              onLogout: _onLogout,
              themeMode: _themeMode,
              onThemeModeChanged: (ThemeMode mode) {
                _storage.write(key: _themeModeKey, value: switch (mode) {
                  ThemeMode.light => 'light',
                  ThemeMode.system => 'system',
                  ThemeMode.dark => 'dark',
                });
                setState(() => _themeMode = mode);
              },
            ),
    );
  }
}
