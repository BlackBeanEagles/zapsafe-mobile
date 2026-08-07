// Day 99 — Help & Support
//
// FAQ accordion (10 items, 4 categories, single-open) ·
// Contact form (topic chips + textarea + 1.2 s send mock → success card) ·
// App info block (version, build, server status).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/theme/spacing.dart';
import '../../domain/providers/help_support_providers.dart';

// ─── Screen ───────────────────────────────────────────────────────────────────

class Day99HelpSupportScreen extends ConsumerWidget {
  const Day99HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: ZapColors.bgPrimary,
        elevation: 0,
        title: Text(
          'Help & Support',
          style: ZapTypography.headlineSmall.copyWith(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: ZapSpacing.lg),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: ZapSpacing.md),

                // ─── Hero banner ───────────────────────────────────
                const _HeroBanner(),
                const SizedBox(height: ZapSpacing.xl),

                // ─── FAQ section ───────────────────────────────────
                const _SectionHeader(
                  icon:  Icons.help_outline_rounded,
                  label: 'Frequently Asked',
                  color: ZapColors.info,
                ),
                const SizedBox(height: ZapSpacing.sm),
                const _CategoryFilter(),
                const SizedBox(height: ZapSpacing.sm),
                const _FaqList(),
                const SizedBox(height: ZapSpacing.xl),

                // ─── Contact support ───────────────────────────────
                const _SectionHeader(
                  icon:  Icons.support_agent_rounded,
                  label: 'Contact Support',
                  color: ZapColors.safe,
                ),
                const SizedBox(height: ZapSpacing.sm),
                const _ContactForm(),
                const SizedBox(height: ZapSpacing.xl),

                // ─── App info ──────────────────────────────────────
                const _SectionHeader(
                  icon:  Icons.info_outline_rounded,
                  label: 'App Info',
                  color: ZapColors.textSecondary,
                ),
                const SizedBox(height: ZapSpacing.sm),
                const _AppInfoCard(),
                const SizedBox(height: ZapSpacing.xxxl),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Hero banner ──────────────────────────────────────────────────────────────

class _HeroBanner extends StatelessWidget {
  const _HeroBanner();

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
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: ZapColors.safe.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: ZapColors.safe.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.support_agent_rounded,
                size: 26, color: ZapColors.safe),
          ),
          const SizedBox(width: ZapSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'We\'re here to help',
                  style: ZapTypography.headlineSmall.copyWith(
                    color: ZapColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: ZapSpacing.xs),
                Text(
                  'Premium users get 4 h response · Free users 48 h',
                  style: ZapTypography.bodySmall.copyWith(
                    color: ZapColors.textSecondary,
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

// ─── Section header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String   label;
  final Color    color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: ZapSpacing.xs),
        Text(
          label.toUpperCase(),
          style: ZapTypography.labelSmall.copyWith(
            color: color,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: ZapSpacing.md),
        const Expanded(child: Divider(color: ZapColors.border)),
      ],
    );
  }
}

// ─── Category filter ──────────────────────────────────────────────────────────

class _CategoryFilter extends ConsumerWidget {
  const _CategoryFilter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active   = ref.watch(helpSupportProvider.select((s) => s.activeCategory));
    final notifier = ref.read(helpSupportProvider.notifier);

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: FaqCategory.values.length,
        separatorBuilder: (_, __) =>
            const SizedBox(width: ZapSpacing.sm),
        itemBuilder: (_, i) {
          final cat      = FaqCategory.values[i];
          final selected = cat == active;
          return GestureDetector(
            onTap: () => notifier.setCategory(cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(
                  horizontal: ZapSpacing.md, vertical: ZapSpacing.xs),
              decoration: BoxDecoration(
                color: selected
                    ? ZapColors.info.withOpacity(0.2)
                    : ZapColors.bgCard,
                borderRadius:
                    BorderRadius.circular(ZapSpacing.radiusSmall),
                border: Border.all(
                  color: selected ? ZapColors.info : ZapColors.border,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Text(
                cat.label,
                style: ZapTypography.labelSmall.copyWith(
                  color: selected
                      ? ZapColors.info
                      : ZapColors.textSecondary,
                  fontWeight: selected
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── FAQ list ─────────────────────────────────────────────────────────────────

class _FaqList extends ConsumerWidget {
  const _FaqList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items    = ref.watch(filteredFaqProvider);
    final expanded = ref.watch(helpSupportProvider.select((s) => s.expandedFaqId));
    final notifier = ref.read(helpSupportProvider.notifier);

    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(ZapSpacing.xl),
        decoration: BoxDecoration(
          color: ZapColors.bgCard,
          borderRadius: BorderRadius.circular(ZapSpacing.radius),
          border: Border.all(color: ZapColors.border, width: 1),
        ),
        child: Center(
          child: Text('No questions in this category.',
              style: ZapTypography.bodyMedium
                  .copyWith(color: ZapColors.textMuted)),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: ZapColors.border, width: 1),
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final i    = entry.key;
          final item = entry.value;
          final isOpen = item.id == expanded;
          return Column(
            children: [
              if (i > 0)
                const Divider(color: ZapColors.divider, height: 1),
              _FaqTile(item: item, isOpen: isOpen, onToggle: notifier.toggleFaq),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({
    required this.item,
    required this.isOpen,
    required this.onToggle,
  });

  final FaqItem  item;
  final bool     isOpen;
  final void Function(String) onToggle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onToggle(item.id),
      borderRadius: BorderRadius.circular(ZapSpacing.radius),
      child: Padding(
        padding: const EdgeInsets.all(ZapSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.question,
                    style: ZapTypography.labelLarge.copyWith(
                      color: isOpen
                          ? ZapColors.info
                          : ZapColors.textPrimary,
                      fontWeight:
                          isOpen ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: ZapSpacing.sm),
                Icon(
                  isOpen
                      ? Icons.remove_circle_outline_rounded
                      : Icons.add_circle_outline_rounded,
                  size: 18,
                  color: isOpen ? ZapColors.info : ZapColors.textMuted,
                ),
              ],
            ),
            if (isOpen) ...[
              const SizedBox(height: ZapSpacing.md),
              Text(
                item.answer,
                style: ZapTypography.bodyMedium.copyWith(
                  color: ZapColors.textSecondary,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: ZapSpacing.xs),
              // Category chip
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: ZapSpacing.sm, vertical: 3),
                decoration: BoxDecoration(
                  color: ZapColors.info.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  item.category.label,
                  style: ZapTypography.labelSmall.copyWith(
                    fontSize: 10,
                    color: ZapColors.info,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Contact form ─────────────────────────────────────────────────────────────

class _ContactForm extends ConsumerStatefulWidget {
  const _ContactForm();

  @override
  ConsumerState<_ContactForm> createState() => _ContactFormState();
}

class _ContactFormState extends ConsumerState<_ContactForm> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController();
    _ctrl.addListener(
        () => ref.read(helpSupportProvider.notifier).setMessage(_ctrl.text));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state    = ref.watch(helpSupportProvider);
    final notifier = ref.read(helpSupportProvider.notifier);

    if (state.sentSuccess) {
      return _SuccessCard(onReset: () {
        notifier.resetForm();
        _ctrl.clear();
      });
    }

    return Container(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: ZapColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Topic selector
          Text('Topic',
              style: ZapTypography.labelMedium
                  .copyWith(color: ZapColors.textPrimary)),
          const SizedBox(height: ZapSpacing.sm),
          Wrap(
            spacing: ZapSpacing.sm,
            runSpacing: ZapSpacing.sm,
            children: SupportTopic.values.map((t) {
              final sel = t == state.selectedTopic;
              return GestureDetector(
                onTap: () => notifier.setTopic(t),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(
                      horizontal: ZapSpacing.md, vertical: ZapSpacing.xs),
                  decoration: BoxDecoration(
                    color: sel
                        ? ZapColors.safe.withOpacity(0.18)
                        : ZapColors.bgElevated,
                    borderRadius:
                        BorderRadius.circular(ZapSpacing.radiusSmall),
                    border: Border.all(
                      color: sel ? ZapColors.safe : ZapColors.border,
                      width: sel ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    t.label,
                    style: ZapTypography.labelSmall.copyWith(
                      color: sel
                          ? ZapColors.safe
                          : ZapColors.textSecondary,
                      fontWeight:
                          sel ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: ZapSpacing.lg),

          // Message field
          Text('Message',
              style: ZapTypography.labelMedium
                  .copyWith(color: ZapColors.textPrimary)),
          const SizedBox(height: ZapSpacing.sm),
          TextField(
            controller: _ctrl,
            maxLines: 5,
            minLines: 4,
            style: ZapTypography.bodyMedium
                .copyWith(color: ZapColors.textPrimary),
            cursorColor: ZapColors.safe,
            decoration: InputDecoration(
              hintText:
                  'Describe your issue in detail (minimum 10 characters)…',
              hintStyle: ZapTypography.bodyMedium
                  .copyWith(color: ZapColors.textMuted),
              filled: true,
              fillColor: ZapColors.bgElevated,
              border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(ZapSpacing.radiusSmall),
                borderSide:
                    const BorderSide(color: ZapColors.border, width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(ZapSpacing.radiusSmall),
                borderSide:
                    const BorderSide(color: ZapColors.border, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(ZapSpacing.radiusSmall),
                borderSide: const BorderSide(
                    color: ZapColors.safe, width: 1.5),
              ),
              contentPadding: const EdgeInsets.all(ZapSpacing.md),
            ),
          ),

          // Character counter
          const SizedBox(height: ZapSpacing.xs),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${state.message.length} / 1000',
              style: ZapTypography.bodySmall
                  .copyWith(color: ZapColors.textMuted),
            ),
          ),
          const SizedBox(height: ZapSpacing.md),

          // Send button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: state.canSend ? notifier.sendMessage : null,
              icon: state.isSending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded, size: 16),
              label: Text(
                state.isSending ? 'Sending…' : 'Send Message',
                style: ZapTypography.labelMedium
                    .copyWith(color: Colors.white),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: ZapColors.safe,
                disabledBackgroundColor: ZapColors.bgElevated,
                padding: const EdgeInsets.symmetric(
                    vertical: ZapSpacing.md),
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(ZapSpacing.radiusSmall)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuccessCard extends StatelessWidget {
  const _SuccessCard({required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.xl),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border:
            Border.all(color: ZapColors.safe.withOpacity(0.4), width: 1),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: ZapColors.safe.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded,
                size: 28, color: ZapColors.safe),
          ),
          const SizedBox(height: ZapSpacing.md),
          Text(
            'Message Sent!',
            style: ZapTypography.headlineSmall.copyWith(
              color: ZapColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: ZapSpacing.sm),
          Text(
            'Our support team will get back to you within 4–48 hours depending on your subscription plan.',
            textAlign: TextAlign.center,
            style: ZapTypography.bodyMedium.copyWith(
              color: ZapColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: ZapSpacing.lg),
          OutlinedButton(
            onPressed: onReset,
            style: OutlinedButton.styleFrom(
              foregroundColor: ZapColors.textSecondary,
              side: const BorderSide(color: ZapColors.border, width: 1),
              padding: const EdgeInsets.symmetric(
                  horizontal: ZapSpacing.xl, vertical: ZapSpacing.md),
              shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(ZapSpacing.radiusSmall)),
            ),
            child: const Text('Send Another'),
          ),
        ],
      ),
    );
  }
}

// ─── App info card ────────────────────────────────────────────────────────────

class _AppInfoCard extends StatelessWidget {
  const _AppInfoCard();

  @override
  Widget build(BuildContext context) {
    const info = kAppInfo;
    final statusColor = info.serverStatus == 'operational'
        ? ZapColors.safe
        : info.serverStatus == 'degraded'
            ? ZapColors.warning
            : ZapColors.danger;
    final statusLabel = info.serverStatus == 'operational'
        ? 'All Systems Operational'
        : info.serverStatus == 'degraded'
            ? 'Degraded Performance'
            : 'Service Outage';

    return Container(
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: ZapColors.border, width: 1),
      ),
      child: Column(
        children: [
          _InfoRow(
            label: 'Version',
            value: info.version,
            icon:  Icons.new_releases_rounded,
          ),
          const Divider(color: ZapColors.divider, height: 1, indent: 52),
          _InfoRow(
            label: 'Build',
            value: info.build,
            icon:  Icons.build_rounded,
          ),
          const Divider(color: ZapColors.divider, height: 1, indent: 52),
          _InfoRow(
            label: 'Last Sync',
            value: info.lastSync,
            icon:  Icons.sync_rounded,
          ),
          const Divider(color: ZapColors.divider, height: 1, indent: 52),
          // Server status row
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: ZapSpacing.lg, vertical: ZapSpacing.md),
            child: Row(
              children: [
                const Icon(Icons.cloud_done_rounded,
                    size: 20, color: ZapColors.textMuted),
                const SizedBox(width: ZapSpacing.md),
                Expanded(
                  child: Text('Server Status',
                      style: ZapTypography.labelLarge
                          .copyWith(color: ZapColors.textPrimary)),
                ),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: ZapSpacing.xs),
                Text(
                  statusLabel,
                  style: ZapTypography.bodySmall
                      .copyWith(color: statusColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String   label;
  final String   value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: ZapSpacing.lg, vertical: ZapSpacing.md),
      child: Row(
        children: [
          Icon(icon, size: 20, color: ZapColors.textMuted),
          const SizedBox(width: ZapSpacing.md),
          Expanded(
            child: Text(label,
                style: ZapTypography.labelLarge
                    .copyWith(color: ZapColors.textPrimary)),
          ),
          Text(value,
              style: ZapTypography.bodySmall
                  .copyWith(color: ZapColors.textSecondary)),
        ],
      ),
    );
  }
}
