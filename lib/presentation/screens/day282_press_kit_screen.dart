/// Day 282 — Press Kit Asset Gallery
///
/// Section E (Days 281-300): press kit gallery with logos, screenshots,
/// founder quote, and download ZIP mock for journalists and store listings.
///
/// Tag: 🟢 FRONTEND-ONLY · mock assets · no file I/O in demo.
///
/// Route: [AppRoutes.pressKit] → `/press-kit`
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../navigation/app_router.dart';

// ── Constants ─────────────────────────────────────────────────────────────────
const _kAccent = Color(0xFFF97316);
const _kTabs = ['Gallery', 'Download', 'Info'];
const _kJsonEncoder = JsonEncoder.withIndent('  ');

enum _AssetKind { logo, screenshot, icon }

class _PressAsset {
  const _PressAsset({
    required this.id,
    required this.label,
    required this.kind,
    required this.fileName,
    required this.sizeLabel,
    required this.previewColor,
    required this.icon,
  });

  final String id;
  final String label;
  final _AssetKind kind;
  final String fileName;
  final String sizeLabel;
  final Color previewColor;
  final IconData icon;
}

const _kFounderQuote =
    '"We built ZapSafe because every woman deserves a panic button that '
    'actually works — private, fast, and always in your pocket."';

const _kFounderName = 'Priya Sharma';
const _kFounderTitle = 'Co-founder & CEO · ZapSafe';

const _kAssets = [
  _PressAsset(
    id: 'logo_primary',
    label: 'Primary logo',
    kind: _AssetKind.logo,
    fileName: 'zapsafe-logo-primary.png',
    sizeLabel: '2400×800 · PNG',
    previewColor: ZapColors.danger,
    icon: Icons.shield_rounded,
  ),
  _PressAsset(
    id: 'logo_wordmark',
    label: 'Wordmark',
    kind: _AssetKind.logo,
    fileName: 'zapsafe-wordmark.svg',
    sizeLabel: 'Vector · SVG',
    previewColor: Color(0xFF0F172A),
    icon: Icons.text_fields_rounded,
  ),
  _PressAsset(
    id: 'logo_mono',
    label: 'Monochrome logo',
    kind: _AssetKind.logo,
    fileName: 'zapsafe-logo-mono.png',
    sizeLabel: '2400×800 · PNG',
    previewColor: ZapColors.neutral,
    icon: Icons.invert_colors_rounded,
  ),
  _PressAsset(
    id: 'app_icon',
    label: 'App icon',
    kind: _AssetKind.icon,
    fileName: 'zapsafe-app-icon-1024.png',
    sizeLabel: '1024×1024 · PNG',
    previewColor: ZapColors.danger,
    icon: Icons.apps_rounded,
  ),
  _PressAsset(
    id: 'ss_sos',
    label: 'SOS dashboard',
    kind: _AssetKind.screenshot,
    fileName: 'screenshot-sos-dashboard.png',
    sizeLabel: '1290×2796 · PNG',
    previewColor: Color(0xFFDC2626),
    icon: Icons.emergency_rounded,
  ),
  _PressAsset(
    id: 'ss_journey',
    label: 'Journey mode',
    kind: _AssetKind.screenshot,
    fileName: 'screenshot-journey-mode.png',
    sizeLabel: '1290×2796 · PNG',
    previewColor: Color(0xFF3B82F6),
    icon: Icons.map_rounded,
  ),
  _PressAsset(
    id: 'ss_vault',
    label: 'Evidence vault',
    kind: _AssetKind.screenshot,
    fileName: 'screenshot-evidence-vault.png',
    sizeLabel: '1290×2796 · PNG',
    previewColor: Color(0xFF6366F1),
    icon: Icons.folder_special_rounded,
  ),
  _PressAsset(
    id: 'ss_privacy',
    label: 'Privacy settings',
    kind: _AssetKind.screenshot,
    fileName: 'screenshot-privacy-settings.png',
    sizeLabel: '1290×2796 · PNG',
    previewColor: Color(0xFF10B981),
    icon: Icons.privacy_tip_rounded,
  ),
];

Map<String, dynamic> _pressKitPayload({
  required Set<String> selected,
  required bool zipDownloaded,
}) =>
    {
      'endpoint': 'GET /api/v1/marketing/press-kit/',
      'assets_total': _kAssets.length,
      'assets_selected': selected.length,
      'zip_filename': 'zapsafe-press-kit-2026.zip',
      'zip_downloaded': zipDownloaded,
      'includes': [
        'logos (PNG + SVG)',
        'app store screenshots',
        'founder-quote.txt',
        'brand-colors.json',
      ],
      'wire_note': 'Mock gallery · wire to CDN zip when marketing assets ship',
    };

// ── Providers ─────────────────────────────────────────────────────────────────
final _d282TabProvider = StateProvider<int>((ref) => 0);
final _d282SelectedProvider = StateProvider<Set<String>>(
  (ref) => _kAssets.map((a) => a.id).toSet(),
);
final _d282DownloadingProvider = StateProvider<bool>((ref) => false);
final _d282ZipDoneProvider = StateProvider<bool>((ref) => false);

// ── Screen ────────────────────────────────────────────────────────────────────
class Day282PressKitScreen extends ConsumerWidget {
  const Day282PressKitScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(_d282SelectedProvider);
    final zipDone = ref.watch(_d282ZipDoneProvider);
    final downloading = ref.watch(_d282DownloadingProvider);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 282 · Press Kit'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: ZapSpacing.md),
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _kAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: _kAccent.withOpacity(0.45)),
                ),
                child: Text(
                  downloading
                      ? 'ZIPPING…'
                      : zipDone
                          ? 'ZIP ✅'
                          : '${selected.length} ASSETS',
                  style: const TextStyle(
                    color: _kAccent,
                    fontSize: 10,
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
            tab: ref.watch(_d282TabProvider),
            onSelect: (i) => ref.read(_d282TabProvider.notifier).state = i,
          ),
          Expanded(
            child: switch (ref.watch(_d282TabProvider)) {
              0 => const _GalleryTab(),
              1 => const _DownloadTab(),
              _ => const _InfoTab(),
            },
          ),
        ],
      ),
    );
  }
}

// ── Tab 0: Gallery ────────────────────────────────────────────────────────────
class _GalleryTab extends ConsumerWidget {
  const _GalleryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(_d282SelectedProvider);
    final logos = _kAssets.where((a) => a.kind == _AssetKind.logo).toList();
    final icons = _kAssets.where((a) => a.kind == _AssetKind.icon).toList();
    final shots =
        _kAssets.where((a) => a.kind == _AssetKind.screenshot).toList();

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
            '🟢 FRONTEND-ONLY · Section E Day 2/20 · logos · screenshots · founder quote',
            style: TextStyle(color: _kAccent, fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.lg),
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kAccent.withOpacity(0.3)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.format_quote_rounded, color: _kAccent, size: 28),
              SizedBox(height: ZapSpacing.sm),
              Text(
                _kFounderQuote,
                style: TextStyle(
                  color: ZapColors.textPrimary,
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  height: 1.5,
                ),
              ),
              SizedBox(height: ZapSpacing.md),
              Text(
                _kFounderName,
                style: TextStyle(
                  color: ZapColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
              Text(
                _kFounderTitle,
                style: TextStyle(
                  color: ZapColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const _SectionTitle(title: 'Logos', subtitle: 'Tap to include in ZIP'),
        _AssetGrid(
          assets: logos,
          selected: selected,
          onToggle: (id) => _toggleAsset(ref, id),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const _SectionTitle(title: 'App icon', subtitle: 'Store listing asset'),
        _AssetGrid(
          assets: icons,
          selected: selected,
          onToggle: (id) => _toggleAsset(ref, id),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const _SectionTitle(
          title: 'Screenshots',
          subtitle: 'iPhone 15 Pro mock frames',
        ),
        _AssetGrid(
          assets: shots,
          selected: selected,
          onToggle: (id) => _toggleAsset(ref, id),
          crossAxisCount: 2,
          childAspectRatio: 0.72,
        ),
      ],
    );
  }

  void _toggleAsset(WidgetRef ref, String id) {
    ref.read(_d282ZipDoneProvider.notifier).state = false;
    ref.read(_d282SelectedProvider.notifier).update((s) {
      final next = {...s};
      if (next.contains(id)) {
        next.remove(id);
      } else {
        next.add(id);
      }
      return next;
    });
  }
}

class _AssetGrid extends StatelessWidget {
  const _AssetGrid({
    required this.assets,
    required this.selected,
    required this.onToggle,
    this.crossAxisCount = 3,
    this.childAspectRatio = 0.95,
  });

  final List<_PressAsset> assets;
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  final int crossAxisCount;
  final double childAspectRatio;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: assets.length,
      itemBuilder: (context, i) {
        final asset = assets[i];
        final isOn = selected.contains(asset.id);
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => onToggle(asset.id),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isOn
                    ? asset.previewColor.withOpacity(0.12)
                    : ZapColors.bgCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isOn
                      ? asset.previewColor.withOpacity(0.5)
                      : ZapColors.border,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: crossAxisCount == 2 ? 48 : 36,
                    height: crossAxisCount == 2 ? 48 : 36,
                    decoration: BoxDecoration(
                      color: asset.previewColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      asset.icon,
                      color: asset.previewColor,
                      size: crossAxisCount == 2 ? 24 : 20,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    asset.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isOn
                          ? ZapColors.textPrimary
                          : ZapColors.textMuted,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    asset.sizeLabel,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: ZapColors.textMuted,
                      fontSize: 8,
                    ),
                  ),
                  Icon(
                    isOn
                        ? Icons.check_box_rounded
                        : Icons.check_box_outline_blank_rounded,
                    size: 14,
                    color: isOn ? ZapColors.safe : ZapColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Tab 1: Download ───────────────────────────────────────────────────────────
class _DownloadTab extends ConsumerWidget {
  const _DownloadTab();

  Future<void> _downloadZip(WidgetRef ref, BuildContext context) async {
    final selected = ref.read(_d282SelectedProvider);
    if (selected.isEmpty) return;

    ref.read(_d282DownloadingProvider.notifier).state = true;
    ref.read(_d282ZipDoneProvider.notifier).state = false;
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    ref.read(_d282DownloadingProvider.notifier).state = false;
    ref.read(_d282ZipDoneProvider.notifier).state = true;

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Press kit ZIP ready (${selected.length} assets · mock).',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(_d282SelectedProvider);
    final downloading = ref.watch(_d282DownloadingProvider);
    final zipDone = ref.watch(_d282ZipDoneProvider);

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const _SectionTitle(
          title: 'Press kit bundle',
          subtitle: 'zapsafe-press-kit-2026.zip · mock download',
        ),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.lg),
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ZapColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _kAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.folder_zip_rounded,
                      color: _kAccent,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: ZapSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'zapsafe-press-kit-2026.zip',
                          style: TextStyle(
                            color: ZapColors.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '${selected.length} files · ~${(selected.length * 1.2).toStringAsFixed(1)} MB (mock)',
                          style: const TextStyle(
                            color: ZapColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: ZapSpacing.md),
              const Text(
                'Includes',
                style: TextStyle(
                  color: ZapColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 6),
              for (final item in const [
                'founder-quote.txt',
                'brand-colors.json',
                'README-press.txt',
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.insert_drive_file_outlined,
                          size: 14, color: ZapColors.textMuted),
                      const SizedBox(width: 6),
                      Text(
                        item,
                        style: const TextStyle(
                          color: ZapColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 6),
              ...selected.map((id) {
                final asset = _kAssets.firstWhere((a) => a.id == id);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(asset.icon, size: 14, color: asset.previewColor),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          asset.fileName,
                          style: const TextStyle(
                            color: ZapColors.textSecondary,
                            fontSize: 11,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () =>
                    ref.read(_d282SelectedProvider.notifier).state =
                        _kAssets.map((a) => a.id).toSet(),
                child: const Text('Select all'),
              ),
            ),
            const SizedBox(width: ZapSpacing.sm),
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  ref.read(_d282SelectedProvider.notifier).state = {};
                  ref.read(_d282ZipDoneProvider.notifier).state = false;
                },
                child: const Text('Clear'),
              ),
            ),
          ],
        ),
        const SizedBox(height: ZapSpacing.md),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: selected.isEmpty || downloading
                ? null
                : () => _downloadZip(ref, context),
            icon: downloading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    zipDone
                        ? Icons.check_rounded
                        : Icons.download_rounded,
                    size: 16,
                  ),
            label: Text(
              selected.isEmpty
                  ? 'Select assets first'
                  : downloading
                      ? 'Building ZIP…'
                      : zipDone
                          ? 'Download again'
                          : 'Download press kit ZIP',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: _kAccent,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        if (zipDone) ...[
          const SizedBox(height: ZapSpacing.md),
          OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(
                const ClipboardData(text: _kFounderQuote),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Founder quote copied.')),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copy founder quote'),
          ),
        ],
      ],
    );
  }
}

// ── Tab 2: Info ───────────────────────────────────────────────────────────────
class _InfoTab extends ConsumerWidget {
  const _InfoTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(_d282SelectedProvider);
    final zipDone = ref.watch(_d282ZipDoneProvider);
    final payload = _pressKitPayload(
      selected: selected,
      zipDownloaded: zipDone,
    );

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        const _PolicyRow(
          icon: Icons.collections_rounded,
          title: 'Press kit asset gallery',
          subtitle:
              'Logos, app icon, store screenshots, and founder quote — '
              'select assets and mock-download a ZIP for journalists.',
        ),
        const _PolicyRow(
          icon: Icons.folder_zip_rounded,
          title: 'ZIP bundle mock',
          subtitle:
              'Includes brand metadata files · wire to CDN or S3 when '
              'marketing assets are finalized.',
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
            borderRadius: BorderRadius.circular(8),
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
              const SnackBar(content: Text('Press kit spec copied.')),
            );
          },
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copy press kit spec'),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.info.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
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
              label: const Text('Day 281 Landing Preview'),
              onPressed: () => context.push(AppRoutes.landingPreview),
            ),
            ActionChip(
              label: const Text('Day 280 Section D Milestone'),
              onPressed: () => context.push(AppRoutes.sectionDMilestone),
            ),
            ActionChip(
              label: const Text('Day 257 Score Widget'),
              onPressed: () => context.push(AppRoutes.homeWidgetScore),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          Text(
            subtitle,
            style: const TextStyle(
              color: ZapColors.textMuted,
              fontSize: 11,
            ),
          ),
        ],
      ),
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
                padding: const EdgeInsets.symmetric(vertical: 12),
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
                    fontWeight:
                        selected ? FontWeight.w800 : FontWeight.w500,
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
