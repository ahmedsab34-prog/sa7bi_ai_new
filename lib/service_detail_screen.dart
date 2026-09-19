import 'package:flutter/material.dart';

import 'chat_screen.dart';
import 'service_config.dart';

class ServiceDetailScreen extends StatelessWidget {
  final Sa7biService service;

  const ServiceDetailScreen({
    super.key,
    required this.service,
  });

  void _openChat(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          serviceTitle: service.title,
          serviceContext: service.aiRole,
        ),
      ),
    );
  }

  void _openImageAi(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          serviceTitle:
              '${service.title} — تحليل الصور',
          serviceContext:
              '${service.aiRole}\n'
              'ركز على تحليل الصور المرسلة من المستخدم '
              'وشرح الأشياء الظاهرة فيها بدقة، '
              'ولا تخمن ما لا يمكن رؤيته.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFF09090F),
      appBar: AppBar(
        backgroundColor:
            const Color(0xFF11111A),
        foregroundColor:
            Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          service.title,
          style: const TextStyle(
            fontWeight:
                FontWeight.w900,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.all(18),
          child: Column(
            children: [
              _buildHeader(),

              const SizedBox(
                height: 20,
              ),

              _buildMainButton(
                context,
                icon:
                    Icons.auto_awesome_rounded,
                title:
                    'تحدث مع صَحبي AI',
                subtitle:
                    'نص + صوت + صور + إنشاء صور',
                onTap: () =>
                    _openChat(context),
              ),

              const SizedBox(
                height: 12,
              ),

              _buildMainButton(
                context,
                icon:
                    Icons.camera_alt_rounded,
                title:
                    'حلل صورة بالكاميرا',
                subtitle:
                    'صوّر أي شيء واسأل صَحبي عنه',
                onTap: () =>
                    _openImageAi(context),
              ),

              const SizedBox(
                height: 12,
              ),

              _buildMainButton(
                context,
                icon:
                    Icons.photo_library_rounded,
                title:
                    'حلل صورة من الهاتف',
                subtitle:
                    'اختر صورة من المعرض ثم اسأل AI',
                onTap: () =>
                    _openImageAi(context),
              ),

              const SizedBox(
                height: 12,
              ),

              _buildMainButton(
                context,
                icon:
                    Icons.mic_rounded,
                title:
                    'تحدث بصوتك',
                subtitle:
                    'صَحبي يسمع كلامك ويرد عليك',
                onTap: () =>
                    _openChat(context),
              ),

              const SizedBox(
                height: 12,
              ),

              _buildMainButton(
                context,
                icon:
                    Icons.image_rounded,
                title:
                    'إنشاء صورة بالـAI',
                subtitle:
                    'اكتب وصف الصورة وسيتم إنشاؤها',
                onTap: () =>
                    _openChat(context),
              ),

              const SizedBox(
                height: 24,
              ),

              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.all(17),
                decoration:
                    BoxDecoration(
                  color:
                      const Color(
                    0xFF11111A,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    20,
                  ),
                  border: Border.all(
                    color: Colors.white
                        .withOpacity(
                      0.08,
                    ),
                  ),
                ),
                child: const Row(
                  textDirection:
                      TextDirection.rtl,
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color:
                          Color(0xFFFFD76A),
                    ),
                    SizedBox(
                      width: 10,
                    ),
                    Expanded(
                      child: Text(
                        'الفيديو موجود في واجهة القسم، لكن تحليل الفيديو نفسه سنضيفه بعد تثبيت تحليل الصور والصوت؛ لأننا لا نريد إدخال مكتبة فيديو قد تكسر نسخة Android الحالية.',
                        textDirection:
                            TextDirection.rtl,
                        style: TextStyle(
                          color:
                              Colors.white70,
                          height: 1.5,
                        ),
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
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(22),
      decoration:
          BoxDecoration(
        borderRadius:
            BorderRadius.circular(
          28,
        ),
        gradient:
            LinearGradient(
          colors: [
            service.color
                .withOpacity(0.30),
            const Color(
              0xFF171722,
            ),
          ],
          begin:
              Alignment.topRight,
          end:
              Alignment.bottomLeft,
        ),
        border:
            Border.all(
          color: service.color
              .withOpacity(0.35),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration:
                BoxDecoration(
              shape:
                  BoxShape.circle,
              color: service.color
                  .withOpacity(
                0.18,
              ),
              border:
                  Border.all(
                color: service.color
                    .withOpacity(
                  0.5,
                ),
                width: 2,
              ),
            ),
            child: Icon(
              service.icon,
              color:
                  service.color,
              size: 42,
            ),
          ),
          const SizedBox(
            height: 15,
          ),
          Text(
            service.title,
            textDirection:
                TextDirection.rtl,
            textAlign:
                TextAlign.center,
            style:
                const TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight:
                  FontWeight.w900,
            ),
          ),
          const SizedBox(
            height: 8,
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
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainButton(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color:
          const Color(0xFF15151F),
      borderRadius:
          BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding:
              const EdgeInsets.all(16),
          decoration:
              BoxDecoration(
            borderRadius:
                BorderRadius.circular(
              20,
            ),
            border: Border.all(
              color: Colors.white
                  .withOpacity(
                0.08,
              ),
            ),
          ),
          child: Row(
            textDirection:
                TextDirection.rtl,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration:
                    BoxDecoration(
                  shape:
                      BoxShape.circle,
                  color: service.color
                      .withOpacity(
                    0.14,
                  ),
                  border:
                      Border.all(
                    color: service.color
                        .withOpacity(
                      0.35,
                    ),
                  ),
                ),
                child: Icon(
                  icon,
                  color:
                      service.color,
                  size: 28,
                ),
              ),
              const SizedBox(
                width: 14,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .end,
                  children: [
                    Text(
                      title,
                      textDirection:
                          TextDirection
                              .rtl,
                      style:
                          const TextStyle(
                        color:
                            Colors.white,
                        fontSize: 17,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    Text(
                      subtitle,
                      textDirection:
                          TextDirection
                              .rtl,
                      style:
                          const TextStyle(
                        color:
                            Colors.white60,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_left_rounded,
                color:
                    Colors.white38,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
