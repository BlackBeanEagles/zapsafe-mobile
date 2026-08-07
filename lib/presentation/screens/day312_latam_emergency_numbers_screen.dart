/// Day 312 — LATAM Emergency Numbers Pack
///
/// Editor/viewer for Latin American country emergency numbers, loaded
/// from the bundled `assets/data/emergency_latam.json` asset. Covers
/// Mexico, Brazil, Colombia, Argentina, Chile (the five the spec named)
/// plus five more countries with confidently-verified official numbers:
/// Peru, Ecuador, Uruguay, Costa Rica, Panama. Countries considered but
/// deliberately left out (e.g. Bolivia) had no number this screen's
/// author could confirm with confidence — omitted rather than guessed,
/// per the "never fabricate safety-critical numbers" rule.
///
/// Reuses [EmergencyCountry], [EmergencyNumber] and
/// [loadEmergencyNumbersAsset] from `day311_eu_emergency_numbers_screen.dart`
/// — same JSON shape, same viewer UI, just a different asset path and
/// heading. Not worth a hand-copied duplicate model class.
///
/// Tag: 🟢 FRONTEND-ONLY
///
/// Route: AppRoutes.latamEmergencyNumbers
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

class Day312LatamEmergencyNumbersScreen extends StatefulWidget {
  const Day312LatamEmergencyNumbersScreen({super.key});

  @override
  State<Day312LatamEmergencyNumbersScreen> createState() => _Day312LatamEmergencyNumbersScreenState();
}

class _Day312LatamEmergencyNumbersScreenState extends State<Day312LatamEmergencyNumbersScreen> {
  late Future<List<EmergencyCountry>> _future;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = loadEmergencyNumbersAsset(context, 'assets/data/emergency_latam.json');
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
      appBar: AppBar(title: Text('day311_320.latam_numbers_title'.tr())),
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
                  'Could not load assets/data/emergency_latam.json: ${snapshot.error}',
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
                backgroundColor: ZapColors.warning.withOpacity(0.08),
                borderColor: ZapColors.warning.withOpacity(0.3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.public_rounded, color: ZapColors.warning, size: 20),
                    const SizedBox(width: ZapSpacing.sm),
                    Expanded(
                      child: Text(
                        'Latin America has no single region-wide number like the EU\'s '
                        '112 — each country below uses its own. Only well-documented, '
                        'publicly known official numbers are shown; unconfirmed countries '
                        'were deliberately left out.',
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
                          ZapBadge(label: country.code, intent: ZapBadgeIntent.warning, size: ZapBadgeSize.small),
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
