import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/firebase_chat_service.dart';

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
  StreamSubscription<List<FirebaseMessage>>? _sub;
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    // Ensure presence is warmed for this user
    FirebaseChatService.instance.warmPresence([widget.otherUserId]);
    _sub = FirebaseChatService.instance
        .watchMessages(widget.otherUserId)
        .listen((List<FirebaseMessage> msgs) {
      if (mounted) {
        setState(() => _messages = msgs);
        _scrollToBottom();
        // Mark incoming messages as read continuously while chat is open
        _markIncomingRead(msgs);
      }
    });
  }

  void _markIncomingRead(List<FirebaseMessage> msgs) {
    final bool hasUnread = msgs.any(
        (m) => m.senderId == widget.otherUserId && m.readAt == null);
    if (hasUnread) {
      FirebaseChatService.instance.markRead(widget.otherUserId);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
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
      await FirebaseChatService.instance.sendMessage(
        otherUserId: widget.otherUserId,
        body: text,
        myDisplayName: widget.myDisplayName,
        myAvatarUrl: widget.myAvatarUrl,
        otherDisplayName: widget.otherDisplayName,
        otherAvatarUrl: widget.otherAvatarUrl,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Send failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pickAndSendImage() async {
    final XFile? picked =
        await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked == null) return;
    setState(() => _sending = true);
    try {
      await FirebaseChatService.instance.sendImage(
        otherUserId: widget.otherUserId,
        imageFile: File(picked.path),
        myDisplayName: widget.myDisplayName,
        myAvatarUrl: widget.myAvatarUrl,
        otherDisplayName: widget.otherDisplayName,
        otherAvatarUrl: widget.otherAvatarUrl,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image send failed: $e')),
        );
      }
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
    const List<String> months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
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
            child: Text(label,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
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
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFFFF8F00).withValues(alpha: 0.15),
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.otherDisplayName, style: const TextStyle(fontSize: 16)),
                  // Real-time presence from cache
                  ValueListenableBuilder<int>(
                    valueListenable: FirebaseChatService.instance.presenceVersion,
                    builder: (context, _, __) {
                      final bool isOnline =
                          FirebaseChatService.instance.isOnlineCached(widget.otherUserId) ?? false;
                      return Text(
                        isOnline ? 'online' : 'offline',
                        style: TextStyle(
                          fontSize: 12,
                          color: isOnline ? Colors.green : Colors.grey.shade500,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Text('Say hello!',
                        style: TextStyle(color: Colors.grey.shade500)))
                : ListView.builder(
                    reverse: true,
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    itemCount: _messages.length,
                    itemBuilder: (BuildContext ctx, int i) {
                      final int msgIdx = _messages.length - 1 - i;
                      final FirebaseMessage msg = _messages[msgIdx];
                      final bool isMe = msg.senderId == widget.myUserId;
                      final bool showHeader = msgIdx == 0 ||
                          _isDifferentDay(
                              _messages[msgIdx - 1].createdAt, msg.createdAt);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (showHeader)
                            _buildDateHeader(_formatDateHeader(msg.createdAt)),
                          Align(
                            alignment: isMe
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 3),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              constraints: BoxConstraints(
                                  maxWidth: MediaQuery.sizeOf(ctx).width * 0.72),
                              decoration: BoxDecoration(
                                color: isMe
                                    ? const Color(0xFFFF8F00)
                                    : (isDark
                                        ? const Color(0xFF2C2C2E)
                                        : Colors.white),
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(18),
                                  topRight: const Radius.circular(18),
                                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                                  bottomRight: Radius.circular(isMe ? 4 : 18),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black
                                        .withValues(alpha: isDark ? 0.06 : 0.10),
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
                                  if (msg.type == 'image' && msg.imageUrl != null)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: CachedNetworkImage(
                                        imageUrl: msg.imageUrl!,
                                        width: 200,
                                        fit: BoxFit.cover,
                                        placeholder: (_, __) => const SizedBox(
                                          width: 200,
                                          height: 150,
                                          child: Center(
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2)),
                                        ),
                                      ),
                                    )
                                  else
                                    Text(msg.body,
                                        style: TextStyle(
                                            fontSize: 15,
                                            color: isMe
                                                ? Colors.black87
                                                : (isDark
                                                    ? Colors.white
                                                    : Colors.black87))),
                                  const SizedBox(height: 3),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(_formatTime(msg.createdAt),
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: isMe
                                                  ? Colors.black54
                                                  : (isDark
                                                      ? Colors.grey.shade500
                                                      : Colors.grey.shade400))),
                                      if (isMe) ...[
                                        const SizedBox(width: 3),
                                        Icon(
                                          msg.readAt != null
                                              ? Icons.done_all
                                              : msg.deliveredAt != null
                                                  ? Icons.done_all
                                                  : Icons.done,
                                          size: 13,
                                          color: msg.readAt != null
                                              ? Colors.blue.shade300
                                              : msg.deliveredAt != null
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
                    child: Icon(Icons.image_outlined,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        size: 26),
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
                            child: CircularProgressIndicator(strokeWidth: 2),
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
