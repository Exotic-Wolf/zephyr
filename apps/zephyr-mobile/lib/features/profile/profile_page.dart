import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as sio;

import '../../app_constants.dart';
import '../../models/models.dart';
import '../../services/api_client.dart';
import '../../services/firebase_chat_service.dart';
import '../../widgets/hero_bullet.dart';
import '../chat/thread_firebase_page.dart';
import '../call/random_call_screen.dart';
import '../../flags.dart';
import '../../widgets/coin_icon.dart';
import '../../l10n/app_localizations.dart';

// ── ProfilePage ─────────────────────────────────────────────────────────────

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.feedCard,
    required this.onMessage,
    this.isPreview = false,
    this.apiClient,
    this.accessToken,
    this.myUserId,
    this.myDisplayName,
    this.myAvatarUrl,
  });

  final LiveFeedCard feedCard;
  final VoidCallback onMessage;
  final bool isPreview;
  final ZephyrApiClient? apiClient;
  final String? accessToken;
  final String? myUserId;
  final String? myDisplayName;
  final String? myAvatarUrl;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _following = false;
  bool _isBlocked = false;
  bool _blockLoading = false;

  // Direct call state
  bool _calling = false;
  sio.Socket? _callSocket;

  LiveFeedCard get _card => widget.feedCard;

  int get _callRate => _card.callRateCoinsPerMinute ?? 4200;

  @override
  void initState() {
    super.initState();
    _loadBlockStatus();
    // Warm Firebase RTDB presence for this user
    FirebaseChatService.instance.warmPresence([_card.hostUserId]);
  }

  Future<void> _loadBlockStatus() async {
    final api = widget.apiClient;
    final token = widget.accessToken;
    final me = widget.myUserId;
    if (api == null || token == null || me == null) return;
    if (me == _card.hostUserId) return; // own profile
    try {
      final blocked = await api.isUserBlocked(token, _card.hostUserId);
      if (mounted) setState(() => _isBlocked = blocked);
    } catch (_) {}
  }

  Future<void> _toggleBlock() async {
    final api = widget.apiClient;
    final token = widget.accessToken;
    if (api == null || token == null) return;
    setState(() => _blockLoading = true);
    try {
      if (_isBlocked) {
        await api.unblockUser(token, _card.hostUserId);
        if (mounted) setState(() => _isBlocked = false);
      } else {
        // Confirm before blocking
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text('Block ${_card.hostDisplayName}?'),
            content: const Text("They won't be able to match with you in random calls. You can unblock them later."),
            actions: <Widget>[
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Block', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          await api.blockUser(token, _card.hostUserId);
          if (mounted) setState(() => _isBlocked = true);
        }
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _blockLoading = false);
    }
  }

  @override
  void dispose() {
    _callSocket?.dispose();
    super.dispose();
  }

  void _initiateDirectCall() {
    final userId = widget.myUserId;
    if (userId == null) return;

    setState(() => _calling = true);

    _callSocket = sio.io(
      '$apiBaseUrl/call',
      sio.OptionBuilder()
          .setTransports(<String>['websocket', 'polling'])
          .enableReconnection()
          .setReconnectionAttempts(3)
          .setQuery(<String, dynamic>{'userId': userId})
          .disableAutoConnect()
          .build(),
    );

    _callSocket!
      ..on('connect', (_) {
        _callSocket!.emit('call:direct', <String, dynamic>{
          'userId': userId,
          'receiverId': _card.hostUserId,
        });
      })
      ..on('call:matched', (dynamic data) {
        if (!mounted) return;
        final Map<String, dynamic> payload =
            (data as Map<dynamic, dynamic>).cast<String, dynamic>();
        _callSocket?.disconnect();
        setState(() => _calling = false);
        // Navigate to call screen with pre-matched data
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            fullscreenDialog: true,
            builder: (_) => RandomCallScreen(
              apiClient: widget.apiClient!,
              accessToken: widget.accessToken!,
              userId: userId,
              initialMatch: payload,
            ),
          ),
        );
      })
      ..on('call:busy', (_) {
        if (!mounted) return;
        _callSocket?.disconnect();
        setState(() => _calling = false);
        _showErrorSnack('They are on another call');
      })
      ..on('call:unavailable', (_) {
        if (!mounted) return;
        _callSocket?.disconnect();
        setState(() => _calling = false);
        _showErrorSnack('User is not available right now');
      })
      ..on('call:no_answer', (_) {
        if (!mounted) return;
        _callSocket?.disconnect();
        setState(() => _calling = false);
        _showErrorSnack('No answer');
      })
      ..on('call:rejected', (_) {
        if (!mounted) return;
        _callSocket?.disconnect();
        setState(() => _calling = false);
        _showErrorSnack('Call declined');
      })
      ..on('call:error', (dynamic data) {
        if (!mounted) return;
        _callSocket?.disconnect();
        setState(() => _calling = false);
        _showErrorSnack('Unable to call this user');
      })
      ..connect();
  }

  void _cancelDirectCall() {
    final userId = widget.myUserId;
    if (userId != null) {
      _callSocket?.emit('call:end', <String, dynamic>{
        'userId': userId,
        'sessionId': '',
      });
    }
    _callSocket?.disconnect();
    if (mounted) setState(() => _calling = false);
  }

  void _showErrorSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double bottomPad = MediaQuery.of(context).padding.bottom;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? null : const Color(0xFFF2F2F7),
      bottomNavigationBar: widget.isPreview ? null : Container(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomPad),
        child: Row(
          children: <Widget>[
            Expanded(
              flex: 1,
              child: OutlinedButton.icon(
                onPressed: () {
                  final me = widget.myUserId;
                  if (me != null) {
                    Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => ThreadFirebasePage(
                        myUserId: me,
                        myDisplayName: widget.myDisplayName ?? 'User',
                        myAvatarUrl: widget.myAvatarUrl,
                        otherUserId: _card.hostUserId,
                        otherDisplayName: _card.hostDisplayName,
                        otherAvatarUrl: _card.hostAvatarUrl,
                      ),
                    ));
                  } else {
                    widget.onMessage();
                  }
                },
                icon: const Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 18),
                label: Text(AppLocalizations.of(context)!.messageButton),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? Colors.white : Colors.black87,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(14),
                      bottomLeft: Radius.circular(14),
                    ),
                  ),
                  side: BorderSide.none,
                  backgroundColor: isDark ? const Color(0xFF2C2C2E) : Colors.grey.shade200,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: FilledButton(
                onPressed: (_card.hostStatus == 'offline' || _card.hostStatus == 'busy')
                    ? null
                    : _calling ? _cancelDirectCall : _initiateDirectCall,
                style: FilledButton.styleFrom(
                  backgroundColor: switch (_card.hostStatus) {
                    'offline' => Colors.grey.shade400,
                    'busy'    => Colors.orange.shade300,
                    _ => _calling ? Colors.red.shade400 : const Color(0xFF00A651),
                  },
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(14),
                      bottomRight: Radius.circular(14),
                    ),
                  ),
                ),
                child: switch (_card.hostStatus) {
                  'offline' => Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        const Icon(Icons.phone_disabled_rounded, size: 18),
                        const SizedBox(width: 6),
                        Text(AppLocalizations.of(context)!.notAvailable),
                      ],
                    ),
                  'busy' => Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        const Icon(Icons.phone_locked_rounded, size: 18),
                        const SizedBox(width: 6),
                        Text(AppLocalizations.of(context)!.currentlyBusy),
                      ],
                    ),
                  _ => _calling
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                          ),
                          const SizedBox(width: 8),
                          const Text('Calling...',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600)),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          const Icon(Icons.call_rounded, size: 18),
                          const SizedBox(width: 6),
                          const Text('Video call',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(width: 8),
                          Text('$_callRate',
                              style: const TextStyle(fontSize: 12)),
                          const SizedBox(width: 3),
                          const CoinIcon(size: 13),
                          const Text('/min',
                              style: TextStyle(fontSize: 12)),
                        ],
                      ),
                },
              ),
            ),
          ],
        ),
      ),
      body: CustomScrollView(
        slivers: <Widget>[
          // ── hero header ──────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: const Color(0xFF1FA4EA),
            actions: widget.isPreview || widget.myUserId == _card.hostUserId
                ? null
                : <Widget>[
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.white),
                      onSelected: (String value) {
                        if (value == 'block') _toggleBlock();
                      },
                      itemBuilder: (_) => <PopupMenuEntry<String>>[
                        PopupMenuItem<String>(
                          value: 'block',
                          child: _blockLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Text(
                                  _isBlocked ? 'Unblock' : 'Block',
                                  style: TextStyle(
                                    color: _isBlocked ? null : Colors.red,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  // cover photo placeholder (same blue as card)
                  Container(color: const Color(0xFF1FA4EA)),
                  // avatar centred in lower half
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 48,
                    child: Center(
                      child: CircleAvatar(
                        radius: 48,
                        backgroundColor: Colors.white24,
                        backgroundImage: _card.hostAvatarUrl != null
                            ? CachedNetworkImageProvider(_card.hostAvatarUrl!)
                            : null,
                        child: _card.hostAvatarUrl == null
                            ? Text(
                                _card.hostDisplayName.isNotEmpty
                                    ? _card.hostDisplayName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 36,
                                  fontWeight: FontWeight.w700,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                  // live preview box — top-right (only when live), tappable
                  if (_card.hostStatus == 'live' && !widget.isPreview)
                    Positioned(
                      top: 72,
                      right: 16,
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 100,
                          height: 130,
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          // LiveKit video widget mounts here when wired
                        ),
                      ),
                    ),
                  // status badge bottom-right of cover (real-time Firebase presence)
                  if (!widget.isPreview)
                  Positioned(
                    right: 20,
                    bottom: 16,
                    child: ValueListenableBuilder<int>(
                      valueListenable: FirebaseChatService.instance.presenceVersion,
                      builder: (context, _, __) {
                        final bool isOnline =
                            FirebaseChatService.instance.isOnlineCached(_card.hostUserId) ?? false;
                        final Color dotColor = isOnline ? const Color(0xFF34C759) : const Color(0xFF8E8E93);
                        final String label = isOnline ? 'Online' : 'Offline';
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: dotColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                label,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // ── name + flag ──────────────────────────────────
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          _card.hostDisplayName,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        '${CountryFlags.flagEmoji(_card.hostCountryCode)} ${_card.hostCountryCode}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _card.hostLanguage,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── stats row ────────────────────────────────────
                  Row(
                    children: <Widget>[
                      StatCell(
                          label: AppLocalizations.of(context)!.followers, value: '2.4K'),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // ── follow button ─────────────────────────────────
                  if (!widget.isPreview)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        setState(() => _following = !_following);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: _following
                            ? (isDark ? const Color(0xFF3A3A3C) : Colors.grey.shade300)
                            : const Color(0xFF1FA4EA),
                        foregroundColor:
                            _following ? (isDark ? Colors.white : Colors.black87) : Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        _following ? AppLocalizations.of(context)!.followingButton : AppLocalizations.of(context)!.followButton,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── bio placeholder ──────────────────────────────
                  Text(
                    AppLocalizations.of(context)!.about,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    AppLocalizations.of(context)!.noBioYet,
                    style: TextStyle(
                        fontSize: 14, color: Colors.grey.shade600),
                  ),

                  const SizedBox(height: 28),

                  // ── gifts section ─────────────────────────────────
                  Text(
                    AppLocalizations.of(context)!.gifts,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      AppLocalizations.of(context)!.noGiftsYet,
                      style: TextStyle(
                          fontSize: 14, color: Colors.grey.shade500),
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

