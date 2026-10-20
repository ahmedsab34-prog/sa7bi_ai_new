```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// شاشة مستقلة للألعاب والتجارب التفاعلية في صاحبي AI.
class InteractiveExperiencesScreen extends StatefulWidget {
  const InteractiveExperiencesScreen({super.key, this.onShareResult});

  final ValueChanged<String>? onShareResult;

  @override
  State<InteractiveExperiencesScreen> createState() =>
      _InteractiveExperiencesScreenState();
}

class _InteractiveExperiencesScreenState
    extends State<InteractiveExperiencesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _share(String result) {
    if (widget.onShareResult != null) {
      widget.onShareResult!(result);
      return;
    }
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: const Color(0xFF080B13),
          appBar: AppBar(
            backgroundColor: const Color(0xFF111827),
            title: const Text('الألعاب والتجارب'),
            bottom: TabBar(
              controller: _tabs,
              tabs: const [
                Tab(icon: Icon(Icons.sports_esports_rounded), text: 'الألعاب'),
                Tab(icon: Icon(Icons.auto_awesome_rounded), text: 'التجارب'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabs,
            children: [
              _GamesList(onShare: _share),
              _ExperimentsList(onShare: _share),
            ],
          ),
        ),
      );
}

class _GamesList extends StatelessWidget {
  const _GamesList({required this.onShare});
  final ValueChanged<String> onShare;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _IntroCard(
            icon: Icons.groups_rounded,
            title: 'اللعب داخل الشات',
            body: 'هذه بداية واجهة الألعاب. الألعاب الحالية محلية؛ اللعب المباشر '
                'بين أجهزة مختلفة يتطلب تفعيل خدمة الشات الاجتماعي أولًا.',
          ),
          const SizedBox(height: 12),
          _MenuTile(
            icon: Icons.grid_3x3_rounded,
            title: 'إكس أو — لاعبان على جهاز واحد',
            subtitle: 'تناوب على X و O لتكوين ثلاثة رموز على خط واحد.',
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => _TicTacToeScreen(onShare: onShare),
            )),
          ),
          _MenuTile(
            icon: Icons.back_hand_rounded,
            title: 'حجر ورقة مقص',
            subtitle: 'العب جولات سريعة ضد الكمبيوتر وسجّل نتيجتك.',
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => _RpsScreen(onShare: onShare),
            )),
          ),
          _MenuTile(
            icon: Icons.quiz_rounded,
            title: 'تحدي المعلومات العامة',
            subtitle: 'أسئلة اختيار من متعدد مع نتيجة في نهاية الجولة.',
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => _QuizScreen(onShare: onShare),
            )),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => onShare(
              'اقتراح لعبة جماعية: أريد إنشاء غرفة لعب داخل الشات، '
              'مع دعوات للأعضاء ومزامنة الأدوار والنتائج بين الأجهزة.',
            ),
            icon: const Icon(Icons.share_rounded),
            label: const Text('مشاركة اقتراح لعبة جماعية'),
          ),
        ],
      );
}

class _ExperimentsList extends StatelessWidget {
  const _ExperimentsList({required this.onShare});
  final ValueChanged<String> onShare;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _IntroCard(
            icon: Icons.science_rounded,
            title: 'مختبر التجارب المرئية',
            body: 'أنشطة تعليمية مبسطة تتفاعل مع اختيارات المستخدم، ويمكن لاحقًا '
                'تحويلها إلى تحديات مشتركة داخل الشات.',
          ),
          const SizedBox(height: 12),
          _MenuTile(
            icon: Icons.brightness_7_rounded,
            title: 'رحلة حياة النجوم',
            subtitle: 'حرّك المؤشر بين مراحل تطور النجم.',
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const _StarExperimentScreen(),
            )),
          ),
          _MenuTile(
            icon: Icons.restaurant_menu_rounded,
            title: 'المطبخ التفاعلي',
            subtitle: 'غيّر عدد الأشخاص وشاهد المقادير تتغير.',
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const _KitchenExperimentScreen(),
            )),
          ),
          _MenuTile(
            icon: Icons.sports_soccer_rounded,
            title: 'قاعدة التسلل',
            subtitle: 'حرّك المهاجم لفهم الفكرة الأساسية للتسلل.',
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => const _OffsideExperimentScreen(),
            )),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => onShare(
              'اقتراح تجربة مرئية: أريد نشاطًا تفاعليًا يمكن مشاركته داخل '
              'الشات العام أو الخاص مع حفظ النتائج ومزامنتها بأمان.',
            ),
            icon: const Icon(Icons.send_rounded),
            label: const Text('اقتراح تجربة للشات'),
          ),
        ],
      );
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [Color(0xFF202A45), Color(0xFF111827)],
          ),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 34, color: const Color(0xFFFFD76A)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    body,
                    style: const TextStyle(
                      color: Colors.white70,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
        color: const Color(0xFF111827),
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(17),
          side: const BorderSide(color: Colors.white12),
        ),
        child: ListTile(
          onTap: onTap,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 15, vertical: 7),
          leading: CircleAvatar(
            backgroundColor: const Color(0x22FFD76A),
            child: Icon(icon, color: const Color(0xFFFFD76A)),
          ),
          title: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(
              subtitle,
              style: const TextStyle(color: Colors.white60, height: 1.4),
            ),
          ),
          trailing:
              const Icon(Icons.chevron_left_rounded, color: Colors.white70),
        ),
      );
}

class _GamePage extends StatelessWidget {
  const _GamePage({
    required this.title,
    required this.status,
    required this.child,
    required this.onReset,
    this.onShare,
  });

  final String title;
  final String status;
  final Widget child;
  final VoidCallback onReset;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: const Color(0xFF080B13),
          appBar: AppBar(
            backgroundColor: const Color(0xFF111827),
            title: Text(title),
            actions: [
              IconButton(
                tooltip: 'إعادة',
                onPressed: onReset,
                icon: const Icon(Icons.refresh_rounded),
              ),
              if (onShare != null)
                IconButton(
                  tooltip: 'مشاركة النتيجة',
                  onPressed: onShare,
                  icon: const Icon(Icons.share_rounded),
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF151D2C),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.white12),
                ),
                child: Text(
                  status,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFFFD76A),
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              child,
            ],
          ),
        ),
      );
}

class _TicTacToeScreen extends StatefulWidget {
  const _TicTacToeScreen({required this.onShare});
  final ValueChanged<String> onShare;

  @override
  State<_TicTacToeScreen> createState() => _TicTacToeScreenState();
}

class _TicTacToeScreenState extends State<_TicTacToeScreen> {
  static const _wins = <List<int>>[
    [0, 1, 2],
    [3, 4, 5],
    [6, 7, 8],
    [0, 3, 6],
    [1, 4, 7],
    [2, 5, 8],
    [0, 4, 8],
    [2, 4, 6],
  ];

  List<String> _board = List.filled(9, '');
  String _turn = 'X';
  String? _winner;

  void _move(int index) {
    if (_winner != null || _board[index].isNotEmpty) return;

    setState(() {
      _board[index] = _turn;

      if (_wins.any((line) => line.every((i) => _board[i] == _turn))) {
        _winner = _turn;
      } else if (_board.every((v) => v.isNotEmpty)) {
        _winner = 'تعادل';
      } else {
        _turn = _turn == 'X' ? 'O' : 'X';
      }
    });
  }

  void _reset() => setState(() {
        _board = List.filled(9, '');
        _turn = 'X';
        _winner = null;
      });

  @override
  Widget build(BuildContext context) {
    final status = _winner == null
        ? 'دور اللاعب $_turn'
        : (_winner == 'تعادل' ? 'انتهت المباراة بالتعادل' : 'اللاعب $_winner فاز!');

    return _GamePage(
      title: 'إكس أو',
      status: status,
      onReset: _reset,
      onShare: () => widget.onShare('نتيجة إكس أو: $status.'),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 9,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemBuilder: (context, i) => InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: () => _move(i),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF172033),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white12),
            ),
            alignment: Alignment.center,
            child: Text(
              _board[i],
              style: TextStyle(
                fontSize: 44,
                fontWeight: FontWeight.w900,
                color: _board[i] == 'X'
                    ? const Color(0xFF7FB4FF)
                    : const Color(0xFFFFA77B),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RpsScreen extends StatefulWidget {
  const _RpsScreen({required this.onShare});
  final ValueChanged<String> onShare;

  @override
  State<_RpsScreen> createState() => _RpsScreenState();
}

class _RpsScreenState extends State<_RpsScreen> {
  static const _symbols = {'حجر': '✊', 'ورقة': '✋', 'مقص': '✌️'};
  final _random = math.Random();
  int _wins = 0, _losses = 0, _draws = 0;
  String _status = 'اختر حركتك لبدء اللعب';

  void _choose(String player) {
    final choices = _symbols.keys.toList();
    final cpu = choices[_random.nextInt(choices.length)];
    final draw = player == cpu;
    final win = (player == 'حجر' && cpu == 'مقص') ||
        (player == 'ورقة' && cpu == 'حجر') ||
        (player == 'مقص' && cpu == 'ورقة');

    setState(() {
      if (draw) {
        _draws++;
      } else if (win) {
        _wins++;
      } else {
        _losses++;
      }

      _status =
          'أنت ${_symbols[player]} — الكمبيوتر ${_symbols[cpu]} — ${draw ? 'تعادل' : win ? 'فزت' : 'خسرت'}';
    });
  }

  void _reset() => setState(() {
        _wins = 0;
        _losses = 0;
        _draws = 0;
        _status = 'اختر حركتك لبدء اللعب';
      });

  @override
  Widget build(BuildContext context) => _GamePage(
        title: 'حجر ورقة مقص',
        status: _status,
        onReset: _reset,
        onShare: () => widget.onShare(
          'نتيجة حجر ورقة مقص: فوز $_wins، خسارة $_losses، تعادل $_draws.',
        ),
        child: Column(
          children: [
            Text(
              'فوز $_wins  •  خسارة $_losses  •  تعادل $_draws',
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 18),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: _symbols.entries
                  .map(
                    (e) => FilledButton.tonal(
                      onPressed: () => _choose(e.key),
                      child: Text(
                        '${e.value} ${e.key}',
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      );
}

class _QuizScreen extends StatefulWidget {
  const _QuizScreen({required this.onShare});
  final ValueChanged<String> onShare;

  @override
  State<_QuizScreen> createState() => _QuizScreenState();
}

class _Question {
  const _Question(this.text, this.answers, this.correct);

  final String text;
  final List<String> answers;
  final int correct;
}

class _QuizScreenState extends State<_QuizScreen> {
  static const _questions = <_Question>[
    _Question('ما أكبر كواكب المجموعة الشمسية؟', ['الأرض', 'المشتري', 'المريخ'], 1),
    _Question('كم ضلعًا للمثلث؟', ['ثلاثة', 'أربعة', 'خمسة'], 0),
    _Question('ما الغاز الذي تمتصه النباتات في البناء الضوئي؟', ['الأكسجين', 'النيتروجين', 'ثاني أكسيد الكربون'], 2),
    _Question('كم دقيقة في الساعة؟', ['30', '60', '100'], 1),
  ];

  int _index = 0, _score = 0;
  int? _selected;
  bool _finished = false;

  void _answer(int i) {
    if (_selected != null || _finished) return;
    setState(() {
      _selected = i;
      if (i == _questions[_index].correct) _score++;
    });
  }

  void _next() => setState(() {
        if (_index == _questions.length - 1) {
          _finished = true;
        } else {
          _index++;
          _selected = null;
        }
      });

  void _reset() => setState(() {
        _index = 0;
        _score = 0;
        _selected = null;
        _finished = false;
      });

  @override
  Widget build(BuildContext context) {
    final q = _questions[_index];

    return _GamePage(
      title: 'تحدي المعلومات',
      status: _finished
          ? 'نتيجتك $_score من ${_questions.length}'
          : 'السؤال ${_index + 1} من ${_questions.length} • النقاط $_score',
      onReset: _reset,
      onShare: () => widget.onShare(
        'نتيجة تحدي المعلومات العامة: $_score من ${_questions.length}.',
      ),
      child: _finished
          ? Column(
              children: [
                const Icon(
                  Icons.emoji_events_rounded,
                  size: 64,
                  color: Color(0xFFFFD76A),
                ),
                const SizedBox(height: 12),
                Text(
                  'أجبت إجابة صحيحة على $_score من ${_questions.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 19),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _reset,
                  child: const Text('العب مرة أخرى'),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  q.text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < q.answers.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: OutlinedButton(
                      onPressed: () => _answer(i),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: _selected == i
                              ? (i == q.correct
                                  ? Colors.greenAccent
                                  : Colors.redAccent)
                              : Colors.white24,
                        ),
                      ),
                      child: Text(q.answers[i]),
                    ),
                  ),
                if (_selected != null) ...[
                  Text(
                    _selected == q.correct
                        ? 'إجابة صحيحة، أحسنت!'
                        : 'الإجابة الصحيحة: ${q.answers[q.correct]}',
                    style: TextStyle(
                      color: _selected == q.correct
                          ? Colors.greenAccent
                          : Colors.orangeAccent,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _next,
                    child: Text(
                      _index == _questions.length - 1
                          ? 'عرض النتيجة'
                          : 'السؤال التالي',
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _StarExperimentScreen extends StatefulWidget {
  const _StarExperimentScreen();

  @override
  State<_StarExperimentScreen> createState() => _StarExperimentScreenState();
}

class _StarExperimentScreenState extends State<_StarExperimentScreen> {
  double _value = 1;

  static const _stages = [
    ('سحابة جزيئية', 'تتكون النجوم في مناطق كثيفة من الغاز والغبار.'),
    ('نجم أولي', 'تنكمش المادة بفعل الجاذبية وترتفع درجة حرارتها.'),
    ('النسق الأساسي', 'يحدث الاندماج النووي في قلب النجم خلال معظم عمره.'),
    ('عملاق أحمر', 'يتمدد النجم في مرحلة متأخرة من تطوره.'),
    ('النهاية', 'تختلف النهاية حسب كتلة النجم؛ قد يصبح قزمًا أبيض أو يمر بانفجار مستعر أعظم.'),
  ];

  @override
  Widget build(BuildContext context) {
    final i = _value.round();
    final stage = _stages[i];

    return _GamePage(
      title: 'رحلة حياة النجوم',
      status: stage.$1,
      onReset: () => setState(() => _value = 1),
      child: Column(
        children: [
          const Icon(
            Icons.brightness_7_rounded,
            size: 90,
            color: Color(0xFFFFD76A),
          ),
          Slider(
            value: _value,
            min: 0,
            max: 4,
            divisions: 4,
            label: stage.$1,
            onChanged: (v) => setState(() => _value = v),
          ),
          Text('${i + 1} من ${_stages.length}',
              style: const TextStyle(color: Colors.white54)),
          const SizedBox(height: 12),
          Text(
            stage.$1,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            stage.$2,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, height: 1.5),
          ),
          const SizedBox(height: 10),
          const Text(
            'هذه رحلة تعليمية مبسطة؛ تطور النجم النهائي يعتمد بدرجة كبيرة على كتلته.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _KitchenExperimentScreen extends StatefulWidget {
  const _KitchenExperimentScreen();

  @override
  State<_KitchenExperimentScreen> createState() =>
      _KitchenExperimentScreenState();
}

class _KitchenExperimentScreenState extends State<_KitchenExperimentScreen> {
  double _people = 2;

  @override
  Widget build(BuildContext context) {
    final people = _people.round();

    return _GamePage(
      title: 'المطبخ التفاعلي',
      status: 'مكرونة بالليمون والسبانخ',
      onReset: () => setState(() => _people = 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.restaurant_menu_rounded,
            size: 72,
            color: Color(0xFFFFD76A),
          ),
          Text(
            'عدد الأشخاص: $people',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          Slider(
            value: _people,
            min: 1,
            max: 6,
            divisions: 5,
            label: '$people',
            onChanged: (v) => setState(() => _people = v),
          ),
          _IngredientRow(name: 'مكرونة جافة', amount: '${100 * people} جم'),
          _IngredientRow(name: 'سبانخ', amount: '${40 * people} جم'),
          _IngredientRow(
            name: 'ليمون',
            amount: '$people ${people == 1 ? 'ثمرة' : 'ثمرات'}',
          ),
          _IngredientRow(
            name: 'زيت زيتون',
            amount: '${people} ملعقة صغيرة تقريبًا',
          ),
          const SizedBox(height: 12),
          const Text(
            'اسلق المكرونة، شوّح السبانخ قليلًا، ثم أضف عصير الليمون والزيت '
            'وقليلًا من ماء السلق. عدّل الملح حسب الرغبة.',
            style: TextStyle(color: Colors.white70, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _IngredientRow extends StatelessWidget {
  const _IngredientRow({required this.name, required this.amount});

  final String name;
  final String amount;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 7),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: const TextStyle(color: Colors.white),
              ),
            ),
            Text(
              amount,
              style: const TextStyle(color: Color(0xFFFFD76A)),
            ),
          ],
        ),
      );
}

class _OffsideExperimentScreen extends StatefulWidget {
  const _OffsideExperimentScreen();

  @override
  State<_OffsideExperimentScreen> createState() =>
      _OffsideExperimentScreenState();
}

class _OffsideExperimentScreenState extends State<_OffsideExperimentScreen> {
  double _attacker = 50;

  @override
  Widget build(BuildContext context) {
    final ahead = _attacker > 62;

    return _GamePage(
      title: 'قاعدة التسلل',
      status: ahead
          ? 'المهاجم متقدم عن خط المدافع في هذا الرسم'
          : 'المهاجم على خط المدافع أو خلفه',
      onReset: () => setState(() => _attacker = 50),
      child: Column(
        children: [
          SizedBox(
            height: 190,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;

                return Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF12643E),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white54),
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        left: width * .12,
                        top: 0,
                        bottom: 0,
                        child: Container(width: 1, color: Colors.white24),
                      ),
                      Positioned(
                        left: width * .50,
                        top: 0,
                        bottom: 0,
                        child: Container(width: 1, color: Colors.white24),
                      ),
                      Positioned(
                        left: width * .88,
                        top: 0,
                        bottom: 0,
                        child: Container(width: 1, color: Colors.white24),
                      ),
                      Positioned(
                        left: width * .62,
                        top: 0,
                        bottom: 0,
                        child: Container(width: 2, color: Colors.amberAccent),
                      ),
                      Positioned(
                        left: (width * _attacker / 100)
                            .clamp(0.0, width - 34),
                        top: 76,
                        child: const Icon(
                          Icons.directions_run_rounded,
                          size: 34,
                          color: Colors.white,
                        ),
                      ),
                      const Positioned(
                        left: 18,
                        top: 76,
                        child: Icon(
                          Icons.sports_soccer_rounded,
                          size: 22,
                          color: Colors.white,
                        ),
                      ),
                      const Positioned(
                        left: 10,
                        top: 8,
                        child: Text(
                          'اتجاه المرمى ←',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'حرّك المهاجم على طول الملعب',
            style: TextStyle(color: Colors.white70),
          ),
          Slider(
            value: _attacker,
            min: 10,
            max: 90,
            divisions: 16,
            onChanged: (v) => setState(() => _attacker = v),
          ),
          Text(
            ahead
                ? 'قد يكون اللاعب في موقف تسلل عند لعب الكرة إذا كان أقرب لخط '
                    'المرمى من الكرة والمدافع الثاني الأخير.'
                : 'وفق الرسم المبسط، المهاجم ليس متقدمًا عن خط المدافع المحدد.',
            style: TextStyle(
              color: ahead ? Colors.orangeAccent : Colors.greenAccent,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'موقف التسلل وحده ليس مخالفة؛ تُحتسب المخالفة عند مشاركة اللاعب '
            'في اللعب وفق القانون. الرسم للتوضيح وليس محاكاة كاملة للقانون.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, height: 1.4, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
