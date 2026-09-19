import 'package:flutter/material.dart';

import 'chat_screen.dart';

class KhalasanaPortalScreen
    extends StatelessWidget {
  const KhalasanaPortalScreen({
    super.key,
  });

  void _openChat(
    BuildContext context, {
    required String title,
    required String prompt,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          serviceTitle: title,
          serviceContext: prompt,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFF080814),
      appBar: AppBar(
        backgroundColor:
            const Color(0xFF080814),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'خلصانة AI',
          style: TextStyle(
            color:
                Color(0xFFFFD76A),
            fontWeight:
                FontWeight.w900,
          ),
        ),
        leading:
            IconButton(
          icon: const Icon(
            Icons
                .arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () =>
              Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.fromLTRB(
            18,
            12,
            18,
            28,
          ),
          child: Column(
            children: [
              Container(
                padding:
                    const EdgeInsets.all(
                  22,
                ),
                decoration:
                    BoxDecoration(
                  borderRadius:
                      BorderRadius.circular(
                    28,
                  ),
                  gradient:
                      const LinearGradient(
                    colors: [
                      Color(0xFF1E1B45),
                      Color(0xFF0E1022),
                    ],
                  ),
                  border:
                      Border.all(
                    color:
                        const Color(
                      0xFFFFD76A,
                    ),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color:
                          Color(0x446C63FF),
                      blurRadius: 28,
                    ),
                  ],
                ),
                child: const Column(
                  children: [
                    Text(
                      '✨',
                      style:
                          TextStyle(
                        fontSize: 42,
                      ),
                    ),
                    SizedBox(
                      height: 8,
                    ),
                    Text(
                      'أهلاً بيك في خلصانة AI',
                      textDirection:
                          TextDirection.rtl,
                      textAlign:
                          TextAlign.center,
                      style:
                          TextStyle(
                        color:
                            Colors.white,
                        fontSize: 22,
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),
                    SizedBox(
                      height: 8,
                    ),
                    Text(
                      'قول بس عايز إيه… والباقي علينا.',
                      textDirection:
                          TextDirection.rtl,
                      textAlign:
                          TextAlign.center,
                      style:
                          TextStyle(
                        color:
                            Colors.white70,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                height: 22,
              ),

              Container(
                padding:
                    const EdgeInsets.all(
                  16,
                ),
                decoration:
                    BoxDecoration(
                  color: Colors.white
                      .withOpacity(
                    0.07,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    22,
                  ),
                  border:
                      Border.all(
                    color: Colors.white
                        .withOpacity(
                      0.12,
                    ),
                  ),
                ),
                child:
                    _CommandButton(
                  onTap: () =>
                      _openChat(
                    context,
                    title:
                        'خلصانة AI',
                    prompt:
                        'أنت مساعد شامل داخل خلصانة AI. '
                        'افهم طلب المستخدم وحدد أفضل طريقة لمساعدته. '
                        'إذا كان يحتاج صورة فاقترح استخدام إنشاء الصور، '
                        'وإذا كان يحتاج تحليل صورة فاطلب منه إرسالها.',
                  ),
                ),
              ),

              const SizedBox(
                height: 24,
              ),

              const Align(
                alignment:
                    Alignment.centerRight,
                child: Text(
                  'اختار بسرعة',
                  textDirection:
                      TextDirection.rtl,
                  style: TextStyle(
                    color:
                        Colors.white,
                    fontSize: 19,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
              ),

              const SizedBox(
                height: 14,
              ),

              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics:
                    const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio:
                    1.25,
                children: [
                  _PortalAction(
                    icon:
                        Icons.psychology_alt_rounded,
                    title:
                        'اسأل AI',
                    subtitle:
                        'أي سؤال',
                    onTap: () =>
                        _openChat(
                      context,
                      title:
                          'اسأل صَحبي AI',
                      prompt:
                          'أجب عن أسئلة المستخدم بوضوح وبالعربية.',
                    ),
                  ),
                  _PortalAction(
                    icon:
                        Icons.search_rounded,
                    title:
                        'بحث',
                    subtitle:
                        'مساعدة وبحث',
                    onTap: () =>
                        _openChat(
                      context,
                      title:
                          'البحث',
                      prompt:
                          'ساعد المستخدم في صياغة وفهم طلب البحث، '
                          'ولا تدّعي أنك بحثت في الويب إذا لم يتم تشغيل أداة ويب.',
                    ),
                  ),
                  _PortalAction(
                    icon:
                        Icons.school_rounded,
                    title:
                        'ذاكر',
                    subtitle:
                        'شرح وتلخيص',
                    onTap: () =>
                        _openChat(
                      context,
                      title:
                          'المذاكرة',
                      prompt:
                          'أنت مدرس شخصي. اشرح وبسط وراجع واختبر المستخدم.',
                    ),
                  ),
                  _PortalAction(
                    icon:
                        Icons.newspaper_rounded,
                    title:
                        'أخبار',
                    subtitle:
                        'مساعد الأخبار',
                    onTap: () =>
                        _openChat(
                      context,
                      title:
                          'الأخبار',
                      prompt:
                          'ساعد المستخدم في فهم الأخبار وصياغة أسئلة عنها، '
                          'ولا تدّعي معرفة خبر لحظي دون مصدر مباشر.',
                    ),
                  ),
                  _PortalAction(
                    icon:
                        Icons.sports_soccer_rounded,
                    title:
                        'رياضة',
                    subtitle:
                        'رياضة ومعلومات',
                    onTap: () =>
                        _openChat(
                      context,
                      title:
                          'الرياضة',
                      prompt:
                          'أنت مساعد رياضي. ساعد المستخدم في المعلومات والتحليل والأسئلة الرياضية.',
                    ),
                  ),
                  _PortalAction(
                    icon:
                        Icons.movie_rounded,
                    title:
                        'أفلام',
                    subtitle:
                        'اقتراحات ومعلومات',
                    onTap: () =>
                        _openChat(
                      context,
                      title:
                          'الأفلام',
                      prompt:
                          'ساعد المستخدم في الأفلام والمسلسلات والمحتوى بطريقة مفيدة.',
                    ),
                  ),
                  _PortalAction(
                    icon:
                        Icons.image_rounded,
                    title:
                        'صور',
                    subtitle:
                        'إنشاء صور AI',
                    onTap: () =>
                        _openChat(
                      context,
                      title:
                          'إنشاء الصور',
                      prompt:
                          'ساعد المستخدم على إنشاء صور بالذكاء الاصطناعي.',
                    ),
                  ),
                  _PortalAction(
                    icon:
                        Icons.shopping_bag_rounded,
                    title:
                        'منتجات',
                    subtitle:
                        'مقارنة ومساعدة',
                    onTap: () =>
                        _openChat(
                      context,
                      title:
                          'المنتجات',
                      prompt:
                          'ساعد المستخدم في فهم المنتجات ومقارنة المواصفات.',
                    ),
                  ),
                  _PortalAction(
                    icon:
                        Icons.mic_rounded,
                    title:
                        'صوت',
                    subtitle:
                        'اتكلم مع AI',
                    onTap: () =>
                        _openChat(
                      context,
                      title:
                          'صوت',
                      prompt:
                          'تحدث مع المستخدم من خلال التعرف على صوته والرد عليه.',
                    ),
                  ),
                  _PortalAction(
                    icon:
                        Icons.auto_awesome_rounded,
                    title:
                        'اعمل أي حاجة',
                    subtitle:
                        'المساعد الشامل',
                    onTap: () =>
                        _openChat(
                      context,
                      title:
                          'خلصانة AI',
                      prompt:
                          'أنت المساعد الشامل. افهم ما يريده المستخدم وساعده بأفضل طريقة ممكنة.',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommandButton
    extends StatelessWidget {
  final VoidCallback onTap;

  const _CommandButton({
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius:
          BorderRadius.circular(16),
      child: const Padding(
        padding:
            EdgeInsets.symmetric(
          vertical: 8,
        ),
        child: Row(
          textDirection:
              TextDirection.rtl,
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              color:
                  Color(0xFFFFD76A),
            ),
            SizedBox(
              width: 10,
            ),
            Expanded(
              child: Text(
                'قول لخلصانة تعمل إيه؟',
                textDirection:
                    TextDirection.rtl,
                style: TextStyle(
                  color:
                      Colors.white70,
                  fontSize: 16,
                ),
              ),
            ),
            Icon(
              Icons.arrow_upward_rounded,
              color:
                  Color(0xFFFFD76A),
            ),
          ],
        ),
      ),
    );
  }
}

class _PortalAction
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _PortalAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(22),
        child: Ink(
          decoration:
              BoxDecoration(
            borderRadius:
                BorderRadius.circular(
              22,
            ),
            gradient:
                LinearGradient(
              colors: [
                Colors.white
                    .withOpacity(
                  0.10,
                ),
                Colors.white
                    .withOpacity(
                  0.035,
                ),
              ],
            ),
            border:
                Border.all(
              color: Colors.white
                  .withOpacity(
                0.10,
              ),
            ),
          ),
          child: Padding(
            padding:
                const EdgeInsets.all(
              14,
            ),
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment
                      .center,
              children: [
                Icon(
                  icon,
                  color:
                      const Color(
                    0xFFFFD76A,
                  ),
                  size: 30,
                ),
                const SizedBox(
                  height: 8,
                ),
                Text(
                  title,
                  textDirection:
                      TextDirection.rtl,
                  textAlign:
                      TextAlign.center,
                  style:
                      const TextStyle(
                    color:
                        Colors.white,
                    fontWeight:
                        FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(
                  height: 3,
                ),
                Text(
                  subtitle,
                  textDirection:
                      TextDirection.rtl,
                  textAlign:
                      TextAlign.center,
                  maxLines: 2,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    color:
                        Colors.white54,
                    fontSize: 11,
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
