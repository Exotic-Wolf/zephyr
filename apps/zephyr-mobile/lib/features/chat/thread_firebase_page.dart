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
import '../call/direct_call_screen.dart';
import '../live/viewer_live_screen.dart';
import '../profile/profile_page.dart';
import 'live_preview_widget.dart';

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
  bool _sending = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _streamReady = false;
  final Map<String, String> _translations = {}; // messageId -> translated text
  final Set<String> _translating = {}; // messageIds currently being translated

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
  StreamSubscription<DatabaseEvent>? _callSub;
  Timer? _callTimeout;

  String _generateKey() =>
      '${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(999999)}';

  @override
  void initState() {
    super.initState();
    // Ensure presence and profile are warmed for this user
    FirebaseChatService.instance.warmPresence([widget.otherUserId]);
    FirebaseChatService.instance.warmProfiles([widget.otherUserId]);
    _ensureChatDocAndListen();
    _scrollCtrl.addListener(_onScroll);
    _lookupLiveRoom();
  }

  /// Ensure the chat doc exists (with participants) before listening.
  /// Security rules on /messages require the parent doc's participants array.
  Future<void> _ensureChatDocAndListen() async {
    await FirebaseChatService.instance.ensureChatDoc(
      widget.otherUserId,
      myDisplayName: widget.myDisplayName,
      myAvatarUrl: widget.myAvatarUrl,
      otherDisplayName: widget.otherDisplayName,
      otherAvatarUrl: widget.otherAvatarUrl,
    );
    if (!mounted) return;
    _sub = FirebaseChatService.instance
        .watchMessages(widget.otherUserId)
        .listen((List<FirebaseMessage> msgs) {
          if (mounted) {
            setState(() {
              _messages = msgs;
              _streamReady = true;
            });
            _scrollToBottom();
            // Mark incoming messages as read continuously while chat is open
            _markIncomingRead(msgs);
          }
        });
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

  @override
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
    if (text.isEmpty || _sending) return;
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

    // Duplicate message cooldown
    if (_lastSentText == text &&
        _sendTimestamps.isNotEmpty &&
        now.difference(_sendTimestamps.last) < _duplicateCooldown) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Same message — wait before resending')),
      );
      return;
    }

    _sendTimestamps.add(now);
    _lastSentText = text;
    setState(() => _sending = true);
    _inputCtrl.clear();
    final String key = _generateKey();

    try {
      await FirebaseChatService.instance.sendMessage(
        otherUserId: widget.otherUserId,
        body: text,
        myDisplayName: widget.myDisplayName,
        myAvatarUrl: widget.myAvatarUrl,
        idempotencyKey: key,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Send failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickAndSendImage() async {
    final XFile? picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (picked == null) return;
    setState(() => _sending = true);
    try {
      await FirebaseChatService.instance.sendImage(
        otherUserId: widget.otherUserId,
        imageFile: File(picked.path),
        myDisplayName: widget.myDisplayName,
        myAvatarUrl: widget.myAvatarUrl,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Image send failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  List<FirebaseMessage> get _allMessages => [..._olderMessages, ..._messages];

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

  void _initiateCall() async {
    final api = ZephyrApiClient.instance;
    final token = ZephyrApiClient.accessToken;
    if (api == null || token == null || _calling) return;

    final svc = FirebaseChatService.instance;
    final status = svc.presenceStateCached(widget.otherUserId) ?? 'offline';
    if (status == 'offline' || status == 'busy' || status == 'premium_live') {
      _showSnack('User is not available');
      return;
    }

    setState(() => _calling = true);

    try {
      final session = await api.startCallSession(
        accessToken: token,
        mode: 'direct',
        receiverUserId: widget.otherUserId,
      );

      await svc.writeRinging(
        targetUserId: widget.otherUserId,
        callerId: widget.myUserId,
        callerName: widget.myDisplayName,
        callerAvatarUrl: widget.myAvatarUrl,
        sessionId: session.id,
      );

      _callSub = svc.listenCallSignal(widget.otherUserId, (
        Map<String, dynamic>? data,
      ) {
        if (!mounted) return;
        if (data == null) {
          _cleanupCall();
          return;
        }
        final s = data['status'] as String?;
        if (s == 'accepted') {
          _onCallAccepted(session.id);
        } else if (s == 'declined') {
          _cleanupCall();
          _showSnack('Call declined');
        }
      });

      _callTimeout = Timer(const Duration(seconds: 30), () {
        if (!mounted || !_calling) return;
        svc.removeCallSignal(widget.otherUserId);
        _cleanupCall();
        _showSnack('No answer');
        api
            .endCallSession(
              accessToken: token,
              sessionId: session.id,
              reason: 'no_answer',
            )
            .ignore();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _calling = false);
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

  @override
  Widget build(BuildContext context) {
    final double bottomPad = MediaQuery.of(context).padding.bottom;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

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
                                'offline';
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
                  'offline';
              final unavailable =
                  status == 'offline' ||
                  status == 'busy' ||
                  status == 'premium_live';
              return IconButton(
                icon: _calling
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.videocam_outlined),
                onPressed: _calling || unavailable ? null : _initiateCall,
              );
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
                child: !_streamReady
                    ? const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : _messages.isEmpty && _olderMessages.isEmpty
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
                        itemCount: _allMessages.length + (_loadingMore ? 1 : 0),
                        itemBuilder: (BuildContext ctx, int i) {
                          // Loading indicator at top (end of reverse list)
                          if (_loadingMore && i == _allMessages.length) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          }
                          final int msgIdx = _allMessages.length - 1 - i;
                          final FirebaseMessage msg = _allMessages[msgIdx];
                          final bool isMe = msg.senderId == widget.myUserId;
                          final bool showHeader =
                              msgIdx == 0 ||
                              _isDifferentDay(
                                _allMessages[msgIdx - 1].createdAt,
                                msg.createdAt,
                              );
                          final bool isDeleted = msg.type == 'deleted';

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (showHeader)
                                _buildDateHeader(
                                  _formatDateHeader(msg.createdAt),
                                ),
                              GestureDetector(
                                onLongPress: isDeleted
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
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 10,
                                        ),
                                        constraints: BoxConstraints(
                                          maxWidth:
                                              MediaQuery.sizeOf(ctx).width *
                                              0.72,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isMe
                                              ? const Color(0xFFFF8F00)
                                              : (isDark
                                                    ? const Color(0xFF2C2C2E)
                                                    : Colors.white),
                                          borderRadius: BorderRadius.only(
                                            topLeft: const Radius.circular(18),
                                            topRight: const Radius.circular(18),
                                            bottomLeft: Radius.circular(
                                              isMe ? 18 : 4,
                                            ),
                                            bottomRight: Radius.circular(
                                              isMe ? 4 : 18,
                                            ),
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                alpha: isDark ? 0.06 : 0.10,
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
                                            else if (msg.type == 'image' &&
                                                msg.imageUrl != null)
                                              ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                child: CachedNetworkImage(
                                                  imageUrl: msg.imageUrl!,
                                                  width: 200,
                                                  fit: BoxFit.cover,
                                                  placeholder: (_, __) =>
                                                      const SizedBox(
                                                        width: 200,
                                                        height: 150,
                                                        child: Center(
                                                          child:
                                                              CircularProgressIndicator(
                                                                strokeWidth: 2,
                                                              ),
                                                        ),
                                                      ),
                                                ),
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
                                                    color: isMe
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
                                                  Icon(
                                                    msg.readAt != null
                                                        ? Icons.done_all
                                                        : msg.deliveredAt !=
                                                              null
                                                        ? Icons.done_all
                                                        : Icons.done,
                                                    size: 13,
                                                    color: msg.readAt != null
                                                        ? Colors.blue.shade300
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
              // Input bar
              Container(
                color: isDark ? const Color(0xFF1C1C1C) : Colors.white,
                padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + bottomPad),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _sending ? null : _pickAndSendImage,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Icon(
                          Icons.image_outlined,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                          size: 26,
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
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Message…',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 10),
                          ),
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _sending
                        ? const SizedBox(
                            width: 40,
                            height: 40,
                            child: Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          )
                        : GestureDetector(
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
