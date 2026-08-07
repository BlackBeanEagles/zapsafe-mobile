import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/spacing.dart';

// ── Provider ───────────────────────────────────────────────────────────────────
final _flavorProvider = StateProvider<_AppFlavor>((ref) => _AppFlavor.prod);

enum _AppFlavor { prod, beta }

// ── Screen ─────────────────────────────────────────────────────────────────────
class Day111BetaFlavorScreen extends ConsumerWidget {
  const Day111BetaFlavorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flavor = ref.watch(_flavorProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Day 111 · Beta Flavor'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Hero(),
            const SizedBox(height: ZapSpacing.xl),
            _FlavorToggle(current: flavor),
            const SizedBox(height: ZapSpacing.xl),
            _LivePreview(flavor: flavor),
            const SizedBox(height: ZapSpacing.xl),
            const _SectionLabel('ANDROID · android/app/build.gradle'),
            const SizedBox(height: ZapSpacing.md),
            const _BuildGradleCard(),
            const SizedBox(height: ZapSpacing.xl),
            const _SectionLabel('FLUTTER · lib/core/config/flavor_config.dart'),
            const SizedBox(height: ZapSpacing.md),
            const _FlavorConfigCard(),
            const SizedBox(height: ZapSpacing.xl),
            const _SectionLabel('SETUP CHECKLIST'),
            const SizedBox(height: ZapSpacing.md),
            const _SetupChecklist(),
            const SizedBox(height: ZapSpacing.xl),
            const _SectionLabel('BUILD COMMANDS'),
            const SizedBox(height: ZapSpacing.md),
            const _BuildCommands(),
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
          colors: [Color(0xFF022020), Color(0xFF041A1A), Color(0xFF0A0A0A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF06B6D4).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.science_rounded,
                  color: Color(0xFF06B6D4),
                  size: 22,
                ),
              ),
              const SizedBox(width: ZapSpacing.md),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DAY 111  ·  MONTH 5: BETA',
                    style: TextStyle(
                      color: Color(0xFF06B6D4),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                  Text(
                    'Beta Flavor Setup',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.md),
          const Text(
            'Android productFlavors · separate applicationId (com.zapsafe.app.beta) · '
            'beta app icon overlay · FlavorConfig Dart class · main_beta.dart entry point · '
            'BetaEnvironmentBanner widget · feedback FAB gated on isBeta.',
            style: TextStyle(
              color: Color(0xFFD1D5DB),
              fontSize: 12,
              height: 1.6,
            ),
          ),
          const SizedBox(height: ZapSpacing.md),
          const Row(
            children: [
              _HeroStat('2',  'Flavors',        Color(0xFF06B6D4)),
              _HeroStat('3',  'Files changed',  Color(0xFF10B981)),
              _HeroStat('2',  'Entry points',   Color(0xFFF59E0B)),
              _HeroStat('β',  'Build suffix',   Color(0xFFF97316)),
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
              fontSize: 22,
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

// ── Flavor toggle ──────────────────────────────────────────────────────────────
class _FlavorToggle extends ConsumerWidget {
  final _AppFlavor current;
  const _FlavorToggle({required this.current});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('FLAVOR SIMULATOR'),
        const SizedBox(height: ZapSpacing.md),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
            border: Border.all(color: const Color(0xFF2A2A2A)),
          ),
          child: Row(
            children: _AppFlavor.values.map((f) {
              final isSelected = current == f;
              final accent = f == _AppFlavor.beta
                  ? const Color(0xFFF97316)
                  : const Color(0xFF3B82F6);
              final label  = f == _AppFlavor.beta ? '⚡  Beta' : '🏁  Prod';
              final sub    = f == _AppFlavor.beta
                  ? 'com.zapsafe.app.beta'
                  : 'com.zapsafe.app';
              return Expanded(
                child: GestureDetector(
                  onTap: () => ref.read(_flavorProvider.notifier).state = f,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? accent.withOpacity(0.15)
                          : Colors.transparent,
                      borderRadius:
                          BorderRadius.circular(ZapSpacing.radiusSmall),
                      border: isSelected
                          ? Border.all(color: accent.withOpacity(0.6))
                          : null,
                    ),
                    child: Column(
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            color: isSelected ? accent : Colors.white54,
                            fontSize: 14,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          sub,
                          style: TextStyle(
                            color: isSelected
                                ? accent.withOpacity(0.7)
                                : Colors.white24,
                            fontSize: 10,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ── Live preview ───────────────────────────────────────────────────────────────
class _LivePreview extends StatelessWidget {
  final _AppFlavor flavor;
  const _LivePreview({required this.flavor});

  @override
  Widget build(BuildContext context) {
    final isBeta = flavor == _AppFlavor.beta;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('LIVE PREVIEW · MOCK APP SCREEN'),
        const SizedBox(height: ZapSpacing.md),
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
            border: Border.all(
              color: isBeta
                  ? const Color(0xFFF97316).withOpacity(0.5)
                  : const Color(0xFF2A2A2A),
              width: isBeta ? 1.5 : 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(ZapSpacing.radius - 1),
            child: Column(
              children: [
                // Beta environment banner (only in beta)
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  child: isBeta
                      ? Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              vertical: 6, horizontal: ZapSpacing.md),
                          color: const Color(0xFFF97316).withOpacity(0.85),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.science_rounded,
                                  color: Colors.white, size: 12),
                              SizedBox(width: 6),
                              Text(
                                '⚡  BETA BUILD  ·  Build 111  ·  Feedback enabled',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                // Mock app bar
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: ZapSpacing.md, vertical: 12),
                  color: const Color(0xFF0F0F0F),
                  child: Row(
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: Text(
                          isBeta ? 'ZapSafe  BETA' : 'ZapSafe',
                          key: ValueKey(isBeta),
                          style: TextStyle(
                            color: isBeta
                                ? const Color(0xFFF97316)
                                : Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (isBeta)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF97316).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: const Color(0xFFF97316).withOpacity(0.5),
                            ),
                          ),
                          child: const Text(
                            'BETA',
                            style: TextStyle(
                              color: Color(0xFFF97316),
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'PROD',
                            style: TextStyle(
                              color: Color(0xFF10B981),
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Mock content area
                Padding(
                  padding: const EdgeInsets.all(ZapSpacing.md),
                  child: Column(
                    children: [
                      // Status card
                      Container(
                        padding: const EdgeInsets.all(ZapSpacing.md),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A),
                          borderRadius:
                              BorderRadius.circular(ZapSpacing.radiusSmall),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.shield_rounded,
                                  color: Color(0xFF10B981), size: 18),
                            ),
                            const SizedBox(width: ZapSpacing.md),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'ZapSafe Active',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  isBeta
                                      ? 'applicationId: com.zapsafe.app.beta'
                                      : 'applicationId: com.zapsafe.app',
                                  style: const TextStyle(
                                    color: Color(0xFF9CA3AF),
                                    fontSize: 10,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: ZapSpacing.sm),
                      // Feedback FAB (beta only)
                      if (isBeta) ...[
                        Container(
                          padding: const EdgeInsets.all(ZapSpacing.sm),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF97316).withOpacity(0.12),
                            borderRadius:
                                BorderRadius.circular(ZapSpacing.radiusSmall),
                            border: Border.all(
                              color: const Color(0xFFF97316).withOpacity(0.3),
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.feedback_rounded,
                                  color: Color(0xFFF97316), size: 16),
                              SizedBox(width: ZapSpacing.sm),
                              Text(
                                'Feedback FAB  ·  only visible in beta builds',
                                style: TextStyle(
                                  color: Color(0xFFF97316),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(ZapSpacing.sm),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A1A),
                            borderRadius:
                                BorderRadius.circular(ZapSpacing.radiusSmall),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.feedback_outlined,
                                  color: Color(0xFF4B5563), size: 16),
                              SizedBox(width: ZapSpacing.sm),
                              Text(
                                'Feedback FAB  ·  hidden in prod builds',
                                style: TextStyle(
                                  color: Color(0xFF4B5563),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
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

// ── build.gradle code card ─────────────────────────────────────────────────────
class _BuildGradleCard extends StatelessWidget {
  const _BuildGradleCard();

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // File path chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF1C2128),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'android/app/build.gradle',
              style: TextStyle(
                color: Color(0xFF79C0FF),
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(height: ZapSpacing.md),
          const Text(
            '    flavorDimensions "env"\n'
            '\n'
            '    productFlavors {\n'
            '        prod {\n'
            '            dimension "env"\n'
            '            applicationId "com.zapsafe.app"\n'
            '            resValue "string", "app_name", "ZapSafe"\n'
            '        }\n'
            '        beta {\n'
            '            dimension "env"\n'
            '            applicationId "com.zapsafe.app.beta"\n'
            '            resValue "string", "app_name", "ZapSafe BETA"\n'
            '            versionNameSuffix "-beta"\n'
            '            buildConfigField "boolean",\n'
            '                "IS_BETA", "true"\n'
            '        }\n'
            '    }',
            style: TextStyle(
              color: Color(0xFFE6EDF3),
              fontSize: 12,
              fontFamily: 'monospace',
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ── FlavorConfig Dart code card ────────────────────────────────────────────────
class _FlavorConfigCard extends StatelessWidget {
  const _FlavorConfigCard();

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
          Row(
            children: [
              _FileChip('lib/core/config/flavor_config.dart',
                  Color(0xFF79C0FF)),
              SizedBox(width: ZapSpacing.sm),
              _FileChip('lib/main_beta.dart', Color(0xFFF97316)),
            ],
          ),
          SizedBox(height: ZapSpacing.md),
          Text(
            '// flavor_config.dart\n'
            'enum AppFlavor { prod, beta }\n'
            '\n'
            'class FlavorConfig {\n'
            '  FlavorConfig._();\n'
            '  static late AppFlavor _flavor;\n'
            '\n'
            '  static void init(AppFlavor f) => _flavor = f;\n'
            '  static bool get isBeta => _flavor == AppFlavor.beta;\n'
            '  static String get appId => isBeta\n'
            '      ? "com.zapsafe.app.beta"\n'
            '      : "com.zapsafe.app";\n'
            '}\n'
            '\n'
            '// main_beta.dart\n'
            'void main() {\n'
            '  FlavorConfig.init(AppFlavor.beta);\n'
            '  runApp(const ProviderScope(child: ZapSafeApp()));\n'
            '}',
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

class _FileChip extends StatelessWidget {
  final String path;
  final Color color;
  const _FileChip(this.path, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF1C2128),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        path,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}

// ── Setup checklist ────────────────────────────────────────────────────────────
const _kChecks = <(String, String, bool, Color)>[
  // (platform, task, done, accent)
  ('ANDROID', 'flavorDimensions "env" in build.gradle',          true,  Color(0xFF10B981)),
  ('ANDROID', 'productFlavors: prod + beta blocks',              true,  Color(0xFF10B981)),
  ('ANDROID', 'beta applicationId: com.zapsafe.app.beta',        true,  Color(0xFF10B981)),
  ('ANDROID', 'Beta icon assets in src/beta/res/mipmap-*/',      true,  Color(0xFF10B981)),
  ('FLUTTER', 'FlavorConfig class (lib/core/config/)',           true,  Color(0xFF06B6D4)),
  ('FLUTTER', 'main_beta.dart entry point',                      true,  Color(0xFF06B6D4)),
  ('FLUTTER', 'BetaEnvironmentBanner widget',                    true,  Color(0xFF06B6D4)),
  ('FLUTTER', 'Feedback FAB gated on FlavorConfig.isBeta',       true,  Color(0xFF06B6D4)),
  ('iOS',     'Xcode scheme: ZapSafe Beta',                      false, Color(0xFF8B5CF6)),
  ('iOS',     'Info.plist FLAVOR = beta',                        false, Color(0xFF8B5CF6)),
  ('iOS',     'AppIconBeta asset catalog',                       false, Color(0xFF8B5CF6)),
];

class _SetupChecklist extends StatelessWidget {
  const _SetupChecklist();

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
          final (platform, task, done, accent) = _kChecks[i];
          final isLast = i == _kChecks.length - 1;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: ZapSpacing.md, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        platform,
                        style: TextStyle(
                          color: accent,
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: ZapSpacing.sm),
                    Expanded(
                      child: Text(
                        task,
                        style: TextStyle(
                          color: done ? Colors.white : Colors.white54,
                          fontSize: 12,
                          decoration:
                              done ? null : TextDecoration.none,
                        ),
                      ),
                    ),
                    const SizedBox(width: ZapSpacing.sm),
                    Icon(
                      done
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: done
                          ? const Color(0xFF10B981)
                          : Colors.white24,
                      size: 18,
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

// ── Build commands ─────────────────────────────────────────────────────────────
const _kCommands = <(String, String, Color)>[
  ('Debug prod',       'flutter run --flavor prod -t lib/main.dart',              Color(0xFF3B82F6)),
  ('Debug beta',       'flutter run --flavor beta -t lib/main_beta.dart',         Color(0xFFF97316)),
  ('Release prod APK', 'flutter build apk --flavor prod --release\n'
                       '    -t lib/main.dart',                                     Color(0xFF10B981)),
  ('Release beta APK', 'flutter build apk --flavor beta --release\n'
                       '    -t lib/main_beta.dart',                               Color(0xFFF97316)),
];

class _BuildCommands extends StatelessWidget {
  const _BuildCommands();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _kCommands.map((entry) {
        final (label, cmd, accent) = entry;
        return Padding(
          padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1117),
              borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
              border: Border.all(color: accent.withOpacity(0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  cmd,
                  style: const TextStyle(
                    color: Color(0xFFE6EDF3),
                    fontSize: 12,
                    fontFamily: 'monospace',
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
