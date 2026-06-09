/// Day 94-95 — Payment Methods screen.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../domain/providers/payment_methods_providers.dart';

// ─── Root screen ──────────────────────────────────────────────────────────────

class Day94PaymentMethodsScreen extends ConsumerWidget {
  const Day94PaymentMethodsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(paymentMethodsProvider);

    return Scaffold(
      backgroundColor: ZapColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: ZapColors.bgPrimary,
        surfaceTintColor: Colors.transparent,
        title: const Text('Payment Methods',
            style: ZapTypography.headlineSmall),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 20, color: ZapColors.textPrimary),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: state.methods.isEmpty
                ? const _EmptyState()
                : ListView(
                    padding: const EdgeInsets.all(ZapSpacing.lg),
                    children: [
                      // ── Info banner ───────────────────────────
                      const _InfoBanner(),
                      const SizedBox(height: ZapSpacing.lg),

                      // ── Method list ───────────────────────────
                      Text('Saved methods',
                          style: ZapTypography.labelMedium
                              .copyWith(
                                  color: ZapColors.textSecondary)),
                      const SizedBox(height: ZapSpacing.md),
                      ...state.methods.map(
                        (m) => _MethodTile(
                          key: ValueKey(m.id),
                          method: m,
                          isRemoving:
                              state.removingIds.contains(m.id),
                        ),
                      ),
                      const SizedBox(height: ZapSpacing.xxl),
                    ],
                  ),
          ),

          // ── Add button ────────────────────────────────────────
          _AddBar(isSaving: state.isSaving),
        ],
      ),
    );
  }
}

// ─── Info banner ──────────────────────────────────────────────────────────────

class _InfoBanner extends StatelessWidget {
  const _InfoBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(ZapSpacing.md),
      decoration: BoxDecoration(
        color: ZapColors.info.withAlpha(13),
        borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
        border: Border.all(color: ZapColors.info.withAlpha(51)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_rounded, size: 14, color: ZapColors.info),
          const SizedBox(width: ZapSpacing.sm),
          Expanded(
            child: Text(
              'Cards are tokenised via Stripe — your full number is '
              'never stored on our servers.',
              style: ZapTypography.bodySmall
                  .copyWith(color: ZapColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Method tile ──────────────────────────────────────────────────────────────

class _MethodTile extends ConsumerStatefulWidget {
  const _MethodTile({
    super.key,
    required this.method,
    required this.isRemoving,
  });

  final PaymentMethod method;
  final bool          isRemoving;

  @override
  ConsumerState<_MethodTile> createState() => _MethodTileState();
}

class _MethodTileState extends ConsumerState<_MethodTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final m         = widget.method;
    final notifier  = ref.read(paymentMethodsProvider.notifier);
    final accentColor = m.type == PaymentMethodType.card
        ? (m.brand?.color ?? ZapColors.info)
        : ZapColors.safe;

    return Padding(
      padding: const EdgeInsets.only(bottom: ZapSpacing.md),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ZapSpacing.radius),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // left accent
              Container(width: 4, color: accentColor),

              // card body
              Expanded(
                child: Container(
                  color: ZapColors.bgCard,
                  child: Column(
                    children: [
                      // main row
                      InkWell(
                        onTap: () =>
                            setState(() => _expanded = !_expanded),
                        child: Padding(
                          padding: const EdgeInsets.all(ZapSpacing.lg),
                          child: Row(
                            children: [
                              // brand/type icon
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: accentColor.withAlpha(26),
                                  borderRadius:
                                      BorderRadius.circular(
                                          ZapSpacing.radiusSmall),
                                ),
                                child: Icon(
                                  m.type == PaymentMethodType.card
                                      ? (m.brand?.icon ??
                                          Icons.credit_card_rounded)
                                      : Icons.account_balance_rounded,
                                  size: 20,
                                  color: accentColor,
                                ),
                              ),
                              const SizedBox(width: ZapSpacing.md),

                              // title / subtitle
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(m.displayTitle,
                                              style: ZapTypography
                                                  .labelLarge
                                                  .copyWith(
                                                    color: ZapColors
                                                        .textPrimary,
                                                  )),
                                        ),
                                        if (m.isDefault) ...[
                                          const SizedBox(
                                              width: ZapSpacing.sm),
                                          _DefaultBadge(),
                                        ],
                                        if (m.isExpired) ...[
                                          const SizedBox(
                                              width: ZapSpacing.sm),
                                          _ExpiredBadge(),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(m.displaySubtitle,
                                        style: ZapTypography.bodySmall
                                            .copyWith(
                                              color: m.isExpired
                                                  ? ZapColors.danger
                                                  : ZapColors
                                                      .textSecondary,
                                            )),
                                  ],
                                ),
                              ),

                              // spinner or expand icon
                              if (widget.isRemoving)
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: ZapColors.danger,
                                  ),
                                )
                              else
                                Icon(
                                  _expanded
                                      ? Icons.keyboard_arrow_up_rounded
                                      : Icons.keyboard_arrow_down_rounded,
                                  size: 20,
                                  color: ZapColors.textSecondary,
                                ),
                            ],
                          ),
                        ),
                      ),

                      // expanded actions
                      if (_expanded && !widget.isRemoving) ...[
                        const Divider(
                            color: ZapColors.divider, height: 1),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                              ZapSpacing.lg,
                              ZapSpacing.sm,
                              ZapSpacing.lg,
                              ZapSpacing.sm),
                          child: Row(
                            children: [
                              // holder name for cards
                              if (m.type == PaymentMethodType.card &&
                                  m.holderName != null)
                                Expanded(
                                  child: Row(
                                    children: [
                                      const Icon(Icons.person_rounded,
                                          size: 14,
                                          color:
                                              ZapColors.textSecondary),
                                      const SizedBox(
                                          width: ZapSpacing.xs),
                                      Text(m.holderName!,
                                          style: ZapTypography.bodySmall
                                              .copyWith(
                                                  color: ZapColors
                                                      .textSecondary)),
                                    ],
                                  ),
                                )
                              else
                                const Expanded(child: SizedBox.shrink()),

                              // set default
                              if (!m.isDefault)
                                TextButton(
                                  onPressed: () =>
                                      notifier.setDefault(m.id),
                                  style: TextButton.styleFrom(
                                    visualDensity:
                                        VisualDensity.compact,
                                    padding:
                                        const EdgeInsets.symmetric(
                                      horizontal: ZapSpacing.sm,
                                      vertical: ZapSpacing.xs,
                                    ),
                                  ),
                                  child: Text('Set default',
                                      style: ZapTypography.labelSmall
                                          .copyWith(
                                              color: ZapColors.info)),
                                ),

                              const SizedBox(width: ZapSpacing.sm),

                              // remove
                              TextButton(
                                onPressed: () => _confirmRemove(
                                    context, notifier, m),
                                style: TextButton.styleFrom(
                                  visualDensity:
                                      VisualDensity.compact,
                                  padding:
                                      const EdgeInsets.symmetric(
                                    horizontal: ZapSpacing.sm,
                                    vertical: ZapSpacing.xs,
                                  ),
                                ),
                                child: Text('Remove',
                                    style: ZapTypography.labelSmall
                                        .copyWith(
                                            color: ZapColors.danger)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmRemove(
    BuildContext context,
    PaymentNotifier notifier,
    PaymentMethod m,
  ) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: ZapColors.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ZapSpacing.radius),
        ),
        title: Text('Remove ${m.displayTitle}?',
            style: ZapTypography.labelLarge
                .copyWith(color: ZapColors.textPrimary)),
        content: Text(
          m.isDefault
              ? 'This is your default payment method. '
                'The next card on file will become default.'
              : 'This payment method will be permanently removed.',
          style: ZapTypography.bodySmall
              .copyWith(color: ZapColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel',
                style: ZapTypography.labelMedium
                    .copyWith(color: ZapColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              notifier.removeMethod(m.id);
              setState(() => _expanded = false);
            },
            child: Text('Remove',
                style: ZapTypography.labelMedium
                    .copyWith(color: ZapColors.danger)),
          ),
        ],
      ),
    );
  }
}

class _DefaultBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: ZapSpacing.xs, vertical: 2),
      decoration: BoxDecoration(
        color: ZapColors.safe.withAlpha(26),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: ZapColors.safe.withAlpha(77)),
      ),
      child: Text('Default',
          style: ZapTypography.labelSmall
              .copyWith(color: ZapColors.safe, fontSize: 10)),
    );
  }
}

class _ExpiredBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: ZapSpacing.xs, vertical: 2),
      decoration: BoxDecoration(
        color: ZapColors.danger.withAlpha(26),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: ZapColors.danger.withAlpha(77)),
      ),
      child: Text('Expired',
          style: ZapTypography.labelSmall
              .copyWith(color: ZapColors.danger, fontSize: 10)),
    );
  }
}

// ─── Add button bar ───────────────────────────────────────────────────────────

class _AddBar extends StatelessWidget {
  const _AddBar({required this.isSaving});
  final bool isSaving;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: ZapColors.bgPrimary,
        border: Border(top: BorderSide(color: ZapColors.divider)),
      ),
      padding: EdgeInsets.fromLTRB(
        ZapSpacing.lg,
        ZapSpacing.md,
        ZapSpacing.lg,
        ZapSpacing.md + MediaQuery.of(context).padding.bottom,
      ),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: isSaving
              ? null
              : () => showModalBottomSheet<void>(
                    context: context,
                    backgroundColor: ZapColors.bgCard,
                    isScrollControlled: true,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                          top: Radius.circular(
                              ZapSpacing.radiusSmall)),
                    ),
                    builder: (_) => const _AddMethodSheet(),
                  ),
          style: FilledButton.styleFrom(
            backgroundColor: ZapColors.info,
            disabledBackgroundColor: ZapColors.bgElevated,
            padding:
                const EdgeInsets.symmetric(vertical: ZapSpacing.lg),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(ZapSpacing.radius),
            ),
          ),
          icon: const Icon(Icons.add_rounded, size: 20),
          label: Text('Add payment method',
              style: ZapTypography.labelLarge
                  .copyWith(color: Colors.white)),
        ),
      ),
    );
  }
}

// ─── Add method sheet ─────────────────────────────────────────────────────────

class _AddMethodSheet extends ConsumerStatefulWidget {
  const _AddMethodSheet();

  @override
  ConsumerState<_AddMethodSheet> createState() => _AddMethodSheetState();
}

class _AddMethodSheetState extends ConsumerState<_AddMethodSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = ref.watch(
        paymentMethodsProvider.select((s) => s.isSaving));
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // handle
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(
                top: ZapSpacing.md, bottom: ZapSpacing.sm),
            decoration: BoxDecoration(
              color: ZapColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // tab bar
          TabBar(
            controller: _tabs,
            indicatorColor: ZapColors.info,
            labelColor: ZapColors.textPrimary,
            unselectedLabelColor: ZapColors.textSecondary,
            dividerColor: ZapColors.divider,
            tabs: const [
              Tab(
                icon: Icon(Icons.credit_card_rounded, size: 18),
                text: 'Card',
              ),
              Tab(
                icon: Icon(Icons.account_balance_rounded, size: 18),
                text: 'UPI',
              ),
            ],
          ),

          // tab views — intrinsic height via IndexedStack
          IndexedStack(
            index: _tabs.index,
            children: [
              _CardForm(isSaving: isSaving),
              _UpiForm(isSaving: isSaving),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Card number formatter ────────────────────────────────────────────────────

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limited = digits.length > 16 ? digits.substring(0, 16) : digits;
    final buffer  = StringBuffer();
    for (var i = 0; i < limited.length; i++) {
      if (i > 0 && i % 4 == 0) {
        buffer.write(' ');
      }
      buffer.write(limited[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection:
          TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final limited = digits.length > 4 ? digits.substring(0, 4) : digits;
    final buffer  = StringBuffer();
    for (var i = 0; i < limited.length; i++) {
      if (i == 2) {
        buffer.write('/');
      }
      buffer.write(limited[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection:
          TextSelection.collapsed(offset: formatted.length),
    );
  }
}

// ─── Card form ────────────────────────────────────────────────────────────────

class _CardForm extends ConsumerStatefulWidget {
  const _CardForm({required this.isSaving});
  final bool isSaving;

  @override
  ConsumerState<_CardForm> createState() => _CardFormState();
}

class _CardFormState extends ConsumerState<_CardForm> {
  final _formKey    = GlobalKey<FormState>();
  final _nameCtrl   = TextEditingController();
  final _numberCtrl = TextEditingController();
  final _expiryCtrl = TextEditingController();
  final _cvvCtrl    = TextEditingController();
  bool _cvvObscured = true;
  CardBrand _detectedBrand = CardBrand.unknown;

  @override
  void initState() {
    super.initState();
    _numberCtrl.addListener(() {
      setState(() {
        _detectedBrand = detectBrand(_numberCtrl.text);
      });
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _numberCtrl.dispose();
    _expiryCtrl.dispose();
    _cvvCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final parts = _expiryCtrl.text.split('/');
    final month = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 0;
    final year  = int.tryParse(parts.length > 1 ? '20${parts[1]}' : '') ?? 0;

    final messenger = ScaffoldMessenger.of(context);
    await ref.read(paymentMethodsProvider.notifier).addCard(
      holderName:  _nameCtrl.text.trim(),
      number:      _numberCtrl.text,
      expiryMonth: month,
      expiryYear:  year,
    );
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Card added successfully'),
        backgroundColor: ZapColors.safe,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(ZapSpacing.xxl),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // cardholder name
            _FormField(
              controller: _nameCtrl,
              label: 'Cardholder name',
              hint: 'Full name as on card',
              icon: Icons.person_rounded,
              keyboardType: TextInputType.name,
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: ZapSpacing.md),

            // card number
            TextFormField(
              controller: _numberCtrl,
              style: ZapTypography.bodyMedium
                  .copyWith(color: ZapColors.textPrimary),
              keyboardType: TextInputType.number,
              inputFormatters: [_CardNumberFormatter()],
              decoration: _inputDecoration(
                label: 'Card number',
                hint: '1234 5678 9012 3456',
                prefixIcon: Icon(
                  _detectedBrand.icon,
                  size: 18,
                  color: _detectedBrand == CardBrand.unknown
                      ? ZapColors.textSecondary
                      : _detectedBrand.color,
                ),
                suffixIcon: _detectedBrand != CardBrand.unknown
                    ? Padding(
                        padding: const EdgeInsets.only(
                            right: ZapSpacing.md),
                        child: Text(_detectedBrand.label,
                            style: ZapTypography.labelSmall.copyWith(
                                color: _detectedBrand.color)),
                      )
                    : null,
              ),
              validator: (v) {
                final digits =
                    (v ?? '').replaceAll(' ', '');
                if (digits.length < 13) {
                  return 'Enter a valid card number';
                }
                return null;
              },
            ),
            const SizedBox(height: ZapSpacing.md),

            // expiry + CVV row
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _expiryCtrl,
                    style: ZapTypography.bodyMedium
                        .copyWith(color: ZapColors.textPrimary),
                    keyboardType: TextInputType.number,
                    inputFormatters: [_ExpiryFormatter()],
                    decoration: _inputDecoration(
                      label: 'Expiry',
                      hint: 'MM/YY',
                      prefixIcon: const Icon(
                          Icons.calendar_month_rounded,
                          size: 18,
                          color: ZapColors.textSecondary),
                    ),
                    validator: (v) {
                      if (v == null || !v.contains('/')) {
                        return 'MM/YY';
                      }
                      final p = v.split('/');
                      final m = int.tryParse(p[0]) ?? 0;
                      if (m < 1 || m > 12) {
                        return 'Invalid month';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: ZapSpacing.md),
                Expanded(
                  child: TextFormField(
                    controller: _cvvCtrl,
                    style: ZapTypography.bodyMedium
                        .copyWith(color: ZapColors.textPrimary),
                    keyboardType: TextInputType.number,
                    obscureText: _cvvObscured,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    decoration: _inputDecoration(
                      label: 'CVV',
                      hint: '•••',
                      prefixIcon: const Icon(Icons.lock_rounded,
                          size: 18,
                          color: ZapColors.textSecondary),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _cvvObscured
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          size: 18,
                          color: ZapColors.textSecondary,
                        ),
                        onPressed: () => setState(
                            () => _cvvObscured = !_cvvObscured),
                      ),
                    ),
                    validator: (v) =>
                        ((v?.length ?? 0) < 3) ? 'Invalid' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: ZapSpacing.xl),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed:
                    widget.isSaving ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: ZapColors.info,
                  disabledBackgroundColor: ZapColors.bgElevated,
                  padding: const EdgeInsets.symmetric(
                      vertical: ZapSpacing.lg),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(ZapSpacing.radius),
                  ),
                ),
                child: widget.isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white),
                      )
                    : Text('Save Card',
                        style: ZapTypography.labelLarge
                            .copyWith(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── UPI form ─────────────────────────────────────────────────────────────────

class _UpiForm extends ConsumerStatefulWidget {
  const _UpiForm({required this.isSaving});
  final bool isSaving;

  @override
  ConsumerState<_UpiForm> createState() => _UpiFormState();
}

class _UpiFormState extends ConsumerState<_UpiForm> {
  final _formKey = GlobalKey<FormState>();
  final _upiCtrl = TextEditingController();
  bool _verified = false;
  bool _verifying = false;

  @override
  void initState() {
    super.initState();
    _upiCtrl.addListener(() => setState(() => _verified = false));
  }

  @override
  void dispose() {
    _upiCtrl.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_upiCtrl.text.trim().isEmpty) {
      return;
    }
    setState(() => _verifying = true);
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (!mounted) {
      return;
    }
    setState(() {
      _verifying = false;
      _verified  = true;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(paymentMethodsProvider.notifier).addUpi(
          upiId: _upiCtrl.text.trim(),
        );
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
    messenger.showSnackBar(
      const SnackBar(
        content: Text('UPI ID added successfully'),
        backgroundColor: ZapColors.safe,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(ZapSpacing.xxl),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // UPI ID field
            TextFormField(
              controller: _upiCtrl,
              style: ZapTypography.bodyMedium
                  .copyWith(color: ZapColors.textPrimary),
              keyboardType: TextInputType.emailAddress,
              decoration: _inputDecoration(
                label: 'UPI ID',
                hint: 'yourname@upi',
                prefixIcon: const Icon(
                    Icons.account_balance_rounded,
                    size: 18,
                    color: ZapColors.textSecondary),
                suffixIcon: _verified
                    ? const Icon(Icons.check_circle_rounded,
                        size: 18, color: ZapColors.safe)
                    : null,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Enter a UPI ID';
                }
                if (!v.contains('@')) {
                  return 'UPI ID must contain @';
                }
                return null;
              },
            ),
            const SizedBox(height: ZapSpacing.md),

            // verify status
            if (_verified)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(ZapSpacing.sm),
                decoration: BoxDecoration(
                  color: ZapColors.safe.withAlpha(13),
                  borderRadius:
                      BorderRadius.circular(ZapSpacing.radiusSmall),
                  border: Border.all(
                      color: ZapColors.safe.withAlpha(51)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_rounded,
                        size: 14, color: ZapColors.safe),
                    const SizedBox(width: ZapSpacing.sm),
                    Text('UPI ID verified — account found',
                        style: ZapTypography.bodySmall
                            .copyWith(color: ZapColors.safe)),
                  ],
                ),
              ),
            const SizedBox(height: ZapSpacing.xl),

            Row(
              children: [
                // verify button
                Expanded(
                  child: OutlinedButton(
                    onPressed: (_verifying ||
                            widget.isSaving ||
                            _verified)
                        ? null
                        : _verify,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ZapColors.info,
                      side: const BorderSide(color: ZapColors.info),
                      padding: const EdgeInsets.symmetric(
                          vertical: ZapSpacing.md),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(ZapSpacing.radius),
                      ),
                    ),
                    child: _verifying
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: ZapColors.info),
                          )
                        : Text(
                            _verified ? 'Verified ✓' : 'Verify',
                            style: ZapTypography.labelLarge.copyWith(
                              color: _verified
                                  ? ZapColors.textMuted
                                  : ZapColors.info,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: ZapSpacing.md),

                // save button
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: (!_verified || widget.isSaving)
                        ? null
                        : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: ZapColors.safe,
                      disabledBackgroundColor: ZapColors.bgElevated,
                      padding: const EdgeInsets.symmetric(
                          vertical: ZapSpacing.md),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(ZapSpacing.radius),
                      ),
                    ),
                    child: widget.isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white),
                          )
                        : Text('Save UPI ID',
                            style: ZapTypography.labelLarge
                                .copyWith(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared form helpers ──────────────────────────────────────────────────────

InputDecoration _inputDecoration({
  required String  label,
  required String  hint,
  required Widget  prefixIcon,
  Widget?          suffixIcon,
}) {
  return InputDecoration(
    labelText: label,
    labelStyle: ZapTypography.bodySmall
        .copyWith(color: ZapColors.textSecondary),
    hintText: hint,
    hintStyle: ZapTypography.bodyMedium
        .copyWith(color: ZapColors.textMuted),
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: ZapColors.bgSurface,
    contentPadding: const EdgeInsets.symmetric(
        horizontal: ZapSpacing.md, vertical: ZapSpacing.md),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
      borderSide: const BorderSide(color: ZapColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
      borderSide: const BorderSide(color: ZapColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
      borderSide: const BorderSide(color: ZapColors.info),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
      borderSide: const BorderSide(color: ZapColors.danger),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(ZapSpacing.radiusSmall),
      borderSide: const BorderSide(color: ZapColors.danger),
    ),
  );
}

class _FormField extends StatelessWidget {
  const _FormField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.keyboardType,
    required this.validator,
    this.textCapitalization = TextCapitalization.none,
  });

  final TextEditingController controller;
  final String                label;
  final String                hint;
  final IconData              icon;
  final TextInputType         keyboardType;
  final String? Function(String?) validator;
  final TextCapitalization    textCapitalization;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      style: ZapTypography.bodyMedium
          .copyWith(color: ZapColors.textPrimary),
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      decoration: _inputDecoration(
        label: label,
        hint: hint,
        prefixIcon: Icon(icon,
            size: 18, color: ZapColors.textSecondary),
      ),
      validator: validator,
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.credit_card_off_rounded,
              size: 56, color: ZapColors.textMuted),
          const SizedBox(height: ZapSpacing.lg),
          Text('No payment methods',
              style: ZapTypography.labelLarge
                  .copyWith(color: ZapColors.textSecondary)),
          const SizedBox(height: ZapSpacing.sm),
          Text('Add a card or UPI ID to manage your subscription.',
              style: ZapTypography.bodySmall
                  .copyWith(color: ZapColors.textMuted),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
