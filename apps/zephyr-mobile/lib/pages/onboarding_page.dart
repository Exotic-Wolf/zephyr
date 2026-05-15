import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../models/models.dart';
import '../services/api_client.dart';
import 'dart:io';
import '../app_constants.dart';
import '../l10n/app_localizations.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    required this.apiClient,
    required this.onLoginSuccess,
    super.key,
  });

  final ZephyrApiClient apiClient;
  final ValueChanged<String> onLoginSuccess;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final GoogleSignIn _googleSignIn;
  bool _loading = false;
  bool _googleLoading = false;
  bool _appleLoading = false;
  bool _checkingApiStatus = true;
  bool? _apiReachable;
  String? _error;

  @override
  void initState() {
    super.initState();
    _googleSignIn = GoogleSignIn(
      scopes: <String>['email'],
      serverClientId: googleServerClientId.isEmpty
          ? null
          : googleServerClientId,
    );
    _refreshApiStatus();
  }

  Future<void> _refreshApiStatus() async {
    setState(() {
      _checkingApiStatus = true;
    });

    final bool isReachable = await widget.apiClient.ping();
    if (!mounted) {
      return;
    }

    setState(() {
      _apiReachable = isReachable;
      _checkingApiStatus = false;
    });
  }

  Future<void> _continue() async {
    const String guestName = 'wolf';

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final AuthSession session = await widget.apiClient.guestLogin(guestName);
      if (!mounted) {
        return;
      }
      widget.onLoginSuccess(session.accessToken);
    } catch (error) {
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _continueWithGoogle() async {
    setState(() {
      _googleLoading = true;
      _error = null;
    });

    try {
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account == null) {
        if (!mounted) {
          return;
        }
        setState(() {
          _error = 'Google sign-in canceled.';
        });
        return;
      }

      final GoogleSignInAuthentication auth = await account.authentication;
      final String? idToken = auth.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw Exception(
          'Google ID token not available. Set GOOGLE_SERVER_CLIENT_ID '
          '(Web OAuth client ID) via --dart-define and retry.',
        );
      }

      final AuthSession session = await widget.apiClient.googleLogin(idToken);
      if (!mounted) {
        return;
      }
      widget.onLoginSuccess(session.accessToken);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _googleLoading = false;
        });
      }
    }
  }

  Future<void> _continueWithApple() async {
    setState(() {
      _appleLoading = true;
      _error = null;
    });

    try {
      final AuthorizationCredentialAppleID credential =
          await SignInWithApple.getAppleIDCredential(
            scopes: <AppleIDAuthorizationScopes>[
              AppleIDAuthorizationScopes.email,
              AppleIDAuthorizationScopes.fullName,
            ],
          );

      final String? idToken = credential.identityToken;
      if (idToken == null || idToken.isEmpty) {
        throw Exception(
          'Apple ID token not available from Sign in with Apple.',
        );
      }

      final AuthSession session = await widget.apiClient.appleLogin(
        idToken: idToken,
        email: credential.email,
        givenName: credential.givenName,
        familyName: credential.familyName,
      );

      if (!mounted) {
        return;
      }
      widget.onLoginSuccess(session.accessToken);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _appleLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isTablet = MediaQuery.sizeOf(context).width >= tabletBreakpoint;

    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.goLiveInSeconds)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxContentWidth),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(isTablet ? 24 : 16),
            child: Column(
              crossAxisAlignment: isTablet ? CrossAxisAlignment.center : CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  AppLocalizations.of(context)!.goLiveInSeconds,
                  style: TextStyle(
                    fontSize: isTablet ? 24 : 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    Expanded(child: Text('API: ${widget.apiClient.baseUrl}')),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _checkingApiStatus
                            ? Colors.orange.shade50
                            : (_apiReachable == true
                                  ? Colors.green.shade50
                                  : Colors.red.shade50),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _checkingApiStatus
                            ? AppLocalizations.of(context)!.checkingApi
                            : (_apiReachable == true
                                  ? AppLocalizations.of(context)!.apiConnected
                                  : AppLocalizations.of(context)!.apiOffline),
                        style: TextStyle(
                          color: _checkingApiStatus
                              ? Colors.orange.shade700
                              : (_apiReachable == true
                                    ? Colors.green.shade700
                                    : Colors.red.shade700),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: AppLocalizations.of(context)!.refreshApiStatus,
                      onPressed: _checkingApiStatus ? null : _refreshApiStatus,
                      icon: const Icon(Icons.refresh, size: 20),
                    ),
                  ],
                ),
                SizedBox(height: isTablet ? 20 : 16),
                SizedBox(
                  width: isTablet ? 320 : double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _continue,
                    child: Text(
                      _loading ? AppLocalizations.of(context)!.connecting : AppLocalizations.of(context)!.continueAsGuest,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: isTablet ? 320 : double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _googleLoading ? null : _continueWithGoogle,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4285F4),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Text(
                      'G',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    label: Text(
                      _googleLoading ? AppLocalizations.of(context)!.signingIn : AppLocalizations.of(context)!.continueWithGoogle,
                    ),
                  ),
                ),
                if (Platform.isIOS) ...<Widget>[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: isTablet ? 320 : double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _appleLoading ? null : _continueWithApple,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.apple),
                      label: Text(
                        _appleLoading
                            ? AppLocalizations.of(context)!.signingIn
                            : AppLocalizations.of(context)!.continueWithApple,
                      ),
                    ),
                  ),
                ],
                if (_error != null) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

