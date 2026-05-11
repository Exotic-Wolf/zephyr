import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/api_client.dart';
import '../widgets/coin_icon.dart';
import '../widgets/spark_icon.dart';
import '../widgets/hero_bullet.dart';

// ── CallPricePage ────────────────────────────────────────────────────────────

class _CallTier {
  const _CallTier({
    required this.label,
    required this.sparkPerMin,
    required this.coinsPerMin,
    required this.minLevel,
  });
  final String label;
  final int sparkPerMin;
  final int coinsPerMin;
  final int minLevel;
}

const List<_CallTier> _kCallTiers = <_CallTier>[
  _CallTier(label: '≤Lv3',  sparkPerMin:  1260,  coinsPerMin:  2100,  minLevel: 1),
  _CallTier(label: 'Lv4',   sparkPerMin:  1920,  coinsPerMin:  3200,  minLevel: 4),
  _CallTier(label: 'Lv5',   sparkPerMin:  2520,  coinsPerMin:  4200,  minLevel: 5),
  _CallTier(label: 'Lv6',   sparkPerMin:  3240,  coinsPerMin:  5400,  minLevel: 6),
  _CallTier(label: 'Lv7',   sparkPerMin:  3840,  coinsPerMin:  6400,  minLevel: 7),
  _CallTier(label: 'Lv8',   sparkPerMin:  4800,  coinsPerMin:  8000,  minLevel: 8),
  _CallTier(label: 'Lv9+',  sparkPerMin: 16200,  coinsPerMin: 27000,  minLevel: 9),
];

class CallPricePage extends StatefulWidget {
  const CallPricePage({
    super.key,
    required this.userLevel,
    required this.apiClient,
    required this.accessToken,
    this.me,
  });

  final int userLevel;
  final ZephyrApiClient apiClient;
  final String accessToken;
  final UserProfile? me;

  @override
  State<CallPricePage> createState() => _CallPricePageState();
}

class _CallPricePageState extends State<CallPricePage> {
  // default to highest tier the user qualifies for
  late int _selectedCoins = _kCallTiers
      .lastWhere(
        (t) => t.minLevel <= widget.userLevel,
        orElse: () => _kCallTiers.first,
      )
      .coinsPerMin;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Pre-populate from saved rate if it matches a valid tier
    final int? saved = widget.me?.callRateCoinsPerMinute;
    if (saved != null &&
        _kCallTiers.any((t) => t.coinsPerMin == saved && t.minLevel <= widget.userLevel)) {
      _selectedCoins = saved;
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final UserProfile updated = await widget.apiClient.updateMe(
        widget.accessToken,
        callRateCoinsPerMinute: _selectedCoins,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('Call rate saved'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ));
      Navigator.of(context).pop(updated);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('Failed to save: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Call Price'),
        actions: <Widget>[
          if (_saving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _save,
              child: const Text('Save',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      backgroundColor: const Color(0xFFF2F2F7),
      body: Column(
        children: <Widget>[
          // ── Spark hero — 1/4 screen ───────────────────────────
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.32,
            child: Container(
              width: double.infinity,
              color: Colors.white,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  SizedBox(
                    width: 200,
                    height: 120,
                    child: Stack(
                      alignment: Alignment.center,
                      children: <Widget>[
                        // rays + sparkles layer behind flame
                        Positioned.fill(
                          child: CustomPaint(painter: FlameGloryPainter()),
                        ),
                        // flame centered
                        SizedBox(
                          width: 70,
                          height: 90,
                          child: CustomPaint(painter: ClassicFlamePainter()),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Spark',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFE53935),
                      letterSpacing: 2.0,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: <Widget>[
                        HeroBullet(
                          iconWidget: const SparkIcon(size: 16),
                          text: 'You earn Sparks every second you\'re on a call',
                        ),
                        const SizedBox(height: 6),
                        HeroBullet(
                          iconWidget: const Icon(Icons.trending_up_rounded, size: 16, color: Color(0xFFE53935)),
                          text: 'Fair pricing gets you more calls, faster',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── rest of the page ──────────────────────────────────
          Expanded(
            child: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          // ── caller preview banner ─────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1FA4EA).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: const Color(0xFF1FA4EA).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: <Widget>[
                const Icon(Icons.info_outline_rounded,
                    color: Color(0xFF1FA4EA), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 3,
                    children: <Widget>[
                      const Text('Callers will see:',
                          style: TextStyle(fontSize: 13, color: Colors.black87)),
                      Text('Video call  $_selectedCoins',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87)),
                      const CoinIcon(size: 14),
                      const Text('/min',
                          style: TextStyle(fontSize: 13, color: Colors.black87)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          const Text('Choose your rate',
              style:
                  TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            'Your level is ${widget.userLevel}. Higher tiers unlock at higher levels.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),

          // ── tier table ────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: <Widget>[
                // header row
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  child: Row(
                    children: <Widget>[
                      const Expanded(
                          flex: 3,
                          child: Text('Tier',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey))),
                      const Expanded(
                          flex: 3,
                          child: Text('You earn',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey))),
                      const Expanded(
                          flex: 3,
                          child: Text('Caller pays',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey))),
                      const SizedBox(width: 32),
                    ],
                  ),
                ),
                const Divider(height: 1),
                ..._kCallTiers.map((_CallTier tier) {
                  final bool unlocked =
                      widget.userLevel >= tier.minLevel;
                  final bool selected =
                      _selectedCoins == tier.coinsPerMin;
                  return Column(
                    children: <Widget>[
                      InkWell(
                        onTap: unlocked
                            ? () {
                                setState(() => _selectedCoins = tier.coinsPerMin);
                              }
                            : null,
                        child: Container(
                          color: selected
                              ? const Color(0xFF1FA4EA)
                                  .withValues(alpha: 0.08)
                              : null,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                flex: 3,
                                child: Text(
                                  tier.label,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: unlocked
                                        ? Colors.black87
                                        : Colors.grey.shade400,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Row(
                                  children: <Widget>[
                                    Text(
                                      '${tier.sparkPerMin}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: unlocked
                                            ? const Color(0xFF00A651)
                                            : Colors.grey.shade400,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 3),
                                    unlocked
                                        ? Padding(
                                            padding: const EdgeInsets.only(bottom: 4),
                                            child: const SparkIcon(size: 18),
                                          )
                                        : const SizedBox.shrink(),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Row(
                                  children: <Widget>[
                                    Text(
                                      '${tier.coinsPerMin}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: unlocked
                                            ? Colors.black87
                                            : Colors.grey.shade400,
                                      ),
                                    ),
                                    const SizedBox(width: 3),
                                    unlocked
                                        ? const CoinIcon(size: 13)
                                        : const SizedBox.shrink(),
                                  ],
                                ),
                              ),
                              SizedBox(
                                width: 32,
                                child: unlocked
                                    ? (selected
                                        ? const Icon(
                                            Icons.check_circle_rounded,
                                            color: Color(0xFF1FA4EA),
                                            size: 20)
                                        : null)
                                    : Icon(Icons.lock_outline_rounded,
                                        size: 16,
                                        color: Colors.grey.shade400),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (tier != _kCallTiers.last)
                        const Divider(height: 1),
                    ],
                  );
                }),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── level unlock note ─────────────────────────────────
          Text(
            '🔒 Locked tiers unlock as you level up by being active on Zephyr.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),

          const SizedBox(height: 8),
        ],
            ),
          ),
        ],
      ),
    );
  }
}

