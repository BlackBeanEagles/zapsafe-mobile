/// Day 108 — Functional Language Toggle
///
/// Searchable language picker that calls context.setLocale() from
/// easy_localization AND updates i18nProvider so both the app locale and the
/// custom state stay in sync. The live-preview section uses real .tr() calls,
/// so strings visibly update the moment a new locale is applied.
library;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/spacing.dart';
import '../../domain/providers/i18n_providers.dart';

class Day108LanguageToggleScreen extends ConsumerStatefulWidget {
  const Day108LanguageToggleScreen({super.key});

  @override
  ConsumerState<Day108LanguageToggleScreen> createState() =>
      _Day108LanguageToggleScreenState();
}

class _Day108LanguageToggleScreenState
    extends ConsumerState<Day108LanguageToggleScreen> {
  final TextEditingController _search = TextEditingController();
  String _query = '';
  String? _lastApplied;   // code of last successfully applied locale

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<LangInfo> get _filtered {
    if (_query.isEmpty) return kSupportedLanguages;
    final q = _query.toLowerCase();
    return kSupportedLanguages.where((l) =>
        l.name.toLowerCase().contains(q) ||
        l.nativeName.toLowerCase().contains(q) ||
        l.code.toLowerCase().contains(q)).toList();
  }

  void _apply(LangInfo lang) {
    context.setLocale(lang.locale);
    ref.read(i18nProvider.notifier).select(lang.code);
    setState(() => _lastApplied = lang.code);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${lang.flag} ${lang.nativeName} — language applied'),
        backgroundColor: const Color(0xFF10B981),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final i18n    = ref.watch(i18nProvider);
    final current = i18n.lang;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: CustomScrollView(
        slivers: [
          _HeroBanner(current: current),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.md),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: ZapSpacing.md),
                _CurrentLanguageCard(lang: current),
                const SizedBox(height: ZapSpacing.lg),
                _LivePreviewCard(current: current),
                const SizedBox(height: ZapSpacing.lg),
                const _SectionLabel('SELECT LANGUAGE'),
                const SizedBox(height: ZapSpacing.sm),
                _SearchField(
                  controller: _search,
                  onChanged: (v) => setState(() => _query = v),
                ),
                const SizedBox(height: ZapSpacing.sm),
                _LanguageList(
                  filtered:    _filtered,
                  current:     current,
                  lastApplied: _lastApplied,
                  onTap:       _apply,
                ),
                const SizedBox(height: ZapSpacing.lg),
                const _TechNote(),
                const SizedBox(height: ZapSpacing.xl),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Hero ─────────────────────────────────────────────────────────────────────

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.current});
  final LangInfo current;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(ZapSpacing.md),
        padding: const EdgeInsets.all(ZapSpacing.lg),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF064E3B), Color(0xFF020F0A)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF10B981), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(20)),
                  child: const Text('DAY 108', style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
                  ),
                  child: Text('${current.flag} ${current.code.toUpperCase()}',
                      style: const TextStyle(color: Color(0xFF6EE7B7), fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: ZapSpacing.md),
            const Text('Language Toggle\nFunctional', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, height: 1.2)),
            const SizedBox(height: ZapSpacing.sm),
            const Text(
              'context.setLocale() · i18nProvider · live .tr() · search · 15 locales',
              style: TextStyle(color: Color(0xFF6EE7B7), fontSize: 13, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Current Language Card ────────────────────────────────────────────────────

class _CurrentLanguageCard extends StatelessWidget {
  const _CurrentLanguageCard({required this.lang});
  final LangInfo lang;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1F18),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Text(lang.flag, style: const TextStyle(fontSize: 36)),
          const SizedBox(width: ZapSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('CURRENT LANGUAGE',
                    style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.1)),
                const SizedBox(height: 4),
                Text(lang.nativeName,
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                Text(lang.name,
                    style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
              ],
            ),
          ),
          if (lang.rtl)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.4)),
              ),
              child: const Text('RTL', style: TextStyle(color: Color(0xFFA78BFA), fontSize: 11, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }
}

// ─── Live Preview Card ────────────────────────────────────────────────────────

class _LivePreviewCard extends StatelessWidget {
  const _LivePreviewCard({required this.current});
  final LangInfo current;

  @override
  Widget build(BuildContext context) {
    final dir = current.rtl ? TextDirection.rtl : TextDirection.ltr;
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1F2F28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: Color(0xFF10B981), size: 16),
              const SizedBox(width: 6),
              const Text('LIVE .tr() PREVIEW',
                  style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1)),
              const Spacer(),
              Text('Updates instantly', style: TextStyle(color: const Color(0xFF10B981).withOpacity(0.6), fontSize: 10)),
            ],
          ),
          const Divider(color: Color(0xFF1A2A22), height: 20),
          Directionality(
            textDirection: dir,
            child: Column(
              children: [
                _trRow(Icons.shield_rounded,          const Color(0xFFEF4444), 'sos.trigger',      'sos.trigger'.tr()),
                _trRow(Icons.home_rounded,             const Color(0xFF3B82F6), 'home.status_safe', 'home.status_safe'.tr()),
                _trRow(Icons.settings_rounded,         const Color(0xFF8B5CF6), 'settings.title',   'settings.title'.tr()),
                _trRow(Icons.check_rounded,            const Color(0xFF10B981), 'common.save',       'common.save'.tr()),
                _trRow(Icons.people_rounded,           const Color(0xFFF59E0B), 'contacts.title',   'contacts.title'.tr()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _trRow(IconData icon, Color color, String key, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 8),
          SizedBox(width: 120,
              child: Text(key, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11, fontFamily: 'monospace'))),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: const TextStyle(color: Color(0xFFE5E7EB), fontSize: 13, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

// ─── Section Label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2),
  );
}

// ─── Search Field ─────────────────────────────────────────────────────────────

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: 'Search languages…',
        hintStyle: const TextStyle(color: Color(0xFF4B5563)),
        prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF6B7280), size: 20),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear_rounded, color: Color(0xFF6B7280), size: 18),
                onPressed: () { controller.clear(); onChanged(''); },
              )
            : null,
        filled: true,
        fillColor: const Color(0xFF111111),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }
}

// ─── Language List ────────────────────────────────────────────────────────────

class _LanguageList extends StatelessWidget {
  const _LanguageList({
    required this.filtered,
    required this.current,
    required this.lastApplied,
    required this.onTap,
  });
  final List<LangInfo> filtered;
  final LangInfo current;
  final String? lastApplied;
  final void Function(LangInfo) onTap;

  @override
  Widget build(BuildContext context) {
    if (filtered.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(ZapSpacing.xl),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: const Color(0xFF111111), borderRadius: BorderRadius.circular(12)),
        child: const Text('No languages match your search', style: TextStyle(color: Color(0xFF6B7280), fontSize: 14)),
      );
    }
    return Container(
      decoration: BoxDecoration(color: const Color(0xFF111111), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFF1F1F1F))),
      child: Column(
        children: List.generate(filtered.length, (i) {
          final lang    = filtered[i];
          final isFirst = i == 0;
          final isLast  = i == filtered.length - 1;
          final isCurrent  = lang.code == current.code;
          final wasApplied = lang.code == lastApplied;

          return GestureDetector(
            onTap: () => onTap(lang),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.md, vertical: 14),
              decoration: BoxDecoration(
                color: isCurrent ? const Color(0xFF10B981).withOpacity(0.08) : Colors.transparent,
                borderRadius: BorderRadius.vertical(
                  top:    isFirst ? const Radius.circular(16) : Radius.zero,
                  bottom: isLast  ? const Radius.circular(16) : Radius.zero,
                ),
                border: isLast ? null : const Border(bottom: BorderSide(color: Color(0xFF1A1A1A))),
              ),
              child: Row(
                children: [
                  Text(lang.flag, style: const TextStyle(fontSize: 24)),
                  const SizedBox(width: ZapSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(lang.nativeName,
                            style: TextStyle(
                              color: isCurrent ? const Color(0xFF10B981) : Colors.white,
                              fontSize: 15, fontWeight: FontWeight.w600,
                            )),
                        Text(lang.name, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
                      ],
                    ),
                  ),
                  if (lang.rtl)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C3AED).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Text('RTL', style: TextStyle(color: Color(0xFFA78BFA), fontSize: 9, fontWeight: FontWeight.w700)),
                    ),
                  if (isCurrent)
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 22)
                  else if (wasApplied)
                    const Icon(Icons.check_rounded, color: Color(0xFF6B7280), size: 20)
                  else
                    const Icon(Icons.chevron_right_rounded, color: Color(0xFF374151), size: 20),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─── Tech Note ────────────────────────────────────────────────────────────────

class _TechNote extends StatelessWidget {
  const _TechNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1F1F1F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('HOW IT WORKS', style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.1)),
          const SizedBox(height: ZapSpacing.sm),
          _noteRow(Icons.language_rounded,      const Color(0xFF10B981), 'context.setLocale()',    'easy_localization — rebuilds entire MaterialApp.router locale'),
          _noteRow(Icons.sync_rounded,           const Color(0xFF3B82F6), 'i18nProvider.select()',  'Riverpod state — syncs custom locale picker + RTL flag'),
          _noteRow(Icons.translate_rounded,      const Color(0xFF8B5CF6), '.tr() extension',        'All widget subtrees re-render with new locale strings'),
          _noteRow(Icons.swap_horiz_rounded,     const Color(0xFFF59E0B), 'RTL Directionality',     'ur / ar trigger TextDirection.rtl automatically'),
          _noteRow(Icons.storage_rounded,        const Color(0xFFEF4444), 'Persistence',            'easy_localization saves choice to shared_preferences'),
        ],
      ),
    );
  }

  Widget _noteRow(IconData icon, Color color, String label, String detail) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(children: [
                TextSpan(text: '$label  ', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700, fontFamily: 'monospace')),
                TextSpan(text: detail, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
