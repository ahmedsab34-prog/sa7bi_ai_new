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
      appBar: AppBar(
        backgroundColor: const Color(0xFF11141D),
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'خدمات صاحبي AI',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'صوت صاحبي',
            onPressed: onAudio,
            icon: const Icon(
              Icons.graphic_eq_rounded,
              color: Color(0xFF63E6FF),
            ),
          ),
        ],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.fromLTRB(
          12,
          14,
          12,
          120,
        ),
        itemCount: sa7biServices.length,
        gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.93,
        ),
        itemBuilder: (context, index) {
          final service = sa7biServices[index];

          return _ServiceCard(
            service: service,
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
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final Sa7biService service;
  final VoidCallback onTap;

  const _ServiceCard({
    required this.service,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(22),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                service.color
                    .withOpacity(0.22),
                const Color(0xFF121620),
                const Color(0xFF0D1018),
              ],
            ),
            border: Border.all(
              color: service.color
                  .withOpacity(0.32),
            ),
            boxShadow: [
              BoxShadow(
                color: service.color
                    .withOpacity(0.08),
                blurRadius: 15,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Padding(
            padding:
                const EdgeInsets.all(11),
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration:
                      BoxDecoration(
                    shape: BoxShape.circle,
                    gradient:
                        LinearGradient(
                      begin:
                          Alignment.topLeft,
                      end:
                          Alignment.bottomRight,
                      colors: [
                        service.color,
                        service.color
                            .withOpacity(
                          0.48,
                        ),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: service.color
                            .withOpacity(
                          0.20,
                        ),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: Icon(
                    service.icon,
                    color: Colors.black,
                    size: 31,
                  ),
                ),

                const SizedBox(height: 9),

                Text(
                  service.title,
                  textDirection:
                      TextDirection.rtl,
                  textAlign:
                      TextAlign.center,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  service.description,
                  textDirection:
                      TextDirection.rtl,
                  textAlign:
                      TextAlign.center,
                  maxLines: 2,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                    height: 1.25,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  'تحدث مع صاحبي',
                  textDirection:
                      TextDirection.rtl,
                  style: TextStyle(
                    color: service.color,
                    fontSize: 10,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
