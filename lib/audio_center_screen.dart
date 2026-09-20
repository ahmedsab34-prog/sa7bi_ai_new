import 'package:audio_service/audio_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'audio_player_service.dart';

class AudioCenterScreen extends StatefulWidget {
const AudioCenterScreen({
super.key,
});

@override
State<AudioCenterScreen> createState() =>
_AudioCenterScreenState();
}

class _AudioCenterScreenState
extends State<AudioCenterScreen> {
bool loading = true;

Sa7biAudioHandler? handler;

@override
void initState() {
super.initState();
_init();
}

Future<void> _init() async {
try {
final result =
await AudioController.initialize();

  if (!mounted) {
    return;
  }

  setState(() {
    handler = result;
    loading = false;
  });
} catch (e) {
  if (!mounted) {
    return;
  }

  setState(() {
    loading = false;
  });

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        'تعذر تشغيل المشغل الصوتي: $e',
        textDirection:
            TextDirection.rtl,
      ),
    ),
  );
}

}

Future<void> _pickLocalAudio() async {
final file =
await FilePicker.pickFile(
type: FileType.audio,
);

if (file == null) {
  return;
}

final path = file.path;

if (path == null ||
    path.isEmpty) {
  if (!mounted) {
    return;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text(
        'لم يتم العثور على مسار الملف.',
        textDirection:
            TextDirection.rtl,
      ),
    ),
  );

  return;
}

final localHandler = handler;

if (localHandler == null) {
  return;
}

try {
  await localHandler.playLocalFile(
    path: path,
    title: file.name,
  );
} catch (e) {
  if (!mounted) {
    return;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        'تعذر تشغيل الملف: $e',
        textDirection:
            TextDirection.rtl,
      ),
    ),
  );
}

}

Future<void> _openUrlDialog() async {
final controller =
TextEditingController();

final result =
    await showDialog<Map<String, String>>(
  context: context,
  builder: (context) {
    return AlertDialog(
      backgroundColor:
          const Color(0xFF171A24),
      title: const Text(
        'تشغيل رابط صوتي أو راديو',
        textDirection:
            TextDirection.rtl,
      ),
      content: Column(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          TextField(
            controller:
                controller,
            keyboardType:
                TextInputType.url,
            textDirection:
                TextDirection.ltr,
            decoration:
                const InputDecoration(
              hintText:
                  'https://example.com/audio.mp3',
              labelText:
                  'رابط الصوت',
            ),
          ),
          const SizedBox(
            height: 10,
          ),
          const Text(
            'يمكن أن يكون ملف صوت أو بث راديو مباشر.',
            textDirection:
                TextDirection.rtl,
            style: TextStyle(
              color:
                  Colors.white60,
              fontSize: 12,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(
              context,
            );
          },
          child:
              const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () {
            final url =
                controller.text.trim();

            if (url.isEmpty) {
              return;
            }

            Navigator.pop(
              context,
              {
                'url': url,
                'title':
                    'صوت من الإنترنت',
              },
            );
          },
          child:
              const Text('تشغيل'),
        ),
      ],
    );
  },
);

controller.dispose();

if (result == null) {
  return;
}

final localHandler = handler;

if (localHandler == null) {
  return;
}

try {
  await localHandler.playUrl(
    url: result['url']!,
    title: result['title']!,
    artist: 'إنترنت / راديو',
  );
} catch (e) {
  if (!mounted) {
    return;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        'تعذر تشغيل الرابط: $e',
        textDirection:
            TextDirection.rtl,
      ),
    ),
  );
}

}

@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor:
const Color(0xFF080A10),
appBar: AppBar(
backgroundColor:
Colors.transparent,
title: const Text(
'المشغل الصوتي',
textDirection:
TextDirection.rtl,
style: TextStyle(
fontWeight:
FontWeight.w900,
),
),
centerTitle: true,
),
body: loading
? const Center(
child:
CircularProgressIndicator(),
)
: handler == null
? const Center(
child: Text(
'تعذر تشغيل مشغل الصوت.',
textDirection:
TextDirection.rtl,
),
)
: ListView(
padding:
const EdgeInsets.fromLTRB(
16,
12,
16,
30,
),
children: [
const _AudioHero(),
const SizedBox(
height: 16,
),
_AudioAction(
icon:
Icons.menu_book_rounded,
title:
'القرآن الكريم',
subtitle:
'تشغيل التلاوات والقرّاء',
onTap:
_openUrlDialog,
),
_AudioAction(
icon:
Icons.auto_awesome_rounded,
title:
'الأذكار',
subtitle:
'تشغيل أصوات الأذكار',
onTap:
_openUrlDialog,
),
_AudioAction(
icon:
Icons.radio_rounded,
title:
'الراديو والبث المباشر',
subtitle:
'أدخل رابط محطة أو بث مباشر',
onTap:
_openUrlDialog,
),
_AudioAction(
icon:
Icons.music_note_rounded,
title:
'الموسيقى',
subtitle:
'تشغيل روابط الصوت',
onTap:
_openUrlDialog,
),
_AudioAction(
icon:
Icons.podcasts_rounded,
title:
'البودكاست',
subtitle:
'تشغيل الحلقات الصوتية',
onTap:
_openUrlDialog,
),
_AudioAction(
icon:
Icons.folder_rounded,
title:
'ملفات الهاتف',
subtitle:
'اختيار ملف صوت من الجهاز',
onTap:
_pickLocalAudio,
),
const SizedBox(
height: 20,
),
const Text(
'أثناء التشغيل يمكنك ترك التطبيق أو إطفاء الشاشة، والتحكم من إشعار الصوت.',
textDirection:
TextDirection.rtl,
textAlign:
TextAlign.center,
style: TextStyle(
color:
Colors.white54,
height: 1.5,
),
),
],
),
);
}
}

class _AudioHero
extends StatelessWidget {
const _AudioHero();

@override
Widget build(BuildContext context) {
return Container(
padding:
const EdgeInsets.all(22),
decoration:
BoxDecoration(
borderRadius:
BorderRadius.circular(28),
gradient:
const LinearGradient(
begin:
Alignment.topRight,
end:
Alignment.bottomLeft,
colors: [
Color(0xFF30210A),
Color(0xFF151827),
Color(0xFF10131C),
],
),
border: Border.all(
color:
const Color(0x55FFD76A),
),
),
child:
const Column(
children: [
Icon(
Icons.graphic_eq_rounded,
size: 54,
color:
Color(0xFFFFD76A),
),
SizedBox(
height: 10,
),
Text(
'صوت صاحبي',
textDirection:
TextDirection.rtl,
style: TextStyle(
fontSize: 27,
fontWeight:
FontWeight.w900,
),
),
SizedBox(
height: 7,
),
Text(
'صوتك معاك في كل مكان',
textDirection:
TextDirection.rtl,
style: TextStyle(
color:
Colors.white60,
),
),
],
),
);
}
}

class _AudioAction
extends StatelessWidget {
final IconData icon;
final String title;
final String subtitle;
final VoidCallback onTap;

const _AudioAction({
required this.icon,
required this.title,
required this.subtitle,
required this.onTap,
});

@override
Widget build(BuildContext context) {
return Container(
margin:
const EdgeInsets.only(
bottom: 10,
),
decoration:
BoxDecoration(
color:
const Color(0xFF121620),
borderRadius:
BorderRadius.circular(20),
border: Border.all(
color:
Colors.white10,
),
),
child: ListTile(
onTap: onTap,
contentPadding:
const EdgeInsets.symmetric(
horizontal: 15,
vertical: 7,
),
leading: Container(
width: 50,
height: 50,
decoration:
const BoxDecoration(
shape:
BoxShape.circle,
gradient:
LinearGradient(
colors: [
Color(0xFFFFD76A),
Color(0xFF6F5CFF),
],
),
),
child: Icon(
icon,
color:
Colors.black,
),
),
title: Text(
title,
textDirection:
TextDirection.rtl,
style:
const TextStyle(
fontWeight:
FontWeight.w900,
),
),
subtitle: Text(
subtitle,
textDirection:
TextDirection.rtl,
style:
const TextStyle(
color:
Colors.white54,
fontSize: 12,
),
),
trailing:
const Icon(
Icons.chevron_left_rounded,
),
),
);
}
}
