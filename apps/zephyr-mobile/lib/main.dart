import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'firebase_options.dart';
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

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
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
  static const String _localeKey = 'app_locale';
  String? _accessToken;
  bool _restoringSession = true;
  ThemeMode _themeMode = ThemeMode.dark;
  Locale? _locale; // null = follow device
  final ValueNotifier<int> _tabNotifier = ValueNotifier<int>(0);
  StreamSubscription<RemoteMessage>? _fcmOpenSub;

  @override
  void initState() {
    super.initState();
    _restoreSession();
    _setupFcmHandlers();
  }

  void _setupFcmHandlers() {
    // App launched from terminated state by tapping a notification
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null && mounted) _tabNotifier.value = 3;
    });
    // App in background, user taps notification
    _fcmOpenSub = FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (mounted) _tabNotifier.value = 3;
    });
  }

  @override
  void dispose() {
    _fcmOpenSub?.cancel();
    _tabNotifier.dispose();
    super.dispose();
  }

  Future<void> _restoreSession() async {
    FlutterNativeSplash.remove(); // Show Flutter splash immediately
    final Future<void> minDelay = Future<void>.delayed(const Duration(seconds: 2));
    try {
      final String? saved = await _storage.read(key: _tokenKey);
      if (saved != null && saved.isNotEmpty) {
        try {
          await _apiClient.getMe(saved);
          if (mounted) {
            setState(() => _accessToken = saved);
            _registerFcmToken(saved);
          }
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
      final String? savedLocale = await _storage.read(key: _localeKey);
      if (savedLocale != null && mounted) {
        setState(() => _locale = Locale(savedLocale));
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
    _registerFcmToken(accessToken);
  }

  Future<void> _registerFcmToken(String accessToken) async {
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      final token = await messaging.getToken();
      if (token != null) {
        await _apiClient.registerDeviceToken(accessToken, token);
      }
    } catch (_) {}
  }

  void _onLogout() {
    final token = _accessToken;
    _storage.delete(key: _tokenKey);
    setState(() => _accessToken = null);
    if (token != null) _unregisterFcmToken(token);
  }

  Future<void> _unregisterFcmToken(String accessToken) async {
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null) {
        await _apiClient.unregisterDeviceToken(accessToken, fcmToken);
      }
    } catch (_) {}
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
      locale: _locale,
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
              tabNotifier: _tabNotifier,
              themeMode: _themeMode,
              onThemeModeChanged: (ThemeMode mode) {
                _storage.write(key: _themeModeKey, value: switch (mode) {
                  ThemeMode.light => 'light',
                  ThemeMode.system => 'system',
                  ThemeMode.dark => 'dark',
                });
                setState(() => _themeMode = mode);
              },
              locale: _locale,
              onLocaleChanged: (Locale? locale) {
                if (locale == null) {
                  _storage.delete(key: _localeKey);
                } else {
                  _storage.write(key: _localeKey, value: locale.languageCode);
                }
                setState(() => _locale = locale);
              },
            ),
    );
  }
}
