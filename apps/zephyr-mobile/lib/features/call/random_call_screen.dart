import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../services/api_client.dart';
import '../../services/firebase_chat_service.dart';
import 'direct_call_screen.dart';

/// Random Call — matchmaking layer that inherits from the Call feature.
///
/// Flow: seek match → if instant match, start call → if no match, listen RTDB
/// → on match notification, start call → on "Next", seek again → loop.
class RandomCallScreen extends StatefulWidget {
  const RandomCallScreen({
    super.key,
    required this.apiClient,
    required this.accessToken,
    required this.userId,
  });

  final ZephyrApiClient apiClient;
  final String accessToken;
  final String userId;

  @override
  State<RandomCallScreen> createState() => _RandomCallScreenState();
}

class _RandomCallScreenState extends State<RandomCallScreen>
    with SingleTickerProviderStateMixin {
  bool _searching = false;
  int _rateCoinsPerMinute = 600;
  StreamSubscription<dynamic>? _callSignalSub;
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _start();
  }

  Future<void> _start() async {
    await [Permission.camera, Permission.microphone].request();
    _loadRandomRate();
    _listenForAsyncMatch();
    _seek();
  }

  Future<void> _loadRandomRate() async {
    try {
      final quote = await widget.apiClient.getPrivateCallQuote(
        minutes: 1,
        mode: 'random',
      );
      if (!mounted) return;
      setState(() => _rateCoinsPerMinute = quote.rateCoinsPerMinute);
    } catch (_) {
      // Keep the backend default fallback for offline/prewarm states.
    }
  }

  // ── Matchmaking ─────────────────────────────────────────────────────────────

  Future<void> _seek() async {
    if (!mounted) return;
    setState(() => _searching = true);

    try {
      final result = await widget.apiClient.seekRandomCall(widget.accessToken);
      if (!mounted) return;

      if (result['matched'] == true) {
        _openCall(result);
      }
      // If not matched, we wait for RTDB notification (_listenForAsyncMatch)
    } catch (e) {
      if (!mounted) return;
      debugPrint('[RandomCall] seek error: $e');
      // Show error and let user retry or go back
      setState(() => _searching = false);
    }
  }

  /// Listen to RTDB for async match (when no instant match was available).
  void _listenForAsyncMatch() {
    _callSignalSub?.cancel();
    _callSignalSub = FirebaseChatService.instance.listenCallSignal(
      widget.userId,
      (Map<String, dynamic>? data) {
        if (!mounted || data == null) return;
        if (data['event'] == 'matched') {
          _openCall(data);
        }
      },
    );
  }

  /// Push DirectCallScreen in random mode.
  Future<void> _openCall(Map<String, dynamic> match) async {
    if (!mounted) return;
    setState(() => _searching = false);

    // Clear the RTDB signal node so it doesn't re-trigger
    FirebaseChatService.instance.removeCallSignal(widget.userId);

    final result = await Navigator.of(context).push<Map<String, String>>(
      MaterialPageRoute(
        builder: (_) => DirectCallScreen(
          apiClient: widget.apiClient,
          accessToken: widget.accessToken,
          sessionId: match['sessionId'] as String,
          appId: match['appId'] as String,
          channelName: match['channelName'] as String,
          uid: match['uid'] as int,
          token: match['token'] as String,
          partnerId: match['partnerId'] as String,
          partnerName: (match['partnerName'] as String?) ?? 'User',
          myUserId: widget.userId,
          mode: 'random',
        ),
      ),
    );

    if (!mounted) return;

    // Handle the result from DirectCallScreen
    final action = result?['action'];
    if (action == 'next') {
      // User pressed Next — end old session + seek new match
      final sessionId = result!['sessionId']!;
      final partnerId = result['partnerId']!;
      setState(() => _searching = true);
      try {
        final nextResult = await widget.apiClient.nextRandomCall(
          widget.accessToken,
          sessionId: sessionId,
          partnerId: partnerId,
        );
        if (!mounted) return;
        if (nextResult['matched'] == true) {
          _openCall(nextResult);
        }
        // else: waiting for RTDB async match
      } catch (e) {
        debugPrint('[RandomCall] next error: $e');
        _seek(); // retry
      }
    } else if (action == 'partner_left') {
      // Partner left — auto-seek again
      _seek();
    } else {
      // User ended or popped — exit random call flow
      if (mounted) Navigator.of(context).pop();
    }
  }

  void _cancel() {
    widget.apiClient.cancelSeekRandomCall(widget.accessToken).ignore();
    _callSignalSub?.cancel();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _callSignalSub?.cancel();
    super.dispose();
  }

  // ── UI ──────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: _cancel,
              ),
            ),
            const Spacer(),
            // Pulsing ring animation
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, __) {
                final double scale = 1.0 + _pulseCtrl.value * 0.15;
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.06),
                      border: Border.all(
                        color: const Color(0xFF1FA4EA).withValues(alpha: 0.5),
                        width: 2,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.videocam_rounded,
                        color: Color(0xFF1FA4EA),
                        size: 48,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
            Text(
              _searching ? 'Finding someone to chat with…' : 'Preparing…',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$_rateCoinsPerMinute coins / min when connected',
              style: const TextStyle(color: Colors.white38, fontSize: 13),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white24),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _cancel,
                  child: const Text('Cancel'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
