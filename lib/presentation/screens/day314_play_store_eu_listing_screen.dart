/// Day 314 — Play Store EU Listing Copy Generator
///
/// Generates draft Play Store listing copy for four EU-relevant locales
/// (en, de, fr, es) against Google Play's real published character
/// limits: title 30 chars, short description 80 chars, full description
/// 4000 chars. Each field has a live counter (turns red over-limit) and a
/// copy-to-clipboard button. Draft copy is editable — this is a starting
/// point for the actual Play Console submission, not a final translation
/// service.
///
/// The copy references this app's real "27 Loophole Defenses" system
/// (`zapsafe_backend/loopholes/models.py`'s `LPNumber` choices, LP1-LP27)
/// rather than a fabricated privacy feature. The spec asked to reference
/// "LP27" as a privacy feature specifically — grepping the repo shows
/// LP27 is actually **"Lock Screen Suppression"** (also called
/// Blank-Screen Panic Mode in `day71_alert_pending_screen.dart` /
/// `day76_sos_active_screen.dart`), a discretion/anti-detection safety
/// feature, not a GDPR-style data-privacy control. The copy below cites
/// it accurately for what it is (a safety-discretion feature) and uses
/// generic "privacy-by-design" language for the actual GDPR/data-
/// protection angle, per the spec's own fallback instruction.
///
/// Tag: 🟢 FRONTEND-ONLY
///
/// Route: AppRoutes.playStoreEuListing
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../widgets/zap_badge.dart';
import '../widgets/zap_card.dart';

class _ListingCopy {
  const _ListingCopy({required this.title, required this.shortDesc, required this.fullDesc});
  final String title;
  final String shortDesc;
  final String fullDesc;
}

const _kTitleLimit = 30;
const _kShortDescLimit = 80;
const _kFullDescLimit = 4000;

const _kLocales = ['en', 'de', 'fr', 'es'];

const _kLocaleNames = {
  'en': 'English',
  'de': 'Deutsch (German)',
  'fr': 'Français (French)',
  'es': 'Español (Spanish)',
};

const _kDraftCopy = {
  'en': _ListingCopy(
    title: 'ZapSafe – Safety & SOS Alerts',
    shortDesc: 'AI-powered SOS, live location sharing & silent evidence capture. Stay safe.',
    fullDesc:
        'ZapSafe is a personal-safety app built around one idea: help should arrive '
        'before you even finish saying you need it.\n\n'
        'Trigger an SOS by voice, motion, or a single tap — ZapSafe shares your live '
        'location with trusted contacts, escalates automatically if you don\'t respond, '
        'and can silently record audio/video evidence, encrypted on your device.\n\n'
        'Built for real emergencies, not demos: ZapSafe ships with 27 built-in '
        '"loophole defenses" that close the gaps most safety apps miss — from '
        'duress PINs and mic-tamper detection to Lock Screen Suppression, which '
        'keeps the SOS screen from being visible or dismissible by someone else '
        'holding your phone during an active alert.\n\n'
        'Privacy-by-design throughout: granular, withdrawable consent controls for '
        'every optional data use, on-device evidence storage by default, and full '
        'transparency about what is (and is never) shared.\n\n'
        'Free tier included. Premium unlocks extra trusted contacts, longer evidence '
        'retention, and priority SMS delivery.',
  ),
  'de': _ListingCopy(
    title: 'ZapSafe – Sicherheit & SOS',
    shortDesc: 'KI-gestützte SOS-Alarme, Live-Standort und stille Beweissicherung. Bleib sicher.',
    fullDesc:
        'ZapSafe ist eine App für persönliche Sicherheit, die auf einer Idee beruht: '
        'Hilfe sollte ankommen, bevor Sie überhaupt fertig gesprochen haben.\n\n'
        'Lösen Sie einen SOS-Alarm per Stimme, Bewegung oder Fingertipp aus — ZapSafe '
        'teilt Ihren Live-Standort mit Vertrauenspersonen, eskaliert automatisch bei '
        'ausbleibender Reaktion und kann still Audio-/Videobeweise verschlüsselt auf '
        'Ihrem Gerät speichern.\n\n'
        'Für echte Notfälle gebaut: ZapSafe enthält 27 integrierte "Loophole-'
        'Verteidigungen", die typische Sicherheitslücken schließen — von Duress-PINs '
        'und Mikrofon-Manipulationserkennung bis zur Bildschirmsperr-Unterdrückung, '
        'die verhindert, dass der SOS-Bildschirm von einer anderen Person, die Ihr '
        'Telefon während eines aktiven Alarms hält, gesehen oder geschlossen werden '
        'kann.\n\n'
        'Privacy-by-Design durchgängig: granulare, jederzeit widerrufbare '
        'Einwilligungen für jede optionale Datennutzung, Beweisspeicherung standard'
        'mäßig auf dem Gerät und volle Transparenz darüber, was (nie) geteilt wird.\n\n'
        'Kostenlose Version inklusive. Premium schaltet zusätzliche Vertrauenspersonen, '
        'längere Beweisaufbewahrung und priorisierten SMS-Versand frei.',
  ),
  'fr': _ListingCopy(
    title: 'ZapSafe – Sécurité & SOS',
    shortDesc: 'Alertes SOS par IA, partage de position en direct et preuves silencieuses.',
    fullDesc:
        'ZapSafe est une application de sécurité personnelle construite autour d\'une '
        'idée simple : l\'aide devrait arriver avant même que vous ayez fini de dire '
        'que vous en avez besoin.\n\n'
        'Déclenchez une alerte SOS par la voix, le mouvement ou un simple appui — '
        'ZapSafe partage votre position en direct avec vos contacts de confiance, '
        'escalade automatiquement en l\'absence de réponse, et peut enregistrer '
        'silencieusement des preuves audio/vidéo, chiffrées sur votre appareil.\n\n'
        'Conçu pour de vraies urgences : ZapSafe intègre 27 "défenses contre les '
        'failles" qui comblent les lacunes que la plupart des applications de '
        'sécurité laissent ouvertes — du code PIN de détresse à la détection de '
        'sabotage du micro, en passant par la suppression de l\'écran de verrouillage, '
        'qui empêche l\'écran SOS d\'être vu ou fermé par une autre personne tenant '
        'votre téléphone pendant une alerte active.\n\n'
        'Confidentialité dès la conception partout : contrôles de consentement '
        'granulaires et révocables pour chaque usage optionnel des données, stockage '
        'des preuves sur l\'appareil par défaut, et transparence totale sur ce qui '
        'est (et n\'est jamais) partagé.\n\n'
        'Offre gratuite incluse. Premium débloque des contacts de confiance '
        'supplémentaires, une conservation des preuves plus longue et une livraison '
        'SMS prioritaire.',
  ),
  'es': _ListingCopy(
    title: 'ZapSafe – Seguridad y SOS',
    shortDesc: 'Alertas SOS con IA, ubicación en vivo y captura silenciosa de evidencia.',
    fullDesc:
        'ZapSafe es una aplicación de seguridad personal construida sobre una idea: '
        'la ayuda debería llegar antes de que termines de decir que la necesitas.\n\n'
        'Activa una alerta SOS por voz, movimiento o un solo toque — ZapSafe comparte '
        'tu ubicación en vivo con tus contactos de confianza, escala automáticamente '
        'si no respondes, y puede grabar en silencio evidencia de audio/video, '
        'cifrada en tu dispositivo.\n\n'
        'Diseñada para emergencias reales: ZapSafe incluye 27 "defensas contra '
        'brechas" integradas que cierran los vacíos que la mayoría de las apps de '
        'seguridad dejan abiertos — desde PIN de coacción y detección de manipulación '
        'del micrófono hasta la supresión de la pantalla de bloqueo, que evita que la '
        'pantalla de SOS sea vista o cerrada por otra persona que sostenga tu teléfono '
        'durante una alerta activa.\n\n'
        'Privacidad desde el diseño en todo momento: controles de consentimiento '
        'granulares y revocables para cada uso opcional de datos, almacenamiento de '
        'evidencia en el dispositivo por defecto, y total transparencia sobre qué se '
        'comparte (y qué nunca se comparte).\n\n'
        'Nivel gratuito incluido. Premium desbloquea contactos de confianza '
        'adicionales, retención de evidencia más larga y envío de SMS prioritario.',
  ),
};

class Day314PlayStoreEuListingScreen extends StatefulWidget {
  const Day314PlayStoreEuListingScreen({super.key});

  @override
  State<Day314PlayStoreEuListingScreen> createState() => _Day314PlayStoreEuListingScreenState();
}

class _Day314PlayStoreEuListingScreenState extends State<Day314PlayStoreEuListingScreen> {
  String _locale = 'en';
  late final Map<String, TextEditingController> _titleCtrl;
  late final Map<String, TextEditingController> _shortCtrl;
  late final Map<String, TextEditingController> _fullCtrl;

  @override
  void initState() {
    super.initState();
    _titleCtrl = {
      for (final l in _kLocales) l: TextEditingController(text: _kDraftCopy[l]!.title),
    };
    _shortCtrl = {
      for (final l in _kLocales) l: TextEditingController(text: _kDraftCopy[l]!.shortDesc),
    };
    _fullCtrl = {
      for (final l in _kLocales) l: TextEditingController(text: _kDraftCopy[l]!.fullDesc),
    };
  }

  @override
  void dispose() {
    for (final c in _titleCtrl.values) {
      c.dispose();
    }
    for (final c in _shortCtrl.values) {
      c.dispose();
    }
    for (final c in _fullCtrl.values) {
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
      appBar: AppBar(title: Text('day311_320.play_listing_title'.tr())),
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
                    'Draft copy against Google Play\'s real published limits: title 30 '
                    'chars, short description 80 chars, full description 4000 chars. '
                    'Edit freely — these are starting drafts, not final translations.',
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
            label: 'Title',
            limit: _kTitleLimit,
            controller: _titleCtrl[_locale]!,
            maxLines: 1,
            onCopy: () => _copy('title', _titleCtrl[_locale]!.text),
          ),
          const SizedBox(height: ZapSpacing.md),
          _FieldCard(
            label: 'Short description',
            limit: _kShortDescLimit,
            controller: _shortCtrl[_locale]!,
            maxLines: 2,
            onCopy: () => _copy('short description', _shortCtrl[_locale]!.text),
          ),
          const SizedBox(height: ZapSpacing.md),
          _FieldCard(
            label: 'Full description',
            limit: _kFullDescLimit,
            controller: _fullCtrl[_locale]!,
            maxLines: 12,
            onCopy: () => _copy('full description', _fullCtrl[_locale]!.text),
          ),
          const SizedBox(height: ZapSpacing.lg),
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
                    'References this app\'s real "27 Loophole Defenses" system '
                    '(LP1-LP27 in zapsafe_backend/loopholes/models.py) — LP27 is '
                    'Lock Screen Suppression, a discretion/safety feature, not a '
                    'GDPR-style privacy control. The GDPR angle above uses generic '
                    '"privacy-by-design" language instead of inventing an LP27 '
                    'privacy-feature description that doesn\'t exist.',
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
