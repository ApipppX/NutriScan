import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/widgets/brand_mark.dart';
import '../core/widgets/offline_badge.dart';
import '../features/food_scan/presentation/providers/scan_providers.dart';
import '../features/food_scan/presentation/screens/scanner_screen.dart';

/// Root gate that loads model + nutrition metadata before showing the scanner.
final class AppBootstrapGate extends ConsumerWidget {
  const AppBootstrapGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrap = ref.watch(appBootstrapProvider);
    return bootstrap.when(
      data: (_) => const ScannerScreen(),
      loading: () => const _BootstrapSplash(),
      error: (error, stackTrace) => _BootstrapError(
        error: error,
        onRetry: () {
          ref.invalidate(foodClassifierProvider);
          ref.invalidate(nutritionRepositoryProvider);
          ref.invalidate(appBootstrapProvider);
        },
      ),
    );
  }
}

final class _BootstrapSplash extends StatelessWidget {
  const _BootstrapSplash();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  scheme.surface,
                  scheme.primaryContainer.withValues(alpha: 0.26),
                  scheme.surface,
                ],
              ),
            ),
          ),
          Positioned(
            top: -80,
            right: -70,
            child: _GlowCircle(
              size: 240,
              color: scheme.primary.withValues(alpha: 0.09),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -90,
            child: _GlowCircle(
              size: 280,
              color: scheme.tertiary.withValues(alpha: 0.07),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: <Widget>[
                  const Spacer(),
                  const BrandMark(size: 78),
                  const SizedBox(height: 24),
                  Text(
                    'NutriScan',
                    style: textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Kenali makanan. Ketahui gizinya.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 36),
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Menyiapkan model di perangkat…',
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  const OfflineBadge(),
                  const SizedBox(height: 18),
                  Text(
                    'Foto diproses secara lokal. Tidak ada data yang dikirim.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 22),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final class _BootstrapError extends StatelessWidget {
  const _BootstrapError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: scheme.errorContainer,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(
                      Icons.memory_rounded,
                      size: 36,
                      color: scheme.onErrorContainer,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Model belum siap',
                    textAlign: TextAlign.center,
                    style: textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Aplikasi tidak dapat memuat model AI di perangkat ini. '
                    'Pastikan aset model dan metadata sudah terpasang dengan benar.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Coba lagi'),
                    ),
                  ),
                  if (kDebugMode) ...<Widget>[
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'DEBUG DETAIL',
                            style: textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SelectableText(
                            error.toString(),
                            style: textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class _GlowCircle extends StatelessWidget {
  const _GlowCircle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}
