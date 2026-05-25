import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/firebase_chat_service.dart';
import 'thread_firebase_page.dart';

/// Firebase-backed inbox page — completely isolated from the custom inbox.
/// Uses Firestore real-time listeners for conversations.
class InboxFirebasePage extends StatefulWidget {
  const InboxFirebasePage({
    super.key,
    required this.myUserId,
    required this.myDisplayName,
    this.myAvatarUrl,
  });

  final String myUserId;
  final String myDisplayName;
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
    _init();
  }

  Future<void> _init() async {
    try {
      await FirebaseChatService.instance.init(widget.myUserId);
      _sub = FirebaseChatService.instance.watchConversations().listen(
        (List<FirebaseConversation> convos) {
          if (mounted) setState(() { _conversations = convos; _initialized = true; });
          // Pre-warm presence cache for all conversation partners
          FirebaseChatService.instance.warmPresence(
            convos.map((c) => c.otherUserId).toList(),
          );
          // Mark messages as delivered for all conversations with unread
          for (final c in convos) {
            if (c.unreadCount > 0) {
              FirebaseChatService.instance.markDelivered(c.otherUserId);
            }
          }
        },
        onError: (e) {
          if (mounted) setState(() { _error = e.toString(); _initialized = true; });
        },
      );
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _initialized = true; });
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
        final controller = TextEditingController();
        final userId = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('New Firebase Chat'),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Paste the other user ID',
              ),
              autofocus: true,
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              TextButton(
                onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                child: const Text('Start'),
              ),
            ],
          ),
        );
        if (userId == null || userId.isEmpty) return;
        if (!context.mounted) return;
        Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ThreadFirebasePage(
                myUserId: widget.myUserId,
                myDisplayName: widget.myDisplayName,
                myAvatarUrl: widget.myAvatarUrl,
                otherUserId: userId,
                otherDisplayName: 'User',
                otherAvatarUrl: null,
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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Firebase error:\n$_error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red)),
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
              Icon(Icons.chat_bubble_outline_rounded,
                  size: 56,
                  color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
              const SizedBox(height: 12),
              Text('No Firebase messages yet',
                  style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade500)),
              const SizedBox(height: 8),
              Text('Tap + to start a Firebase chat',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: widget.myUserId));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('ID copied!'), duration: Duration(seconds: 1)),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade800,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.copy, size: 14, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(widget.myUserId,
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade400, fontFamily: 'monospace')),
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
      body: ListView.separated(
        itemCount: _conversations.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
        itemBuilder: (BuildContext ctx, int i) {
          final FirebaseConversation c = _conversations[i];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: SizedBox(
              width: 52,
              height: 52,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: const Color(0xFFFF8F00).withValues(alpha: 0.15),
                    backgroundImage: c.otherAvatarUrl != null
                        ? CachedNetworkImageProvider(c.otherAvatarUrl!)
                        : null,
                    child: c.otherAvatarUrl == null
                        ? Text(
                            c.otherDisplayName.isNotEmpty
                                ? c.otherDisplayName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                                color: Color(0xFFFF8F00),
                                fontWeight: FontWeight.w700),
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
                  child: Text(c.otherDisplayName,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                Text(_timeAgo(c.lastMessageAt),
                    style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey.shade500 : Colors.grey.shade400)),
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
                            : FontWeight.normal),
                  ),
                ),
                if (c.unreadCount > 0)
                  Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF8F00),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${c.unreadCount}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700),
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
                    otherDisplayName: c.otherDisplayName,
                    otherAvatarUrl: c.otherAvatarUrl,

                  ),
                ),
              );
            },
          );
        },
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
            FirebaseChatService.instance.presenceStateCached(userId) ?? 'offline';
        final Color color;
        final double opacity;
        switch (state) {
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
