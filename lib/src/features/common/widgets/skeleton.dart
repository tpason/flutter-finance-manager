import 'package:flutter/material.dart';

class Skeleton extends StatefulWidget {
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final bool shimmer;
  final Color? baseColor;
  final Color? highlightColor;

  const Skeleton({
    super.key,
    this.width,
    this.height,
    this.borderRadius,
    this.shimmer = true,
    this.baseColor,
    this.highlightColor,
  });

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _shimmer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _shimmer = Tween<double>(begin: -1, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );
    if (widget.shimmer) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.baseColor ?? Colors.grey.shade300;
    final highlight = widget.highlightColor ?? Colors.grey.shade100;

    if (!widget.shimmer) {
      return Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: base,
          borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _shimmer,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: base,
            borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
          ),
          child: ClipRRect(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(color: base),
                ),
                Positioned.fill(
                  child: FractionalTranslation(
                    translation: Offset(_shimmer.value, 0),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            base.withOpacity(0.0),
                            highlight.withOpacity(0.8),
                            base.withOpacity(0.0),
                          ],
                          stops: const [0.25, 0.5, 0.75],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
