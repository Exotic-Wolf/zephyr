import 'package:flutter/material.dart';
import 'package:country_picker/country_picker.dart';

import '../models/models.dart';
import '../services/api_client.dart';
import '../widgets/spark_icon.dart';
import '../widgets/language_picker_sheet.dart';
import '../widgets/hero_bullet.dart';
import 'thread_page.dart';
import '../flags.dart';
import '../widgets/coin_icon.dart';

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
  });

  final LiveFeedCard feedCard;
  final VoidCallback onMessage;
  final bool isPreview;
  final ZephyrApiClient? apiClient;
  final String? accessToken;
  final String? myUserId;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _following = false;

  LiveFeedCard get _card => widget.feedCard;

  void _showCallSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // drag handle
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // video call row
                InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  borderRadius: BorderRadius.circular(14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 8),
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFF00A651).withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.call_rounded,
                            color: Color(0xFF00A651),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Text(
                            'Video call',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Row(
                          children: <Widget>[
                            const Text(
                              '4200',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const CoinIcon(size: 18),
                            const Text(
                              ' /min',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color get _statusColor => switch (_card.hostStatus) {
        'live' => const Color(0xFFFF3B30),
        'busy' => const Color(0xFFFF9500),
        'offline' => const Color(0xFF8E8E93),
        _ => const Color(0xFF34C759),
      };

  String get _statusLabel => switch (_card.hostStatus) {
        'live' => 'Live',
        'busy' => 'Busy',
        'offline' => 'Offline',
        _ => 'Online',
      };

  @override
  Widget build(BuildContext context) {
    final double bottomPad = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      bottomNavigationBar: widget.isPreview ? null : Container(
        color: Colors.white,
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomPad),
        child: Row(
          children: <Widget>[
            Expanded(
              flex: 1,
              child: OutlinedButton.icon(
                onPressed: () {
                  final api = widget.apiClient;
                  final token = widget.accessToken;
                  final me = widget.myUserId;
                  if (api != null && token != null && me != null) {
                    Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => ThreadPage(
                        apiClient: api,
                        accessToken: token,
                        myUserId: me,
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
                label: const Text('Message'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black87,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(14),
                      bottomLeft: Radius.circular(14),
                    ),
                  ),
                  side: BorderSide.none,
                  backgroundColor: Colors.grey.shade200,
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: FilledButton(
                onPressed: (_card.hostStatus == 'offline' || _card.hostStatus == 'busy')
                    ? null
                    : () => _showCallSheet(context),
                style: FilledButton.styleFrom(
                  backgroundColor: switch (_card.hostStatus) {
                    'offline' => Colors.grey.shade400,
                    'busy'    => Colors.orange.shade300,
                    _         => const Color(0xFF00A651),
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
                  'offline' => const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(Icons.phone_disabled_rounded, size: 18),
                        SizedBox(width: 6),
                        Text('Not available'),
                      ],
                    ),
                  'busy' => const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Icon(Icons.phone_locked_rounded, size: 18),
                        SizedBox(width: 6),
                        Text('Currently busy'),
                      ],
                    ),
                  _ => Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        const Icon(Icons.call_rounded, size: 18),
                        const SizedBox(width: 6),
                        const Text('Video call',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                        const Text('4200',
                            style: TextStyle(fontSize: 12)),
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
                            ? NetworkImage(_card.hostAvatarUrl!)
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
                  // status badge bottom-right of cover
                  if (!widget.isPreview)
                  Positioned(
                    right: 20,
                    bottom: 16,
                    child: Container(
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
                              color: _statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _statusLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
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
                          label: 'Followers', value: '2.4K'),
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
                            ? Colors.grey.shade300
                            : const Color(0xFF1FA4EA),
                        foregroundColor:
                            _following ? Colors.black87 : Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        _following ? 'Following' : 'Follow',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── bio placeholder ──────────────────────────────
                  const Text(
                    'About',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'No bio yet.',
                    style: TextStyle(
                        fontSize: 14, color: Colors.grey.shade600),
                  ),

                  const SizedBox(height: 28),

                  // ── gifts section ─────────────────────────────────
                  const Text(
                    'Gifts',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      'No gifts yet.',
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

