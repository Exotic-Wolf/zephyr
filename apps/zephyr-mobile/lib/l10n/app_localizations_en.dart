// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get goLiveInSeconds => 'Go live in seconds';

  @override
  String get checkingApi => 'Checking API...';

  @override
  String get apiConnected => 'API Connected';

  @override
  String get apiOffline => 'API Offline';

  @override
  String get refreshApiStatus => 'Refresh API status';

  @override
  String get connecting => 'Connecting...';

  @override
  String get continueAsGuest => 'Continue as Guest';

  @override
  String get signingIn => 'Signing in...';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get continueWithApple => 'Continue with Apple';

  @override
  String get home => 'Home';

  @override
  String get live => 'Live';

  @override
  String get explore => 'Explore';

  @override
  String get inbox => 'Inbox';

  @override
  String get me => 'Me';

  @override
  String get noOneIsLiveRightNow =>
      'No one is live right now. Check again in a moment.';

  @override
  String noResultsFor(String query) {
    return 'No results for \"$query\".';
  }

  @override
  String noOneIsLiveFrom(String location) {
    return 'No one is live from $location right now.';
  }

  @override
  String get popular => 'Popular';

  @override
  String get discover => 'Discover';

  @override
  String get follow => 'Follow';

  @override
  String get noPopularStreamersRightNow =>
      'No popular streamers right now. Check again in a moment.';

  @override
  String noStreamersFrom(String location) {
    return 'No streamers from $location right now.';
  }

  @override
  String noneOfPeopleYouFollowAreLive(String location) {
    return 'None of the people you follow are live from $location right now.';
  }

  @override
  String get followSomeoneToSeeThemHere => 'Follow someone to see them here.';

  @override
  String get openingLive => 'Opening live...';

  @override
  String get randomMatch => 'Random match';

  @override
  String get goLive => 'Go Live';

  @override
  String get startLiveStreamAndConnect =>
      'Start a live stream and connect\nwith your audience in real time';

  @override
  String get starting => 'Starting…';

  @override
  String get startLiveStream => 'Start Live Stream';

  @override
  String get level => 'Level';

  @override
  String levelValue(int level) {
    return 'Level $level';
  }

  @override
  String get keepStreamingToLevelUp =>
      'Keep streaming, receiving gifts, and engaging to level up.';

  @override
  String get myBalance => 'My Balance';

  @override
  String get coinBalance => 'Coin Balance';

  @override
  String coinsAmount(int coins) {
    return '$coins coins';
  }

  @override
  String get buyCoins => 'Buy Coins';

  @override
  String coinPackLabel(int coins, String label) {
    return '$coins coins • $label';
  }

  @override
  String get buying => 'Buying...';

  @override
  String get buy => 'Buy';

  @override
  String get myRevenue => 'My Revenue';

  @override
  String get revenueFromGiftsAndCalls =>
      'Revenue from gifts and paid calls appears here.';

  @override
  String get settings => 'Settings';

  @override
  String get account => 'Account';

  @override
  String get privacy => 'Privacy';

  @override
  String get notifications => 'Notifications';

  @override
  String get language => 'Language';

  @override
  String get appearance => 'Appearance';

  @override
  String get search => 'Search';

  @override
  String get closeSearch => 'Close search';

  @override
  String get nameOrId => 'Name or ID…';

  @override
  String get refresh => 'Refresh';

  @override
  String get logout => 'Logout';

  @override
  String get systemDefault => 'System default';

  @override
  String get followDeviceSetting => 'Follow device setting';

  @override
  String get lightMode => 'Light';

  @override
  String get alwaysUseLightMode => 'Always use light mode';

  @override
  String get darkMode => 'Dark';

  @override
  String get alwaysUseDarkMode => 'Always use dark mode';

  @override
  String get owner => 'OWNER';

  @override
  String get callSessionStarted => 'Call session started. Billing is live.';

  @override
  String get notEnoughCoinsForRandomMatch =>
      'Not enough coins for random match. Top up first.';

  @override
  String get noReceiverAvailable =>
      'No receiver available for direct call. Try Random mode.';

  @override
  String get callEndedInsufficientBalance =>
      'Call ended: insufficient balance.';

  @override
  String get callEnded => 'Call ended.';

  @override
  String get noMessagesYet => 'No messages yet';

  @override
  String get noMessagesYetSayHello => 'No messages yet. Say hello!';

  @override
  String get messageHint => 'Message…';

  @override
  String failedToSend(String error) {
    return 'Failed to send: $error';
  }

  @override
  String get findAnyoneByNameOrId => 'Find anyone by name or 8-digit ID';

  @override
  String get nameOrIdHint => 'Name or 8-digit ID…';

  @override
  String get discoverPeople => 'Discover people';

  @override
  String get searchByNameOrId =>
      'Search by name or enter an\nexact 8-digit public ID';

  @override
  String get noUsersFound => 'No users found';

  @override
  String get tryDifferentNameOrId => 'Try a different name or ID';

  @override
  String get myProfile => 'My Profile';

  @override
  String get save => 'Save';

  @override
  String get edit => 'Edit';

  @override
  String get id => 'ID';

  @override
  String get idCopiedToClipboard => 'ID copied to clipboard';

  @override
  String get nickname => 'Nickname';

  @override
  String get enterNickname => 'Enter nickname';

  @override
  String get gender => 'Gender';

  @override
  String get male => 'Male';

  @override
  String get female => 'Female';

  @override
  String get nonBinary => 'Non-binary';

  @override
  String get preferNotToSay => 'Prefer not to say';

  @override
  String get birthday => 'Birthday';

  @override
  String get notSet => 'Not set';

  @override
  String get country => 'Country';

  @override
  String get yourIdIsPermanent => 'Your ID is permanent and cannot be changed.';

  @override
  String get viewPublicProfile => 'View Public Profile';

  @override
  String get takePhoto => 'Take Photo';

  @override
  String get chooseFromLibrary => 'Choose from Library';

  @override
  String get ownerBadge => '👑  OWNER';

  @override
  String get avatarUpdated => 'Avatar updated';

  @override
  String uploadFailed(String error) {
    return 'Upload failed: $error';
  }

  @override
  String get profileSaved => 'Profile saved';

  @override
  String failedToSaveProfile(String error) {
    return 'Failed to save: $error';
  }

  @override
  String get myCallPrice => 'My Call Price';

  @override
  String get spark => 'Spark';

  @override
  String get youEarnSparks => 'You earn Sparks every second you\'re on a call';

  @override
  String get fairPricingGetsMoreCalls =>
      'Fair pricing gets you more calls, faster';

  @override
  String get callersWillSee => 'Callers will see:';

  @override
  String get videoCall => 'Video call';

  @override
  String get perMinute => '/min';

  @override
  String get chooseYourRate => 'Choose your rate';

  @override
  String yourLevelIs(int level) {
    return 'Your level is $level. Higher tiers unlock at higher levels.';
  }

  @override
  String get tier => 'Tier';

  @override
  String get youEarn => 'You earn';

  @override
  String get callerPays => 'Caller pays';

  @override
  String get callRateSaved => 'Call rate saved';

  @override
  String failedToSaveRate(String error) {
    return 'Failed to save: $error';
  }

  @override
  String get lockedTiersUnlock =>
      'Locked tiers unlock as you level up by being active on Zephyr.';

  @override
  String videoCallWithRate(String rate) {
    return 'Video call $rate';
  }

  @override
  String get messageButton => 'Message';

  @override
  String get notAvailable => 'Not available';

  @override
  String get currentlyBusy => 'Currently busy';

  @override
  String get followers => 'Followers';

  @override
  String get followButton => 'Follow';

  @override
  String get followingButton => 'Following';

  @override
  String get about => 'About';

  @override
  String get noBioYet => 'No bio yet.';

  @override
  String get gifts => 'Gifts';

  @override
  String get noGiftsYet => 'No gifts yet.';

  @override
  String get getReady => 'Get ready!';

  @override
  String get startingYourStream => 'Starting your stream…';

  @override
  String get cancel => 'Cancel';

  @override
  String get liveIndicator => 'LIVE';

  @override
  String get endLive => 'End Live?';

  @override
  String get streamWillEndMessage =>
      'Your stream will end and viewers will be disconnected.';

  @override
  String get endLiveButton => 'End Live';

  @override
  String get startingCamera => 'Starting camera…';

  @override
  String get cameraIsOff => 'Camera is off';

  @override
  String get micOn => 'Mic On';

  @override
  String get micOff => 'Mic Off';

  @override
  String get camera => 'Camera';

  @override
  String get off => 'Off';

  @override
  String get flip => 'Flip';

  @override
  String totalWatching(int total) {
    return '$total watching';
  }

  @override
  String get noViewersYet => 'No viewers yet';

  @override
  String andMoreWatching(int count) {
    return 'and $count more watching…';
  }

  @override
  String get saySomething => 'Say something…';

  @override
  String get welcomeToLive => 'Welcome to my live! 👋';
}
