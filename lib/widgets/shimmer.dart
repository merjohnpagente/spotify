import 'package:flutter/material.dart';

import 'package:spotify_fy/theme.dart';

/// A shimmering skeleton placeholder shown while content loads.
///
/// Use [ShimmerBox] for generic blocks (grids, cards) and [ShimmerTile]
/// for list rows. Both animate a diagonal highlight sweep.
class Shimmer extends StatefulWidget {
  final Widget child;

  const Shimmer({super.key, required this.child});

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reducedMotion) return widget.child;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final dx = (bounds.width + bounds.height) * _controller.value;
            return LinearGradient(
              begin: Alignment(-1 - bounds.height / bounds.width, -1),
              end: Alignment(1 + bounds.height / bounds.width, 1),
              colors: const [
                Color(0xFF3A3A3A),
                Color(0xFF4A4A4A),
                Color(0xFF3A3A3A),
              ],
              stops: const [0.35, 0.5, 0.65],
              transform: _SlideTransform(dx),
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}

class _SlideTransform extends GradientTransform {
  final double dx;

  const _SlideTransform(this.dx);

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(-dx, 0, 0);
  }
}

/// A rectangular shimmering block (grid/card placeholder).
class ShimmerBox extends StatelessWidget {
  final double? width;
  final double height;
  final BorderRadius? borderRadius;

  const ShimmerBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: SpotifyColors.cardBackground,
          borderRadius: borderRadius ?? BorderRadius.circular(8),
        ),
      ),
    );
  }
}

/// A shimmering list row (thumbnail + two text lines).
class ShimmerTile extends StatelessWidget {
  final double imageSize;

  const ShimmerTile({super.key, this.imageSize = 56});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          ShimmerBox(
            width: imageSize,
            height: imageSize,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(height: 14, borderRadius: BorderRadius.circular(4)),
                const SizedBox(height: 8),
                ShimmerBox(
                  width: 120,
                  height: 12,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A column of shimmering list rows (generic screen loading state).
class ShimmerList extends StatelessWidget {
  final int count;

  const ShimmerList({super.key, this.count = 6});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      itemBuilder: (context, index) => const ShimmerTile(),
    );
  }
}
