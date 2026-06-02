import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/api_client.dart';

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
  late final TextEditingController _nicknameCtrl;
  Country? _selectedCountry;
  String? _selectedLanguage;
  bool _saving = false;
  String? _error;

  static const List<Map<String, String>> _languages = [
    {'code': 'en', 'label': 'English'},
    {'code': 'ar', 'label': 'العربية'},
    {'code': 'pt', 'label': 'Português'},
    {'code': 'es', 'label': 'Español'},
    {'code': 'fil', 'label': 'Filipino'},
    {'code': 'hi', 'label': 'हिन्दी'},
    {'code': 'id', 'label': 'Bahasa Indonesia'},
    {'code': 'th', 'label': 'ภาษาไทย'},
    {'code': 'vi', 'label': 'Tiếng Việt'},
    {'code': 'zh', 'label': '中文'},
  ];

  @override
  void initState() {
    super.initState();
    // Pre-fill with the name from Google/Apple if it looks real
    final name = widget.initialDisplayName;
    final isPlaceholder = name.startsWith('google_') ||
        name.startsWith('zephyr_') ||
        name.startsWith('apple_');
    _nicknameCtrl = TextEditingController(text: isPlaceholder ? '' : name);
  }

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _nicknameCtrl.text.trim().length >= 2 &&
      _selectedCountry != null &&
      _selectedLanguage != null;

  Future<void> _save() async {
    if (!_isValid) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.apiClient.updateMe(
        widget.accessToken,
        displayName: _nicknameCtrl.text.trim(),
        countryCode: _selectedCountry!.countryCode,
        language: _selectedLanguage,
      );
      if (mounted) widget.onComplete();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _pickCountry() {
    showCountryPicker(
      context: context,
      showPhoneCode: false,
      countryListTheme: CountryListThemeData(
        backgroundColor: const Color(0xFF1C1C2E),
        textStyle: const TextStyle(color: Colors.white),
        searchTextStyle: const TextStyle(color: Colors.white),
        inputDecoration: InputDecoration(
          hintText: 'Search country',
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
          prefixIcon: const Icon(Icons.search, color: Colors.white54),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white.withOpacity(0.1),
        ),
      ),
      onSelect: (Country country) {
        setState(() => _selectedCountry = country);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: const Color(0xFF150805),
        body: SafeArea(
          child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 48),
              const Text(
                'Welcome to Zephyr',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Set up your profile to get started',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 40),

              // Nickname
              const Text(
                'Nickname',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nicknameCtrl,
                maxLength: 20,
                style: const TextStyle(color: Colors.white),
                inputFormatters: [
                  FilteringTextInputFormatter.deny(RegExp(r'[\x00-\x1F]')),
                ],
                decoration: InputDecoration(
                  hintText: 'Enter your nickname',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                  counterStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.08),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 20),

              // Country
              const Text(
                'Country',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Semantics(
                label: 'Country picker',
                button: true,
                child: GestureDetector(
                  onTap: _pickCountry,
                  child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _selectedCountry == null
                      ? Text(
                          'Select your country',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 16,
                          ),
                        )
                      : Row(
                          children: [
                            Text(
                              _selectedCountry!.flagEmoji,
                              style: const TextStyle(fontSize: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _selectedCountry!.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              color: Colors.white38,
                            ),
                          ],
                        ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Language
              const Text(
                'Language',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Semantics(
                label: 'Language selector',
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedLanguage,
                    hint: Text(
                      'Select your language',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 16,
                      ),
                    ),
                    dropdownColor: const Color(0xFF2D2D44),
                    isExpanded: true,
                    icon: const Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.white38,
                    ),
                    items: _languages
                        .map(
                          (lang) => DropdownMenuItem<String>(
                            value: lang['code'],
                            child: Text(
                              lang['label']!,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _selectedLanguage = value),
                  ),
                ),
              ),
              ),

              const Spacer(),

              // Error
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                  ),
                ),

              // Continue button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isValid && !_saving ? _save : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF8F00),
                    disabledBackgroundColor: const Color(0xFFFF8F00).withOpacity(0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Continue',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              SizedBox(height: bottomPad + 16),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
