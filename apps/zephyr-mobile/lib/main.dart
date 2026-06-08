import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'firebase_options.dart';
import 'l10n/app_localizations.dart';
import 'services/api_client.dart';
import 'services/firebase_chat_service.dart';
import 'features/onboarding/onboarding_page.dart';
import 'features/onboarding/profile_setup_screen.dart';
import 'features/home/home_screen.dart';
import 'splash_screen.dart';

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
  // ACK delivery immediately so sender gets ✓✓ even while app is backgrounded
  if (message.data['source'] == 'firestore') return;
  final String? messageId = message.data['messageId'];
  if (messageId == null || messageId.isEmpty) return;
  const storage = FlutterSecureStorage();
  final String? token = await storage.read(key: 'access_token');
  if (token == null || token.isEmpty) return;
  try {
    final HttpClient client = HttpClient();
    final Uri uri = Uri.parse('$apiBaseUrl/v1/messages/$messageId/delivered');
    final HttpClientRequest req = await client.patchUrl(uri);
    req.headers.set('authorization', 'Bearer $token');
    req.headers.set('content-length', '0');
    final HttpClientResponse res = await req.close();
    await res.drain<void>();
    client.close(force: true);
  } catch (_) {}
}

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await SentryFlutter.init((options) {
    options.dsn =
        'https://72291af0e04cf5281a0224c462ba5f59@o4511418834354176.ingest.us.sentry.io/4511418852638720';
    options.tracesSampleRate = 0.2;
  }, appRunner: () => runApp(const MyApp()));
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
  String? _pendingSetupToken;
  String? _pendingSetupDisplayName;
  bool _restoringSession = true;
  ThemeMode _themeMode = ThemeMode.dark;
  Locale? _locale; // null = follow device
  final ValueNotifier<int> _tabNotifier = ValueNotifier<int>(0);
  StreamSubscription<RemoteMessage>? _fcmOpenSub;

  @override
  void initState() {
    super.initState();
    ZephyrApiClient.instance = _apiClient;
    _restoreSession();
    _setupFcmHandlers();
  }

  void _setupFcmHandlers() {
    // App launched from terminated state by tapping a notification
    FirebaseMessaging.instance.getInitialMessage().then((
      RemoteMessage? message,
    ) {
      if (message != null && mounted) _tabNotifier.value = 4;
    });
    // App in background, user taps notification
    _fcmOpenSub = FirebaseMessaging.onMessageOpenedApp.listen((
      RemoteMessage message,
    ) {
      if (mounted) _tabNotifier.value = 4;
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
    final Future<void> minDelay = Future<void>.delayed(
      const Duration(seconds: 2),
    );
    try {
      final String? saved = await _storage.read(key: _tokenKey);
      if (saved != null && saved.isNotEmpty) {
        try {
          final profile = await _apiClient.getMe(saved);
          // Only restore session if profile setup is complete
          final isComplete = profile.onboardedAt != null;
          if (mounted && isComplete) {
            ZephyrApiClient.accessToken = saved;
            setState(() {
              _accessToken = saved;
              _pendingSetupToken = null;
              _pendingSetupDisplayName = null;
            });
            _registerFcmToken(saved);
          } else if (!isComplete) {
            if (mounted) {
              setState(() {
                _pendingSetupToken = saved;
                _pendingSetupDisplayName = profile.displayName;
              });
            }
          }
        } catch (_) {
          try {
            await FirebaseChatService.instance.clearSession().timeout(
              const Duration(seconds: 3),
              onTimeout: () {},
            );
          } catch (_) {}
          await _storage.delete(key: _tokenKey);
          ZephyrApiClient.accessToken = null;
          if (mounted) {
            setState(() {
              _accessToken = null;
              _pendingSetupToken = null;
              _pendingSetupDisplayName = null;
            });
          }
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
    ZephyrApiClient.accessToken = accessToken;
    setState(() {
      _accessToken = accessToken;
      _pendingSetupToken = null;
      _pendingSetupDisplayName = null;
    });
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

  Future<void> _onLogout() async {
    final token = _accessToken;

    try {
      await FirebaseChatService.instance.setOfflineStatus().timeout(
        const Duration(seconds: 3),
        onTimeout: () {},
      );
    } catch (_) {}

    if (token != null) {
      try {
        await _unregisterFcmToken(
          token,
        ).timeout(const Duration(seconds: 3), onTimeout: () {});
      } catch (_) {}
    }

    try {
      await FirebaseChatService.instance.clearSession().timeout(
        const Duration(seconds: 3),
        onTimeout: () {},
      );
    } catch (_) {}

    await _storage.delete(key: _tokenKey);
    ZephyrApiClient.accessToken = null;
    if (mounted) {
      setState(() {
        _accessToken = null;
        _pendingSetupToken = null;
        _pendingSetupDisplayName = null;
      });
    }
  }

  Future<void> _onDeleteAccount() async {
    final token = _accessToken;
    if (token == null || token.isEmpty) return;

    // Critical step — delete the account on the backend.
    // Timeout is treated as success: the SQL delete completes in <1s,
    // but the response may be slow if Firebase cleanup blocks (old deploys).
    try {
      await _apiClient.deleteMyAccount(token);
    } on TimeoutException {
      debugPrint('Delete account API timed out — treating as success');
    } catch (error) {
      debugPrint('Delete account failed at deleteMyAccount API: $error');
      rethrow;
    }

    // Everything below is best-effort cleanup — never hang.
    try {
      await FirebaseChatService.instance.setOfflineStatus().timeout(
        const Duration(seconds: 3),
        onTimeout: () {},
      );
    } catch (_) {}

    try {
      await _unregisterFcmToken(
        token,
      ).timeout(const Duration(seconds: 3), onTimeout: () {});
    } catch (_) {}

    try {
      await _clearLocalAppData().timeout(
        const Duration(seconds: 10),
        onTimeout: () {},
      );
    } catch (_) {}

    ZephyrApiClient.accessToken = null;
    if (mounted) {
      setState(() {
        _accessToken = null;
        _pendingSetupToken = null;
        _pendingSetupDisplayName = null;
      });
    }
  }

  Future<void> _clearLocalAppData() async {
    // Terminate Firestore FIRST — while auth is still valid.
    // This drops all snapshot listeners cleanly before sign-out.
    try {
      await FirebaseFirestore.instance.terminate().timeout(
        const Duration(seconds: 5),
        onTimeout: () {},
      );
      await FirebaseFirestore.instance.clearPersistence().timeout(
        const Duration(seconds: 3),
        onTimeout: () {},
      );
    } catch (_) {}

    try {
      await _storage.deleteAll();
    } catch (_) {}

    try {
      await FirebaseChatService.instance.clearSession().timeout(
        const Duration(seconds: 3),
        onTimeout: () {},
      );
    } catch (_) {}

    // Clear Flutter image cache held in memory.
    try {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    } catch (_) {}

    // Best-effort remove files from app cache/temp dirs.
    try {
      final Directory tempDir = await getTemporaryDirectory();
      await _deleteDirectoryContents(tempDir);
    } catch (_) {}

    try {
      final Directory cacheDir = await getApplicationCacheDirectory();
      await _deleteDirectoryContents(cacheDir);
    } catch (_) {}

    // Wipe any extra cache-like folders under app support used by plugins.
    try {
      final Directory supportDir = await getApplicationSupportDirectory();
      final Directory supportCache = Directory(
        p.join(supportDir.path, 'cache'),
      );
      if (await supportCache.exists()) {
        await _deleteDirectoryContents(supportCache);
      }
    } catch (_) {}
  }

  Future<void> _deleteDirectoryContents(Directory directory) async {
    if (!await directory.exists()) return;

    await for (final entity in directory.list(followLinks: false)) {
      try {
        if (entity is File) {
          await entity.delete();
        } else if (entity is Directory) {
          await entity.delete(recursive: true);
        }
      } catch (_) {
        // Ignore per-entity failures so wipe keeps progressing.
      }
    }
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
      return const MaterialApp(home: SplashScreen());
    }
    final String? setupToken = _pendingSetupToken;
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
          ? setupToken != null
                ? ProfileSetupScreen(
                    apiClient: _apiClient,
                    accessToken: setupToken,
                    initialDisplayName:
                        _pendingSetupDisplayName?.trim().isNotEmpty == true
                        ? _pendingSetupDisplayName!.trim()
                        : 'Zephyr',
                    onComplete: () => _onLoginSuccess(setupToken),
                  )
                : OnboardingScreen(
                    apiClient: _apiClient,
                    onLoginSuccess: _onLoginSuccess,
                  )
          : HomeScreen(
              apiClient: _apiClient,
              accessToken: _accessToken!,
              onLogout: _onLogout,
              onDeleteAccount: _onDeleteAccount,
              tabNotifier: _tabNotifier,
              themeMode: _themeMode,
              onThemeModeChanged: (ThemeMode mode) {
                _storage.write(
                  key: _themeModeKey,
                  value: switch (mode) {
                    ThemeMode.light => 'light',
                    ThemeMode.system => 'system',
                    ThemeMode.dark => 'dark',
                  },
                );
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
