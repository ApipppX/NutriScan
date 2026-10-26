import 'package:flutter/material.dart';

/// Small trust indicator communicating that inference is local.
final class OfflineBadge extends StatelessWidget {
  const OfflineBadge({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Tooltip(
      message: 'Model AI berjalan di perangkat. Foto tidak diunggah ke server.',
      child: Semantics(
        label: 'Pemrosesan 100 persen offline di perangkat',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: scheme.primaryContainer.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: scheme.primary.withValues(alpha: 0.18)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.offline_bolt_rounded,
                size: 15,
                color: scheme.onPrimaryContainer,
              ),
              const SizedBox(width: 5),
              Text(
                compact ? 'On-device' : '100% offline',
                style: textTheme.labelSmall?.copyWith(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
