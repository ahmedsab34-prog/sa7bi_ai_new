import 'package:flutter/material.dart';

import 'chat_screen.dart';
import 'service_config.dart';

class ServiceDetailScreen
    extends StatelessWidget {
  final Sa7biService service;

  const ServiceDetailScreen({
    super.key,
    required this.service,
  });

  void _openChat(
    BuildContext context,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ChatScreen(
          serviceTitle:
              service.title,
          serviceContext:
              service.aiRole,
        ),
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          const Color(0xFF080A10),
      appBar: AppBar(
        backgroundColor:
            const Color(0xFF10131C),
        foregroundColor:
            Colors.white,
        centerTitle: true,
        title: Text(
          service.title,
          style:
              const TextStyle(
            fontWeight:
                FontWeight.w900,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding:
              const EdgeInsets.all(18),
          child: Column(
            children: [
              Expanded(
                child:
                    _ServiceIntro(
                  service:
                      service,
                ),
              ),

              SizedBox(
                width:
                    double.infinity,
                child:
                    FilledButton.icon(
                  onPressed:
                      () => _openChat(
                    context,
                  ),
                  icon:
                      const Icon(
                    Icons
                        .auto_awesome_rounded,
                  ),
                  label:
                      const Text(
                    'تحدث مع صاحبي',
                    style:
                        TextStyle(
                      fontSize: 17,
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),
                  style:
                      FilledButton.styleFrom(
                    backgroundColor:
                        service.color,
                    foregroundColor:
                        Colors.black,
                    padding:
                        const EdgeInsets
                            .symmetric(
                      vertical: 16,
                    ),
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius
                              .circular(
                        18,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(
                height: 10,
              ),

              const Text(
                'داخل المحادثة تقدر تكتب، تتكلم، تصور، تبعت صورة، أو تطلب إنشاء صورة.',
                textDirection:
                    TextDirection.rtl,
                textAlign:
                    TextAlign.center,
                style:
                    TextStyle(
                  color:
                      Colors.white54,
                  height: 1.4,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceIntro
    extends StatelessWidget {
  final Sa7biService service;

  const _ServiceIntro({
    required this.service,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Center(
      child: Container(
        width:
            double.infinity,
        padding:
            const EdgeInsets.all(25),
        decoration:
            BoxDecoration(
          borderRadius:
              BorderRadius.circular(30),
          gradient:
              LinearGradient(
            begin:
                Alignment.topRight,
            end:
                Alignment.bottomLeft,
            colors: [
              service.color
                  .withOpacity(
                0.28,
              ),
              const Color(
                0xFF11141D,
              ),
              const Color(
                0xFF090C13,
              ),
            ],
          ),
          border:
              Border.all(
            color: service.color
                .withOpacity(
              0.35,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: service.color
                  .withOpacity(
                0.10,
              ),
              blurRadius: 30,
            ),
          ],
        ),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration:
                  BoxDecoration(
                shape:
                    BoxShape.circle,
                color:
                    service.color
                        .withOpacity(
                  0.15,
                ),
                border:
                    Border.all(
                  color:
                      service.color
                          .withOpacity(
                    0.55,
                  ),
                  width: 2,
                ),
              ),
              child:
                  Icon(
                service.icon,
                color:
                    service.color,
                size: 43,
              ),
            ),

            const SizedBox(
              height: 18,
            ),

            Text(
              service.title,
              textDirection:
                  TextDirection.rtl,
              textAlign:
                  TextAlign.center,
              style:
                  const TextStyle(
                color:
                    Colors.white,
                fontSize: 26,
                fontWeight:
                    FontWeight.w900,
              ),
            ),

            const SizedBox(
              height: 10,
            ),

            Text(
              service.description,
              textDirection:
                  TextDirection.rtl,
              textAlign:
                  TextAlign.center,
              style:
                  const TextStyle(
                color:
                    Colors.white70,
                fontSize: 15,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
