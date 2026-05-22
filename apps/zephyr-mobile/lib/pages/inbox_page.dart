import 'dart:async';

import 'package:agora_chat_sdk/agora_chat_sdk.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/api_client.dart';
import '../services/chat_service.dart';
import 'thread_page.dart';
import '../l10n/app_localizations.dart';

class InboxPage extends StatefulWidget {
  const InboxPage({
    super.key,
    required this.apiClient,
    required this.accessToken,
    required this.myUserId,
    this.onThreadChanged,
  });

  final ZephyrApiClient apiClient;
  final String accessToken;
  final String myUserId;
  final void Function(String? userId)? onThreadChanged;

  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage> with WidgetsBindingObserver {
  List<_InboxItem> _items = <_InboxItem>[];
  bool _loading = true;
  StreamSubscription<void>? _chatSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _chatSub = ChatService.instance.onConversationsChanged.listen((_) {
      if (mounted) _load();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _chatSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final List<ChatConversation> convos =
          await ChatService.instance.getConversations();
      if (!mounted) return;

      // Resolve profiles for all peer user IDs
      final List<String> zephyrIds = convos
          .map((c) => ChatService.toZephyrUserId(c.id))
          .toList();
      final List<UserProfile> profiles =
          await widget.apiClient.getUsersByIds(zephyrIds);
      final Map<String, UserProfile> profileMap = {
        for (final p in profiles) p.id: p,
      };

      // Build inbox items
      final List<_InboxItem> items = <_InboxItem>[];
      for (final conv in convos) {
        final String zephyrId = ChatService.toZephyrUserId(conv.id);
        final UserProfile? profile = profileMap[zephyrId];
        final int unread = await conv.unreadCount();
        final ChatMessage? last = await conv.latestMessage();
        if (last == null) continue;

        String lastText = '';
        if (last.body is ChatTextMessageBody) {
          lastText = (last.body as ChatTextMessageBody).content;
        }

        items.add(_InboxItem(
          zephyrUserId: zephyrId,
          chatUserId: conv.id,
          displayName: profile?.displayName ?? zephyrId.substring(0, 8),
          avatarUrl: profile?.avatarUrl,
          lastMessage: lastText,
          lastMessageAt: DateTime.fromMillisecondsSinceEpoch(last.serverTime),
          unreadCount: unread,
        ));
      }

      // Sort by most recent first
      items.sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));

      if (mounted) setState(() { _items = items; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _timeAgo(DateTime dt) {
    final Duration diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(Icons.chat_bubble_outline_rounded,
                          size: 56,
                          color: isDark
                              ? Colors.grey.shade700
                              : Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text(AppLocalizations.of(context)!.noMessagesYet,
                          style: TextStyle(
                              fontSize: 16, color: Colors.grey.shade500)),
                    ],
                  ),
                )
              : ListView.separated(
                  itemCount: _items.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 72),
                  itemBuilder: (BuildContext ctx, int i) {
                    final _InboxItem c = _items[i];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        radius: 26,
                        backgroundColor:
                            const Color(0xFFFF8F00).withValues(alpha: 0.15),
                        backgroundImage: c.avatarUrl != null
                            ? CachedNetworkImageProvider(c.avatarUrl!)
                            : null,
                        child: c.avatarUrl == null
                            ? Text(
                                c.displayName.isNotEmpty
                                    ? c.displayName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                    color: Color(0xFFFF8F00),
                                    fontWeight: FontWeight.w700),
                              )
                            : null,
                      ),
                      title: Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(c.displayName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                          ),
                          Text(_timeAgo(c.lastMessageAt),
                              style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.grey.shade500
                                      : Colors.grey.shade400)),
                        ],
                      ),
                      subtitle: Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              c.lastMessage,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: c.unreadCount > 0
                                      ? (isDark
                                          ? Colors.white
                                          : Colors.black87)
                                      : Colors.grey.shade500,
                                  fontWeight: c.unreadCount > 0
                                      ? FontWeight.w500
                                      : FontWeight.normal),
                            ),
                          ),
                          if (c.unreadCount > 0)
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
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
                      onTap: () async {
                        widget.onThreadChanged?.call(c.zephyrUserId);
                        await Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ThreadPage(
                              apiClient: widget.apiClient,
                              accessToken: widget.accessToken,
                              myUserId: widget.myUserId,
                              otherUserId: c.zephyrUserId,
                              otherDisplayName: c.displayName,
                              otherAvatarUrl: c.avatarUrl,
                            ),
                          ),
                        );
                        widget.onThreadChanged?.call(null);
                        _load();
                      },
                    );
                  },
                ),
    );
  }
}

class _InboxItem {
  _InboxItem({
    required this.zephyrUserId,
    required this.chatUserId,
    required this.displayName,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.unreadCount,
    this.avatarUrl,
  });

  final String zephyrUserId;
  final String chatUserId;
  final String displayName;
  final String? avatarUrl;
  final String lastMessage;
  final DateTime lastMessageAt;
  final int unreadCount;
}
