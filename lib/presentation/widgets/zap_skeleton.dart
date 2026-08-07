/// ZapSafe skeleton loaders — Day 209
///
/// Shimmer placeholders for async data screens. Prefer over spinners
/// for list/card/chart layouts — shows structure while data loads.
library;

import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';

/// Base shimmer bone — building block for all skeleton layouts.
class ZapSkeletonBone extends StatefulWidget {
  final double? width;
  final double height;
  final double borderRadius;
  final BoxShape shape;

  const ZapSkeletonBone({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = 6,
    this.shape = BoxShape.rectangle,
  });

  const ZapSkeletonBone.circle({
    super.key,
    required double size,
  })  : width = size,
        height = size,
        borderRadius = 0,
        shape = BoxShape.circle;

  @override
  State<ZapSkeletonBone> createState() => _ZapSkeletonBoneState();
}

class _ZapSkeletonBoneState extends State<ZapSkeletonBone>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            shape: widget.shape,
            borderRadius: widget.shape == BoxShape.rectangle
                ? BorderRadius.circular(widget.borderRadius)
                : null,
            gradient: LinearGradient(
              begin: Alignment(-1 + t * 2, 0),
              end: Alignment(1 + t * 2, 0),
              colors: const [
                ZapColors.bgElevated,
                ZapColors.bgSurface,
                ZapColors.bgElevated,
              ],
              stops: const [0.25, 0.5, 0.75],
            ),
          ),
        );
      },
    );
  }
}

/// Standard list row skeleton (contacts, vault, audit log).
class ZapSkeletonListTile extends StatelessWidget {
  final bool showTrailing;

  const ZapSkeletonListTile({super.key, this.showTrailing = true});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading list item',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: ZapSpacing.sm),
        child: Row(
          children: [
            const ZapSkeletonBone.circle(size: 44),
            const SizedBox(width: ZapSpacing.md),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ZapSkeletonBone(width: double.infinity, height: 14),
                  SizedBox(height: ZapSpacing.sm),
                  ZapSkeletonBone(width: 120, height: 10),
                ],
              ),
            ),
            if (showTrailing) ...[
              const SizedBox(width: ZapSpacing.sm),
              const ZapSkeletonBone(width: 48, height: 24, borderRadius: 12),
            ],
          ],
        ),
      ),
    );
  }
}

/// Card block skeleton (settings, feature cards).
class ZapSkeletonCard extends StatelessWidget {
  final double height;

  const ZapSkeletonCard({super.key, this.height = 120});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading card',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
          color: ZapColors.bgCard,
          borderRadius: BorderRadius.circular(ZapSpacing.radius),
          border: Border.all(color: ZapColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const ZapSkeletonBone(width: 140, height: 14),
            const SizedBox(height: ZapSpacing.md),
            ZapSkeletonBone(width: double.infinity, height: height - 50),
          ],
        ),
      ),
    );
  }
}

/// Chart / score ring skeleton (Protection Score, history sparkline).
class ZapSkeletonChart extends StatelessWidget {
  final bool ring;

  const ZapSkeletonChart({super.key, this.ring = true});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading chart',
      child: Center(
        child: ring
            ? const ZapSkeletonBone.circle(size: 140)
            : const Column(
                children: [
                  ZapSkeletonBone(width: 280, height: 100, borderRadius: 8),
                  SizedBox(height: ZapSpacing.sm),
                  ZapSkeletonBone(width: 200, height: 10),
                ],
              ),
      ),
    );
  }
}

/// Contact row with tier badge placeholder.
class ZapSkeletonContactRow extends StatelessWidget {
  const ZapSkeletonContactRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading contact',
      child: Container(
        margin: const EdgeInsets.only(bottom: ZapSpacing.sm),
        padding: const EdgeInsets.all(ZapSpacing.md),
        decoration: BoxDecoration(
          color: ZapColors.bgCard,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ZapColors.border),
        ),
        child: const Row(
          children: [
            ZapSkeletonBone.circle(size: 48),
            SizedBox(width: ZapSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ZapSkeletonBone(width: 100, height: 14),
                  SizedBox(height: 6),
                  ZapSkeletonBone(width: 160, height: 10),
                ],
              ),
            ),
            ZapSkeletonBone(width: 36, height: 20, borderRadius: 4),
          ],
        ),
      ),
    );
  }
}

/// Dashboard header skeleton (mode card + SOS area).
class ZapSkeletonDashboard extends StatelessWidget {
  const ZapSkeletonDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading dashboard',
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(ZapSpacing.md),
            decoration: BoxDecoration(
              color: ZapColors.bgCard,
              borderRadius: BorderRadius.circular(ZapSpacing.radius),
              border: Border.all(color: ZapColors.border),
            ),
            child: const Row(
              children: [
                ZapSkeletonBone.circle(size: 40),
                SizedBox(width: ZapSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ZapSkeletonBone(width: 100, height: 12),
                      SizedBox(height: 6),
                      ZapSkeletonBone(width: double.infinity, height: 10),
                    ],
                  ),
                ),
                ZapSkeletonBone(width: 44, height: 28, borderRadius: 6),
              ],
            ),
          ),
          const SizedBox(height: ZapSpacing.xl),
          const ZapSkeletonBone.circle(size: 88),
          const SizedBox(height: ZapSpacing.md),
          const ZapSkeletonBone(width: 120, height: 10),
        ],
      ),
    );
  }
}

/// Chat message list skeleton.
class ZapSkeletonMessageList extends StatelessWidget {
  final int count;

  const ZapSkeletonMessageList({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading messages',
      child: Column(
        children: List.generate(count, (i) {
          final isUser = i.isOdd;
          return Padding(
            padding: const EdgeInsets.only(bottom: ZapSpacing.md),
            child: Align(
              alignment:
                  isUser ? Alignment.centerRight : Alignment.centerLeft,
              child: ZapSkeletonBone(
                width: isUser ? 180 : 220,
                height: isUser ? 44 : 56,
                borderRadius: 12,
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Full list of repeated list tiles.
class ZapSkeletonList extends StatelessWidget {
  final int count;
  final bool showTrailing;

  const ZapSkeletonList({
    super.key,
    this.count = 5,
    this.showTrailing = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        count,
        (_) => ZapSkeletonListTile(showTrailing: showTrailing),
      ),
    );
  }
}
