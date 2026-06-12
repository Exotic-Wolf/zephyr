import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/models.dart';
import '../../services/api_error_messages.dart';
import '../../services/api_client.dart';
import '../../services/firebase_chat_service.dart';
import '../../services/translation_service.dart';
import '../../widgets/coin_icon.dart';
import '../call/direct_call_screen.dart';
import '../gifts/gift_module.dart';
import '../live/viewer_live_screen.dart';
import '../profile/profile_page.dart';
import 'live_preview_widget.dart';

enum _MediaSourceKind { camera, gallery }

class _MediaDraft {
  const _MediaDraft({required this.file, required this.source});

  final File file;
  final _MediaSourceKind source;
}

/// Firebase-backed thread page — completely isolated from the custom thread.
/// Uses Firestore real-time listeners for messages.
class ThreadFirebasePage extends StatefulWidget {
  const ThreadFirebasePage({
    super.key,
    required this.myUserId,
    required this.myDisplayName,
    this.myAvatarUrl,
    required this.otherUserId,
    required this.otherDisplayName,
    this.otherAvatarUrl,
  });

  final String myUserId;
  final String myDisplayName;
  final String? myAvatarUrl;
  final String otherUserId;
  final String otherDisplayName;
  final String? otherAvatarUrl;

  @override
  State<ThreadFirebasePage> createState() => _ThreadFirebasePageState();
}

class _ThreadFirebasePageState extends State<ThreadFirebasePage> {
  List<FirebaseMessage> _messages = [];
  List<FirebaseMessage> _olderMessages = [];
  StreamSubscription<List<FirebaseMessage>>? _sub;
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  bool _mediaTrayOpen = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _streamReady = false;
  String? _pressedMediaAction;
  String? _threadError;
  _MediaDraft? _mediaDraft;
  final Map<String, FirebaseMessage> _optimisticMessages = {};
  final Map<String, String> _failedSends = {};
  final Map<String, File> _pendingImageFiles = {};
  final Map<String, double> _pendingImageProgress = {};
  final Map<String, String> _pendingImageUrls = {};
  final Map<String, String> _translations = {}; // messageId -> translated text
  final Set<String> _translating = {}; // messageIds currently being translated
  final Set<String> _autoPlayedGiftEventIds = {};
  final List<GiftVisual> _giftAnimationQueue = [];
  bool _giftAnimationQueueRunning = false;

  // Live preview
  String? _liveRoomId;
  int _previewGen = 0;

  // Anti-spam
  final List<DateTime> _sendTimestamps = [];
  String? _lastSentText;
  static const int _maxMessagesPerWindow = 5;
  static const Duration _rateWindow = Duration(seconds: 10);
  static const Duration _duplicateCooldown = Duration(seconds: 30);

  // Direct call
  bool _calling = false;
  int? _callRateCoinsPerMinute;
  StreamSubscription<DatabaseEvent>? _callSub;
  Timer? _callTimeout;
  static const int _fallbackDirectCallRateCoinsPerMinute = 2100;

  String _generateKey() =>
      '${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(999999)}';

  void _debugDirectCall(String message) {
    assert(() {
      debugPrint('[ThreadDirectCall] $message');
      return true;
    }());
  }

  @override
  void initState() {
    super.initState();
    // Ensure presence and profile are warmed for this user
    FirebaseChatService.instance.warmPresence([widget.otherUserId]);
    FirebaseChatService.instance.warmProfiles([widget.otherUserId]);
    _seedCachedMessages();
    _ensureChatDocAndListen();
    _scrollCtrl.addListener(_onScroll);
    _lookupLiveRoom();
    _loadCallRate();
  }

  void _seedCachedMessages() {
    final service = FirebaseChatService.instance;
    if (!service.isInitializedFor(widget.myUserId)) return;
    final cached = service.cachedMessages(widget.otherUserId);
    if (cached.isEmpty) return;
    _messages = cached;
    _streamReady = true;
    _threadError = null;
    _scrollToBottom(jump: true);
  }

  /// Ensure the chat doc exists (with participants) before listening.
  /// Security rules on /messages require the parent doc's participants array.
  Future<void> _ensureChatDocAndListen({bool forceTokenRefresh = false}) async {
    try {
      await _sub?.cancel();
      _sub = null;

      final api = ZephyrApiClient.instance;
      final token = ZephyrApiClient.accessToken;
      final service = FirebaseChatService.instance;
      if (api != null &&
          token != null &&
          (forceTokenRefresh || !service.isInitializedFor(widget.myUserId))) {
        final String firebaseToken = await api.getFirebaseToken(token);
        await service.init(widget.myUserId, firebaseToken: firebaseToken);
      }

      final cached = await service.loadCachedMessages(widget.otherUserId);
      if (mounted && cached.isNotEmpty) {
        setState(() {
          _messages = cached;
          _streamReady = true;
          _threadError = null;
        });
        _scrollToBottom(jump: true);
      }

      await service.ensureChatDoc(
        widget.otherUserId,
        myDisplayName: widget.myDisplayName,
        myAvatarUrl: widget.myAvatarUrl,
        otherDisplayName: widget.otherDisplayName,
        otherAvatarUrl: widget.otherAvatarUrl,
      );
      if (!mounted) return;
      _sub = service
          .watchMessages(widget.otherUserId)
          .listen(
            (List<FirebaseMessage> msgs) {
              if (mounted) {
                final List<FirebaseMessage> incomingUnseenGifts = msgs
                    .where(
                      (FirebaseMessage message) =>
                          message.type == 'gift' &&
                          message.senderId == widget.otherUserId &&
                          message.readAt == null,
                    )
                    .toList(growable: false);
                final Set<String> committedIds = msgs.map((m) => m.id).toSet();
                setState(() {
                  _threadError = null;
                  _messages = msgs;
                  _streamReady = true;
                  for (final String id in committedIds) {
                    _pendingImageFiles.remove(id);
                    _pendingImageProgress.remove(id);
                    _pendingImageUrls.remove(id);
                  }
                  _optimisticMessages.removeWhere(
                    (id, _) => committedIds.contains(id),
                  );
                  _failedSends.removeWhere(
                    (id, _) => committedIds.contains(id),
                  );
                });
                _scrollToBottom();
                _queueIncomingGiftAnimations(incomingUnseenGifts);
                // Mark incoming messages as read continuously while chat is open
                _markIncomingRead(msgs);
              }
            },
            onError: (Object error) {
              if (!mounted) return;
              setState(() {
                _streamReady = true;
                _threadError = isFirebasePermissionDeniedError(error)
                    ? 'Messages are reconnecting. Please try again.'
                    : apiErrorMessage(error);
              });
            },
          );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _streamReady = true;
        _threadError = isFirebasePermissionDeniedError(error)
            ? 'Messages are reconnecting. Please try again.'
            : apiErrorMessage(error);
      });
    }
  }

  /// Fetches roomId from live feed if presence doesn't include it.
  Future<void> _lookupLiveRoom() async {
    final api = ZephyrApiClient.instance;
    final token = ZephyrApiClient.accessToken;
    if (api == null || token == null) return;
    try {
      final feed = await api.listLiveFeed(token);
      final match = feed
          .where((c) => c.hostUserId == widget.otherUserId)
          .firstOrNull;
      if (match?.roomId != null && mounted) {
        setState(() => _liveRoomId = match!.roomId);
      }
    } catch (_) {}
  }

  void _markIncomingRead(List<FirebaseMessage> msgs) {
    final bool hasUnread = msgs.any(
      (m) => m.senderId == widget.otherUserId && m.readAt == null,
    );
    if (hasUnread) {
      FirebaseChatService.instance.markRead(widget.otherUserId);
    }
  }

  GiftVisual _giftVisualFromMessage(FirebaseMessage message) {
    return GiftVisual(
      giftEventId: message.giftEventId ?? message.id,
      giftId: message.giftId ?? '',
      giftName: message.giftName ?? message.body,
      thumbnailUrl: message.giftThumbnailUrl ?? '',
      animationUrl: message.giftAnimationUrl ?? '',
      animationType: message.giftAnimationType ?? 'image',
      tier: message.giftTier ?? 'small',
      quantity: message.giftQuantity ?? 1,
      coinCost: message.giftCoinCost ?? 0,
      totalCoins: message.giftTotalCoins ?? message.giftCoinCost ?? 0,
    );
  }

  void _queueIncomingGiftAnimations(List<FirebaseMessage> messages) {
    if (messages.isEmpty) return;
    final Iterable<FirebaseMessage> playable = messages
        .where((FirebaseMessage message) {
          final String eventId = message.giftEventId ?? message.id;
          return eventId.isNotEmpty && _autoPlayedGiftEventIds.add(eventId);
        })
        .take(3);

    for (final FirebaseMessage message in playable) {
      _giftAnimationQueue.add(_giftVisualFromMessage(message));
    }
    if (!_giftAnimationQueueRunning && _giftAnimationQueue.isNotEmpty) {
      unawaited(_drainGiftAnimationQueue());
    }
  }

  Future<void> _drainGiftAnimationQueue() async {
    if (_giftAnimationQueueRunning) return;
    final OverlayState? giftOverlay = Overlay.maybeOf(
      context,
      rootOverlay: true,
    );
    if (giftOverlay == null) return;
    _giftAnimationQueueRunning = true;
    try {
      while (mounted && _giftAnimationQueue.isNotEmpty) {
        final GiftVisual visual = _giftAnimationQueue.removeAt(0);
        await GiftAnimationOverlay.playOnOverlay(giftOverlay, visual);
        if (_giftAnimationQueue.isNotEmpty) {
          await Future<void>.delayed(const Duration(milliseconds: 180));
        }
      }
    } finally {
      _giftAnimationQueueRunning = false;
    }
  }

  Future<void> _openGiftPicker() async {
    final ZephyrApiClient? api = ZephyrApiClient.instance;
    final String? token = ZephyrApiClient.accessToken;
    if (api == null || token == null || token.isEmpty) {
      _showSnack('Account session unavailable');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _mediaTrayOpen = false);

    final String contextId = FirebaseChatService.instance.chatId(
      widget.myUserId,
      widget.otherUserId,
    );
    final GiftSendResult? result = await showGiftPickerSheet(
      context: context,
      apiClient: api,
      accessToken: token,
      target: GiftSendTarget(
        surface: 'inbox',
        contextId: contextId,
        receiverUserId: widget.otherUserId,
        receiverDisplayName: widget.otherDisplayName,
      ),
    );
    if (!mounted || result == null) return;
    unawaited(
      GiftAnimationOverlay.play(context, GiftVisual.fromSendResult(result)),
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    _callSub?.cancel();
    _callTimeout?.cancel();
    _inputCtrl.dispose();
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Load more when scrolled near the top (reverse list, so maxScrollExtent = top)
    if (_scrollCtrl.position.pixels >=
            _scrollCtrl.position.maxScrollExtent - 100 &&
        !_loadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    final allMessages = [..._olderMessages, ..._messages];
    if (allMessages.isEmpty) return;
    setState(() => _loadingMore = true);
    try {
      final oldest = allMessages.first.createdAt;
      final older = await FirebaseChatService.instance.loadMoreMessages(
        widget.otherUserId,
        oldest,
      );
      if (mounted) {
        setState(() {
          if (older.isEmpty) {
            _hasMore = false;
          } else {
            _olderMessages = [...older, ..._olderMessages];
          }
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _scrollToBottom({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      if (jump) {
        _scrollCtrl.jumpTo(0);
      } else {
        _scrollCtrl.animateTo(
          0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final String text = _inputCtrl.text.trim();
    final _MediaDraft? draft = _mediaDraft;
    if (text.isEmpty && draft == null) return;
    if (text.length > 2000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message too long (max 2000 characters)')),
      );
      return;
    }

    // Rate limit: max N messages per window
    final now = DateTime.now();
    _sendTimestamps.removeWhere((t) => now.difference(t) > _rateWindow);
    if (_sendTimestamps.length >= _maxMessagesPerWindow) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Slow down! Try again in a few seconds')),
      );
      return;
    }

    // Duplicate text cooldown. Media sends are allowed to share a caption.
    if (draft == null &&
        _lastSentText == text &&
        _sendTimestamps.isNotEmpty &&
        now.difference(_sendTimestamps.last) < _duplicateCooldown) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Same message — wait before resending')),
      );
      return;
    }

    _sendTimestamps.add(now);
    if (draft == null) _lastSentText = text;
    final String key = _generateKey();
    final FirebaseMessage optimistic = FirebaseMessage(
      id: key,
      senderId: widget.myUserId,
      body: text,
      createdAt: now,
      type: draft == null ? 'text' : 'image',
    );

    setState(() {
      _optimisticMessages[key] = optimistic;
      if (draft != null) {
        _pendingImageFiles[key] = draft.file;
        _pendingImageProgress[key] = 0;
        _mediaDraft = null;
        _mediaTrayOpen = false;
      }
      _failedSends.remove(key);
    });
    _inputCtrl.clear();
    _scrollToBottom(jump: true);

    if (draft == null) {
      unawaited(_commitOptimisticText(optimistic));
    } else {
      unawaited(_commitOptimisticImage(optimistic, draft.file));
    }
  }

  Future<void> _commitOptimisticText(FirebaseMessage message) async {
    try {
      await _withFirebasePermissionRecovery(
        () => FirebaseChatService.instance.sendMessage(
          otherUserId: widget.otherUserId,
          body: message.body,
          myDisplayName: widget.myDisplayName,
          myAvatarUrl: widget.myAvatarUrl,
          idempotencyKey: message.id,
        ),
      );
    } catch (e) {
      debugPrint('Text message send failed for ${message.id}: $e');
      if (await _isOptimisticMessageCommitted(message.id)) {
        if (mounted) {
          setState(() => _failedSends.remove(message.id));
        }
        return;
      }
      if (mounted) {
        setState(() {
          if (_optimisticMessages.containsKey(message.id)) {
            _failedSends[message.id] = apiErrorMessage(e);
          }
        });
      }
    }
  }

  void _retryOptimisticText(String messageId) {
    final FirebaseMessage? message = _optimisticMessages[messageId];
    if (message == null) return;
    setState(() => _failedSends.remove(messageId));
    final File? imageFile = _pendingImageFiles[messageId];
    if (message.type == 'image' && imageFile != null) {
      unawaited(_commitOptimisticImage(message, imageFile));
    } else {
      unawaited(_commitOptimisticText(message));
    }
  }

  Future<void> _commitOptimisticImage(
    FirebaseMessage message,
    File imageFile,
  ) async {
    try {
      String? downloadUrl = _pendingImageUrls[message.id];
      if (downloadUrl == null) {
        if (mounted) {
          setState(() => _pendingImageProgress[message.id] = 0.02);
        }
        await _refreshFirebaseSessionForMediaUpload();
        final String uploadedUrl = await _withFirebasePermissionRecovery(
          () => FirebaseChatService.instance.uploadChatImage(
            otherUserId: widget.otherUserId,
            imageFile: imageFile,
            onProgress: (double progress) {
              if (!mounted) return;
              setState(() {
                _pendingImageProgress[message.id] = progress
                    .clamp(0.02, 0.95)
                    .toDouble();
              });
            },
          ),
        );
        _pendingImageUrls[message.id] = uploadedUrl;
        downloadUrl = uploadedUrl;
      }

      if (mounted) {
        setState(() => _pendingImageProgress[message.id] = 0.98);
      }

      await _withFirebasePermissionRecovery(
        () => FirebaseChatService.instance.sendMessage(
          otherUserId: widget.otherUserId,
          body: message.body,
          myDisplayName: widget.myDisplayName,
          myAvatarUrl: widget.myAvatarUrl,
          type: 'image',
          imageUrl: downloadUrl,
          idempotencyKey: message.id,
        ),
      );
    } catch (e) {
      debugPrint('Image message send failed for ${message.id}: $e');
      if (await _isOptimisticMessageCommitted(message.id)) {
        if (mounted) {
          setState(() {
            _failedSends.remove(message.id);
            _pendingImageProgress[message.id] = 1.0;
          });
        }
        return;
      }
      if (mounted) {
        setState(() {
          if (_optimisticMessages.containsKey(message.id)) {
            _failedSends[message.id] = apiErrorMessage(e);
          }
        });
      }
    }
  }

  Future<void> _refreshFirebaseSessionForMediaUpload() async {
    final api = ZephyrApiClient.instance;
    final token = ZephyrApiClient.accessToken;
    if (api == null || token == null || token.isEmpty) {
      debugPrint('Chat image upload auth refresh skipped: missing API token');
      return;
    }
    final String firebaseToken = await api.getFirebaseToken(token);
    await FirebaseChatService.instance.init(
      widget.myUserId,
      firebaseToken: firebaseToken,
    );
  }

  Future<T> _withFirebasePermissionRecovery<T>(
    Future<T> Function() action,
  ) async {
    try {
      return await action();
    } catch (error) {
      if (!isFirebasePermissionDeniedError(error)) rethrow;
      await _ensureChatDocAndListen(forceTokenRefresh: true);
      return await action();
    }
  }

  Future<bool> _isOptimisticMessageCommitted(String messageId) async {
    try {
      return await FirebaseChatService.instance.sentMessageExists(
        otherUserId: widget.otherUserId,
        messageId: messageId,
      );
    } catch (e) {
      debugPrint('Message commit lookup failed for $messageId: $e');
      return false;
    }
  }

  Future<void> _selectMedia(ImageSource source) async {
    try {
      final XFile? picked = await ImagePicker().pickImage(
        source: source,
        imageQuality: 76,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (picked == null || !mounted) return;
      setState(() {
        _mediaDraft = _MediaDraft(
          file: File(picked.path),
          source: source == ImageSource.camera
              ? _MediaSourceKind.camera
              : _MediaSourceKind.gallery,
        );
        _mediaTrayOpen = false;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(apiErrorMessage(error))));
    }
  }

  List<FirebaseMessage> get _allMessages {
    final Set<String> committedIds = {
      ..._olderMessages.map((m) => m.id),
      ..._messages.map((m) => m.id),
    };
    final List<FirebaseMessage> visible = [
      ..._olderMessages,
      ..._messages,
      ..._optimisticMessages.entries
          .where((entry) => !committedIds.contains(entry.key))
          .map((entry) => entry.value),
    ];
    visible.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return visible;
  }

  void _showMessageMenu(FirebaseMessage msg) {
    final bool isMe = msg.senderId == widget.myUserId;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete for me'),
              onTap: () {
                Navigator.pop(ctx);
                FirebaseChatService.instance.deleteMessageForMe(
                  widget.otherUserId,
                  msg.id,
                );
              },
            ),
            if (isMe)
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text(
                  'Delete for everyone',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  FirebaseChatService.instance.deleteMessageForEveryone(
                    widget.otherUserId,
                    msg.id,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  void _openProfile(String name, String? avatar) {
    final profile = FirebaseChatService.instance.profileCached(
      widget.otherUserId,
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProfilePage(
          feedCard: LiveFeedCard(
            roomId: null,
            title: '',
            audienceCount: 0,
            hostUserId: widget.otherUserId,
            hostDisplayName: name,
            hostAvatarUrl: avatar,
            hostCountryCode: profile?.countryCode ?? '',
            hostLanguage: profile?.language ?? '',
            hostStatus:
                FirebaseChatService.instance.presenceStateCached(
                  widget.otherUserId,
                ) ??
                'offline',
            startedAt: DateTime.now(),
          ),
          apiClient: ZephyrApiClient.instance,
          accessToken: ZephyrApiClient.accessToken,
          myUserId: widget.myUserId,
          myDisplayName: widget.myDisplayName,
          myAvatarUrl: widget.myAvatarUrl,
          onMessage: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  Future<int?> _fetchCallRate() async {
    final api = ZephyrApiClient.instance;
    if (api == null) return _callRateCoinsPerMinute;
    final UserProfile user = await api.getUserById(widget.otherUserId);
    return user.callRateCoinsPerMinute ?? _fallbackDirectCallRateCoinsPerMinute;
  }

  Future<void> _loadCallRate() async {
    try {
      final int? rate = await _fetchCallRate();
      if (!mounted || rate == null) return;
      setState(() => _callRateCoinsPerMinute = rate);
    } catch (_) {
      // Price preview is optional; backend still owns final call billing.
    }
  }

  Future<int?> _refreshCallRateForCall() async {
    try {
      final int? rate = await _fetchCallRate();
      if (mounted && rate != null) {
        setState(() => _callRateCoinsPerMinute = rate);
      }
      return rate;
    } catch (_) {
      return _callRateCoinsPerMinute;
    }
  }

  Future<void> _openCallOptionsSheet() async {
    final api = ZephyrApiClient.instance;
    final token = ZephyrApiClient.accessToken;
    if (api == null || token == null || _calling) return;

    final svc = FirebaseChatService.instance;
    final status = svc.presenceStateCached(widget.otherUserId) ?? 'checking';
    if (_isUnavailableForCall(status)) {
      _showSnack(_callUnavailableMessage(status));
      return;
    }

    final int? callRateCoinsPerMinute =
        _callRateCoinsPerMinute ?? await _refreshCallRateForCall();
    if (!mounted) return;

    final int? selectedRate = await showModalBottomSheet<int?>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (BuildContext sheetContext) {
        final bool sheetIsDark =
            Theme.of(sheetContext).brightness == Brightness.dark;
        final Color tileColor = sheetIsDark
            ? const Color(0xFF1F1F22)
            : const Color(0xFFF7F7F9);
        final Color borderColor = sheetIsDark
            ? const Color(0xFFFF8F00).withValues(alpha: 0.24)
            : const Color(0xFFFF8F00).withValues(alpha: 0.18);
        final bool canStartVideoCall = callRateCoinsPerMinute != null;
        final double bottomLift =
            max(MediaQuery.of(sheetContext).viewPadding.bottom, 16) + 28;

        return Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, bottomLift),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: canStartVideoCall
                      ? () {
                          Navigator.of(
                            sheetContext,
                          ).pop(callRateCoinsPerMinute);
                        }
                      : null,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: tileColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: borderColor),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFFFF8F00,
                          ).withValues(alpha: sheetIsDark ? 0.10 : 0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 7),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFFFF8F00,
                              ).withValues(alpha: 0.22),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.videocam_rounded,
                              color: Color(0xFFFF8F00),
                              size: 25,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Video Call',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Charged after answer',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: sheetIsDark
                                        ? Colors.white60
                                        : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (callRateCoinsPerMinute != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '$callRateCoinsPerMinute',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const CoinIcon(size: 15),
                                Text(
                                  '/min',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: sheetIsDark
                                        ? Colors.white60
                                        : Colors.black54,
                                  ),
                                ),
                              ],
                            )
                          else
                            Text(
                              'Price unavailable',
                              style: TextStyle(
                                fontSize: 12,
                                color: sheetIsDark
                                    ? Colors.white60
                                    : Colors.black54,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || selectedRate == null) return;
    _initiateCall(callRateCoinsPerMinute: selectedRate);
  }

  void _initiateCall({int? callRateCoinsPerMinute}) async {
    final api = ZephyrApiClient.instance;
    final token = ZephyrApiClient.accessToken;
    if (api == null || token == null || _calling) return;

    final svc = FirebaseChatService.instance;
    final status = svc.presenceStateCached(widget.otherUserId) ?? 'checking';
    if (_isUnavailableForCall(status)) {
      _showSnack(_callUnavailableMessage(status));
      return;
    }

    setState(() => _calling = true);

    CallSession? session;
    try {
      final int? currentRate =
          callRateCoinsPerMinute ?? await _refreshCallRateForCall();
      _debugDirectCall(
        'start-session receiver=${widget.otherUserId} rate=$currentRate',
      );
      final CallSession startedSession = await api.startCallSession(
        accessToken: token,
        mode: 'direct',
        receiverUserId: widget.otherUserId,
        directRateCoinsPerMinute: currentRate,
      );
      session = startedSession;
      _debugDirectCall('session-created session=${startedSession.id}');

      await svc.writeRinging(
        targetUserId: widget.otherUserId,
        callerId: widget.myUserId,
        callerName: widget.myDisplayName,
        callerAvatarUrl: widget.myAvatarUrl,
        sessionId: startedSession.id,
      );
      _debugDirectCall(
        'ringing-written receiver=${widget.otherUserId} session=${startedSession.id}',
      );

      _debugDirectCall('caller-listen receiver=${widget.otherUserId}');
      _callSub = svc.listenCallSignal(widget.otherUserId, (
        Map<String, dynamic>? data,
      ) {
        if (!mounted) return;
        if (data == null) {
          _debugDirectCall('caller-listen event=null');
          _cleanupCall();
          return;
        }
        final s = data['status'] as String?;
        _debugDirectCall(
          'caller-listen event status=$s session=${data['sessionId']}',
        );
        if (s == 'accepted') {
          _onCallAccepted(startedSession.id);
        } else if (s == 'declined') {
          _cleanupCall();
          _showSnack('Call declined');
        }
      });

      _callTimeout = Timer(const Duration(seconds: 30), () {
        if (!mounted || !_calling) return;
        _debugDirectCall('timeout-no-answer session=${startedSession.id}');
        svc.removeCallSignal(widget.otherUserId);
        _cleanupCall();
        _showSnack('No answer');
        api
            .endCallSession(
              accessToken: token,
              sessionId: startedSession.id,
              reason: 'no_answer',
            )
            .ignore();
      });
    } catch (e) {
      final CallSession? startedSession = session;
      if (startedSession != null) {
        _debugDirectCall('setup-failed rollback session=${startedSession.id}');
        svc.removeCallSignal(widget.otherUserId).ignore();
        api
            .endCallSession(
              accessToken: token,
              sessionId: startedSession.id,
              reason: 'setup_failed',
            )
            .ignore();
      }
      if (!mounted) return;
      setState(() => _calling = false);
      _debugDirectCall('error ${directCallFailureMessage(e)}');
      _showSnack(directCallFailureMessage(e));
    }
  }

  void _onCallAccepted(String sessionId) async {
    final api = ZephyrApiClient.instance;
    final token = ZephyrApiClient.accessToken;
    if (api == null || token == null || !mounted) return;

    _callSub?.cancel();
    _callTimeout?.cancel();
    FirebaseChatService.instance.cancelOnDisconnect(widget.otherUserId);

    try {
      final rtc = await api.requestCallRtcToken(
        accessToken: token,
        sessionId: sessionId,
      );
      if (!mounted) return;
      setState(() => _calling = false);
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => DirectCallScreen(
            apiClient: api,
            accessToken: token,
            sessionId: sessionId,
            appId: rtc.appId,
            channelName: rtc.channelName,
            uid: rtc.uid,
            token: rtc.token,
            partnerId: widget.otherUserId,
            partnerName:
                FirebaseChatService.instance
                    .profileCached(widget.otherUserId)
                    ?.displayName ??
                widget.otherDisplayName,
            partnerAvatarUrl:
                FirebaseChatService.instance
                    .profileCached(widget.otherUserId)
                    ?.avatarUrl ??
                widget.otherAvatarUrl,
            myUserId: widget.myUserId,
            myDisplayName: widget.myDisplayName,
            myAvatarUrl: widget.myAvatarUrl,
          ),
        ),
      );
    } catch (_) {
      _cleanupCall();
      _showSnack('Failed to connect call');
    }
  }

  void _cleanupCall() {
    _callSub?.cancel();
    _callTimeout?.cancel();
    _callSub = null;
    _callTimeout = null;
    if (mounted) setState(() => _calling = false);
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  Future<void> _handleMenuAction(String action) async {
    final api = ZephyrApiClient.instance;
    final token = ZephyrApiClient.accessToken;
    switch (action) {
      case 'block':
        if (api == null || token == null) {
          _showSnack('Account session unavailable');
          return;
        }
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Block user'),
            content: Text(
              'Block ${widget.otherDisplayName}? They won\'t be able to message you.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Block', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
        if (confirmed == true && mounted) {
          await api.blockUser(token, widget.otherUserId);
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('User blocked')));
            Navigator.pop(context);
          }
        }
        return;
      case 'report':
        if (api == null || token == null) {
          _showSnack('Account session unavailable');
          return;
        }
        final controller = TextEditingController();
        final reason = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Report user'),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Reason for reporting...',
              ),
              maxLines: 3,
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                child: const Text(
                  'Report',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        );
        if (reason != null && reason.isNotEmpty && mounted) {
          await api.reportUser(token, widget.otherUserId, reason: reason);
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Report submitted')));
          }
        }
        return;
    }
  }

  Future<void> _translateMessage(FirebaseMessage msg) async {
    if (_translations.containsKey(msg.id)) {
      // Toggle off — remove translation
      setState(() => _translations.remove(msg.id));
      return;
    }
    setState(() => _translating.add(msg.id));
    final String targetLang = Localizations.localeOf(context).languageCode;
    String? translated = await TranslationService.instance.translate(
      msg.body,
      targetLang: targetLang,
    );
    // If device language matches source, try English as fallback
    if (translated == null && targetLang != 'en') {
      translated = await TranslationService.instance.translate(
        msg.body,
        targetLang: 'en',
      );
    }
    if (mounted) {
      setState(() {
        _translating.remove(msg.id);
        if (translated != null) {
          _translations[msg.id] = translated;
        }
      });
    }
  }

  String _formatTime(DateTime dt) {
    final DateTime local = dt.toLocal();
    final String h = local.hour.toString().padLeft(2, '0');
    final String m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Widget _buildCallActionButton({
    required String status,
    required bool isDark,
  }) {
    const Color accent = Color(0xFFFF8F00);
    final bool unavailable = _isUnavailableForCall(status);
    final bool enabled = !_calling && !unavailable;
    final Color disabledForeground = isDark
        ? Colors.white.withValues(alpha: 0.34)
        : Colors.black.withValues(alpha: 0.32);
    final Color foreground = enabled ? accent : disabledForeground;
    final Color background = enabled
        ? accent.withValues(alpha: 0.16)
        : (isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.04));
    final Color border = enabled
        ? accent.withValues(alpha: 0.28)
        : foreground.withValues(alpha: 0.16);

    return Tooltip(
      message: enabled
          ? 'Video call'
          : _calling
          ? 'Starting call'
          : _callUnavailableMessage(status),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Material(
          color: background,
          shape: CircleBorder(side: BorderSide(color: border)),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _calling
                ? null
                : enabled
                ? _openCallOptionsSheet
                : () => _showSnack(_callUnavailableMessage(status)),
            child: SizedBox(
              width: 38,
              height: 38,
              child: Center(
                child: _calling
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: foreground,
                        ),
                      )
                    : Icon(Icons.videocam_rounded, color: foreground, size: 23),
              ),
            ),
          ),
        ),
      ),
    );
  }

  bool _isUnavailableForCall(String status) {
    return status == 'offline' ||
        status == 'busy' ||
        status == 'premium_live' ||
        status == 'checking';
  }

  String _callUnavailableMessage(String status) {
    final String name = widget.otherDisplayName.trim().isEmpty
        ? 'User'
        : widget.otherDisplayName.trim();
    switch (status) {
      case 'offline':
        return '$name is offline';
      case 'busy':
        return '$name is busy right now';
      case 'premium_live':
        return '$name is in premium live';
      case 'checking':
        return 'Checking $name availability';
      default:
        return '$name is not available for video call';
    }
  }

  bool _isDifferentDay(DateTime a, DateTime b) {
    final DateTime la = a.toLocal();
    final DateTime lb = b.toLocal();
    return la.year != lb.year || la.month != lb.month || la.day != lb.day;
  }

  String _formatDateHeader(DateTime dt) {
    final DateTime local = dt.toLocal();
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime msgDay = DateTime(local.year, local.month, local.day);
    final int diffDays = today.difference(msgDay).inDays;
    if (diffDays == 0) return 'Today';
    if (diffDays == 1) return 'Yesterday';
    const List<String> months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${local.day} ${months[local.month - 1]} ${local.year}';
  }

  Widget _buildDateHeader(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade500,
              ),
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }

  Widget _buildRetrySendControl({required String messageId}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _retryOptimisticText(messageId),
      child: const Padding(
        padding: EdgeInsets.only(left: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 14,
              color: Color(0xFFE53935),
            ),
            SizedBox(width: 3),
            Text(
              'Retry',
              style: TextStyle(
                color: Color(0xFFE53935),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaTray(bool isDark) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      reverseDuration: const Duration(milliseconds: 140),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        return SizeTransition(
          sizeFactor: animation,
          axisAlignment: -1,
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      child: !_mediaTrayOpen
          ? const SizedBox.shrink(key: ValueKey('media-tray-closed'))
          : Container(
              key: const ValueKey('media-tray-open'),
              height: 96,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF171717)
                    : const Color(0xFFF8F8FA),
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? Colors.white10
                        : Colors.black.withValues(alpha: 0.06),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildMediaTrayTile(
                      actionId: 'camera',
                      icon: Icons.photo_camera_rounded,
                      label: 'Camera',
                      isDark: isDark,
                      onTap: () => _selectMedia(ImageSource.camera),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMediaTrayTile(
                      actionId: 'photos',
                      icon: Icons.photo_library_rounded,
                      label: 'Photos',
                      isDark: isDark,
                      onTap: () => _selectMedia(ImageSource.gallery),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildMediaTrayTile({
    required String actionId,
    required IconData icon,
    required String label,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final bool pressed = _pressedMediaAction == actionId;
    const Color accent = Color(0xFFFF8F00);
    final Color base = isDark ? const Color(0xFF242424) : Colors.white;
    final Color textColor = isDark ? Colors.white : Colors.black87;
    final Color shadowColor = Colors.black.withValues(
      alpha: isDark ? 0.22 : 0.08,
    );

    void setPressed(bool value) {
      if (_pressedMediaAction == (value ? actionId : null)) return;
      setState(() => _pressedMediaAction = value ? actionId : null);
    }

    return AnimatedScale(
      scale: pressed ? 0.97 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          onTapDown: (_) => setPressed(true),
          onTapCancel: () => setPressed(false),
          onTapUp: (_) => setPressed(false),
          borderRadius: BorderRadius.circular(8),
          splashColor: accent.withValues(alpha: 0.16),
          highlightColor: accent.withValues(alpha: 0.08),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: pressed ? accent.withValues(alpha: 0.10) : base,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: pressed
                    ? accent.withValues(alpha: 0.82)
                    : accent.withValues(alpha: 0.28),
              ),
              boxShadow: pressed
                  ? const []
                  : [
                      BoxShadow(
                        color: shadowColor,
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOutCubic,
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: pressed ? 0.24 : 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: accent, size: 22),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAttachmentDraft(bool isDark) {
    final _MediaDraft? draft = _mediaDraft;
    if (draft == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      color: isDark ? const Color(0xFF1C1C1C) : Colors.white,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                draft.file,
                width: 78,
                height: 78,
                fit: BoxFit.cover,
              ),
            ),
            Positioned(
              top: -8,
              right: -8,
              child: GestureDetector(
                onTap: () => setState(() => _mediaDraft = null),
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white : Colors.black87,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.22),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: isDark ? Colors.black87 : Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageImageThumbnail({
    required FirebaseMessage message,
    required bool isDark,
    required bool isOptimistic,
    required String? sendError,
  }) {
    final File? localFile = _pendingImageFiles[message.id];
    final String? imageUrl = message.imageUrl?.trim();
    final bool canOpen =
        localFile != null || (imageUrl != null && imageUrl.isNotEmpty);

    final Widget thumbnail = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 210,
        height: 160,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (localFile != null)
              Image.file(localFile, fit: BoxFit.cover)
            else if (imageUrl != null && imageUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              ColoredBox(
                color: isDark ? Colors.black26 : Colors.grey.shade200,
                child: const Center(child: Icon(Icons.image_outlined)),
              ),
            if (canOpen)
              Positioned(
                right: 8,
                top: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.38),
                    shape: BoxShape.circle,
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(5),
                    child: Icon(
                      Icons.open_in_full_rounded,
                      color: Colors.white,
                      size: 13,
                    ),
                  ),
                ),
              ),
            if (isOptimistic && sendError == null)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.24),
                  ),
                  child: Center(
                    child: SizedBox(
                      width: 34,
                      height: 34,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        value: _pendingImageProgress[message.id],
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            if (sendError != null)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.46),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.error_outline_rounded,
                      color: Color(0xFFE53935),
                      size: 34,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    final Widget hero = canOpen
        ? Hero(tag: _imageHeroTag(message.id), child: thumbnail)
        : thumbnail;

    if (!canOpen) return hero;

    return Semantics(
      button: true,
      label: 'Open photo',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _openImageViewer(
          messageId: message.id,
          file: localFile,
          imageUrl: imageUrl,
        ),
        child: hero,
      ),
    );
  }

  String _imageHeroTag(String messageId) => 'chat-image-$messageId';

  void _openImageViewer({
    required String messageId,
    File? file,
    String? imageUrl,
  }) {
    if (file == null && (imageUrl == null || imageUrl.isEmpty)) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _ChatImageViewer(
          file: file,
          imageUrl: imageUrl,
          heroTag: _imageHeroTag(messageId),
        ),
      ),
    );
  }

  Widget _buildThreadError(String message, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.mark_chat_unread_outlined,
              size: 46,
              color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _ensureChatDocAndListen(forceTokenRefresh: true),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double bottomPad = MediaQuery.of(context).padding.bottom;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final List<FirebaseMessage> visibleMessages = _allMessages;

    return Scaffold(
      backgroundColor: isDark ? null : Colors.white,
      appBar: AppBar(
        leadingWidth: 40,
        title: ValueListenableBuilder<int>(
          valueListenable: FirebaseChatService.instance.profileVersion,
          builder: (context, _, __) {
            final profile = FirebaseChatService.instance.profileCached(
              widget.otherUserId,
            );
            final String name = profile?.displayName ?? widget.otherDisplayName;
            final String? avatar = profile?.avatarUrl ?? widget.otherAvatarUrl;
            return GestureDetector(
              onTap: () => _openProfile(name, avatar),
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(
                      0xFFFF8F00,
                    ).withValues(alpha: 0.15),
                    backgroundImage: avatar != null
                        ? CachedNetworkImageProvider(avatar)
                        : null,
                    child: avatar == null
                        ? Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: const TextStyle(
                              color: Color(0xFFFF8F00),
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontSize: 16)),
                        // Real-time presence from cache
                        ValueListenableBuilder<int>(
                          valueListenable:
                              FirebaseChatService.instance.presenceVersion,
                          builder: (context, _, __) {
                            final String state =
                                FirebaseChatService.instance
                                    .presenceStateCached(widget.otherUserId) ??
                                'checking';
                            final String label;
                            final Color color;
                            switch (state) {
                              case 'premium_live':
                                label = 'premium';
                                color = const Color(0xFFFF2D55);
                              case 'live':
                                label = 'live';
                                color = const Color(0xFFFF3B30);
                              case 'online':
                                label = 'online';
                                color = Colors.green;
                              case 'busy':
                                label = 'busy';
                                color = Colors.orange;
                              case 'away':
                                label = 'away';
                                color = const Color(0xFFFFCC00);
                              case 'checking':
                                label = 'checking';
                                color = Colors.grey.shade500;
                              default:
                                label = 'offline';
                                color = Colors.grey.shade500;
                            }
                            return Text(
                              label,
                              style: TextStyle(fontSize: 12, color: color),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          ValueListenableBuilder<int>(
            valueListenable: FirebaseChatService.instance.presenceVersion,
            builder: (context, _, __) {
              final status =
                  FirebaseChatService.instance.presenceStateCached(
                    widget.otherUserId,
                  ) ??
                  'checking';
              return _buildCallActionButton(status: status, isDark: isDark);
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) => _handleMenuAction(value),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'block', child: Text('Block user')),
              const PopupMenuItem(value: 'report', child: Text('Report user')),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: _threadError != null && visibleMessages.isEmpty
                    ? _buildThreadError(_threadError!, isDark)
                    : !_streamReady && visibleMessages.isEmpty
                    ? const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : visibleMessages.isEmpty
                    ? Center(
                        child: Text(
                          'Say hello!',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      )
                    : ListView.builder(
                        reverse: true,
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 16,
                        ),
                        itemCount:
                            visibleMessages.length + (_loadingMore ? 1 : 0),
                        itemBuilder: (BuildContext ctx, int i) {
                          // Loading indicator at top (end of reverse list)
                          if (_loadingMore && i == visibleMessages.length) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          }
                          final int msgIdx = visibleMessages.length - 1 - i;
                          final FirebaseMessage msg = visibleMessages[msgIdx];
                          final bool isMe = msg.senderId == widget.myUserId;
                          final bool isOptimistic = _optimisticMessages
                              .containsKey(msg.id);
                          final String? sendError = _failedSends[msg.id];
                          final bool showHeader =
                              msgIdx == 0 ||
                              _isDifferentDay(
                                visibleMessages[msgIdx - 1].createdAt,
                                msg.createdAt,
                              );
                          final bool isDeleted = msg.type == 'deleted';
                          final bool isGift = msg.type == 'gift' && !isDeleted;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (showHeader)
                                _buildDateHeader(
                                  _formatDateHeader(msg.createdAt),
                                ),
                              GestureDetector(
                                onLongPress: isDeleted || isOptimistic
                                    ? null
                                    : () => _showMessageMenu(msg),
                                child: Row(
                                  mainAxisAlignment: isMe
                                      ? MainAxisAlignment.end
                                      : MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    if (!isMe &&
                                        !isDeleted &&
                                        msg.type == 'text' &&
                                        msg.body.isNotEmpty)
                                      GestureDetector(
                                        onTap: () => _translateMessage(msg),
                                        child: Container(
                                          margin: const EdgeInsets.only(
                                            right: 4,
                                            bottom: 6,
                                          ),
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? const Color(0xFF3A3A3C)
                                                : Colors.grey.shade200,
                                            shape: BoxShape.circle,
                                          ),
                                          child: _translating.contains(msg.id)
                                              ? const SizedBox(
                                                  width: 12,
                                                  height: 12,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 1.5,
                                                      ),
                                                )
                                              : Icon(
                                                  _translations.containsKey(
                                                        msg.id,
                                                      )
                                                      ? Icons.translate
                                                      : Icons.translate,
                                                  size: 12,
                                                  color:
                                                      _translations.containsKey(
                                                        msg.id,
                                                      )
                                                      ? Colors.blue.shade300
                                                      : Colors.grey.shade500,
                                                ),
                                        ),
                                      ),
                                    Flexible(
                                      child: Container(
                                        margin: const EdgeInsets.symmetric(
                                          vertical: 3,
                                        ),
                                        padding: isGift
                                            ? EdgeInsets.zero
                                            : const EdgeInsets.symmetric(
                                                horizontal: 14,
                                                vertical: 10,
                                              ),
                                        constraints: BoxConstraints(
                                          maxWidth:
                                              MediaQuery.sizeOf(ctx).width *
                                              0.72,
                                        ),
                                        decoration: isGift
                                            ? const BoxDecoration()
                                            : BoxDecoration(
                                                color: isMe
                                                    ? const Color(0xFFFF8F00)
                                                    : (isDark
                                                          ? const Color(
                                                              0xFF2C2C2E,
                                                            )
                                                          : Colors.white),
                                                borderRadius: BorderRadius.only(
                                                  topLeft:
                                                      const Radius.circular(18),
                                                  topRight:
                                                      const Radius.circular(18),
                                                  bottomLeft: Radius.circular(
                                                    isMe ? 18 : 4,
                                                  ),
                                                  bottomRight: Radius.circular(
                                                    isMe ? 4 : 18,
                                                  ),
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withValues(
                                                          alpha: isDark
                                                              ? 0.06
                                                              : 0.10,
                                                        ),
                                                    blurRadius: isDark ? 4 : 6,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                        child: Column(
                                          crossAxisAlignment: isMe
                                              ? CrossAxisAlignment.end
                                              : CrossAxisAlignment.start,
                                          children: [
                                            if (isDeleted)
                                              Text(
                                                '🚫 This message was deleted',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontStyle: FontStyle.italic,
                                                  color: Colors.grey.shade500,
                                                ),
                                              )
                                            else if (isGift)
                                              GiftReceiptCard(
                                                visual: _giftVisualFromMessage(
                                                  msg,
                                                ),
                                                isMine: isMe,
                                              )
                                            else if (msg.type == 'image')
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  _buildMessageImageThumbnail(
                                                    message: msg,
                                                    isDark: isDark,
                                                    isOptimistic: isOptimistic,
                                                    sendError: sendError,
                                                  ),
                                                  if (msg.body.isNotEmpty) ...[
                                                    const SizedBox(height: 8),
                                                    Text(
                                                      msg.body,
                                                      style: TextStyle(
                                                        fontSize: 15,
                                                        color: isMe
                                                            ? Colors.black87
                                                            : (isDark
                                                                  ? Colors.white
                                                                  : Colors
                                                                        .black87),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              )
                                            else ...[
                                              Text(
                                                _translations.containsKey(
                                                      msg.id,
                                                    )
                                                    ? _translations[msg.id]!
                                                    : msg.body,
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  color: isMe
                                                      ? Colors.black87
                                                      : (isDark
                                                            ? Colors.white
                                                            : Colors.black87),
                                                ),
                                              ),
                                              if (_translations.containsKey(
                                                msg.id,
                                              ))
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        top: 2,
                                                      ),
                                                  child: Text(
                                                    'translated',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontStyle:
                                                          FontStyle.italic,
                                                      color:
                                                          Colors.grey.shade500,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                            const SizedBox(height: 3),
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  _formatTime(msg.createdAt),
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: isGift
                                                        ? Colors.grey.shade500
                                                        : isMe
                                                        ? Colors.black54
                                                        : (isDark
                                                              ? Colors
                                                                    .grey
                                                                    .shade500
                                                              : Colors
                                                                    .grey
                                                                    .shade400),
                                                  ),
                                                ),
                                                if (isMe) ...[
                                                  const SizedBox(width: 3),
                                                  if (sendError != null)
                                                    _buildRetrySendControl(
                                                      messageId: msg.id,
                                                    )
                                                  else
                                                    Icon(
                                                      isOptimistic
                                                          ? Icons
                                                                .schedule_rounded
                                                          : msg.readAt != null
                                                          ? Icons.done_all
                                                          : msg.deliveredAt !=
                                                                null
                                                          ? Icons.done_all
                                                          : Icons.done,
                                                      size: 13,
                                                      color: isOptimistic
                                                          ? Colors.black54
                                                          : msg.readAt != null
                                                          ? Colors.blue.shade300
                                                          : isGift
                                                          ? Colors.white54
                                                          : msg.deliveredAt !=
                                                                null
                                                          ? Colors.white70
                                                          : Colors.white54,
                                                    ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
              ),
              _buildMediaTray(isDark),
              _buildAttachmentDraft(isDark),
              // Input bar
              Container(
                color: isDark ? const Color(0xFF1C1C1C) : Colors.white,
                padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + bottomPad),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        FocusScope.of(context).unfocus();
                        setState(() => _mediaTrayOpen = !_mediaTrayOpen);
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Icon(
                          _mediaTrayOpen
                              ? Icons.close_rounded
                              : Icons.add_circle_outline_rounded,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                          size: 28,
                        ),
                      ),
                    ),
                    Tooltip(
                      message: 'Send gift',
                      child: GestureDetector(
                        onTap: _openGiftPicker,
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Icon(
                            Icons.card_giftcard_rounded,
                            color: const Color(
                              0xFFFF8F00,
                            ).withValues(alpha: 0.92),
                            size: 27,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF2A2A2A)
                              : const Color(0xFFF2F2F7),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: TextField(
                          controller: _inputCtrl,
                          minLines: 1,
                          maxLines: 4,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: _mediaDraft == null
                                ? 'Message…'
                                : 'Add a message…',
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 10,
                            ),
                          ),
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _send,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFFF8F00),
                        ),
                        child: const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // ── Live preview overlay ───────────────────────────────────────────
          ValueListenableBuilder<int>(
            valueListenable: FirebaseChatService.instance.presenceVersion,
            builder: (context, _, __) {
              final String state =
                  FirebaseChatService.instance.presenceStateCached(
                    widget.otherUserId,
                  ) ??
                  'offline';
              final String? roomId =
                  FirebaseChatService.instance.presenceRoomIdCached(
                    widget.otherUserId,
                  ) ??
                  _liveRoomId;
              if (state != 'live' || roomId == null) {
                return const SizedBox.shrink();
              }
              return Positioned(
                top: 8,
                right: 12,
                child: LivePreviewWidget(
                  key: ValueKey('$roomId-$_previewGen'),
                  roomId: roomId,
                  onTap: (engine, hostUid, channelName) =>
                      _openLiveStream(roomId, engine, hostUid, channelName),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openLiveStream(
    String roomId,
    RtcEngine engine,
    int hostUid,
    String channelName,
  ) async {
    final api = ZephyrApiClient.instance;
    final token = ZephyrApiClient.accessToken;
    if (api == null || token == null) return;

    final p = FirebaseChatService.instance.profileCached(widget.otherUserId);
    final name = p?.displayName ?? widget.otherDisplayName;
    final avatar = p?.avatarUrl ?? widget.otherAvatarUrl;

    final feedCard = LiveFeedCard(
      roomId: roomId,
      title: '$name\'s live',
      audienceCount: 0,
      hostUserId: widget.otherUserId,
      hostDisplayName: name,
      hostAvatarUrl: avatar,
      hostCountryCode: p?.countryCode ?? '',
      hostLanguage: '',
      hostStatus: 'live',
      startedAt: DateTime.now(),
    );

    // Join room before navigating
    int viewerCount = 0;
    bool didJoin = false;
    try {
      final room = await api.joinRoom(token, roomId);
      viewerCount = room.audienceCount;
      didJoin = true;
    } catch (_) {}
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => ViewerLiveScreen(
          feedCard: feedCard,
          apiClient: api,
          accessToken: token,
          myUserId: widget.myUserId,
          myDisplayName: widget.myDisplayName,
          onLeave: () {},
          initialViewerCount: viewerCount,
          didJoin: didJoin,
          existingEngine: engine,
          existingHostUid: hostUid,
          existingChannelName: channelName,
        ),
      ),
    );
    // Bump generation so preview rebuilds fresh with a new engine
    if (mounted) setState(() => _previewGen++);
  }
}

class _ChatImageViewer extends StatelessWidget {
  const _ChatImageViewer({this.file, this.imageUrl, required this.heroTag});

  final File? file;
  final String? imageUrl;
  final String heroTag;

  @override
  Widget build(BuildContext context) {
    final Widget image = file != null
        ? Image.file(file!, fit: BoxFit.contain)
        : CachedNetworkImage(
            imageUrl: imageUrl!,
            fit: BoxFit.contain,
            placeholder: (_, __) =>
                const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            errorWidget: (_, __, ___) => const Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: Colors.white70,
                size: 44,
              ),
            ),
          );

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Center(
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  clipBehavior: Clip.none,
                  child: Hero(tag: heroTag, child: image),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.14),
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
