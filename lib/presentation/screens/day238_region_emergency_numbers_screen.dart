/// Day 238 — Region Emergency Numbers
///
/// Section B (Days 221-240): country picker loaded from bundled
/// [assets/data/emergency_numbers.json]. Tap-to-call via `url_launcher` tel:.
///
/// Tag: 🟢 FRONTEND-ONLY · verify numbers locally before travel.
///
/// Route: [AppRoutes.regionEmergencyNumbers] → `/region-emergency-numbers`
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../navigation/app_router.dart';

const _kAssetPath = 'assets/data/emergency_numbers.json';
const _kJsonEncoder = JsonEncoder.withIndent('  ');

// ── Models ────────────────────────────────────────────────────────────────────
class EmergencyNumber {
  const EmergencyNumber({
    required this.label,
    required this.number,
    required this.primary,
    required this.service,
  });

  final String label;
  final String number;
  final bool primary;
  final String service;

  factory EmergencyNumber.fromJson(Map<String, dynamic> json) {
    return EmergencyNumber(
      label: json['label'] as String,
      number: json['number'] as String,
      primary: json['primary'] as bool? ?? false,
      service: json['service'] as String? ?? 'all',
    );
  }

  IconData get icon => switch (service) {
        'police' => Icons.local_police_rounded,
        'fire' => Icons.local_fire_department_rounded,
        'ambulance' => Icons.medical_services_rounded,
        'helpline' => Icons.support_agent_rounded,
        _ => Icons.emergency_rounded,
      };
}

class EmergencyCountry {
  const EmergencyCountry({
    required this.code,
    required this.name,
    required this.flag,
    required this.region,
    required this.notes,
    required this.numbers,
  });

  final String code;
  final String name;
  final String flag;
  final String region;
  final String notes;
  final List<EmergencyNumber> numbers;

  EmergencyNumber? get primaryNumber {
    for (final n in numbers) {
      if (n.primary) return n;
    }
    return numbers.isNotEmpty ? numbers.first : null;
  }

  factory EmergencyCountry.fromJson(Map<String, dynamic> json) {
    final raw = json['numbers'] as List<dynamic>? ?? [];
    return EmergencyCountry(
      code: json['code'] as String,
      name: json['name'] as String,
      flag: json['flag'] as String? ?? '🏳️',
      region: json['region'] as String? ?? 'Other',
      notes: json['notes'] as String? ?? '',
      numbers: raw
          .map((e) => EmergencyNumber.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class EmergencyNumbersBundle {
  const EmergencyNumbersBundle({
    required this.version,
    required this.updatedAt,
    required this.source,
    required this.countries,
  });

  final String version;
  final String updatedAt;
  final String source;
  final List<EmergencyCountry> countries;

  factory EmergencyNumbersBundle.fromJson(Map<String, dynamic> json) {
    final raw = json['countries'] as List<dynamic>? ?? [];
    return EmergencyNumbersBundle(
      version: json['version'] as String? ?? '1.0.0',
      updatedAt: json['updated_at'] as String? ?? '',
      source: json['source'] as String? ?? '',
      countries: raw
          .map((e) => EmergencyCountry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

Future<EmergencyNumbersBundle> _loadBundle() async {
  final raw = await rootBundle.loadString(_kAssetPath);
  return EmergencyNumbersBundle.fromJson(
    jsonDecode(raw) as Map<String, dynamic>,
  );
}

Future<void> dialEmergencyNumber(
  BuildContext context,
  String number,
) async {
  final digits = number.replaceAll(RegExp(r'[^\d+]'), '');
  final uri = Uri(scheme: 'tel', path: digits);
  try {
    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open dialer for $number')),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('tel:$digits (simulated on this platform)')),
      );
    }
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────
final _d238BundleProvider = FutureProvider<EmergencyNumbersBundle>((ref) async {
  return _loadBundle();
});

final _d238TabProvider = StateProvider<int>((ref) => 0);
final _d238SelectedCodeProvider = StateProvider<String>((ref) => 'IN');
final _d238SearchProvider = StateProvider<String>((ref) => '');
final _d238RegionProvider = StateProvider<String?>((ref) => null);
final _d238LastDialProvider = StateProvider<String?>((ref) => null);

const _kTabs = ['Regions', 'Dial', 'Source'];

List<EmergencyCountry> _filterCountries(
  EmergencyNumbersBundle bundle,
  String search,
  String? region,
) {
  var list = bundle.countries;
  if (region != null) {
    list = list.where((c) => c.region == region).toList();
  }
  if (search.trim().isEmpty) return list;
  final q = search.trim().toLowerCase();
  return list
      .where(
        (c) =>
            c.name.toLowerCase().contains(q) ||
            c.code.toLowerCase().contains(q) ||
            c.numbers.any((n) => n.number.contains(q)),
      )
      .toList();
}

EmergencyCountry? _countryByCode(
  EmergencyNumbersBundle bundle,
  String code,
) {
  for (final c in bundle.countries) {
    if (c.code == code) return c;
  }
  return bundle.countries.isNotEmpty ? bundle.countries.first : null;
}

// ── Screen ────────────────────────────────────────────────────────────────────
class Day238RegionEmergencyNumbersScreen extends ConsumerWidget {
  const Day238RegionEmergencyNumbersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_d238TabProvider);
    final bundleAsync = ref.watch(_d238BundleProvider);
    final selectedCode = ref.watch(_d238SelectedCodeProvider);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Day 238 · Emergency Numbers'),
        actions: [
          bundleAsync.maybeWhen(
            data: (bundle) {
              final country = _countryByCode(bundle, selectedCode);
              if (country == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(right: ZapSpacing.md),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: ZapColors.danger.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: ZapColors.danger.withOpacity(0.35),
                      ),
                    ),
                    child: Text(
                      '${country.flag} ${country.code}',
                      style: const TextStyle(
                        color: ZapColors.danger,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: bundleAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: ZapColors.info),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(ZapSpacing.lg),
            child: Text(
              'Failed to load $_kAssetPath\n$e',
              textAlign: TextAlign.center,
              style: const TextStyle(color: ZapColors.danger),
            ),
          ),
        ),
        data: (bundle) => Column(
          children: [
            _TabBar(
              tab: tab,
              onSelect: (i) => ref.read(_d238TabProvider.notifier).state = i,
            ),
            Expanded(
              child: switch (tab) {
                0 => _RegionsTab(bundle: bundle),
                1 => _DialTab(bundle: bundle),
                _ => _SourceTab(bundle: bundle),
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tab 0: Regions ────────────────────────────────────────────────────────────
class _RegionsTab extends ConsumerWidget {
  final EmergencyNumbersBundle bundle;

  const _RegionsTab({required this.bundle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final search = ref.watch(_d238SearchProvider);
    final region = ref.watch(_d238RegionProvider);
    final selected = ref.watch(_d238SelectedCodeProvider);
    final countries = _filterCountries(bundle, search, region);
    final regions = bundle.countries.map((c) => c.region).toSet().toList()
      ..sort();

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
          child: Text(
            '🟢 FRONTEND-ONLY · Section B Day 18/20 · '
            '${bundle.countries.length} regions · bundled JSON · tel: tap-to-call',
            style: const TextStyle(color: ZapColors.safe, fontSize: 11),
          ),
        ),
        const SizedBox(height: ZapSpacing.md),
        TextField(
          decoration: InputDecoration(
            hintText: 'Search country or number…',
            hintStyle: const TextStyle(
              color: ZapColors.textMuted,
              fontSize: 12,
            ),
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            filled: true,
            fillColor: ZapColors.bgCard,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: ZapColors.border),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
          style: const TextStyle(color: ZapColors.textPrimary, fontSize: 12),
          onChanged: (v) => ref.read(_d238SearchProvider.notifier).state = v,
        ),
        const SizedBox(height: ZapSpacing.sm),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            FilterChip(
              label: const Text('All regions', style: TextStyle(fontSize: 10)),
              selected: region == null,
              onSelected: (_) =>
                  ref.read(_d238RegionProvider.notifier).state = null,
            ),
            ...regions.map(
              (r) => FilterChip(
                label: Text(r, style: const TextStyle(fontSize: 10)),
                selected: region == r,
                onSelected: (_) =>
                    ref.read(_d238RegionProvider.notifier).state = r,
              ),
            ),
          ],
        ),
        const SizedBox(height: ZapSpacing.lg),
        ...countries.map(
          (c) => _CountryTile(
            country: c,
            selected: c.code == selected,
            onTap: () {
              ref.read(_d238SelectedCodeProvider.notifier).state = c.code;
              ref.read(_d238TabProvider.notifier).state = 1;
            },
          ),
        ),
        if (countries.isEmpty)
          const Padding(
            padding: EdgeInsets.all(ZapSpacing.xl),
            child: Center(
              child: Text(
                'No countries match your search.',
                style: TextStyle(color: ZapColors.textMuted),
              ),
            ),
          ),
      ],
    );
  }
}

class _CountryTile extends StatelessWidget {
  final EmergencyCountry country;
  final bool selected;
  final VoidCallback onTap;

  const _CountryTile({
    required this.country,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = country.primaryNumber;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected ? ZapColors.danger : ZapColors.border,
          width: selected ? 2 : 1,
        ),
      ),
      child: ListTile(
        dense: true,
        leading: Text(country.flag, style: const TextStyle(fontSize: 24)),
        title: Text(
          country.name,
          style: const TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
        subtitle: Text(
          primary == null
              ? country.region
              : '${country.region} · ${primary.number} ${primary.label}',
          style: const TextStyle(color: ZapColors.textMuted, fontSize: 10),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          country.code,
          style: TextStyle(
            color: selected ? ZapColors.danger : ZapColors.textSecondary,
            fontWeight: FontWeight.w800,
            fontSize: 11,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}

// ── Tab 1: Dial ─────────────────────────────────────────────────────────────
class _DialTab extends ConsumerWidget {
  final EmergencyNumbersBundle bundle;

  const _DialTab({required this.bundle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final code = ref.watch(_d238SelectedCodeProvider);
    final lastDial = ref.watch(_d238LastDialProvider);
    final country = _countryByCode(bundle, code);

    if (country == null) {
      return const Center(
        child: Text(
          'No country data',
          style: TextStyle(color: ZapColors.textMuted),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.lg),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                ZapColors.danger.withOpacity(0.18),
                ZapColors.bgCard,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ZapColors.danger.withOpacity(0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(country.flag, style: const TextStyle(fontSize: 32)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          country.name,
                          style: const TextStyle(
                            color: ZapColors.textPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '${country.code} · ${country.region}',
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
              if (country.notes.isNotEmpty) ...[
                const SizedBox(height: ZapSpacing.sm),
                Text(
                  country.notes,
                  style: const TextStyle(
                    color: ZapColors.textSecondary,
                    fontSize: 11,
                    height: 1.45,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        const Text(
          'Tap to open phone dialer',
          style: TextStyle(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        ...country.numbers.map(
          (n) => _NumberDialCard(
            number: n,
            onDial: () async {
              ref.read(_d238LastDialProvider.notifier).state =
                  '${country.code} · ${n.number}';
              await dialEmergencyNumber(context, n.number);
            },
          ),
        ),
        if (lastDial != null) ...[
          const SizedBox(height: ZapSpacing.md),
          Container(
            padding: const EdgeInsets.all(ZapSpacing.sm),
            decoration: BoxDecoration(
              color: ZapColors.bgCard,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: ZapColors.border),
            ),
            child: Text(
              'Last dial attempt: $lastDial',
              style: const TextStyle(
                color: ZapColors.textMuted,
                fontSize: 10,
              ),
            ),
          ),
        ],
        const SizedBox(height: ZapSpacing.lg),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              label: const Text('Change region'),
              onPressed: () => ref.read(_d238TabProvider.notifier).state = 0,
            ),
            ActionChip(
              label: const Text('Day 236 Hindi QA'),
              onPressed: () => context.push(AppRoutes.hindiUxQa),
            ),
            ActionChip(
              label: const Text('Day 239 India launch'),
              onPressed: () => context.push(AppRoutes.indiaLaunchReadiness),
            ),
          ],
        ),
        const SizedBox(height: ZapSpacing.md),
        Container(
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.warning.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.warning.withOpacity(0.3)),
          ),
          child: const Text(
            'ZapSafe SOS does not replace dialling local emergency services. '
            'Opens device dialer via tel: — user must confirm the call.',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 11),
          ),
        ),
      ],
    );
  }
}

class _NumberDialCard extends StatelessWidget {
  final EmergencyNumber number;
  final VoidCallback onDial;

  const _NumberDialCard({
    required this.number,
    required this.onDial,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: number.primary
              ? ZapColors.danger.withOpacity(0.45)
              : ZapColors.border,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: ZapColors.danger.withOpacity(0.12),
            child: Icon(number.icon, color: ZapColors.danger, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  number.number,
                  style: const TextStyle(
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
                Text(
                  number.label,
                  style: const TextStyle(
                    color: ZapColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (number.primary)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: ZapColors.danger.withOpacity(0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'PRIMARY',
                style: TextStyle(
                  color: ZapColors.danger,
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          FilledButton.icon(
            onPressed: onDial,
            icon: const Icon(Icons.phone_rounded, size: 18),
            label: const Text('Call'),
            style: FilledButton.styleFrom(
              backgroundColor: ZapColors.danger,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tab 2: Source ─────────────────────────────────────────────────────────────
class _SourceTab extends ConsumerWidget {
  final EmergencyNumbersBundle bundle;

  const _SourceTab({required this.bundle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final previewMap = bundle.countries.isNotEmpty
        ? {
            'code': bundle.countries.first.code,
            'name': bundle.countries.first.name,
            'numbers': bundle.countries.first.numbers
                .map(
                  (n) => {
                    'label': n.label,
                    'number': n.number,
                    'primary': n.primary,
                  },
                )
                .toList(),
          }
        : <String, dynamic>{};

    return ListView(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Bundled asset',
                style: TextStyle(
                  color: ZapColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              const _MetaRow(label: 'Path', value: _kAssetPath),
              _MetaRow(label: 'Version', value: bundle.version),
              _MetaRow(label: 'Updated', value: bundle.updatedAt),
              _MetaRow(
                label: 'Countries',
                value: '${bundle.countries.length}',
              ),
              const SizedBox(height: 6),
              Text(
                bundle.source,
                style: const TextStyle(
                  color: ZapColors.textMuted,
                  fontSize: 10,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.border),
          ),
          child: const SelectableText(
            '// Load at runtime\n'
            'final raw = await rootBundle.loadString(\n'
            '  \'assets/data/emergency_numbers.json\',\n'
            ');\n'
            'final bundle = EmergencyNumbersBundle.fromJson(\n'
            '  jsonDecode(raw),\n'
            ');\n\n'
            '// Tap-to-call\n'
            'await launchUrl(\n'
            '  Uri(scheme: \'tel\', path: \'112\'),\n'
            '  mode: LaunchMode.externalApplication,\n'
            ');',
            style: TextStyle(
              color: ZapColors.textSecondary,
              fontFamily: 'monospace',
              fontSize: 10,
              height: 1.45,
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(ZapSpacing.md),
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ZapColors.border),
          ),
          child: SelectableText(
            _kJsonEncoder.convert(previewMap),
            style: const TextStyle(
              color: ZapColors.textSecondary,
              fontFamily: 'monospace',
              fontSize: 10,
              height: 1.45,
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.lg),
        FilledButton.icon(
          onPressed: () async {
            final raw = await rootBundle.loadString(_kAssetPath);
            await Clipboard.setData(ClipboardData(text: raw));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied emergency_numbers.json')),
              );
            }
          },
          icon: const Icon(Icons.copy_rounded, size: 18),
          label: const Text('Copy full JSON'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            backgroundColor: ZapColors.info,
          ),
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
            'Tomorrow: Day 241 — Journey Mode v2 (Section C).',
            style: TextStyle(color: ZapColors.textSecondary, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _MetaRow extends StatelessWidget {
  final String label;
  final String value;

  const _MetaRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(color: ZapColors.textMuted, fontSize: 10),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: ZapColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
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
                        color: selected ? ZapColors.info : Colors.transparent,
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
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 10,
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
