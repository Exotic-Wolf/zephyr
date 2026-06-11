import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/models.dart';
import '../../services/api_error_messages.dart';
import '../../services/api_client.dart';
import '../../services/firebase_chat_service.dart';
import 'thread_firebase_page.dart';

/// Firebase-backed inbox page — completely isolated from the custom inbox.
/// Uses Firestore real-time listeners for conversations.
class InboxFirebasePage extends StatefulWidget {
  const InboxFirebasePage({
    super.key,
    required this.apiClient,
    required this.accessToken,
    required this.myUserId,
    required this.myDisplayName,
    required this.onSessionExpired,
    this.myAvatarUrl,
  });

  final ZephyrApiClient apiClient;
  final String accessToken;
  final String myUserId;
  final String myDisplayName;
  final Future<void> Function() onSessionExpired;
  final String? myAvatarUrl;

  @override
  State<InboxFirebasePage> createState() => _InboxFirebasePageState();
}

class _InboxFirebasePageState extends State<InboxFirebasePage> {
  List<FirebaseConversation> _conversations = [];
  StreamSubscription<List<FirebaseConversation>>? _sub;
  bool _initialized = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _seedCachedConversations();
    _init();
  }

  void _seedCachedConversations() {
    final service = FirebaseChatService.instance;
    if (!service.isInitializedFor(widget.myUserId)) return;
    final cached = service.cachedConversations();
    if (cached.isEmpty) return;
    _conversations = cached;
    _initialized = true;
    _primeConversationCaches(cached, markDelivered: false);
  }

  Future<void> _init({bool forceTokenRefresh = false}) async {
    await _sub?.cancel();
    if (!mounted) return;
    if (mounted) {
      setState(() {
        _initialized = _conversations.isNotEmpty;
        _error = null;
      });
    }

    try {
      if (widget.myUserId.isEmpty) {
        throw StateError('Inbox needs the current user before connecting.');
      }
      final service = FirebaseChatService.instance;
      if (forceTokenRefresh || !service.isInitializedFor(widget.myUserId)) {
        final String token = await widget.apiClient.getFirebaseToken(
          widget.accessToken,
        );
        if (!mounted) return;
        await service.init(widget.myUserId, firebaseToken: token);
      }
      if (!mounted) return;
      final cached = await service.loadCachedConversations();
      if (mounted && cached.isNotEmpty) {
        setState(() {
          _conversations = cached;
          _error = null;
          _initialized = true;
        });
        _primeConversationCaches(cached, markDelivered: false);
      }
      if (!mounted) return;
      _sub = service.watchConversations().listen((
        List<FirebaseConversation> convos,
      ) {
        if (mounted) {
          setState(() {
            _conversations = convos;
            _error = null;
            _initialized = true;
          });
        }
        _primeConversationCaches(convos, markDelivered: true);
      }, onError: _handleInboxError);
    } catch (e) {
      _handleInboxError(e);
    }
  }

  void _primeConversationCaches(
    List<FirebaseConversation> convos, {
    required bool markDelivered,
  }) {
    final userIds = convos.map((c) => c.otherUserId).toList();
    FirebaseChatService.instance.warmPresence(userIds);
    FirebaseChatService.instance.warmProfiles(userIds);
    if (!markDelivered) return;
    for (final c in convos) {
      if (c.unreadCount > 0) {
        FirebaseChatService.instance.markDelivered(c.otherUserId);
      }
    }
  }

  void _handleInboxError(Object error) {
    if (isAuthSessionInvalidError(error)) {
      widget.onSessionExpired().ignore();
      return;
    }
    if (isFirebasePermissionDeniedError(error)) {
      _validateBackendSessionAfterPermissionDenied(error).ignore();
      return;
    }
    _showInboxUnavailable(error);
  }

  Future<void> _validateBackendSessionAfterPermissionDenied(
    Object error,
  ) async {
    try {
      await widget.apiClient.getMe(widget.accessToken);
    } catch (apiError) {
      if (isAuthSessionInvalidError(apiError)) {
        widget.onSessionExpired().ignore();
        return;
      }
    }
    _showInboxUnavailable(error);
  }

  void _showInboxUnavailable(Object error) {
    debugPrint('Firebase inbox unavailable: $error');
    if (mounted) {
      setState(() {
        _error = 'Inbox is reconnecting. Please try again.';
        _initialized = true;
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  String _timeAgo(DateTime dt) {
    final Duration diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Widget _buildNewChatFab(BuildContext context) {
    return FloatingActionButton(
      backgroundColor: const Color(0xFFFF8F00),
      child: const Icon(Icons.add, color: Colors.white),
      onPressed: () async {
        final result = await showDialog<UserProfile>(
          context: context,
          builder: (ctx) => _UserSearchDialog(myUserId: widget.myUserId),
        );
        if (result == null) return;
        if (!context.mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ThreadFirebasePage(
              myUserId: widget.myUserId,
              myDisplayName: widget.myDisplayName,
              myAvatarUrl: widget.myAvatarUrl,
              otherUserId: result.id,
              otherDisplayName: result.displayName,
              otherAvatarUrl: result.avatarUrl,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    if (!_initialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.mark_chat_unread_outlined,
                  size: 54,
                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                ),
                const SizedBox(height: 14),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: () => _init(forceTokenRefresh: true),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_conversations.isEmpty) {
      return Scaffold(
        floatingActionButton: _buildNewChatFab(context),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.chat_bubble_outline_rounded,
                size: 56,
                color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
              ),
              const SizedBox(height: 12),
              Text(
                'No Firebase messages yet',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap + to start a Firebase chat',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: widget.myUserId));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('ID copied!'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade800,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.copy, size: 14, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(
                        widget.myUserId,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade400,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      floatingActionButton: _buildNewChatFab(context),
      body: ValueListenableBuilder<int>(
        valueListenable: FirebaseChatService.instance.profileVersion,
        builder: (context, _, __) => ListView.separated(
          itemCount: _conversations.length,
          separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
          itemBuilder: (BuildContext ctx, int i) {
            final FirebaseConversation c = _conversations[i];
            final profile = FirebaseChatService.instance.profileCached(
              c.otherUserId,
            );
            final String displayName =
                profile?.displayName ?? c.otherDisplayName;
            final String? avatarUrl = profile?.avatarUrl ?? c.otherAvatarUrl;
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: SizedBox(
                width: 52,
                height: 52,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: const Color(
                        0xFFFF8F00,
                      ).withValues(alpha: 0.15),
                      backgroundImage: avatarUrl != null
                          ? CachedNetworkImageProvider(avatarUrl)
                          : null,
                      child: avatarUrl == null
                          ? Text(
                              displayName.isNotEmpty
                                  ? displayName[0].toUpperCase()
                                  : '?',
                              style: const TextStyle(
                                color: Color(0xFFFF8F00),
                                fontWeight: FontWeight.w700,
                              ),
                            )
                          : null,
                    ),
                    // Firebase presence dot
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: _PresenceDot(userId: c.otherUserId),
                    ),
                  ],
                ),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      displayName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    _timeAgo(c.lastMessageAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? Colors.grey.shade500
                          : Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
              subtitle: Row(
                children: [
                  Expanded(
                    child: Text(
                      c.lastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c.unreadCount > 0
                            ? (isDark ? Colors.white : Colors.black87)
                            : Colors.grey.shade500,
                        fontWeight: c.unreadCount > 0
                            ? FontWeight.w500
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                  if (c.unreadCount > 0)
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF8F00),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${c.unreadCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ThreadFirebasePage(
                      myUserId: widget.myUserId,
                      myDisplayName: widget.myDisplayName,
                      myAvatarUrl: widget.myAvatarUrl,
                      otherUserId: c.otherUserId,
                      otherDisplayName: displayName,
                      otherAvatarUrl: avatarUrl,
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// ── Firebase Presence Dot (reads from cache via ValueNotifier) ────────────────

class _PresenceDot extends StatelessWidget {
  const _PresenceDot({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: FirebaseChatService.instance.presenceVersion,
      builder: (context, _, __) {
        final String state =
            FirebaseChatService.instance.presenceStateCached(userId) ??
            'offline';
        if (state == 'away') {
          return Icon(
            Icons.nightlight_round,
            size: 12,
            color: const Color(0xFFFFCC00),
          );
        }
        final Color color;
        final double opacity;
        switch (state) {
          case 'premium_live':
            color = const Color(0xFFFF2D55);
            opacity = 1.0;
          case 'live':
            color = const Color(0xFFFF3B30);
            opacity = 1.0;
          case 'busy':
            color = const Color(0xFFFF9500);
            opacity = 1.0;
          case 'online':
            color = const Color(0xFF34C759);
            opacity = 1.0;
          default:
            color = const Color(0xFF8E8E93);
            opacity = 0.0;
        }
        return AnimatedOpacity(
          opacity: opacity,
          duration: const Duration(milliseconds: 300),
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              border: Border.all(
                color: Theme.of(context).scaffoldBackgroundColor,
                width: 2,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── User Search Dialog ───────────────────────────────────────────────────────

class _UserSearchDialog extends StatefulWidget {
  const _UserSearchDialog({required this.myUserId});
  final String myUserId;

  @override
  State<_UserSearchDialog> createState() => _UserSearchDialogState();
}

class _UserSearchDialogState extends State<_UserSearchDialog> {
  final TextEditingController _ctrl = TextEditingController();
  Timer? _debounce;
  List<UserProfile> _results = [];
  bool _loading = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onQueryChanged(String q) {
    _debounce?.cancel();
    if (q.trim().length < 2) {
      setState(() => _results = []);
      return;
    }
    _debounce = Timer(
      const Duration(milliseconds: 400),
      () => _search(q.trim()),
    );
  }

  Future<void> _search(String q) async {
    final api = ZephyrApiClient.instance;
    if (api == null) return;
    setState(() => _loading = true);
    try {
      final users = await api.searchUsers(q);
      if (mounted) {
        setState(() {
          _results = users.where((u) => u.id != widget.myUserId).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Chat'),
      content: SizedBox(
        width: double.maxFinite,
        height: 350,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _ctrl,
              decoration: const InputDecoration(
                hintText: 'Search by name...',
                prefixIcon: Icon(Icons.search),
              ),
              autofocus: true,
              onChanged: _onQueryChanged,
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              )
            else
              Expanded(
                child: _results.isEmpty
                    ? Center(
                        child: Text(
                          _ctrl.text.length < 2
                              ? 'Type to search'
                              : 'No results',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _results.length,
                        itemBuilder: (ctx, i) {
                          final user = _results[i];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: user.avatarUrl != null
                                  ? CachedNetworkImageProvider(user.avatarUrl!)
                                  : null,
                              child: user.avatarUrl == null
                                  ? Text(
                                      user.displayName.isNotEmpty
                                          ? user.displayName[0].toUpperCase()
                                          : '?',
                                    )
                                  : null,
                            ),
                            title: Text(user.displayName),
                            subtitle: Text(
                              '#${user.publicId}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            onTap: () => Navigator.pop(ctx, user),
                          );
                        },
                      ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
