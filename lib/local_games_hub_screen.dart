import 'dart:math';

import 'package:flutter/material.dart';

import 'services/achievements_service.dart';
import 'theme/sa7bi_theme.dart';

/// مجموعة ألعاب محلية تعمل دون حساب ألعاب أو اتصال بالخادم.
class LocalGamesHubScreen extends StatelessWidget {
  const LocalGamesHubScreen({super.key});

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    final games = <_LocalGameInfo>[
      _LocalGameInfo(
        title: 'الذاكرة',
        description: 'اقلب البطاقات واكتشف الأزواج المتطابقة.',
        icon: Icons.psychology_rounded,
        tag: 'تركيز',
        page: const _MemoryGameScreen(),
      ),
      _LocalGameInfo(
        title: '2048',
        description: 'ادمج الأرقام حتى تصل إلى 2048.',
        icon: Icons.apps_rounded,
        tag: 'ألغاز',
        page: const _Game2048Screen(),
      ),
      _LocalGameInfo(
        title: 'خمن الرقم',
        description: 'اكتشف الرقم السري من 1 إلى 100.',
        icon: Icons.numbers_rounded,
        tag: 'ذكاء',
        page: const _GuessNumberScreen(),
      ),
      _LocalGameInfo(
        title: 'اختبر معلوماتك',
        description: 'أسئلة عامة قصيرة وسجل إجاباتك الصحيحة.',
        icon: Icons.quiz_rounded,
        tag: 'معلومات',
        page: const _QuizGameScreen(),
      ),
    ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Sa7biTheme.background,
        appBar: AppBar(
          title: const Text('ألعاب صاحبي'),
          backgroundColor: Sa7biTheme.background,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: Sa7biTheme.premiumGradient,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Sa7biTheme.border),
              ),
              child: const Row(
                children: [
                  Icon(Icons.sports_esports_rounded, color: Sa7biTheme.cyan, size: 34),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'ألعاب خفيفة تشتغل من غير إنترنت، ونتيجتك تساعدك تفتح إنجازات جديدة.',
                      style: TextStyle(
                        color: Sa7biTheme.textPrimary,
                        fontSize: 12,
                        height: 1.6,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            for (final game in games) ...[
              _LocalGameCard(
                info: game,
                onTap: () => _open(context, game.page),
              ),
              const SizedBox(height: 9),
            ],
            const SizedBox(height: 5),
            const Text(
              'الألعاب دي محلية على جهازك. اللعب الجماعي المباشر يظل في قسم ألعاب الأصدقاء.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Sa7biTheme.textSecondary,
                fontSize: 10,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocalGameInfo {
  const _LocalGameInfo({
    required this.title,
    required this.description,
    required this.icon,
    required this.tag,
    required this.page,
  });

  final String title;
  final String description;
  final IconData icon;
  final String tag;
  final Widget page;
}

class _LocalGameCard extends StatelessWidget {
  const _LocalGameCard({required this.info, required this.onTap});

  final _LocalGameInfo info;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Sa7biTheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Sa7biTheme.border),
          ),
          child: Row(
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: Sa7biTheme.cyan.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(info.icon, color: Sa7biTheme.cyan, size: 24),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      info.title,
                      style: const TextStyle(
                        color: Sa7biTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      info.description,
                      style: const TextStyle(
                        color: Sa7biTheme.textSecondary,
                        fontSize: 10,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      info.tag,
                      style: const TextStyle(
                        color: Sa7biTheme.cyan,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_left_rounded, color: Sa7biTheme.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemoryGameScreen extends StatefulWidget {
  const _MemoryGameScreen();

  @override
  State<_MemoryGameScreen> createState() => _MemoryGameScreenState();
}

class _MemoryGameScreenState extends State<_MemoryGameScreen> {
  final Random _random = Random();
  late List<int> _cards;
  final Set<int> _matched = <int>{};
  final List<int> _opened = <int>[];
  bool _busy = false;
  bool _winRecorded = false;
  int _moves = 0;

  @override
  void initState() {
    super.initState();
    _newGame();
  }

  void _newGame() {
    _cards = <int>[1, 2, 3, 4, 5, 6, 1, 2, 3, 4, 5, 6]..shuffle(_random);
    _matched.clear();
    _opened.clear();
    _busy = false;
    _winRecorded = false;
    _moves = 0;
    if (mounted) setState(() {});
    AchievementsService.instance.recordGameStarted('memory').catchError((_) {});
  }

  Future<void> _tapCard(int index) async {
    if (_busy || _matched.contains(index) || _opened.contains(index)) return;

    setState(() => _opened.add(index));
    if (_opened.length < 2) return;

    _busy = true;
    _moves++;
    final first = _opened[0];
    final second = _opened[1];
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;

    if (_cards[first] == _cards[second]) {
      _matched.add(first);
      _matched.add(second);
    }
    _opened.clear();
    _busy = false;

    if (_matched.length == _cards.length && !_winRecorded) {
      _winRecorded = true;
      try {
        await AchievementsService.instance.recordMemoryWin();
      } catch (_) {}
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final won = _matched.length == _cards.length;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Sa7biTheme.background,
        appBar: AppBar(title: const Text('لعبة الذاكرة')),
        body: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              _GameStatusCard(
                title: won ? 'ممتاز! أكملت اللعبة' : 'اعثر على كل الأزواج',
                subtitle: 'عدد المحاولات: $_moves',
              ),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.builder(
                  itemCount: _cards.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.05,
                  ),
                  itemBuilder: (context, index) {
                    final visible = _matched.contains(index) || _opened.contains(index);
                    return Material(
                      color: visible ? Sa7biTheme.surfaceRaised : Sa7biTheme.surface,
                      borderRadius: BorderRadius.circular(15),
                      child: InkWell(
                        onTap: () => _tapCard(index),
                        borderRadius: BorderRadius.circular(15),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: _matched.contains(index) ? Sa7biTheme.success : Sa7biTheme.border,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              visible ? _cards[index].toString() : '?',
                              style: TextStyle(
                                color: visible ? Sa7biTheme.cyan : Sa7biTheme.textSecondary,
                                fontSize: 27,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (won)
                FilledButton.icon(
                  onPressed: _newGame,
                  icon: const Icon(Icons.replay_rounded),
                  label: const Text('العب مرة أخرى'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Game2048Screen extends StatefulWidget {
  const _Game2048Screen();

  @override
  State<_Game2048Screen> createState() => _Game2048ScreenState();
}

class _Game2048ScreenState extends State<_Game2048Screen> {
  final Random _random = Random();
  late List<List<int>> _grid;
  int _score = 0;
  int _bestTile = 0;

  @override
  void initState() {
    super.initState();
    _reset();
    _recordStart();
  }

  Future<void> _recordStart() async {
    try {
      await AchievementsService.instance.recordGameStarted('2048');
    } catch (_) {}
  }

  void _reset() {
    _grid = List<List<int>>.generate(4, (_) => List<int>.filled(4, 0));
    _score = 0;
    _bestTile = 0;
    _addRandomTile();
    _addRandomTile();
    if (mounted) setState(() {});
  }

  void _addRandomTile() {
    final empty = <Point<int>>[];
    for (var row = 0; row < 4; row++) {
      for (var col = 0; col < 4; col++) {
        if (_grid[row][col] == 0) empty.add(Point<int>(row, col));
      }
    }
    if (empty.isEmpty) return;
    final point = empty[_random.nextInt(empty.length)];
    _grid[point.x][point.y] = _random.nextInt(10) == 0 ? 4 : 2;
  }

  List<int> _compressLeft(List<int> source) {
    final values = source.where((value) => value != 0).toList();
    final output = <int>[];
    var index = 0;
    while (index < values.length) {
      if (index + 1 < values.length && values[index] == values[index + 1]) {
        final merged = values[index] * 2;
        output.add(merged);
        _score += merged;
        if (merged > _bestTile) _bestTile = merged;
        index += 2;
      } else {
        output.add(values[index]);
        if (values[index] > _bestTile) _bestTile = values[index];
        index++;
      }
    }
    while (output.length < 4) {
      output.add(0);
    }
    return output;
  }

  List<List<int>> _transpose(List<List<int>> input) {
    return List<List<int>>.generate(
      4,
      (row) => List<int>.generate(4, (col) => input[col][row]),
    );
  }

  bool _move(int direction) {
    // 0 left, 1 right, 2 up, 3 down.
    final before = _grid.map((row) => List<int>.from(row)).toList();
    var work = _grid.map((row) => List<int>.from(row)).toList();
    final vertical = direction == 2 || direction == 3;
    if (vertical) work = _transpose(work);
    final reverse = direction == 1 || direction == 3;

    if (reverse) {
      work = work.map((row) => row.reversed.toList()).toList();
    }
    work = work.map(_compressLeft).toList();
    if (reverse) {
      work = work.map((row) => row.reversed.toList()).toList();
    }
    if (vertical) work = _transpose(work);

    final changed = !_sameGrid(before, work);
    if (!changed) return false;

    setState(() {
      _grid = work;
      _addRandomTile();
    });
    if (_bestTile > 0) {
      AchievementsService.instance.record2048Tile(_bestTile).catchError((_) {});
    }
    return true;
  }

  bool _sameGrid(List<List<int>> a, List<List<int>> b) {
    for (var row = 0; row < 4; row++) {
      for (var col = 0; col < 4; col++) {
        if (a[row][col] != b[row][col]) return false;
      }
    }
    return true;
  }

  bool get _gameOver {
    for (var row = 0; row < 4; row++) {
      for (var col = 0; col < 4; col++) {
        if (_grid[row][col] == 0) return false;
        if (row < 3 && _grid[row][col] == _grid[row + 1][col]) return false;
        if (col < 3 && _grid[row][col] == _grid[row][col + 1]) return false;
      }
    }
    return true;
  }

  Color _tileColor(int value) {
    if (value == 0) return Sa7biTheme.surfaceSoft;
    if (value <= 4) return const Color(0xFF263D55);
    if (value <= 16) return const Color(0xFF23617A);
    if (value <= 64) return const Color(0xFF277E91);
    if (value <= 256) return const Color(0xFF4C70B5);
    return const Color(0xFF7667B8);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Sa7biTheme.background,
        appBar: AppBar(
          title: const Text('2048'),
          actions: [
            IconButton(onPressed: _reset, tooltip: 'لعبة جديدة', icon: const Icon(Icons.refresh_rounded)),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              _GameStatusCard(title: 'النقاط: $_score', subtitle: 'اسحب في اتجاه الحركة أو استخدم الأسهم.'),
              const SizedBox(height: 14),
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: GestureDetector(
                      onPanEnd: (details) {
                        final dx = details.velocity.pixelsPerSecond.dx;
                        final dy = details.velocity.pixelsPerSecond.dy;
                        if (dx.abs() > dy.abs()) {
                          if (dx < -100) _move(0);
                          if (dx > 100) _move(1);
                        } else {
                          if (dy < -100) _move(2);
                          if (dy > 100) _move(3);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Sa7biTheme.surface,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Sa7biTheme.border),
                        ),
                        child: GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: 16,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            crossAxisSpacing: 6,
                            mainAxisSpacing: 6,
                          ),
                          itemBuilder: (context, index) {
                            final value = _grid[index ~/ 4][index % 4];
                            return Container(
                              decoration: BoxDecoration(
                                color: _tileColor(value),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  value == 0 ? '' : value.toString(),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: value >= 1024 ? 17 : 21,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filledTonal(onPressed: () => _move(2), icon: const Icon(Icons.keyboard_arrow_up_rounded)),
                  const SizedBox(width: 5),
                  IconButton.filledTonal(onPressed: () => _move(0), icon: const Icon(Icons.keyboard_arrow_left_rounded)),
                  const SizedBox(width: 5),
                  IconButton.filledTonal(onPressed: () => _move(3), icon: const Icon(Icons.keyboard_arrow_down_rounded)),
                  const SizedBox(width: 5),
                  IconButton.filledTonal(onPressed: () => _move(1), icon: const Icon(Icons.keyboard_arrow_right_rounded)),
                ],
              ),
              if (_gameOver) ...[
                const SizedBox(height: 8),
                const Text('انتهت الحركات المتاحة.', style: TextStyle(color: Sa7biTheme.textSecondary)),
                TextButton(onPressed: _reset, child: const Text('ابدأ من جديد')),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _GuessNumberScreen extends StatefulWidget {
  const _GuessNumberScreen();

  @override
  State<_GuessNumberScreen> createState() => _GuessNumberScreenState();
}

class _GuessNumberScreenState extends State<_GuessNumberScreen> {
  final TextEditingController _controller = TextEditingController();
  final Random _random = Random();
  late int _secret;
  int _attempts = 0;
  String _hint = 'اختر رقمًا من 1 إلى 100.';
  bool _won = false;

  @override
  void initState() {
    super.initState();
    _newRound();
    AchievementsService.instance.recordGameStarted('guess_number').catchError((_) {});
  }

  void _newRound() {
    _secret = _random.nextInt(100) + 1;
    _attempts = 0;
    _hint = 'اختر رقمًا من 1 إلى 100.';
    _won = false;
    _controller.clear();
    if (mounted) setState(() {});
  }

  void _check() {
    if (_won) return;
    final guess = int.tryParse(_controller.text.trim());
    if (guess == null || guess < 1 || guess > 100) {
      setState(() => _hint = 'اكتب رقمًا صحيحًا بين 1 و100.');
      return;
    }
    setState(() {
      _attempts++;
      if (guess == _secret) {
        _won = true;
        _hint = 'أحسنت! عرفت الرقم بعد $_attempts محاولات.';
      } else if (guess < _secret) {
        _hint = 'الرقم السري أكبر من $guess.';
      } else {
        _hint = 'الرقم السري أصغر من $guess.';
      }
      _controller.clear();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Sa7biTheme.background,
        appBar: AppBar(title: const Text('خمن الرقم')),
        body: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.numbers_rounded, color: Sa7biTheme.cyan, size: 66),
              const SizedBox(height: 18),
              _GameStatusCard(title: _won ? 'فزت!' : 'أنا اخترت رقمًا سريًا', subtitle: _hint),
              const SizedBox(height: 18),
              TextField(
                controller: _controller,
                enabled: !_won,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                decoration: const InputDecoration(labelText: 'اكتب تخمينك', border: OutlineInputBorder()),
                onSubmitted: (_) => _check(),
              ),
              const SizedBox(height: 12),
              if (!_won)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(onPressed: _check, child: const Text('تأكيد الرقم')),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(onPressed: _newRound, icon: const Icon(Icons.replay_rounded), label: const Text('جولة جديدة')),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuizQuestion {
  const _QuizQuestion(this.question, this.answers, this.correctIndex);
  final String question;
  final List<String> answers;
  final int correctIndex;
}

class _QuizGameScreen extends StatefulWidget {
  const _QuizGameScreen();

  @override
  State<_QuizGameScreen> createState() => _QuizGameScreenState();
}

class _QuizGameScreenState extends State<_QuizGameScreen> {
  static const List<_QuizQuestion> _questions = <_QuizQuestion>[
    _QuizQuestion('ما عاصمة مصر؟', <String>['القاهرة', 'الإسكندرية', 'أسوان', 'المنصورة'], 0),
    _QuizQuestion('كم عدد أيام الأسبوع؟', <String>['خمسة', 'ستة', 'سبعة', 'ثمانية'], 2),
    _QuizQuestion('أي كوكب يُعرف بالكوكب الأحمر؟', <String>['الزهرة', 'المريخ', 'المشتري', 'زحل'], 1),
    _QuizQuestion('ما أكبر محيط على الأرض؟', <String>['الأطلسي', 'الهندي', 'المتجمد', 'الهادئ'], 3),
    _QuizQuestion('كم ضلعًا للمثلث؟', <String>['ثلاثة', 'أربعة', 'خمسة', 'ستة'], 0),
    _QuizQuestion('ما الغاز الذي تحتاجه النباتات غالبًا في البناء الضوئي؟', <String>['الأكسجين', 'ثاني أكسيد الكربون', 'الهيليوم', 'النيتروجين'], 1),
    _QuizQuestion('كم دقيقة في الساعة؟', <String>['30', '45', '60', '90'], 2),
  ];

  int _index = 0;
  int _score = 0;
  bool _finished = false;
  int? _selected;
  bool _answered = false;

  @override
  void initState() {
    super.initState();
    AchievementsService.instance.recordGameStarted('quiz').catchError((_) {});
  }

  Future<void> _answer(int index) async {
    if (_answered || _finished) return;
    final correct = index == _questions[_index].correctIndex;
    setState(() {
      _selected = index;
      _answered = true;
      if (correct) _score++;
    });
    if (correct) {
      try {
        await AchievementsService.instance.recordQuizCorrectAnswer();
      } catch (_) {}
    }
    await Future<void>.delayed(const Duration(milliseconds: 550));
    if (!mounted) return;
    setState(() {
      if (_index + 1 >= _questions.length) {
        _finished = true;
      } else {
        _index++;
        _selected = null;
        _answered = false;
      }
    });
  }

  void _restart() {
    setState(() {
      _index = 0;
      _score = 0;
      _finished = false;
      _selected = null;
      _answered = false;
    });
    AchievementsService.instance.recordGameStarted('quiz').catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final question = _questions[_index];
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Sa7biTheme.background,
        appBar: AppBar(title: const Text('اختبر معلوماتك')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: _finished
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.emoji_events_rounded, color: Sa7biTheme.cyan, size: 64),
                      const SizedBox(height: 12),
                      const Text('انتهى الاختبار', style: TextStyle(color: Sa7biTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 7),
                      Text('نتيجتك: $_score من ${_questions.length}', style: const TextStyle(color: Sa7biTheme.textSecondary)),
                      const SizedBox(height: 16),
                      FilledButton.icon(onPressed: _restart, icon: const Icon(Icons.replay_rounded), label: const Text('اختبار جديد')),
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _GameStatusCard(title: 'السؤال ${_index + 1} من ${_questions.length}', subtitle: 'الإجابات الصحيحة: $_score'),
                    const SizedBox(height: 19),
                    Text(
                      question.question,
                      style: const TextStyle(color: Sa7biTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w900, height: 1.5),
                    ),
                    const SizedBox(height: 16),
                    for (var i = 0; i < question.answers.length; i++) ...[
                      _QuizAnswerButton(
                        label: question.answers[i],
                        selected: _selected == i,
                        correct: _answered && i == question.correctIndex,
                        wrong: _answered && _selected == i && i != question.correctIndex,
                        onTap: () => _answer(i),
                      ),
                      const SizedBox(height: 9),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

class _QuizAnswerButton extends StatelessWidget {
  const _QuizAnswerButton({
    required this.label,
    required this.selected,
    required this.correct,
    required this.wrong,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool correct;
  final bool wrong;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = correct ? Sa7biTheme.success : wrong ? Sa7biTheme.danger : Sa7biTheme.border;
    return Material(
      color: Sa7biTheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: selected || correct || wrong ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color),
          ),
          child: Text(label, style: const TextStyle(color: Sa7biTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}

class _GameStatusCard extends StatelessWidget {
  const _GameStatusCard({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Sa7biTheme.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Sa7biTheme.border),
      ),
      child: Column(
        children: [
          Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Sa7biTheme.textPrimary, fontWeight: FontWeight.w900, fontSize: 14)),
          const SizedBox(height: 5),
          Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Sa7biTheme.textSecondary, fontSize: 10, height: 1.4)),
        ],
      ),
    );
  }
}
