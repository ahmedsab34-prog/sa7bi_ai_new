import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'service_config.dart';
import 'service_detail_screen.dart';

class CategoriesScreen extends StatelessWidget {
  final VoidCallback onAudio;

  const CategoriesScreen({
    super.key,
    required this.onAudio,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080A10),
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  4,
                ),
                child: _ServicesHeader(
                  onAudio: onAudio,
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                12,
                12,
                12,
                120,
              ),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final service =
                        sa7biServices[index];

                    return _GlassServiceCard(
                      service: service,
                      index: index,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ServiceDetailScreen(
                              service: service,
                            ),
                          ),
                        );
                      },
                    );
                  },
                  childCount:
                      sa7biServices.length,
                ),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.86,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// HEADER
// ============================================================

class _ServicesHeader extends StatelessWidget {
  final VoidCallback onAudio;

  const _ServicesHeader({
    required this.onAudio,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: onAudio,
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF141822),
                  border: Border.all(
                    color: const Color(0x4463E6FF),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x2263E6FF),
                      blurRadius: 15,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.graphic_eq_rounded,
                  color: Color(0xFF63E6FF),
                  size: 24,
                ),
              ),
            ),

            const SizedBox(width: 10),

            const Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.end,
                children: [
                  Text(
                    'خدمات صاحبي AI',
                    textDirection:
                        TextDirection.rtl,
                    textAlign:
                        TextAlign.right,
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'اختار المجال اللي محتاج صاحبي يساعدك فيه',
                    textDirection:
                        TextDirection.rtl,
                    textAlign:
                        TextAlign.right,
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 13),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 11,
          ),
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(18),
            gradient: const LinearGradient(
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
              colors: [
                Color(0xFF222031),
                Color(0xFF111722),
              ],
            ),
            border: Border.all(
              color: const Color(0x335EECFF),
            ),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                color: Color(0xFFFFD76A),
                size: 19,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'كل خدمة لها شخصية وسياق AI مختلف عشان الإجابة تكون مناسبة للمجال.',
                  textDirection:
                      TextDirection.rtl,
                  textAlign:
                      TextAlign.right,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================
// GLASS SERVICE CARD
// ============================================================

class _GlassServiceCard
    extends StatefulWidget {
  final Sa7biService service;
  final int index;
  final VoidCallback onTap;

  const _GlassServiceCard({
    required this.service,
    required this.index,
    required this.onTap,
  });

  @override
  State<_GlassServiceCard> createState() =>
      _GlassServiceCardState();
}

class _GlassServiceCardState
    extends State<_GlassServiceCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: Duration(
        seconds: 4 + (widget.index % 3),
      ),
    )..repeat();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.service;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final pulse =
            (math.sin(
                      controller.value *
                          math.pi *
                          2,
                    ) +
                    1) /
                2;

        return GestureDetector(
          onTap: widget.onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius:
                  BorderRadius.circular(25),
              gradient: LinearGradient(
                begin:
                    Alignment.topRight,
                end:
                    Alignment.bottomLeft,
                colors: [
                  service.color.withOpacity(
                    0.16 + pulse * 0.06,
                  ),
                  const Color(0xFF171A24),
                  const Color(0xFF0D1017),
                ],
              ),
              border: Border.all(
                color:
                    service.color.withOpacity(
                  0.24 + pulse * 0.10,
                ),
                width: 1.1,
              ),
              boxShadow: [
                BoxShadow(
                  color:
                      service.color.withOpacity(
                    0.05 + pulse * 0.05,
                  ),
                  blurRadius:
                      20 + pulse * 7,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius:
                  BorderRadius.circular(25),
              child: Stack(
                children: [
                  // Moving glass light
                  Positioned(
                    top: -35 +
                        (controller.value *
                                160) %
                            160,
                    left: -50 +
                        (controller.value *
                                90) %
                            120,
                    child: Transform.rotate(
                      angle: -0.35,
                      child: Container(
                        width: 95,
                        height: 150,
                        decoration:
                            BoxDecoration(
                          gradient:
                              LinearGradient(
                            colors: [
                              Colors.white
                                  .withOpacity(
                                0.00,
                              ),
                              Colors.white
                                  .withOpacity(
                                0.045,
                              ),
                              Colors.white
                                  .withOpacity(
                                0.00,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  Padding(
                    padding:
                        const EdgeInsets.all(11),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 27,
                              height: 27,
                              decoration:
                                  BoxDecoration(
                                shape:
                                    BoxShape.circle,
                                color: service
                                    .color
                                    .withOpacity(
                                  0.10,
                                ),
                                border:
                                    Border.all(
                                  color: service
                                      .color
                                      .withOpacity(
                                    0.20,
                                  ),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  '${widget.index + 1}',
                                  style:
                                      TextStyle(
                                    color:
                                        service.color,
                                    fontSize: 10,
                                    fontWeight:
                                        FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),

                            const Spacer(),

                            Icon(
                              Icons
                                  .arrow_forward_ios_rounded,
                              color:
                                  Colors.white38,
                              size: 12,
                            ),
                          ],
                        ),

                        const Spacer(),

                        // Main glass icon
                        Center(
                          child: Container(
                            width: 92,
                            height: 92,
                            decoration:
                                BoxDecoration(
                              shape:
                                  BoxShape.circle,
                              gradient:
                                  LinearGradient(
                                begin:
                                    Alignment.topLeft,
                                end:
                                    Alignment.bottomRight,
                                colors: [
                                  service.color
                                      .withOpacity(
                                    0.25,
                                  ),
                                  service.color
                                      .withOpacity(
                                    0.07,
                                  ),
                                  const Color(
                                    0xFF0E1118,
                                  ),
                                ],
                              ),
                              border:
                                  Border.all(
                                color: service
                                    .color
                                    .withOpacity(
                                  0.38 +
                                      pulse *
                                          0.10,
                                ),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: service
                                      .color
                                      .withOpacity(
                                    0.13 +
                                        pulse *
                                            0.08,
                                  ),
                                  blurRadius:
                                      25,
                                  spreadRadius:
                                      2,
                                ),
                              ],
                            ),
                            child: Stack(
                              alignment:
                                  Alignment.center,
                              children: [
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration:
                                      BoxDecoration(
                                    shape:
                                        BoxShape.circle,
                                    border:
                                        Border.all(
                                      color: Colors
                                          .white
                                          .withOpacity(
                                        0.06,
                                      ),
                                    ),
                                  ),
                                ),

                                Icon(
                                  service.icon,
                                  color:
                                      service.color,
                                  size: 42,
                                ),
                              ],
                            ),
                          ),
                        ),

                        const Spacer(),

                        Text(
                          service.title,
                          textDirection:
                              TextDirection.rtl,
                          textAlign:
                              TextAlign.right,
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight:
                                FontWeight.w900,
                          ),
                        ),

                        const SizedBox(
                          height: 4,
                        ),

                        Text(
                          service.description,
                          textDirection:
                              TextDirection.rtl,
                          textAlign:
                              TextAlign.right,
                          maxLines: 2,
                          overflow:
                              TextOverflow.ellipsis,
                          style:
                              const TextStyle(
                            color:
                                Colors.white54,
                            fontSize: 9.5,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
