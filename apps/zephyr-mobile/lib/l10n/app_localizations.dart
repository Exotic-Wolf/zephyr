import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
    Locale('es'),
    Locale('pt'),
  ];

  /// No description provided for @goLiveInSeconds.
  ///
  /// In en, this message translates to:
  /// **'Go live in seconds'**
  String get goLiveInSeconds;

  /// No description provided for @checkingApi.
  ///
  /// In en, this message translates to:
  /// **'Checking API...'**
  String get checkingApi;

  /// No description provided for @apiConnected.
  ///
  /// In en, this message translates to:
  /// **'API Connected'**
  String get apiConnected;

  /// No description provided for @apiOffline.
  ///
  /// In en, this message translates to:
  /// **'API Offline'**
  String get apiOffline;

  /// No description provided for @refreshApiStatus.
  ///
  /// In en, this message translates to:
  /// **'Refresh API status'**
  String get refreshApiStatus;

  /// No description provided for @connecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get connecting;

  /// No description provided for @continueAsGuest.
  ///
  /// In en, this message translates to:
  /// **'Continue as Guest'**
  String get continueAsGuest;

  /// No description provided for @signingIn.
  ///
  /// In en, this message translates to:
  /// **'Signing in...'**
  String get signingIn;

  /// No description provided for @continueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// No description provided for @continueWithApple.
  ///
  /// In en, this message translates to:
  /// **'Continue with Apple'**
  String get continueWithApple;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @live.
  ///
  /// In en, this message translates to:
  /// **'Live'**
  String get live;

  /// No description provided for @explore.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get explore;

  /// No description provided for @inbox.
  ///
  /// In en, this message translates to:
  /// **'Inbox'**
  String get inbox;

  /// No description provided for @me.
  ///
  /// In en, this message translates to:
  /// **'Me'**
  String get me;

  /// No description provided for @noOneIsLiveRightNow.
  ///
  /// In en, this message translates to:
  /// **'No one is live right now. Check again in a moment.'**
  String get noOneIsLiveRightNow;

  /// No description provided for @noResultsFor.
  ///
  /// In en, this message translates to:
  /// **'No results for \"{query}\".'**
  String noResultsFor(String query);

  /// No description provided for @noOneIsLiveFrom.
  ///
  /// In en, this message translates to:
  /// **'No one is live from {location} right now.'**
  String noOneIsLiveFrom(String location);

  /// No description provided for @popular.
  ///
  /// In en, this message translates to:
  /// **'Popular'**
  String get popular;

  /// No description provided for @discover.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get discover;

  /// No description provided for @follow.
  ///
  /// In en, this message translates to:
  /// **'Follow'**
  String get follow;

  /// No description provided for @noPopularStreamersRightNow.
  ///
  /// In en, this message translates to:
  /// **'No popular streamers right now. Check again in a moment.'**
  String get noPopularStreamersRightNow;

  /// No description provided for @noStreamersFrom.
  ///
  /// In en, this message translates to:
  /// **'No streamers from {location} right now.'**
  String noStreamersFrom(String location);

  /// No description provided for @noneOfPeopleYouFollowAreLive.
  ///
  /// In en, this message translates to:
  /// **'None of the people you follow are live from {location} right now.'**
  String noneOfPeopleYouFollowAreLive(String location);

  /// No description provided for @followSomeoneToSeeThemHere.
  ///
  /// In en, this message translates to:
  /// **'Follow someone to see them here.'**
  String get followSomeoneToSeeThemHere;

  /// No description provided for @openingLive.
  ///
  /// In en, this message translates to:
  /// **'Opening live...'**
  String get openingLive;

  /// No description provided for @randomMatch.
  ///
  /// In en, this message translates to:
  /// **'Random match'**
  String get randomMatch;

  /// No description provided for @goLive.
  ///
  /// In en, this message translates to:
  /// **'Go Live'**
  String get goLive;

  /// No description provided for @startLiveStreamAndConnect.
  ///
  /// In en, this message translates to:
  /// **'Start a live stream and connect\nwith your audience in real time'**
  String get startLiveStreamAndConnect;

  /// No description provided for @starting.
  ///
  /// In en, this message translates to:
  /// **'Starting…'**
  String get starting;

  /// No description provided for @startLiveStream.
  ///
  /// In en, this message translates to:
  /// **'Start Live Stream'**
  String get startLiveStream;

  /// No description provided for @level.
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get level;

  /// No description provided for @levelValue.
  ///
  /// In en, this message translates to:
  /// **'Level {level}'**
  String levelValue(int level);

  /// No description provided for @keepStreamingToLevelUp.
  ///
  /// In en, this message translates to:
  /// **'Keep streaming, receiving gifts, and engaging to level up.'**
  String get keepStreamingToLevelUp;

  /// No description provided for @myBalance.
  ///
  /// In en, this message translates to:
  /// **'My Balance'**
  String get myBalance;

  /// No description provided for @coinBalance.
  ///
  /// In en, this message translates to:
  /// **'Coin Balance'**
  String get coinBalance;

  /// No description provided for @coinsAmount.
  ///
  /// In en, this message translates to:
  /// **'{coins} coins'**
  String coinsAmount(int coins);

  /// No description provided for @buyCoins.
  ///
  /// In en, this message translates to:
  /// **'Buy Coins'**
  String get buyCoins;

  /// No description provided for @coinPackLabel.
  ///
  /// In en, this message translates to:
  /// **'{coins} coins • {label}'**
  String coinPackLabel(int coins, String label);

  /// No description provided for @buying.
  ///
  /// In en, this message translates to:
  /// **'Buying...'**
  String get buying;

  /// No description provided for @buy.
  ///
  /// In en, this message translates to:
  /// **'Buy'**
  String get buy;

  /// No description provided for @myRevenue.
  ///
  /// In en, this message translates to:
  /// **'My Revenue'**
  String get myRevenue;

  /// No description provided for @revenueFromGiftsAndCalls.
  ///
  /// In en, this message translates to:
  /// **'Revenue from gifts and paid calls appears here.'**
  String get revenueFromGiftsAndCalls;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacy;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @closeSearch.
  ///
  /// In en, this message translates to:
  /// **'Close search'**
  String get closeSearch;

  /// No description provided for @nameOrId.
  ///
  /// In en, this message translates to:
  /// **'Name or ID…'**
  String get nameOrId;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @systemDefault.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get systemDefault;

  /// No description provided for @followDeviceSetting.
  ///
  /// In en, this message translates to:
  /// **'Follow device setting'**
  String get followDeviceSetting;

  /// No description provided for @lightMode.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get lightMode;

  /// No description provided for @alwaysUseLightMode.
  ///
  /// In en, this message translates to:
  /// **'Always use light mode'**
  String get alwaysUseLightMode;

  /// No description provided for @darkMode.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get darkMode;

  /// No description provided for @alwaysUseDarkMode.
  ///
  /// In en, this message translates to:
  /// **'Always use dark mode'**
  String get alwaysUseDarkMode;

  /// No description provided for @owner.
  ///
  /// In en, this message translates to:
  /// **'OWNER'**
  String get owner;

  /// No description provided for @callSessionStarted.
  ///
  /// In en, this message translates to:
  /// **'Call session started. Billing is live.'**
  String get callSessionStarted;

  /// No description provided for @notEnoughCoinsForRandomMatch.
  ///
  /// In en, this message translates to:
  /// **'Not enough coins for random match. Top up first.'**
  String get notEnoughCoinsForRandomMatch;

  /// No description provided for @noReceiverAvailable.
  ///
  /// In en, this message translates to:
  /// **'No receiver available for direct call. Try Random mode.'**
  String get noReceiverAvailable;

  /// No description provided for @callEndedInsufficientBalance.
  ///
  /// In en, this message translates to:
  /// **'Call ended: insufficient balance.'**
  String get callEndedInsufficientBalance;

  /// No description provided for @callEnded.
  ///
  /// In en, this message translates to:
  /// **'Call ended.'**
  String get callEnded;

  /// No description provided for @noMessagesYet.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get noMessagesYet;

  /// No description provided for @noMessagesYetSayHello.
  ///
  /// In en, this message translates to:
  /// **'No messages yet. Say hello!'**
  String get noMessagesYetSayHello;

  /// No description provided for @messageHint.
  ///
  /// In en, this message translates to:
  /// **'Message…'**
  String get messageHint;

  /// No description provided for @failedToSend.
  ///
  /// In en, this message translates to:
  /// **'Failed to send: {error}'**
  String failedToSend(String error);

  /// No description provided for @findAnyoneByNameOrId.
  ///
  /// In en, this message translates to:
  /// **'Find anyone by name or 8-digit ID'**
  String get findAnyoneByNameOrId;

  /// No description provided for @nameOrIdHint.
  ///
  /// In en, this message translates to:
  /// **'Name or 8-digit ID…'**
  String get nameOrIdHint;

  /// No description provided for @discoverPeople.
  ///
  /// In en, this message translates to:
  /// **'Discover people'**
  String get discoverPeople;

  /// No description provided for @searchByNameOrId.
  ///
  /// In en, this message translates to:
  /// **'Search by name or enter an\nexact 8-digit public ID'**
  String get searchByNameOrId;

  /// No description provided for @noUsersFound.
  ///
  /// In en, this message translates to:
  /// **'No users found'**
  String get noUsersFound;

  /// No description provided for @tryDifferentNameOrId.
  ///
  /// In en, this message translates to:
  /// **'Try a different name or ID'**
  String get tryDifferentNameOrId;

  /// No description provided for @myProfile.
  ///
  /// In en, this message translates to:
  /// **'My Profile'**
  String get myProfile;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @id.
  ///
  /// In en, this message translates to:
  /// **'ID'**
  String get id;

  /// No description provided for @idCopiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'ID copied to clipboard'**
  String get idCopiedToClipboard;

  /// No description provided for @nickname.
  ///
  /// In en, this message translates to:
  /// **'Nickname'**
  String get nickname;

  /// No description provided for @enterNickname.
  ///
  /// In en, this message translates to:
  /// **'Enter nickname'**
  String get enterNickname;

  /// No description provided for @gender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get gender;

  /// No description provided for @male.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get male;

  /// No description provided for @female.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get female;

  /// No description provided for @nonBinary.
  ///
  /// In en, this message translates to:
  /// **'Non-binary'**
  String get nonBinary;

  /// No description provided for @preferNotToSay.
  ///
  /// In en, this message translates to:
  /// **'Prefer not to say'**
  String get preferNotToSay;

  /// No description provided for @birthday.
  ///
  /// In en, this message translates to:
  /// **'Birthday'**
  String get birthday;

  /// No description provided for @notSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get notSet;

  /// No description provided for @country.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get country;

  /// No description provided for @yourIdIsPermanent.
  ///
  /// In en, this message translates to:
  /// **'Your ID is permanent and cannot be changed.'**
  String get yourIdIsPermanent;

  /// No description provided for @viewPublicProfile.
  ///
  /// In en, this message translates to:
  /// **'View Public Profile'**
  String get viewPublicProfile;

  /// No description provided for @takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take Photo'**
  String get takePhoto;

  /// No description provided for @chooseFromLibrary.
  ///
  /// In en, this message translates to:
  /// **'Choose from Library'**
  String get chooseFromLibrary;

  /// No description provided for @ownerBadge.
  ///
  /// In en, this message translates to:
  /// **'👑  OWNER'**
  String get ownerBadge;

  /// No description provided for @avatarUpdated.
  ///
  /// In en, this message translates to:
  /// **'Avatar updated'**
  String get avatarUpdated;

  /// No description provided for @uploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed: {error}'**
  String uploadFailed(String error);

  /// No description provided for @profileSaved.
  ///
  /// In en, this message translates to:
  /// **'Profile saved'**
  String get profileSaved;

  /// No description provided for @failedToSaveProfile.
  ///
  /// In en, this message translates to:
  /// **'Failed to save: {error}'**
  String failedToSaveProfile(String error);

  /// No description provided for @myCallPrice.
  ///
  /// In en, this message translates to:
  /// **'My Call Price'**
  String get myCallPrice;

  /// No description provided for @spark.
  ///
  /// In en, this message translates to:
  /// **'Spark'**
  String get spark;

  /// No description provided for @youEarnSparks.
  ///
  /// In en, this message translates to:
  /// **'You earn Sparks every second you\'re on a call'**
  String get youEarnSparks;

  /// No description provided for @fairPricingGetsMoreCalls.
  ///
  /// In en, this message translates to:
  /// **'Fair pricing gets you more calls, faster'**
  String get fairPricingGetsMoreCalls;

  /// No description provided for @callersWillSee.
  ///
  /// In en, this message translates to:
  /// **'Callers will see:'**
  String get callersWillSee;

  /// No description provided for @videoCall.
  ///
  /// In en, this message translates to:
  /// **'Video call'**
  String get videoCall;

  /// No description provided for @perMinute.
  ///
  /// In en, this message translates to:
  /// **'/min'**
  String get perMinute;

  /// No description provided for @chooseYourRate.
  ///
  /// In en, this message translates to:
  /// **'Choose your rate'**
  String get chooseYourRate;

  /// No description provided for @yourLevelIs.
  ///
  /// In en, this message translates to:
  /// **'Your level is {level}. Higher tiers unlock at higher levels.'**
  String yourLevelIs(int level);

  /// No description provided for @tier.
  ///
  /// In en, this message translates to:
  /// **'Tier'**
  String get tier;

  /// No description provided for @youEarn.
  ///
  /// In en, this message translates to:
  /// **'You earn'**
  String get youEarn;

  /// No description provided for @callerPays.
  ///
  /// In en, this message translates to:
  /// **'Caller pays'**
  String get callerPays;

  /// No description provided for @callRateSaved.
  ///
  /// In en, this message translates to:
  /// **'Call rate saved'**
  String get callRateSaved;

  /// No description provided for @failedToSaveRate.
  ///
  /// In en, this message translates to:
  /// **'Failed to save: {error}'**
  String failedToSaveRate(String error);

  /// No description provided for @lockedTiersUnlock.
  ///
  /// In en, this message translates to:
  /// **'Locked tiers unlock as you level up by being active on Zephyr.'**
  String get lockedTiersUnlock;

  /// No description provided for @videoCallWithRate.
  ///
  /// In en, this message translates to:
  /// **'Video call {rate}'**
  String videoCallWithRate(String rate);

  /// No description provided for @messageButton.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get messageButton;

  /// No description provided for @notAvailable.
  ///
  /// In en, this message translates to:
  /// **'Not available'**
  String get notAvailable;

  /// No description provided for @currentlyBusy.
  ///
  /// In en, this message translates to:
  /// **'Currently busy'**
  String get currentlyBusy;

  /// No description provided for @followers.
  ///
  /// In en, this message translates to:
  /// **'Followers'**
  String get followers;

  /// No description provided for @followButton.
  ///
  /// In en, this message translates to:
  /// **'Follow'**
  String get followButton;

  /// No description provided for @followingButton.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get followingButton;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @noBioYet.
  ///
  /// In en, this message translates to:
  /// **'No bio yet.'**
  String get noBioYet;

  /// No description provided for @gifts.
  ///
  /// In en, this message translates to:
  /// **'Gifts'**
  String get gifts;

  /// No description provided for @noGiftsYet.
  ///
  /// In en, this message translates to:
  /// **'No gifts yet.'**
  String get noGiftsYet;

  /// No description provided for @getReady.
  ///
  /// In en, this message translates to:
  /// **'Get ready!'**
  String get getReady;

  /// No description provided for @startingYourStream.
  ///
  /// In en, this message translates to:
  /// **'Starting your stream…'**
  String get startingYourStream;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @liveIndicator.
  ///
  /// In en, this message translates to:
  /// **'LIVE'**
  String get liveIndicator;

  /// No description provided for @endLive.
  ///
  /// In en, this message translates to:
  /// **'End Live?'**
  String get endLive;

  /// No description provided for @streamWillEndMessage.
  ///
  /// In en, this message translates to:
  /// **'Your stream will end and viewers will be disconnected.'**
  String get streamWillEndMessage;

  /// No description provided for @endLiveButton.
  ///
  /// In en, this message translates to:
  /// **'End Live'**
  String get endLiveButton;

  /// No description provided for @startingCamera.
  ///
  /// In en, this message translates to:
  /// **'Starting camera…'**
  String get startingCamera;

  /// No description provided for @cameraIsOff.
  ///
  /// In en, this message translates to:
  /// **'Camera is off'**
  String get cameraIsOff;

  /// No description provided for @micOn.
  ///
  /// In en, this message translates to:
  /// **'Mic On'**
  String get micOn;

  /// No description provided for @micOff.
  ///
  /// In en, this message translates to:
  /// **'Mic Off'**
  String get micOff;

  /// No description provided for @camera.
  ///
  /// In en, this message translates to:
  /// **'Camera'**
  String get camera;

  /// No description provided for @off.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get off;

  /// No description provided for @flip.
  ///
  /// In en, this message translates to:
  /// **'Flip'**
  String get flip;

  /// No description provided for @totalWatching.
  ///
  /// In en, this message translates to:
  /// **'{total} watching'**
  String totalWatching(int total);

  /// No description provided for @noViewersYet.
  ///
  /// In en, this message translates to:
  /// **'No viewers yet'**
  String get noViewersYet;

  /// No description provided for @andMoreWatching.
  ///
  /// In en, this message translates to:
  /// **'and {count} more watching…'**
  String andMoreWatching(int count);

  /// No description provided for @saySomething.
  ///
  /// In en, this message translates to:
  /// **'Say something…'**
  String get saySomething;

  /// No description provided for @welcomeToLive.
  ///
  /// In en, this message translates to:
  /// **'Welcome to my live! 👋'**
  String get welcomeToLive;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en', 'es', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
