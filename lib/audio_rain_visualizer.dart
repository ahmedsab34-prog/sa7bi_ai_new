// ============================================================
// FILE: lib/audio_rain_visualizer.dart
// ============================================================
//
// مؤشر صوت مستقل.
// ============================================================

import 'package:flutter/material.dart';

class AudioRainVisualizer extends StatefulWidget {
  const AudioRainVisualizer({
    super.key,
  });

  @override
  State<AudioRainVisualizer> createState() =>
      _AudioRainVisualizerState();
}

class _AudioRainVisualizerState
    extends State<AudioRainVisualizer>
    with SingleTickerProviderStateMixin {
  static const Color _gold =
      Color(0xFFE6C875);

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 1100,
      ),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return SizedBox(
      width: 42,
      height: 34,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceEvenly,
            crossAxisAlignment:
                CrossAxisAlignment.end,
            children: List.generate(
              7,
              (index) {
                final phase =
                    (_controller.value +
                            index * 0.13) %
                        1.0;

                final height =
                    7.0 + (phase * 20.0);

                return Container(
                  width: 3,
                  height: height,
                  decoration: BoxDecoration(
                    color: Color.lerp(
                      Colors.white54,
                      _gold,
                      phase,
                    ),
                    borderRadius:
                        BorderRadius.circular(8),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
