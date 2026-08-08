/// Day 215 — Font Scale 200% Regression
///
/// Section A (Days 201-220): simulates textScaleFactor 1.0→2.0 on critical
/// screen mini-previews; flags layout overflow at large accessibility sizes.
///
/// Tag: 🟢 FRONTEND-ONLY — QA regression tool, not production settings.
///
/// Route: [AppRoutes.fontScaleRegression] → `/font-scale-regression`
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';

// ── Models ────────────────────────────────────────────────────────────────────
enum FontScaleScreen { dashboard, alertPending, settings }

extension FontScaleScreenX on FontScaleScreen {
  String get title => switch (this) {
        FontScaleScreen.dashboard => 'Dashboard',
        FontScaleScreen.alertPending => 'ALERT_PENDING',
        FontScaleScreen.settings => 'Settings',
      };

  String get route => switch (this) {
        FontScaleScreen.dashboard => '/dashboard',
        FontScaleScreen.alertPending => '/alert-pending',
        FontScaleScreen.settings => '/settings',
      };

  IconData get icon => switch (this) {
        FontScaleScreen.dashboard => Icons.dashboard_rounded,
        FontScaleScreen.alertPending => Icons.warning_amber_rounded,
        FontScaleScreen.settings => Icons.settings_rounded,
      };

  Color get accent => switch (this) {
        FontScaleScreen.dashboard => ZapColors.safe,
        FontScaleScreen.alertPending => ZapColors.danger,
        FontScaleScreen.settings => ZapColors.info,
      };
}

// ── Providers ─────────────────────────────────────────────────────────────────
final _d215TabProvider = StateProvider<int>((ref) => 0);
final _d215ScaleProvider = StateProvider<double>((ref) => 1.0);
final _d215OverflowProvider = StateProvider<Map<FontScaleScreen, bool>>(
  (ref) => {
    for (final s in FontScaleScreen.values) s: false,
  },
);
final _d215SelectedProvider =
    StateProvider<FontScaleScreen>((ref) => FontScaleScreen.dashboard);

const _kTabs = ['Live Preview', 'Issues', 'Spec'];
const _kFrameWidth = 168.0;
const _kFrameHeight = 300.0;

// ── Screen ────────────────────────────────────────────────────────────────────
class Day215FontScaleRegressionScreen extends ConsumerWidget {
  const Day215FontScaleRegressionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_d215TabProvider);
    final scale = ref.watch(_d215ScaleProvider);
    final overflows = ref.watch(_d215OverflowProvider);
    final passCount = overflows.values.where((overflow) => !overflow).length;

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 215 · Font Scale Regression'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: ZapSpacing.md),
            child: Center(
              child: Text(
                '$passCount/${FontScaleScreen.values.length}',
                style: TextStyle(
                  color: passCount == FontScaleScreen.values.length
                      ? ZapColors.safe
                      : ZapColors.textSecondary,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
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
            onSelect: (i) => ref.read(_d215TabProvider.notifier).state = i,
          ),
          if (tab == 0)
            _ScaleStrip(
              scale: scale,
              passCount: passCount,
              total: FontScaleScreen.values.length,
            ),
          Expanded(
            child: switch (tab) {
              0 => const _LivePreviewTab(),
              1 => const _IssuesTab(),
              _ => const _SpecTab(),
            },
          ),
        ],
      ),
    );
  }
}

class _ScaleStrip extends StatelessWidget {
  final double scale;
  final int passCount;
  final int total;

  const _ScaleStrip({
    required this.scale,
    required this.passCount,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        ZapSpacing.lg,
        ZapSpacing.sm,
        ZapSpacing.lg,
        ZapSpacing.md,
      ),
      color: ZapColors.bgCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'textScaleFactor ${scale.toStringAsFixed(2)}×',
                style: const TextStyle(
                  color: ZapColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              Text(
                '$passCount/$total layouts OK',
                style: TextStyle(
                  color:
                      passCount == total ? ZapColors.safe : ZapColors.warning,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (scale - 1.0) / 1.0,
              minHeight: 6,
              backgroundColor: ZapColors.bgElevated,
              color: scale >= 2.0 ? ZapColors.warning : ZapColors.info,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab 0: Live Preview ───────────────────────────────────────────────────────
class _LivePreviewTab extends ConsumerWidget {
  const _LivePreviewTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = ref.watch(_d215ScaleProvider);
    final overflows = ref.watch(_d215OverflowProvider);
    final selected = ref.watch(_d215SelectedProvider);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: ZapColors.safe.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: ZapColors.safe.withOpacity(0.35)),
          ),
          child: const Text(
            '🟢 FRONTEND-ONLY · Section A Day 15/20 · WCAG 1.4.4 resize text',
            style: TextStyle(color: ZapColors.safe, fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Text(
          'Font scale ${scale.toStringAsFixed(2)}×',
          style: const TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        Slider(
          value: scale,
          min: 1.0,
          max: 2.0,
          divisions: 20,
          label: '${scale.toStringAsFixed(2)}×',
          activeColor: ZapColors.info,
          onChanged: (v) => ref.read(_d215ScaleProvider.notifier).state = v,
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _QuickScaleChip(
              label: '1.0×',
              value: 1.0,
              current: scale,
              onSelect: (v) => ref.read(_d215ScaleProvider.notifier).state = v,
            ),
            _QuickScaleChip(
              label: '1.25×',
              value: 1.25,
              current: scale,
              onSelect: (v) => ref.read(_d215ScaleProvider.notifier).state = v,
            ),
            _QuickScaleChip(
              label: '1.5×',
              value: 1.5,
              current: scale,
              onSelect: (v) => ref.read(_d215ScaleProvider.notifier).state = v,
            ),
            _QuickScaleChip(
              label: '2.0×',
              value: 2.0,
              current: scale,
              onSelect: (v) => ref.read(_d215ScaleProvider.notifier).state = v,
            ),
          ],
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Critical screen mini-previews (fixed phone frame). '
          'Red badge = measured overflow at current scale.',
          style: TextStyle(color: ZapColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: ZapSpacing.lg),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: FontScaleScreen.values.map((screen) {
              final overflow = overflows[screen] ?? false;
              final isSelected = selected == screen;
              return Padding(
                padding: const EdgeInsets.only(right: ZapSpacing.md),
                child: _PreviewFrame(
                  screen: screen,
                  scale: scale,
                  overflow: overflow,
                  selected: isSelected,
                  onOverflow: (v) {
                    ref.read(_d215OverflowProvider.notifier).update(
                          (m) => {...m, screen: v},
                        );
                  },
                  onTap: () =>
                      ref.read(_d215SelectedProvider.notifier).state = screen,
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        _LargePreview(
          screen: selected,
          scale: scale,
          overflow: overflows[selected] ?? false,
          onOverflow: (v) {
            ref.read(_d215OverflowProvider.notifier).update(
                  (m) => {...m, selected: v},
                );
          },
        ),
      ],
    );
  }
}

class _QuickScaleChip extends StatelessWidget {
  final String label;
  final double value;
  final double current;
  final ValueChanged<double> onSelect;

  const _QuickScaleChip({
    required this.label,
    required this.value,
    required this.current,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final selected = (current - value).abs() < 0.01;
    return Semantics(
      label: 'Set font scale $label',
      button: true,
      selected: selected,
      child: ActionChip(
        label: Text(label),
        onPressed: () => onSelect(value),
        backgroundColor:
            selected ? ZapColors.info.withOpacity(0.2) : ZapColors.bgElevated,
      ),
    );
  }
}

class _PreviewFrame extends StatelessWidget {
  final FontScaleScreen screen;
  final double scale;
  final bool overflow;
  final bool selected;
  final ValueChanged<bool> onOverflow;
  final VoidCallback onTap;

  const _PreviewFrame({
    required this.screen,
    required this.scale,
    required this.overflow,
    required this.selected,
    required this.onOverflow,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          '${screen.title} preview. ${overflow ? "Overflow detected" : "Layout OK"}',
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(screen.icon, size: 14, color: screen.accent),
                const SizedBox(width: ZapSpacing.xs),
                Text(
                  screen.title,
                  style: TextStyle(
                    color: screen.accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected
                      ? screen.accent
                      : overflow
                          ? ZapColors.danger
                          : ZapColors.border,
                  width: selected || overflow ? 2 : 1,
                ),
                boxShadow: overflow
                    ? [
                        BoxShadow(
                          color: ZapColors.danger.withOpacity(0.25),
                          blurRadius: 8,
                        ),
                      ]
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: _ScaledPreviewHost(
                  width: _kFrameWidth,
                  height: _kFrameHeight,
                  scale: scale,
                  onOverflow: onOverflow,
                  child: _MiniPreview(screen: screen),
                ),
              ),
            ),
            const SizedBox(height: 6),
            _OverflowBadge(overflow: overflow),
          ],
        ),
      ),
    );
  }
}

class _LargePreview extends StatelessWidget {
  final FontScaleScreen screen;
  final double scale;
  final bool overflow;
  final ValueChanged<bool> onOverflow;

  const _LargePreview({
    required this.screen,
    required this.scale,
    required this.overflow,
    required this.onOverflow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: overflow ? ZapColors.danger : ZapColors.border,
          width: overflow ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'Zoom · ${screen.title}',
                style: const TextStyle(
                  color: ZapColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              _OverflowBadge(overflow: overflow, compact: false),
            ],
          ),
          const SizedBox(height: ZapSpacing.sm),
          Text(
            screen.route,
            style: const TextStyle(
              color: ZapColors.textMuted,
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: ZapSpacing.md),
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _ScaledPreviewHost(
                width: _kFrameWidth * 1.35,
                height: _kFrameHeight * 1.2,
                scale: scale,
                onOverflow: onOverflow,
                child: _MiniPreview(screen: screen),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverflowBadge extends StatelessWidget {
  final bool overflow;
  final bool compact;

  const _OverflowBadge({required this.overflow, this.compact = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: overflow
            ? ZapColors.danger.withOpacity(0.15)
            : ZapColors.safe.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: overflow
              ? ZapColors.danger.withOpacity(0.5)
              : ZapColors.safe.withOpacity(0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            overflow ? Icons.report_rounded : Icons.check_circle_rounded,
            size: compact ? 12 : 14,
            color: overflow ? ZapColors.danger : ZapColors.safe,
          ),
          const SizedBox(width: ZapSpacing.xs),
          Text(
            overflow ? 'OVERFLOW' : 'OK',
            style: TextStyle(
              color: overflow ? ZapColors.danger : ZapColors.safe,
              fontSize: compact ? 9 : 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScaledPreviewHost extends StatefulWidget {
  final double width;
  final double height;
  final double scale;
  final Widget child;
  final ValueChanged<bool> onOverflow;

  const _ScaledPreviewHost({
    required this.width,
    required this.height,
    required this.scale,
    required this.child,
    required this.onOverflow,
  });

  @override
  State<_ScaledPreviewHost> createState() => _ScaledPreviewHostState();
}

class _ScaledPreviewHostState extends State<_ScaledPreviewHost> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: ColoredBox(
        color: ZapColors.bgPrimary,
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(widget.scale),
            size: Size(widget.width, widget.height),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRect(
                child: _OverflowMeasurer(
                  maxWidth: widget.width,
                  maxHeight: widget.height,
                  onOverflow: widget.onOverflow,
                  child: widget.child,
                ),
              ),
              if (widget.scale >= 1.85)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: Container(
                      height: 3,
                      color: ZapColors.warning.withOpacity(0.35),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverflowMeasurer extends SingleChildRenderObjectWidget {
  final double maxWidth;
  final double maxHeight;
  final ValueChanged<bool> onOverflow;

  const _OverflowMeasurer({
    required this.maxWidth,
    required this.maxHeight,
    required this.onOverflow,
    super.child,
  });

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderOverflowMeasurer(
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      onOverflow: onOverflow,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderOverflowMeasurer renderObject,
  ) {
    renderObject
      ..maxWidth = maxWidth
      ..maxHeight = maxHeight
      ..onOverflow = onOverflow;
  }
}

class _RenderOverflowMeasurer extends RenderProxyBox {
  _RenderOverflowMeasurer({
    required double maxWidth,
    required double maxHeight,
    required ValueChanged<bool> onOverflow,
  })  : _maxWidth = maxWidth,
        _maxHeight = maxHeight,
        _onOverflow = onOverflow;

  double _maxWidth;
  double _maxHeight;
  ValueChanged<bool> _onOverflow;
  bool? _last;

  set maxWidth(double value) => _maxWidth = value;
  set maxHeight(double value) => _maxHeight = value;
  set onOverflow(ValueChanged<bool> value) => _onOverflow = value;

  @override
  void performLayout() {
    if (child != null) {
      child!.layout(
        BoxConstraints(
          maxWidth: _maxWidth,
          maxHeight: double.infinity,
        ),
        parentUsesSize: true,
      );
      size = Size(_maxWidth, _maxHeight);
      final overflow = child!.size.width > _maxWidth + 0.5 ||
          child!.size.height > _maxHeight + 0.5;
      if (_last != overflow) {
        _last = overflow;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _onOverflow(overflow);
        });
      }
    } else {
      size = Size(_maxWidth, _maxHeight);
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) return;
    final overflow = child!.size.width > _maxWidth + 0.5 ||
        child!.size.height > _maxHeight + 0.5;
    if (overflow) {
      context.canvas.save();
      context.canvas.clipRect(offset & size);
      context.paintChild(child!, offset);
      context.canvas.restore();
      final paint = Paint()
        ..color = ZapColors.danger.withOpacity(0.18)
        ..style = PaintingStyle.fill;
      context.canvas.drawRect(offset & size, paint);
      final stripe = Paint()
        ..color = ZapColors.danger
        ..strokeWidth = 2;
      context.canvas.drawLine(
        offset,
        offset + Offset(size.width, size.height),
        stripe,
      );
      context.canvas.drawLine(
        offset + Offset(size.width, 0),
        offset + Offset(0, size.height),
        stripe,
      );
    } else {
      context.paintChild(child!, offset);
    }
  }
}

class _MiniPreview extends StatelessWidget {
  final FontScaleScreen screen;

  const _MiniPreview({required this.screen});

  @override
  Widget build(BuildContext context) {
    return switch (screen) {
      FontScaleScreen.dashboard => const _DashboardMiniPreview(),
      FontScaleScreen.alertPending => const _AlertPendingMiniPreview(),
      FontScaleScreen.settings => const _SettingsMiniPreview(),
    };
  }
}

class _DashboardMiniPreview extends StatelessWidget {
  const _DashboardMiniPreview();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(ZapSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(ZapSpacing.sm),
            decoration: BoxDecoration(
              color: ZapColors.safe.withOpacity(0.1),
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              border: Border.all(color: ZapColors.safe.withOpacity(0.35)),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_rounded,
                    color: ZapColors.safe, size: 18),
                const SizedBox(width: 6),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MONITORING',
                        style: TextStyle(
                          color: ZapColors.safe,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        'Battery 82% · DCS 12%',
                        style: TextStyle(
                          color: ZapColors.textSecondary,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: ZapColors.bgElevated,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'GPS every 30 seconds',
                    style: TextStyle(
                      color: ZapColors.textMuted,
                      fontSize: 8,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.sm),
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: ZapColors.safe, width: 3),
                ),
                alignment: Alignment.center,
                child: const Text(
                  '78',
                  style: TextStyle(
                    color: ZapColors.safe,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: ZapSpacing.sm),
              const Expanded(
                child: Text(
                  'Protection score · 4 AI models active',
                  style: TextStyle(
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Align(
            alignment: Alignment.center,
            child: Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: ZapColors.danger,
              ),
              alignment: Alignment.center,
              child: const Text(
                'SOS',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(height: ZapSpacing.sm),
        ],
      ),
    );
  }
}

class _AlertPendingMiniPreview extends StatelessWidget {
  const _AlertPendingMiniPreview();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(ZapSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: ZapColors.danger.withOpacity(0.15),
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              border: Border.all(color: ZapColors.danger),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ALERT PENDING',
                  style: TextStyle(
                    color: ZapColors.danger,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  'SOS triggers in 8 seconds unless cancelled',
                  style: TextStyle(
                    color: ZapColors.textPrimary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.md),
          const Center(
            child: Text(
              '8',
              style: TextStyle(
                color: ZapColors.danger,
                fontWeight: FontWeight.w900,
                fontSize: 42,
                height: 1,
              ),
            ),
          ),
          const Text(
            'seconds remaining',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: ZapColors.textSecondary,
              fontSize: 10,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: ZapColors.bgElevated,
                    borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                    border: Border.all(color: ZapColors.border),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'Cancel alert',
                    style: TextStyle(
                      color: ZapColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: ZapColors.safe.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                    border: Border.all(color: ZapColors.safe),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    "I'm OK — dismiss",
                    style: TextStyle(
                      color: ZapColors.safe,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
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

class _SettingsMiniPreview extends StatelessWidget {
  const _SettingsMiniPreview();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(ZapSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Settings',
            style: TextStyle(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: ZapSpacing.sm),
          const _SettingsRow(
            icon: Icons.person_outline_rounded,
            title: 'Account & profile',
            subtitle: 'Email, phone, emergency identity',
          ),
          const _SettingsRow(
            icon: Icons.notifications_none_rounded,
            title: 'Notifications',
            subtitle: 'Push, SMS fallback, quiet hours schedule',
          ),
          const _SettingsRow(
            icon: Icons.accessibility_new_rounded,
            title: 'Accessibility',
            subtitle: 'Font size, contrast, reduce motion, screen reader',
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: ZapColors.bgElevated,
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              border: Border.all(color: ZapColors.border),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Text size preview',
                    style: TextStyle(
                      color: ZapColors.textPrimary,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '${MediaQuery.textScalerOf(context).scale(1).toStringAsFixed(1)}×',
                  style: const TextStyle(
                    color: ZapColors.info,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
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

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: ZapColors.textMuted),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: ZapColors.textMuted,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              size: 16, color: ZapColors.textMuted),
        ],
      ),
    );
  }
}

// ── Tab 1: Issues ─────────────────────────────────────────────────────────────
class _IssuesTab extends ConsumerWidget {
  const _IssuesTab();

  String _fixHint(FontScaleScreen screen) => switch (screen) {
        FontScaleScreen.dashboard =>
          'Wrap mode chip row · shorten GPS label · FittedBox on score caption',
        FontScaleScreen.alertPending =>
          'Stack action buttons vertically at scale ≥ 1.5 · reduce countdown font cap',
        FontScaleScreen.settings =>
          'Allow ListTile subtitle maxLines: 2 · wrap chevron row · use Flexible titles',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scale = ref.watch(_d215ScaleProvider);
    final overflows = ref.watch(_d215OverflowProvider);
    final issueCount = overflows.values.where((v) => v).length;

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Text(
          'Overflow report at ${scale.toStringAsFixed(2)}×',
          style: const TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        Text(
          issueCount == 0
              ? 'All critical layouts fit inside the phone frame.'
              : '$issueCount screen(s) overflow — fix before release.',
          style: TextStyle(
            color: issueCount == 0 ? ZapColors.safe : ZapColors.danger,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        ...FontScaleScreen.values.map((screen) {
          final overflow = overflows[screen] ?? false;
          return Container(
            margin: const EdgeInsets.only(bottom: ZapSpacing.md),
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: ZapColors.bgCard,
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              border: Border.all(
                color: overflow ? ZapColors.danger : ZapColors.border,
                width: overflow ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(screen.icon, color: screen.accent, size: 20),
                    const SizedBox(width: ZapSpacing.sm),
                    Expanded(
                      child: Text(
                        screen.title,
                        style: const TextStyle(
                          color: ZapColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    _OverflowBadge(overflow: overflow),
                  ],
                ),
                const SizedBox(height: ZapSpacing.xs),
                Text(
                  screen.route,
                  style: const TextStyle(
                    color: ZapColors.textMuted,
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
                if (overflow) ...[
                  const SizedBox(height: ZapSpacing.sm),
                  Text(
                    'Suggested fix: ${_fixHint(screen)}',
                    style: const TextStyle(
                      color: ZapColors.textSecondary,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
        Semantics(
          label: 'Copy overflow report',
          button: true,
          child: FilledButton.icon(
            onPressed: () {
              final buf = StringBuffer()
                ..writeln('ZapSafe Font Scale Regression — Day 215')
                ..writeln('Scale: ${scale.toStringAsFixed(2)}×')
                ..writeln('');
              for (final s in FontScaleScreen.values) {
                final o = overflows[s] ?? false;
                buf.writeln(
                    '${s.title} (${s.route}): ${o ? "OVERFLOW" : "OK"}');
                if (o) buf.writeln('  Fix: ${_fixHint(s)}');
              }
              Clipboard.setData(ClipboardData(text: buf.toString()));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Overflow report copied')),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copy overflow report'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 75),
              backgroundColor: ZapColors.bgElevated,
              foregroundColor: ZapColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Tab 2: Spec ───────────────────────────────────────────────────────────────
class _SpecTab extends StatelessWidget {
  const _SpecTab();

  @override
  Widget build(BuildContext context) {
    const rules = [
      ('WCAG 1.4.4', 'Text resizable up to 200% without loss of content'),
      ('Test at 2.0×', 'System font slider max + in-app Day 97 font scale'),
      ('No clipped CTAs', 'SOS + Cancel alert buttons remain tappable'),
      ('Wrap rows', 'Replace fixed Row + long strings with Wrap / Flexible'),
      ('Max font caps', 'Countdown numerals may use maxScaleFactor on Text'),
    ];

    const adopt = [
      ('Dashboard', 'ModeStatusCard chip row · protection caption · SOS label'),
      ('ALERT_PENDING', 'Countdown + dual action row · liveRegion text'),
      ('Settings', 'Day 97 accessibility rows · long subtitles'),
      ('Onboarding', 'Day 44/45 step review cards at 1.75×'),
      ('Production', 'MediaQuery.textScalerOf(context) in layout decisions'),
    ];

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const Text(
          'Font scale regression (Day 215)',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        ...rules.map(
          (r) => Container(
            margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: ZapColors.bgCard,
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              border: Border.all(color: ZapColors.border),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 100,
                  child: Text(
                    r.$1,
                    style: const TextStyle(
                      color: ZapColors.safe,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    r.$2,
                    style: const TextStyle(
                      color: ZapColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Screens to regression-test',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        ...adopt.map(
          (a) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.chevron_right_rounded,
                    size: 16, color: ZapColors.textMuted),
                const SizedBox(width: ZapSpacing.xs),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        color: ZapColors.textSecondary,
                        fontSize: 12,
                      ),
                      children: [
                        TextSpan(
                          text: '${a.$1}\n',
                          style: const TextStyle(
                            color: ZapColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextSpan(text: a.$2),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.info.withOpacity(0.1),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: ZapColors.info.withOpacity(0.3)),
          ),
          child: const Text(
            'Tomorrow: Day 217 — Performance profiling dashboard (cold start, RAM, battery targets).',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _TabBar extends StatelessWidget {
  final int tab;
  final ValueChanged<int> onSelect;

  const _TabBar({required this.tab, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ZapColors.bgCard,
      child: Row(
        children: List.generate(_kTabs.length, (i) {
          final selected = tab == i;
          return Expanded(
            child: Semantics(
              label: '${_kTabs[i]} tab',
              button: true,
              selected: selected,
              child: InkWell(
                onTap: () => onSelect(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: ZapSpacing.md),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: selected ? ZapColors.safe : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    _kTabs[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: selected
                          ? ZapColors.textPrimary
                          : ZapColors.textSecondary,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 12,
                    ),
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
