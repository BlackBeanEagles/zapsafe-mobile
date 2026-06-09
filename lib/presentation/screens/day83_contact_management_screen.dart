/// Day 83 — Contact Management Screen
///
/// Full CRUD + tier assignment + batch operations for emergency contacts.
///
/// ── Tiers ────────────────────────────────────────────────────────────────────
///   Tier 1 — max 1 contact  (primary emergency contact)
///   Tier 2 — max 5 contacts (secondary escalation ring)
///   Tier 3 — unlimited      (broader notification group)
///
/// ── Modes ────────────────────────────────────────────────────────────────────
///   Normal: search bar, tiered list, FAB to add, long-press for options
///   Batch:  checkboxes, count appbar, bottom bar for delete / tier change
///
/// ── LP18 — Biometric gate ────────────────────────────────────────────────────
///   Any destructive or edit action requires biometric confirmation.
///   In emulator dev mode a single "Confirm" dialog stands in for biometrics.
///
/// ── Mock data ────────────────────────────────────────────────────────────────
///   7 seed contacts (1 Tier-1, 3 Tier-2, 3 Tier-3).
///   API: GET/POST/PATCH/DELETE /api/v1/contacts/ — Month 4.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../domain/providers/contacts_providers.dart';

// ─── Screen ───────────────────────────────────────────────────────────────────

class Day83ContactManagementScreen extends ConsumerWidget {
  const Day83ContactManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batchMode = ref.watch(batchModeProvider);
    final selected  = ref.watch(contactSelectionProvider);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: _buildAppBar(context, ref, batchMode, selected),
      body: const _ContactBody(),
      floatingActionButton: batchMode
          ? null
          : FloatingActionButton(
              onPressed:       () => _showAddSheet(context, ref),
              backgroundColor: ZapColors.safe,
              foregroundColor: Colors.white,
              child:           const Icon(Icons.person_add_rounded),
            ),
      bottomNavigationBar: batchMode && selected.isNotEmpty
          ? _BatchBar(selected: selected)
          : null,
    );
  }

  AppBar _buildAppBar(
    BuildContext context,
    WidgetRef ref,
    bool batchMode,
    Set<String> selected,
  ) {
    if (batchMode) {
      return AppBar(
        backgroundColor:  ZapColors.bgPrimary,
        elevation:        0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon:    const Icon(Icons.close_rounded, color: ZapColors.textPrimary),
          onPressed: () {
            ref.read(batchModeProvider.notifier).state       = false;
            ref.read(contactSelectionProvider.notifier).state = {};
          },
        ),
        title: Text(
          selected.isEmpty ? 'Select contacts' : '${selected.length} selected',
          style: ZapTypography.headlineSmall.copyWith(color: ZapColors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () {
              final all = ref.read(contactsProvider).map((c) => c.id).toSet();
              ref.read(contactSelectionProvider.notifier).state = all;
            },
            child: Text(
              'All',
              style: ZapTypography.labelMedium.copyWith(color: ZapColors.info),
            ),
          ),
        ],
      );
    }

    return AppBar(
      backgroundColor:  ZapColors.bgPrimary,
      elevation:        0,
      surfaceTintColor: Colors.transparent,
      leading: const BackButton(color: ZapColors.textPrimary),
      title: Text(
        'Contacts',
        style: ZapTypography.headlineSmall.copyWith(color: ZapColors.textPrimary),
      ),
    );
  }

  void _showAddSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    ZapColors.bgElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _ContactSheet(existing: null),
    );
  }
}

// ─── Contact body ─────────────────────────────────────────────────────────────

class _ContactBody extends ConsumerWidget {
  const _ContactBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contacts   = ref.watch(contactsProvider);
    final notifier   = ref.read(contactsProvider.notifier);
    final query      = ref.watch(contactSearchProvider);
    final batchMode  = ref.watch(batchModeProvider);
    final selected   = ref.watch(contactSelectionProvider);

    List<Contact> filtered(List<Contact> list) {
      if (query.isEmpty) return list;
      final q = query.toLowerCase();
      return list
          .where((c) =>
              c.name.toLowerCase().contains(q) ||
              c.phone.contains(q))
          .toList();
    }

    final t1 = filtered(notifier.tier1);
    final t2 = filtered(notifier.tier2);
    final t3 = filtered(notifier.tier3);

    if (contacts.isEmpty) {
      return const _EmptyContacts();
    }

    return Column(
      children: [
        // Search bar
        if (!batchMode)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              ZapSpacing.lg, ZapSpacing.md, ZapSpacing.lg, 0,
            ),
            child: _SearchBar(
              onChanged: (q) =>
                  ref.read(contactSearchProvider.notifier).state = q,
            ),
          ),

        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(
              top: ZapSpacing.md,
              bottom: ZapSpacing.xxxl * 3,
            ),
            children: [
              if (t1.isNotEmpty) ...[
                _TierHeader(
                  tier:     1,
                  count:    t1.length,
                  maxCount: kTier1Max,
                ),
                ...t1.map((c) => _ContactTile(
                      contact:    c,
                      batchMode:  batchMode,
                      isSelected: selected.contains(c.id),
                    )),
              ],
              if (t2.isNotEmpty) ...[
                _TierHeader(
                  tier:     2,
                  count:    t2.length,
                  maxCount: kTier2Max,
                ),
                ...t2.map((c) => _ContactTile(
                      contact:    c,
                      batchMode:  batchMode,
                      isSelected: selected.contains(c.id),
                    )),
              ],
              if (t3.isNotEmpty) ...[
                const _TierHeader(tier: 3, count: 0, maxCount: 0),
                ...t3.map((c) => _ContactTile(
                      contact:    c,
                      batchMode:  batchMode,
                      isSelected: selected.contains(c.id),
                    )),
              ],
              if (t1.isEmpty && t2.isEmpty && t3.isEmpty && query.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(ZapSpacing.xxxl),
                  child: Center(
                    child: Text(
                      'No contacts match "$query"',
                      style: ZapTypography.bodyMedium.copyWith(
                        color: ZapColors.textMuted,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Tier header ──────────────────────────────────────────────────────────────

class _TierHeader extends StatelessWidget {
  const _TierHeader({
    required this.tier,
    required this.count,
    required this.maxCount,
  });

  final int tier;
  final int count;
  final int maxCount;

  Color get _color {
    switch (tier) {
      case 1:  return ZapColors.danger;
      case 2:  return ZapColors.warning;
      default: return ZapColors.info;
    }
  }

  String get _label {
    switch (tier) {
      case 1:  return 'Tier 1 · Primary';
      case 2:  return 'Tier 2 · Escalation';
      default: return 'Tier 3 · Broadcast';
    }
  }

  String get _cap {
    if (tier == 3) return 'Unlimited';
    return '$count / $maxCount';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ZapSpacing.lg, ZapSpacing.lg, ZapSpacing.lg, ZapSpacing.sm,
      ),
      child: Row(
        children: [
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _color,
            ),
          ),
          const SizedBox(width: ZapSpacing.sm),
          Text(
            _label.toUpperCase(),
            style: ZapTypography.labelSmall.copyWith(
              color:         _color,
              letterSpacing: 1.0,
            ),
          ),
          const Spacer(),
          Text(
            _cap,
            style: ZapTypography.labelSmall.copyWith(
              color:      ZapColors.textMuted,
              fontFamily: 'IBMPlexMono',
              fontSize:   10,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Contact tile ─────────────────────────────────────────────────────────────

class _ContactTile extends ConsumerWidget {
  const _ContactTile({
    required this.contact,
    required this.batchMode,
    required this.isSelected,
  });

  final Contact contact;
  final bool    batchMode;
  final bool    isSelected;

  Color get _tierColor {
    switch (contact.tier) {
      case 1:  return ZapColors.danger;
      case 2:  return ZapColors.warning;
      default: return ZapColors.info;
    }
  }

  String get _initials {
    final parts = contact.name.trim().split(' ');
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () {
        if (batchMode) {
          final sel = Set<String>.from(ref.read(contactSelectionProvider));
          if (sel.contains(contact.id)) {
            sel.remove(contact.id);
          } else {
            sel.add(contact.id);
          }
          ref.read(contactSelectionProvider.notifier).state = sel;
        }
      },
      onLongPress: () {
        if (!batchMode) {
          ref.read(batchModeProvider.notifier).state       = true;
          ref.read(contactSelectionProvider.notifier).state = {contact.id};
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: ZapSpacing.lg,
          vertical:   ZapSpacing.sm,
        ),
        child: Row(
          children: [
            // Checkbox in batch mode
            if (batchMode)
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width:  24,
                height: 24,
                margin: const EdgeInsets.only(right: ZapSpacing.sm),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? ZapColors.info
                      : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? ZapColors.info : ZapColors.border,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check_rounded,
                        size:  14,
                        color: Colors.white,
                      )
                    : null,
              ),

            // Avatar
            Container(
              width:  44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _tierColor.withOpacity(0.15),
              ),
              alignment: Alignment.center,
              child: Text(
                _initials,
                style: ZapTypography.labelMedium.copyWith(
                  color:      _tierColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: ZapSpacing.md),

            // Name + phone
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contact.name,
                    style: ZapTypography.bodyMedium.copyWith(
                      color: ZapColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    contact.maskedPhone,
                    style: ZapTypography.bodySmall.copyWith(
                      color:      ZapColors.textSecondary,
                      fontFamily: 'IBMPlexMono',
                    ),
                  ),
                ],
              ),
            ),

            // Verified badge
            if (contact.isVerified)
              const Icon(
                Icons.verified_rounded,
                size:  16,
                color: ZapColors.safe,
              )
            else
              const Icon(
                Icons.warning_amber_rounded,
                size:  16,
                color: ZapColors.warning,
              ),

            const SizedBox(width: ZapSpacing.sm),

            // Options button (normal mode)
            if (!batchMode)
              GestureDetector(
                onTap: () => _showOptions(context, ref),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(
                    Icons.more_vert_rounded,
                    size:  18,
                    color: ZapColors.textMuted,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context:         context,
      backgroundColor: ZapColors.bgElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _OptionsSheet(
        contact: contact,
        onEdit:  () {
          Navigator.pop(ctx);
          _biometricGate(context, ref, action: 'edit', onConfirm: () {
            showModalBottomSheet<void>(
              context:            context,
              isScrollControlled: true,
              backgroundColor:    ZapColors.bgElevated,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              builder: (_) => _ContactSheet(existing: contact),
            );
          });
        },
        onDelete: () {
          Navigator.pop(ctx);
          _biometricGate(context, ref, action: 'delete', onConfirm: () {
            ref.read(contactsProvider.notifier).delete(contact.id);
          });
        },
        onChangeTier: (newTier) {
          Navigator.pop(ctx);
          _biometricGate(context, ref, action: 'change tier', onConfirm: () {
            final err = ref.read(contactsProvider.notifier).update(
              contact.copyWith(tier: newTier),
            );
            if (err != null && context.mounted) {
              _showTierError(context, err);
            }
          });
        },
      ),
    );
  }

  void _biometricGate(
    BuildContext context,
    WidgetRef ref, {
    required String    action,
    required VoidCallback onConfirm,
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ZapColors.bgElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.fingerprint_rounded, color: ZapColors.info, size: 24),
            const SizedBox(width: ZapSpacing.sm),
            Text(
              'Verify identity',
              style: ZapTypography.headlineSmall.copyWith(
                color: ZapColors.textPrimary,
              ),
            ),
          ],
        ),
        content: Text(
          'Biometric confirmation required to $action this contact (LP18).',
          style: ZapTypography.bodyMedium.copyWith(
            color: ZapColors.textSecondary, height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: ZapTypography.labelMedium.copyWith(
                color: ZapColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            child: Text(
              'Confirm',
              style: ZapTypography.labelMedium.copyWith(color: ZapColors.info),
            ),
          ),
        ],
      ),
    );
  }

  void _showTierError(BuildContext context, ContactsError err) {
    final msg = err == ContactsError.tier1Full
        ? 'Tier 1 is full (max $kTier1Max contact). Remove the existing Tier 1 contact first.'
        : 'Tier 2 is full (max $kTier2Max contacts). Remove a Tier 2 contact first.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: ZapColors.bgElevated,
        behavior:        SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        content: Text(
          msg,
          style: ZapTypography.bodyMedium.copyWith(color: ZapColors.danger),
        ),
      ),
    );
  }
}

// ─── Options sheet ────────────────────────────────────────────────────────────

class _OptionsSheet extends StatelessWidget {
  const _OptionsSheet({
    required this.contact,
    required this.onEdit,
    required this.onDelete,
    required this.onChangeTier,
  });

  final Contact                contact;
  final VoidCallback           onEdit;
  final VoidCallback           onDelete;
  final void Function(int tier) onChangeTier;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        ZapSpacing.lg, ZapSpacing.md, ZapSpacing.lg, ZapSpacing.xxxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: ZapColors.border, borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: ZapSpacing.lg),
          Text(
            contact.name,
            style: ZapTypography.headlineSmall.copyWith(
              color: ZapColors.textPrimary,
            ),
          ),
          Text(
            contact.maskedPhone,
            style: ZapTypography.bodySmall.copyWith(
              color: ZapColors.textSecondary, fontFamily: 'IBMPlexMono',
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),

          _SheetAction(
            icon:    Icons.edit_outlined,
            label:   'Edit contact',
            color:   ZapColors.info,
            onTap:   onEdit,
          ),
          const SizedBox(height: ZapSpacing.sm),

          Text(
            'MOVE TO TIER',
            style: ZapTypography.labelSmall.copyWith(
              color: ZapColors.textMuted, letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: ZapSpacing.sm),
          Row(
            children: [1, 2, 3].map((t) {
              final isCurrent = contact.tier == t;
              final color     = t == 1
                  ? ZapColors.danger
                  : t == 2
                      ? ZapColors.warning
                      : ZapColors.info;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: OutlinedButton(
                    onPressed: isCurrent ? null : () => onChangeTier(t),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isCurrent ? ZapColors.textMuted : color,
                      side: BorderSide(
                        color: isCurrent
                            ? ZapColors.border
                            : color.withOpacity(0.5),
                      ),
                      backgroundColor: isCurrent
                          ? color.withOpacity(0.08)
                          : Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: ZapSpacing.sm),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text('Tier $t'),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: ZapSpacing.lg),

          _SheetAction(
            icon:    Icons.delete_outline_rounded,
            label:   'Delete contact',
            color:   ZapColors.danger,
            onTap:   onDelete,
          ),
        ],
      ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData     icon;
  final String       label;
  final Color        color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap:        onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: ZapSpacing.md),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: ZapSpacing.md),
            Text(
              label,
              style: ZapTypography.bodyMedium.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Batch action bar ─────────────────────────────────────────────────────────

class _BatchBar extends ConsumerWidget {
  const _BatchBar({required this.selected});
  final Set<String> selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color:   ZapColors.bgElevated,
      padding: EdgeInsets.fromLTRB(
        ZapSpacing.lg,
        ZapSpacing.md,
        ZapSpacing.lg,
        ZapSpacing.md + MediaQuery.of(context).padding.bottom,
      ),
      child: Row(
        children: [
          // Change tier
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _showBatchTierPicker(context, ref),
              icon:      const Icon(Icons.swap_vert_rounded, size: 16),
              label:     const Text('Change tier'),
              style: OutlinedButton.styleFrom(
                foregroundColor: ZapColors.info,
                side: const BorderSide(color: ZapColors.info, width: 0.8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(width: ZapSpacing.md),
          // Delete
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _confirmBatchDelete(context, ref),
              icon:      const Icon(Icons.delete_rounded, size: 16),
              label:     Text('Delete (${selected.length})'),
              style: ElevatedButton.styleFrom(
                backgroundColor: ZapColors.danger,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showBatchTierPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context:         context,
      backgroundColor: ZapColors.bgElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(
          ZapSpacing.lg, ZapSpacing.md, ZapSpacing.lg, ZapSpacing.xxxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: ZapColors.border, borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: ZapSpacing.lg),
            Text(
              'Move ${selected.length} contacts to tier',
              style: ZapTypography.headlineSmall.copyWith(
                color: ZapColors.textPrimary,
              ),
            ),
            const SizedBox(height: ZapSpacing.xl),
            ...([1, 2, 3].map((t) {
              final color = t == 1
                  ? ZapColors.danger
                  : t == 2 ? ZapColors.warning : ZapColors.info;
              final label = t == 1
                  ? 'Tier 1 · Primary (max $kTier1Max)'
                  : t == 2
                      ? 'Tier 2 · Escalation (max $kTier2Max)'
                      : 'Tier 3 · Broadcast';
              return Padding(
                padding: const EdgeInsets.only(bottom: ZapSpacing.sm),
                child: ListTile(
                  tileColor:    color.withOpacity(0.08),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side:         BorderSide(color: color.withOpacity(0.3)),
                  ),
                  leading: Icon(Icons.circle, size: 10, color: color),
                  title: Text(
                    label,
                    style: ZapTypography.bodyMedium.copyWith(color: color),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    final failed = ref
                        .read(contactsProvider.notifier)
                        .batchSetTier(Set.from(selected), t);
                    ref.read(batchModeProvider.notifier).state       = false;
                    ref.read(contactSelectionProvider.notifier).state = {};
                    if (failed.isNotEmpty && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: ZapColors.bgElevated,
                          behavior:        SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          content: Text(
                            '${failed.length} contact(s) could not be moved — tier limit reached.',
                            style: ZapTypography.bodyMedium.copyWith(
                              color: ZapColors.warning,
                            ),
                          ),
                        ),
                      );
                    }
                  },
                ),
              );
            })),
          ],
        ),
      ),
    );
  }

  void _confirmBatchDelete(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ZapColors.bgElevated,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete ${selected.length} contacts?',
          style: ZapTypography.headlineSmall.copyWith(
            color: ZapColors.textPrimary,
          ),
        ),
        content: Text(
          'This cannot be undone. These contacts will no longer receive SOS alerts.',
          style: ZapTypography.bodyMedium.copyWith(
            color: ZapColors.textSecondary, height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: ZapTypography.labelMedium.copyWith(
                color: ZapColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(contactsProvider.notifier).batchDelete(Set.from(selected));
              ref.read(batchModeProvider.notifier).state       = false;
              ref.read(contactSelectionProvider.notifier).state = {};
            },
            child: Text(
              'Delete',
              style: ZapTypography.labelMedium.copyWith(color: ZapColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Add / Edit contact sheet ─────────────────────────────────────────────────

class _ContactSheet extends ConsumerStatefulWidget {
  const _ContactSheet({required this.existing});
  final Contact? existing;

  @override
  ConsumerState<_ContactSheet> createState() => _ContactSheetState();
}

class _ContactSheetState extends ConsumerState<_ContactSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  late int  _tier;
  bool      _saving = false;
  String?   _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl  = TextEditingController(text: widget.existing?.name  ?? '');
    _phoneCtrl = TextEditingController(text: widget.existing?.phone ?? '');
    _tier      = widget.existing?.tier ?? 2;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final name  = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();

    if (name.isEmpty || phone.isEmpty) {
      setState(() => _error = 'Name and phone are required.');
      return;
    }

    setState(() { _saving = true; _error = null; });

    final notifier = ref.read(contactsProvider.notifier);
    ContactsError? err;

    if (_isEdit) {
      err = notifier.update(
        widget.existing!.copyWith(name: name, phone: phone, tier: _tier),
      );
    } else {
      err = notifier.add(name: name, phone: phone, tier: _tier);
    }

    if (err != null) {
      setState(() {
        _saving = false;
        _error  = err == ContactsError.tier1Full
            ? 'Tier 1 is full (max $kTier1Max).'
            : 'Tier 2 is full (max $kTier2Max).';
      });
      return;
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        ZapSpacing.lg,
        ZapSpacing.md,
        ZapSpacing.lg,
        ZapSpacing.lg + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize:      MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: ZapColors.border, borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: ZapSpacing.lg),
          Text(
            _isEdit ? 'Edit contact' : 'Add contact',
            style: ZapTypography.headlineSmall.copyWith(
              color: ZapColors.textPrimary,
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),

          _Field(ctrl: _nameCtrl,  label: 'Full name',     hint: 'e.g. Priya Sharma'),
          const SizedBox(height: ZapSpacing.md),
          _Field(ctrl: _phoneCtrl, label: 'Phone number',  hint: '+91 98765 43210',
              keyboardType: TextInputType.phone),

          const SizedBox(height: ZapSpacing.lg),
          Text(
            'TIER',
            style: ZapTypography.labelSmall.copyWith(
              color: ZapColors.textSecondary, letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: ZapSpacing.sm),
          Row(
            children: [1, 2, 3].map((t) {
              final active = _tier == t;
              final color  = t == 1
                  ? ZapColors.danger
                  : t == 2 ? ZapColors.warning : ZapColors.info;
              final caption = t == 1 ? 'max 1' : t == 2 ? 'max 5' : '∞';
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _tier = t),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    margin:  const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(vertical: ZapSpacing.sm),
                    decoration: BoxDecoration(
                      color: active ? color.withOpacity(0.15) : ZapColors.bgSurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: active ? color : ZapColors.border,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Tier $t',
                          style: ZapTypography.labelMedium.copyWith(
                            color:      active ? color : ZapColors.textSecondary,
                            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          caption,
                          style: ZapTypography.labelSmall.copyWith(
                            color:    active ? color.withOpacity(0.7) : ZapColors.textMuted,
                            fontSize: 9,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          if (_error != null) ...[
            const SizedBox(height: ZapSpacing.md),
            Text(
              _error!,
              style: ZapTypography.bodySmall.copyWith(color: ZapColors.danger),
            ),
          ],

          const SizedBox(height: ZapSpacing.xl),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: ZapColors.safe,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: ZapSpacing.md),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white,
                      ),
                    )
                  : Text(_isEdit ? 'Save changes' : 'Add contact'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.ctrl,
    required this.label,
    required this.hint,
    this.keyboardType,
  });

  final TextEditingController ctrl;
  final String                label;
  final String                hint;
  final TextInputType?        keyboardType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: ZapTypography.labelSmall.copyWith(
            color: ZapColors.textSecondary, letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: ZapSpacing.xs),
        TextField(
          controller:  ctrl,
          keyboardType: keyboardType,
          style: ZapTypography.bodyMedium.copyWith(color: ZapColors.textPrimary),
          cursorColor: ZapColors.info,
          decoration: InputDecoration(
            hintText:       hint,
            hintStyle:      ZapTypography.bodyMedium.copyWith(
              color: ZapColors.textMuted,
            ),
            filled:         true,
            fillColor:      ZapColors.bgSurface,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: ZapSpacing.md, vertical: ZapSpacing.md,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:   const BorderSide(color: ZapColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:   const BorderSide(color: ZapColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:   const BorderSide(color: ZapColors.info),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyContacts extends StatelessWidget {
  const _EmptyContacts();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.people_outline_rounded,
              size: 48, color: ZapColors.textMuted),
          const SizedBox(height: ZapSpacing.lg),
          Text(
            'No emergency contacts',
            style: ZapTypography.headlineSmall.copyWith(
              color: ZapColors.textSecondary,
            ),
          ),
          const SizedBox(height: ZapSpacing.sm),
          Text(
            'Add at least one Tier 1 contact\nso SOS alerts can be dispatched.',
            textAlign: TextAlign.center,
            style: ZapTypography.bodyMedium.copyWith(
              color: ZapColors.textMuted, height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Search bar ───────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.onChanged});
  final void Function(String) onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged:    onChanged,
      style: ZapTypography.bodyMedium.copyWith(color: ZapColors.textPrimary),
      cursorColor:  ZapColors.info,
      decoration: InputDecoration(
        hintText:       'Search contacts…',
        hintStyle:      ZapTypography.bodyMedium.copyWith(
          color: ZapColors.textMuted,
        ),
        prefixIcon:     const Icon(Icons.search_rounded,
            color: ZapColors.textMuted, size: 20),
        filled:         true,
        fillColor:      ZapColors.bgSurface,
        contentPadding: const EdgeInsets.symmetric(vertical: ZapSpacing.sm),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   const BorderSide(color: ZapColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   const BorderSide(color: ZapColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   const BorderSide(color: ZapColors.info),
        ),
      ),
    );
  }
}
