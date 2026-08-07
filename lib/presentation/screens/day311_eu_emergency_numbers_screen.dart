/// Day 311 — EU Emergency Numbers Pack
///
/// Section G kickoff. Editor/viewer for EU country emergency numbers,
/// loaded from the bundled `assets/data/emergency_eu.json` asset (27 EU
/// member states + a universal "any member state" card). 112 is the
/// EU-wide mandated emergency number (Council Decision 91/396/EEC,
/// Directive 2002/22/EC) — it works free of charge, from any phone, in
/// every member state, and is always shown first. Country-specific
/// supplementary numbers are included only where they are well-documented
/// public facts (e.g. Germany 110 police, France 15/17/18); where no
/// supplementary number could be confirmed with confidence, the card
/// shows 112 only with an explicit "verify locally" note rather than a
/// fabricated number.
///
/// This screen follows the JSON shape already established by
/// `assets/data/emergency_numbers.json` (the Day 238 India/US/UK/etc.
/// reference file — read first as the format/tone reference; there is no
/// `day238_region_emergency_numbers_screen.dart` anywhere in this repo or
/// on `main`, despite the spec referencing one by that name, so this
/// screen is the first real viewer for that JSON shape). Tapping a number
/// dials it via `url_launcher` `tel:`.
///
/// Tag: 🟢 FRONTEND-ONLY
///
/// Route: AppRoutes.euEmergencyNumbers
library;

import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../widgets/zap_badge.dart';
import '../widgets/zap_card.dart';

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

  factory EmergencyCountry.fromJson(Map<String, dynamic> json) => EmergencyCountry(
        code: json['code'] as String,
        name: json['name'] as String,
        flag: json['flag'] as String,
        region: json['region'] as String,
        notes: json['notes'] as String,
        numbers: (json['numbers'] as List)
            .map((e) => EmergencyNumber.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

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

  factory EmergencyNumber.fromJson(Map<String, dynamic> json) => EmergencyNumber(
        label: json['label'] as String,
        number: json['number'] as String,
        primary: json['primary'] as bool,
        service: json['service'] as String,
      );
}

/// Loads and parses one of the `assets/data/emergency_*.json` region
/// packs (Days 311-313: EU, LATAM, SEA — same JSON shape as the Day 238
/// `emergency_numbers.json` reference file). Shared across all three
/// screens rather than duplicated three times. Exposed as a plain async
/// function (not a provider) — these are simple StatefulWidgets, matching
/// the complexity of a JSON-viewer screen rather than pulling in Riverpod
/// for a one-shot asset load.
Future<List<EmergencyCountry>> loadEmergencyNumbersAsset(BuildContext context, String assetPath) async {
  final raw = await DefaultAssetBundle.of(context).loadString(assetPath);
  final decoded = jsonDecode(raw) as Map<String, dynamic>;
  return (decoded['countries'] as List)
      .map((e) => EmergencyCountry.fromJson(e as Map<String, dynamic>))
      .toList();
}

class Day311EuEmergencyNumbersScreen extends StatefulWidget {
  const Day311EuEmergencyNumbersScreen({super.key});

  @override
  State<Day311EuEmergencyNumbersScreen> createState() => _Day311EuEmergencyNumbersScreenState();
}

class _Day311EuEmergencyNumbersScreenState extends State<Day311EuEmergencyNumbersScreen> {
  late Future<List<EmergencyCountry>> _future;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = loadEmergencyNumbersAsset(context, 'assets/data/emergency_eu.json');
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
      appBar: AppBar(title: Text('day311_320.eu_numbers_title'.tr())),
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
                  'Could not load assets/data/emergency_eu.json: ${snapshot.error}',
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
                        '112 works free of charge, from any phone, in all 27 EU member '
                        'states — the universal baseline mandated by EU Council Decision '
                        '91/396/EEC and Directive 2002/22/EC. Country-specific numbers '
                        'below are shown only where independently well-documented.',
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
