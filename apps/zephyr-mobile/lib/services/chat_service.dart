import 'dart:async';

import 'package:agora_chat_sdk/agora_chat_sdk.dart';

import 'api_client.dart';

/// Singleton service wrapping the Agora Chat SDK.
///
/// Lifecycle:
///   1. App calls [init] once at startup (from home_screen).
///   2. [login] fetches a chat token from our backend and logs into Agora Chat.
///   3. UI subscribes to [onMessagesReceived] / [onConversationsChanged].
///   4. [logout] on sign-out.
class ChatService {
  ChatService._();
  static final ChatService instance = ChatService._();

  bool _initialized = false;
  String? _currentUserId;

  // ── Streams for UI ─────────────────────────────────────────────────────────

  final StreamController<List<ChatMessage>> _messageCtrl =
      StreamController<List<ChatMessage>>.broadcast();
  Stream<List<ChatMessage>> get onMessagesReceived => _messageCtrl.stream;

  final StreamController<void> _conversationCtrl =
      StreamController<void>.broadcast();
  /// Fires whenever conversations list may have changed (new msg, read, etc.)
  Stream<void> get onConversationsChanged => _conversationCtrl.stream;

  // ── Init ───────────────────────────────────────────────────────────────────

  Future<void> init(String appKey) async {
    if (_initialized) return;
    final options = ChatOptions(appKey: appKey, autoLogin: false);
    await ChatClient.getInstance.init(options);
    _initialized = true;
  }

  // ── Login / Logout ─────────────────────────────────────────────────────────

  Future<void> login({
    required ZephyrApiClient apiClient,
    required String accessToken,
  }) async {
    final creds = await apiClient.getChatToken(accessToken);

    if (!_initialized) {
      await init(creds.appKey);
    }

    _currentUserId = creds.chatUserId;

    await ChatClient.getInstance.loginWithToken(
      creds.chatUserId,
      creds.token,
    );

    // Register event handlers after login
    ChatClient.getInstance.chatManager.addEventHandler(
      'ChatService',
      ChatEventHandler(
        onMessagesReceived: (List<ChatMessage> messages) {
          _messageCtrl.add(messages);
          _conversationCtrl.add(null);
        },
      ),
    );

    ChatClient.getInstance.chatManager.addEventHandler(
      'ChatServiceRead',
      ChatEventHandler(
        onMessagesRead: (List<ChatMessage> messages) {
          _conversationCtrl.add(null);
        },
      ),
    );
  }

  Future<void> logout() async {
    ChatClient.getInstance.chatManager.removeEventHandler('ChatService');
    ChatClient.getInstance.chatManager.removeEventHandler('ChatServiceRead');
    await ChatClient.getInstance.logout();
    _currentUserId = null;
  }

  bool get isLoggedIn => _currentUserId != null;
  String? get currentUserId => _currentUserId;

  // ── Conversations ──────────────────────────────────────────────────────────

  Future<List<ChatConversation>> getConversations() async {
    final result = await ChatClient.getInstance.chatManager
        .fetchConversationsByOptions(
      options: ConversationFetchOptions(pageSize: 50),
    );
    return result.data;
  }

  // ── Messages ───────────────────────────────────────────────────────────────

  /// Send a text message to [peerId] (their Agora Chat user ID, i.e. UUID without dashes).
  Future<ChatMessage> sendTextMessage(String peerId, String text) async {
    final msg = ChatMessage.createTxtSendMessage(
      targetId: peerId,
      content: text,
    );
    await ChatClient.getInstance.chatManager.sendMessage(msg);
    _conversationCtrl.add(null);
    return msg;
  }

  /// Fetch history messages for a 1-on-1 conversation.
  /// [startMsgId] empty string = most recent; pass last message ID for pagination.
  Future<List<ChatMessage>> fetchHistory(
    String peerId, {
    String startMsgId = '',
    int pageSize = 30,
  }) async {
    final cursor = await ChatClient.getInstance.chatManager
        .fetchHistoryMessagesByOption(
      peerId,
      ChatConversationType.Chat,
      cursor: startMsgId.isEmpty ? null : startMsgId,
      pageSize: pageSize,
    );
    return cursor.data;
  }

  /// Mark all messages from [peerId] as read.
  Future<void> markConversationRead(String peerId) async {
    final conv = await ChatClient.getInstance.chatManager.getConversation(peerId);
    await conv?.markAllMessagesAsRead();
    await ChatClient.getInstance.chatManager.sendConversationReadAck(peerId);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Convert a Zephyr UUID (with dashes) to Agora Chat user ID (no dashes, lowercase).
  static String toChatUserId(String zephyrUserId) {
    return zephyrUserId.replaceAll('-', '').toLowerCase();
  }

  /// Convert an Agora Chat user ID (32-char hex) back to Zephyr UUID format.
  static String toZephyrUserId(String chatUserId) {
    final s = chatUserId.toLowerCase();
    return '${s.substring(0, 8)}-${s.substring(8, 12)}-${s.substring(12, 16)}-${s.substring(16, 20)}-${s.substring(20)}';
  }
}
