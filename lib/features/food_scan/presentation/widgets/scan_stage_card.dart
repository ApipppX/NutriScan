import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../state/scan_state.dart';

/// Hero card that hosts the photo, live camera/gallery actions, and the
/// scanning animation. It intentionally owns no business logic.
final class ScanStageCard extends StatelessWidget {
  const ScanStageCard({
    super.key,
    required this.state,
    required this.onCamera,
    required this.onGallery,
  });

  final ScanState state;
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context) {
    final imageBytes = state.imageBytes;
    final isIdle = state is ScanIdle;
    final isProcessing = state is ScanProcessing;
    final isSuccess = state is ScanSuccessState;
    final isFailure = state is ScanFailureState;
    final scheme = Theme.of(context).colorScheme;
    final stageColors = AppTheme.stageGradient(scheme);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final height = (constraints.maxWidth * 0.84).clamp(300.0, 380.0);
        return Semantics(
          container: true,
          image: imageBytes != null,
          label: switch (state) {
            ScanIdle() => 'Area pemindaian. Ambil foto atau pilih dari galeri.',
            ScanProcessing() => 'Sedang menganalisis foto makanan.',
            ScanSuccessState() => 'Foto makanan yang telah dianalisis.',
            ScanFailureState() => 'Pemindaian gagal.',
          },
          child: Container(
            height: height,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: stageColors,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: stageColors.first.withValues(alpha: 0.32),
                  blurRadius: 32,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                if (imageBytes != null)
                  Image.memory(
                    imageBytes,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    filterQuality: FilterQuality.medium,
                    semanticLabel: 'Foto makanan',
                    errorBuilder: (_, _, _) => const _EmptyStage(
                      icon: Icons.broken_image_outlined,
                      title: 'Foto tidak dapat ditampilkan',
                      subtitle: 'Coba pilih foto lain.',
                    ),
                  )
                else
                  _EmptyStage(
                    icon: isFailure
                        ? Icons.image_not_supported_outlined
                        : Icons.camera_alt_rounded,
                    title: isFailure
                        ? 'Foto tidak tersedia'
                        : 'Ambil foto makananmu',
                    subtitle: isFailure
                        ? 'Pilih foto lain untuk mencoba lagi.'
                        : 'Pastikan seluruh piring terlihat dan cahaya cukup.',
                  ),
                const Positioned.fill(child: _StageScrim()),
                if (imageBytes != null)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(painter: _ViewfinderPainter()),
                    ),
                  ),
                if (isProcessing)
                  const Positioned.fill(child: ScanningOverlay()),
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Row(
                    children: <Widget>[
                      _StatusPill(
                        isProcessing: isProcessing,
                        isSuccess: isSuccess,
                        isFailure: isFailure,
                      ),
                      const Spacer(),
                      if (isSuccess) const _ResultGlyph(),
                    ],
                  ),
                ),
                if (isIdle)
                  Positioned(
                    left: 18,
                    right: 18,
                    bottom: 18,
                    child: _IdleActions(
                      onCamera: onCamera,
                      onGallery: onGallery,
                    ),
                  ),
                if (isProcessing)
                  const Positioned(
                    left: 18,
                    right: 18,
                    bottom: 18,
                    child: _ProcessingFooter(),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

final class _EmptyStage extends StatelessWidget {
  const _EmptyStage({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final accent = AppTheme.stageAccent(scheme);
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        const _StageGlow(),
        Positioned(
          top: -54,
          right: -40,
          child: _Ring(size: 190, opacity: 0.08),
        ),
        Positioned(
          bottom: -74,
          left: -54,
          child: _Ring(size: 230, opacity: 0.055),
        ),
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(34, 44, 34, 100),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent.withValues(alpha: 0.12),
                    border: Border.all(color: accent.withValues(alpha: 0.3)),
                  ),
                  child: Icon(icon, size: 31, color: accent),
                ),
                const SizedBox(height: 15),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.68),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

final class _StageGlow extends StatelessWidget {
  const _StageGlow();

  @override
  Widget build(BuildContext context) {
    final glow = AppTheme.stageAccent(Theme.of(context).colorScheme);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0.35, -0.75),
          radius: 1.1,
          colors: <Color>[glow.withValues(alpha: 0.18), Colors.transparent],
        ),
      ),
    );
  }
}

final class _StageScrim extends StatelessWidget {
  const _StageScrim();

  @override
  Widget build(BuildContext context) {
    final veil = AppTheme.stageGradient(Theme.of(context).colorScheme).first;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Colors.black.withValues(alpha: 0.42),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.12),
            veil.withValues(alpha: 0.84),
          ],
          stops: const <double>[0, 0.26, 0.58, 1],
        ),
      ),
    );
  }
}

final class _Ring extends StatelessWidget {
  const _Ring({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: opacity),
          width: 1.2,
        ),
      ),
    );
  }
}

final class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.isProcessing,
    required this.isSuccess,
    required this.isFailure,
  });

  final bool isProcessing;
  final bool isSuccess;
  final bool isFailure;

  @override
  Widget build(BuildContext context) {
    final (IconData? icon, String label) = switch ((
      isProcessing,
      isSuccess,
      isFailure,
    )) {
      (true, _, _) => (null, 'MENGANALISIS'),
      (_, true, _) => (Icons.check_circle_rounded, 'HASIL ANALISIS'),
      (_, _, true) => (Icons.error_outline_rounded, 'BELUM BERHASIL'),
      _ => (Icons.auto_awesome_rounded, 'SIAP MEMINDAI'),
    };
    final scheme = Theme.of(context).colorScheme;
    final accent = AppTheme.stageAccent(scheme);
    final pillColor = AppTheme.stageGradient(scheme).first;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: pillColor.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.26)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (isProcessing)
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2, color: accent),
            )
          else
            Icon(icon, size: 14, color: accent),
          const SizedBox(width: 7),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
            ),
          ),
        ],
      ),
    );
  }
}

final class _ResultGlyph extends StatelessWidget {
  const _ResultGlyph();

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.stageAccent(Theme.of(context).colorScheme);
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(color: accent.withValues(alpha: 0.24)),
      ),
      child: Icon(Icons.restaurant_rounded, size: 17, color: accent),
    );
  }
}

final class _IdleActions extends StatelessWidget {
  const _IdleActions({required this.onCamera, required this.onGallery});

  final VoidCallback onCamera;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cameraBackground = Color.lerp(scheme.primary, Colors.white, 0.84)!;
    final cameraForeground = Color.lerp(scheme.primary, Colors.black, 0.74)!;

    return Row(
      children: <Widget>[
        Expanded(
          child: FilledButton.icon(
            onPressed: onCamera,
            style: FilledButton.styleFrom(
              backgroundColor: cameraBackground,
              foregroundColor: cameraForeground,
              minimumSize: const Size(0, 54),
              elevation: 0,
              shadowColor: Colors.transparent,
            ),
            icon: const Icon(Icons.photo_camera_rounded, size: 20),
            label: const Text('Kamera'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onGallery,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 54),
              backgroundColor: Colors.black.withValues(alpha: 0.16),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.34)),
            ),
            icon: const Icon(Icons.photo_library_outlined, size: 19),
            label: const Text('Galeri'),
          ),
        ),
      ],
    );
  }
}

final class _ProcessingFooter extends StatelessWidget {
  const _ProcessingFooter();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final accent = AppTheme.stageAccent(theme.colorScheme);
    final veil = AppTheme.stageGradient(theme.colorScheme).first;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: veil.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2.2, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Mengenali makanan & menghitung gizi…',
              style: textTheme.bodySmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            'on-device',
            style: textTheme.labelSmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.48),
            ),
          ),
        ],
      ),
    );
  }
}

/// Moving scan line with a soft green trail.
final class ScanningOverlay extends StatefulWidget {
  const ScanningOverlay({super.key});

  @override
  State<ScanningOverlay> createState() => _ScanningOverlayState();
}

final class _ScanningOverlayState extends State<ScanningOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.stageAccent(Theme.of(context).colorScheme);
    final lineColor = Color.lerp(accent, Colors.white, 0.35)!;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          final progress = Curves.easeInOutCubic.transform(_controller.value);
          final y = -0.86 + (1.72 * progress);
          return Align(
            alignment: Alignment(0, y),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  height: 96,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        Colors.transparent,
                        accent.withValues(alpha: 0.2),
                      ],
                    ),
                  ),
                ),
                Container(
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 22),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[
                        accent.withValues(alpha: 0),
                        lineColor,
                        accent.withValues(alpha: 0),
                      ],
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: lineColor.withValues(alpha: 0.7),
                        blurRadius: 14,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Subtle viewfinder corner brackets drawn over a captured image.
final class _ViewfinderPainter extends CustomPainter {
  const _ViewfinderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    const inset = 18.0;
    const arm = 22.0;
    final left = inset;
    final top = inset + 36;
    final right = size.width - inset;
    final bottom = size.height - inset - 10;

    final path = Path()
      ..moveTo(left, top + arm)
      ..lineTo(left, top)
      ..lineTo(left + arm, top)
      ..moveTo(right - arm, top)
      ..lineTo(right, top)
      ..lineTo(right, top + arm)
      ..moveTo(right, bottom - arm)
      ..lineTo(right, bottom)
      ..lineTo(right - arm, bottom)
      ..moveTo(left + arm, bottom)
      ..lineTo(left, bottom)
      ..lineTo(left, bottom - arm);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
