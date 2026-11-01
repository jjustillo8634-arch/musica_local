import 'dart:math';

import 'package:flutter/material.dart';

import 'theme.dart';

/// Tres barras animadas (como el indicador de "sonando" de Spotify).
class PlayingBars extends StatefulWidget {
  final double size;
  final Color color;
  const PlayingBars({super.key, this.size = 16, this.color = kRed});

  @override
  State<PlayingBars> createState() => _PlayingBarsState();
}

class _PlayingBarsState extends State<PlayingBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.size / 5;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          double h(double phase) =>
              widget.size * (0.25 + 0.75 * sin((_c.value + phase) * 2 * pi).abs());
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final phase in const [0.0, 0.33, 0.66])
                Container(
                  width: w,
                  height: h(phase),
                  decoration: BoxDecoration(
                    color: widget.color,
                    borderRadius: BorderRadius.circular(w / 2),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Gira su contenido como un disco de vinilo mientras [spinning] sea true.
class SpinningCover extends StatefulWidget {
  final bool spinning;
  final Widget child;
  const SpinningCover({super.key, required this.spinning, required this.child});

  @override
  State<SpinningCover> createState() => _SpinningCoverState();
}

class _SpinningCoverState extends State<SpinningCover>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 14),
  );

  @override
  void initState() {
    super.initState();
    if (widget.spinning) _c.repeat();
  }

  @override
  void didUpdateWidget(SpinningCover old) {
    super.didUpdateWidget(old);
    if (widget.spinning && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.spinning && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(turns: _c, child: widget.child);
  }
}
