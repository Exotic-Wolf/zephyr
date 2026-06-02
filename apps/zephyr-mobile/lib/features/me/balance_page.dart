import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../models/models.dart';
import '../../services/api_client.dart';
import '../../services/iap_service.dart';
import '../../widgets/coin_icon.dart';

class BalancePage extends StatefulWidget {
  const BalancePage({
    super.key,
    required this.apiClient,
    required this.accessToken,
  });

  final ZephyrApiClient apiClient;
  final String accessToken;

  @override
  State<BalancePage> createState() => _BalancePageState();
}

class _BalancePageState extends State<BalancePage> {
  int _coinBalance = 0;
  List<CoinPack> _coinPacks = <CoinPack>[];
  List<WalletTransaction> _transactions = <WalletTransaction>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _initIap();
  }

  void _initIap() {
    final iap = IapService.instance;
    iap.initialize(
      apiClient: widget.apiClient,
      accessToken: widget.accessToken,
    );
    iap.onPurchaseSuccess = (int coinsAwarded) {
      if (!mounted) return;
      // Refresh wallet and transactions after successful purchase
      _loadData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('+${_formatNumber(coinsAwarded)} coins added!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    };
    iap.onPurchaseError = (String error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), behavior: SnackBarBehavior.floating),
      );
    };
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        widget.apiClient.getWalletSummary(widget.accessToken),
        widget.apiClient.listCoinPacks(),
        widget.apiClient.getTransactionHistory(widget.accessToken),
      ]);
      if (!mounted) return;
      final WalletSummary wallet = results[0] as WalletSummary;
      final List<CoinPack> packs = results[1] as List<CoinPack>;
      final List<WalletTransaction> txns = results[2] as List<WalletTransaction>;
      setState(() {
        _coinBalance = wallet.coinBalance;
        _coinPacks = packs;
        _transactions = txns;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _buyCoins(CoinPack pack) async {
    // Find matching store product
    final iap = IapService.instance;
    final storeProducts = iap.products.value;
    final ProductDetails? product = storeProducts
        .where((p) => p.id == pack.id)
        .firstOrNull;

    if (product != null) {
      // Use real IAP flow
      Navigator.of(context).pop(); // Close bottom sheet
      await iap.buyProduct(product);
    } else {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close bottom sheet

      if (kDebugMode) {
        // Dev-only fallback for local testing without store products.
        try {
          final WalletSummary wallet =
              await widget.apiClient.purchaseCoins(widget.accessToken, pack.id);
          if (!mounted) return;
          setState(() {
            _coinBalance = wallet.coinBalance;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('+${_formatNumber(pack.coins)} coins added! (DEV MODE)'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          widget.apiClient
              .getTransactionHistory(widget.accessToken)
              .then((txns) {
            if (mounted) setState(() => _transactions = txns);
          });
        } catch (error) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Purchase failed: $error')),
          );
        }
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Purchases are temporarily unavailable. Please try again in a moment.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showCoinPackSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CoinPackSheet(
        packs: _coinPacks,
        onBuy: _buyCoins,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Wallet'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: <Widget>[
                  // ── Balance Card ──────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[Color(0xFF1A1A2E), Color(0xFF16213E)],
                      ),
                      border: Border.all(
                        color: const Color(0xFFFFD95A).withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      children: <Widget>[
                        const Text(
                          'Coin Balance',
                          style: TextStyle(color: Colors.white60, fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            const CoinIcon(size: 28),
                            const SizedBox(width: 10),
                            Text(
                              _formatNumber(_coinBalance),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFD95A),
                              foregroundColor: Colors.black87,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.add_rounded, size: 20),
                            label: const Text(
                              'Top Up',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                            ),
                            onPressed: _showCoinPackSheet,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Transaction History ────────────────────────────
                  Row(
                    children: <Widget>[
                      const Text(
                        'Recent Activity',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      const Spacer(),
                      Text(
                        '${_transactions.length} items',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_transactions.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Text(
                          'No transactions yet',
                          style: TextStyle(
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                      ),
                    )
                  else
                    ..._transactions.map((tx) => _TransactionTile(transaction: tx)),
                ],
              ),
            ),
    );
  }

  String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}

// ── Coin Pack Bottom Sheet ──────────────────────────────────────────────────

class _CoinPackSheet extends StatelessWidget {
  const _CoinPackSheet({
    required this.packs,
    required this.onBuy,
  });

  final List<CoinPack> packs;
  final ValueChanged<CoinPack> onBuy;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
        16, 12, 16, MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade600,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Buy Coins',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.5,
            children: packs.map((pack) {
              return GestureDetector(
                onTap: () => onBuy(pack),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFFFD95A).withValues(alpha: 0.4),
                    ),
                    color: const Color(0xFFFFD95A).withValues(alpha: 0.06),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          const CoinIcon(size: 18),
                          const SizedBox(width: 6),
                          Text(
                            pack.label,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD95A),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '\$${pack.priceUsd.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ── Transaction Tile ────────────────────────────────────────────────────────

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.transaction});

  final WalletTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isCredit = transaction.coinsDelta > 0;
    final bool isDebit = transaction.coinsDelta < 0;

    final (IconData icon, String label) = switch (transaction.type) {
      'call_spend' => (Icons.call_rounded, 'Call charge'),
      'call_earning_spark' => (Icons.call_received_rounded, 'Call earning'),
      'gift_spend' => (Icons.card_giftcard_rounded, 'Gift sent'),
      'gift_earning_spark' => (Icons.redeem_rounded, 'Gift received'),
      'purchase' => (Icons.shopping_cart_rounded, 'Coin purchase'),
      'coin_purchase' => (Icons.shopping_cart_rounded, 'Coin purchase'),
      'iap_purchase' => (Icons.shopping_cart_rounded, 'Coin purchase'),
      _ => (Icons.swap_horiz_rounded, transaction.type),
    };

    final String amountText = isCredit
        ? '+${_formatDelta(transaction.coinsDelta)}'
        : _formatDelta(transaction.coinsDelta);

    final Color amountColor = isCredit
        ? const Color(0xFF4CAF50)
        : isDebit
            ? const Color(0xFFEF5350)
            : (isDark ? Colors.white54 : Colors.black54);

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: amountColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: amountColor),
        ),
        title: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        subtitle: Text(
          _formatDate(transaction.createdAt),
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
        ),
        trailing: Text(
          amountText,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: amountColor,
          ),
        ),
      ),
    );
  }

  String _formatDelta(int delta) {
    final int abs = delta.abs();
    if (abs >= 1000) return '${(abs / 1000).toStringAsFixed(1)}K';
    return abs.toString();
  }

  String _formatDate(String iso) {
    try {
      final DateTime dt = DateTime.parse(iso);
      final DateTime now = DateTime.now();
      final Duration diff = now.difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return '';
    }
  }
}
