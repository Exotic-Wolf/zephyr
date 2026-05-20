import 'dart:async';
import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as sio;

import '../app_constants.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import '../l10n/app_localizations.dart';

// ── Message cache (in-memory, survives navigation within session) ─────────────

class MessageCache {
  MessageCache._();
  static final MessageCache instance = MessageCache._();

  List<ZephyrConversation>? conversations;
  final Map<String, List<ZephyrMessage>> threads = <String, List<ZephyrMessage>>{};
}

// ── Message bus — home_screen publishes here; open threads subscribe ──────────

class MessageBus {
  MessageBus._();
  static final MessageBus instance = MessageBus._();

  final StreamController<ZephyrMessage> _ctrl =
      StreamController<ZephyrMessage>.broadcast();

  Stream<ZephyrMessage> get stream => _ctrl.stream;
  void emit(ZephyrMessage msg) => _ctrl.add(msg);
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

class _FailedMessage {
  _FailedMessage(this.text);
  final String text;
}

class _ThreadPageState extends State<ThreadPage> {
  List<ZephyrMessage> _messages = <ZephyrMessage>[];
  final List<_FailedMessage> _failedMessages = <_FailedMessage>[];
  bool _loading = true;
  bool _sending = false;
  bool _hasMore = false;
  bool _loadingMore = false;
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  sio.Socket? _socket;
  StreamSubscription<RemoteMessage>? _fcmSub;
  StreamSubscription<ZephyrMessage>? _busSub;
  bool _syncInFlight = false;

  @override
  void initState() {
    super.initState();
    final cached = MessageCache.instance.threads[widget.otherUserId];
    if (cached != null) {
      _messages = cached;
      _loading = false;
    }
    _load();
    _connectSocket();
    _busSub = MessageBus.instance.stream.listen(_onBusMessage);
    _fcmSub = FirebaseMessaging.onMessage.listen(_onFcmMessage);
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels >=
          _scrollCtrl.position.maxScrollExtent - 200) {
        _loadMore();
      }
    });
  }

  void _onFcmMessage(RemoteMessage message) {
    if (!mounted) return;
    final data = message.data;
    if (data['type'] != 'read_receipt') return;
    final String? messageId = data['messageId'] as String?;
    final String? readAtStr = data['readAt'] as String?;
    if (messageId == null || readAtStr == null) return;
    final DateTime readAt = DateTime.parse(readAtStr);
    final List<ZephyrMessage> next = _messages.map((ZephyrMessage m) {
      if (m.id != messageId) return m;
      return ZephyrMessage(
        id: m.id,
        senderId: m.senderId,
        receiverId: m.receiverId,
        body: m.body,
        createdAt: m.createdAt,
        readAt: readAt,
      );
    }).toList();
    MessageCache.instance.threads[widget.otherUserId] = next;
    setState(() => _messages = next);
  }

  /// Called by [MessageBus] when home_screen's working socket receives a message.
  void _onBusMessage(ZephyrMessage msg) {
    if (!mounted) return;
    final bool relevant =
        (msg.senderId == widget.otherUserId && msg.receiverId == widget.myUserId) ||
        (msg.senderId == widget.myUserId && msg.receiverId == widget.otherUserId);
    if (!relevant) return;
    if (_messages.any((ZephyrMessage m) => m.id == msg.id)) return;
    final updated = <ZephyrMessage>[..._messages, msg];
    MessageCache.instance.threads[widget.otherUserId] = updated;
    setState(() => _messages = updated);
    _scrollToBottom();
    if (msg.receiverId == widget.myUserId && msg.readAt == null) {
      widget.apiClient.markMessageRead(widget.accessToken, msg.id).ignore();
    }
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
      ..on('connect', (_) {
        _socket?.emit('chat:join', widget.myUserId);
        // On initial connect load full thread; on reconnect only sync missed messages
        if (mounted) {
          if (_messages.isEmpty) {
            _load();
          } else {
            _syncMissed();
          }
        }
      })
      ..on('chat:read', (dynamic data) {
        if (!mounted) return;
        try {
          final Map<String, dynamic> payload =
              (data as Map<dynamic, dynamic>).cast<String, dynamic>();
          final Map<String, dynamic> msgJson =
              (payload['message'] as Map<dynamic, dynamic>).cast<String, dynamic>();
          final ZephyrMessage updated = ZephyrMessage.fromJson(msgJson);
          final List<ZephyrMessage> next = _messages
              .map((ZephyrMessage m) => m.id == updated.id ? updated : m)
              .toList();
          MessageCache.instance.threads[widget.otherUserId] = next;
          setState(() => _messages = next);
        } catch (_) {}
      })
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
    _busSub?.cancel();
    _fcmSub?.cancel();
    _socket?.dispose();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  /// Merges [fresh] from API with any socket-appended messages not yet in DB,
  /// so a _load() return never silently drops in-flight socket messages.
  List<ZephyrMessage> _merge(List<ZephyrMessage> fresh) {
    final Set<String> freshIds = fresh.map((m) => m.id).toSet();
    final List<ZephyrMessage> socketOnly =
        _messages.where((m) => !freshIds.contains(m.id)).toList();
    final List<ZephyrMessage> merged = <ZephyrMessage>[...fresh, ...socketOnly];
    merged.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return merged;
  }

  Future<void> _load() async {
    try {
      final result = await widget.apiClient
          .getThread(widget.accessToken, widget.otherUserId);
      if (!mounted) return;
      final merged = _merge(result.messages);
      MessageCache.instance.threads[widget.otherUserId] = merged;
      setState(() {
        _messages = merged;
        _hasMore = result.hasMore;
        _loading = false;
      });
      _scrollToBottom(jump: true);
      for (final ZephyrMessage m in result.messages) {
        if (m.receiverId == widget.myUserId && m.readAt == null) {
          widget.apiClient.markMessageRead(widget.accessToken, m.id).ignore();
        }
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Cursor-based sync — fetches ONLY messages newer than the last known message.
  /// Called on socket reconnect so we catch anything missed while disconnected.
  /// Zero wasted queries: if nothing is missed, returns immediately with 0 rows.
  Future<void> _syncMissed() async {
    if (_syncInFlight || !mounted || _messages.isEmpty) return;
    _syncInFlight = true;
    try {
      final DateTime after = _messages.last.createdAt;
      final result = await widget.apiClient.getThread(
        widget.accessToken,
        widget.otherUserId,
        after: after,
      );
      if (!mounted) return;
      if (result.messages.isEmpty) return;
      final List<ZephyrMessage> updated = <ZephyrMessage>[..._messages];
      for (final ZephyrMessage m in result.messages) {
        if (!updated.any((ZephyrMessage x) => x.id == m.id)) {
          updated.add(m);
        }
      }
      updated.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      MessageCache.instance.threads[widget.otherUserId] = updated;
      final bool atBottom = !_scrollCtrl.hasClients ||
          _scrollCtrl.position.pixels < 80;
      setState(() => _messages = updated);
      if (atBottom) _scrollToBottom();
      for (final ZephyrMessage m in result.messages) {
        if (m.receiverId == widget.myUserId && m.readAt == null) {
          widget.apiClient.markMessageRead(widget.accessToken, m.id).ignore();
        }
      }
    } catch (_) {
    } finally {
      _syncInFlight = false;
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _messages.isEmpty) return;
    setState(() => _loadingMore = true);
    try {
      final result = await widget.apiClient.getThread(
        widget.accessToken,
        widget.otherUserId,
        before: _messages.first.createdAt,
      );
      if (!mounted) return;
      final List<ZephyrMessage> merged = <ZephyrMessage>[
        ...result.messages,
        ..._messages,
      ];
      MessageCache.instance.threads[widget.otherUserId] = merged;
      setState(() {
        _messages = merged;
        _hasMore = result.hasMore;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _scrollToBottom({bool jump = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      if (jump) {
        _scrollCtrl.jumpTo(0);
      } else {
        _scrollCtrl.animateTo(0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send() async {
    final String text = _inputCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _inputCtrl.clear();
    final String idempotencyKey =
        '${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(999999)}';
    try {
      final ZephyrMessage msg = await widget.apiClient.sendMessage(
          widget.accessToken, widget.otherUserId, text,
          idempotencyKey: idempotencyKey);
      if (!mounted) return;
      final updated = <ZephyrMessage>[..._messages, msg];
      MessageCache.instance.threads[widget.otherUserId] = updated;
      setState(() => _messages = updated);
      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      setState(() => _failedMessages.add(_FailedMessage(text)));
      _scrollToBottom();
    } finally {
      if (mounted) setState(() => _sending = false);
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
    const List<String> months = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    if (local.year == now.year) {
      const List<String> weekdays = <String>[
        'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
      ];
      return '${weekdays[local.weekday - 1]}, ${local.day} ${months[local.month - 1]}';
    }
    return '${local.day} ${months[local.month - 1]} ${local.year}';
  }

  Widget _buildDateHeader(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: <Widget>[
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
        title: Row(
          children: <Widget>[
            CircleAvatar(
              radius: 18,
              backgroundColor:
                  const Color(0xFFFF8F00).withValues(alpha: 0.15),
              backgroundImage: widget.otherAvatarUrl != null
                  ? CachedNetworkImageProvider(widget.otherAvatarUrl!)
                  : null,
              child: widget.otherAvatarUrl == null
                  ? Text(
                      widget.otherDisplayName.isNotEmpty
                          ? widget.otherDisplayName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                          color: Color(0xFFFF8F00),
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
                        child: Text(AppLocalizations.of(context)!.noMessagesYetSayHello,
                            style: TextStyle(color: Colors.grey.shade500)),
                      )
                    : ListView.builder(
                        reverse: true,
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 16),
                        itemCount: _messages.length +
                            _failedMessages.length +
                            (_loadingMore ? 1 : 0),
                        itemBuilder: (BuildContext ctx, int i) {
                          // Spinner at the top (highest index in reversed list)
                          if (_loadingMore &&
                              i == _messages.length + _failedMessages.length) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                            );
                          }
                          // Failed messages sit at the bottom (lowest index = bottom in reversed list)
                          if (i < _failedMessages.length) {
                            final _FailedMessage failed =
                                _failedMessages[_failedMessages.length - 1 - i];
                            return Align(
                              alignment: Alignment.centerRight,
                              child: GestureDetector(
                                onTap: () {
                                  setState(() => _failedMessages.remove(failed));
                                  _inputCtrl.text = failed.text;
                                },
                                child: Container(
                                  margin: const EdgeInsets.symmetric(vertical: 3),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                  constraints: BoxConstraints(
                                      maxWidth: MediaQuery.sizeOf(ctx).width * 0.72),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade700,
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(18),
                                      topRight: Radius.circular(18),
                                      bottomLeft: Radius.circular(18),
                                      bottomRight: Radius.circular(4),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: <Widget>[
                                      Text(failed.text,
                                          style: const TextStyle(
                                              fontSize: 15, color: Colors.white)),
                                      const SizedBox(height: 3),
                                      const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: <Widget>[
                                          Icon(Icons.refresh,
                                              size: 13, color: Colors.white70),
                                          SizedBox(width: 3),
                                          Text('Failed · tap to retry',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.white70)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }
                          final int msgIdx =
                              _messages.length - 1 - (i - _failedMessages.length);
                          final ZephyrMessage msg = _messages[msgIdx];
                          final bool isMe =
                              msg.senderId == widget.myUserId;
                          final bool showHeader = msgIdx == 0 ||
                              _isDifferentDay(
                                  _messages[msgIdx - 1].createdAt,
                                  msg.createdAt);
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              if (showHeader)
                                _buildDateHeader(
                                    _formatDateHeader(msg.createdAt)),
                              Align(
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
                                    ? const Color(0xFFFF8F00)
                                    : (isDark ? const Color(0xFF2C2C2E) : Colors.white),
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(18),
                                  topRight: const Radius.circular(18),
                                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                                  bottomRight: Radius.circular(isMe ? 4 : 18),
                                ),
                                boxShadow: <BoxShadow>[
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: isDark ? 0.06 : 0.10),
                                    blurRadius: isDark ? 4 : 6,
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
                                              ? Colors.black87
                                              : (isDark ? Colors.white : Colors.black87))),
                                  const SizedBox(height: 3),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Text(_formatTime(msg.createdAt),
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: isMe
                                                  ? Colors.black54
                                                  : (isDark ? Colors.grey.shade500 : Colors.grey.shade400))),
                                      if (isMe) ...<Widget>[
                                        const SizedBox(width: 3),
                                        SizedBox(
                                          width: 16,
                                          child: Icon(
                                            msg.readAt != null ? Icons.done_all : Icons.done,
                                            size: 13,
                                            color: msg.readAt != null
                                                ? Colors.blue.shade300
                                                : Colors.black54,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                            ],
                          );
                        },
                      ),
          ),
          // ── Input bar ──────────────────────────────────────────
          Container(
            color: isDark ? const Color(0xFF1C1C1C) : Colors.white,
            padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + bottomPad),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF2F2F7),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _inputCtrl,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: AppLocalizations.of(context)!.messageHint,
                        isDense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 10),
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
                            color: Color(0xFFFF8F00),
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

