import 'dart:async';

import 'package:agora_chat_sdk/agora_chat_sdk.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/chat_service.dart';
import '../l10n/app_localizations.dart';

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
  List<ChatMessage> _messages = <ChatMessage>[];
  bool _loading = true;
  bool _sending = false;
  String _startMsgId = '';
  bool _hasMore = true;
  bool _loadingMore = false;
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  StreamSubscription<List<ChatMessage>>? _msgSub;

  String get _peerChatId => ChatService.toChatUserId(widget.otherUserId);
  String get _myChatId => ChatService.toChatUserId(widget.myUserId);

  @override
  void initState() {
    super.initState();
    _load();
    _msgSub = ChatService.instance.onMessagesReceived.listen(_onMessages);
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.position.pixels >=
          _scrollCtrl.position.maxScrollExtent - 200) {
        _loadMore();
      }
    });
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onMessages(List<ChatMessage> messages) {
    if (!mounted) return;
    final incoming = messages.where((m) =>
        m.from == _peerChatId || m.conversationId == _peerChatId);
    if (incoming.isEmpty) return;
    setState(() {
      _messages = <ChatMessage>[...incoming, ..._messages];
    });
    _scrollToBottom();
    // Mark as read
    ChatService.instance.markConversationRead(_peerChatId);
  }

  Future<void> _load() async {
    try {
      final msgs = await ChatService.instance.fetchHistory(
        _peerChatId,
        startMsgId: '',
        pageSize: 30,
      );
      if (!mounted) return;
      // fetchHistory returns oldest-first; we display reversed (newest at bottom)
      final sorted = msgs.reversed.toList();
      setState(() {
        _messages = sorted;
        _hasMore = msgs.length >= 30;
        if (msgs.isNotEmpty) _startMsgId = msgs.first.msgId;
        _loading = false;
      });
      _scrollToBottom(jump: true);
      // Mark conversation as read
      ChatService.instance.markConversationRead(_peerChatId);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _startMsgId.isEmpty) return;
    setState(() => _loadingMore = true);
    try {
      final msgs = await ChatService.instance.fetchHistory(
        _peerChatId,
        startMsgId: _startMsgId,
        pageSize: 30,
      );
      if (!mounted) return;
      final sorted = msgs.reversed.toList();
      setState(() {
        _messages = <ChatMessage>[..._messages, ...sorted];
        _hasMore = msgs.length >= 30;
        if (msgs.isNotEmpty) _startMsgId = msgs.first.msgId;
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
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send() async {
    final String text = _inputCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _inputCtrl.clear();
    try {
      final msg =
          await ChatService.instance.sendTextMessage(_peerChatId, text);
      if (!mounted) return;
      setState(() => _messages = <ChatMessage>[msg, ..._messages]);
      _scrollToBottom();
    } catch (_) {
      // Put text back so user can retry
      if (mounted) _inputCtrl.text = text;
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _formatTime(int serverTime) {
    final DateTime dt =
        DateTime.fromMillisecondsSinceEpoch(serverTime).toLocal();
    final String h = dt.hour.toString().padLeft(2, '0');
    final String m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  bool _isDifferentDay(int a, int b) {
    final DateTime la = DateTime.fromMillisecondsSinceEpoch(a).toLocal();
    final DateTime lb = DateTime.fromMillisecondsSinceEpoch(b).toLocal();
    return la.year != lb.year || la.month != lb.month || la.day != lb.day;
  }

  String _formatDateHeader(int ts) {
    final DateTime local = DateTime.fromMillisecondsSinceEpoch(ts).toLocal();
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
            child: Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade500)),
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
                        child: Text(
                            AppLocalizations.of(context)!.noMessagesYetSayHello,
                            style: TextStyle(color: Colors.grey.shade500)),
                      )
                    : ListView.builder(
                        reverse: true,
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 16),
                        itemCount:
                            _messages.length + (_loadingMore ? 1 : 0),
                        itemBuilder: (BuildContext ctx, int i) {
                          if (_loadingMore && i == _messages.length) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2)),
                            );
                          }
                          final ChatMessage msg = _messages[i];
                          final bool isMe = msg.from == _myChatId;
                          final bool showHeader = i == _messages.length - 1 ||
                              _isDifferentDay(
                                  _messages[i + 1].serverTime,
                                  msg.serverTime);

                          String text = '';
                          if (msg.body is ChatTextMessageBody) {
                            text =
                                (msg.body as ChatTextMessageBody).content;
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              if (showHeader)
                                _buildDateHeader(
                                    _formatDateHeader(msg.serverTime)),
                              Align(
                                alignment: isMe
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                      vertical: 3),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                  constraints: BoxConstraints(
                                      maxWidth:
                                          MediaQuery.sizeOf(ctx).width *
                                              0.72),
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
                                          isMe ? 18 : 4),
                                      bottomRight: Radius.circular(
                                          isMe ? 4 : 18),
                                    ),
                                    boxShadow: <BoxShadow>[
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                            alpha:
                                                isDark ? 0.06 : 0.10),
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
                                      Text(text,
                                          style: TextStyle(
                                              fontSize: 15,
                                              color: isMe
                                                  ? Colors.black87
                                                  : (isDark
                                                      ? Colors.white
                                                      : Colors
                                                          .black87))),
                                      const SizedBox(height: 3),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: <Widget>[
                                          Text(
                                              _formatTime(
                                                  msg.serverTime),
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: isMe
                                                      ? Colors.black54
                                                      : (isDark
                                                          ? Colors.grey
                                                              .shade500
                                                          : Colors.grey
                                                              .shade400))),
                                          if (isMe) ...<Widget>[
                                            const SizedBox(width: 3),
                                            SizedBox(
                                              width: 16,
                                              child: Icon(
                                                msg.hasReadAck
                                                    ? Icons.done_all
                                                    : Icons.done,
                                                size: 13,
                                                color: msg.hasReadAck
                                                    ? Colors
                                                        .blue.shade300
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
                        hintText:
                            AppLocalizations.of(context)!.messageHint,
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
                            child: CircularProgressIndicator(
                                strokeWidth: 2),
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
