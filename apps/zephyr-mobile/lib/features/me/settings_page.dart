import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.onLogout,
    required this.locale,
    required this.onLocaleChanged,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  final VoidCallback onLogout;
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

  void _handleThemeChanged(ThemeMode mode) {
    setState(() => _themeMode = mode);
    widget.onThemeModeChanged(mode);
  }

  void _handleLocaleChanged(Locale? locale) {
    setState(() => _locale = locale);
    widget.onLocaleChanged(locale);
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
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(l10n.privacy),
          ),
          ListTile(
            leading: const Icon(Icons.notifications_none_rounded),
            title: Text(l10n.notifications),
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
            leading: const Icon(Icons.logout, color: Colors.red),
            title: Text(
              l10n.logout,
              style: const TextStyle(color: Colors.red),
            ),
            onTap: () async {
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
              if (confirm != true) return;
              if (!context.mounted) return;
              Navigator.of(context).popUntil((route) => route.isFirst);
              widget.onLogout();
            },
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
            title: Text(lang['native']!, style: const TextStyle(fontWeight: FontWeight.w600)),
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
          ? Icon(Icons.check_circle_rounded,
              color: Theme.of(context).colorScheme.primary)
          : const Icon(Icons.radio_button_unchecked_rounded),
      onTap: () => onChanged(mode),
    );
  }
}
