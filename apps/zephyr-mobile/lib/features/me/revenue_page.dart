import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../services/api_client.dart';

class RevenuePage extends StatefulWidget {
  const RevenuePage({
    super.key,
    required this.apiClient,
    required this.accessToken,
  });

  final ZephyrApiClient apiClient;
  final String accessToken;

  @override
  State<RevenuePage> createState() => _RevenuePageState();
}

class _RevenuePageState extends State<RevenuePage> {
  double? _revenueUsd;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final wallet = await widget.apiClient.getWalletSummary(widget.accessToken);
      if (mounted) setState(() => _revenueUsd = wallet.revenueUsd);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.myRevenue)),
      body: _revenueUsd == null
          ? const Center(child: CircularProgressIndicator())
          : Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.account_balance_wallet_rounded, size: 56),
              const SizedBox(height: 12),
              Text(
                '\$${_revenueUsd!.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context)!.revenueFromGiftsAndCalls,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
