// ============================================================
// FILE: lib/audio_rain_visualizer.dart
// ============================================================

import 'package:flutter/material.dart';

import 'audio_player_service.dart';

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
  static const Color _blue = Color(0xFF398BFF);
  static const Color _cyan = Color(0xFF32D7E8);

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    AudioController.isPlayingNotifier.addListener(
      _handlePlaybackChanged,
    );

    _handlePlaybackChanged();
  }

  void _handlePlaybackChanged() {
    if (!mounted) return;

    if (AudioController.isPlayingNotifier.value) {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    AudioController.isPlayingNotifier.removeListener(
      _handlePlaybackChanged,
    );

    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AudioController.isPlayingNotifier,
      builder: (context, isPlaying, _) {
        return SizedBox(
          width: 42,
          height: 34,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(
                  7,
                  (index) {
                    final phase = isPlaying
                        ? (_controller.value + index * 0.13) % 1.0
                        : 0.0;

                    final height = isPlaying
                        ? 7.0 + (phase * 20.0)
                        : 5.0;

                    return Container(
                      width: 3,
                      height: height,
                      decoration: BoxDecoration(
                        color: isPlaying
                            ? Color.lerp(_blue, _cyan, phase)
                            : Colors.white24,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: isPlaying
                            ? [
                                BoxShadow(
                                  color: _cyan.withValues(alpha: 0.25),
                                  blurRadius: 5,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                    );
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }
}
