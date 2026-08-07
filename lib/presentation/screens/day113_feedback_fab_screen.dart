import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/spacing.dart';

// ── Provider ───────────────────────────────────────────────────────────────────
final _betaModeProvider = StateProvider<bool>((ref) => true);

// ── Screen ─────────────────────────────────────────────────────────────────────
class Day113FeedbackFabScreen extends ConsumerStatefulWidget {
  const Day113FeedbackFabScreen({super.key});

  @override
  ConsumerState<Day113FeedbackFabScreen> createState() =>
      _Day113FeedbackFabScreenState();
}

class _Day113FeedbackFabScreenState
    extends ConsumerState<Day113FeedbackFabScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double>   _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _openSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (_) => const _MiniSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isBeta = ref.watch(_betaModeProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Day 113 · Feedback FAB'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Hero(),
            const SizedBox(height: ZapSpacing.xl),
            _ModeToggle(isBeta: isBeta),
            const SizedBox(height: ZapSpacing.xl),
            const _SectionLabel('LIVE DEMO · TAP THE BUTTON'),
            const SizedBox(height: ZapSpacing.md),
            _MockScreenDemo(
              isBeta: isBeta,
              pulseAnim: _pulseAnim,
              onFabTap: _openSheet,
            ),
            const SizedBox(height: ZapSpacing.xl),
            const _SectionLabel('INTEGRATION · ANY SCAFFOLD'),
            const SizedBox(height: ZapSpacing.md),
            const _IntegrationCard(),
            const SizedBox(height: ZapSpacing.xl),
            const _SectionLabel('WIDGET API · feedback_fab.dart'),
            const SizedBox(height: ZapSpacing.md),
            const _WidgetApiCard(),
            const SizedBox(height: ZapSpacing.xl),
            const _SectionLabel('CHECKLIST'),
            const SizedBox(height: ZapSpacing.md),
            const _Checklist(),
            const SizedBox(height: ZapSpacing.huge),
          ],
        ),
      ),
    );
  }
}

// ── Hero ───────────────────────────────────────────────────────────────────────
class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF431407), Color(0xFF1C0A02), Color(0xFF0A0A0A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFFF97316).withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF97316).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: const Color(0xFFF97316).withOpacity(0.5)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.science_rounded,
                        color: Color(0xFFF97316), size: 13),
                    SizedBox(width: 5),
                    Text(
                      '⚡  BETA  ·  DAY 113',
                      style: TextStyle(
                        color: Color(0xFFF97316),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),
          const Text(
            'In-App\nFeedback Button',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
          ),
          const SizedBox(height: ZapSpacing.md),
          const Text(
            'A floating feedback button that overlays every screen in beta '
            'builds. Gated on FlavorConfig.isBeta — invisible in production. '
            'Tap it to open the quick-feedback sheet (full form: Day 114).',
            style: TextStyle(
              color: Color(0xFFD1D5DB),
              fontSize: 12,
              height: 1.6,
            ),
          ),
          const SizedBox(height: ZapSpacing.md),
          const Row(
            children: [
              _HeroStat('1',   'Widget file',      Color(0xFFF97316)),
              _HeroStat('β',   'Beta-only',         Color(0xFF10B981)),
              _HeroStat('FAB', 'Positioned',        Color(0xFF3B82F6)),
              _HeroStat('↗',   'Day 114 form',      Color(0xFF8B5CF6)),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String value;
  final String label;
  final Color  color;
  const _HeroStat(this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 9),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Section label ──────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: Color(0xFF6B7280),
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
      ),
    );
  }
}

// ── Beta / Prod mode toggle ────────────────────────────────────────────────────
class _ModeToggle extends ConsumerWidget {
  final bool isBeta;
  const _ModeToggle({required this.isBeta});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('BUILD MODE SIMULATOR'),
        const SizedBox(height: ZapSpacing.md),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          child: Row(
            children: [
              _ModeBtn(
                label: '🏁  Prod',
                sub: 'FAB hidden',
                selected: !isBeta,
                accent: const Color(0xFF3B82F6),
                onTap: () =>
                    ref.read(_betaModeProvider.notifier).state = false,
              ),
              _ModeBtn(
                label: '⚡  Beta',
                sub: 'FAB visible',
                selected: isBeta,
                accent: const Color(0xFFF97316),
                onTap: () =>
                    ref.read(_betaModeProvider.notifier).state = true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ModeBtn extends StatelessWidget {
  final String label;
  final String sub;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _ModeBtn({
    required this.label,
    required this.sub,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? accent.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: selected
                ? Border.all(color: accent.withOpacity(0.6))
                : null,
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: selected ? accent : Colors.white38,
                  fontSize: 14,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                sub,
                style: TextStyle(
                  color: selected ? accent.withOpacity(0.7) : Colors.white24,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Mock screen demo ───────────────────────────────────────────────────────────
class _MockScreenDemo extends StatelessWidget {
  final bool isBeta;
  final Animation<double> pulseAnim;
  final VoidCallback onFabTap;

  const _MockScreenDemo({
    required this.isBeta,
    required this.pulseAnim,
    required this.onFabTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 320,
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(
          color: isBeta
              ? const Color(0xFFF97316).withOpacity(0.4)
              : const Color(0xFF2A2A2A),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ZapSpacing.radius - 1),
        child: Stack(
          children: [
            // ── Mock app content ──────────────────────────────────────
            Positioned.fill(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Beta banner (when beta)
                  if (isBeta)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          vertical: 5, horizontal: ZapSpacing.md),
                      color: const Color(0xFFF97316).withOpacity(0.8),
                      child: const Text(
                        '⚡  BETA  ·  Feedback button active',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  // Mock app bar
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: ZapSpacing.md, vertical: 10),
                    color: const Color(0xFF0F0F0F),
                    child: Row(
                      children: [
                        const Text(
                          'ZapSafe',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'PROTECTED',
                            style: TextStyle(
                              color: Color(0xFF10B981),
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Mock body
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(ZapSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Dashboard',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: ZapSpacing.sm),
                          const Text(
                            'Tap the orange button →',
                            style: TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: ZapSpacing.md),
                          // Mock content cards
                          const _MockCard(
                            icon: Icons.shield_rounded,
                            color: Color(0xFF10B981),
                            label: 'Detection active',
                          ),
                          const SizedBox(height: ZapSpacing.sm),
                          const _MockCard(
                            icon: Icons.people_rounded,
                            color: Color(0xFF3B82F6),
                            label: '3 emergency contacts',
                          ),
                          const SizedBox(height: ZapSpacing.sm),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: const EdgeInsets.symmetric(
                                vertical: 10, horizontal: 12),
                            decoration: BoxDecoration(
                              color: isBeta
                                  ? const Color(0xFFF97316).withOpacity(0.08)
                                  : const Color(0xFF2A2A2A),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isBeta
                                    ? const Color(0xFFF97316)
                                        .withOpacity(0.3)
                                    : const Color(0xFF3A3A3A),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isBeta
                                      ? Icons.feedback_rounded
                                      : Icons.feedback_outlined,
                                  color: isBeta
                                      ? const Color(0xFFF97316)
                                      : Colors.white24,
                                  size: 16,
                                ),
                                const SizedBox(width: ZapSpacing.sm),
                                Text(
                                  isBeta
                                      ? 'Feedback FAB  ·  tap the button →'
                                      : 'Feedback FAB  ·  hidden in prod',
                                  style: TextStyle(
                                    color: isBeta
                                        ? const Color(0xFFF97316)
                                        : Colors.white24,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Feedback FAB (beta only) ──────────────────────────────
            if (isBeta)
              Positioned(
                right: 16,
                bottom: 16,
                child: GestureDetector(
                  onTap: onFabTap,
                  child: ScaleTransition(
                    scale: pulseAnim,
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF97316),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFF97316).withOpacity(0.5),
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.feedback_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              )
            else
              // Prod: show greyed-out hidden indicator
              const Positioned(
                right: 16,
                bottom: 16,
                child: Opacity(
                  opacity: 0.18,
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color(0xFF3A3A3A),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.feedback_outlined,
                        color: Colors.white38,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MockCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;

  const _MockCard({
    required this.icon,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: ZapSpacing.sm),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ── Mini feedback sheet ────────────────────────────────────────────────────────
class _MiniSheet extends StatefulWidget {
  const _MiniSheet();

  @override
  State<_MiniSheet> createState() => _MiniSheetState();
}

class _MiniSheetState extends State<_MiniSheet> {
  int _rating = 0;
  bool _sent = false;
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _send() {
    if (_rating == 0) return;
    setState(() => _sent = true);
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: ZapSpacing.lg,
        right: ZapSpacing.lg,
        top: ZapSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + ZapSpacing.xl,
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _sent ? _buildSentState() : _buildForm(),
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      key: const ValueKey('form'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Handle bar
        Center(
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF4B5563),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        // Header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF97316).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.feedback_rounded,
                  color: Color(0xFFF97316), size: 18),
            ),
            const SizedBox(width: ZapSpacing.sm),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick Feedback',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Screen: Day 113 · Feedback FAB',
                  style: TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: const Icon(Icons.close_rounded,
                  color: Color(0xFF6B7280), size: 22),
            ),
          ],
        ),
        const SizedBox(height: ZapSpacing.lg),
        // Star rating
        const Text(
          'How was your experience?',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        const SizedBox(height: ZapSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (i) {
            final filled = i < _rating;
            return GestureDetector(
              onTap: () => setState(() => _rating = i + 1),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Icon(
                  filled ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: filled
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF4B5563),
                  size: 36,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: ZapSpacing.lg),
        // Text input
        TextField(
          controller: _ctrl,
          maxLines: 3,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'What\'s on your mind? (optional)',
            hintStyle: const TextStyle(color: Color(0xFF4B5563), fontSize: 13),
            filled: true,
            fillColor: const Color(0xFF111111),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFF97316)),
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        // Send button
        GestureDetector(
          onTap: _send,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: _rating > 0
                  ? const Color(0xFFF97316)
                  : const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            ),
            child: Center(
              child: Text(
                _rating > 0 ? 'Send Quick Feedback' : 'Select a rating first',
                style: TextStyle(
                  color: _rating > 0 ? Colors.white : const Color(0xFF4B5563),
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        // Link to full form
        const Center(
          child: Text(
            'Full feedback form with categories → Day 114',
            style: TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSentState() {
    return const SizedBox(
      key: ValueKey('sent'),
      height: 180,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_rounded,
              color: Color(0xFF10B981), size: 52),
          SizedBox(height: ZapSpacing.md),
          Text(
            'Feedback sent!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: ZapSpacing.sm),
          Text(
            'Thank you — this helps improve ZapSafe.',
            style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ── Integration code card ──────────────────────────────────────────────────────
class _IntegrationCard extends StatelessWidget {
  const _IntegrationCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FileChip('any_screen.dart · Scaffold.floatingActionButton'),
          SizedBox(height: ZapSpacing.md),
          Text(
            'import \'../widgets/feedback_fab.dart\';\n'
            '\n'
            '// Inside any Scaffold:\n'
            'Scaffold(\n'
            '  floatingActionButton: FeedbackFab(\n'
            '    visible: FlavorConfig.isBeta,  // auto-hides in prod\n'
            '    onTap: () => FeedbackSheet.show(context),\n'
            '  ),\n'
            '  body: ...,\n'
            ')',
            style: TextStyle(
              color: Color(0xFFE6EDF3),
              fontSize: 12,
              fontFamily: 'monospace',
              height: 1.7,
            ),
          ),
          Divider(height: ZapSpacing.xl, color: Color(0xFF30363D)),
          _FileChip('Stack approach (precise position)'),
          SizedBox(height: ZapSpacing.md),
          Text(
            'Stack(\n'
            '  children: [\n'
            '    YourScreenBody(),\n'
            '    Positioned(\n'
            '      right: 16, bottom: 24,\n'
            '      child: FeedbackFab(\n'
            '        visible: FlavorConfig.isBeta,\n'
            '        onTap: () => FeedbackSheet.show(context),\n'
            '      ),\n'
            '    ),\n'
            '  ],\n'
            ')',
            style: TextStyle(
              color: Color(0xFFE6EDF3),
              fontSize: 12,
              fontFamily: 'monospace',
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Widget API card ────────────────────────────────────────────────────────────
class _WidgetApiCard extends StatelessWidget {
  const _WidgetApiCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: const Column(
        children: [
          _ApiRow('visible',  'bool',         'false',  'Hides widget when false (use FlavorConfig.isBeta)'),
          Divider(height: 1, color: Color(0xFF2A2A2A)),
          _ApiRow('onTap',    'VoidCallback?', 'null',   'Called on button press — open FeedbackSheet'),
          Divider(height: 1, color: Color(0xFF2A2A2A)),
          _ApiRow('heroTag',  'String',        '"zap_feedback_fab"', 'Unique hero tag — override if multiple FABs'),
        ],
      ),
    );
  }
}

class _ApiRow extends StatelessWidget {
  final String param;
  final String type;
  final String defaultVal;
  final String description;

  const _ApiRow(this.param, this.type, this.defaultVal, this.description);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: ZapSpacing.md, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                param,
                style: const TextStyle(
                  color: Color(0xFF79C0FF),
                  fontSize: 12,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: ZapSpacing.sm),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  type,
                  style: const TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'default: $defaultVal',
                style: const TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 10,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.xs),
          Text(
            description,
            style: const TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 11,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Checklist ──────────────────────────────────────────────────────────────────
const _kChecks = <(String, bool)>[
  ('FeedbackFab widget created (lib/presentation/widgets/feedback_fab.dart)',  true),
  ('visible param — hides automatically in prod (FlavorConfig.isBeta)',        true),
  ('Pulse animation (ScaleTransition 1.0→1.18) draws attention on first open', true),
  ('Orange glow boxShadow on FAB in beta mode',                                true),
  ('FAB hidden (opacity 0.18) in prod mode for visual comparison',             true),
  ('showModalBottomSheet quick-feedback sheet with star rating',               true),
  ('5-star tap-to-rate row (StatefulWidget in sheet)',                         true),
  ('Optional text field for comments',                                         true),
  ('Send button gated on rating > 0 — grey when no star selected',            true),
  ('1.4s mock send → success state → auto-dismiss',                           true),
  ('"Full feedback form → Day 114" link in sheet',                             true),
  ('Integration code snippet (floatingActionButton + Stack approaches)',       true),
];

class _Checklist extends StatelessWidget {
  const _Checklist();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(
        children: List.generate(_kChecks.length, (i) {
          final (text, done) = _kChecks[i];
          final isLast = i == _kChecks.length - 1;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: ZapSpacing.md, vertical: 10),
                child: Row(
                  children: [
                    Icon(
                      done
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: done
                          ? const Color(0xFF10B981)
                          : Colors.white24,
                      size: 16,
                    ),
                    const SizedBox(width: ZapSpacing.sm),
                    Expanded(
                      child: Text(
                        text,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast)
                const Divider(height: 1, color: Color(0xFF2A2A2A)),
            ],
          );
        }),
      ),
    );
  }
}

// ── Shared helpers ─────────────────────────────────────────────────────────────
class _FileChip extends StatelessWidget {
  final String label;
  const _FileChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2128),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF79C0FF),
          fontSize: 10,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}
