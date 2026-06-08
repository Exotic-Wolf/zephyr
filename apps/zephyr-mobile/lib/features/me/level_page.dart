import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/models.dart';
import '../../services/api_client.dart';
import '../../widgets/coin_icon.dart';
import '../../widgets/spark_icon.dart';

class LevelPage extends StatefulWidget {
  const LevelPage({
    super.key,
    required this.apiClient,
    required this.accessToken,
  });

  final ZephyrApiClient apiClient;
  final String accessToken;

  @override
  State<LevelPage> createState() => _LevelPageState();
}

class _LevelPageState extends State<LevelPage> {
  WalletSummary? _wallet;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final wallet = await widget.apiClient.getWalletSummary(
        widget.accessToken,
      );
      if (!mounted) return;
      setState(() {
        _wallet = wallet;
        _loading = false;
        _failed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.level)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _failed || _wallet == null
          ? Center(
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _failed = false;
                  });
                  _load();
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                children: <Widget>[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: <Widget>[
                          const Icon(Icons.military_tech_rounded, size: 56),
                          const SizedBox(height: 12),
                          Text(
                            AppLocalizations.of(
                              context,
                            )!.levelValue(_wallet!.level),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            AppLocalizations.of(
                              context,
                            )!.keepStreamingToLevelUp,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Column(
                      children: <Widget>[
                        _LevelMetricTile(
                          icon: const SparkIcon(size: 22),
                          label: 'Spark balance',
                          value: _formatNumber(_wallet!.sparkBalance),
                        ),
                        const Divider(height: 1),
                        _LevelMetricTile(
                          icon: const CoinIcon(size: 22),
                          label: 'Coin balance',
                          value: _formatNumber(_wallet!.coinBalance),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  String _formatNumber(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value.toString();
  }
}

class _LevelMetricTile extends StatelessWidget {
  const _LevelMetricTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final Widget icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: icon,
      title: Text(label),
      trailing: Text(
        value,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
  }
}
