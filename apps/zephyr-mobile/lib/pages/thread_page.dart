import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as sio;

import '../app_constants.dart';
import '../models/models.dart';
import '../services/api_client.dart';

// ── Message cache (in-memory, survives navigation within session) ─────────────

class MessageCache {
  MessageCache._();
  static final MessageCache instance = MessageCache._();

  List<ZephyrConversation>? conversations;
  final Map<String, List<ZephyrMessage>> threads = <String, List<ZephyrMessage>>{};
}

// ── InboxPage ─────────────────────────────────────────────────────────────────


class ThreadPage extends StatefulWidget {
  const ThreadPage({
    super.key,
    required this.apiClient,
    required this.accessToken,
    required this.myUserId,
    required this.otherUserId,
    required this.otherDisplayName,
    this.otherAvatarUrl,
  });

  final ZephyrApiClient apiClient;
  final String accessToken;
  final String myUserId;
  final String otherUserId;
  final String otherDisplayName;
  final String? otherAvatarUrl;

  @override
  State<ThreadPage> createState() => _ThreadPageState();
}

class _ThreadPageState extends State<ThreadPage> {
  List<ZephyrMessage> _messages = <ZephyrMessage>[];
  bool _loading = true;
  bool _sending = false;
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  sio.Socket? _socket;

  @override
  void initState() {
    super.initState();
    final cached = MessageCache.instance.threads[widget.otherUserId];
    if (cached != null) {
      _messages = cached;
      _loading = false;
      _scrollToBottom();
    }
    _load();
    _connectSocket();
  }

  void _connectSocket() {
    _socket = sio.io(
      '$apiBaseUrl/chat',
      sio.OptionBuilder()
          .setTransports(<String>['websocket', 'polling'])
          .setQuery(<String, String>{'userId': widget.myUserId})
          .enableReconnection()
          .setReconnectionAttempts(999999)
          .setReconnectionDelay(2000)
          .disableAutoConnect()
          .build(),
    )
      ..on('chat:message', (dynamic data) {
        if (!mounted) return;
        try {
          final Map<String, dynamic> payload =
              (data as Map<dynamic, dynamic>).cast<String, dynamic>();
          final Map<String, dynamic> msgJson =
              (payload['message'] as Map<dynamic, dynamic>).cast<String, dynamic>();
          final ZephyrMessage msg = ZephyrMessage.fromJson(msgJson);
          // Only handle messages relevant to this thread
          final bool relevant =
              (msg.senderId == widget.otherUserId && msg.receiverId == widget.myUserId) ||
              (msg.senderId == widget.myUserId && msg.receiverId == widget.otherUserId);
          if (!relevant) return;
          // Avoid duplicates (sender already appended optimistically)
          if (_messages.any((ZephyrMessage m) => m.id == msg.id)) return;
          final updated = <ZephyrMessage>[..._messages, msg];
          MessageCache.instance.threads[widget.otherUserId] = updated;
          setState(() => _messages = updated);
          _scrollToBottom();
          // Mark as read if incoming
          if (msg.receiverId == widget.myUserId && msg.readAt == null) {
            widget.apiClient.markMessageRead(widget.accessToken, msg.id).ignore();
          }
        } catch (_) {}
      })
      ..connect();
  }

  @override
  void dispose() {
    _socket?.dispose();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final List<ZephyrMessage> msgs = await widget.apiClient
          .getThread(widget.accessToken, widget.otherUserId);
      MessageCache.instance.threads[widget.otherUserId] = msgs;
      if (!mounted) return;
      setState(() { _messages = msgs; _loading = false; });
      for (final ZephyrMessage m in msgs) {
        if (m.receiverId == widget.myUserId && m.readAt == null) {
          widget.apiClient.markMessageRead(widget.accessToken, m.id).ignore();
        }
      }
      _scrollToBottom();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final String text = _inputCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _inputCtrl.clear();
    try {
      final ZephyrMessage msg = await widget.apiClient.sendMessage(
          widget.accessToken, widget.otherUserId, text);
      if (!mounted) return;
      final updated = <ZephyrMessage>[..._messages, msg];
      MessageCache.instance.threads[widget.otherUserId] = updated;
      setState(() => _messages = updated);
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _formatTime(DateTime dt) {
    final String h = dt.hour.toString().padLeft(2, '0');
    final String m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final double bottomPad = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        leadingWidth: 40,
        title: Row(
          children: <Widget>[
            CircleAvatar(
              radius: 18,
              backgroundColor:
                  const Color(0xFF1FA4EA).withValues(alpha: 0.15),
              backgroundImage: widget.otherAvatarUrl != null
                  ? NetworkImage(widget.otherAvatarUrl!)
                  : null,
              child: widget.otherAvatarUrl == null
                  ? Text(
                      widget.otherDisplayName.isNotEmpty
                          ? widget.otherDisplayName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                          color: Color(0xFF1FA4EA),
                          fontWeight: FontWeight.w700,
                          fontSize: 14),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Text(widget.otherDisplayName),
          ],
        ),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Text('No messages yet. Say hello!',
                            style: TextStyle(color: Colors.grey.shade500)),
                      )
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 16),
                        itemCount: _messages.length,
                        itemBuilder: (BuildContext ctx, int i) {
                          final ZephyrMessage msg = _messages[i];
                          final bool isMe =
                              msg.senderId == widget.myUserId;
                          return Align(
                            alignment: isMe
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin:
                                  const EdgeInsets.symmetric(vertical: 3),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.sizeOf(ctx).width * 0.72),
                              decoration: BoxDecoration(
                                color: isMe
                                    ? const Color(0xFF1FA4EA)
                                    : Colors.white,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(18),
                                  topRight: const Radius.circular(18),
                                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                                  bottomRight: Radius.circular(isMe ? 4 : 18),
                                ),
                                boxShadow: <BoxShadow>[
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.06),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: isMe
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(msg.body,
                                      style: TextStyle(
                                          fontSize: 15,
                                          color: isMe
                                              ? Colors.white
                                              : Colors.black87)),
                                  const SizedBox(height: 3),
                                  Text(_formatTime(msg.createdAt),
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: isMe
                                              ? Colors.white70
                                              : Colors.grey.shade400)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          // ── Input bar ──────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + bottomPad),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F2F7),
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
                        contentPadding:
                            EdgeInsets.symmetric(vertical: 10),
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
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
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
                            color: Color(0xFF1FA4EA),
                          ),
                          child: const Icon(Icons.send_rounded,
                              color: Colors.white, size: 18),
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

