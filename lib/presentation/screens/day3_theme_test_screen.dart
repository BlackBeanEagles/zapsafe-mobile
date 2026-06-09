import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/theme/spacing.dart';

/// Provider that holds whether High Contrast Mode is enabled.
/// Day 3 — accessibility testing.
final highContrastModeProvider = StateProvider<bool>((ref) => false);

/// Day 3 — Theme Test Screen
///
/// Exercises every themed component in BOTH dark mode AND high-contrast mode.
/// Use the toggle in the AppBar to switch between modes and verify:
/// - All touch targets are 75×75dp
/// - All text is readable at default + 200% font scale
/// - Contrast ratios meet WCAG AAA (7:1 for normal text, 4.5:1 for large text)
class Day3ThemeTestScreen extends ConsumerWidget {
  const Day3ThemeTestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isHC = ref.watch(highContrastModeProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Day 3 · Theme Test'),
        actions: [
          // ─── Theme Toggle ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(right: ZapSpacing.sm),
            child: Row(
              children: [
                Icon(isHC ? Icons.contrast : Icons.dark_mode, size: 20),
                const SizedBox(width: ZapSpacing.sm),
                Text(
                  isHC ? 'HIGH CONTRAST' : 'DARK MODE',
                  style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.5),
                ),
                const SizedBox(width: ZapSpacing.sm),
                Switch(
                  value: isHC,
                  onChanged: (v) => ref.read(highContrastModeProvider.notifier).state = v,
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Status Banner ──────────────────────────────────────────
            _StatusBanner(isHC: isHC),
            const SizedBox(height: ZapSpacing.xxl),

            // ─── Typography Quick Check ─────────────────────────────────
            const _SectionHeader(label: 'TYPOGRAPHY'),
            const SizedBox(height: ZapSpacing.md),
            Text('Display Large', style: theme.textTheme.displayLarge),
            Text('Headline Medium', style: theme.textTheme.headlineMedium),
            Text(
              'Body text at default scale. Switch the toggle in the AppBar to flip between dark mode and high contrast mode.',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: ZapSpacing.xxxl),

            // ─── Buttons ─────────────────────────────────────────────────
            const _SectionHeader(label: 'BUTTONS · all 75×75dp tap area'),
            const SizedBox(height: ZapSpacing.md),
            Wrap(
              spacing: ZapSpacing.md,
              runSpacing: ZapSpacing.md,
              children: [
                ElevatedButton(
                  onPressed: () {},
                  child: const Text('TRIGGER SOS'),
                ),
                OutlinedButton(
                  onPressed: () {},
                  child: const Text('CANCEL'),
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text('Learn more'),
                ),
                ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.shield),
                  label: const Text('PROTECT ME'),
                ),
              ],
            ),
            const SizedBox(height: ZapSpacing.xxxl),

            // ─── Inputs ──────────────────────────────────────────────────
            const _SectionHeader(label: 'INPUT FIELDS'),
            const SizedBox(height: ZapSpacing.md),
            const TextField(
              decoration: InputDecoration(
                labelText: 'Phone number',
                hintText: '+91 98765 43210',
                prefixIcon: Icon(Icons.phone),
              ),
            ),
            const SizedBox(height: ZapSpacing.md),
            const TextField(
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Cancel PIN',
                hintText: 'Enter 6-digit PIN',
                prefixIcon: Icon(Icons.lock),
              ),
            ),
            const SizedBox(height: ZapSpacing.md),
            const TextField(
              decoration: InputDecoration(
                labelText: 'Email',
                errorText: 'Please enter a valid email',
                prefixIcon: Icon(Icons.email),
              ),
            ),
            const SizedBox(height: ZapSpacing.xxxl),

            // ─── Cards ───────────────────────────────────────────────────
            const _SectionHeader(label: 'CARDS'),
            const SizedBox(height: ZapSpacing.md),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(ZapSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.shield, color: cs.secondary, size: 32),
                        const SizedBox(width: ZapSpacing.md),
                        Text(
                          'Protection Score',
                          style: theme.textTheme.headlineSmall,
                        ),
                        const Spacer(),
                        Text(
                          '85',
                          style: theme.textTheme.displaySmall?.copyWith(color: cs.secondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: ZapSpacing.md),
                    Text(
                      'Your safety setup is in great shape. Add a Tier 2 contact to reach 95.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: ZapSpacing.lg),
                    LinearProgressIndicator(
                      value: 0.85,
                      color: cs.secondary,
                      backgroundColor: cs.surface,
                      minHeight: 8,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: ZapSpacing.xxxl),

            // ─── Toggles & Selection ─────────────────────────────────────
            const _SectionHeader(label: 'TOGGLES & SELECTION'),
            const SizedBox(height: ZapSpacing.md),
            const Card(
              child: Column(
                children: [
                  _SwitchRow(label: 'Auto-detect Fall', initial: true),
                  Divider(height: 1),
                  _SwitchRow(label: 'Voice trigger', initial: false),
                  Divider(height: 1),
                  _CheckboxRow(label: 'Share location with Tier 1', initial: true),
                  Divider(height: 1),
                  _CheckboxRow(label: 'Auto-call 112 in CRITICAL mode', initial: false),
                ],
              ),
            ),
            const SizedBox(height: ZapSpacing.xxxl),

            // ─── Chips ───────────────────────────────────────────────────
            const _SectionHeader(label: 'CHIPS'),
            const SizedBox(height: ZapSpacing.md),
            Wrap(
              spacing: ZapSpacing.sm,
              runSpacing: ZapSpacing.sm,
              children: [
                Chip(label: const Text('SAFE'), avatar: Icon(Icons.check_circle, size: 18, color: cs.secondary)),
                Chip(label: const Text('ELEVATED'), backgroundColor: ZapColors.warning.withOpacity(0.15)),
                Chip(label: const Text('CRITICAL'), backgroundColor: ZapColors.danger.withOpacity(0.15)),
                const Chip(label: Text('LP24 · Trusted Location')),
                const Chip(label: Text('Tier 1')),
              ],
            ),
            const SizedBox(height: ZapSpacing.xxxl),

            // ─── Dialogs & Snackbars ─────────────────────────────────────
            const _SectionHeader(label: 'DIALOGS & SNACKBARS'),
            const SizedBox(height: ZapSpacing.md),
            Wrap(
              spacing: ZapSpacing.md,
              runSpacing: ZapSpacing.md,
              children: [
                OutlinedButton(
                  onPressed: () => _showDialog(context),
                  child: const Text('SHOW DIALOG'),
                ),
                OutlinedButton(
                  onPressed: () => _showSnackbar(context),
                  child: const Text('SHOW SNACKBAR'),
                ),
              ],
            ),
            const SizedBox(height: ZapSpacing.xxxl),

            // ─── Accessibility Info ──────────────────────────────────────
            _AccessibilityCard(),
            const SizedBox(height: ZapSpacing.huge),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.warning_amber_rounded, size: 32),
      ),
    );
  }

  void _showDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm SOS'),
        content: const Text(
          'You are about to trigger an emergency SOS. Your Tier 1 contacts will be notified. Continue?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('CONFIRM SOS')),
        ],
      ),
    );
  }

  void _showSnackbar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('SOS dispatched to 1 Tier-1 contact'),
        duration: Duration(seconds: 3),
      ),
    );
  }
}

// ─── Status Banner ─────────────────────────────────────────────────────
class _StatusBanner extends StatelessWidget {
  final bool isHC;
  const _StatusBanner({required this.isHC});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isHC ? ZapColors.hcFocus : ZapColors.safe;
    final bgColor = isHC ? ZapColors.hcBackground : color.withOpacity(0.08);
    final borderColor = isHC ? ZapColors.hcText : color.withOpacity(0.3);
    final borderWidth = isHC ? 2.0 : 1.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: Row(
        children: [
          Icon(
            isHC ? Icons.contrast : Icons.check_circle,
            color: color,
            size: 28,
          ),
          const SizedBox(width: ZapSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isHC ? 'High Contrast Mode Active' : 'Day 3 — Theme Wired',
                  style: theme.textTheme.headlineSmall?.copyWith(color: color),
                ),
                const SizedBox(height: ZapSpacing.xs),
                Text(
                  isHC
                      ? 'WCAG AAA 21:1 contrast · 2px borders · yellow focus rings'
                      : 'Material 3 Dark · OLED-optimized · all components themed',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section Header ─────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: ZapTypography.labelSmall.copyWith(
            color: Theme.of(context).textTheme.bodySmall?.color,
            letterSpacing: 2,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: ZapSpacing.md),
        const Expanded(child: Divider()),
      ],
    );
  }
}

// ─── Switch Row ─────────────────────────────────────────────────────────
class _SwitchRow extends StatefulWidget {
  final String label;
  final bool initial;
  const _SwitchRow({required this.label, required this.initial});

  @override
  State<_SwitchRow> createState() => _SwitchRowState();
}

class _SwitchRowState extends State<_SwitchRow> {
  late bool _value = widget.initial;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(widget.label, style: Theme.of(context).textTheme.bodyLarge),
      contentPadding: const EdgeInsets.symmetric(horizontal: ZapSpacing.lg),
      minVerticalPadding: ZapSpacing.md,
      trailing: Switch(value: _value, onChanged: (v) => setState(() => _value = v)),
    );
  }
}

// ─── Checkbox Row ───────────────────────────────────────────────────────
class _CheckboxRow extends StatefulWidget {
  final String label;
  final bool initial;
  const _CheckboxRow({required this.label, required this.initial});

  @override
  State<_CheckboxRow> createState() => _CheckboxRowState();
}

class _CheckboxRowState extends State<_CheckboxRow> {
  late bool _value = widget.initial;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      title: Text(widget.label, style: Theme.of(context).textTheme.bodyLarge),
      value: _value,
      onChanged: (v) => setState(() => _value = v ?? false),
      controlAffinity: ListTileControlAffinity.trailing,
      contentPadding: const EdgeInsets.symmetric(horizontal: ZapSpacing.lg),
    );
  }
}

// ─── Accessibility Card ─────────────────────────────────────────────────
class _AccessibilityCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.accessibility_new, color: theme.colorScheme.tertiary, size: 28),
                const SizedBox(width: ZapSpacing.md),
                Text('Accessibility Audit', style: theme.textTheme.headlineSmall),
              ],
            ),
            const SizedBox(height: ZapSpacing.lg),
            const _AuditRow(label: 'Min touch target', value: '75 × 75dp (AAA)', pass: true),
            const _AuditRow(label: 'Color contrast (dark)', value: '15.8:1 (AAA)', pass: true),
            const _AuditRow(label: 'Color contrast (HC)', value: '21:1 (AAA)', pass: true),
            const _AuditRow(label: 'Font scaling', value: 'Up to 200% supported', pass: true),
            const _AuditRow(label: 'Screen reader labels', value: 'Day 5 task', pass: false),
          ],
        ),
      ),
    );
  }
}

class _AuditRow extends StatelessWidget {
  final String label;
  final String value;
  final bool pass;
  const _AuditRow({required this.label, required this.value, required this.pass});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: ZapSpacing.sm),
      child: Row(
        children: [
          Icon(
            pass ? Icons.check_circle : Icons.pending,
            color: pass ? theme.colorScheme.secondary : ZapColors.warning,
            size: 20,
          ),
          const SizedBox(width: ZapSpacing.md),
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          Text(value, style: ZapTypography.monoSmall.copyWith(color: theme.textTheme.bodySmall?.color)),
        ],
      ),
    );
  }
}
