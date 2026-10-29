import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_config.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/brand_mark.dart';
import '../../../../core/widgets/offline_badge.dart';
import '../../../food_scan/domain/entities/nutrition_provenance.dart';
import '../../domain/entities/about_info.dart';
import '../providers/about_providers.dart';

/// About screen that makes the model and nutrition provenance inspectable.
final class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(aboutInfoProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Tentang NutriScan')),
      body: SafeArea(
        top: false,
        child: info.when(
          data: (AboutInfo value) => _AboutContent(info: value),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) =>
              _AboutError(onRetry: () => ref.invalidate(aboutInfoProvider)),
        ),
      ),
    );
  }
}

final class _AboutContent extends StatelessWidget {
  const _AboutContent({required this.info});

  final AboutInfo info;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final provenance = info.provenance;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _AppIdentity(),
              const SizedBox(height: 22),
              _AboutSection(
                icon: Icons.memory_rounded,
                title: 'Model klasifikasi',
                children: <Widget>[
                  const _InfoRow(
                    label: 'Arsitektur',
                    value: 'MobileNetV3-Large',
                  ),
                  const _InfoRow(
                    label: 'Format',
                    value: 'TensorFlow Lite, berjalan di perangkat',
                  ),
                  _InfoRow(label: 'Versi model', value: info.modelVersion),
                  _InfoRow(
                    label: 'Jumlah kelas',
                    value: '${info.classCount} makanan',
                  ),
                  if (info.modelSha256 != null)
                    _InfoRow(
                      label: 'SHA-256 model',
                      value: info.modelSha256!,
                      monospace: true,
                    ),
                  if (info.generatedAt != null)
                    _InfoRow(label: 'Katalog dibuat', value: info.generatedAt!),
                ],
              ),
              const SizedBox(height: 14),
              _AboutSection(
                icon: Icons.rule_rounded,
                title: 'Batasan model',
                children: <Widget>[
                  Text(
                    'Model ini bersifat tertutup (closed-set): model hanya '
                    'mengenali ${info.classCount} makanan yang tercantum di '
                    'aplikasi dan tidak memiliki kelas "tidak dikenal". Foto '
                    'makanan lain tetap akan dipetakan ke salah satu kelas.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _Bullet(
                    'Peringatan memakai heuristik: keyakinan di bawah '
                    '${formatPercent(AppConfig.confidenceWarningThreshold, decimals: 0)} '
                    'atau selisih dua prediksi teratas di bawah '
                    '${formatPercent(AppConfig.confidenceMarginThreshold, decimals: 0)}. '
                    'Ini bukan deteksi makanan asing yang tervalidasi.',
                  ),
                  const _Bullet(
                    'Selalu periksa "Daftar makanan" pada hasil scan. Jika '
                    'makananmu tidak ada di sana, foto ulang atau pilih '
                    'alternatif yang paling sesuai.',
                  ),
                  const _Bullet(
                    'Hasil dengan keyakinan sangat rendah memerlukan '
                    'konfirmasi sebelum disimpan ke diary.',
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _AboutSection(
                icon: Icons.menu_book_rounded,
                title: 'Sumber nilai gizi',
                children: <Widget>[
                  Text(
                    'Nilai gizi adalah estimasi universal per 100 g. Sebagian '
                    'kelas berlabuh pada TKPI 2017/2018 dan USDA FoodData '
                    'Central; hidangan komposit tanpa entri representatif '
                    'memakai estimasi resep standar.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _InfoRow(
                    label: 'Acuan nilai',
                    value: 'per ${info.referenceAmount} ${info.referenceUnit}',
                  ),
                  if (provenance == null)
                    Text(
                      'Informasi provenance belum tersedia di katalog ini.',
                      style: theme.textTheme.bodySmall,
                    )
                  else ...<Widget>[
                    _InfoRow(
                      label: 'Jenis data',
                      value: provenance.isEstimation
                          ? 'Estimasi, bukan data komposisi tervalidasi'
                          : provenance.sourceType,
                    ),
                    _InfoRow(
                      label: 'Tanggal verifikasi',
                      value: provenance.verifiedAt,
                    ),
                    _InfoRow(
                      label: 'Halaman sumber',
                      value: provenance.sourcePage,
                    ),
                    _SourceCodeList(provenance: provenance),
                    if (provenance.sourceUrl.isNotEmpty)
                      _InfoRow(
                        label: 'URL sumber',
                        value: provenance.sourceUrl,
                        monospace: true,
                      ),
                    if (provenance.note.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest.withValues(
                            alpha: 0.55,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          provenance.note,
                          style: theme.textTheme.bodySmall?.copyWith(
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
              const SizedBox(height: 14),
              const _AboutSection(
                icon: Icons.lock_outline_rounded,
                title: 'Privasi & penyimpanan',
                children: <Widget>[
                  _Bullet(
                    'Tidak ada izin internet, telepon, atau penyimpanan '
                    'eksternal; foto tidak diunggah.',
                  ),
                  _Bullet('Inferensi berjalan lokal dengan TensorFlow Lite.'),
                  _Bullet('Diary disimpan lokal di perangkat dengan SQLite.'),
                  _Bullet('Tidak ada akun, iklan, atau sinkronisasi cloud.'),
                ],
              ),
              const SizedBox(height: 14),
              _AboutSection(
                icon: Icons.health_and_safety_outlined,
                title: 'Disclaimer',
                children: <Widget>[
                  Text(
                    'NutriScan bukan alat medis dan tidak menggantikan '
                    'konsultasi dengan dokter atau ahli gizi. Nilai gizi dapat '
                    'berbeda tergantung resep, merek, dan ukuran porsi.',
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.6),
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

final class _AppIdentity extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      children: <Widget>[
        const BrandMark(size: 68),
        const SizedBox(height: 14),
        Text(
          'NutriScan',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Klasifikasi makanan dan estimasi gizi sepenuhnya offline.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        const OfflineBadge(),
      ],
    );
  }
}

final class _AboutSection extends StatelessWidget {
  const _AboutSection({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(icon, size: 20, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

final class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.monospace = false,
  });

  final String label;
  final String value;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 2),
          SelectableText(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: monospace ? 'monospace' : null,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

final class _SourceCodeList extends StatelessWidget {
  const _SourceCodeList({required this.provenance});

  final NutritionProvenance provenance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Kode sumber',
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              for (final source in provenance.sources)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    source,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

final class _Bullet extends StatelessWidget {
  const _Bullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(
              Icons.check_circle_rounded,
              size: 16,
              color: scheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

final class _AboutError extends StatelessWidget {
  const _AboutError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.error_outline_rounded, size: 44, color: scheme.error),
            const SizedBox(height: 14),
            Text(
              'Informasi sumber belum dapat dimuat.',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba lagi'),
            ),
          ],
        ),
      ),
    );
  }
}
