import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/brand_mark.dart';
import '../../domain/entities/user_profile.dart';
import '../providers/user_profile_providers.dart';

/// Simple profile screen to manage user's physical stats for TDEE calculation.
final class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Profil & Target Kalori')),
      body: SafeArea(
        child: profile.when(
          data: (UserProfile value) => _ProfileContent(profile: value),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object error, StackTrace stackTrace) => _ProfileLoadError(
            onRetry: () => ref.invalidate(userProfileProvider),
          ),
        ),
      ),
    );
  }
}

final class _ProfileContent extends StatelessWidget {
  const _ProfileContent({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final tdee = profile.tdee;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _ProfileHeader(tdee: tdee),
              const SizedBox(height: 16),
              _ProfileForm(profile: profile),
              const SizedBox(height: 16),
              _TdeeExplanationCard(tdee: tdee),
            ],
          ),
        ),
      ),
    );
  }
}

final class _ProfileLoadError extends StatelessWidget {
  const _ProfileLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.error_outline_rounded, size: 40),
            const SizedBox(height: 12),
            const Text('Profil tidak dapat dimuat.'),
            const SizedBox(height: 12),
            FilledButton.icon(
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

final class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.tdee});

  final double tdee;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: <Widget>[
            const BrandMark(size: 56),
            const SizedBox(height: 12),
            Text(
              'Profil Pengguna',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Data ini digunakan untuk menghitung kebutuhan kalori harian (TDEE) '
              'dan menyesuaikan rekomendasi olahraga.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Icon(
                    Icons.local_fire_department_rounded,
                    color: theme.extension<MacroColors>()!.calories,
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Target Harian (TDEE)',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        formatKcal(tdee),
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: theme.extension<MacroColors>()!.calories,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
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

final class _ProfileForm extends ConsumerStatefulWidget {
  const _ProfileForm({required this.profile});

  final UserProfile profile;

  @override
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<_ProfileForm> {
  late final TextEditingController _weightCtrl;
  late final TextEditingController _heightCtrl;
  late final TextEditingController _ageCtrl;
  late Gender _gender;
  late ActivityLevel _activityLevel;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    _weightCtrl = TextEditingController(
      text: profile.weightKg.toStringAsFixed(1),
    );
    _heightCtrl = TextEditingController(
      text: profile.heightCm.toStringAsFixed(0),
    );
    _ageCtrl = TextEditingController(text: profile.age.toString());
    _gender = profile.gender;
    _activityLevel = profile.activityLevel;
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    _ageCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final weight = double.tryParse(
      _weightCtrl.text.trim().replaceAll(',', '.'),
    );
    final height = double.tryParse(
      _heightCtrl.text.trim().replaceAll(',', '.'),
    );
    final age = int.tryParse(_ageCtrl.text.trim());

    if (weight == null ||
        weight < 20 ||
        weight > 300 ||
        height == null ||
        height < 50 ||
        height > 250 ||
        age == null ||
        age < 5 ||
        age > 120) {
      _showMessage('Masukkan berat, tinggi, dan usia yang valid.');
      return;
    }

    setState(() => _saving = true);
    try {
      await ref
          .read(userProfileProvider.notifier)
          .updateProfile(
            weightKg: weight,
            heightCm: height,
            age: age,
            gender: _gender,
            activityLevel: _activityLevel,
          );
      if (!mounted) return;
      _showMessage('Profil tersimpan.');
    } catch (_) {
      if (!mounted) return;
      _showMessage('Gagal menyimpan profil. Coba lagi.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final weightCtrl = _weightCtrl;
    final heightCtrl = _heightCtrl;
    final ageCtrl = _ageCtrl;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Data Fisik',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextFormField(
                    controller: weightCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Berat (kg)',
                      suffixText: 'kg',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: heightCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Tinggi (cm)',
                      suffixText: 'cm',
                    ),
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextFormField(
                    controller: ageCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Usia (tahun)',
                    ),
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<Gender>(
                    initialValue: _gender,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Jenis Kelamin',
                    ),
                    items: const <DropdownMenuItem<Gender>>[
                      DropdownMenuItem<Gender>(
                        value: Gender.male,
                        child: Text('Pria'),
                      ),
                      DropdownMenuItem<Gender>(
                        value: Gender.female,
                        child: Text('Wanita'),
                      ),
                    ],
                    onChanged: (Gender? value) {
                      if (value != null) setState(() => _gender = value);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<ActivityLevel>(
              initialValue: _activityLevel,
              decoration: const InputDecoration(labelText: 'Aktivitas'),
              isExpanded: true,
              items: ActivityLevel.values
                  .map(
                    (ActivityLevel level) => DropdownMenuItem<ActivityLevel>(
                      value: level,
                      child: Text(level.label),
                    ),
                  )
                  .toList(),
              onChanged: (ActivityLevel? value) {
                if (value != null) {
                  setState(() => _activityLevel = value);
                }
              },
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_activityLevel.description} Target harian memakai '
                      '${_activityLevel.multiplierLabel} dari BMR.',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving ? null : _saveProfile,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(_saving ? 'Menyimpan…' : 'Simpan Profil'),
            ),
          ],
        ),
      ),
    );
  }
}

final class _TdeeExplanationCard extends StatelessWidget {
  const _TdeeExplanationCard({required this.tdee});

  final double tdee;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      color: scheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: scheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Cara Kerja Perhitungan',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '• BMR (Basal Metabolic Rate): Kalori yang dibutuhkan tubuh saat istirahat total. '
              'Dihitung dengan rumus Mifflin-St Jeor.\n'
              '• TDEE (Total Daily Energy Expenditure): BMR × Faktor Aktivitas. '
              'Ini adalah estimasi kalori yang dibakar sehari-hari.\n'
              '• Target harianmu: ${formatKcal(tdee)}.\n'
              '• Jika makan melebihi target, aplikasi akan merekomendasikan olahraga '
              'untuk membakar kelebihannya.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Catatan: Perhitungan ini adalah estimasi. Kebutuhan aktual bervariasi '
              'berdasarkan komposisi tubuh, genetik, dan kondisi kesehatan. '
              'Konsultasikan dengan ahli gizi untuk rencana yang personal.',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
