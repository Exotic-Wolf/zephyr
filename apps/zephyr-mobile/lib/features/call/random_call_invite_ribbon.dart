import 'package:flutter/material.dart';

class RandomCallInviteRibbon extends StatelessWidget {
  const RandomCallInviteRibbon({
    super.key,
    required this.partnerName,
    required this.rateCoinsPerMinute,
    required this.hostEarningCoinsPerMinute,
    required this.onAccept,
    required this.onDecline,
    this.accepting = false,
  });

  final String partnerName;
  final int rateCoinsPerMinute;
  final int hostEarningCoinsPerMinute;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final bool accepting;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final earning = hostEarningCoinsPerMinute > 0
        ? hostEarningCoinsPerMinute
        : rateCoinsPerMinute;

    return Material(
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xF21A1511) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFFFFB300).withValues(alpha: 0.42),
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.34 : 0.16),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: <Color>[Color(0xFFFFD54F), Color(0xFFFF7043)],
                  ),
                ),
                child: const Icon(
                  Icons.videocam_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'Random call from $partnerName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF191611),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Earn $earning coins/min',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFFFFB300),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Customer pays $rateCoinsPerMinute coins/min',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _RibbonActionButton(
                tooltip: 'Decline random call',
                icon: Icons.call_end_rounded,
                color: Colors.redAccent,
                onTap: accepting ? null : onDecline,
              ),
              const SizedBox(width: 8),
              _RibbonActionButton(
                tooltip: 'Accept random call',
                icon: accepting ? null : Icons.videocam_rounded,
                color: const Color(0xFF20C05C),
                onTap: accepting ? null : onAccept,
                loading: accepting,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RibbonActionButton extends StatelessWidget {
  const _RibbonActionButton({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onTap,
    this.loading = false,
  });

  final String tooltip;
  final IconData? icon;
  final Color color;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 26,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(icon, color: Colors.white, size: 23),
          ),
        ),
      ),
    );
  }
}
