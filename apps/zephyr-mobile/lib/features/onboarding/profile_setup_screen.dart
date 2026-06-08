import 'dart:io';

import 'package:flutter/material.dart';

import '../../services/api_client.dart';
import '../../services/firebase_chat_service.dart';
import '../../l10n/app_localizations.dart';

typedef ProfileRealtimeWriter =
    Future<void> Function({
      required String displayName,
      String? avatarUrl,
      required String countryCode,
      required String language,
      String? birthday,
    });

typedef CountryCodeResolver = String Function();

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({
    required this.apiClient,
    required this.accessToken,
    required this.initialDisplayName,
    required this.onComplete,
    this.profileWriter,
    this.countryCodeResolver,
    super.key,
  });

  final ZephyrApiClient apiClient;
  final String accessToken;
  final String initialDisplayName;
  final VoidCallback onComplete;
  final ProfileRealtimeWriter? profileWriter;
  final CountryCodeResolver? countryCodeResolver;

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final PageController _pageCtrl = PageController();
  late final ProfileRealtimeWriter _profileWriter;
  String? _selectedGender;
  String? _selectedLanguage;
  bool _saving = false;

  static const List<Map<String, String>> _languages = [
    {'code': 'en', 'label': 'English', 'flag': '🇬🇧'},
    {'code': 'ar', 'label': 'العربية', 'flag': '🇸🇦'},
    {'code': 'pt', 'label': 'Português', 'flag': '🇧🇷'},
    {'code': 'es', 'label': 'Español', 'flag': '🇪🇸'},
    {'code': 'fil', 'label': 'Filipino', 'flag': '🇵🇭'},
    {'code': 'hi', 'label': 'हिन्दी', 'flag': '🇮🇳'},
    {'code': 'id', 'label': 'Indonesia', 'flag': '🇮🇩'},
    {'code': 'th', 'label': 'ภาษาไทย', 'flag': '🇹🇭'},
    {'code': 'vi', 'label': 'Tiếng Việt', 'flag': '🇻🇳'},
    {'code': 'zh', 'label': '中文', 'flag': '🇨🇳'},
    {'code': 'fr', 'label': 'Français', 'flag': '🇫🇷'},
    {'code': 'ru', 'label': 'Русский', 'flag': '🇷🇺'},
  ];

  @override
  void initState() {
    super.initState();
    _profileWriter =
        widget.profileWriter ?? FirebaseChatService.instance.writeMyProfile;
  }

  String _detectCountryCode() {
    final String? resolved = widget.countryCodeResolver?.call();
    if (resolved != null && resolved.trim().isNotEmpty) {
      return resolved.trim().toUpperCase();
    }
    try {
      final parts = Platform.localeName.split('_');
      if (parts.length >= 2) return parts.last.substring(0, 2).toUpperCase();
    } catch (_) {}
    return '';
  }

  void _selectGender(String gender) {
    setState(() => _selectedGender = gender);
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _pageCtrl.nextPage(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _selectLanguage(String code) async {
    if (_saving) return;
    setState(() {
      _selectedLanguage = code;
      _saving = true;
    });

    try {
      final country = _detectCountryCode();
      await widget.apiClient.updateMe(
        widget.accessToken,
        gender: _selectedGender,
        language: code,
        countryCode: country.isNotEmpty ? country : null,
      );
      await _profileWriter(
        displayName: widget.initialDisplayName,
        countryCode: country,
        language: code,
      );
      if (mounted) widget.onComplete();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.failedToSaveProfile(e.toString()),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: PageView(
          controller: _pageCtrl,
          physics: const NeverScrollableScrollPhysics(),
          children: [_buildGenderPage(), _buildLanguagePage()],
        ),
      ),
    );
  }

  // ─── Page 1: Gender ───────────────────────────────────────────────────────

  Widget _buildGenderPage() {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const Spacer(flex: 2),
          Text(
            l10n.gender,
            style: TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.selectYourGender,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 15,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: _buildGenderCard(
                  value: 'Male',
                  label: l10n.male,
                  icon: Icons.face_5_rounded,
                  color: const Color(0xFF4A90D9),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _buildGenderCard(
                  value: 'Female',
                  label: l10n.female,
                  icon: Icons.face_3_rounded,
                  color: const Color(0xFFE84393),
                ),
              ),
            ],
          ),
          const Spacer(flex: 3),
        ],
      ),
    );
  }

  Widget _buildGenderCard({
    required String value,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    final bool selected = _selectedGender == value;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: () => _selectGender(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 36),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: selected
                  ? [color, color.withValues(alpha: 0.7)]
                  : [
                      color.withValues(alpha: 0.12),
                      color.withValues(alpha: 0.06),
                    ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: selected ? color : color.withValues(alpha: 0.3),
              width: selected ? 2 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 64,
                color: selected ? Colors.white : color.withValues(alpha: 0.8),
              ),
              const SizedBox(height: 16),
              Text(
                label,
                style: TextStyle(
                  color: selected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.8),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Page 2: Language ─────────────────────────────────────────────────────

  void _goBackToGender() {
    _pageCtrl.previousPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildLanguagePage() {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: _goBackToGender,
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              icon: const Icon(
                Icons.arrow_back_ios_rounded,
                color: Colors.white70,
                size: 20,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.yourLanguage,
            style: TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.translateMessagesForYou,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.only(bottom: 32),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 2.4,
              ),
              itemCount: _languages.length,
              itemBuilder: (context, index) {
                final lang = _languages[index];
                final bool selected = _selectedLanguage == lang['code'];
                return Semantics(
                  button: true,
                  selected: selected,
                  enabled: !_saving,
                  label: lang['label'],
                  child: GestureDetector(
                    onTap: _saving
                        ? null
                        : () => _selectLanguage(lang['code']!),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFFFF8F00)
                            : Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFFFF8F00)
                              : Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            lang['flag']!,
                            style: const TextStyle(fontSize: 22),
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              lang['label']!,
                              style: TextStyle(
                                color: selected
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.8),
                                fontSize: 15,
                                fontWeight: selected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_saving)
            Padding(
              padding: const EdgeInsets.only(bottom: 32),
              child: Center(
                child: Semantics(
                  label: l10n.savingProfile,
                  child: const CircularProgressIndicator(
                    color: Color(0xFFFF8F00),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
