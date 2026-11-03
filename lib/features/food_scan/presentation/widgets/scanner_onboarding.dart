import 'package:flutter/material.dart';

/// Idle-state guidance: how it works, what makes a good photo, and which menu
/// the closed-set model actually supports.
final class ScannerOnboarding extends StatelessWidget {
  const ScannerOnboarding({super.key, required this.supportedCount});

  final int supportedCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    Icons.explore_outlined,
                    size: 19,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Cara pakai',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const _StepRow(
              number: '1',
              icon: Icons.add_a_photo_outlined,
              title: 'Ambil atau pilih foto',
              description:
                  'Posisikan satu piring dalam frame, dari atas bila bisa.',
            ),
            const SizedBox(height: 13),
            _StepRow(
              number: '2',
              icon: Icons.memory_rounded,
              title: 'AI mengenali makanan',
              description:
                  'Model hanya mengenali $supportedCount menu dari dataset '
                  'dan berjalan lokal, tanpa internet.',
            ),
            const SizedBox(height: 13),
            const _StepRow(
              number: '3',
              icon: Icons.monitor_heart_outlined,
              title: 'Lihat estimasi gizi',
              description:
                  'Kalori dan makronutrien muncul lengkap dengan porsi.',
            ),
            const SizedBox(height: 18),
            Divider(color: scheme.outlineVariant.withValues(alpha: 0.5)),
            const SizedBox(height: 14),
            Text(
              'Agar hasil akurat',
              style: textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: const <Widget>[
                _TipChip(
                  icon: Icons.light_mode_outlined,
                  label: 'Cahaya terang',
                ),
                _TipChip(icon: Icons.crop_free_rounded, label: 'Satu porsi'),
                _TipChip(icon: Icons.height_rounded, label: 'Sudut atas'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

final class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.number,
    required this.icon,
    required this.title,
    required this.description,
  });

  final String number;
  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: scheme.primary.withValues(alpha: 0.1),
                ),
              ),
              child: Icon(icon, size: 19, color: scheme.onPrimaryContainer),
            ),
            Positioned(
              right: -5,
              bottom: -5,
              child: Container(
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: scheme.surface, width: 2),
                ),
                child: Text(
                  number,
                  style: textTheme.labelSmall?.copyWith(
                    color: scheme.onPrimary,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

final class _TipChip extends StatelessWidget {
  const _TipChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: scheme.onSurfaceVariant),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
