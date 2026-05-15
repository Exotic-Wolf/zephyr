import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:country_picker/country_picker.dart';
import 'package:image_picker/image_picker.dart';

import '../models/models.dart';
import '../services/api_client.dart';
import '../widgets/language_picker_sheet.dart';
import 'profile_page.dart';

class MyProfilePage extends StatefulWidget {
  const MyProfilePage({
    super.key,
    required this.me,
    required this.apiClient,
    required this.accessToken,
  });
  final UserProfile? me;
  final ZephyrApiClient apiClient;
  final String accessToken;

  @override
  State<MyProfilePage> createState() => _MyProfilePageState();
}

class _MyProfilePageState extends State<MyProfilePage> {
  late final TextEditingController _nicknameCtrl;
  bool _editing = false;
  bool _saving = false;
  bool _uploadingAvatar = false;
  String? _avatarUrl;
  UserProfile? _pendingReturn;

  String _gender = 'Prefer not to say';
  DateTime? _birthday;
  Country? _country;
  String _language = '';

  Future<void> _pickLanguage() async {
    final String? picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const LanguagePickerSheet(),
    );
    if (picked != null) setState(() => _language = picked);
  }

  static const List<String> _genders = <String>[
    'Male', 'Female', 'Non-binary', 'Prefer not to say',
  ];

  @override
  void initState() {
    super.initState();
    final UserProfile? me = widget.me;
    _nicknameCtrl = TextEditingController(text: me?.displayName ?? '');
    _avatarUrl = me?.avatarUrl;
    if (me?.gender != null) _gender = me!.gender!;
    if (me?.birthday != null) {
      _birthday = DateTime.tryParse(me!.birthday!);
    }
    if (me?.countryCode != null) {
      _country = CountryService().findByCode(me!.countryCode!);
    }
    if (me?.language != null && me!.language!.isNotEmpty) {
      _language = me.language!;
    }
  }

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    super.dispose();
  }

  String get _userId => widget.me?.publicId ?? '—';

  Future<void> _pickAndUploadAvatar() async {
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose from Library'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    final XFile? picked = await ImagePicker().pickImage(source: source, imageQuality: 85, maxWidth: 800);
    if (picked == null || !mounted) return;
    setState(() => _uploadingAvatar = true);
    try {
      final String url = await widget.apiClient.uploadAvatar(widget.accessToken, File(picked.path), mimeType: picked.mimeType);
      if (!mounted) return;
      final UserProfile? me = widget.me;
      setState(() {
        _avatarUrl = url;
        if (me != null) {
          _pendingReturn = UserProfile(
            id: me.id,
            publicId: me.publicId,
            isAdmin: me.isAdmin,
            displayName: me.displayName,
            avatarUrl: url,
            bio: me.bio,
            gender: me.gender,
            birthday: me.birthday,
            countryCode: me.countryCode,
            language: me.language,
            callRateCoinsPerMinute: me.callRateCoinsPerMinute,
            createdAt: me.createdAt,
          );
        }
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('Avatar updated'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Upload failed: $e'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _pickBirthday() async {
    if (!_editing) return;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime(2000),
      firstDate: DateTime(1920),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 13)),
    );
    if (picked != null) setState(() => _birthday = picked);
  }

  String _formatBirthday() {
    if (_birthday == null) return 'Not set';
    return '${_birthday!.day}/${_birthday!.month}/${_birthday!.year}';
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final String? birthdayStr = _birthday != null
          ? '${_birthday!.year.toString().padLeft(4, '0')}-'
            '${_birthday!.month.toString().padLeft(2, '0')}-'
            '${_birthday!.day.toString().padLeft(2, '0')}'
          : null;

      final UserProfile updated = await widget.apiClient.updateMe(
        widget.accessToken,
        displayName: _nicknameCtrl.text.trim().isEmpty
            ? null
            : _nicknameCtrl.text.trim(),
        gender: _gender,
        birthday: birthdayStr,
        countryCode: _country?.countryCode,
        language: _language.isEmpty ? null : _language,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('Profile saved'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ));
      Navigator.of(context).pop(updated);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('Failed to save: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color valueColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final TextStyle valueStyle = TextStyle(fontSize: 14, color: valueColor);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(_pendingReturn),
        ),
        title: const Text('My Profile'),
        actions: <Widget>[
          if (_saving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_editing)
            TextButton(
              onPressed: _save,
              child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
            )
          else
            TextButton(
              onPressed: () => setState(() => _editing = true),
              child: const Text('Edit', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[

          // ── Avatar ───────────────────────────────────────────
          Center(
            child: Column(
              children: <Widget>[
                Stack(
                  children: <Widget>[
                    CircleAvatar(
                      radius: 48,
                      backgroundColor: widget.me?.isAdmin == true
                          ? const Color(0xFFFFD700).withValues(alpha: 0.18)
                          : const Color(0xFFFF8F00).withValues(alpha: 0.15),
                      backgroundImage: _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                      child: _avatarUrl == null
                          ? Text(
                              (widget.me?.displayName ?? 'M').substring(0, 1).toUpperCase(),
                              style: TextStyle(
                                  fontSize: 40, fontWeight: FontWeight.w700,
                                  color: widget.me?.isAdmin == true
                                      ? const Color(0xFFB8860B)
                                      : const Color(0xFFFF8F00)),
                            )
                          : null,
                    ),
                    if (_uploadingAvatar)
                      const Positioned.fill(
                        child: CircleAvatar(
                          backgroundColor: Colors.black45,
                          child: SizedBox(
                            width: 24, height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          ),
                        ),
                      ),
                    Positioned(
                      bottom: 0, right: 0,
                      child: GestureDetector(
                        onTap: _uploadingAvatar ? null : _pickAndUploadAvatar,
                        child: Container(
                          width: 30, height: 30,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFFFF8F00),
                          ),
                          child: const Icon(Icons.camera_alt_rounded,
                              size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
                if (widget.me?.isAdmin == true) ...<Widget>[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: <Color>[Color(0xFFFFD700), Color(0xFFFF8C00)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '👑  OWNER',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Fields ───────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: <Widget>[

                // ID — always read-only
                ListTile(
                  title: const Text('ID'),
                  trailing: GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: _userId));
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(const SnackBar(
                          content: Text('ID copied to clipboard'),
                          behavior: SnackBarBehavior.floating,
                          duration: Duration(seconds: 2),
                        ));
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(_userId,
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
                        const SizedBox(width: 6),
                        Icon(Icons.copy_rounded, size: 15, color: Colors.grey.shade400),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),

                // Nickname
                ListTile(
                  title: const Text('Nickname'),
                  trailing: _editing
                      ? SizedBox(
                          width: 160,
                          child: TextField(
                            controller: _nicknameCtrl,
                            textAlign: TextAlign.end,
                            style: valueStyle,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              hintText: 'Enter nickname',
                              hintStyle: TextStyle(color: Colors.grey),
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        )
                      : Text(_nicknameCtrl.text.isEmpty ? '—' : _nicknameCtrl.text,
                          style: TextStyle(fontSize: 14, color: valueColor)),
                ),
                const Divider(height: 1),

                // Gender
                ListTile(
                  title: const Text('Gender'),
                  trailing: _editing
                      ? DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _gender,
                            isDense: true,
                            isExpanded: false,
                            alignment: AlignmentDirectional.centerEnd,
                            style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                            selectedItemBuilder: (_) => _genders.map((String g) =>
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(g, style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
                              ),
                            ).toList(),
                            items: _genders.map((String g) => DropdownMenuItem<String>(
                              value: g, child: Text(g),
                            )).toList(),
                            onChanged: (String? v) {
                              if (v != null) setState(() => _gender = v);
                            },
                          ),
                        )
                      : Text(_gender, style: TextStyle(fontSize: 14, color: valueColor)),
                ),
                const Divider(height: 1),

                // Birthday
                ListTile(
                  title: const Text('Birthday'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(_formatBirthday(),
                          style: TextStyle(fontSize: 14, color: valueColor)),
                      if (_editing) ...<Widget>[
                        const SizedBox(width: 4),
                        Icon(Icons.edit_calendar_rounded,
                            size: 16, color: Colors.grey.shade400),
                      ],
                    ],
                  ),
                  onTap: _pickBirthday,
                ),
                const Divider(height: 1),

                // Country
                ListTile(
                  title: const Text('Country'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      _country == null
                          ? Text('Not set', style: TextStyle(fontSize: 14, color: Colors.grey.shade400))
                          : Text('${_country!.flagEmoji} ${_country!.name}',
                              style: TextStyle(fontSize: 14, color: valueColor)),
                      if (_editing) ...<Widget>[
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right_rounded,
                            size: 18, color: Colors.grey.shade400),
                      ],
                    ],
                  ),
                  onTap: _editing
                      ? () => showCountryPicker(
                            context: context,
                            showPhoneCode: false,
                            onSelect: (Country c) => setState(() => _country = c),
                          )
                      : null,
                ),
                const Divider(height: 1),

                // Language
                ListTile(
                  title: const Text('Language'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(_language.isEmpty ? 'Not set' : _language,
                          style: TextStyle(
                              fontSize: 14,
                              color: _language.isEmpty
                                  ? Colors.grey.shade400
                                  : valueColor)),
                      if (_editing) ...<Widget>[
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right_rounded,
                            size: 18, color: Colors.grey.shade400),
                      ],
                    ],
                  ),
                  onTap: _editing ? _pickLanguage : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Your ID is permanent and cannot be changed.',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () {
              final UserProfile? me = widget.me;
              final LiveFeedCard card = LiveFeedCard(
                roomId: '',
                title: '',
                audienceCount: 0,
                hostUserId: me?.id ?? '',
                hostDisplayName: me?.displayName ?? '',
                hostAvatarUrl: me?.avatarUrl,
                hostCountryCode: me?.countryCode ?? '',
                hostLanguage: me?.language ?? '',
                hostStatus: 'online',
                startedAt: DateTime.now(),
              );
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ProfilePage(
                    feedCard: card,
                    onMessage: () {},
                    isPreview: true,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.person_search_rounded, size: 18),
            label: const Text('View Public Profile'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

