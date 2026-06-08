import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/models.dart';
import '../../services/api_client.dart';
import '../../widgets/coin_icon.dart';
import '../../widgets/spark_icon.dart';
import 'call_price_page.dart';
import '../profile/my_profile_page.dart';
import 'balance_page.dart';
import 'level_page.dart';
import 'revenue_page.dart';
import 'settings_page.dart';

class MeTab extends StatefulWidget {
  const MeTab({
    super.key,
    required this.me,
    required this.apiClient,
    required this.accessToken,
    required this.onLogout,
    required this.onDeleteAccount,
    required this.locale,
    required this.onLocaleChanged,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.onProfileUpdated,
  });

  final UserProfile? me;
  final ZephyrApiClient apiClient;
  final String accessToken;
  final Future<void> Function() onLogout;
  final Future<void> Function() onDeleteAccount;
  final Locale? locale;
  final ValueChanged<Locale?> onLocaleChanged;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ValueChanged<UserProfile> onProfileUpdated;

  @override
  State<MeTab> createState() => _MeTabState();
}

class _MeTabState extends State<MeTab> {
  WalletSummary? _wallet;
  bool _walletLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWallet();
  }

  @override
  void didUpdateWidget(covariant MeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accessToken != widget.accessToken) {
      _loadWallet();
    }
  }

  Future<void> _loadWallet() async {
    setState(() => _walletLoading = true);
    try {
      final wallet = await widget.apiClient.getWalletSummary(
        widget.accessToken,
      );
      if (!mounted) return;
      setState(() {
        _wallet = wallet;
        _walletLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _walletLoading = false);
    }
  }

  String _formatCount(num value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}K';
    return value is int ? value.toString() : value.toStringAsFixed(2);
  }

  Future<void> _openMyProfilePage(BuildContext context) async {
    final UserProfile? updated = await Navigator.of(context).push(
      MaterialPageRoute<UserProfile>(
        builder: (_) => MyProfilePage(
          me: widget.me,
          apiClient: widget.apiClient,
          accessToken: widget.accessToken,
          onLogout: widget.onLogout,
        ),
      ),
    );
    if (updated != null) {
      widget.onProfileUpdated(updated);
    }
  }

  Future<void> _openCallPricePage(BuildContext context) async {
    final UserProfile? updated = await Navigator.of(context).push(
      MaterialPageRoute<UserProfile>(
        builder: (_) => CallPricePage(
          apiClient: widget.apiClient,
          accessToken: widget.accessToken,
          me: widget.me,
        ),
      ),
    );
    if (updated != null) {
      widget.onProfileUpdated(updated);
    }
  }

  Future<void> _openBalancePage(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BalancePage(
          apiClient: widget.apiClient,
          accessToken: widget.accessToken,
        ),
      ),
    );
    if (mounted) await _loadWallet();
  }

  Future<void> _openRevenuePage(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RevenuePage(
          apiClient: widget.apiClient,
          accessToken: widget.accessToken,
        ),
      ),
    );
    if (mounted) await _loadWallet();
  }

  Future<void> _openLevelPage(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LevelPage(
          apiClient: widget.apiClient,
          accessToken: widget.accessToken,
        ),
      ),
    );
    if (mounted) await _loadWallet();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundImage: widget.me?.avatarUrl != null
                  ? CachedNetworkImageProvider(widget.me!.avatarUrl!)
                  : null,
              child: widget.me?.avatarUrl == null
                  ? const Icon(Icons.person_rounded)
                  : null,
            ),
            title: Row(
              children: <Widget>[
                Text(widget.me?.displayName ?? l10n.me),
                if (widget.me?.isAdmin == true) ...<Widget>[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: <Color>[Color(0xFFFFD700), Color(0xFFFF8C00)],
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      l10n.owner,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _openMyProfilePage(context),
          ),
        ),
        const SizedBox(height: 12),
        _MeOverviewCard(
          loading: _walletLoading,
          wallet: _wallet,
          callRateCoinsPerMinute: widget.me?.callRateCoinsPerMinute,
          formatCount: _formatCount,
          onWalletTap: () => _openBalancePage(context),
          onRevenueTap: () => _openRevenuePage(context),
          onLevelTap: () => _openLevelPage(context),
          onRateTap: () => _openCallPricePage(context),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.military_tech_rounded),
                title: Text(l10n.level),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _openLevelPage(context),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.account_balance_wallet_rounded),
                title: Text(l10n.myBalance),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _openBalancePage(context),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.payments_rounded),
                title: Text(l10n.myRevenue),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _openRevenuePage(context),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.call_rounded),
                title: Text(l10n.myCallPrice),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => _openCallPricePage(context),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.settings_rounded),
                title: Text(l10n.settings),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => SettingsPage(
                        onLogout: widget.onLogout,
                        onDeleteAccount: widget.onDeleteAccount,
                        locale: widget.locale,
                        onLocaleChanged: widget.onLocaleChanged,
                        themeMode: widget.themeMode,
                        onThemeModeChanged: widget.onThemeModeChanged,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MeOverviewCard extends StatelessWidget {
  const _MeOverviewCard({
    required this.loading,
    required this.wallet,
    required this.callRateCoinsPerMinute,
    required this.formatCount,
    required this.onWalletTap,
    required this.onRevenueTap,
    required this.onLevelTap,
    required this.onRateTap,
  });

  final bool loading;
  final WalletSummary? wallet;
  final int? callRateCoinsPerMinute;
  final String Function(num value) formatCount;
  final VoidCallback onWalletTap;
  final VoidCallback onRevenueTap;
  final VoidCallback onLevelTap;
  final VoidCallback onRateTap;

  @override
  Widget build(BuildContext context) {
    final wallet = this.wallet;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: loading
            ? const SizedBox(
                height: 84,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            : GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.45,
                children: <Widget>[
                  _MetricTile(
                    icon: const CoinIcon(size: 17),
                    label: 'Coins',
                    value: formatCount(wallet?.coinBalance ?? 0),
                    onTap: onWalletTap,
                  ),
                  _MetricTile(
                    icon: const SparkIcon(size: 17),
                    label: 'Sparks',
                    value: formatCount(wallet?.sparkBalance ?? 0),
                    onTap: onLevelTap,
                  ),
                  _MetricTile(
                    icon: const Icon(Icons.payments_rounded, size: 17),
                    label: 'Revenue',
                    value: '\$${(wallet?.revenueUsd ?? 0).toStringAsFixed(2)}',
                    onTap: onRevenueTap,
                  ),
                  _MetricTile(
                    icon: const Icon(Icons.call_rounded, size: 17),
                    label: 'Call price',
                    value: callRateCoinsPerMinute == null
                        ? 'Set now'
                        : '${formatCount(callRateCoinsPerMinute!)} /min',
                    onTap: onRateTap,
                  ),
                ],
              ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final Widget icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF4F4F7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: <Widget>[
            icon,
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
