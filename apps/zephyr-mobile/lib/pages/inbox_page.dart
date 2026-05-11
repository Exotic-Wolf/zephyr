import 'dart:async';
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/api_client.dart';
import 'thread_page.dart';
import '../app_constants.dart';

class InboxPage extends StatefulWidget {
  const InboxPage({
    super.key,
    required this.apiClient,
    required this.accessToken,
    required this.myUserId,
  });

  final ZephyrApiClient apiClient;
  final String accessToken;
  final String myUserId;

  @override
  State<InboxPage> createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage> {
  List<ZephyrConversation> _conversations = <ZephyrConversation>[];
  bool _loading = true;
  String? _error;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    // Show cache immediately — no spinner if we have data
    final cached = MessageCache.instance.conversations;
    if (cached != null) {
      _conversations = cached;
      _loading = false;
    }
    _refresh();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _refresh());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  // Called by pull-to-refresh button — shows spinner only if no cache
  Future<void> _load() async {
    if (_conversations.isEmpty) setState(() { _loading = true; _error = null; });
    await _refresh();
  }

  Future<void> _refresh() async {
    try {
      final List<ZephyrConversation> convos =
          await widget.apiClient.getConversations(widget.accessToken);
      MessageCache.instance.conversations = convos;
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
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
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
                              size: 56, color: Colors.grey.shade300),
                          const SizedBox(height: 12),
                          Text('No messages yet',
                              style: TextStyle(
                                  fontSize: 16, color: Colors.grey.shade500)),
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
                          leading: CircleAvatar(
                            radius: 26,
                            backgroundColor:
                                const Color(0xFF1FA4EA).withValues(alpha: 0.15),
                            backgroundImage: c.avatarUrl != null
                                ? NetworkImage(c.avatarUrl!)
                                : null,
                            child: c.avatarUrl == null
                                ? Text(
                                    c.displayName.isNotEmpty
                                        ? c.displayName[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                        color: Color(0xFF1FA4EA),
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
                                      color: Colors.grey.shade400)),
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
                                          ? Colors.black87
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
                                    color: const Color(0xFF1FA4EA),
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
                            _load(); // refresh unread counts on return
                          },
                        );
                      },
                    ),
    );
  }
}

// ── ThreadPage ────────────────────────────────────────────────────────────────

