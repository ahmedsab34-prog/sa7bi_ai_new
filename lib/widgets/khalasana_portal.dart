import 'dart:math' as math;
import 'package:flutter/material.dart';

class KhalasanaPortal extends StatefulWidget {
  final VoidCallback onTap;

  const KhalasanaPortal({
    super.key,
    required this.onTap,
  });

  @override
  State<KhalasanaPortal> createState() => _KhalasanaPortalState();
}

class _KhalasanaPortalState extends State<KhalasanaPortal>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: controller,
        builder: (_, __) {
          final pulse =
              (math.sin(controller.value * math.pi * 2) + 1) / 2;

          return SizedBox(
            width: 94,
            height: 106,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 82,
                  height: 82,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6C63FF)
                            .withOpacity(0.12 + pulse * 0.08),
                        blurRadius: 25,
                        spreadRadius: 5,
                      ),
                      BoxShadow(
                        color: const Color(0xFFFFD76A)
                            .withOpacity(0.08 + pulse * 0.08),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                ),

                Transform.rotate(
                  angle: controller.value * math.pi * 2,
                  child: Container(
                    width: 79,
                    height: 79,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(
                        colors: [
                          Color(0xFFFFD76A),
                          Color(0xFF5BD9FF),
                          Color(0xFF8B5CF6),
                          Color(0xFF4CE0A6),
                          Color(0xFFFFD76A),
                        ],
                      ),
                    ),
                  ),
                ),

                Container(
                  width: 69,
                  height: 69,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF292C50),
                        Color(0xFF090B14),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white24,
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF090A13),
                          border: Border.all(
                            color: const Color(0xFFFFD76A),
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.chat_bubble_rounded,
                        color: Color(0xFFFFD76A),
                        size: 25,
                      ),
                      Positioned(
                        right: 12,
                        top: 12,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF63E6FF),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Positioned(
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xEE10101D),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0x66FFD76A),
                      ),
                    ),
                    child: const Text(
                      'خلصانة AI',
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        color: Color(0xFFFFD76A),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
