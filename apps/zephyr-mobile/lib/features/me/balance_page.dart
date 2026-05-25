import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/models.dart';
import '../../services/api_client.dart';
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
  String? _purchasingPackId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        widget.apiClient.getWalletSummary(widget.accessToken),
        widget.apiClient.listCoinPacks(),
      ]);
      if (!mounted) return;
      final WalletSummary wallet = results[0] as WalletSummary;
      final List<CoinPack> packs = results[1] as List<CoinPack>;
      setState(() {
        _coinBalance = wallet.coinBalance;
        _coinPacks = packs;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatUsd(double value) => '\$${value.toStringAsFixed(2)}';

  Future<void> _buyCoins(CoinPack pack) async {
    setState(() => _purchasingPackId = pack.id);

    try {
      final WalletSummary wallet =
          await widget.apiClient.purchaseCoins(widget.accessToken, pack.id);

      if (!mounted) return;

      setState(() {
        _coinBalance = wallet.coinBalance;
        _purchasingPackId = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added ${pack.coins} coins via ${pack.label}.')),
      );
    } catch (error) {
      if (!mounted) return;

      setState(() => _purchasingPackId = null);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Purchase failed: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.myBalance)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    l10n.coinBalance,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.coinsAmount(_coinBalance),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.buyCoins,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ..._coinPacks.map((CoinPack pack) {
            final bool isPurchasing = _purchasingPackId == pack.id;

            return ListTile(
              leading: const CoinIcon(size: 28),
              title: Text(l10n.coinPackLabel(pack.coins, pack.label)),
              subtitle: Text(_formatUsd(pack.priceUsd)),
              trailing: ElevatedButton(
                onPressed: isPurchasing ? null : () => _buyCoins(pack),
                child: Text(isPurchasing ? l10n.buying : l10n.buy),
              ),
            );
          }),
        ],
      ),
    );
  }
}
