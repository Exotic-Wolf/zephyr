import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/api_client.dart';
import '../../services/api_error_messages.dart';
import '../../widgets/coin_icon.dart';

class GiftSendTarget {
  const GiftSendTarget({
    required this.surface,
    required this.contextId,
    this.receiverUserId,
    required this.receiverDisplayName,
  });

  final String surface;
  final String contextId;
  final String? receiverUserId;
  final String receiverDisplayName;
}

class GiftVisual {
  const GiftVisual({
    required this.giftEventId,
    required this.giftId,
    required this.giftName,
    required this.thumbnailUrl,
    required this.animationUrl,
    required this.animationType,
    required this.tier,
    required this.quantity,
    required this.coinCost,
    required this.totalCoins,
  });

  final String giftEventId;
  final String giftId;
  final String giftName;
  final String thumbnailUrl;
  final String animationUrl;
  final String animationType;
  final String tier;
  final int quantity;
  final int coinCost;
  final int totalCoins;

  factory GiftVisual.fromSendResult(GiftSendResult result) {
    return GiftVisual(
      giftEventId: result.giftEventId,
      giftId: result.giftId,
      giftName: result.giftName,
      thumbnailUrl: result.thumbnailUrl,
      animationUrl: result.animationUrl,
      animationType: result.animationType,
      tier: result.tier,
      quantity: result.quantity,
      coinCost: result.coinCost,
      totalCoins: result.totalGiftCoins,
    );
  }
}

Future<GiftSendResult?> showGiftPickerSheet({
  required BuildContext context,
  required ZephyrApiClient apiClient,
  required String accessToken,
  required GiftSendTarget target,
}) {
  return showModalBottomSheet<GiftSendResult>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext sheetContext) {
      return _GiftPickerSheet(
        apiClient: apiClient,
        accessToken: accessToken,
        target: target,
      );
    },
  );
}

class _GiftPickerSheet extends StatefulWidget {
  const _GiftPickerSheet({
    required this.apiClient,
    required this.accessToken,
    required this.target,
  });

  final ZephyrApiClient apiClient;
  final String accessToken;
  final GiftSendTarget target;

  @override
  State<_GiftPickerSheet> createState() => _GiftPickerSheetState();
}

class _GiftPickerSheetState extends State<_GiftPickerSheet> {
  Future<List<GiftCatalogItem>>? _catalogFuture;
  GiftCatalogItem? _selectedGift;
  String? _selectedSectionId;
  String? _sendingGiftId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _catalogFuture = _loadCatalog();
  }

  Future<List<GiftCatalogItem>> _loadCatalog() async {
    final List<GiftCatalogItem> catalog = await widget.apiClient
        .listGiftCatalog();
    final List<GiftCatalogItem> filtered = catalog
        .where(
          (GiftCatalogItem gift) =>
              gift.enabled && gift.surfaces.contains(widget.target.surface),
        )
        .toList(growable: false);
    if (filtered.isNotEmpty) {
      _selectedSectionId = filtered.first.sectionId;
      _selectedGift = filtered.first;
    }
    return filtered;
  }

  Future<void> _sendSelectedGift() async {
    final GiftCatalogItem? gift = _selectedGift;
    if (gift == null || _sendingGiftId != null) return;

    setState(() {
      _sendingGiftId = gift.id;
      _error = null;
    });

    final String idempotencyKey =
        'gift:${widget.target.surface}:${widget.target.contextId}:'
        '${DateTime.now().microsecondsSinceEpoch}:${gift.id}:1';
    try {
      final GiftSendResult result = await widget.apiClient.sendGift(
        widget.accessToken,
        surface: widget.target.surface,
        contextId: widget.target.contextId,
        receiverUserId: widget.target.receiverUserId,
        giftId: gift.id,
        quantity: 1,
        idempotencyKey: idempotencyKey,
      );
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = giftFailureMessage(error);
        _sendingGiftId = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Size size = MediaQuery.sizeOf(context);
    final double maxHeight = math.min(size.height * 0.76, 620);

    return Align(
      alignment: Alignment.bottomCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141216) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border(
              top: BorderSide(
                color: const Color(0xFFFF8F00).withValues(alpha: 0.20),
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          child: FutureBuilder<List<GiftCatalogItem>>(
            future: _catalogFuture,
            builder: (BuildContext context, snapshot) {
              final List<GiftCatalogItem>? gifts = snapshot.data;
              return Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  10,
                  16,
                  MediaQuery.viewPaddingOf(context).bottom + 14,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 34,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.black26,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Send gift',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.target.receiverDisplayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white60
                                      : Colors.black54,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: _sendingGiftId == null
                              ? () => Navigator.of(context).pop()
                              : null,
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (snapshot.connectionState != ConnectionState.done)
                      const Expanded(
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else if (snapshot.hasError)
                      Expanded(
                        child: _GiftPickerStateMessage(
                          icon: Icons.wifi_off_rounded,
                          message: apiErrorMessage(
                            snapshot.error ??
                                Exception('Gift catalog unavailable'),
                          ),
                          actionLabel: 'Retry',
                          onAction: () {
                            setState(() {
                              _error = null;
                              _catalogFuture = _loadCatalog();
                            });
                          },
                        ),
                      )
                    else if (gifts == null || gifts.isEmpty)
                      const Expanded(
                        child: _GiftPickerStateMessage(
                          icon: Icons.card_giftcard_rounded,
                          message: 'No gifts available here yet',
                        ),
                      )
                    else ...[
                      _GiftSectionTabs(
                        gifts: gifts,
                        selectedSectionId: _selectedSectionId,
                        onChanged: (String sectionId) {
                          final GiftCatalogItem firstInSection = gifts
                              .firstWhere(
                                (gift) => gift.sectionId == sectionId,
                              );
                          setState(() {
                            _selectedSectionId = sectionId;
                            _selectedGift = firstInSection;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: _GiftGrid(
                          gifts: gifts
                              .where(
                                (GiftCatalogItem gift) =>
                                    gift.sectionId == _selectedSectionId,
                              )
                              .toList(growable: false),
                          selectedGiftId: _selectedGift?.id,
                          sendingGiftId: _sendingGiftId,
                          onSelected: (GiftCatalogItem gift) {
                            if (_sendingGiftId != null) return;
                            setState(() => _selectedGift = gift);
                          },
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFFF453A),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _sendingGiftId == null
                            ? _sendSelectedGift
                            : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFFF8F00),
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: _sendingGiftId == null
                            ? const Icon(Icons.card_giftcard_rounded, size: 19)
                            : const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                        label: Text(
                          _selectedGift == null
                              ? 'Select gift'
                              : 'Send ${_selectedGift!.name}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _GiftSectionTabs extends StatelessWidget {
  const _GiftSectionTabs({
    required this.gifts,
    required this.selectedSectionId,
    required this.onChanged,
  });

  final List<GiftCatalogItem> gifts;
  final String? selectedSectionId;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final List<GiftCatalogItem> sections = <GiftCatalogItem>[];
    final Set<String> seen = <String>{};
    for (final GiftCatalogItem gift in gifts) {
      if (seen.add(gift.sectionId)) {
        sections.add(gift);
      }
    }

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: sections.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int index) {
          final GiftCatalogItem section = sections[index];
          final bool selected = section.sectionId == selectedSectionId;
          return ChoiceChip(
            selected: selected,
            label: Text(section.sectionName),
            onSelected: (_) => onChanged(section.sectionId),
            labelStyle: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: selected ? Colors.white : null,
            ),
            selectedColor: const Color(0xFFFF8F00),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            side: BorderSide(
              color: selected
                  ? const Color(0xFFFF8F00)
                  : const Color(0xFFFF8F00).withValues(alpha: 0.25),
            ),
          );
        },
      ),
    );
  }
}

class _GiftGrid extends StatelessWidget {
  const _GiftGrid({
    required this.gifts,
    required this.selectedGiftId,
    required this.sendingGiftId,
    required this.onSelected,
  });

  final List<GiftCatalogItem> gifts;
  final String? selectedGiftId;
  final String? sendingGiftId;
  final ValueChanged<GiftCatalogItem> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final int columns = width >= 560
            ? 5
            : width >= 390
            ? 4
            : 3;
        return GridView.builder(
          itemCount: gifts.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 0.78,
          ),
          itemBuilder: (BuildContext context, int index) {
            final GiftCatalogItem gift = gifts[index];
            final bool selected = gift.id == selectedGiftId;
            final bool sending = gift.id == sendingGiftId;
            return _GiftTile(
              gift: gift,
              selected: selected,
              sending: sending,
              onTap: () => onSelected(gift),
            );
          },
        );
      },
    );
  }
}

class _GiftTile extends StatelessWidget {
  const _GiftTile({
    required this.gift,
    required this.selected,
    required this.sending,
    required this.onTap,
  });

  final GiftCatalogItem gift;
  final bool selected;
  final bool sending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: selected
          ? const Color(0xFFFF8F00).withValues(alpha: 0.16)
          : isDark
          ? Colors.white.withValues(alpha: 0.05)
          : const Color(0xFFF8F8FA),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? const Color(0xFFFF8F00)
                  : Colors.white.withValues(alpha: isDark ? 0.08 : 0),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    GiftThumbnail(url: gift.thumbnailUrl, size: 56),
                    if (sending)
                      const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 5),
              Text(
                gift.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CoinIcon(size: 12),
                  const SizedBox(width: 3),
                  Flexible(
                    child: Text(
                      '${gift.coinCost}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFFFB020),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GiftThumbnail extends StatelessWidget {
  const GiftThumbnail({super.key, required this.url, required this.size});

  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final Widget fallback = DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFF8F00).withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: const Center(
        child: Icon(Icons.card_giftcard_rounded, color: Color(0xFFFF8F00)),
      ),
    );

    return SizedBox(
      width: size,
      height: size,
      child: url.trim().isEmpty
          ? fallback
          : CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.contain,
              placeholder: (_, __) => fallback,
              errorWidget: (_, __, ___) => fallback,
            ),
    );
  }
}

class GiftReceiptCard extends StatelessWidget {
  const GiftReceiptCard({
    super.key,
    required this.visual,
    required this.isMine,
    required this.timeLabel,
    this.read = false,
    this.optimistic = false,
  });

  final GiftVisual visual;
  final bool isMine;
  final String timeLabel;
  final bool read;
  final bool optimistic;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color accent = const Color(0xFFFF8F00);
    final Color background = isDark ? const Color(0xFF242126) : Colors.white;
    final Color foreground = isDark ? Colors.white : Colors.black87;
    final Color border = isMine
        ? accent.withValues(alpha: 0.58)
        : accent.withValues(alpha: 0.28);

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 198, maxWidth: 250),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.10),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Stack(
          children: [
            if (isMine)
              Positioned(
                top: 0,
                right: 0,
                bottom: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(8),
                    ),
                  ),
                  child: const SizedBox(width: 3),
                ),
              ),
            Padding(
              padding: EdgeInsets.fromLTRB(10, 10, isMine ? 13 : 10, 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GiftThumbnail(url: visual.thumbnailUrl, size: 58),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          visual.quantity > 1
                              ? '${visual.giftName} x${visual.quantity}'
                              : visual.giftName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: foreground,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            const CoinIcon(size: 13),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '${visual.totalCoins}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFFFFB020),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Text(
                              timeLabel,
                              style: TextStyle(
                                color: foreground.withValues(alpha: 0.58),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (isMine) ...[
                              const SizedBox(width: 4),
                              Icon(
                                optimistic
                                    ? Icons.schedule_rounded
                                    : read
                                    ? Icons.done_all
                                    : Icons.done,
                                size: 12,
                                color: read
                                    ? Colors.blue.shade300
                                    : foreground.withValues(alpha: 0.56),
                              ),
                            ],
                          ],
                        ),
                      ],
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

class GiftAnimationOverlay {
  const GiftAnimationOverlay._();

  static Future<void> play(BuildContext context, GiftVisual visual) {
    final OverlayState? overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return Future<void>.value();
    return playOnOverlay(overlay, visual);
  }

  static Future<void> playOnOverlay(OverlayState overlay, GiftVisual visual) {
    final Completer<void> completer = Completer<void>();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _GiftAnimationLayer(
        visual: visual,
        onDone: () {
          entry.remove();
          if (!completer.isCompleted) completer.complete();
        },
      ),
    );
    overlay.insert(entry);
    return completer.future;
  }
}

class _GiftAnimationLayer extends StatefulWidget {
  const _GiftAnimationLayer({required this.visual, required this.onDone});

  final GiftVisual visual;
  final VoidCallback onDone;

  @override
  State<_GiftAnimationLayer> createState() => _GiftAnimationLayerState();
}

class _GiftAnimationLayerState extends State<_GiftAnimationLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _durationForTier(widget.visual.tier),
    )..forward();
    _controller.addStatusListener((AnimationStatus status) {
      if (status == AnimationStatus.completed && mounted) {
        widget.onDone();
      }
    });
  }

  Duration _durationForTier(String tier) {
    return switch (tier) {
      'huge' => const Duration(milliseconds: 2500),
      'large' => const Duration(milliseconds: 2200),
      'medium' => const Duration(milliseconds: 1900),
      _ => const Duration(milliseconds: 1600),
    };
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Animation<double> curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return IgnorePointer(
      child: Material(
        color: Colors.transparent,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (BuildContext context, Widget? child) {
            final double t = _controller.value;
            final double fade = t < 0.16
                ? t / 0.16
                : t > 0.82
                ? (1 - t) / 0.18
                : 1;
            final double scale = 0.72 + curved.value * 0.34;
            return Opacity(
              opacity: fade.clamp(0, 1),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.46 * fade),
                    ),
                  ),
                  Center(
                    child: Transform.scale(
                      scale: scale,
                      child: _GiftAnimationCore(visual: widget.visual),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _GiftAnimationCore extends StatelessWidget {
  const _GiftAnimationCore({required this.visual});

  final GiftVisual visual;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 154,
          height: 154,
          decoration: BoxDecoration(
            color: const Color(0xFF1E1715),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFFFF8F00).withValues(alpha: 0.55),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.32),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: GiftThumbnail(url: visual.thumbnailUrl, size: 96),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          visual.giftName,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w900,
            shadows: [Shadow(color: Colors.black54, blurRadius: 12)],
          ),
        ),
        const SizedBox(height: 7),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CoinIcon(size: 16),
            const SizedBox(width: 5),
            Text(
              '${visual.totalCoins}',
              style: const TextStyle(
                color: Color(0xFFFFD36E),
                fontSize: 15,
                fontWeight: FontWeight.w900,
                shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _GiftPickerStateMessage extends StatelessWidget {
  const _GiftPickerStateMessage({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 42, color: Colors.grey.shade500),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white70
                  : Colors.black54,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}
