import 'package:flutter/material.dart';

// Text followed by dots that appear one at a time and start over ("Testing", "Testing.", "Testing..", "Testing..."),
// so the player can see something is happening while they wait.
//
// The dots that have not appeared yet still take up their space (invisibly), so the text does not jump around as
// the dots come and go. If the phone is set to reduce motion, the dots are shown all at once and nothing moves.
class AnimatedEllipsis extends StatefulWidget {
  final String text;
  final TextStyle? style;

  // how many dots there are, and how long each step of the animation lasts
  final int dots;
  final Duration stepDuration;

  const AnimatedEllipsis(
    this.text, {
    super.key,
    this.style,
    this.dots = 3,
    this.stepDuration = const Duration(milliseconds: 400),
  });

  @override
  State<AnimatedEllipsis> createState() => _AnimatedEllipsisState();
}

class _AnimatedEllipsisState extends State<AnimatedEllipsis> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _reduceMotion = false;

  // 0 dots, then 1, 2, ... up to all of them, then round again
  int get _steps => widget.dots + 1;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.stepDuration * _steps);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (_reduceMotion) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
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
    final style = widget.style ?? DefaultTextStyle.of(context).style;

    // Screen readers should hear one "Testing", not the dots being typed out.
    return Semantics(
      label: widget.text,
      excludeSemantics: true,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final visible = _reduceMotion ? widget.dots : (_controller.value * _steps).floor().clamp(0, widget.dots);
          return Text.rich(
            TextSpan(
              style: style,
              children: [
                TextSpan(text: widget.text),
                TextSpan(text: '.' * visible),
                // the dots still to come: present but invisible, so the width stays the same
                TextSpan(text: '.' * (widget.dots - visible), style: const TextStyle(color: Colors.transparent)),
              ],
            ),
          );
        },
      ),
    );
  }
}
