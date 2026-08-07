/// Day 313 — SEA Emergency Numbers Pack
///
/// Editor/viewer for Southeast Asian country emergency numbers, loaded
/// from the bundled `assets/data/emergency_sea.json` asset. Covers the
/// six countries named in the spec: Singapore, Malaysia, Indonesia,
/// Philippines, Vietnam, Thailand — all well-documented official numbers.
///
/// Reuses [EmergencyCountry], [EmergencyNumber] and
/// [loadEmergencyNumbersAsset] from `day311_eu_emergency_numbers_screen.dart`
/// — same JSON shape, same viewer UI, just a different asset path and
/// heading.
///
/// Tag: 🟢 FRONTEND-ONLY
///
/// Route: AppRoutes.seaEmergencyNumbers
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../widgets/zap_badge.dart';
import '../widgets/zap_card.dart';
import 'day311_eu_emergency_numbers_screen.dart' show EmergencyCountry, loadEmergencyNumbersAsset;

class Day313SeaEmergencyNumbersScreen extends StatefulWidget {
  const Day313SeaEmergencyNumbersScreen({super.key});

  @override
  State<Day313SeaEmergencyNumbersScreen> createState() => _Day313SeaEmergencyNumbersScreenState();
}

class _Day313SeaEmergencyNumbersScreenState extends State<Day313SeaEmergencyNumbersScreen> {
  late Future<List<EmergencyCountry>> _future;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = loadEmergencyNumbersAsset(context, 'assets/data/emergency_sea.json');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _dial(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    final ok = await canLaunchUrl(uri);
    if (ok) {
      await launchUrl(uri);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cannot place calls on this device — dial $number manually')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('day311_320.sea_numbers_title'.tr())),
      body: FutureBuilder<List<EmergencyCountry>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(ZapSpacing.lg),
                child: Text(
                  'Could not load assets/data/emergency_sea.json: ${snapshot.error}',
                  style: ZapTypography.bodyMedium.copyWith(color: ZapColors.danger),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final countries = snapshot.data!
              .where((c) => _query.isEmpty || c.name.toLowerCase().contains(_query.toLowerCase()))
              .toList();

          return ListView(
            padding: const EdgeInsets.all(ZapSpacing.lg),
            children: [
              ZapCard(
                backgroundColor: ZapColors.info.withOpacity(0.08),
                borderColor: ZapColors.info.withOpacity(0.3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.public_rounded, color: ZapColors.info, size: 20),
                    const SizedBox(width: ZapSpacing.sm),
                    Expanded(
                      child: Text(
                        'Southeast Asia has no single region-wide number like the EU\'s '
                        '112 — each country below uses its own. Only the six countries '
                        'named in the Day 313 spec are covered.',
                        style: ZapTypography.bodySmall.copyWith(color: ZapColors.textPrimary, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: ZapSpacing.lg),
              TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v),
                style: ZapTypography.bodyMedium.copyWith(color: ZapColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'day311_320.search_country_hint'.tr(),
                  prefixIcon: const Icon(Icons.search_rounded, color: ZapColors.textSecondary),
                  filled: true,
                  fillColor: ZapColors.bgCard,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: ZapSpacing.lg),
              Text('${countries.length} day311_320.countries_shown'.tr(),
                  style: ZapTypography.labelMedium.copyWith(color: ZapColors.textSecondary)),
              const SizedBox(height: ZapSpacing.sm),
              for (final country in countries)
                ZapCard(
                  margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(country.flag, style: const TextStyle(fontSize: 22)),
                          const SizedBox(width: ZapSpacing.sm),
                          Expanded(
                            child: Text(country.name,
                                style: ZapTypography.bodyMedium
                                    .copyWith(color: ZapColors.textPrimary, fontWeight: FontWeight.w700)),
                          ),
                          ZapBadge(label: country.code, intent: ZapBadgeIntent.info, size: ZapBadgeSize.small),
                        ],
                      ),
                      const SizedBox(height: ZapSpacing.xs),
                      Text(country.notes,
                          style: ZapTypography.bodySmall.copyWith(color: ZapColors.textSecondary, height: 1.4)),
                      const SizedBox(height: ZapSpacing.md),
                      Wrap(
                        spacing: ZapSpacing.sm,
                        runSpacing: ZapSpacing.sm,
                        children: [
                          for (final n in country.numbers)
                            GestureDetector(
                              onTap: () => _dial(n.number),
                              onLongPress: () {
                                Clipboard.setData(ClipboardData(text: n.number));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Copied ${n.number}')),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: n.primary
                                      ? ZapColors.safe.withOpacity(0.12)
                                      : ZapColors.bgSurface,
                                  borderRadius: BorderRadius.circular(ZapSpacing.radiusPill),
                                  border: Border.all(
                                    color: n.primary
                                        ? ZapColors.safe.withOpacity(0.4)
                                        : ZapColors.border,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.call_rounded,
                                        size: 14,
                                        color: n.primary ? ZapColors.safe : ZapColors.textSecondary),
                                    const SizedBox(width: 6),
                                    Text('${n.label}: ${n.number}',
                                        style: ZapTypography.labelMedium.copyWith(
                                          color: n.primary ? ZapColors.safe : ZapColors.textPrimary,
                                          fontWeight: n.primary ? FontWeight.w700 : FontWeight.w500,
                                        )),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: ZapSpacing.huge),
            ],
          );
        },
      ),
    );
  }
}
