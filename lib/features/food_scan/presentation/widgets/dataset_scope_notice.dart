import 'package:flutter/material.dart';

/// Persistent disclosure that NutriScan is a development build with a
/// closed-set model trained on a small, fixed menu.
///
/// The notice is deliberately visible before the user scans anything. A
/// closed-set classifier always returns one of its known classes, so users must
/// know the supported list *before* interpreting a result.
final class DatasetScopeNotice extends StatelessWidget {
  const DatasetScopeNotice({
    super.key,
    required this.supportedCount,
    required this.onShowSupportedFoods,
    required this.onOpenAbout,
    this.compact = false,
  });

  /// Number of classes in the bundled model and nutrition catalog.
  final int supportedCount;

  final VoidCallback onShowSupportedFoods;
  final VoidCallback onOpenAbout;

  /// Uses a slimmer banner once a result or failure is on screen.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final countLabel = '$supportedCount menu';

    if (compact) {
      return Material(
        color: scheme.tertiaryContainer.withValues(alpha: 0.38),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: scheme.tertiary.withValues(alpha: 0.24)),
        ),
        child: InkWell(
          onTap: onShowSupportedFoods,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.science_outlined,
                  size: 19,
                  color: scheme.onTertiaryContainer,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Versi pengembangan · $countLabel',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.onTertiaryContainer,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Hanya menu dataset yang dikenali. Makanan lain bisa '
                        'salah diklasifikasi.',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onTertiaryContainer,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.chevron_right_rounded,
                  color: scheme.onTertiaryContainer,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 13),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.tertiary.withValues(alpha: 0.26)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: scheme.tertiary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: scheme.tertiary.withValues(alpha: 0.18),
                  ),
                ),
                child: Icon(
                  Icons.science_outlined,
                  size: 21,
                  color: scheme.onTertiaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Wrap(
                      spacing: 7,
                      runSpacing: 5,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.tertiary.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'VERSI PENGEMBANGAN',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onTertiaryContainer,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.55,
                            ),
                          ),
                        ),
                        Text(
                          '$countLabel didukung',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onTertiaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      'Aplikasi masih dalam pengembangan',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: scheme.onTertiaryContainer,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'NutriScan hanya mengenali $countLabel yang ada di '
                      'dataset penelitian. Makanan di luar daftar itu tetap '
                      'akan dipetakan ke salah satu kelas, sehingga hasil dan '
                      'nilai gizinya bisa keliru.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onTertiaryContainer,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                Icons.health_and_safety_outlined,
                size: 15,
                color: scheme.onTertiaryContainer,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Bukan alat medis. Selalu periksa hasil sebelum menyimpan '
                  'ke diary.',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onTertiaryContainer,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: <Widget>[
              FilledButton.tonalIcon(
                onPressed: onShowSupportedFoods,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 42),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                ),
                icon: const Icon(Icons.restaurant_menu_rounded, size: 18),
                label: Text('Lihat $countLabel'),
              ),
              TextButton.icon(
                onPressed: onOpenAbout,
                style: TextButton.styleFrom(
                  foregroundColor: scheme.onTertiaryContainer,
                  minimumSize: const Size(0, 42),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 9,
                  ),
                ),
                icon: const Icon(Icons.info_outline_rounded, size: 18),
                label: const Text('Batasan & disclaimer'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
