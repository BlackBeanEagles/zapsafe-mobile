/// Day 1 — Flutter Project Setup
///
/// Monday of Week 1. The very first day of ZapSafe frontend development.
///
/// What was done on Day 1:
///   • `flutter create zapsafe_mobile --org com.zapsafe`
///   • Full folder structure created (core / data / domain / presentation /
///     native / ml / assets)
///   • `pubspec.yaml` seeded with core packages:
///       flutter_riverpod, go_router, dio, hive_flutter, sqflite,
///       shared_preferences
///   • Git repository initialised and skeleton pushed.
///
/// This screen is a milestone card — it shows the scaffold choices made
/// on Day 1 so any new contributor can understand the starting point.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';

// ── Screen ────────────────────────────────────────────────────────────────────
class Day1ProjectSetupScreen extends StatelessWidget {
  const Day1ProjectSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F0F0F),
        foregroundColor: Colors.white,
        title: const Text('Day 1 · Project Setup'),
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: ZapSpacing.md, top: 8, bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: ZapColors.safe.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ZapColors.safe.withOpacity(0.4)),
            ),
            child: const Text('WEEK 1',
                style: TextStyle(
                    color: ZapColors.safe,
                    fontSize: 10,
                    fontWeight: FontWeight.w800)),
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
            const _SectionLabel('COMMAND RUN'),
            const SizedBox(height: ZapSpacing.md),
            const _CodeBlock(
              code: 'flutter create zapsafe_mobile --org com.zapsafe\n'
                  'cd zapsafe_mobile\n'
                  'git init\n'
                  'git add .\n'
                  'git commit -m "chore: initial Flutter scaffold"',
            ),
            const SizedBox(height: ZapSpacing.xl),
            const _SectionLabel('FOLDER STRUCTURE'),
            const SizedBox(height: ZapSpacing.md),
            const _FolderTree(),
            const SizedBox(height: ZapSpacing.xl),
            const _SectionLabel('CORE PACKAGES — pubspec.yaml'),
            const SizedBox(height: ZapSpacing.md),
            const _PackageList(),
            const SizedBox(height: ZapSpacing.xl),
            const _SectionLabel('DAY 1 CHECKLIST'),
            const SizedBox(height: ZapSpacing.md),
            const _Checklist(),
            const SizedBox(height: ZapSpacing.huge),
          ],
        ),
      ),
    );
  }
}

// ── Hero ─────────────────────────────────────────────────────────────────────
class _Hero extends StatelessWidget {
  const _Hero();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ZapColors.safe.withOpacity(0.12),
            ZapColors.info.withOpacity(0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ZapColors.safe.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: ZapColors.safe.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.rocket_launch_rounded,
                    color: ZapColors.safe, size: 26),
              ),
              const SizedBox(width: ZapSpacing.md),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Day 1 — Project Scaffold',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800)),
                    SizedBox(height: 2),
                    Text('Week 1 · Month 1 · Flutter Foundation',
                        style: TextStyle(
                            color: ZapColors.safe,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.lg),
          const Text(
            'The very first commit. Flutter project created with the ZapSafe '
            'org identifier, full folder structure established, and core '
            'packages added to pubspec.yaml. Git history starts here.',
            style: TextStyle(
                color: Color(0xFFB0B0C8), fontSize: 13, height: 1.6),
          ),
          const SizedBox(height: ZapSpacing.lg),
          Row(
            children: [
              _StatChip(label: 'Flutter', value: '3.19.6', color: ZapColors.info),
              const SizedBox(width: ZapSpacing.sm),
              _StatChip(label: 'Dart', value: '3.3.4', color: ZapColors.warning),
              const SizedBox(width: ZapSpacing.sm),
              _StatChip(label: 'Org', value: 'com.zapsafe', color: ZapColors.safe),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatChip({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label ', style: TextStyle(color: color.withOpacity(0.7), fontSize: 10)),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 10, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ── Code block ───────────────────────────────────────────────────────────────
class _CodeBlock extends StatelessWidget {
  final String code;
  const _CodeBlock({required this.code});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Clipboard.setData(ClipboardData(text: code));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Copied to clipboard'),
              duration: Duration(seconds: 1)),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(ZapSpacing.lg),
        decoration: BoxDecoration(
          color: const Color(0xFF0D0D16),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2A2A3A)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.terminal_rounded,
                    color: Color(0xFF6E6E82), size: 14),
                const SizedBox(width: 6),
                const Text('terminal',
                    style: TextStyle(color: Color(0xFF6E6E82), fontSize: 11)),
                const Spacer(),
                const Icon(Icons.copy_rounded,
                    color: Color(0xFF6E6E82), size: 14),
              ],
            ),
            const SizedBox(height: ZapSpacing.md),
            Text(code,
                style: const TextStyle(
                    color: Color(0xFF06D6A0),
                    fontSize: 12,
                    fontFamily: 'monospace',
                    height: 1.7)),
          ],
        ),
      ),
    );
  }
}

// ── Folder tree ───────────────────────────────────────────────────────────────
class _FolderTree extends StatelessWidget {
  const _FolderTree();

  static const _tree = [
    ('zapsafe_mobile/', true, 0),
    ('lib/', true, 1),
    ('core/', true, 2),
    ('theme/    ← colors, typography, spacing', false, 3),
    ('constants/ ← API URLs, enums', false, 3),
    ('utils/     ← formatters, validators', false, 3),
    ('data/', true, 2),
    ('models/    ← SOSEvent, Contact, AuthUser', false, 3),
    ('repositories/ ← API + local DB access', false, 3),
    ('services/  ← auth, GPS, push, SOS', false, 3),
    ('domain/', true, 2),
    ('providers/ ← Riverpod providers', false, 3),
    ('state/     ← state classes', false, 3),
    ('presentation/', true, 2),
    ('screens/   ← 200 day screens', false, 3),
    ('widgets/   ← ZapButton, ZapCard, etc.', false, 3),
    ('navigation/ ← GoRouter setup', false, 3),
    ('native/', true, 2),
    ('android/   ← Kotlin ForegroundService', false, 3),
    ('ios/       ← Swift BGProcessingTask', false, 3),
    ('ml/', true, 2),
    ('models/    ← .tflite files', false, 3),
    ('inference/ ← feature extraction', false, 3),
    ('assets/', true, 1),
    ('models/    ← TFLite model files', false, 2),
    ('fonts/     ← Clash Display, Syne', false, 2),
    ('icons/     ← app icon, SVGs', false, 2),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A3A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _tree.map((e) {
          final (name, isDir, indent) = e;
          return Padding(
            padding: EdgeInsets.only(
                left: indent * 16.0, bottom: 3),
            child: Row(
              children: [
                Icon(
                  isDir
                      ? Icons.folder_rounded
                      : Icons.insert_drive_file_rounded,
                  color: isDir
                      ? const Color(0xFFF59E0B)
                      : const Color(0xFF6E6E82),
                  size: 14,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    name,
                    style: TextStyle(
                      color: isDir
                          ? const Color(0xFFE0E0EE)
                          : const Color(0xFF9E9EB8),
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Package list ──────────────────────────────────────────────────────────────
class _PackageList extends StatelessWidget {
  const _PackageList();

  static const _packages = [
    ('flutter_riverpod', '^2.4.0', 'State management — all providers', Color(0xFF3B82F6)),
    ('go_router', '^12.0.0', 'Declarative navigation + route guards', Color(0xFF8B5CF6)),
    ('dio', '^5.3.0', 'HTTP client — better error handling than http', Color(0xFF10B981)),
    ('hive_flutter', '^1.1.0', 'Local persistent key-value storage', Color(0xFFF59E0B)),
    ('sqflite', '^2.3.0', 'Local SQLite for GPS traces + baseline', Color(0xFFEC4899)),
    ('shared_preferences', '^2.2.0', 'Simple key-value (non-sensitive only)', Color(0xFF6E6E82)),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _packages.map((p) {
        final (name, version, desc, color) = p;
        return Container(
          margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: const Color(0xFF0D0D16),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.extension_rounded, color: color, size: 18),
              ),
              const SizedBox(width: ZapSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(name,
                            style: TextStyle(
                                color: color,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'monospace')),
                        const SizedBox(width: 8),
                        Text(version,
                            style: const TextStyle(
                                color: Color(0xFF6E6E82),
                                fontSize: 11,
                                fontFamily: 'monospace')),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(desc,
                        style: const TextStyle(
                            color: Color(0xFF9E9EB8), fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── Checklist ─────────────────────────────────────────────────────────────────
class _Checklist extends StatelessWidget {
  const _Checklist();

  static const _items = [
    'flutter create zapsafe_mobile --org com.zapsafe',
    'Folder structure created (core/data/domain/presentation/native/ml/assets)',
    'pubspec.yaml — 6 core packages added',
    'Git repository initialised — first commit pushed',
    'Android emulator (Pixel 6 API 33) and iOS Simulator (iPhone 14) verified',
    'Backend repo cloned — API verified at http://localhost:8000',
    'README.md written with project context',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _items.map((item) {
        return Container(
          margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
          padding: const EdgeInsets.symmetric(
              horizontal: ZapSpacing.md, vertical: ZapSpacing.sm),
          decoration: BoxDecoration(
            color: ZapColors.safe.withOpacity(0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: ZapColors.safe.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: ZapColors.safe, size: 18),
              const SizedBox(width: ZapSpacing.md),
              Expanded(
                child: Text(item,
                    style: const TextStyle(
                        color: Color(0xFFD0D0E8), fontSize: 12)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            color: Color(0xFF6E6E82),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2));
  }
}
