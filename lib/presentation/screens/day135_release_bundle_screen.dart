/// Day 135 — Build & Release v0.5-beta #2
///
/// Bundles all fixes from Days 121-134 into one release:
///   v0.5.1 — Crash fixes × 3 (Android 11 SMS, iPhone 7 OOM, TFLite)
///   v0.5.2 — False positive fixes (threshold + explanation card)
///   v0.5.3 — Notification improvements (Doze fix, contact delivery)
///   v0.5.4 — Performance (cold start 5.2s→1.8s, battery 20%→6%/hr)
///   v0.5.5 — Memory leak fixes × 5 (13 MB/min eliminated)
///   v0.5.6 — Onboarding simplification (7 steps→4, < 2 min)
///
/// Today: write release notes → tag git → build → sign → upload both
/// platforms → notify 847 testers → monitor first-hour metrics.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';

// ── Providers ──────────────────────────────────────────────────────────────────
final _buildStateProvider   = StateProvider<_BuildState>((ref) => _BuildState.idle);
final _notifyStateProvider  = StateProvider<_NotifyState>((ref) => _NotifyState.idle);
final _activeTabProvider    = StateProvider<int>((ref) => 0);
final _hoursProvider        = StateProvider<int>((ref) => 0);
final _metricsProvider      = StateProvider<bool>((ref) => false);

enum _BuildState  { idle, tagging, building, signing, uploading, reviewing, live }
enum _NotifyState { idle, sending, sent }

// ── Data ───────────────────────────────────────────────────────────────────────
class _Release {
  final String version;
  final String date;
  final Color  color;
  final IconData icon;
  final List<String> changes;
  const _Release({
    required this.version,
    required this.date,
    required this.color,
    required this.icon,
    required this.changes,
  });
}

const _kReleases = [
  _Release(
    version: 'v0.5.1',
    date: '2026-05-31',
    color: Color(0xFFEF4444),
    icon: Icons.bug_report_rounded,
    changes: [
      '🐛 Fixed: Android 11 SMS crash on SOS send (51 users)',
      '🐛 Fixed: iPhone 7 OOM after 20 min — location leak (32 users)',
      '🐛 Fixed: TFLite OOM on < 2 GB RAM devices (19 users)',
    ],
  ),
  _Release(
    version: 'v0.5.2',
    date: '2026-06-02',
    color: Color(0xFFF59E0B),
    icon: Icons.warning_amber_rounded,
    changes: [
      '✨ Post-SOS explanation card (trigger + confidence % shown)',
      '⚡ M1 scream threshold 0.80 → 0.88 (movie audio no longer triggers)',
      '✨ ALERT_PENDING shows detection reason during countdown',
      '✨ Model info cards in Settings → Detection',
    ],
  ),
  _Release(
    version: 'v0.5.3',
    date: '2026-06-04',
    color: Color(0xFF3B82F6),
    icon: Icons.notifications_rounded,
    changes: [
      '✨ Per-contact delivery status (pending→delivered→opened→responded)',
      '⚡ Notification text clarity ("Emergency alert sent to 5 contacts")',
      '⚡ Samsung Android 13 Doze fix — delivery < 2s',
      '⚡ Xiaomi/Huawei AutoStart detection + user prompt',
    ],
  ),
  _Release(
    version: 'v0.5.4',
    date: '2026-06-06',
    color: Color(0xFF8B5CF6),
    icon: Icons.speed_rounded,
    changes: [
      '⚡ Cold start: 5.2s → 1.8s (DB/TFLite/GPS deferred to post-frame)',
      '⚡ Battery: 20%/hr → 6%/hr (adaptive GPS + batched audio)',
      '⚡ RAM: 195 MB → 58 MB (image cache + GPS buffer capped)',
      '⚡ 7 non-critical screens lazy-loaded',
    ],
  ),
  _Release(
    version: 'v0.5.5',
    date: '2026-06-08',
    color: Color(0xFFF97316),
    icon: Icons.leak_remove_rounded,
    changes: [
      '🐛 Fixed: AnimationController leak in 4 screens',
      '🐛 Fixed: StreamSubscription leak in 4 providers',
      '🐛 Fixed: GpsService reference-count (stops when 0 consumers)',
      '🐛 Fixed: SQLite singleton — no per-query open/close',
      '🐛 Fixed: Timer.cancel() guard in DcsEngine',
    ],
  ),
  _Release(
    version: 'v0.5.6',
    date: '2026-06-10',
    color: Color(0xFF10B981),
    icon: Icons.route_rounded,
    changes: [
      '✨ Onboarding: 7 steps → 4 steps',
      '✨ Permission rationale cards before each system dialog',
      '✨ Skip paths: contacts optional, SOS test optional',
      '⚡ Onboarding time: 5 min → < 2 min',
      '📊 Target abandon rate: 34% → < 8%',
    ],
  ),
];

// Metrics comparison
class _Metric {
  final String label;
  final String before;
  final String after;
  final Color  color;
  final IconData icon;
  const _Metric(this.label, this.before, this.after, this.color, this.icon);
}

const _kMetrics = [
  _Metric('Crash rate',           '0.31%',  '0.10%',  Color(0xFF10B981), Icons.bug_report_rounded),
  _Metric('False positive rate',  '7.8%',   '4.8%',   Color(0xFF10B981), Icons.warning_amber_rounded),
  _Metric('Notification delay',   '> 30s',  '< 2s',   Color(0xFF10B981), Icons.notifications_rounded),
  _Metric('Cold start',           '5.2s',   '1.8s',   Color(0xFF10B981), Icons.speed_rounded),
  _Metric('Battery/hr',           '20%',    '6%',     Color(0xFF10B981), Icons.battery_charging_full_rounded),
  _Metric('Peak RAM',             '195 MB', '58 MB',  Color(0xFF10B981), Icons.memory_rounded),
  _Metric('Onboarding abandon',   '34%',    '< 8%',   Color(0xFF10B981), Icons.route_rounded),
  _Metric('Memory leak rate',     '13 MB/min','0',    Color(0xFF10B981), Icons.leak_remove_rounded),
];

const _kBuildSteps = [
  (Color(0xFF6B7280), 'idle',      ''),
  (Color(0xFF3B82F6), 'tagging',   'git tag v0.5-beta-2 && git push…'),
  (Color(0xFF8B5CF6), 'building',  'flutter build appbundle --flavor beta --release…'),
  (Color(0xFFF59E0B), 'signing',   'Signing with release keystore…'),
  (Color(0xFFF97316), 'uploading', 'Uploading AAB + IPA to stores…'),
  (Color(0xFFEF4444), 'reviewing', 'Waiting for Apple review (~30 min)…'),
  (Color(0xFF10B981), 'live',      'v0.5-beta-2 live on both platforms!'),
];

// ── Screen ─────────────────────────────────────────────────────────────────────
class Day135ReleaseBundleScreen extends ConsumerWidget {
  const Day135ReleaseBundleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab        = ref.watch(_activeTabProvider);
    final buildState = ref.watch(_buildStateProvider);
    final isLive     = buildState == _BuildState.live;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Day 135 · Release v0.5-beta-2'),
        elevation: 0,
        actions: [
          if (isLive)
            TextButton(
              onPressed: () {
                ref.read(_buildStateProvider.notifier).state   = _BuildState.idle;
                ref.read(_notifyStateProvider.notifier).state  = _NotifyState.idle;
                ref.read(_hoursProvider.notifier).state        = 0;
                ref.read(_metricsProvider.notifier).state      = false;
              },
              child: const Text('Reset',
                  style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Hero(),
            const SizedBox(height: ZapSpacing.xl),

            // Tab bar
            const _SectionLabel('SELECT VIEW'),
            const SizedBox(height: ZapSpacing.md),
            _TabBar(active: tab,
                onSelect: (t) =>
                    ref.read(_activeTabProvider.notifier).state = t),
            const SizedBox(height: ZapSpacing.xl),

            if (tab == 0) const _ReleaseNotesTab(),
            if (tab == 1) const _MetricsTab(),
            const SizedBox(height: ZapSpacing.xl),

            // Build + release
            const _SectionLabel('BUILD & RELEASE  ·  v0.5-beta-2'),
            const SizedBox(height: ZapSpacing.md),
            const _BuildPanel(),
            const SizedBox(height: ZapSpacing.xl),

            // Notify testers (after live)
            if (isLive) ...[
              const _SectionLabel('NOTIFY 847 TESTERS'),
              const SizedBox(height: ZapSpacing.md),
              const _NotifyPanel(),
              const SizedBox(height: ZapSpacing.xl),
            ],

            // First-hour metrics (after notified)
            if (ref.watch(_notifyStateProvider) == _NotifyState.sent) ...[
              const _SectionLabel('FIRST-HOUR MONITORING'),
              const SizedBox(height: ZapSpacing.md),
              const _FirstHourMetrics(),
              const SizedBox(height: ZapSpacing.xl),
            ],

            // Next
            const _SectionLabel('NEXT  ·  DAYS 136-140'),
            const SizedBox(height: ZapSpacing.md),
            const _NextCard(),
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
          colors: [Color(0xFF0D2010), Color(0xFF070F08), Color(0xFF0A0A0A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _badge('⚡  BETA  ·  DAY 135', const Color(0xFF10B981)),
            const SizedBox(width: ZapSpacing.sm),
            _badge('v0.5-beta-2 🚀', const Color(0xFF3B82F6)),
          ]),
          const SizedBox(height: ZapSpacing.md),
          const Text(
            'Bundle & Release\nv0.5-beta-2',
            style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w900,
                height: 1.2),
          ),
          const SizedBox(height: ZapSpacing.sm),
          const Text(
            '14 days of fixes (Days 121-134) bundled into one release. '
            '6 patch versions → v0.5-beta-2 final. '
            'Crash rate 0.31%→0.10%, battery 20%→6%, onboarding 34%→<8% abandon.',
            style: TextStyle(
                color: Color(0xFFD1D5DB), fontSize: 12, height: 1.6),
          ),
          const SizedBox(height: ZapSpacing.md),
          const Row(children: [
            _HStat('14',  'Days fixed',   Color(0xFF10B981)),
            _HStat('6',   'Patch versions',Color(0xFF3B82F6)),
            _HStat('847', 'Testers',      Color(0xFFF59E0B)),
            _HStat('Day\n135', 'Bundle day', Color(0xFF8B5CF6)),
          ]),
        ],
      ),
    );
  }

  Widget _badge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Text(label,
            style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5)),
      );
}

class _HStat extends StatelessWidget {
  final String value, label;
  final Color  color;
  const _HStat(this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w800),
              textAlign: TextAlign.center),
          Text(label,
              style: const TextStyle(
                  color: Color(0xFF9CA3AF), fontSize: 9, height: 1.3),
              textAlign: TextAlign.center),
        ]),
      );
}

// ── Section label ──────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) => Text(label,
      style: const TextStyle(
          color: Color(0xFF6B7280),
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5));
}

// ── Tab bar ────────────────────────────────────────────────────────────────────
class _TabBar extends StatelessWidget {
  final int active;
  final ValueChanged<int> onSelect;
  const _TabBar({required this.active, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.new_releases_rounded,    Color(0xFF10B981), 'Release Notes'),
      (Icons.bar_chart_rounded,       Color(0xFF3B82F6), 'Metrics'),
    ];
    return Row(
      children: List.generate(2, (i) {
        final (icon, color, label) = items[i];
        final isActive = i == active;
        return Expanded(
          child: GestureDetector(
            onTap: () => onSelect(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: EdgeInsets.only(right: i == 0 ? ZapSpacing.sm : 0),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: isActive
                    ? color.withOpacity(0.12)
                    : const Color(0xFF1A1A1A),
                borderRadius:
                    BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                  color: isActive
                      ? color.withOpacity(0.5)
                      : const Color(0xFF2A2A2A),
                  width: isActive ? 2 : 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon,
                      color: isActive ? color : const Color(0xFF6B7280),
                      size: 18),
                  const SizedBox(width: 6),
                  Text(label,
                      style: TextStyle(
                          color: isActive
                              ? color
                              : const Color(0xFF6B7280),
                          fontSize: 12,
                          fontWeight: isActive
                              ? FontWeight.w700
                              : FontWeight.w400)),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ── Release Notes Tab ──────────────────────────────────────────────────────────
class _ReleaseNotesTab extends StatelessWidget {
  const _ReleaseNotesTab();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Version header
        _codeNote('git',
            'git tag v0.5-beta-2 -m "Beta iteration 2 — Days 121-134"\n'
            'git push origin v0.5-beta-2'),
        const SizedBox(height: ZapSpacing.lg),

        // Release cards (newest first)
        ..._kReleases.reversed.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
              child: _ReleaseCard(release: r),
            )),

        const SizedBox(height: ZapSpacing.md),
        // Full changelog preview
        const _SectionLabel('FULL CHANGELOG  ·  WHAT TESTERS SEE'),
        const SizedBox(height: ZapSpacing.md),
        const _ChangelogPreview(),
      ],
    );
  }
}

class _ReleaseCard extends StatefulWidget {
  final _Release release;
  const _ReleaseCard({required this.release});

  @override
  State<_ReleaseCard> createState() => _ReleaseCardState();
}

class _ReleaseCardState extends State<_ReleaseCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.release;
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: _expanded
              ? r.color.withOpacity(0.07)
              : const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(
            color: _expanded
                ? r.color.withOpacity(0.4)
                : const Color(0xFF2A2A2A),
          ),
        ),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(ZapSpacing.md),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: r.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(r.icon, color: r.color, size: 18),
              ),
              const SizedBox(width: ZapSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.version,
                        style: TextStyle(
                            color: r.color,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'monospace')),
                    Text(r.date,
                        style: const TextStyle(
                            color: Color(0xFF6B7280), fontSize: 10)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: r.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('${r.changes.length} changes',
                    style: TextStyle(
                        color: r.color,
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: ZapSpacing.sm),
              Icon(
                _expanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: const Color(0xFF4B5563), size: 18),
            ]),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(
                        ZapSpacing.md, 0, ZapSpacing.md, ZapSpacing.md),
                    child: Column(children: [
                      const Divider(
                          height: ZapSpacing.md, color: Color(0xFF2A2A2A)),
                      ...r.changes.map((c) => Padding(
                            padding: const EdgeInsets.only(bottom: 5),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  c.substring(0, 2),
                                  style: const TextStyle(
                                      fontSize: 13, height: 1.4),
                                ),
                                const SizedBox(width: ZapSpacing.xs),
                                Expanded(
                                  child: Text(c.substring(2),
                                      style: const TextStyle(
                                          color: Color(0xFFD1D5DB),
                                          fontSize: 12,
                                          height: 1.4)),
                                ),
                              ],
                            ),
                          )),
                    ]),
                  )
                : const SizedBox.shrink(),
          ),
        ]),
      ),
    );
  }
}

class _ChangelogPreview extends StatelessWidget {
  const _ChangelogPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('v0.5-beta-2',
                  style: TextStyle(
                      color: Color(0xFF10B981),
                      fontSize: 11,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: ZapSpacing.sm),
            const Text('ZapSafe Beta — What\'s New',
                style: TextStyle(
                    color: Color(0xFF79C0FF),
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: ZapSpacing.md),
          const Text(
            'This update fixes crashes, improves battery life, '
            'and makes the app easier to set up.\n\n'
            '✅ Fixed: App no longer crashes on Android 11 when sending SOS\n'
            '✅ Fixed: App stable after 30+ minutes in background\n'
            '⚡ SOS notifications now arrive in under 2 seconds\n'
            '⚡ Battery usage reduced by 70%\n'
            '⚡ App launches 3× faster\n'
            '✨ Onboarding is now simpler — takes less than 2 minutes\n'
            '✨ SOS now shows why it triggered (e.g. "Scream detected")\n'
            '✨ See when each contact receives your alert\n\n'
            'Thank you for helping make ZapSafe better! 🙏',
            style: TextStyle(
                color: Color(0xFFE6EDF3),
                fontSize: 12,
                fontFamily: 'monospace',
                height: 1.7),
          ),
        ],
      ),
    );
  }
}

// ── Metrics Tab ────────────────────────────────────────────────────────────────
class _MetricsTab extends StatelessWidget {
  const _MetricsTab();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary card
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              const Color(0xFF10B981).withOpacity(0.12),
              const Color(0xFF10B981).withOpacity(0.04),
            ]),
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
            border: Border.all(
                color: const Color(0xFF10B981).withOpacity(0.4)),
          ),
          child: Column(children: [
            const Row(children: [
              Icon(Icons.trending_down_rounded,
                  color: Color(0xFF10B981), size: 22),
              SizedBox(width: ZapSpacing.sm),
              Text('Days 121-134 Impact Summary',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: ZapSpacing.md),
            Wrap(
              spacing: ZapSpacing.sm,
              runSpacing: ZapSpacing.sm,
              children: _kMetrics.map((m) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: ZapSpacing.sm, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: const Color(0xFF10B981).withOpacity(0.3)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(m.icon,
                          color: const Color(0xFF10B981), size: 13),
                      const SizedBox(width: 5),
                      Text('${m.before} → ${m.after}',
                          style: const TextStyle(
                              color: Color(0xFFD1D5DB),
                              fontSize: 11)),
                    ]),
                  )).toList(),
            ),
          ]),
        ),
        const SizedBox(height: ZapSpacing.lg),

        // Per-metric rows
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          child: Column(
            children: _kMetrics.asMap().entries.map((e) {
              final i      = e.key;
              final m      = e.value;
              final isLast = i == _kMetrics.length - 1;
              return Column(children: [
                Padding(
                  padding: const EdgeInsets.all(ZapSpacing.md),
                  child: Row(children: [
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: m.color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(m.icon, color: m.color, size: 16),
                    ),
                    const SizedBox(width: ZapSpacing.md),
                    Expanded(
                      child: Text(m.label,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13)),
                    ),
                    // Before → After
                    Row(children: [
                      Text(m.before,
                          style: const TextStyle(
                              color: Color(0xFFEF4444),
                              fontSize: 12,
                              fontFamily: 'monospace',
                              decoration: TextDecoration.lineThrough,
                              decorationColor: Color(0xFFEF4444))),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(Icons.arrow_forward_rounded,
                            color: Color(0xFF4B5563), size: 12),
                      ),
                      Text(m.after,
                          style: TextStyle(
                              color: m.color,
                              fontSize: 13,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w700)),
                    ]),
                  ]),
                ),
                if (!isLast)
                  const Divider(height: 1, color: Color(0xFF2A2A2A)),
              ]);
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ── Build Panel ────────────────────────────────────────────────────────────────
class _BuildPanel extends ConsumerWidget {
  const _BuildPanel();

  static const _kStates = [
    _BuildState.idle,
    _BuildState.tagging,
    _BuildState.building,
    _BuildState.signing,
    _BuildState.uploading,
    _BuildState.reviewing,
    _BuildState.live,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_buildStateProvider);
    final idx   = _kStates.indexOf(state);

    return Container(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        color: state == _BuildState.live
            ? const Color(0xFF10B981).withOpacity(0.07)
            : const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(
          color: state == _BuildState.live
              ? const Color(0xFF10B981).withOpacity(0.4)
              : const Color(0xFF2A2A2A),
        ),
      ),
      child: Column(children: [
        if (state == _BuildState.idle)
          _actionButton(
            label: 'Start release pipeline',
            icon: Icons.rocket_launch_rounded,
            color: const Color(0xFF10B981),
            onTap: () async {
              for (final s in _kStates.skip(1)) {
                if (!context.mounted) return;
                ref.read(_buildStateProvider.notifier).state = s;
                await Future.delayed(Duration(
                  milliseconds: s == _BuildState.reviewing ? 1800 : 800,
                ));
              }
            },
          )
        else if (state == _BuildState.live) ...[
          const Icon(Icons.check_circle_rounded,
              color: Color(0xFF10B981), size: 52),
          const SizedBox(height: ZapSpacing.md),
          const Text('v0.5-beta-2 is LIVE!',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: ZapSpacing.sm),
          const Text(
            'Available on TestFlight + Google Play Internal Testing',
            style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: ZapSpacing.md),
          Row(children: [
            Expanded(child: _linkChip(
                'testflight.apple.com/join/zApSaFe-v2',
                const Color(0xFF3B82F6))),
          ]),
          const SizedBox(height: ZapSpacing.sm),
          Row(children: [
            Expanded(child: _linkChip(
                'play.google.com/apps/testing/com.zapsafe.beta',
                const Color(0xFF3DDC84))),
          ]),
        ] else
          // Progress steps
          ...List.generate(6, (i) {
            final _ = _kStates[i + 1];
            final stepLabel  = _kBuildSteps[i + 1].$3;
            final stepColor  = _kBuildSteps[i + 1].$1;
            final isDone     = i + 1 < idx;
            final isActive   = i + 1 == idx;

            return Padding(
              padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
              child: Row(children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: isDone
                        ? const Color(0xFF10B981).withOpacity(0.15)
                        : isActive
                            ? stepColor.withOpacity(0.15)
                            : const Color(0xFF111111),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDone
                          ? const Color(0xFF10B981).withOpacity(0.5)
                          : isActive
                              ? stepColor.withOpacity(0.6)
                              : const Color(0xFF2A2A2A),
                    ),
                  ),
                  child: isDone
                      ? const Icon(Icons.check_rounded,
                          color: Color(0xFF10B981), size: 14)
                      : isActive
                          ? Padding(
                              padding: const EdgeInsets.all(5),
                              child: CircularProgressIndicator(
                                  color: stepColor, strokeWidth: 2))
                          : null,
                ),
                const SizedBox(width: ZapSpacing.md),
                Text(stepLabel,
                    style: TextStyle(
                      color: isDone
                          ? const Color(0xFF6B7280)
                          : isActive
                              ? Colors.white
                              : const Color(0xFF4B5563),
                      fontSize: 13,
                      fontWeight:
                          isActive ? FontWeight.w600 : FontWeight.w400,
                    )),
              ]),
            );
          }),
      ]),
    );
  }

  Widget _linkChip(String url, Color color) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: ZapSpacing.sm, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1117),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          border: Border.all(color: const Color(0xFF30363D)),
        ),
        child: Text(url,
            style: TextStyle(
                color: color, fontSize: 10, fontFamily: 'monospace'),
            textAlign: TextAlign.center),
      );
}

// ── Notify Panel ───────────────────────────────────────────────────────────────
class _NotifyPanel extends ConsumerWidget {
  const _NotifyPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(_notifyStateProvider);

    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(
          color: state == _NotifyState.sent
              ? const Color(0xFF10B981).withOpacity(0.35)
              : const Color(0xFF2A2A2A),
        ),
      ),
      child: Column(children: [
        // Notification preview
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [ZapColors.danger, Color(0xFFB01F2A)]),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.bolt_rounded,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: ZapSpacing.md),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ZapSafe Beta · Update available',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                  Text(
                    'v0.5-beta-2 fixes crashes + 70% battery saving + '
                    'faster onboarding. Update now.',
                    style: TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 11,
                        height: 1.4),
                  ),
                ],
              ),
            ),
          ]),
        ),
        const SizedBox(height: ZapSpacing.lg),

        if (state == _NotifyState.idle)
          _actionButton(
            label: 'Send update notification to 847 testers',
            icon: Icons.notifications_active_rounded,
            color: const Color(0xFF3B82F6),
            onTap: () async {
              ref.read(_notifyStateProvider.notifier).state =
                  _NotifyState.sending;
              await Future.delayed(const Duration(milliseconds: 1200));
              if (!context.mounted) return;
              ref.read(_notifyStateProvider.notifier).state =
                  _NotifyState.sent;
              _simulateHours(ref, context);
            },
          )
        else if (state == _NotifyState.sending)
          _statusChip(Icons.send_rounded, const Color(0xFF3B82F6),
              'Sending FCM push to 847 devices…', loading: true)
        else
          _statusChip(Icons.check_circle_rounded, const Color(0xFF10B981),
              '847 testers notified — monitoring metrics'),
      ]),
    );
  }

  void _simulateHours(WidgetRef ref, BuildContext context) async {
    for (int i = 1; i <= 3; i++) {
      await Future.delayed(const Duration(milliseconds: 400));
      if (!context.mounted) return;
      ref.read(_hoursProvider.notifier).state = i;
      if (i == 3) {
        ref.read(_metricsProvider.notifier).state = true;
      }
    }
  }
}

// ── First Hour Metrics ─────────────────────────────────────────────────────────
class _FirstHourMetrics extends ConsumerWidget {
  const _FirstHourMetrics();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hours   = ref.watch(_hoursProvider);
    final hasData = ref.watch(_metricsProvider);

    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Post-release monitoring',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            Text('${hours}h post-release',
                style: const TextStyle(
                    color: Color(0xFF9CA3AF), fontSize: 11)),
          ],
        ),
        const SizedBox(height: ZapSpacing.md),

        if (!hasData)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(ZapSpacing.md),
              child: Column(children: [
                CircularProgressIndicator(
                    color: Color(0xFF10B981), strokeWidth: 2),
                SizedBox(height: ZapSpacing.sm),
                Text('Waiting for first-hour data…',
                    style: TextStyle(
                        color: Color(0xFF9CA3AF), fontSize: 12)),
              ]),
            ),
          )
        else ...[
          // Metric grid
          Row(children: [
            _miniMetric('Crash rate',   '0.09%', const Color(0xFF10B981), Icons.bug_report_rounded),
            const SizedBox(width: ZapSpacing.sm),
            _miniMetric('Testers updated', '612', const Color(0xFF3B82F6), Icons.system_update_rounded),
            const SizedBox(width: ZapSpacing.sm),
            _miniMetric('Avg open time', '14 min', const Color(0xFF8B5CF6), Icons.timer_rounded),
          ]),
          const SizedBox(height: ZapSpacing.sm),
          Row(children: [
            _miniMetric('Onboarding done', '89%', const Color(0xFF10B981), Icons.route_rounded),
            const SizedBox(width: ZapSpacing.sm),
            _miniMetric('New crashes',    '0',    const Color(0xFF10B981), Icons.new_releases_rounded),
            const SizedBox(width: ZapSpacing.sm),
            _miniMetric('FP reports',     '3',    const Color(0xFFF59E0B), Icons.warning_amber_rounded),
          ]),
          const SizedBox(height: ZapSpacing.md),
          Container(
            padding: const EdgeInsets.all(ZapSpacing.sm),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.07),
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              border: Border.all(
                  color: const Color(0xFF10B981).withOpacity(0.3)),
            ),
            child: const Row(children: [
              Icon(Icons.check_circle_rounded,
                  color: Color(0xFF10B981), size: 14),
              SizedBox(width: ZapSpacing.sm),
              Expanded(
                child: Text(
                  'First-hour metrics: all green ✅  '
                  'Crash rate 0.09% (below 0.10% target). '
                  'No P0 events. Proceeding to Days 136-137 feedback round.',
                  style: TextStyle(
                      color: Color(0xFFD1D5DB), fontSize: 11, height: 1.5),
                ),
              ),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _miniMetric(String label, String value, Color color, IconData icon) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(
              vertical: ZapSpacing.sm, horizontal: ZapSpacing.sm),
          decoration: BoxDecoration(
            color: color.withOpacity(0.07),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: ZapSpacing.xs),
            Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w800)),
            Text(label,
                style: const TextStyle(
                    color: Color(0xFF9CA3AF), fontSize: 8, height: 1.3),
                textAlign: TextAlign.center),
          ]),
        ),
      );
}

// ── Next Card ──────────────────────────────────────────────────────────────────
class _NextCard extends StatelessWidget {
  const _NextCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Column(children: [
        _row(const Color(0xFF3B82F6), 'Days 136-137',
            'Second feedback round — ask testers if fixes landed, '
            'measure retention, crash rate, FP rate after v0.5-beta-2'),
        const Divider(height: 1, color: Color(0xFF2A2A2A)),
        _row(const Color(0xFF8B5CF6), 'Days 138-139',
            'Final polish — P0/P1 bug fixes only, no new features. '
            'Final accessibility check + security scan'),
        const Divider(height: 1, color: Color(0xFF2A2A2A)),
        _row(const Color(0xFF10B981), 'Day 140',
            'Tag v0.5-beta-final — production-ready app, '
            'all tests pass, ready for App Store submission (Days 141+)'),
      ]),
    );
  }

  Widget _row(Color color, String days, String action) => Padding(
        padding: const EdgeInsets.all(ZapSpacing.md),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              width: 8, height: 8,
              margin: const EdgeInsets.only(top: 4),
              decoration:
                  BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: ZapSpacing.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(days,
                  style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
              Text(action,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 13, height: 1.4)),
            ]),
          ),
        ]),
      );
}

// ── Shared helpers ─────────────────────────────────────────────────────────────
Widget _actionButton({
  required String label,
  required IconData icon,
  required Color color,
  required VoidCallback onTap,
}) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [color, color.withOpacity(0.8)]),
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 14,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: ZapSpacing.sm),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
        ]),
      ),
    );

Widget _statusChip(IconData icon, Color color, String label,
        {bool loading = false}) =>
    Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        loading
            ? SizedBox(
                width: 16, height: 16,
                child: CircularProgressIndicator(color: color, strokeWidth: 2))
            : Icon(icon, color: color, size: 16),
        const SizedBox(width: ZapSpacing.sm),
        Text(label,
            style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      ]),
    );

Widget _codeNote(String filename, String code) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
              color: const Color(0xFF1C2128),
              borderRadius: BorderRadius.circular(4)),
          child: Text(filename,
              style: const TextStyle(
                  color: Color(0xFF79C0FF),
                  fontSize: 10,
                  fontFamily: 'monospace')),
        ),
        const SizedBox(height: ZapSpacing.sm),
        Text(code,
            style: const TextStyle(
                color: Color(0xFFE6EDF3),
                fontSize: 11,
                fontFamily: 'monospace',
                height: 1.6)),
      ]),
    );
