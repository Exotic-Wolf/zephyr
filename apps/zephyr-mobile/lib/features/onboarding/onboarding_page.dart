import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/models.dart';
import '../../services/api_client.dart';
import '../../services/device_session_service.dart';
import '../../app_constants.dart';
import '../../l10n/app_localizations.dart';
import 'profile_setup_screen.dart';

abstract class OnboardingAuthGateway {
  Future<AuthSession?> continueWithGoogle();
  Future<AuthSession> continueWithApple();
}

class PlatformOnboardingAuthGateway implements OnboardingAuthGateway {
  PlatformOnboardingAuthGateway({
    required ZephyrApiClient apiClient,
    String serverClientId = googleServerClientId,
  }) : _apiClient = apiClient,
       _googleSignIn = GoogleSignIn(
         scopes: <String>['email'],
         serverClientId: serverClientId.isEmpty ? null : serverClientId,
       );

  final ZephyrApiClient _apiClient;
  final GoogleSignIn _googleSignIn;

  @override
  Future<AuthSession?> continueWithGoogle() async {
    final GoogleSignInAccount? account = await _googleSignIn.signIn();
    if (account == null) return null;

    final GoogleSignInAuthentication auth = await account.authentication;
    final String? idToken = auth.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw StateError('missing_google_id_token');
    }
    final String deviceId = await DeviceSessionService.getDeviceId();
    return _apiClient.googleLogin(idToken, deviceId: deviceId);
  }

  @override
  Future<AuthSession> continueWithApple() async {
    final AuthorizationCredentialAppleID credential =
        await SignInWithApple.getAppleIDCredential(
          scopes: <AppleIDAuthorizationScopes>[
            AppleIDAuthorizationScopes.email,
            AppleIDAuthorizationScopes.fullName,
          ],
        );
    final String? idToken = credential.identityToken;
    if (idToken == null || idToken.isEmpty) {
      throw StateError('missing_apple_id_token');
    }
    final String deviceId = await DeviceSessionService.getDeviceId();
    return _apiClient.appleLogin(
      idToken: idToken,
      email: credential.email,
      givenName: credential.givenName,
      familyName: credential.familyName,
      deviceId: deviceId,
    );
  }
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    required this.apiClient,
    required this.onLoginSuccess,
    this.authGateway,
    this.showAppleSignIn,
    this.brandHero,
    this.profileWriter,
    this.countryCodeResolver,
    this.sessionNotice,
    this.onSessionNoticeDismissed,
    super.key,
  });

  final ZephyrApiClient apiClient;
  final ValueChanged<String> onLoginSuccess;
  final OnboardingAuthGateway? authGateway;
  final bool? showAppleSignIn;
  final Widget? brandHero;
  final ProfileRealtimeWriter? profileWriter;
  final CountryCodeResolver? countryCodeResolver;
  final String? sessionNotice;
  final VoidCallback? onSessionNoticeDismissed;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final OnboardingAuthGateway _authGateway;
  bool _googleLoading = false;
  bool _appleLoading = false;
  bool _apiOffline = false;
  String? _error;
  String? _dismissedSessionNotice;
  Timer? _apiOfflineRetryTimer;
  int _apiCheckGeneration = 0;

  static const Duration _apiOfflineRetryDelay = Duration(seconds: 2);

  String? get _visibleSessionNotice {
    final notice = widget.sessionNotice?.trim();
    if (notice == null || notice.isEmpty || notice == _dismissedSessionNotice) {
      return null;
    }
    return notice;
  }

  @override
  void initState() {
    super.initState();
    _authGateway =
        widget.authGateway ??
        PlatformOnboardingAuthGateway(apiClient: widget.apiClient);
    _checkApi(retryOnFailure: true);
  }

  @override
  void didUpdateWidget(covariant OnboardingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sessionNotice != oldWidget.sessionNotice) {
      _dismissedSessionNotice = null;
    }
  }

  @override
  void dispose() {
    _apiOfflineRetryTimer?.cancel();
    super.dispose();
  }

  void _dismissSessionNotice() {
    final notice = widget.sessionNotice?.trim();
    if (notice == null || notice.isEmpty) return;
    _dismissedSessionNotice = notice;
    widget.onSessionNoticeDismissed?.call();
  }

  Future<bool> _checkApi({bool retryOnFailure = false}) async {
    final int generation = ++_apiCheckGeneration;
    final bool ok = await widget.apiClient.ping();
    if (!mounted || generation != _apiCheckGeneration) return ok;

    if (ok) {
      _apiOfflineRetryTimer?.cancel();
      _apiOfflineRetryTimer = null;
    }
    setState(() => _apiOffline = !ok);

    if (!ok && retryOnFailure) {
      _apiOfflineRetryTimer?.cancel();
      _apiOfflineRetryTimer = Timer(_apiOfflineRetryDelay, () {
        _apiOfflineRetryTimer = null;
        if (!mounted || !_apiOffline) return;
        unawaited(_checkApi());
      });
    }

    return ok;
  }

  Future<void> _continueWithGoogle() async {
    final l10n = AppLocalizations.of(context)!;
    _dismissSessionNotice();
    setState(() {
      _googleLoading = true;
      _error = null;
    });
    try {
      final AuthSession? session = await _authGateway.continueWithGoogle();
      if (session == null) {
        if (mounted) setState(() => _error = l10n.signInCancelled);
        return;
      }
      if (!mounted) return;
      _handleLoginResult(session);
    } catch (error) {
      final String message = await _friendlySignInError(error, l10n);
      if (mounted) setState(() => _error = message);
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  Future<void> _continueWithApple() async {
    final l10n = AppLocalizations.of(context)!;
    _dismissSessionNotice();
    setState(() {
      _appleLoading = true;
      _error = null;
    });
    try {
      final AuthSession session = await _authGateway.continueWithApple();
      if (!mounted) return;
      _handleLoginResult(session);
    } catch (error) {
      final String message = await _friendlySignInError(error, l10n);
      if (mounted) setState(() => _error = message);
    } finally {
      if (mounted) setState(() => _appleLoading = false);
    }
  }

  Future<String> _friendlySignInError(
    Object error,
    AppLocalizations l10n,
  ) async {
    final String raw = error is ZephyrApiException
        ? error.message
        : error.toString();
    final String lower = raw.toLowerCase();

    if (lower.contains('cancel')) return l10n.signInCancelled;
    if (_isNetworkSignInError(error, lower)) {
      if (await _checkApi()) return l10n.signInFailedTryAgain;
      return l10n.signInNetworkError;
    }
    return l10n.signInFailedTryAgain;
  }

  bool _isNetworkSignInError(Object error, String lowerMessage) {
    return error is SocketException ||
        lowerMessage.contains('socket') ||
        lowerMessage.contains('network') ||
        lowerMessage.contains('connection') ||
        lowerMessage.contains('timed out');
  }

  void _handleLoginResult(AuthSession session) {
    final user = session.user;
    final needsSetup = user.onboardedAt == null;

    if (!needsSetup) {
      widget.onLoginSuccess(session.accessToken);
      return;
    }

    // User needs profile setup — navigate within the module
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProfileSetupScreen(
          apiClient: widget.apiClient,
          accessToken: session.accessToken,
          initialDisplayName: user.displayName,
          profileWriter: widget.profileWriter,
          countryCodeResolver: widget.countryCodeResolver,
          onComplete: () {
            Navigator.of(context).pop(); // pop setup screen
            widget.onLoginSuccess(session.accessToken);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sessionNotice = _visibleSessionNotice;
    final double bottomPad = MediaQuery.of(context).padding.bottom;
    final bool showApple = widget.showAppleSignIn ?? Platform.isIOS;

    return Scaffold(
      backgroundColor: const Color(0xFF150805),
      body: Stack(
        children: <Widget>[
          // ── Gradient background ───────────────────────────────────────────
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Color(0xFF150805),
                    Color(0xFF1E0A06),
                    Color(0xFF150805),
                  ],
                  stops: <double>[0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),

          // ── Content ───────────────────────────────────────────────────────
          SafeArea(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final bool needsCompactHero =
                    constraints.maxHeight < 720 ||
                    sessionNotice != null ||
                    _apiOffline ||
                    _error != null;
                final double heroFraction = needsCompactHero ? 0.48 : 0.58;
                final double minHeroHeight = constraints.maxHeight < 640
                    ? 200
                    : 240;
                final double naturalMaxHeroHeight =
                    constraints.maxHeight * 0.58;
                final double maxHeroHeight =
                    naturalMaxHeroHeight < minHeroHeight
                    ? minHeroHeight
                    : naturalMaxHeroHeight;
                final double heroHeight = (constraints.maxHeight * heroFraction)
                    .clamp(minHeroHeight, maxHeroHeight)
                    .toDouble();

                return Column(
                  children: <Widget>[
                    // ── Top: mascot branding ──────────────────────────────
                    SizedBox(
                      height: heroHeight,
                      child: Center(
                        child:
                            widget.brandHero ??
                            Image.asset(
                              'assets/images/zephyr_mascot.png',
                              width: MediaQuery.of(context).size.width * 0.85,
                              height: heroHeight * 0.9,
                              fit: BoxFit.contain,
                            ),
                      ),
                    ),

                    // ── Bottom: buttons ───────────────────────────────────
                    Expanded(
                      child: LayoutBuilder(
                        builder:
                            (
                              BuildContext context,
                              BoxConstraints bottomConstraints,
                            ) {
                              final double bottomInset = bottomPad + 24;
                              final double minBottomHeight =
                                  bottomConstraints.maxHeight > bottomInset
                                  ? bottomConstraints.maxHeight - bottomInset
                                  : 0;

                              return SingleChildScrollView(
                                padding: EdgeInsets.fromLTRB(
                                  28,
                                  0,
                                  28,
                                  bottomInset,
                                ),
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minHeight: minBottomHeight,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: <Widget>[
                                      // Offline warning
                                      if (_apiOffline)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 16,
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: <Widget>[
                                              const Icon(
                                                Icons.wifi_off_rounded,
                                                color: Colors.orange,
                                                size: 16,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                l10n.apiOffline,
                                                style: const TextStyle(
                                                  color: Colors.orange,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                      if (sessionNotice != null)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 16,
                                          ),
                                          child: Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 12,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(
                                                0xFFFF8F00,
                                              ).withValues(alpha: 0.16),
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              border: Border.all(
                                                color: const Color(
                                                  0xFFFFB347,
                                                ).withValues(alpha: 0.36),
                                              ),
                                            ),
                                            child: Text(
                                              sessionNotice,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                color: Color(0xFFFFD7A3),
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                height: 1.25,
                                              ),
                                            ),
                                          ),
                                        ),

                                      // Apple button (iOS only, shown first)
                                      if (showApple) ...<Widget>[
                                        _SignInButton(
                                          onTap: _googleLoading || _appleLoading
                                              ? null
                                              : _continueWithApple,
                                          loading: _appleLoading,
                                          semanticLabel: l10n.continueWithApple,
                                          backgroundColor: Colors.black,
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: <Widget>[
                                              if (!_appleLoading)
                                                const Icon(
                                                  Icons.apple,
                                                  color: Colors.white,
                                                  size: 22,
                                                ),
                                              if (!_appleLoading)
                                                const SizedBox(width: 8),
                                              Text(
                                                _appleLoading
                                                    ? l10n.signingIn
                                                    : l10n.continueWithApple,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                      ],

                                      // Google button
                                      _SignInButton(
                                        onTap: _googleLoading || _appleLoading
                                            ? null
                                            : _continueWithGoogle,
                                        loading: _googleLoading,
                                        semanticLabel: l10n.continueWithGoogle,
                                        backgroundColor: const Color(
                                          0xFF2A2A2A,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: <Widget>[
                                            // Google "G" logo colours
                                            if (!_googleLoading)
                                              const _GoogleLogo(),
                                            if (!_googleLoading)
                                              const SizedBox(width: 10),
                                            Text(
                                              _googleLoading
                                                  ? l10n.signingIn
                                                  : l10n.continueWithGoogle,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Error
                                      if (_error != null) ...<Widget>[
                                        const SizedBox(height: 16),
                                        Text(
                                          _error!,
                                          style: const TextStyle(
                                            color: Colors.redAccent,
                                            fontSize: 13,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ],

                                      // Legal links
                                      const SizedBox(height: 16),
                                      Text(
                                        l10n.ageGateNotice,
                                        style: const TextStyle(
                                          color: Color(0xB3FFFFFF),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 4),
                                      _LegalLinks(l10n: l10n),
                                    ],
                                  ),
                                ),
                              );
                            },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sign-in button ────────────────────────────────────────────────────────────

class _SignInButton extends StatelessWidget {
  const _SignInButton({
    required this.child,
    required this.backgroundColor,
    required this.onTap,
    required this.loading,
    required this.semanticLabel,
  });

  final Widget child;
  final Color backgroundColor;
  final VoidCallback? onTap;
  final bool loading;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: semanticLabel,
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: Material(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : FittedBox(fit: BoxFit.scaleDown, child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LegalLinks extends StatelessWidget {
  const _LegalLinks({required this.l10n});

  final AppLocalizations l10n;

  Future<void> _open(String path) {
    return launchUrl(
      Uri.parse('$apiBaseUrl$path'),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    const TextStyle baseStyle = TextStyle(
      color: Color(0x73FFFFFF),
      fontSize: 11.5,
    );
    final ButtonStyle linkStyle = TextButton.styleFrom(
      foregroundColor: const Color(0xFFFF8F00),
      padding: const EdgeInsets.symmetric(horizontal: 2),
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: baseStyle.copyWith(decoration: TextDecoration.underline),
    );

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        Text(l10n.byContinuingPrefix, style: baseStyle),
        TextButton(
          style: linkStyle,
          onPressed: () => _open('/legal/terms'),
          child: Text(l10n.termsOfService),
        ),
        Text(l10n.byContinuingAnd, style: baseStyle),
        TextButton(
          style: linkStyle,
          onPressed: () => _open('/legal/privacy'),
          child: Text(l10n.privacy),
        ),
      ],
    );
  }
}

// ── Google "G" logo (official SVG paths) ─────────────────────────────────────

class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo();

  // Official Google G logo paths (same as Google's sign-in button spec).
  static const String _svg = '''
<svg viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
  <path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z" fill="#4285F4"/>
  <path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" fill="#34A853"/>
  <path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z" fill="#FBBC05"/>
  <path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" fill="#EA4335"/>
</svg>
''';

  @override
  Widget build(BuildContext context) {
    return SvgPicture.string(_svg, width: 20, height: 20);
  }
}
