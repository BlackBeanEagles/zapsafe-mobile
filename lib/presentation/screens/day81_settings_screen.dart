/// Day 81 — Settings Screen
///
/// Master hub for all user-configurable preferences.
///
/// ── Sections ──────────────────────────────────────────────────────────────────
///   • Profile       — display name (inline edit), language (15 locales)
///   • Notifications — links to DND (Day 73) + notification prefs (Day 67)
///   • Detection     — DCS sensitivity segmented control, alert thresholds,
///                     escalation policy links
///   • Security      — SOS templates, audit log, data export, privacy links
///   • Device info   — app version, device tier, build hash, reset settings
///
/// All values read/write via Riverpod providers in settings_providers.dart.
/// API integration: PUT /api/v1/users/preferences/ wired in Month 4.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../domain/providers/settings_providers.dart';
import '../navigation/app_router.dart';

// ─── Language metadata ────────────────────────────────────────────────────────

const _kLanguages = [
  ('en', 'English'),
  ('hi', 'हिन्दी'),
  ('ta', 'தமிழ்'),
  ('te', 'తెలుగు'),
  ('ml', 'മലയാളം'),
  ('bn', 'বাংলা'),
  ('mr', 'मराठी'),
  ('gu', 'ગુજરાતી'),
  ('pa', 'ਪੰਜਾਬੀ'),
  ('ur', 'اردو'),
  ('ar', 'العربية'),
  ('es', 'Español'),
  ('fr', 'Français'),
  ('pt', 'Português'),
  ('de', 'Deutsch'),
];

// ─── Mock device info ─────────────────────────────────────────────────────────

const _kAppVersion   = '1.0.0+81';
const _kBuildHash    = '2026.05.28.0001';
const _kDeviceTier   = 'Performance';   // Hydrated from device_providers Day 13

// ─── Screen ───────────────────────────────────────────────────────────────────

class Day81SettingsScreen extends ConsumerStatefulWidget {
  const Day81SettingsScreen({super.key});

  @override
  ConsumerState<Day81SettingsScreen> createState() =>
      _Day81SettingsScreenState();
}

class _Day81SettingsScreenState extends ConsumerState<Day81SettingsScreen> {

  late final TextEditingController _nameCtrl;
  bool _editingName = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(
      text: ref.read(displayNameProvider),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _saveName() {
    final trimmed = _nameCtrl.text.trim();
    if (trimmed.isNotEmpty) {
      ref.read(displayNameProvider.notifier).state = trimmed;
    } else {
      _nameCtrl.text = ref.read(displayNameProvider);
    }
    setState(() => _editingName = false);
    FocusScope.of(context).unfocus();
  }

  void _resetSettings() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ZapColors.bgElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Reset all settings?',
          style: ZapTypography.headlineSmall.copyWith(color: ZapColors.textPrimary),
        ),
        content: Text(
          'This will restore all preferences to their default values. '
          'Your SOS contacts and templates are not affected.',
          style: ZapTypography.bodyMedium.copyWith(
            color: ZapColors.textSecondary, height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Cancel',
              style: ZapTypography.labelMedium.copyWith(
                color: ZapColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              ref.read(displayNameProvider.notifier).state    = 'ZapSafe User';
              ref.read(selectedLanguageProvider.notifier).state = 'en';
              ref.read(dcsSensitivityProvider.notifier).state  = DcsSensitivity.medium;
              ref.read(highContrastProvider.notifier).state    = false;
              ref.read(fontScaleProvider.notifier).state       = 1.0;
              _nameCtrl.text = 'ZapSafe User';
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: ZapColors.bgElevated,
                  behavior:        SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  content: Text(
                    'Settings reset to defaults',
                    style: ZapTypography.bodyMedium.copyWith(
                      color: ZapColors.textPrimary,
                    ),
                  ),
                ),
              );
            },
            child: Text(
              'Reset',
              style: ZapTypography.labelMedium.copyWith(color: ZapColors.danger),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name       = ref.watch(displayNameProvider);
    final lang       = ref.watch(selectedLanguageProvider);
    final dcs        = ref.watch(dcsSensitivityProvider);
    final hiContrast = ref.watch(highContrastProvider);
    final fontScale  = ref.watch(fontScaleProvider);

    final langName = _kLanguages
        .firstWhere((l) => l.$1 == lang, orElse: () => const ('en', 'English'))
        .$2;

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        backgroundColor:  ZapColors.bgPrimary,
        elevation:        0,
        surfaceTintColor: Colors.transparent,
        leading: const BackButton(color: ZapColors.textPrimary),
        title: Text(
          'Settings',
          style: ZapTypography.headlineSmall.copyWith(color: ZapColors.textPrimary),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(
          top: ZapSpacing.sm,
          bottom: ZapSpacing.xxxl * 2,
        ),
        children: [

          // ── PROFILE ──────────────────────────────────────────────────────
          const _SectionHeader(title: 'PROFILE'),

          // Display name
          _SettingsTile(
            icon:    Icons.person_outline_rounded,
            accent:  ZapColors.info,
            title:   'Display name',
            trailing: _editingName
                ? _NameEditRow(
                    ctrl:    _nameCtrl,
                    onSave:  _saveName,
                    onCancel: () {
                      _nameCtrl.text = name;
                      setState(() => _editingName = false);
                      FocusScope.of(context).unfocus();
                    },
                  )
                : GestureDetector(
                    onTap: () => setState(() => _editingName = true),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          name,
                          style: ZapTypography.bodyMedium.copyWith(
                            color: ZapColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: ZapSpacing.xs),
                        const Icon(
                          Icons.edit_outlined,
                          size:  14,
                          color: ZapColors.textMuted,
                        ),
                      ],
                    ),
                  ),
          ),

          // Language
          _LanguageTile(
            current:  langName,
            onChanged: (code) =>
                ref.read(selectedLanguageProvider.notifier).state = code,
          ),

          const SizedBox(height: ZapSpacing.lg),

          // ── NOTIFICATIONS ─────────────────────────────────────────────────
          const _SectionHeader(title: 'NOTIFICATIONS'),

          const _NavSettingsTile(
            icon:     Icons.do_not_disturb_on_outlined,
            accent:   ZapColors.warning,
            title:    'Do Not Disturb',
            subtitle: 'Quiet hours and SOS bypass',
            route:    AppRoutes.doNotDisturb,
          ),

          const _NavSettingsTile(
            icon:     Icons.notifications_outlined,
            accent:   ZapColors.info,
            title:    'Notification preferences',
            subtitle: 'Per-category push & SMS toggles',
            route:    AppRoutes.notificationPrefs,
          ),

          const SizedBox(height: ZapSpacing.lg),

          // ── DETECTION ─────────────────────────────────────────────────────
          const _SectionHeader(title: 'DETECTION'),

          // DCS sensitivity
          _DcsSensitivityTile(
            value:     dcs,
            onChanged: (v) =>
                ref.read(dcsSensitivityProvider.notifier).state = v,
          ),

          const _NavSettingsTile(
            icon:     Icons.tune_rounded,
            accent:   ZapColors.danger,
            title:    'Alert thresholds',
            subtitle: 'Per-model confidence levels',
            route:    AppRoutes.alertThresholds,
          ),

          const _NavSettingsTile(
            icon:     Icons.account_tree_outlined,
            accent:   ZapColors.warning,
            title:    'Escalation policy',
            subtitle: 'Tier timeouts and auto-911',
            route:    AppRoutes.escalationPolicies,
          ),

          const SizedBox(height: ZapSpacing.lg),

          // ── SECURITY & PRIVACY ────────────────────────────────────────────
          const _SectionHeader(title: 'SECURITY & PRIVACY'),

          const _NavSettingsTile(
            icon:     Icons.message_outlined,
            accent:   ZapColors.safe,
            title:    'SOS message templates',
            subtitle: 'Customize dispatch messages',
            route:    AppRoutes.sosTemplates,
          ),

          const _NavSettingsTile(
            icon:     Icons.history_rounded,
            accent:   ZapColors.textSecondary,
            title:    'Activity audit log',
            subtitle: 'Append-only event history',
            route:    AppRoutes.auditLog,
          ),

          const _NavSettingsTile(
            icon:     Icons.download_outlined,
            accent:   ZapColors.info,
            title:    'Export my data',
            subtitle: 'GDPR data snapshot (7-day link)',
            route:    AppRoutes.dataExport,
          ),

          const _NavSettingsTile(
            icon:     Icons.shield_outlined,
            accent:   ZapColors.safe,
            title:    'Privacy & consent',
            subtitle: 'Analytics, evidence, deletion',
            route:    AppRoutes.privacy,
          ),

          const SizedBox(height: ZapSpacing.lg),

          // ── ACCESSIBILITY ─────────────────────────────────────────────────
          const _SectionHeader(title: 'ACCESSIBILITY'),

          _SwitchTile(
            icon:     Icons.contrast_rounded,
            accent:   ZapColors.warning,
            title:    'High contrast mode',
            subtitle: 'WCAG AAA 21:1 ratio UI',
            value:    hiContrast,
            onChanged: (v) =>
                ref.read(highContrastProvider.notifier).state = v,
          ),

          _FontScaleTile(
            value:     fontScale,
            onChanged: (v) =>
                ref.read(fontScaleProvider.notifier).state = v,
          ),

          const SizedBox(height: ZapSpacing.lg),

          // ── DEVICE INFO ───────────────────────────────────────────────────
          const _SectionHeader(title: 'DEVICE INFO'),

          const _InfoTile(label: 'App version',  value: _kAppVersion),
          const _InfoTile(label: 'Device tier',  value: _kDeviceTier),
          const _InfoTile(label: 'Build',         value: _kBuildHash),
          _InfoTile(
            label: 'Device ID',
            value: 'zap-xxxxxxxx',
            onTap: () {
              Clipboard.setData(const ClipboardData(text: 'zap-xxxxxxxx'));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: ZapColors.bgElevated,
                  behavior:        SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  content: Text(
                    'Device ID copied',
                    style: ZapTypography.bodyMedium.copyWith(
                      color: ZapColors.textPrimary,
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: ZapSpacing.lg),

          // Reset button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.lg),
            child: OutlinedButton.icon(
              onPressed:  _resetSettings,
              icon:       const Icon(Icons.restore_rounded, size: 18),
              label:      const Text('Reset all settings to defaults'),
              style: OutlinedButton.styleFrom(
                foregroundColor: ZapColors.danger,
                side:            const BorderSide(color: ZapColors.danger, width: 0.8),
                padding: const EdgeInsets.symmetric(
                  horizontal: ZapSpacing.lg,
                  vertical:   ZapSpacing.md,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ZapSpacing.lg, ZapSpacing.sm, ZapSpacing.lg, ZapSpacing.sm,
      ),
      child: Text(
        title,
        style: ZapTypography.labelSmall.copyWith(
          color:         ZapColors.textSecondary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ─── Generic settings tile ────────────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.accent,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData  icon;
  final Color     accent;
  final String    title;
  final String?   subtitle;
  final Widget?   trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: ZapSpacing.lg,
          vertical:   ZapSpacing.md,
        ),
        child: Row(
          children: [
            Container(
              width:  36,
              height: 36,
              decoration: BoxDecoration(
                color:        accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: accent),
            ),
            const SizedBox(width: ZapSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: ZapTypography.bodyMedium.copyWith(
                      color: ZapColors.textPrimary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: ZapTypography.bodySmall.copyWith(
                        color: ZapColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

// ─── Nav row (chevron) ────────────────────────────────────────────────────────

class _NavSettingsTile extends StatelessWidget {
  const _NavSettingsTile({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.route,
  });

  final IconData icon;
  final Color    accent;
  final String   title;
  final String   subtitle;
  final String   route;

  @override
  Widget build(BuildContext context) {
    return _SettingsTile(
      icon:     icon,
      accent:   accent,
      title:    title,
      subtitle: subtitle,
      onTap:    () => context.push(route),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: ZapColors.textMuted,
        size:  20,
      ),
    );
  }
}

// ─── Language picker ──────────────────────────────────────────────────────────

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({required this.current, required this.onChanged});

  final String                  current;
  final void Function(String)   onChanged;

  @override
  Widget build(BuildContext context) {
    return _SettingsTile(
      icon:    Icons.language_rounded,
      accent:  ZapColors.info,
      title:   'Language',
      trailing: GestureDetector(
        onTap: () => _showPicker(context),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              current,
              style: ZapTypography.bodyMedium.copyWith(
                color: ZapColors.textSecondary,
              ),
            ),
            const SizedBox(width: ZapSpacing.xs),
            const Icon(
              Icons.expand_more_rounded,
              size:  16,
              color: ZapColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context:        context,
      isScrollControlled: true,
      backgroundColor: ZapColors.bgElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand:          false,
        initialChildSize: 0.6,
        maxChildSize:     0.85,
        minChildSize:     0.4,
        builder: (_, controller) => Column(
          children: [
            const SizedBox(height: ZapSpacing.sm),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color:        ZapColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: ZapSpacing.md),
            Text(
              'Select language',
              style: ZapTypography.headlineSmall.copyWith(
                color: ZapColors.textPrimary,
              ),
            ),
            const SizedBox(height: ZapSpacing.md),
            Expanded(
              child: ListView.builder(
                controller:  controller,
                itemCount:   _kLanguages.length,
                itemBuilder: (_, i) {
                  final (code, name) = _kLanguages[i];
                  final isSelected   = name == current;
                  return ListTile(
                    tileColor: isSelected
                        ? ZapColors.info.withOpacity(0.08)
                        : Colors.transparent,
                    title: Text(
                      name,
                      style: ZapTypography.bodyMedium.copyWith(
                        color: isSelected
                            ? ZapColors.info
                            : ZapColors.textPrimary,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(
                            Icons.check_rounded,
                            color: ZapColors.info,
                            size:  18,
                          )
                        : null,
                    onTap: () {
                      onChanged(code);
                      Navigator.of(ctx).pop();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── DCS sensitivity segmented control ────────────────────────────────────────

class _DcsSensitivityTile extends StatelessWidget {
  const _DcsSensitivityTile({required this.value, required this.onChanged});

  final DcsSensitivity                value;
  final void Function(DcsSensitivity) onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ZapSpacing.lg,
        vertical:   ZapSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width:  36,
                height: 36,
                decoration: BoxDecoration(
                  color:        ZapColors.danger.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.graphic_eq_rounded,
                  size:  18,
                  color: ZapColors.danger,
                ),
              ),
              const SizedBox(width: ZapSpacing.md),
              Expanded(
                child: Text(
                  'DCS sensitivity',
                  style: ZapTypography.bodyMedium.copyWith(
                    color: ZapColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),
          // Segmented control
          Row(
            children: DcsSensitivity.values.map((s) {
              final active = s == value;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(s),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(vertical: ZapSpacing.sm),
                    decoration: BoxDecoration(
                      color: active
                          ? ZapColors.danger.withOpacity(0.18)
                          : ZapColors.bgSurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: active
                            ? ZapColors.danger.withOpacity(0.5)
                            : ZapColors.border,
                      ),
                    ),
                    child: Text(
                      s.label,
                      textAlign: TextAlign.center,
                      style: ZapTypography.labelMedium.copyWith(
                        color: active
                            ? ZapColors.danger
                            : ZapColors.textSecondary,
                        fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: ZapSpacing.sm),
          Text(
            value.description,
            style: ZapTypography.bodySmall.copyWith(
              color:  ZapColors.textMuted,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Switch tile ──────────────────────────────────────────────────────────────

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData              icon;
  final Color                 accent;
  final String                title;
  final String                subtitle;
  final bool                  value;
  final void Function(bool)   onChanged;

  @override
  Widget build(BuildContext context) {
    return _SettingsTile(
      icon:     icon,
      accent:   accent,
      title:    title,
      subtitle: subtitle,
      trailing: Switch(
        value:              value,
        onChanged:          onChanged,
        activeColor:        accent,
        activeTrackColor:   accent.withOpacity(0.3),
        inactiveTrackColor: ZapColors.bgSurface,
        inactiveThumbColor: ZapColors.textMuted,
      ),
    );
  }
}

// ─── Font scale tile ──────────────────────────────────────────────────────────

class _FontScaleTile extends StatelessWidget {
  const _FontScaleTile({required this.value, required this.onChanged});

  final double              value;
  final void Function(double) onChanged;

  String get _label {
    if (value <= 1.0) return 'Default';
    if (value <= 1.2) return 'Large';
    return 'Extra large';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: ZapSpacing.lg, vertical: ZapSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width:  36,
                height: 36,
                decoration: BoxDecoration(
                  color:        ZapColors.info.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.format_size_rounded,
                  size:  18,
                  color: ZapColors.info,
                ),
              ),
              const SizedBox(width: ZapSpacing.md),
              Expanded(
                child: Text(
                  'Text size',
                  style: ZapTypography.bodyMedium.copyWith(
                    color: ZapColors.textPrimary,
                  ),
                ),
              ),
              Text(
                _label,
                style: ZapTypography.labelMedium.copyWith(
                  color: ZapColors.textSecondary,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor:   ZapColors.info,
              inactiveTrackColor: ZapColors.bgSurface,
              thumbColor:         ZapColors.info,
              overlayColor:       ZapColors.info.withOpacity(0.12),
              trackHeight:        3,
            ),
            child: Slider(
              value:    value,
              min:      1.0,
              max:      1.5,
              divisions: 5,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Info row (read-only) ─────────────────────────────────────────────────────

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value, this.onTap});

  final String       label;
  final String       value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: ZapSpacing.lg,
          vertical:   ZapSpacing.md,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: ZapTypography.bodyMedium.copyWith(
                  color: ZapColors.textSecondary,
                ),
              ),
            ),
            Text(
              value,
              style: ZapTypography.bodyMedium.copyWith(
                color:      ZapColors.textMuted,
                fontFamily: 'IBMPlexMono',
                fontSize:   12,
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: ZapSpacing.xs),
              const Icon(
                Icons.copy_outlined,
                size:  13,
                color: ZapColors.textMuted,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Inline name editor ───────────────────────────────────────────────────────

class _NameEditRow extends StatelessWidget {
  const _NameEditRow({
    required this.ctrl,
    required this.onSave,
    required this.onCancel,
  });

  final TextEditingController ctrl;
  final VoidCallback          onSave;
  final VoidCallback          onCancel;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 140,
          height: 32,
          child: TextField(
            controller:  ctrl,
            autofocus:   true,
            style: ZapTypography.bodyMedium.copyWith(
              color: ZapColors.textPrimary,
            ),
            cursorColor: ZapColors.info,
            decoration: InputDecoration(
              isDense:        true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: ZapSpacing.sm, vertical: ZapSpacing.xs,
              ),
              filled:      true,
              fillColor:   ZapColors.bgSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:   const BorderSide(color: ZapColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:   const BorderSide(color: ZapColors.info),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:   const BorderSide(color: ZapColors.border),
              ),
            ),
            onSubmitted: (_) => onSave(),
          ),
        ),
        const SizedBox(width: ZapSpacing.xs),
        GestureDetector(
          onTap: onSave,
          child: const Icon(
            Icons.check_rounded,
            size:  20,
            color: ZapColors.safe,
          ),
        ),
        const SizedBox(width: ZapSpacing.xs),
        GestureDetector(
          onTap: onCancel,
          child: const Icon(
            Icons.close_rounded,
            size:  20,
            color: ZapColors.textMuted,
          ),
        ),
      ],
    );
  }
}
