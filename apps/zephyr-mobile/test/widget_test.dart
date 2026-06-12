import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zephyr_mobile/features/call/call_ended_screen.dart';
import 'package:zephyr_mobile/features/call/direct_call_screen.dart';
import 'package:zephyr_mobile/features/home/host_card_cover_assets.dart';
import 'package:zephyr_mobile/features/home/widgets/follow_feed.dart';
import 'package:zephyr_mobile/features/me/me_tab.dart';
import 'package:zephyr_mobile/features/onboarding/onboarding_page.dart';
import 'package:zephyr_mobile/l10n/app_localizations.dart';
import 'package:zephyr_mobile/main.dart' as zephyr_app;
import 'package:zephyr_mobile/models/models.dart';
import 'package:zephyr_mobile/services/api_client.dart';
import 'package:zephyr_mobile/services/api_error_messages.dart';
import 'package:zephyr_mobile/widgets/zephyr_app_header.dart';

void main() {
  testWidgets(
    'onboarding shows current OAuth/legal surface without guest copy',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _localizedHost(
          OnboardingScreen(
            apiClient: _FakeApiClient(),
            authGateway: _FakeAuthGateway(),
            showAppleSignIn: false,
            brandHero: const SizedBox(key: Key('test-hero'), height: 120),
            onLoginSuccess: (_) {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Continue as Guest'), findsNothing);
      expect(find.text('You must be 17+ to use Zephyr.'), findsOneWidget);
      expect(find.text('Terms of Service'), findsOneWidget);
      expect(find.text('Privacy'), findsOneWidget);
    },
  );

  testWidgets('onboarding explains when another device takes the account', (
    WidgetTester tester,
  ) async {
    const notice =
        'This account was signed in on another device. Sign in again to continue on this device.';

    await tester.pumpWidget(
      _localizedHost(
        OnboardingScreen(
          apiClient: _FakeApiClient(),
          authGateway: _FakeAuthGateway(),
          showAppleSignIn: false,
          brandHero: const SizedBox(key: Key('test-hero'), height: 120),
          sessionNotice: notice,
          onLoginSuccess: (_) {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text(notice), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
  });

  testWidgets('onboarding stale-session notice fits compact safe-area phones', (
    WidgetTester tester,
  ) async {
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    const notice =
        'This account was signed in on another device. Sign in again to continue on this device.';
    const viewportSize = Size(402, 700);

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = viewportSize;

    await tester.pumpWidget(
      _localizedHost(
        MediaQuery(
          data: const MediaQueryData(
            size: viewportSize,
            padding: EdgeInsets.only(top: 59, bottom: 34),
          ),
          child: OnboardingScreen(
            apiClient: _FakeApiClient(),
            authGateway: _FakeAuthGateway(),
            showAppleSignIn: true,
            brandHero: const SizedBox(key: Key('test-hero'), height: 120),
            sessionNotice: notice,
            onLoginSuccess: (_) {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text(notice), findsOneWidget);
    expect(find.text('Continue with Apple'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('You must be 17+ to use Zephyr.'), findsOneWidget);
  });

  testWidgets('stale-session notice does not block signing in again', (
    WidgetTester tester,
  ) async {
    const notice =
        'This account was signed in on another device. Sign in again to continue on this device.';
    String? completedToken;
    var noticeDismissed = false;

    await tester.pumpWidget(
      _localizedHost(
        OnboardingScreen(
          apiClient: _FakeApiClient(),
          authGateway: _FakeAuthGateway(
            googleSession: AuthSession(
              accessToken: 'tablet-token',
              user: _profile(onboardedAt: DateTime(2026, 6, 10)),
            ),
          ),
          showAppleSignIn: false,
          brandHero: const SizedBox(key: Key('test-hero'), height: 120),
          sessionNotice: notice,
          onSessionNoticeDismissed: () => noticeDismissed = true,
          onLoginSuccess: (token) => completedToken = token,
        ),
      ),
    );
    await tester.pump();

    expect(find.text(notice), findsOneWidget);
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();

    expect(completedToken, 'tablet-token');
    expect(noticeDismissed, isTrue);
    expect(find.text(notice), findsNothing);
  });

  testWidgets('cancelled Google sign-in shows product-safe error copy', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _localizedHost(
        OnboardingScreen(
          apiClient: _FakeApiClient(),
          authGateway: _FakeAuthGateway(googleSession: null),
          showAppleSignIn: false,
          brandHero: const SizedBox(key: Key('test-hero'), height: 120),
          onLoginSuccess: (_) {},
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();

    expect(find.text('Sign-in cancelled.'), findsOneWidget);
  });

  testWidgets('transient API offline warning clears after retry', (
    WidgetTester tester,
  ) async {
    final apiClient = _FakeApiClient(pingResults: <bool>[false, true]);

    await tester.pumpWidget(
      _localizedHost(
        OnboardingScreen(
          apiClient: apiClient,
          authGateway: _FakeAuthGateway(),
          showAppleSignIn: false,
          brandHero: const SizedBox(key: Key('test-hero'), height: 120),
          onLoginSuccess: (_) {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('API Offline'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    expect(find.text('API Offline'), findsNothing);
    expect(apiClient.pingCalls, 2);
  });

  testWidgets('sign-in network error rechecks API before outage copy', (
    WidgetTester tester,
  ) async {
    final apiClient = _FakeApiClient(pingResults: <bool>[false, true]);

    await tester.pumpWidget(
      _localizedHost(
        OnboardingScreen(
          apiClient: apiClient,
          authGateway: _FakeAuthGateway(
            googleError: Exception('Socket closed'),
          ),
          showAppleSignIn: false,
          brandHero: const SizedBox(key: Key('test-hero'), height: 120),
          onLoginSuccess: (_) {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('API Offline'), findsOneWidget);

    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();

    expect(find.text('API Offline'), findsNothing);
    expect(
      find.text(
        "We couldn't reach Zephyr. Check your connection and try again.",
      ),
      findsNothing,
    );
    expect(
      find.text("We couldn't sign you in. Please try again."),
      findsOneWidget,
    );
    expect(apiClient.pingCalls, 2);
  });

  testWidgets('new OAuth user completes setup after backend and RTDB writes', (
    WidgetTester tester,
  ) async {
    final apiClient = _FakeApiClient();
    final profileWrite = Completer<void>();
    var profileWriteStarted = false;
    String? completedToken;

    await tester.pumpWidget(
      _localizedHost(
        OnboardingScreen(
          apiClient: apiClient,
          authGateway: _FakeAuthGateway(
            googleSession: AuthSession(
              accessToken: 'new-token',
              user: _profile(onboardedAt: null),
            ),
          ),
          showAppleSignIn: false,
          brandHero: const SizedBox(key: Key('test-hero'), height: 120),
          countryCodeResolver: () => 'mu',
          profileWriter:
              ({
                required String displayName,
                String? avatarUrl,
                required String countryCode,
                required String language,
                String? birthday,
              }) {
                profileWriteStarted = true;
                expect(displayName, 'Ava');
                expect(countryCode, 'MU');
                expect(language, 'en');
                return profileWrite.future;
              },
          onLoginSuccess: (token) => completedToken = token,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();

    expect(find.text('Gender'), findsOneWidget);
    await tester.tap(find.text('Male'));
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();

    expect(find.text('Your language'), findsOneWidget);
    await tester.tap(find.text('English'));
    await tester.pump();

    expect(apiClient.lastGender, 'Male');
    expect(apiClient.lastLanguage, 'en');
    expect(apiClient.lastCountryCode, 'MU');
    expect(profileWriteStarted, isTrue);
    expect(completedToken, isNull);

    profileWrite.complete();
    await tester.pumpAndSettle();

    expect(completedToken, 'new-token');
  });

  test('following parser accepts deployed string IDs and legacy objects', () {
    expect(
      parseFollowingIdsResponse(<dynamic>[
        'host-1',
        <String, dynamic>{'userId': 'host-2'},
        <String, dynamic>{'id': 'ignored'},
      ]),
      <String>{'host-1', 'host-2'},
    );
  });

  test('auth session detector separates moved sessions from expired tokens', () {
    const expired = ZephyrApiException(
      statusCode: 401,
      message: 'Invalid or expired token',
      responseBody: '{}',
    );
    const moved = ZephyrApiException(
      statusCode: 401,
      message: 'Session moved to another device',
      responseBody: '{}',
    );
    const forbiddenBusinessError = ZephyrApiException(
      statusCode: 403,
      message: 'Purchase is not allowed for this account',
      responseBody: '{}',
    );
    final firestoreDenied = Exception(
      '[cloud_firestore/permission-denied] The caller does not have permission.',
    );

    expect(isAuthSessionInvalidError(expired), isTrue);
    expect(isSessionMovedToAnotherDeviceError(expired), isFalse);
    expect(isAuthSessionInvalidError(moved), isTrue);
    expect(isSessionMovedToAnotherDeviceError(moved), isTrue);
    expect(isAuthSessionInvalidError(forbiddenBusinessError), isFalse);
    expect(isAuthSessionInvalidError(firestoreDenied), isFalse);
    expect(isFirebasePermissionDeniedError(firestoreDenied), isTrue);
    expect(isSessionMovedToAnotherDeviceError(firestoreDenied), isFalse);
    expect(isAuthSessionInvalidError(Exception('Socket closed')), isFalse);
    expect(
      apiErrorMessage(firestoreDenied),
      'Your secure session changed. Please sign in again.',
    );
    expect(
      apiErrorMessage(Exception('[firebase_storage/unauthorized] User denied')),
      'Your secure session changed. Please sign in again.',
    );
    expect(
      apiErrorMessage(Exception('Unsupported image format')),
      'This photo format is not supported. Try another photo.',
    );
    expect(
      apiErrorMessage(Exception('Photo is too large after compression')),
      'This photo is too large. Choose a smaller photo.',
    );
    expect(
      apiErrorMessage(Exception('Socket closed')),
      'Connection issue. Please try again.',
    );
  });

  test('user logout suppresses false another-device notice', () {
    final DateTime now = DateTime(2026, 6, 11, 12);

    expect(
      zephyr_app.shouldSuppressSessionMovedNoticeForLogout(
        loggingOut: true,
        suppressUntil: null,
        now: now,
      ),
      isTrue,
    );
    expect(
      zephyr_app.shouldSuppressSessionMovedNoticeForLogout(
        loggingOut: false,
        suppressUntil: now.add(const Duration(seconds: 10)),
        now: now,
      ),
      isTrue,
    );
    expect(
      zephyr_app.shouldSuppressSessionMovedNoticeForLogout(
        loggingOut: false,
        suppressUntil: now.subtract(const Duration(seconds: 1)),
        now: now,
      ),
      isFalse,
    );
  });

  testWidgets('presence activity observer restores away from pushed routes', (
    WidgetTester tester,
  ) async {
    var awayWrites = 0;
    var restoreWrites = 0;

    await tester.pumpWidget(
      MaterialApp(
        builder: (BuildContext context, Widget? child) {
          return zephyr_app.PresenceActivityObserver(
            enabled: true,
            awayTimeout: const Duration(seconds: 1),
            setAway: () => awayWrites++,
            restoreOnline: () => restoreWrites++,
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: const _PresenceRouteHarness(),
      ),
    );

    await tester.tap(find.text('Open pushed route'));
    await tester.pumpAndSettle();

    await tester.pump(const Duration(milliseconds: 1100));
    expect(awayWrites, 1);
    expect(restoreWrites, 0);

    await tester.tap(find.text('Touch pushed route'));
    await tester.pump();

    expect(restoreWrites, 1);
  });

  testWidgets('follow feed has a useful empty state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _localizedHost(
        FollowFeed(
          cards: <LiveFeedCard>[_feedCard()],
          followingIds: const <String>{},
          filterCountryName: null,
          isTablet: false,
          onCardTap: (_) {},
          onProfileTap: (_) {},
          onRandomMatch: () {},
          showRandomMatch: true,
        ),
      ),
    );

    expect(find.text('Follow someone to see them here.'), findsOneWidget);
  });

  testWidgets('follow feed can hide random match for host accounts', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _localizedHost(
        FollowFeed(
          cards: <LiveFeedCard>[_feedCard()],
          followingIds: const <String>{},
          filterCountryName: null,
          isTablet: false,
          onCardTap: (_) {},
          onProfileTap: (_) {},
          onRandomMatch: () {},
          showRandomMatch: false,
        ),
      ),
    );

    expect(find.text('Random match'), findsNothing);
  });

  test('host card cover assignment is stable and local', () {
    final String first = HostCardCoverAssets.forUserId('host-1');
    final String second = HostCardCoverAssets.forUserId('host-1');

    expect(first, second);
    expect(first, startsWith('assets/images/host_covers/'));
    expect(HostCardCoverAssets.all, hasLength(6));
    expect(HostCardCoverAssets.all.toSet(), hasLength(6));
  });

  testWidgets('zephyr header replaces Me tab with avatar and wallet access', (
    WidgetTester tester,
  ) async {
    var avatarTapped = false;
    var rechargeTapped = false;

    await tester.pumpWidget(
      _localizedHost(
        Scaffold(
          body: Center(
            child: ZephyrAppHeader(
              me: _profile(),
              wallet: WalletSummary(
                coinBalance: 12345,
                level: 4,
                revenueUsd: 0,
                sparkBalance: 678,
              ),
              apiReachable: true,
              onAvatarTap: () => avatarTapped = true,
              onRechargeTap: () => rechargeTapped = true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('12.3K'), findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Open profile'));
    await tester.tap(find.byIcon(Icons.add_rounded));
    expect(avatarTapped, isTrue);
    expect(rechargeTapped, isTrue);

    await tester.pumpWidget(
      _localizedHost(
        Scaffold(
          body: Center(
            child: ZephyrAppHeader(
              me: _profile(isHost: true),
              wallet: WalletSummary(
                coinBalance: 12345,
                level: 4,
                revenueUsd: 0,
                sparkBalance: 678,
              ),
              onAvatarTap: () {},
              onRechargeTap: null,
            ),
          ),
        ),
      ),
    );

    expect(find.text('678'), findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsNothing);
  });

  testWidgets('direct call exposes safety UI and post-call screen reports', (
    WidgetTester tester,
  ) async {
    final apiClient = _FakeApiClient();

    await tester.pumpWidget(
      MaterialApp(
        home: DirectCallScreen(
          apiClient: apiClient,
          accessToken: 'token',
          sessionId: 'session-1',
          appId: 'agora-app',
          channelName: 'channel',
          uid: 1,
          token: 'rtc-token',
          partnerId: 'host-1',
          partnerName: 'Mira',
          myUserId: 'me-1',
          myDisplayName: 'Ava',
          startMedia: false,
          managePresence: false,
        ),
      ),
    );

    expect(find.byKey(const Key('direct-call-report-button')), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: CallEndedScreen(
          apiClient: apiClient,
          accessToken: 'token',
          sessionId: 'session-1',
          partnerId: 'host-1',
          partnerName: 'Mira',
          myUserId: 'me-1',
          myDisplayName: 'Ava',
        ),
      ),
    );

    expect(find.text('Call ended'), findsOneWidget);
    expect(find.text('Message'), findsOneWidget);
    expect(find.text('Report call'), findsOneWidget);

    await tester.tap(find.byKey(const Key('call-ended-report-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Harassment or abuse'));
    await tester.pumpAndSettle();

    expect(apiClient.reportedSessionId, 'session-1');
    expect(apiClient.reportedUserId, 'host-1');
  });

  testWidgets('me tab shows economy overview and settings subpages', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _localizedHost(
        MeTab(
          me: _profile(
            onboardedAt: DateTime(2026, 6, 7),
            callRateCoinsPerMinute: 4200,
          ),
          apiClient: _FakeApiClient(),
          accessToken: 'token',
          onLogout: () async {},
          onDeleteAccount: () async {},
          locale: null,
          onLocaleChanged: (_) {},
          themeMode: ThemeMode.system,
          onThemeModeChanged: (_) {},
          onProfileUpdated: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Coins'), findsOneWidget);
    expect(find.text('Sparks'), findsOneWidget);
    expect(find.text('Revenue'), findsOneWidget);
    expect(find.text('Call price'), findsOneWidget);
    expect(find.text('12.3K'), findsOneWidget);
    expect(find.text('\$12.34'), findsOneWidget);
    expect(find.text('4.2K /min'), findsOneWidget);

    await tester.ensureVisible(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Privacy'));
    await tester.pumpAndSettle();
    expect(find.text('Privacy controls'), findsOneWidget);
    expect(find.text('Privacy Policy'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Notifications'));
    await tester.pumpAndSettle();
    expect(find.text('Message alerts'), findsOneWidget);
    expect(find.text('Incoming call alerts'), findsOneWidget);
  });
}

Widget _localizedHost(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );
}

UserProfile _profile({
  DateTime? onboardedAt,
  int? callRateCoinsPerMinute,
  bool isHost = false,
}) {
  return UserProfile(
    id: 'user-1',
    displayName: 'Ava',
    avatarUrl: null,
    bio: null,
    createdAt: DateTime(2026, 6, 7),
    onboardedAt: onboardedAt,
    callRateCoinsPerMinute: callRateCoinsPerMinute,
    isHost: isHost,
  );
}

LiveFeedCard _feedCard() {
  return LiveFeedCard(
    roomId: null,
    title: 'Mira',
    audienceCount: 0,
    hostUserId: 'host-1',
    hostDisplayName: 'Mira',
    hostAvatarUrl: null,
    hostCountryCode: 'PH',
    hostLanguage: 'English',
    hostStatus: 'online',
    startedAt: DateTime(2026, 6, 7),
  );
}

class _PresenceRouteHarness extends StatelessWidget {
  const _PresenceRouteHarness();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () {},
                      child: const Text('Touch pushed route'),
                    ),
                  ),
                ),
              ),
            );
          },
          child: const Text('Open pushed route'),
        ),
      ),
    );
  }
}

class _FakeAuthGateway implements OnboardingAuthGateway {
  _FakeAuthGateway({
    AuthSession? googleSession,
    Object? googleError,
    Object? appleError,
  }) : _googleSession = googleSession,
       _googleError = googleError,
       _appleError = appleError;

  final AuthSession? _googleSession;
  final Object? _googleError;
  final Object? _appleError;

  @override
  Future<AuthSession?> continueWithGoogle() async {
    final error = _googleError;
    if (error != null) throw error;
    return _googleSession;
  }

  @override
  Future<AuthSession> continueWithApple() async {
    final error = _appleError;
    if (error != null) throw error;
    return AuthSession(accessToken: 'apple-token', user: _profile());
  }
}

class _FakeApiClient extends ZephyrApiClient {
  _FakeApiClient({List<bool> pingResults = const <bool>[true]})
    : _pingResults = pingResults,
      super(baseUrl: 'http://localhost');

  String? lastGender;
  String? lastLanguage;
  String? lastCountryCode;
  String? reportedSessionId;
  String? reportedUserId;
  String? endedSessionId;
  int pingCalls = 0;
  final List<bool> _pingResults;

  @override
  Future<bool> ping() async {
    pingCalls += 1;
    if (_pingResults.isEmpty) return true;
    final int index = pingCalls - 1;
    if (index < _pingResults.length) return _pingResults[index];
    return _pingResults.last;
  }

  @override
  Future<WalletSummary> getWalletSummary(String accessToken) async {
    return WalletSummary(
      coinBalance: 12345,
      level: 4,
      revenueUsd: 12.34,
      sparkBalance: 678,
    );
  }

  @override
  Future<UserProfile> updateMe(
    String accessToken, {
    String? displayName,
    String? gender,
    String? birthday,
    String? countryCode,
    String? language,
    int? callRateCoinsPerMinute,
    String? publicId,
  }) async {
    expect(accessToken, 'new-token');
    lastGender = gender;
    lastLanguage = language;
    lastCountryCode = countryCode;
    return _profile(onboardedAt: DateTime(2026, 6, 7));
  }

  @override
  Future<void> reportCall({
    required String accessToken,
    required String sessionId,
    required String reportedUserId,
    String? reason,
  }) async {
    reportedSessionId = sessionId;
    this.reportedUserId = reportedUserId;
  }

  @override
  Future<CallSession> endCallSession({
    required String accessToken,
    required String sessionId,
    String reason = 'caller_ended',
  }) async {
    endedSessionId = sessionId;
    return CallSession(
      id: sessionId,
      callerUserId: 'me-1',
      receiverUserId: 'host-1',
      mode: 'direct',
      rateCoinsPerMinute: 600,
      totalBilledCoins: 0,
      status: 'ended',
      endReason: reason,
    );
  }
}
