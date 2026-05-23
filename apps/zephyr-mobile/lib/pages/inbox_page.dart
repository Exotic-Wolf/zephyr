import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/api_client.dart';
import '../services/local_db.dart';
import '../widgets/status_dot.dart';
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
  /// Called with the other user's ID and unread count when a thread opens,
  /// or (null, 0) when it closes.
  final void Function(String? userId, int unreadCount)? onThreadChanged;

  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage> with WidgetsBindingObserver {
  List<ZephyrConversation> _conversations = <ZephyrConversation>[];
  bool _loading = true;
  String? _error;
  StreamSubscription<ZephyrMessage>? _busSub;
  StreamSubscription<void>? _reconnectSub;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadLocal();
    _busSub = MessageBus.instance.stream.listen((_) => _debouncedRefresh());
    _reconnectSub = ChatReconnectBus.instance.stream.listen((_) => _refresh());
  }

  /// Load from local SQLite instantly (no network).
  Future<void> _loadLocal() async {
    final List<ZephyrConversation> local = await LocalDb.instance.getConversations();
    if (local.isNotEmpty && mounted) {
      setState(() { _conversations = local; _loading = false; });
    }
    // Then sync from server in background
    _refresh();
  }

  void _debouncedRefresh() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) _refresh();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _busSub?.cancel();
    _reconnectSub?.cancel();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final List<ZephyrConversation> convos =
          await widget.apiClient.getConversations(widget.accessToken);
      // Persist to local SQLite for next instant load
      await LocalDb.instance.replaceConversations(convos);
      if (mounted) setState(() { _conversations = convos; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = _conversations.isEmpty ? e.toString() : null; _loading = false; });
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
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
              : _conversations.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(Icons.chat_bubble_outline_rounded,
                              size: 56, color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text(AppLocalizations.of(context)!.noMessagesYet,
                              style: TextStyle(
                                  fontSize: 16, color: isDark ? Colors.grey.shade500 : Colors.grey.shade500)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: _conversations.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1, indent: 72),
                      itemBuilder: (BuildContext ctx, int i) {
                        final ZephyrConversation c = _conversations[i];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          leading: SizedBox(
                            width: 52,
                            height: 52,
                            child: Stack(
                              children: <Widget>[
                                CircleAvatar(
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
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: StatusDot(userId: c.userId),
                                ),
                              ],
                            ),
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
                                      color: isDark ? Colors.grey.shade500 : Colors.grey.shade400)),
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
                            widget.onThreadChanged?.call(c.userId, c.unreadCount);
                            await Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => ThreadPage(
                                  apiClient: widget.apiClient,
                                  accessToken: widget.accessToken,
                                  myUserId: widget.myUserId,
                                  otherUserId: c.userId,
                                  otherDisplayName: c.displayName,
                                  otherAvatarUrl: c.avatarUrl,
                                ),
                              ),
                            );
                            widget.onThreadChanged?.call(null, 0);
                            _refresh(); // refresh unread counts on return
                          },
                        );
                      },
                    ),
    );
  }
}

// ── ThreadPage ────────────────────────────────────────────────────────────────

