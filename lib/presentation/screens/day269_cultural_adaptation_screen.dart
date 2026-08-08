/// Day 269 — Cultural Adaptation Settings
///
/// Section D (Days 261-280): region presets for date format, 12h/24h clock,
/// first day of week, and default emergency number with live preview.
///
/// Tag: 🟢 FRONTEND-ONLY · mock PUT /api/v1/users/cultural-preferences/.
///
/// Route: [AppRoutes.culturalAdaptation] → `/cultural-adaptation`
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../navigation/app_router.dart';

// ── Constants ─────────────────────────────────────────────────────────────────
const _kAccent = Color(0xFF7C3AED);
const _kTabs = ['Presets', 'Customize', 'Info'];
const _kJsonEncoder = JsonEncoder.withIndent('  ');

enum _DateFormatStyle { ddMMyyyy, mmDDyyyy, yyyyMMdd, ddMMyyyyDot }

const _kDateFormatLabels = {
  _DateFormatStyle.ddMMyyyy: 'DD/MM/YYYY',
  _DateFormatStyle.mmDDyyyy: 'MM/DD/YYYY',
  _DateFormatStyle.yyyyMMdd: 'YYYY-MM-DD',
  _DateFormatStyle.ddMMyyyyDot: 'DD.MM.YYYY',
};

String _datePattern(_DateFormatStyle style) => switch (style) {
      _DateFormatStyle.ddMMyyyy => 'dd/MM/yyyy',
      _DateFormatStyle.mmDDyyyy => 'MM/dd/yyyy',
      _DateFormatStyle.yyyyMMdd => 'yyyy-MM-dd',
      _DateFormatStyle.ddMMyyyyDot => 'dd.MM.yyyy',
    };

const _kWeekDayLabels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

class _RegionPreset {
  const _RegionPreset({
    required this.id,
    required this.name,
    required this.flag,
    required this.dateFormat,
    required this.use24h,
    required this.firstDayOfWeek,
    required this.emergencyNumber,
    required this.emergencyLabel,
  });

  final String id;
  final String name;
  final String flag;
  final _DateFormatStyle dateFormat;
  final bool use24h;
  final int firstDayOfWeek;
  final String emergencyNumber;
  final String emergencyLabel;
}

const _kRegionPresets = [
  _RegionPreset(
    id: 'in',
    name: 'India',
    flag: '🇮🇳',
    dateFormat: _DateFormatStyle.ddMMyyyy,
    use24h: false,
    firstDayOfWeek: 1,
    emergencyNumber: '112',
    emergencyLabel: 'Unified emergency (112)',
  ),
  _RegionPreset(
    id: 'us',
    name: 'United States',
    flag: '🇺🇸',
    dateFormat: _DateFormatStyle.mmDDyyyy,
    use24h: false,
    firstDayOfWeek: 0,
    emergencyNumber: '911',
    emergencyLabel: 'Emergency services (911)',
  ),
  _RegionPreset(
    id: 'gb',
    name: 'United Kingdom',
    flag: '🇬🇧',
    dateFormat: _DateFormatStyle.ddMMyyyy,
    use24h: true,
    firstDayOfWeek: 1,
    emergencyNumber: '999',
    emergencyLabel: 'Emergency services (999)',
  ),
  _RegionPreset(
    id: 'jp',
    name: 'Japan',
    flag: '🇯🇵',
    dateFormat: _DateFormatStyle.yyyyMMdd,
    use24h: true,
    firstDayOfWeek: 0,
    emergencyNumber: '110',
    emergencyLabel: 'Police (110) · Fire/Ambulance 119',
  ),
  _RegionPreset(
    id: 'ae',
    name: 'UAE',
    flag: '🇦🇪',
    dateFormat: _DateFormatStyle.ddMMyyyy,
    use24h: false,
    firstDayOfWeek: 6,
    emergencyNumber: '999',
    emergencyLabel: 'Emergency (999)',
  ),
  _RegionPreset(
    id: 'de',
    name: 'Germany',
    flag: '🇩🇪',
    dateFormat: _DateFormatStyle.ddMMyyyyDot,
    use24h: true,
    firstDayOfWeek: 1,
    emergencyNumber: '112',
    emergencyLabel: 'EU emergency (112)',
  ),
  _RegionPreset(
    id: 'id',
    name: 'Indonesia',
    flag: '🇮🇩',
    dateFormat: _DateFormatStyle.ddMMyyyy,
    use24h: true,
    firstDayOfWeek: 1,
    emergencyNumber: '112',
    emergencyLabel: 'Emergency (112)',
  ),
  _RegionPreset(
    id: 'sa',
    name: 'Saudi Arabia',
    flag: '🇸🇦',
    dateFormat: _DateFormatStyle.ddMMyyyy,
    use24h: false,
    firstDayOfWeek: 0,
    emergencyNumber: '911',
    emergencyLabel: 'Emergency (911)',
  ),
];

class _CulturalSettings {
  const _CulturalSettings({
    this.presetId = 'in',
    this.dateFormat = _DateFormatStyle.ddMMyyyy,
    this.use24h = false,
    this.firstDayOfWeek = 1,
    this.emergencyNumber = '112',
    this.emergencyLabel = 'Unified emergency (112)',
    this.customized = false,
  });

  final String? presetId;
  final _DateFormatStyle dateFormat;
  final bool use24h;
  final int firstDayOfWeek;
  final String emergencyNumber;
  final String emergencyLabel;
  final bool customized;

  _CulturalSettings copyWith({
    String? presetId,
    _DateFormatStyle? dateFormat,
    bool? use24h,
    int? firstDayOfWeek,
    String? emergencyNumber,
    String? emergencyLabel,
    bool? customized,
    bool clearPreset = false,
  }) {
    return _CulturalSettings(
      presetId: clearPreset ? null : (presetId ?? this.presetId),
      dateFormat: dateFormat ?? this.dateFormat,
      use24h: use24h ?? this.use24h,
      firstDayOfWeek: firstDayOfWeek ?? this.firstDayOfWeek,
      emergencyNumber: emergencyNumber ?? this.emergencyNumber,
      emergencyLabel: emergencyLabel ?? this.emergencyLabel,
      customized: customized ?? this.customized,
    );
  }

  Map<String, dynamic> toJson() => {
        'preset_id': presetId,
        'date_format': _kDateFormatLabels[dateFormat],
        'use_24h_clock': use24h,
        'first_day_of_week': _kWeekDayLabels[firstDayOfWeek],
        'emergency_number': emergencyNumber,
        'emergency_label': emergencyLabel,
        'customized': customized,
      };
}

// ── Providers ─────────────────────────────────────────────────────────────────
final _d269TabProvider = StateProvider<int>((ref) => 0);
final _d269SettingsProvider =
    StateProvider<_CulturalSettings>((ref) => const _CulturalSettings());
final _d269SavedProvider = StateProvider<bool>((ref) => false);

void _applyPreset(WidgetRef ref, _RegionPreset preset) {
  ref.read(_d269SettingsProvider.notifier).state = _CulturalSettings(
    presetId: preset.id,
    dateFormat: preset.dateFormat,
    use24h: preset.use24h,
    firstDayOfWeek: preset.firstDayOfWeek,
    emergencyNumber: preset.emergencyNumber,
    emergencyLabel: preset.emergencyLabel,
    customized: false,
  );
  ref.read(_d269SavedProvider.notifier).state = false;
}

String _formatPreviewDate(_CulturalSettings settings) {
  final now = DateTime.now();
  return DateFormat(_datePattern(settings.dateFormat)).format(now);
}

String _formatPreviewTime(_CulturalSettings settings) {
  final now = DateTime.now();
  return settings.use24h
      ? DateFormat('HH:mm').format(now)
      : DateFormat('h:mm a').format(now);
}

// ── Screen ────────────────────────────────────────────────────────────────────
class Day269CulturalAdaptationScreen extends ConsumerWidget {
  const Day269CulturalAdaptationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_d269TabProvider);
    final settings = ref.watch(_d269SettingsProvider);
    final saved = ref.watch(_d269SavedProvider);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 269 · Cultural Adaptation'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: ZapSpacing.md),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: ZapSpacing.sm, vertical: ZapSpacing.xs),
                decoration: BoxDecoration(
                  color: (saved ? ZapColors.safe : _kAccent).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color:
                        (saved ? ZapColors.safe : _kAccent).withOpacity(0.45),
                  ),
                ),
                child: Text(
                  saved
                      ? 'SAVED ✅'
                      : settings.customized
                          ? 'CUSTOM'
                          : settings.presetId?.toUpperCase() ?? '—',
                  style: TextStyle(
                    color: saved ? ZapColors.safe : _kAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _TabBar(
            tab: tab,
            onSelect: (i) => ref.read(_d269TabProvider.notifier).state = i,
          ),
          Expanded(
            child: switch (tab) {
              0 => const _PresetsTab(),
              1 => const _CustomizeTab(),
              _ => const _InfoTab(),
            },
          ),
        ],
      ),
    );
  }
}

// ── Tab 0: Presets ────────────────────────────────────────────────────────────
class _PresetsTab extends ConsumerWidget {
  const _PresetsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(_d269SettingsProvider);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _kAccent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _kAccent.withOpacity(0.35)),
          ),
          child: const Text(
            '🟢 FRONTEND-ONLY · Section D Day 9/20 · region presets · live preview',
            style: TextStyle(color: _kAccent, fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        _LivePreviewCard(settings: settings),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Region presets',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        ..._kRegionPresets.map((preset) {
          final active = settings.presetId == preset.id && !settings.customized;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: active ? _kAccent.withOpacity(0.08) : ZapColors.bgCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: active ? _kAccent.withOpacity(0.45) : ZapColors.border,
              ),
            ),
            child: ListTile(
              leading: Text(preset.flag, style: const TextStyle(fontSize: 24)),
              title: Text(
                preset.name,
                style: TextStyle(
                  color: ZapColors.textPrimary,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
              subtitle: Text(
                '${_kDateFormatLabels[preset.dateFormat]} · '
                '${preset.use24h ? '24h' : '12h'} · '
                'Week starts ${_kWeekDayLabels[preset.firstDayOfWeek]} · '
                '${preset.emergencyNumber}',
                style: const TextStyle(
                  color: ZapColors.textSecondary,
                  fontSize: 11,
                ),
              ),
              trailing: active
                  ? const Icon(Icons.check_circle_rounded, color: _kAccent)
                  : const Icon(Icons.chevron_right_rounded),
              onTap: () {
                _applyPreset(ref, preset);
                HapticFeedback.lightImpact();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${preset.name} preset applied.')),
                );
              },
            ),
          );
        }),
      ],
    );
  }
}

class _LivePreviewCard extends StatelessWidget {
  const _LivePreviewCard({required this.settings});

  final _CulturalSettings settings;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kAccent.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Live preview',
            style: TextStyle(
              color: _kAccent,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: ZapSpacing.sm),
          _PreviewRow(label: 'Date', value: _formatPreviewDate(settings)),
          _PreviewRow(label: 'Time', value: _formatPreviewTime(settings)),
          _PreviewRow(
            label: 'Calendar',
            value: 'Week starts ${_kWeekDayLabels[settings.firstDayOfWeek]}',
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: ZapColors.danger.withOpacity(0.1),
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              border: Border.all(color: ZapColors.danger.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.emergency_rounded,
                    color: ZapColors.danger, size: 18),
                const SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        settings.emergencyNumber,
                        style: const TextStyle(
                          color: ZapColors.danger,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        settings.emergencyLabel,
                        style: const TextStyle(
                          color: ZapColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(color: ZapColors.textMuted, fontSize: 11),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab 1: Customize ──────────────────────────────────────────────────────────
class _CustomizeTab extends ConsumerWidget {
  const _CustomizeTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(_d269SettingsProvider);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        _LivePreviewCard(settings: settings),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Date format',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _DateFormatStyle.values.map((style) {
            final selected = settings.dateFormat == style;
            return ChoiceChip(
              label: Text(_kDateFormatLabels[style]!),
              selected: selected,
              selectedColor: _kAccent.withOpacity(0.2),
              onSelected: (_) {
                ref.read(_d269SettingsProvider.notifier).state =
                    settings.copyWith(
                  dateFormat: style,
                  customized: true,
                  clearPreset: true,
                );
                ref.read(_d269SavedProvider.notifier).state = false;
              },
            );
          }).toList(),
        ),
        const SizedBox(height: ZapSpacing.lg),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            '24-hour clock',
            style: TextStyle(color: ZapColors.textPrimary),
          ),
          subtitle: Text(
            settings.use24h ? 'Showing 24h format' : 'Showing 12h AM/PM',
            style:
                const TextStyle(color: ZapColors.textSecondary, fontSize: 11),
          ),
          value: settings.use24h,
          activeColor: _kAccent,
          onChanged: (v) {
            ref.read(_d269SettingsProvider.notifier).state = settings.copyWith(
              use24h: v,
              customized: true,
              clearPreset: true,
            );
            ref.read(_d269SavedProvider.notifier).state = false;
          },
        ),
        const SizedBox(height: ZapSpacing.md),
        const Text(
          'First day of week',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: List.generate(7, (i) {
            final selected = settings.firstDayOfWeek == i;
            return ChoiceChip(
              label: Text(_kWeekDayLabels[i]),
              selected: selected,
              selectedColor: _kAccent.withOpacity(0.2),
              onSelected: (_) {
                ref.read(_d269SettingsProvider.notifier).state =
                    settings.copyWith(
                  firstDayOfWeek: i,
                  customized: true,
                  clearPreset: true,
                );
                ref.read(_d269SavedProvider.notifier).state = false;
              },
            );
          }),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Default emergency number',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        TextFormField(
          key: ValueKey('num-${settings.presetId}-${settings.emergencyNumber}'),
          initialValue: settings.emergencyNumber,
          decoration: const InputDecoration(
            labelText: 'Emergency number',
            hintText: 'e.g. 112, 911, 999',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.phone,
          onChanged: (v) {
            ref.read(_d269SettingsProvider.notifier).state = settings.copyWith(
              emergencyNumber: v.trim().isEmpty ? settings.emergencyNumber : v,
              customized: true,
              clearPreset: true,
            );
            ref.read(_d269SavedProvider.notifier).state = false;
          },
        ),
        const SizedBox(height: ZapSpacing.sm),
        TextFormField(
          key:
              ValueKey('label-${settings.presetId}-${settings.emergencyLabel}'),
          initialValue: settings.emergencyLabel,
          decoration: const InputDecoration(
            labelText: 'Label shown in app',
            border: OutlineInputBorder(),
          ),
          onChanged: (v) {
            ref.read(_d269SettingsProvider.notifier).state = settings.copyWith(
              emergencyLabel: v,
              customized: true,
              clearPreset: true,
            );
            ref.read(_d269SavedProvider.notifier).state = false;
          },
        ),
        const SizedBox(height: ZapSpacing.lg),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  _applyPreset(ref, _kRegionPresets.first);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Reset to India preset.')),
                  );
                },
                child: const Text('Reset to India'),
              ),
            ),
            const SizedBox(width: ZapSpacing.sm),
            Expanded(
              child: FilledButton(
                onPressed: () {
                  ref.read(_d269SavedProvider.notifier).state = true;
                  HapticFeedback.mediumImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Cultural preferences saved (mock) · PUT cultural-preferences',
                      ),
                    ),
                  );
                },
                style: FilledButton.styleFrom(backgroundColor: ZapColors.safe),
                child: const Text('Save (mock)'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Tab 2: Info ───────────────────────────────────────────────────────────────
class _InfoTab extends ConsumerWidget {
  const _InfoTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(_d269SettingsProvider);
    final saved = ref.watch(_d269SavedProvider);

    final payload = {
      'endpoint': 'PUT /api/v1/users/cultural-preferences/',
      'body': settings.toJson(),
      'saved': saved,
      'presets_available': _kRegionPresets.map((p) => p.id).toList(),
      'fields': [
        'date_format',
        'use_24h_clock',
        'first_day_of_week',
        'emergency_number',
        'emergency_label',
      ],
      'notes':
          'SOS screen dial shortcut uses emergency_number · calendar widgets '
              'honour first_day_of_week · timestamps use use_24h_clock',
    };

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const _PolicyRow(
          icon: Icons.public_rounded,
          title: 'Region presets',
          subtitle:
              '8 launch regions with date/time/calendar/emergency defaults · '
              'one tap apply · India default for ZapSafe primary market.',
        ),
        const _PolicyRow(
          icon: Icons.tune_rounded,
          title: 'Customize tab',
          subtitle:
              'Override any field independently · marks profile as customized · '
              'mock save via PUT cultural-preferences endpoint.',
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'API contract (mock)',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: ZapColors.border),
          ),
          child: SelectableText(
            _kJsonEncoder.convert(payload),
            style: const TextStyle(
              color: ZapColors.textSecondary,
              fontSize: 10,
              fontFamily: 'monospace',
              height: 1.45,
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        OutlinedButton.icon(
          onPressed: () {
            Clipboard.setData(
              ClipboardData(text: _kJsonEncoder.convert(payload)),
            );
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Cultural preferences spec copied.')),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copy preferences spec'),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.info.withOpacity(0.1),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: ZapColors.info.withOpacity(0.3)),
          ),
          child: const Text(
            'Next: Day 365 — Global Launch Milestone '
            '(Phase 2 finale · worldwide rollout).',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 13),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              label: const Text('Day 268 QA Runner'),
              onPressed: () => context.push(AppRoutes.multilangQaRunner),
            ),
            ActionChip(
              label: const Text('Day 261 Language Hub'),
              onPressed: () => context.push(AppRoutes.languageExpansionHub),
            ),
            ActionChip(
              label: const Text('Day 239 India Launch'),
              onPressed: () => context.push(AppRoutes.indiaLaunchReadiness),
            ),
          ],
        ),
      ],
    );
  }
}

class _PolicyRow extends StatelessWidget {
  const _PolicyRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ZapSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: _kAccent),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: ZapColors.textSecondary,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.tab, required this.onSelect});

  final int tab;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ZapColors.bgCard,
      child: Row(
        children: List.generate(_kTabs.length, (i) {
          final selected = tab == i;
          return Expanded(
            child: InkWell(
              onTap: () => onSelect(i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: ZapSpacing.md),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: selected ? _kAccent : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  _kTabs[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected ? _kAccent : ZapColors.textMuted,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
