import 'dart:async';

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
    unawaited(
      iap.initialize(
        apiClient: widget.apiClient,
        accessToken: widget.accessToken,
      ),
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
      final List<WalletTransaction> txns =
          results[2] as List<WalletTransaction>;
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
    final iap = IapService.instance;
    final IapCatalogState catalog = iap.catalog.value;
    final ProductDetails? product = catalog.productFor(pack.id);

    if (product != null) {
      // Use real IAP flow
      Navigator.of(context).pop(); // Close bottom sheet
      await iap.buyProduct(product);
    } else {
      if (!mounted) return;

      debugPrint(
        '[IAP] Store product unavailable for ${pack.id}; '
        'loaded=${catalog.products.map((p) => p.id).join(',')}; '
        'notFound=${catalog.notFoundIds.join(',')}',
      );

      if (kDebugMode) {
        // Dev-only fallback for local testing without store products.
        Navigator.of(context).pop(); // Close bottom sheet
        try {
          final WalletSummary wallet = await widget.apiClient.purchaseCoins(
            widget.accessToken,
            pack.id,
          );
          if (!mounted) return;
          setState(() {
            _coinBalance = wallet.coinBalance;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '+${_formatNumber(pack.coins)} coins added! (DEV MODE)',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
          widget.apiClient.getTransactionHistory(widget.accessToken).then((
            txns,
          ) {
            if (mounted) setState(() => _transactions = txns);
          });
        } catch (error) {
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Purchase failed: $error')));
        }
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_storeProductUnavailableMessage(catalog, pack)),
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
      builder: (_) => ValueListenableBuilder<IapCatalogState>(
        valueListenable: IapService.instance.catalog,
        builder: (context, catalog, _) => _CoinPackSheet(
          packs: _coinPacks,
          catalog: catalog,
          onBuy: _buyCoins,
          onRetry: () => unawaited(IapService.instance.reloadProducts()),
        ),
      ),
    );
  }

  String _storeProductUnavailableMessage(
    IapCatalogState catalog,
    CoinPack pack,
  ) {
    if (catalog.loading) {
      return 'Store products are still loading. Please try again in a moment.';
    }
    if (!catalog.storeAvailable) {
      return 'Google Play Billing is not available on this device.';
    }
    if (catalog.error != null) {
      return 'Store catalog could not load. Please retry.';
    }
    if (catalog.notFoundIds.contains(pack.id)) {
      return '${pack.label} is not active in the store yet.';
    }
    return 'This coin pack is not available in the store yet.';
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('My Wallet'), centerTitle: true),
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
                    padding: const EdgeInsets.symmetric(
                      vertical: 28,
                      horizontal: 24,
                    ),
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
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
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
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
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
                    ..._transactions.map(
                      (tx) => _TransactionTile(transaction: tx),
                    ),
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
    required this.catalog,
    required this.onBuy,
    required this.onRetry,
  });

  final List<CoinPack> packs;
  final IapCatalogState catalog;
  final ValueChanged<CoinPack> onBuy;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final double maxHeight = MediaQuery.sizeOf(context).height * 0.85;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
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
              const SizedBox(height: 12),
              _CatalogStatusBanner(catalog: catalog, onRetry: onRetry),
              if (packs.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Text(
                    'No coin packs available',
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                )
              else
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.42,
                  children: packs.map((pack) {
                    final ProductDetails? product = catalog.productFor(pack.id);
                    final bool available =
                        product != null &&
                        catalog.storeAvailable &&
                        !catalog.loading;
                    final Color accent = available
                        ? const Color(0xFFFFD95A)
                        : Theme.of(context).disabledColor;
                    final String priceLabel =
                        product?.price ??
                        (catalog.loading ? 'Loading' : 'Store pending');

                    return Opacity(
                      opacity: available ? 1 : 0.58,
                      child: GestureDetector(
                        onTap: available ? () => onBuy(pack) : null,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: accent.withValues(alpha: 0.4),
                            ),
                            color: accent.withValues(alpha: 0.06),
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
                                  Flexible(
                                    child: Text(
                                      pack.label,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: available
                                      ? const Color(0xFFFFD95A)
                                      : Theme.of(
                                          context,
                                        ).colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  priceLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: available
                                        ? Colors.black87
                                        : Theme.of(context).disabledColor,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CatalogStatusBanner extends StatelessWidget {
  const _CatalogStatusBanner({required this.catalog, required this.onRetry});

  final IapCatalogState catalog;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final String? message = _message;
    if (message == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  catalog.loading
                      ? Icons.sync_rounded
                      : Icons.info_outline_rounded,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (!catalog.loading)
                  TextButton(
                    onPressed: onRetry,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text('Retry'),
                  ),
              ],
            ),
            if (catalog.loading) ...<Widget>[
              const SizedBox(height: 10),
              const LinearProgressIndicator(minHeight: 3),
            ],
          ],
        ),
      ),
    );
  }

  String? get _message {
    if (catalog.loading) {
      return 'Loading store products...';
    }
    if (!catalog.storeAvailable) {
      return 'Google Play Billing is not available on this device.';
    }
    if (catalog.error != null) {
      return 'Store catalog could not load. Please retry.';
    }
    if (catalog.products.isEmpty) {
      return 'No active store products yet. Publish pack_299 in Play Console.';
    }
    if (catalog.notFoundIds.isNotEmpty) {
      return '${catalog.notFoundIds.length} coin packs are not active in the store yet.';
    }
    return null;
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
        title: Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
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
