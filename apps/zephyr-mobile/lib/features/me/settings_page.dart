import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app_constants.dart';
import '../../l10n/app_localizations.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.onLogout,
    required this.onDeleteAccount,
    required this.locale,
    required this.onLocaleChanged,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  final Future<void> Function() onLogout;
  final Future<void> Function() onDeleteAccount;
  final Locale? locale;
  final ValueChanged<Locale?> onLocaleChanged;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late ThemeMode _themeMode = widget.themeMode;
  late Locale? _locale = widget.locale;
  bool _deletingAccount = false;

  void _handleThemeChanged(ThemeMode mode) {
    setState(() => _themeMode = mode);
    widget.onThemeModeChanged(mode);
  }

  void _handleLocaleChanged(Locale? locale) {
    setState(() => _locale = locale);
    widget.onLocaleChanged(locale);
  }

  Future<void> _handleDeleteAccount() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'This permanently deletes your account, chats, live data, and wallet history. This cannot be undone.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(ctx)!.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete Forever',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _deletingAccount = true);
    try {
      await widget.onDeleteAccount();
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      debugPrint('Delete account UI error: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Delete account failed: $error')));
      setState(() => _deletingAccount = false);
    }
  }

  Future<void> _handleLogout() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(ctx)!.logout),
        content: Text(AppLocalizations.of(ctx)!.logoutConfirm),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(ctx)!.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              AppLocalizations.of(ctx)!.logout,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    await widget.onLogout();
  }

  void _openAccount() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _AccountPage(
          deletingAccount: _deletingAccount,
          onLogout: _handleLogout,
          onDeleteAccount: _handleDeleteAccount,
        ),
      ),
    );
  }

  void _openPrivacy() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const _PrivacyPage()));
  }

  void _openNotifications() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const _NotificationsPage()));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        children: <Widget>[
          ListTile(
            leading: const Icon(Icons.person_outline_rounded),
            title: Text(l10n.account),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: _openAccount,
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(l10n.privacy),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: _openPrivacy,
          ),
          ListTile(
            leading: const Icon(Icons.notifications_none_rounded),
            title: Text(l10n.notifications),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: _openNotifications,
          ),
          ListTile(
            leading: const Icon(Icons.language_rounded),
            title: Text(l10n.language),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => _LanguagePage(
                    current: _locale,
                    onChanged: _handleLocaleChanged,
                  ),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.brightness_6_rounded),
            title: Text(l10n.appearance),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => _AppearancePage(
                    current: _themeMode,
                    onChanged: _handleThemeChanged,
                  ),
                ),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Privacy Policy'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => launchUrl(
              Uri.parse('$apiBaseUrl/legal/privacy'),
              mode: LaunchMode.externalApplication,
            ),
          ),
          ListTile(
            leading: const Icon(Icons.gavel_outlined),
            title: const Text('Terms of Service'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => launchUrl(
              Uri.parse('$apiBaseUrl/legal/terms'),
              mode: LaunchMode.externalApplication,
            ),
          ),
          const Divider(height: 1),
          ListTile(
            enabled: !_deletingAccount,
            leading: _deletingAccount
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_forever_rounded, color: Colors.red),
            title: Text(
              _deletingAccount ? 'Deleting account...' : 'Delete Account',
              style: const TextStyle(color: Colors.red),
            ),
            onTap: _deletingAccount ? null : _handleDeleteAccount,
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: Text(l10n.logout, style: const TextStyle(color: Colors.red)),
            onTap: _handleLogout,
          ),
        ],
      ),
    );
  }
}

class _AccountPage extends StatelessWidget {
  const _AccountPage({
    required this.deletingAccount,
    required this.onLogout,
    required this.onDeleteAccount,
  });

  final bool deletingAccount;
  final Future<void> Function() onLogout;
  final Future<void> Function() onDeleteAccount;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.account)),
      body: ListView(
        children: <Widget>[
          ListTile(
            leading: const Icon(Icons.verified_user_outlined),
            title: const Text('Signed in account'),
            subtitle: const Text(
              'Your login, profile, wallet, chats, and live history are tied to this account.',
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: Text(l10n.logout, style: const TextStyle(color: Colors.red)),
            onTap: onLogout,
          ),
          ListTile(
            enabled: !deletingAccount,
            leading: deletingAccount
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_forever_rounded, color: Colors.red),
            title: Text(
              deletingAccount ? 'Deleting account...' : 'Delete Account',
              style: const TextStyle(color: Colors.red),
            ),
            subtitle: const Text('Permanently remove account data.'),
            onTap: deletingAccount ? null : onDeleteAccount,
          ),
        ],
      ),
    );
  }
}

class _PrivacyPage extends StatelessWidget {
  const _PrivacyPage();

  Future<void> _open(String path) {
    return launchUrl(
      Uri.parse('$apiBaseUrl$path'),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.privacy)),
      body: ListView(
        children: <Widget>[
          const ListTile(
            leading: Icon(Icons.lock_outline_rounded),
            title: Text('Privacy controls'),
            subtitle: Text(
              'Legal documents open in your browser. Account deletion is available from Account settings.',
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Privacy Policy'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => _open('/legal/privacy'),
          ),
          ListTile(
            leading: const Icon(Icons.gavel_outlined),
            title: const Text('Terms of Service'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => _open('/legal/terms'),
          ),
        ],
      ),
    );
  }
}

class _NotificationsPage extends StatelessWidget {
  const _NotificationsPage();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.notifications)),
      body: ListView(
        children: const <Widget>[
          ListTile(
            leading: Icon(Icons.notifications_active_outlined),
            title: Text('Message alerts'),
            subtitle: Text('New chat messages can trigger push notifications.'),
            trailing: Icon(Icons.check_circle_rounded),
          ),
          ListTile(
            leading: Icon(Icons.call_outlined),
            title: Text('Incoming call alerts'),
            subtitle: Text('Incoming calls appear while you are signed in.'),
            trailing: Icon(Icons.check_circle_rounded),
          ),
          Divider(height: 1),
          ListTile(
            leading: Icon(Icons.settings_suggest_outlined),
            title: Text('Device permission'),
            subtitle: Text(
              'System notification permission is managed in iOS or Android settings.',
            ),
          ),
        ],
      ),
    );
  }
}

// ── Language Settings Page ────────────────────────────────────────────────────
class _LanguagePage extends StatelessWidget {
  const _LanguagePage({required this.current, required this.onChanged});

  final Locale? current;
  final ValueChanged<Locale?> onChanged;

  static const List<Map<String, String>> _languages = <Map<String, String>>[
    {'code': '', 'flag': '🌐', 'name': 'System default', 'native': 'Auto'},
    {'code': 'en', 'flag': '🇬🇧', 'name': 'English', 'native': 'English'},
    {'code': 'ar', 'flag': '🇸🇦', 'name': 'Arabic', 'native': 'العربية'},
    {'code': 'pt', 'flag': '🇧🇷', 'name': 'Portuguese', 'native': 'Português'},
    {'code': 'es', 'flag': '🇪🇸', 'name': 'Spanish', 'native': 'Español'},
  ];

  @override
  Widget build(BuildContext context) {
    final String currentCode = current?.languageCode ?? '';
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.language)),
      body: ListView.separated(
        itemCount: _languages.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
        itemBuilder: (BuildContext ctx, int i) {
          final Map<String, String> lang = _languages[i];
          final bool selected = lang['code'] == currentCode;
          return ListTile(
            leading: Text(lang['flag']!, style: const TextStyle(fontSize: 28)),
            title: Text(
              lang['native']!,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(lang['name']!),
            trailing: selected
                ? const Icon(Icons.check_rounded, color: Color(0xFFFF8F00))
                : null,
            onTap: () {
              final String code = lang['code']!;
              onChanged(code.isEmpty ? null : Locale(code));
              Navigator.of(ctx).pop();
            },
          );
        },
      ),
    );
  }
}

// ── Appearance Settings Page ──────────────────────────────────────────────────
class _AppearancePage extends StatefulWidget {
  const _AppearancePage({required this.current, required this.onChanged});

  final ThemeMode current;
  final ValueChanged<ThemeMode> onChanged;

  @override
  State<_AppearancePage> createState() => _AppearancePageState();
}

class _AppearancePageState extends State<_AppearancePage> {
  late ThemeMode _selected = widget.current;

  void _select(ThemeMode mode) {
    setState(() => _selected = mode);
    widget.onChanged(mode);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context)!.appearance)),
      body: ListView(
        children: <Widget>[
          _AppearanceTile(
            icon: Icons.brightness_auto_rounded,
            label: AppLocalizations.of(context)!.systemDefault,
            subtitle: AppLocalizations.of(context)!.followDeviceSetting,
            mode: ThemeMode.system,
            current: _selected,
            onChanged: _select,
          ),
          _AppearanceTile(
            icon: Icons.light_mode_rounded,
            label: AppLocalizations.of(context)!.lightMode,
            subtitle: AppLocalizations.of(context)!.alwaysUseLightMode,
            mode: ThemeMode.light,
            current: _selected,
            onChanged: _select,
          ),
          _AppearanceTile(
            icon: Icons.dark_mode_rounded,
            label: AppLocalizations.of(context)!.darkMode,
            subtitle: AppLocalizations.of(context)!.alwaysUseDarkMode,
            mode: ThemeMode.dark,
            current: _selected,
            onChanged: _select,
          ),
        ],
      ),
    );
  }
}

class _AppearanceTile extends StatelessWidget {
  const _AppearanceTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.mode,
    required this.current,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final ThemeMode mode;
  final ThemeMode current;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final bool selected = current == mode;
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(subtitle),
      trailing: selected
          ? Icon(
              Icons.check_circle_rounded,
              color: Theme.of(context).colorScheme.primary,
            )
          : const Icon(Icons.radio_button_unchecked_rounded),
      onTap: () => onChanged(mode),
    );
  }
}
