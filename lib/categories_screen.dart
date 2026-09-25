import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'service_detail_screen.dart';
import 'service_config.dart';

class CategoriesScreen extends StatelessWidget {
  final VoidCallback onAudio;

  const CategoriesScreen({
    super.key,
    required this.onAudio,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFF070910),
      body: SafeArea(
        child: Column(
          children: [
            // ==================================================
            // TOP BAR
            // ==================================================

            Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                12,
                8,
                12,
                6,
              ),
              child: Row(
                children: [
                  _AudioButton(
                    onTap: onAudio,
                  ),
                  const Spacer(),
                  const Text(
                    'خدمات صاحبي',
                    textDirection:
                        TextDirection.rtl,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),

            // ==================================================
            // TEN SERVICES
            // ==================================================

            Expanded(
              child: LayoutBuilder(
                builder:
                    (
                  context,
                  constraints,
                ) {
                  final availableHeight =
                      constraints.maxHeight;

                  final rowHeight =
                      ((availableHeight - 18) / 5)
                          .clamp(
                            82.0,
                            118.0,
                          );

                  final cardHeight =
                      rowHeight - 4;

                  return Padding(
                    padding:
                        const EdgeInsets.fromLTRB(
                      10,
                      2,
                      10,
                      10,
                    ),
                    child:
                        GridView.builder(
                      physics:
                          const NeverScrollableScrollPhysics(),
                      padding:
                          EdgeInsets.zero,
                      itemCount:
                          sa7biServices.length,
                      gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 7,
                        mainAxisExtent:
                            cardHeight,
                      ),
                      itemBuilder:
                          (
                        context,
                        index,
                      ) {
                        final service =
                            sa7biServices[
                                index];

                        return _CompactServiceCard(
                          service: service,
                          index: index,
                          onTap: () {
                            // ==================================
                            // SERVICE DETAIL
                            // ==================================
                            //
                            // الخدمة تفتح الآن صفحتها
                            // الكاملة، ومنها:
                            // - الشات
                            // - الصوت
                            // - الكاميرا
                            // - الفيديو
                            // - الكلام إلى نص
                            // - إنشاء الصور
                            // - تعديل الصور
                            // - النص
                            //
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
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// AUDIO BUTTON
// ============================================================

class _AudioButton
    extends StatelessWidget {
  final VoidCallback onTap;

  const _AudioButton({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(16),
        child: Container(
          width: 43,
          height: 43,
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(16),
            gradient:
                const LinearGradient(
              begin:
                  Alignment.topLeft,
              end:
                  Alignment.bottomRight,
              colors: [
                Color(0xFF1C2533),
                Color(0xFF0E131D),
              ],
            ),
            border: Border.all(
              color:
                  const Color(0x4463E6FF),
            ),
            boxShadow: const [
              BoxShadow(
                color:
                    Color(0x1663E6FF),
                blurRadius: 16,
                spreadRadius: 1,
              ),
            ],
          ),
          child: const Icon(
            Icons.graphic_eq_rounded,
            color:
                Color(0xFF63E6FF),
            size: 22,
          ),
        ),
      ),
    );
  }
}

// ============================================================
// COMPACT GLASS SERVICE CARD
// ============================================================

class _CompactServiceCard
    extends StatefulWidget {
  final Sa7biService service;
  final int index;
  final VoidCallback onTap;

  const _CompactServiceCard({
    required this.service,
    required this.index,
    required this.onTap,
  });

  @override
  State<_CompactServiceCard>
      createState() =>
          _CompactServiceCardState();
}

class _CompactServiceCardState
    extends State<_CompactServiceCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController
      controller;

  @override
  void initState() {
    super.initState();

    controller =
        AnimationController(
      vsync: this,
      duration: Duration(
        seconds:
            4 + (widget.index % 3),
      ),
    )..repeat();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final service =
        widget.service;

    return AnimatedBuilder(
      animation: controller,
      builder:
          (
        context,
        child,
      ) {
        final pulse =
            (math.sin(
                      controller.value *
                          math.pi *
                          2,
                    ) +
                    1) /
                2;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius:
                BorderRadius.circular(19),
            child: Ink(
              decoration:
                  BoxDecoration(
                borderRadius:
                    BorderRadius.circular(
                  19,
                ),
                gradient:
                    LinearGradient(
                  begin:
                      Alignment.topRight,
                  end:
                      Alignment.bottomLeft,
                  colors: [
                    service.color
                        .withOpacity(
                      0.18 +
                          pulse * 0.045,
                    ),
                    const Color(
                      0xFF151923,
                    ),
                    const Color(
                      0xFF0C0F16,
                    ),
                  ],
                ),
                border: Border.all(
                  color: service.color
                      .withOpacity(
                    0.25 +
                        pulse * 0.08,
                  ),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: service.color
                        .withOpacity(
                      0.045 +
                          pulse * 0.035,
                    ),
                    blurRadius:
                        16 + pulse * 5,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius:
                    BorderRadius.circular(
                  19,
                ),
                child: Stack(
                  children: [
                    // ==========================================
                    // GLASS REFLECTION
                    // ==========================================

                    Positioned(
                      left:
                          -35 +
                              controller
                                      .value *
                                  150,
                      top: -20,
                      child:
                          Transform.rotate(
                        angle: -0.35,
                        child:
                            Container(
                          width: 42,
                          height: 150,
                          decoration:
                              BoxDecoration(
                            gradient:
                                LinearGradient(
                              colors: [
                                Colors.white
                                    .withOpacity(
                                  0,
                                ),
                                Colors.white
                                    .withOpacity(
                                  0.035,
                                ),
                                Colors.white
                                    .withOpacity(
                                  0,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // ==========================================
                    // SERVICE CONTENT
                    // ==========================================

                    Padding(
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      child: Row(
                        textDirection:
                            TextDirection.rtl,
                        children: [
                          Expanded(
                            child:
                                Column(
                              mainAxisAlignment:
                                  MainAxisAlignment
                                      .center,
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .end,
                              children: [
                                Text(
                                  service
                                      .title,
                                  textDirection:
                                      TextDirection
                                          .rtl,
                                  textAlign:
                                      TextAlign
                                          .right,
                                  maxLines: 1,
                                  overflow:
                                      TextOverflow
                                          .ellipsis,
                                  style:
                                      const TextStyle(
                                    color:
                                        Colors
                                            .white,
                                    fontSize:
                                        13,
                                    fontWeight:
                                        FontWeight
                                            .w900,
                                  ),
                                ),
                                const SizedBox(
                                  height: 3,
                                ),
                                Text(
                                  service
                                      .description,
                                  textDirection:
                                      TextDirection
                                          .rtl,
                                  textAlign:
                                      TextAlign
                                          .right,
                                  maxLines: 2,
                                  overflow:
                                      TextOverflow
                                          .ellipsis,
                                  style:
                                      const TextStyle(
                                    color:
                                        Colors
                                            .white54,
                                    fontSize:
                                        8.5,
                                    height:
                                        1.15,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(
                            width: 7,
                          ),

                          // ====================================
                          // SERVICE ICON
                          // ====================================

                          Container(
                            width: 51,
                            height: 51,
                            decoration:
                                BoxDecoration(
                              shape:
                                  BoxShape
                                      .circle,
                              gradient:
                                  LinearGradient(
                                begin:
                                    Alignment
                                        .topLeft,
                                end:
                                    Alignment
                                        .bottomRight,
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
                                    0xFF0D1119,
                                  ),
                                ],
                              ),
                              border:
                                  Border.all(
                                color: service
                                    .color
                                    .withOpacity(
                                  0.35 +
                                      pulse *
                                          0.08,
                                ),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: service
                                      .color
                                      .withOpacity(
                                    0.10 +
                                        pulse *
                                            0.05,
                                  ),
                                  blurRadius:
                                      14,
                                ),
                              ],
                            ),
                            child: Stack(
                              alignment:
                                  Alignment
                                      .center,
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration:
                                      BoxDecoration(
                                    shape:
                                        BoxShape
                                            .circle,
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
                                      service
                                          .color,
                                  size: 25,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ==========================================
                    // SERVICE NUMBER
                    // ==========================================

                    Positioned(
                      top: 5,
                      left: 6,
                      child: Container(
                        width: 20,
                        height: 20,
                        alignment:
                            Alignment.center,
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
                        child: Text(
                          '${widget.index + 1}',
                          style:
                              TextStyle(
                            color: service
                                .color,
                            fontSize: 8,
                            fontWeight:
                                FontWeight
                                    .w900,
                          ),
                        ),
                      ),
                    ),

                    // ==========================================
                    // ARROW
                    // ==========================================

                    const Positioned(
                      bottom: 6,
                      left: 8,
                      child: Icon(
                        Icons
                            .arrow_back_ios_rounded,
                        color:
                            Colors.white24,
                        size: 9,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
