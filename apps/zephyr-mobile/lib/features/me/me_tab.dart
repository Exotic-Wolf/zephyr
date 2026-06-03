import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/models.dart';
import '../../services/api_client.dart';
import 'call_price_page.dart';
import '../profile/my_profile_page.dart';
import 'balance_page.dart';
import 'level_page.dart';
import 'revenue_page.dart';
import 'settings_page.dart';

class MeTab extends StatelessWidget {
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
  final VoidCallback onLogout;
  final Future<void> Function() onDeleteAccount;
  final Locale? locale;
  final ValueChanged<Locale?> onLocaleChanged;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final ValueChanged<UserProfile> onProfileUpdated;

  Future<void> _openMyProfilePage(BuildContext context) async {
    final UserProfile? updated = await Navigator.of(context).push(
      MaterialPageRoute<UserProfile>(
        builder: (_) => MyProfilePage(
          me: me,
          apiClient: apiClient,
          accessToken: accessToken,
          onLogout: onLogout,
        ),
      ),
    );
    if (updated != null) {
      onProfileUpdated(updated);
    }
  }

  Future<void> _openCallPricePage(BuildContext context) async {
    final UserProfile? updated = await Navigator.of(context).push(
      MaterialPageRoute<UserProfile>(
        builder: (_) => CallPricePage(
          apiClient: apiClient,
          accessToken: accessToken,
          me: me,
        ),
      ),
    );
    if (updated != null) {
      onProfileUpdated(updated);
    }
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
              backgroundImage: me?.avatarUrl != null
                  ? CachedNetworkImageProvider(me!.avatarUrl!)
                  : null,
              child: me?.avatarUrl == null
                  ? const Icon(Icons.person_rounded)
                  : null,
            ),
            title: Row(
              children: <Widget>[
                Text(me?.displayName ?? l10n.me),
                if (me?.isAdmin == true) ...<Widget>[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
        Card(
          child: Column(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.military_tech_rounded),
                title: Text(l10n.level),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => LevelPage(
                        apiClient: apiClient,
                        accessToken: accessToken,
                      ),
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.account_balance_wallet_rounded),
                title: Text(l10n.myBalance),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => BalancePage(
                        apiClient: apiClient,
                        accessToken: accessToken,
                      ),
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.payments_rounded),
                title: Text(l10n.myRevenue),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => RevenuePage(
                        apiClient: apiClient,
                        accessToken: accessToken,
                      ),
                    ),
                  );
                },
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
                        onLogout: onLogout,
                        onDeleteAccount: onDeleteAccount,
                        locale: locale,
                        onLocaleChanged: onLocaleChanged,
                        themeMode: themeMode,
                        onThemeModeChanged: onThemeModeChanged,
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
