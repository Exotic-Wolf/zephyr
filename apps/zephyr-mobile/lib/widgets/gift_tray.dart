import 'package:flutter/material.dart';

/// Gift catalog item — mirrors backend `listGiftCatalog()`.
class GiftItem {
  const GiftItem({required this.id, required this.name, required this.emoji, required this.coinCost});
  final String id;
  final String name;
  final String emoji;
  final int coinCost;
}

const List<GiftItem> kGiftCatalog = <GiftItem>[
  GiftItem(id: 'rose', name: 'Rose', emoji: '🌹', coinCost: 10),
  GiftItem(id: 'heart', name: 'Heart', emoji: '💖', coinCost: 50),
  GiftItem(id: 'rocket', name: 'Rocket', emoji: '🚀', coinCost: 120),
  GiftItem(id: 'crown', name: 'Crown', emoji: '👑', coinCost: 300),
  GiftItem(id: 'lion', name: 'Lion', emoji: '🦁', coinCost: 5000),
];

/// Reusable gift tray bottom sheet.
///
/// Usage from any screen:
/// ```dart
/// showGiftTray(context, onSend: (giftId, quantity) async {
///   await apiClient.sendGiftInRoom(token, roomId, giftId, quantity: quantity);
/// });
/// ```
void showGiftTray(BuildContext context, {required Future<void> Function(String giftId, int quantity) onSend}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF1A1A2E),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _GiftTraySheet(onSend: onSend),
  );
}

class _GiftTraySheet extends StatefulWidget {
  const _GiftTraySheet({required this.onSend});
  final Future<void> Function(String giftId, int quantity) onSend;

  @override
  State<_GiftTraySheet> createState() => _GiftTraySheetState();
}

class _GiftTraySheetState extends State<_GiftTraySheet> {
  int _selectedIndex = 0;
  bool _sending = false;

  Future<void> _send() async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      final GiftItem gift = kGiftCatalog[_selectedIndex];
      await widget.onSend(gift.id, 1);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red.shade700),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          const Text('Send a Gift', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: kGiftCatalog.length,
              itemBuilder: (_, int i) {
                final GiftItem gift = kGiftCatalog[i];
                final bool selected = i == _selectedIndex;
                return GestureDetector(
                  onTap: () => setState(() => _selectedIndex = i),
                  child: Container(
                    width: 72,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: selected ? Colors.white12 : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: selected
                          ? Border.all(color: const Color(0xFF1FA4EA), width: 2)
                          : Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Text(gift.emoji, style: const TextStyle(fontSize: 28)),
                        const SizedBox(height: 4),
                        Text(gift.name, style: const TextStyle(color: Colors.white70, fontSize: 10)),
                        const SizedBox(height: 2),
                        Text('${gift.coinCost}', style: const TextStyle(color: Color(0xFFFFD700), fontSize: 11, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _sending ? null : _send,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1FA4EA),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              child: _sending
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(
                      'Send ${kGiftCatalog[_selectedIndex].name} (${kGiftCatalog[_selectedIndex].coinCost} coins)',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
