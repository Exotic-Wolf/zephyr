import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/api_client.dart';
import '../../widgets/coin_icon.dart';
import '../../widgets/spark_icon.dart';
import '../../widgets/hero_bullet.dart';
import '../../l10n/app_localizations.dart';

// ── CallPricePage ────────────────────────────────────────────────────────────

class CallPricePage extends StatefulWidget {
  const CallPricePage({
    super.key,
    required this.apiClient,
    required this.accessToken,
    this.me,
  });

  final ZephyrApiClient apiClient;
  final String accessToken;
  final UserProfile? me;

  @override
  State<CallPricePage> createState() => _CallPricePageState();
}

class _CallPricePageState extends State<CallPricePage> {
  int _userLevel = 1;
  int? _selectedCoins;
  bool _loading = true;
  bool _saving = false;
  List<CallRateTier> _tiers = <CallRateTier>[];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait(<Future<dynamic>>[
        widget.apiClient.getWalletSummary(widget.accessToken),
        widget.apiClient.getCallRateTiers(),
      ]);
      final wallet = results[0] as WalletSummary;
      final tiers = results[1] as List<CallRateTier>;
      if (!mounted) return;
      setState(() {
        _tiers = tiers;
        _userLevel = wallet.level;
        final int? saved = widget.me?.callRateCoinsPerMinute;
        if (saved != null &&
            _tiers.any((t) => t.coinsPerMinute == saved && t.minLevel <= _userLevel)) {
          _selectedCoins = saved;
        } else {
          _selectedCoins = _tiers
              .lastWhere(
                (t) => t.minLevel <= _userLevel,
                orElse: () => _tiers.first,
              )
              .coinsPerMinute;
        }
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _selectedCoins = _tiers.isNotEmpty ? _tiers.first.coinsPerMinute : 2100;
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final UserProfile updated = await widget.apiClient.updateMe(
        widget.accessToken,
        callRateCoinsPerMinute: _selectedCoins!,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context)!.callRateSaved),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ));
      Navigator.of(context).pop(updated);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context)!.failedToSaveRate(e.toString())),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(AppLocalizations.of(context)!.myCallPrice)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final int selectedCoins = _selectedCoins!;
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.myCallPrice),
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
              child: Text(AppLocalizations.of(context)!.save,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      backgroundColor: isDark ? null : const Color(0xFFF2F2F7),
      body: Column(
        children: <Widget>[
          // ── Spark hero — 1/4 screen ───────────────────────────
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.32,
            child: Container(
              width: double.infinity,
              color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
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
                          text: AppLocalizations.of(context)!.youEarnSparks,
                        ),
                        const SizedBox(height: 6),
                        HeroBullet(
                          iconWidget: const Icon(Icons.trending_up_rounded, size: 16, color: Color(0xFFE53935)),
                          text: AppLocalizations.of(context)!.fairPricingGetsMoreCalls,
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
              color: const Color(0xFFFF8F00).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: const Color(0xFFFF8F00).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: <Widget>[
                const Icon(Icons.info_outline_rounded,
                    color: Color(0xFFFF8F00), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 3,
                    children: <Widget>[
                      Text(AppLocalizations.of(context)!.callersWillSee,
                          style: const TextStyle(fontSize: 13)),
                      Text('${AppLocalizations.of(context)!.videoCall}  $selectedCoins',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                      const CoinIcon(size: 14),
                      Text(AppLocalizations.of(context)!.perMinute,
                          style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          Text(AppLocalizations.of(context)!.chooseYourRate,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            AppLocalizations.of(context)!.yourLevelIs(_userLevel),
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),

          // ── tier table ────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
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
                      Expanded(
                          flex: 3,
                          child: Text(AppLocalizations.of(context)!.tier,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey))),
                      Expanded(
                          flex: 3,
                          child: Text(AppLocalizations.of(context)!.youEarn,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey))),
                      Expanded(
                          flex: 3,
                          child: Text(AppLocalizations.of(context)!.callerPays,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey))),
                      const SizedBox(width: 32),
                    ],
                  ),
                ),
                const Divider(height: 1),
                ..._tiers.map((CallRateTier tier) {
                  final bool unlocked =
                      _userLevel >= tier.minLevel;
                  final bool selected =
                      selectedCoins == tier.coinsPerMinute;
                  return Column(
                    children: <Widget>[
                      InkWell(
                        onTap: unlocked
                            ? () {
                                setState(() => _selectedCoins = tier.coinsPerMinute);
                              }
                            : null,
                        child: Container(
                          color: selected
                              ? const Color(0xFFFF8F00)
                                  .withValues(alpha: 0.12)
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
                                        ? (isDark ? Colors.white : Colors.black87)
                                        : Colors.grey.shade400,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Row(
                                  children: <Widget>[
                                    Text(
                                      '${tier.sparkPerMinute}',
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
                                      '${tier.coinsPerMinute}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: unlocked
                                            ? (isDark ? Colors.white70 : Colors.black87)
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
                                            color: Color(0xFFFF8F00),
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
                      if (tier != _tiers.last)
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
            AppLocalizations.of(context)!.lockedTiersUnlock,
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

