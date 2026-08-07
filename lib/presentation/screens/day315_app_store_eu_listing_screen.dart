/// Day 315 — App Store EU Localization Pack
///
/// Same generator pattern as Day 314, but for Apple App Store Connect's
/// real, documented field limits:
///   • App name          — 30 characters
///   • Subtitle           — 30 characters
///   • Keywords           — 100 characters (comma-separated, no spaces —
///                            Apple strips them, so spaces waste budget)
///   • Promotional text   — 170 characters (can change without review)
///   • Description        — 4000 characters
///
/// Plus a screenshot size guide for the three device classes the spec
/// named — 6.7", 6.5", and iPad — with the real current required pixel
/// dimensions per Apple's App Store Connect screenshot specifications.
/// Apple has occasionally added further size classes (e.g. a 6.9" tier
/// for the newest Pro Max models) since this was last verified — the
/// screen notes to double-check the live App Store Connect Help page
/// before a real submission rather than treating this as eternally fixed.
///
/// Tag: 🟢 FRONTEND-ONLY
///
/// Route: AppRoutes.appStoreEuListing
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../widgets/zap_badge.dart';
import '../widgets/zap_card.dart';

class _AppleListingCopy {
  const _AppleListingCopy({
    required this.name,
    required this.subtitle,
    required this.keywords,
    required this.promoText,
    required this.description,
  });
  final String name;
  final String subtitle;
  final String keywords;
  final String promoText;
  final String description;
}

const _kNameLimit = 30;
const _kSubtitleLimit = 30;
const _kKeywordsLimit = 100;
const _kPromoLimit = 170;
const _kDescLimit = 4000;

const _kLocales = ['en', 'de', 'fr', 'es'];
const _kLocaleNames = {
  'en': 'English',
  'de': 'Deutsch (German)',
  'fr': 'Français (French)',
  'es': 'Español (Spanish)',
};

const _kDraftCopy = {
  'en': _AppleListingCopy(
    name: 'ZapSafe: Safety & SOS',
    subtitle: 'AI SOS & Live Location',
    keywords: 'safety,sos,emergency,panic,alarm,location share,women safety,alert,contacts,evidence',
    promoText: 'AI-powered SOS with live location sharing, silent evidence capture, and 27 built-in safety defenses.',
    description:
        'ZapSafe is a personal-safety app built around one idea: help should arrive '
        'before you even finish saying you need it.\n\n'
        'Trigger an SOS by voice, motion, or a single tap. ZapSafe shares your live '
        'location with trusted contacts, escalates automatically if you don\'t '
        'respond, and can silently record encrypted audio/video evidence on your '
        'device.\n\n'
        'ZapSafe ships with 27 built-in "loophole defenses" — from duress PINs to '
        'Lock Screen Suppression, which keeps the SOS screen from being seen or '
        'dismissed by someone else holding your phone during an active alert.\n\n'
        'Privacy-by-design throughout: granular, withdrawable consent for every '
        'optional data use, on-device evidence storage by default.',
  ),
  'de': _AppleListingCopy(
    name: 'ZapSafe: Sicherheit & SOS',
    subtitle: 'KI-SOS & Live-Standort',
    keywords: 'sicherheit,sos,notfall,alarm,standort teilen,frauensicherheit,alarmierung,kontakte,beweise',
    promoText: 'KI-gestützter SOS-Alarm mit Live-Standort, stiller Beweissicherung und 27 Sicherheitsfunktionen.',
    description:
        'ZapSafe ist eine App für persönliche Sicherheit: Hilfe soll ankommen, '
        'bevor Sie überhaupt fertig gesprochen haben.\n\n'
        'Lösen Sie einen SOS-Alarm per Stimme, Bewegung oder Fingertipp aus. ZapSafe '
        'teilt Ihren Live-Standort mit Vertrauenspersonen und eskaliert automatisch '
        'bei ausbleibender Reaktion.\n\n'
        'Mit 27 integrierten "Loophole-Verteidigungen", darunter die '
        'Bildschirmsperr-Unterdrückung für den SOS-Bildschirm.\n\n'
        'Privacy-by-Design: granulare, widerrufbare Einwilligungen für jede '
        'optionale Datennutzung.',
  ),
  'fr': _AppleListingCopy(
    name: 'ZapSafe : Sécurité & SOS',
    subtitle: 'SOS IA & position en direct',
    keywords: 'securite,sos,urgence,alarme,partage position,securite femmes,alerte,contacts,preuves',
    promoText: 'Alerte SOS par IA avec position en direct, preuves silencieuses et 27 défenses de sécurité.',
    description:
        'ZapSafe est une application de sécurité personnelle : l\'aide devrait '
        'arriver avant même que vous ayez fini de dire que vous en avez besoin.\n\n'
        'Déclenchez une alerte SOS par la voix, le mouvement ou un appui. ZapSafe '
        'partage votre position en direct avec vos contacts de confiance et '
        'escalade automatiquement en l\'absence de réponse.\n\n'
        'Avec 27 "défenses contre les failles" intégrées, dont la suppression de '
        'l\'écran de verrouillage pour l\'écran SOS.\n\n'
        'Confidentialité dès la conception : consentement granulaire et révocable '
        'pour chaque usage optionnel des données.',
  ),
  'es': _AppleListingCopy(
    name: 'ZapSafe: Seguridad y SOS',
    subtitle: 'SOS con IA y ubicación',
    keywords: 'seguridad,sos,emergencia,alarma,compartir ubicacion,seguridad mujer,alerta,contactos,evidencia',
    promoText: 'Alerta SOS con IA, ubicación en vivo, evidencia silenciosa y 27 defensas de seguridad integradas.',
    description:
        'ZapSafe es una aplicación de seguridad personal: la ayuda debería llegar '
        'antes de que termines de decir que la necesitas.\n\n'
        'Activa una alerta SOS por voz, movimiento o un toque. ZapSafe comparte tu '
        'ubicación en vivo con tus contactos de confianza y escala automáticamente '
        'si no respondes.\n\n'
        'Incluye 27 "defensas contra brechas" integradas, entre ellas la supresión '
        'de la pantalla de bloqueo para la pantalla de SOS.\n\n'
        'Privacidad desde el diseño: consentimiento granular y revocable para cada '
        'uso opcional de datos.',
  ),
};

class _ScreenshotSize {
  const _ScreenshotSize({required this.label, required this.devices, required this.pixels});
  final String label;
  final String devices;
  final String pixels;
}

const _kScreenshotSizes = [
  _ScreenshotSize(
    label: '6.7" display',
    devices: 'iPhone 15 Pro Max, 14 Pro Max, 13 Pro Max',
    pixels: '1290 × 2796 px (portrait)',
  ),
  _ScreenshotSize(
    label: '6.5" display',
    devices: 'iPhone 11 Pro Max, XS Max',
    pixels: '1242 × 2688 px (portrait)',
  ),
  _ScreenshotSize(
    label: 'iPad Pro 12.9" (3rd gen or later)',
    devices: 'iPad Pro 12.9-inch',
    pixels: '2048 × 2732 px (portrait)',
  ),
];

class Day315AppStoreEuListingScreen extends StatefulWidget {
  const Day315AppStoreEuListingScreen({super.key});

  @override
  State<Day315AppStoreEuListingScreen> createState() => _Day315AppStoreEuListingScreenState();
}

class _Day315AppStoreEuListingScreenState extends State<Day315AppStoreEuListingScreen> {
  String _locale = 'en';
  late final Map<String, TextEditingController> _nameCtrl;
  late final Map<String, TextEditingController> _subtitleCtrl;
  late final Map<String, TextEditingController> _keywordsCtrl;
  late final Map<String, TextEditingController> _promoCtrl;
  late final Map<String, TextEditingController> _descCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = {for (final l in _kLocales) l: TextEditingController(text: _kDraftCopy[l]!.name)};
    _subtitleCtrl = {for (final l in _kLocales) l: TextEditingController(text: _kDraftCopy[l]!.subtitle)};
    _keywordsCtrl = {for (final l in _kLocales) l: TextEditingController(text: _kDraftCopy[l]!.keywords)};
    _promoCtrl = {for (final l in _kLocales) l: TextEditingController(text: _kDraftCopy[l]!.promoText)};
    _descCtrl = {for (final l in _kLocales) l: TextEditingController(text: _kDraftCopy[l]!.description)};
  }

  @override
  void dispose() {
    for (final c in _nameCtrl.values) {
      c.dispose();
    }
    for (final c in _subtitleCtrl.values) {
      c.dispose();
    }
    for (final c in _keywordsCtrl.values) {
      c.dispose();
    }
    for (final c in _promoCtrl.values) {
      c.dispose();
    }
    for (final c in _descCtrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _copy(String label, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copied $label')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('day311_320.app_store_listing_title'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        children: [
          ZapCard(
            backgroundColor: ZapColors.info.withOpacity(0.08),
            borderColor: ZapColors.info.withOpacity(0.3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.storefront_rounded, color: ZapColors.info, size: 20),
                const SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Text(
                    'Real App Store Connect field limits: name 30 · subtitle 30 · '
                    'keywords 100 (comma-separated, no spaces) · promotional text 170 '
                    '· description 4000. Edit freely — these are starting drafts.',
                    style: ZapTypography.bodySmall.copyWith(color: ZapColors.textPrimary, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.lg),
          Wrap(
            spacing: ZapSpacing.sm,
            children: [
              for (final l in _kLocales)
                ChoiceChip(
                  label: Text(_kLocaleNames[l]!),
                  selected: _locale == l,
                  onSelected: (_) => setState(() => _locale = l),
                  selectedColor: ZapColors.safe.withOpacity(0.2),
                  labelStyle: TextStyle(
                    color: _locale == l ? ZapColors.safe : ZapColors.textSecondary,
                    fontWeight: _locale == l ? FontWeight.w700 : FontWeight.w400,
                  ),
                  backgroundColor: ZapColors.bgCard,
                ),
            ],
          ),
          const SizedBox(height: ZapSpacing.lg),
          _FieldCard(
            label: 'App name',
            limit: _kNameLimit,
            controller: _nameCtrl[_locale]!,
            maxLines: 1,
            onCopy: () => _copy('app name', _nameCtrl[_locale]!.text),
          ),
          const SizedBox(height: ZapSpacing.md),
          _FieldCard(
            label: 'Subtitle',
            limit: _kSubtitleLimit,
            controller: _subtitleCtrl[_locale]!,
            maxLines: 1,
            onCopy: () => _copy('subtitle', _subtitleCtrl[_locale]!.text),
          ),
          const SizedBox(height: ZapSpacing.md),
          _FieldCard(
            label: 'Keywords (comma-separated)',
            limit: _kKeywordsLimit,
            controller: _keywordsCtrl[_locale]!,
            maxLines: 2,
            onCopy: () => _copy('keywords', _keywordsCtrl[_locale]!.text),
          ),
          const SizedBox(height: ZapSpacing.md),
          _FieldCard(
            label: 'Promotional text',
            limit: _kPromoLimit,
            controller: _promoCtrl[_locale]!,
            maxLines: 3,
            onCopy: () => _copy('promotional text', _promoCtrl[_locale]!.text),
          ),
          const SizedBox(height: ZapSpacing.md),
          _FieldCard(
            label: 'Description',
            limit: _kDescLimit,
            controller: _descCtrl[_locale]!,
            maxLines: 12,
            onCopy: () => _copy('description', _descCtrl[_locale]!.text),
          ),
          const SizedBox(height: ZapSpacing.xl),
          Text('SCREENSHOT SIZE GUIDE',
              style: ZapTypography.labelLarge.copyWith(color: ZapColors.textSecondary, letterSpacing: 1.2)),
          const SizedBox(height: ZapSpacing.sm),
          for (final s in _kScreenshotSizes)
            ZapCard(
              margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
              child: Row(
                children: [
                  const Icon(Icons.crop_portrait_rounded, color: ZapColors.info, size: 22),
                  const SizedBox(width: ZapSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.label,
                            style: ZapTypography.bodyMedium
                                .copyWith(color: ZapColors.textPrimary, fontWeight: FontWeight.w700)),
                        Text(s.devices,
                            style: ZapTypography.bodySmall.copyWith(color: ZapColors.textSecondary)),
                      ],
                    ),
                  ),
                  ZapBadge(label: s.pixels, intent: ZapBadgeIntent.info, size: ZapBadgeSize.small),
                ],
              ),
            ),
          const SizedBox(height: ZapSpacing.md),
          ZapCard(
            backgroundColor: ZapColors.warning.withOpacity(0.08),
            borderColor: ZapColors.warning.withOpacity(0.3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_rounded, color: ZapColors.warning, size: 18),
                const SizedBox(width: ZapSpacing.sm),
                Expanded(
                  child: Text(
                    'Apple periodically adds new required size classes (e.g. a 6.9" '
                    'tier for newer Pro Max models). Verify against the live App '
                    'Store Connect Help page before a real submission.',
                    style: ZapTypography.bodySmall.copyWith(color: ZapColors.textSecondary, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.huge),
        ],
      ),
    );
  }
}

class _FieldCard extends StatefulWidget {
  const _FieldCard({
    required this.label,
    required this.limit,
    required this.controller,
    required this.maxLines,
    required this.onCopy,
  });

  final String label;
  final int limit;
  final TextEditingController controller;
  final int maxLines;
  final VoidCallback onCopy;

  @override
  State<_FieldCard> createState() => _FieldCardState();
}

class _FieldCardState extends State<_FieldCard> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final len = widget.controller.text.length;
    final over = len > widget.limit;
    final counterColor = over ? ZapColors.danger : ZapColors.textSecondary;

    return ZapCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(widget.label,
                    style: ZapTypography.bodyMedium
                        .copyWith(color: ZapColors.textPrimary, fontWeight: FontWeight.w700)),
              ),
              ZapBadge(
                label: '$len / ${widget.limit}',
                intent: over ? ZapBadgeIntent.danger : ZapBadgeIntent.neutral,
                size: ZapBadgeSize.small,
              ),
              const SizedBox(width: ZapSpacing.xs),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 18, color: ZapColors.info),
                onPressed: widget.onCopy,
                tooltip: 'Copy',
              ),
            ],
          ),
          TextField(
            controller: widget.controller,
            maxLines: widget.maxLines,
            style: ZapTypography.bodySmall.copyWith(color: ZapColors.textPrimary),
            decoration: InputDecoration(
              filled: true,
              fillColor: ZapColors.bgSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(ZapSpacing.sm),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: ZapSpacing.xs),
            child: Text(
              counterColor == ZapColors.danger ? 'Over limit — trim before submitting' : ' ',
              style: ZapTypography.labelMedium.copyWith(color: counterColor),
            ),
          ),
        ],
      ),
    );
  }
}
