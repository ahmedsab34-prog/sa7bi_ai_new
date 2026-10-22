
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'social_games_hub_screen.dart';
import 'monetization_config.dart';
import 'services/ads_service.dart';
import 'widgets/rewarded_ad_button.dart';

/// يعرض الإعلان البيني عند نقطة طبيعية فقط، بعد كل خمس جولات مكتملة.
/// إعدادات التفعيل وخدمة AdMob الحالية هي المصدر الوحيد للتحكم.
Future<void> _maybeShowInterstitialAfterGame(
  BuildContext context,
) async {
  if (!MonetizationConfig.admobEnabled ||
      !MonetizationConfig.interstitialEnabled) {
    return;
  }

  try {
    final ads = AdsService.instance;
    final shouldShow = await ads.registerInterstitialOpportunity(
      every: 5,
    );

    if (!shouldShow) return;

    await ads.showInterstitial();
  } catch (_) {
    // تعطل الإعلان لا يعطل اللعبة ولا يمنع المستخدم من إكمالها.
  }
}

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
    final callback = widget.onShareResult;
    if (callback != null) {
      callback(result);
    } else {
      Navigator.of(context).pop(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF080B13),
        appBar: AppBar(
          backgroundColor: const Color(0xFF111827),
          title: const Text('الألعاب والتجارب'),
          bottom: TabBar(
            controller: _tabs,
            tabs: const [
              Tab(
                icon: Icon(Icons.sports_esports_rounded),
                text: 'الألعاب',
              ),
              Tab(
                icon: Icon(Icons.auto_awesome_rounded),
                text: 'التجارب',
              ),
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
}

class _GamesList extends StatelessWidget {
  const _GamesList({required this.onShare});

  final ValueChanged<String> onShare;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _IntroCard(
          icon: Icons.groups_rounded,
          title: 'العب واستمتع',
          body: 'الألعاب الحالية تعمل على الجهاز. اللعب المباشر بين '
              'أجهزة مختلفة يحتاج إلى خدمة خادم ومزامنة.',
        ),
        const SizedBox(height: 12),
        if (MonetizationConfig.admobEnabled &&
            MonetizationConfig.rewardedAdsEnabled) ...[
          const _RewardedCreditsPromo(),
          const SizedBox(height: 14),
        ],

        // مركز الألعاب الجماعية الجديد.
        _MenuTile(
          icon: Icons.groups_rounded,
          title: 'الألعاب الجماعية مع الأصدقاء',
          subtitle:
              'أنشئ غرفة أو انضم برمز دعوة، واستكمل مبارياتك المحفوظة.',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => SocialGamesHubScreen(
                onShareInvite: onShare,
              ),
            ),
          ),
        ),

        _MenuTile(
          icon: Icons.grid_3x3_rounded,
          title: 'إكس أو',
          subtitle: 'لاعبان على نفس الجهاز.',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => _TicTacToeScreen(onShare: onShare),
            ),
          ),
        ),
        _MenuTile(
          icon: Icons.back_hand_rounded,
          title: 'حجر ورقة مقص',
          subtitle: 'العب ضد الكمبيوتر وسجّل نتيجتك.',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => _RpsScreen(onShare: onShare),
            ),
          ),
        ),
        _MenuTile(
          icon: Icons.quiz_rounded,
          title: 'تحدي المعلومات العامة',
          subtitle: 'أسئلة متنوعة ونتيجة في نهاية الجولة.',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => _QuizScreen(onShare: onShare),
            ),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => onShare(
            'أقترح إضافة ألعاب جماعية إلى صاحبي AI، '
            'مع غرف ودعوات ومزامنة النتائج بين الأجهزة.',
          ),
          icon: const Icon(Icons.share_rounded),
          label: const Text('مشاركة اقتراح لعبة جماعية'),
        ),
      ],
    );
  }
}

class _ExperimentsList extends StatelessWidget {
  const _ExperimentsList({required this.onShare});

  final ValueChanged<String> onShare;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const _IntroCard(
          icon: Icons.science_rounded,
          title: 'التجارب التفاعلية',
          body: 'تعلم من خلال أنشطة بسيطة تستطيع التحكم فيها.',
        ),
        const SizedBox(height: 12),
        if (MonetizationConfig.admobEnabled &&
            MonetizationConfig.rewardedAdsEnabled) ...[
          const _RewardedCreditsPromo(),
          const SizedBox(height: 14),
        ],
        _MenuTile(
          icon: Icons.brightness_7_rounded,
          title: 'رحلة حياة النجوم',
          subtitle: 'اكتشف مراحل تطور النجم.',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const _StarExperimentScreen(),
            ),
          ),
        ),
        _MenuTile(
          icon: Icons.restaurant_menu_rounded,
          title: 'المطبخ التفاعلي',
          subtitle: 'غيّر عدد الأشخاص وشاهد المقادير تتغير.',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const _KitchenExperimentScreen(),
            ),
          ),
        ),
        _MenuTile(
          icon: Icons.sports_soccer_rounded,
          title: 'قاعدة التسلل',
          subtitle: 'حرّك المهاجم لفهم الفكرة الأساسية.',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const _OffsideExperimentScreen(),
            ),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => onShare(
            'أقترح إضافة تجارب تفاعلية قابلة للمشاركة '
            'داخل الشات العام والخاص.',
          ),
          icon: const Icon(Icons.send_rounded),
          label: const Text('مشاركة اقتراح تجربة'),
        ),
      ],
    );
  }
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
  Widget build(BuildContext context) {
    return Container(
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
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF111827),
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(17),
        side: const BorderSide(color: Colors.white12),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 7,
        ),
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
            style: const TextStyle(
              color: Colors.white60,
              height: 1.4,
            ),
          ),
        ),
        trailing: const Icon(
          Icons.chevron_left_rounded,
          color: Colors.white70,
        ),
      ),
    );
  }
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
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF080B13),
        appBar: AppBar(
          backgroundColor: const Color(0xFF111827),
          title: Text(title),
          actions: [
            IconButton(
              tooltip: 'إعادة اللعب',
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
}

class _TicTacToeScreen extends StatefulWidget {
  const _TicTacToeScreen({required this.onShare});

  final ValueChanged<String> onShare;

  @override
  State<_TicTacToeScreen> createState() => _TicTacToeScreenState();
}

class _TicTacToeScreenState extends State<_TicTacToeScreen> {
  static const List<List<int>> _winningLines = [
    [0, 1, 2],
    [3, 4, 5],
    [6, 7, 8],
    [0, 3, 6],
    [1, 4, 7],
    [2, 5, 8],
    [0, 4, 8],
    [2, 4, 6],
  ];

  List<String> _board = List<String>.filled(9, '');
  String _turn = 'X';
  String? _winner;

  void _move(int index) {
    if (_winner != null || _board[index].isNotEmpty) return;

    setState(() {
      _board[index] = _turn;

      if (_winningLines.any(
        (line) => line.every((i) => _board[i] == _turn),
      )) {
        _winner = _turn;
      } else if (_board.every((value) => value.isNotEmpty)) {
        _winner = 'تعادل';
      } else {
        _turn = _turn == 'X' ? 'O' : 'X';
      }
    });

    if (_winner != null) {
      _maybeShowInterstitialAfterGame(context);
    }
  }

  void _reset() {
    setState(() {
      _board = List<String>.filled(9, '');
      _turn = 'X';
      _winner = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final status = _winner == null
        ? 'دور اللاعب $_turn'
        : _winner == 'تعادل'
            ? 'انتهت المباراة بالتعادل'
            : 'اللاعب $_winner فاز!';

    return _GamePage(
      title: 'إكس أو',
      status: status,
      onReset: _reset,
      onShare: () => widget.onShare('نتيجة لعبة إكس أو: $status.'),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 9,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemBuilder: (context, i) {
          final symbol = _board[i];

          return InkWell(
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
                symbol,
                style: TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                  color: symbol == 'X'
                      ? const Color(0xFF7FB4FF)
                      : const Color(0xFFFFA77B),
                ),
              ),
            ),
          );
        },
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
  static const Map<String, String> _symbols = {
    'حجر': '✊',
    'ورقة': '✋',
    'مقص': '✌️',
  };

  final math.Random _random = math.Random();

  int _wins = 0;
  int _losses = 0;
  int _draws = 0;
  String _status = 'اختر حركتك لبدء اللعب';

  void _choose(String player) {
    final choices = _symbols.keys.toList();
    final computer = choices[_random.nextInt(choices.length)];

    final draw = player == computer;
    final win = (player == 'حجر' && computer == 'مقص') ||
        (player == 'ورقة' && computer == 'حجر') ||
        (player == 'مقص' && computer == 'ورقة');

    setState(() {
      if (draw) {
        _draws++;
      } else if (win) {
        _wins++;
      } else {
        _losses++;
      }

      _status = 'أنت ${_symbols[player]} — الكمبيوتر ${_symbols[computer]} — '
          '${draw ? 'تعادل' : win ? 'فزت' : 'خسرت'}';
    });

    // كل جولة مكتملة تُحسب فرصة واحدة؛ الإعلان لا يظهر إلا بعد خمس جولات.
    _maybeShowInterstitialAfterGame(context);
  }

  void _reset() {
    setState(() {
      _wins = 0;
      _losses = 0;
      _draws = 0;
      _status = 'اختر حركتك لبدء اللعب';
    });
  }

  @override
  Widget build(BuildContext context) {
    return _GamePage(
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
            children: _symbols.entries.map((entry) {
              return FilledButton.tonal(
                onPressed: () => _choose(entry.key),
                child: Text(
                  '${entry.value} ${entry.key}',
                  style: const TextStyle(fontSize: 18),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _QuizScreen extends StatefulWidget {
  const _QuizScreen({required this.onShare});

  final ValueChanged<String> onShare;

  @override
  State<_QuizScreen> createState() => _QuizScreenState();
}

class _Question {
  const _Question(this.text, this.answers, this.correctIndex);

  final String text;
  final List<String> answers;
  final int correctIndex;
}

class _QuizScreenState extends State<_QuizScreen> {
  static const List<_Question> _questions = [
    _Question('ما أكبر كواكب المجموعة الشمسية؟', ['الأرض', 'المشتري', 'المريخ'], 1),
    _Question('كم ضلعًا للمثلث؟', ['ثلاثة', 'أربعة', 'خمسة'], 0),
    _Question(
      'ما الغاز الذي تمتصه النباتات في البناء الضوئي؟',
      ['الأكسجين', 'النيتروجين', 'ثاني أكسيد الكربون'],
      2,
    ),
    _Question('كم دقيقة في الساعة؟', ['30', '60', '100'], 1),
  ];

  int _index = 0;
  int _score = 0;
  int? _selected;
  bool _finished = false;

  void _answer(int index) {
    if (_selected != null || _finished) return;

    setState(() {
      _selected = index;
      if (index == _questions[_index].correctIndex) {
        _score++;
      }
    });
  }

  void _next() {
    final completedQuiz = _index == _questions.length - 1;

    setState(() {
      if (completedQuiz) {
        _finished = true;
      } else {
        _index++;
        _selected = null;
      }
    });

    if (completedQuiz) {
      _maybeShowInterstitialAfterGame(context);
    }
  }

  void _reset() {
    setState(() {
      _index = 0;
      _score = 0;
      _selected = null;
      _finished = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final question = _questions[_index];

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
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                  ),
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
                  question.text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < question.answers.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: OutlinedButton(
                      onPressed: () => _answer(i),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: _selected == i
                              ? (i == question.correctIndex
                                  ? Colors.greenAccent
                                  : Colors.redAccent)
                              : Colors.white24,
                        ),
                      ),
                      child: Text(question.answers[i]),
                    ),
                  ),
                if (_selected != null) ...[
                  Text(
                    _selected == question.correctIndex
                        ? 'إجابة صحيحة، أحسنت!'
                        : 'الإجابة الصحيحة: '
                            '${question.answers[question.correctIndex]}',
                    style: TextStyle(
                      color: _selected == question.correctIndex
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
  State<_StarExperimentScreen> createState() =>
      _StarExperimentScreenState();
}

class _StarExperimentScreenState extends State<_StarExperimentScreen> {
  double _value = 1;

  static const List<(String, String)> _stages = [
    (
      'سحابة جزيئية',
      'تتكون النجوم في مناطق كثيفة من الغاز والغبار.',
    ),
    (
      'نجم أولي',
      'تنكمش المادة بفعل الجاذبية وترتفع درجة حرارتها.',
    ),
    (
      'النسق الأساسي',
      'يحدث الاندماج النووي في قلب النجم خلال معظم عمره.',
    ),
    (
      'عملاق أحمر',
      'يتمدد النجم في مرحلة متأخرة من تطوره.',
    ),
    (
      'النهاية',
      'تختلف النهاية حسب كتلة النجم؛ قد يصبح قزمًا أبيض أو يمر بانفجار مستعر أعظم.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final index = _value.round();
    final stage = _stages[index];

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
            onChanged: (value) => setState(() => _value = value),
          ),
          Text(
            '${index + 1} من ${_stages.length}',
            style: const TextStyle(color: Colors.white54),
          ),
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
            style: const TextStyle(
              color: Colors.white70,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'هذه رحلة تعليمية مبسطة؛ يعتمد تطور النجم على كتلته.',
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

class _KitchenExperimentScreenState
    extends State<_KitchenExperimentScreen> {
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
            onChanged: (value) => setState(() => _people = value),
          ),
          _IngredientRow(
            name: 'مكرونة جافة',
            amount: '${100 * people} جم',
          ),
          _IngredientRow(
            name: 'سبانخ',
            amount: '${40 * people} جم',
          ),
          _IngredientRow(
            name: 'ليمون',
            amount: '$people ${people == 1 ? 'ثمرة' : 'ثمرات'}',
          ),
          _IngredientRow(
            name: 'زيت زيتون',
            amount: '$people ملعقة صغيرة تقريبًا',
          ),
          const SizedBox(height: 12),
          const Text(
            'اسلق المكرونة، وشوّح السبانخ قليلًا، ثم أضف عصير الليمون '
            'والزيت وقليلًا من ماء السلق. عدّل الملح حسب الرغبة.',
            style: TextStyle(
              color: Colors.white70,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _IngredientRow extends StatelessWidget {
  const _IngredientRow({
    required this.name,
    required this.amount,
  });

  final String name;
  final String amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
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
}

class _OffsideExperimentScreen extends StatefulWidget {
  const _OffsideExperimentScreen();

  @override
  State<_OffsideExperimentScreen> createState() =>
      _OffsideExperimentScreenState();
}

class _OffsideExperimentScreenState
    extends State<_OffsideExperimentScreen> {
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
                final attackerLeft =
                    (width * _attacker / 100).clamp(0.0, width - 34);

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
                        child: Container(
                          width: 1,
                          color: Colors.white24,
                        ),
                      ),
                      Positioned(
                        left: width * .50,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: 1,
                          color: Colors.white24,
                        ),
                      ),
                      Positioned(
                        left: width * .88,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: 1,
                          color: Colors.white24,
                        ),
                      ),
                      Positioned(
                        left: width * .62,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: 2,
                          color: Colors.amberAccent,
                        ),
                      ),
                      Positioned(
                        left: attackerLeft,
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
            onChanged: (value) => setState(() => _attacker = value),
          ),
          Text(
            ahead
                ? 'قد يكون اللاعب في موقف تسلل إذا كان أقرب لخط المرمى '
                    'من الكرة والمدافع الثاني الأخير عند لعب الكرة.'
                : 'وفق الرسم المبسط، المهاجم ليس متقدمًا عن خط المدافع المحدد.',
            style: TextStyle(
              color: ahead ? Colors.orangeAccent : Colors.greenAccent,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'موقف التسلل وحده ليس مخالفة؛ تُحتسب المخالفة عند مشاركة '
            'اللاعب في اللعب وفق القانون. الرسم للتوضيح وليس محاكاة كاملة.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white54,
              height: 1.4,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

/// بطاقة مكافأة موحّدة تستخدم خدمة AdMob والرصيد الموجودة بالفعل.
/// لا تمنح أي Credits محليًا؛ التحقق والمكافأة يظلان داخل RewardedAdButton.
class _RewardedCreditsPromo extends StatelessWidget {
  const _RewardedCreditsPromo();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            const Color(0xFFFFD76A).withValues(alpha: 0.13),
            const Color(0xFF7C4DFF).withValues(alpha: 0.10),
            const Color(0xFF111827),
          ],
        ),
        border: Border.all(
          color: const Color(0xFFFFD76A).withValues(alpha: 0.32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD76A).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.card_giftcard_rounded,
                  color: Color(0xFFFFD76A),
                  size: 25,
                ),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'هديتك من صاحبي AI',
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'شاهد بإرادتك واكسب رصيدًا إضافيًا',
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD76A).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Text(
                  '+10',
                  textDirection: TextDirection.ltr,
                  style: TextStyle(
                    color: Color(0xFFFFD76A),
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          const RewardedAdButton(
            label: 'شاهد إعلانًا واكسب 10 Credits',
          ),
          const SizedBox(height: 7),
          const Text(
            'المكافأة تُضاف بعد تأكيدها من الخادم، بحد أقصى 5 مكافآت يوميًا.',
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white54,
              fontSize: 10,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
