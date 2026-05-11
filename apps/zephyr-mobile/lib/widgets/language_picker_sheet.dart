import 'package:flutter/material.dart';

// ── LanguagePickerSheet ──────────────────────────────────────────────────────

class LanguagePickerSheet extends StatefulWidget {
  const LanguagePickerSheet();

  @override
  State<LanguagePickerSheet> createState() => LanguagePickerSheetState();
}

class LanguagePickerSheetState extends State<LanguagePickerSheet> {
  static const List<String> _all = <String>[
    'Afrikaans', 'Arabic', 'Bengali', 'Bulgarian', 'Catalan', 'Chinese (Simplified)',
    'Chinese (Traditional)', 'Croatian', 'Czech', 'Danish', 'Dutch', 'English',
    'Estonian', 'Finnish', 'French', 'German', 'Greek', 'Gujarati', 'Hebrew',
    'Hindi', 'Hungarian', 'Indonesian', 'Italian', 'Japanese', 'Kannada', 'Korean',
    'Latvian', 'Lithuanian', 'Malay', 'Malayalam', 'Marathi', 'Norwegian', 'Persian',
    'Polish', 'Portuguese', 'Punjabi', 'Romanian', 'Russian', 'Serbian', 'Slovak',
    'Slovenian', 'Spanish', 'Swahili', 'Swedish', 'Tamil', 'Telugu', 'Thai',
    'Turkish', 'Ukrainian', 'Urdu', 'Vietnamese',
  ];

  String _query = '';

  List<String> get _filtered => _query.isEmpty
      ? _all
      : _all.where((l) => l.toLowerCase().contains(_query.toLowerCase())).toList();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: <Widget>[
            const SizedBox(height: 8),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            const Text('Select Language',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search language…',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: const Color(0xFFF2F2F7),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                controller: controller,
                itemCount: _filtered.length,
                itemBuilder: (_, i) {
                  final String lang = _filtered[i];
                  return ListTile(
                    title: Text(lang),
                    onTap: () => Navigator.of(context).pop(lang),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

