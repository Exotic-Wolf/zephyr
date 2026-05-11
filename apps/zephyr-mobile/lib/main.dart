import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'services/api_client.dart';
import 'pages/onboarding_page.dart';
import 'pages/home_screen.dart';
import 'app_constants.dart';

const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://zephyr-api-wr1s.onrender.com',
);

const String googleServerClientId = String.fromEnvironment(
  'GOOGLE_SERVER_CLIENT_ID',
  defaultValue: '',
);

void main() {
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
  String? _accessToken;
  bool _restoringSession = true;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
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
    } catch (_) {
      // Storage unavailable — proceed to login
    } finally {
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
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(child: CircularProgressIndicator(color: Colors.white)),
        ),
      );
    }
    return MaterialApp(
      title: 'Zephyr',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.purple),
      ),
      home: _accessToken == null
          ? OnboardingScreen(
              apiClient: _apiClient,
              onLoginSuccess: _onLoginSuccess,
            )
          : HomeScreen(
              apiClient: _apiClient,
              accessToken: _accessToken!,
              onLogout: _onLogout,
            ),
    );
  }
}
