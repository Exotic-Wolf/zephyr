import 'dart:io';

import 'package:flutter/material.dart';

import '../../services/api_client.dart';
import '../../services/firebase_chat_service.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({
    required this.apiClient,
    required this.accessToken,
    required this.initialDisplayName,
    required this.onComplete,
    super.key,
  });

  final ZephyrApiClient apiClient;
  final String accessToken;
  final String initialDisplayName;
  final VoidCallback onComplete;

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final PageController _pageCtrl = PageController();
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

  String _detectCountryCode() {
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
      FirebaseChatService.instance.writeMyProfile(
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
            content: Text('Failed to save: $e'),
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
          children: [
            _buildGenderPage(),
            _buildLanguagePage(),
          ],
        ),
      ),
    );
  }

  // ─── Page 1: Gender ───────────────────────────────────────────────────────

  Widget _buildGenderPage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const Spacer(flex: 2),
          const Text(
            'I am',
            style: TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select your gender to get started',
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
                  'Male',
                  Icons.face_5_rounded,
                  const Color(0xFF4A90D9),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _buildGenderCard(
                  'Female',
                  Icons.face_3_rounded,
                  const Color(0xFFE84393),
                ),
              ),
            ],
          ),
          const Spacer(flex: 3),
        ],
      ),
    );
  }

  Widget _buildGenderCard(String gender, IconData icon, Color color) {
    final bool selected = _selectedGender == gender;
    return GestureDetector(
      onTap: () => _selectGender(gender),
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
                : [color.withValues(alpha: 0.12), color.withValues(alpha: 0.06)],
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
              color: selected
                  ? Colors.white
                  : color.withValues(alpha: 0.8),
            ),
            const SizedBox(height: 16),
            Text(
              gender,
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
              icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white70, size: 20),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Your language',
            style: TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We\'ll translate messages for you',
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
                return GestureDetector(
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
                );
              },
            ),
          ),
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(bottom: 32),
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFFFF8F00)),
              ),
            ),
        ],
      ),
    );
  }
}
