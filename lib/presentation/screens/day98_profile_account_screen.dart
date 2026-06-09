// Day 98 — Profile & Account
//
// User card (avatar + name + phone + member since) · inline name editing ·
// Security (biometric toggle + active sessions with revoke) ·
// Storage (cache size + clear) · quick-link tiles ·
// Danger zone (sign-out confirm dialog).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/theme/spacing.dart';
import '../../domain/providers/profile_providers.dart';
import '../navigation/app_router.dart';

// ─── Screen ───────────────────────────────────────────────────────────────────

class Day98ProfileAccountScreen extends ConsumerWidget {
  const Day98ProfileAccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state    = ref.watch(profileProvider);
    final notifier = ref.read(profileProvider.notifier);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: ZapColors.bgPrimary,
        elevation: 0,
        title: Text(
          'Account',
          style: ZapTypography.headlineSmall.copyWith(
            color: ZapColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
            horizontal: ZapSpacing.lg, vertical: ZapSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── User card ─────────────────────────────────────────
            _UserCard(state: state, onEditTap: notifier.startEditName),
            const SizedBox(height: ZapSpacing.md),

            // ─── Inline name edit ──────────────────────────────────
            if (state.isEditingName) ...[
              _EditNameCard(state: state, notifier: notifier),
              const SizedBox(height: ZapSpacing.md),
            ],

            const SizedBox(height: ZapSpacing.sm),

            // ─── Security ─────────────────────────────────────────
            _SectionCard(
              icon:  Icons.security_rounded,
              title: 'Security',
              color: ZapColors.info,
              children: [
                _SwitchTile(
                  icon:     Icons.fingerprint_rounded,
                  label:    'Biometric Login',
                  subtitle: 'Face ID / Fingerprint unlock',
                  value:    state.biometricEnabled,
                  onToggle: notifier.toggleBiometric,
                ),
                const _Div(),
                _ActionTile(
                  icon:    Icons.pin_rounded,
                  label:   'Change PIN',
                  subtitle: '4-digit emergency access code',
                  trailing: const _ComingSoonChip(),
                  onTap:   () => _showChangePinInfo(context),
                ),
                const _Div(),
                _SessionsHeader(
                  count:      state.sessions.length,
                  expanded:   state.sessionsExpanded,
                  onToggle:   notifier.toggleSessionsExpanded,
                ),
                if (state.sessionsExpanded)
                  _SessionsList(state: state, notifier: notifier),
              ],
            ),
            const SizedBox(height: ZapSpacing.xl),

            // ─── Storage & Data ───────────────────────────────────
            _SectionCard(
              icon:  Icons.storage_rounded,
              title: 'Storage & Data',
              color: ZapColors.warning,
              children: [
                _CacheTile(state: state, notifier: notifier),
                const _Div(),
                _LinkTile(
                  icon:    Icons.file_download_rounded,
                  label:   'Export My Data',
                  subtitle: 'Download a full GDPR snapshot',
                  onTap:   () => context.go(AppRoutes.dataPrivacyV2),
                ),
                const _Div(),
                _LinkTile(
                  icon:    Icons.privacy_tip_rounded,
                  label:   'Privacy & Consent',
                  subtitle: 'Manage data processing preferences',
                  onTap:   () => context.go(AppRoutes.dataPrivacyV2),
                ),
              ],
            ),
            const SizedBox(height: ZapSpacing.xl),

            // ─── Quick links ───────────────────────────────────────
            _SectionCard(
              icon:  Icons.tune_rounded,
              title: 'Preferences',
              color: ZapColors.textSecondary,
              children: [
                _LinkTile(
                  icon:    Icons.language_rounded,
                  label:   'Language & Region',
                  subtitle: '15 languages · completeness bars',
                  onTap:   () => context.go(AppRoutes.languageSettings),
                ),
                const _Div(),
                _LinkTile(
                  icon:    Icons.accessibility_new_rounded,
                  label:   'Accessibility',
                  subtitle: 'Font size · colour · motion · haptics',
                  onTap:   () => context.go(AppRoutes.accessibilitySettings),
                ),
                const _Div(),
                _LinkTile(
                  icon:    Icons.notifications_rounded,
                  label:   'Notification Preferences',
                  subtitle: 'Per-category push & SMS controls',
                  onTap:   () => context.go(AppRoutes.notificationPrefs),
                ),
              ],
            ),
            const SizedBox(height: ZapSpacing.xl),

            // ─── Danger zone ───────────────────────────────────────
            _DangerZone(notifier: notifier),
            const SizedBox(height: ZapSpacing.xxxl),
          ],
        ),
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

void _showChangePinInfo(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: const Text(
          'PIN management launches with full biometric gate in Day 100'),
      backgroundColor: ZapColors.bgElevated,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall)),
    ),
  );
}

Future<void> _confirmSignOut(
    BuildContext context, ProfileNotifier notifier) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: ZapColors.bgCard,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ZapSpacing.radius)),
      title: Text('Sign Out?',
          style: ZapTypography.headlineSmall
              .copyWith(color: ZapColors.textPrimary, fontWeight: FontWeight.w700)),
      content: Text(
        'You will need to re-verify your phone number to sign back in.',
        style: ZapTypography.bodyMedium
            .copyWith(color: ZapColors.textSecondary, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text('Cancel',
              style: ZapTypography.labelMedium
                  .copyWith(color: ZapColors.textSecondary)),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text('Sign Out',
              style: ZapTypography.labelMedium.copyWith(
                  color: ZapColors.danger, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
  if (ok == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Signed out successfully'),
        backgroundColor: ZapColors.bgElevated,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall)),
      ),
    );
  }
}

// ─── User card ────────────────────────────────────────────────────────────────

class _UserCard extends StatelessWidget {
  const _UserCard({required this.state, required this.onEditTap});

  final ProfileState state;
  final VoidCallback onEditTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(ZapSpacing.xl),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A2744), Color(0xFF0D1B38)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: ZapColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [ZapColors.info, ZapColors.info.withOpacity(0.5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                      color: ZapColors.info.withOpacity(0.4), width: 2),
                ),
                child: Center(
                  child: Text(
                    state.initials,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: ZapSpacing.lg),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.displayName,
                      style: ZapTypography.headlineSmall.copyWith(
                        color: ZapColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      state.phone,
                      style: ZapTypography.bodyMedium.copyWith(
                        color: ZapColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.verified_rounded,
                            size: 12, color: ZapColors.safe),
                        const SizedBox(width: 4),
                        Text(
                          'Member since ${state.memberSinceLabel}',
                          style: ZapTypography.bodySmall.copyWith(
                            color: ZapColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: ZapSpacing.lg),
          // Edit name button
          if (!state.isEditingName)
            OutlinedButton.icon(
              onPressed: onEditTap,
              icon: const Icon(Icons.edit_rounded, size: 14),
              label: const Text('Edit Display Name'),
              style: OutlinedButton.styleFrom(
                foregroundColor: ZapColors.textSecondary,
                side: BorderSide(
                    color: ZapColors.border.withOpacity(0.7), width: 1),
                padding: const EdgeInsets.symmetric(
                    horizontal: ZapSpacing.md, vertical: ZapSpacing.sm),
                textStyle: ZapTypography.labelMedium,
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Edit name card ───────────────────────────────────────────────────────────

class _EditNameCard extends ConsumerStatefulWidget {
  const _EditNameCard({required this.state, required this.notifier});

  final ProfileState    state;
  final ProfileNotifier notifier;

  @override
  ConsumerState<_EditNameCard> createState() => _EditNameCardState();
}

class _EditNameCardState extends ConsumerState<_EditNameCard> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.state.pendingName);
    _ctrl.selection = TextSelection.fromPosition(
      TextPosition(offset: _ctrl.text.length),
    );
    _ctrl.addListener(
      () => widget.notifier.updatePendingName(_ctrl.text),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(profileProvider);
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.lg),
      decoration: BoxDecoration(
        color: ZapColors.bgCard,
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        border: Border.all(color: ZapColors.info.withOpacity(0.4), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Edit Display Name',
              style: ZapTypography.labelLarge
                  .copyWith(color: ZapColors.textPrimary)),
          const SizedBox(height: ZapSpacing.md),
          TextField(
            controller: _ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            style: ZapTypography.bodyMedium
                .copyWith(color: ZapColors.textPrimary),
            cursorColor: ZapColors.info,
            decoration: InputDecoration(
              hintText: 'Your display name',
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
                borderSide:
                    const BorderSide(color: ZapColors.info, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: ZapSpacing.md, vertical: ZapSpacing.md),
            ),
          ),
          const SizedBox(height: ZapSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: s.isSavingName ? null : widget.notifier.cancelEditName,
                child: Text('Cancel',
                    style: ZapTypography.labelMedium
                        .copyWith(color: ZapColors.textSecondary)),
              ),
              const SizedBox(width: ZapSpacing.sm),
              FilledButton(
                onPressed: (s.isSavePending && !s.isSavingName)
                    ? widget.notifier.saveName
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: ZapColors.info,
                  disabledBackgroundColor: ZapColors.bgElevated,
                ),
                child: s.isSavingName
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text('Save',
                        style: ZapTypography.labelMedium
                            .copyWith(color: Colors.white)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Section card ─────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.children,
  });

  final IconData     icon;
  final String       title;
  final Color        color;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: ZapSpacing.xs),
            Text(
              title.toUpperCase(),
              style: ZapTypography.labelSmall.copyWith(
                color: color,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: ZapSpacing.md),
            const Expanded(child: Divider(color: ZapColors.border)),
          ],
        ),
        const SizedBox(height: ZapSpacing.sm),
        Container(
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
            border: Border.all(color: ZapColors.border, width: 1),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _Div extends StatelessWidget {
  const _Div();

  @override
  Widget build(BuildContext context) =>
      const Divider(color: ZapColors.divider, height: 1, indent: 52);
}

// ─── Tile variants ────────────────────────────────────────────────────────────

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onToggle,
  });

  final IconData     icon;
  final String       label;
  final String       subtitle;
  final bool         value;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(ZapSpacing.radius),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: ZapSpacing.lg, vertical: ZapSpacing.md),
        child: Row(
          children: [
            Icon(icon,
                size: 20,
                color: value ? ZapColors.info : ZapColors.textMuted),
            const SizedBox(width: ZapSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: ZapTypography.labelLarge
                          .copyWith(color: ZapColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: ZapTypography.bodySmall
                          .copyWith(color: ZapColors.textSecondary)),
                ],
              ),
            ),
            Switch(
              value: value,
              onChanged: (_) => onToggle(),
              activeColor: ZapColors.info,
              activeTrackColor: ZapColors.info.withOpacity(0.3),
              inactiveThumbColor: ZapColors.textMuted,
              inactiveTrackColor: ZapColors.bgElevated,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final IconData  icon;
  final String    label;
  final String    subtitle;
  final VoidCallback onTap;
  final Widget?   trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ZapSpacing.radius),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: ZapSpacing.lg, vertical: ZapSpacing.md),
        child: Row(
          children: [
            Icon(icon, size: 20, color: ZapColors.textMuted),
            const SizedBox(width: ZapSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: ZapTypography.labelLarge
                          .copyWith(color: ZapColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: ZapTypography.bodySmall
                          .copyWith(color: ZapColors.textSecondary)),
                ],
              ),
            ),
            if (trailing != null) trailing!,
            const SizedBox(width: ZapSpacing.sm),
            const Icon(Icons.chevron_right,
                size: 18, color: ZapColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  final IconData     icon;
  final String       label;
  final String       subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ZapSpacing.radius),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: ZapSpacing.lg, vertical: ZapSpacing.md),
        child: Row(
          children: [
            Icon(icon, size: 20, color: ZapColors.textMuted),
            const SizedBox(width: ZapSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: ZapTypography.labelLarge
                          .copyWith(color: ZapColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: ZapTypography.bodySmall
                          .copyWith(color: ZapColors.textSecondary)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                size: 18, color: ZapColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _ComingSoonChip extends StatelessWidget {
  const _ComingSoonChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: ZapColors.warning.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border:
            Border.all(color: ZapColors.warning.withOpacity(0.4), width: 1),
      ),
      child: Text(
        'Day 100',
        style: ZapTypography.labelSmall.copyWith(
          fontSize: 9,
          color: ZapColors.warning,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ─── Sessions header ──────────────────────────────────────────────────────────

class _SessionsHeader extends StatelessWidget {
  const _SessionsHeader({
    required this.count,
    required this.expanded,
    required this.onToggle,
  });

  final int          count;
  final bool         expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(ZapSpacing.radius),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: ZapSpacing.lg, vertical: ZapSpacing.md),
        child: Row(
          children: [
            const Icon(Icons.devices_rounded,
                size: 20, color: ZapColors.textMuted),
            const SizedBox(width: ZapSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Active Sessions',
                      style: ZapTypography.labelLarge
                          .copyWith(color: ZapColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text('$count device${count == 1 ? '' : 's'} logged in',
                      style: ZapTypography.bodySmall
                          .copyWith(color: ZapColors.textSecondary)),
                ],
              ),
            ),
            Icon(
              expanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              size: 20,
              color: ZapColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Sessions list ────────────────────────────────────────────────────────────

class _SessionsList extends ConsumerWidget {
  const _SessionsList({required this.state, required this.notifier});

  final ProfileState    state;
  final ProfileNotifier notifier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: state.sessions.map((s) {
        final revoking = state.revokingIds.contains(s.id);
        final platformIcon = s.platform == 'ios'
            ? Icons.phone_iphone_rounded
            : s.platform == 'web'
                ? Icons.computer_rounded
                : Icons.phone_android_rounded;

        return Column(
          children: [
            const Divider(color: ZapColors.divider, height: 1, indent: 52),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: ZapSpacing.lg, vertical: ZapSpacing.sm),
              child: Row(
                children: [
                  // platform icon in a tinted circle
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: s.isCurrent
                          ? ZapColors.safe.withOpacity(0.15)
                          : ZapColors.bgElevated,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      platformIcon,
                      size: 16,
                      color:
                          s.isCurrent ? ZapColors.safe : ZapColors.textMuted,
                    ),
                  ),
                  const SizedBox(width: ZapSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                s.device,
                                style: ZapTypography.labelMedium.copyWith(
                                    color: ZapColors.textPrimary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (s.isCurrent) ...[
                              const SizedBox(width: ZapSpacing.xs),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: ZapColors.safe.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'This device',
                                  style: ZapTypography.labelSmall.copyWith(
                                    fontSize: 9,
                                    color: ZapColors.safe,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${s.location} · ${s.lastSeen}',
                          style: ZapTypography.bodySmall
                              .copyWith(color: ZapColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  if (!s.isCurrent)
                    revoking
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: ZapColors.danger,
                            ),
                          )
                        : TextButton(
                            onPressed: () => notifier.revokeSession(s.id),
                            style: TextButton.styleFrom(
                              foregroundColor: ZapColors.danger,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: ZapSpacing.sm),
                              minimumSize: Size.zero,
                              tapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text('Revoke',
                                style: ZapTypography.labelSmall.copyWith(
                                    color: ZapColors.danger)),
                          ),
                ],
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

// ─── Cache tile ───────────────────────────────────────────────────────────────

class _CacheTile extends StatelessWidget {
  const _CacheTile({required this.state, required this.notifier});

  final ProfileState    state;
  final ProfileNotifier notifier;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: ZapSpacing.lg, vertical: ZapSpacing.md),
      child: Row(
        children: [
          const Icon(Icons.storage_rounded, size: 20, color: ZapColors.textMuted),
          const SizedBox(width: ZapSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('App Cache',
                    style: ZapTypography.labelLarge
                        .copyWith(color: ZapColors.textPrimary)),
                const SizedBox(height: 2),
                Text(state.cacheSizeLabel,
                    style: ZapTypography.bodySmall
                        .copyWith(color: ZapColors.textSecondary)),
              ],
            ),
          ),
          state.isClearingCache
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.8,
                    color: ZapColors.warning,
                  ),
                )
              : TextButton(
                  onPressed: state.cacheMb <= 0 ? null : notifier.clearCache,
                  style: TextButton.styleFrom(
                    foregroundColor: ZapColors.warning,
                    padding: const EdgeInsets.symmetric(
                        horizontal: ZapSpacing.sm),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    state.cacheMb <= 0 ? 'Cleared' : 'Clear',
                    style: ZapTypography.labelSmall.copyWith(
                      color: state.cacheMb <= 0
                          ? ZapColors.textMuted
                          : ZapColors.warning,
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

// ─── Danger zone ──────────────────────────────────────────────────────────────

class _DangerZone extends StatelessWidget {
  const _DangerZone({required this.notifier});

  final ProfileNotifier notifier;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                size: 13, color: ZapColors.danger),
            const SizedBox(width: ZapSpacing.xs),
            Text(
              'DANGER ZONE',
              style: ZapTypography.labelSmall.copyWith(
                color: ZapColors.danger,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: ZapSpacing.md),
            const Expanded(child: Divider(color: ZapColors.border)),
          ],
        ),
        const SizedBox(height: ZapSpacing.sm),
        Container(
          decoration: BoxDecoration(
            color: ZapColors.bgCard,
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
            border: Border.all(
                color: ZapColors.danger.withOpacity(0.3), width: 1),
          ),
          child: InkWell(
            onTap: () => _confirmSignOut(context, notifier),
            borderRadius: BorderRadius.circular(ZapSpacing.radius),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: ZapSpacing.lg, vertical: ZapSpacing.lg),
              child: Row(
                children: [
                  Icon(Icons.logout_rounded,
                      size: 20,
                      color: ZapColors.danger.withOpacity(0.8)),
                  const SizedBox(width: ZapSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sign Out',
                            style: ZapTypography.labelLarge.copyWith(
                                color: ZapColors.danger,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(
                          'Remove this device from your account',
                          style: ZapTypography.bodySmall
                              .copyWith(color: ZapColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right,
                      size: 18,
                      color: ZapColors.danger.withOpacity(0.6)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: ZapSpacing.sm),
        Center(
          child: TextButton(
            onPressed: () => context.go(AppRoutes.dataPrivacyV2),
            child: Text(
              'Delete Account',
              style: ZapTypography.labelSmall.copyWith(
                color: ZapColors.textMuted,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
