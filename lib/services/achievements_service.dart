import 'package:shared_preferences/shared_preferences.dart';

class AchievementProgress {
  const AchievementProgress({
    required this.id,
    required this.title,
    required this.description,
    required this.iconName,
    required this.current,
    required this.target,
  });

  final String id;
  final String title;
  final String description;
  final String iconName;
  final int current;
  final int target;

  bool get unlocked => current >= target;
  double get fraction => target <= 0 ? 1 : (current / target).clamp(0.0, 1.0).toDouble();
}

/// Local, privacy-friendly achievement tracker.
/// It stores counters only; no messages, names, or personal content are saved.
class AchievementsService {
  AchievementsService._();

  static final AchievementsService instance = AchievementsService._();

  static const String _gamesKey = 'sa7bi_achievements_games_total_v1';
  static const String _quizKey = 'sa7bi_achievements_quiz_correct_v1';
  static const String _memoryKey = 'sa7bi_achievements_memory_wins_v1';
  static const String _best2048Key = 'sa7bi_achievements_2048_best_v1';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<void> recordGameStarted(String gameId) async {
    final prefs = await _prefs;
    final total = prefs.getInt(_gamesKey) ?? 0;
    await prefs.setInt(_gamesKey, total + 1);
    final key = 'sa7bi_achievements_game_${_safeKey(gameId)}_v1';
    await prefs.setInt(key, (prefs.getInt(key) ?? 0) + 1);
  }

  Future<void> recordQuizCorrectAnswer() async {
    final prefs = await _prefs;
    await prefs.setInt(_quizKey, (prefs.getInt(_quizKey) ?? 0) + 1);
  }

  Future<void> recordMemoryWin() async {
    final prefs = await _prefs;
    await prefs.setInt(_memoryKey, (prefs.getInt(_memoryKey) ?? 0) + 1);
  }

  Future<void> record2048Tile(int value) async {
    if (value <= 0) return;
    final prefs = await _prefs;
    final best = prefs.getInt(_best2048Key) ?? 0;
    if (value > best) {
      await prefs.setInt(_best2048Key, value);
    }
  }

  String _safeKey(String input) {
    final cleaned = input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_-]'), '_');
    return cleaned.isEmpty ? 'unknown' : cleaned;
  }

  Future<List<AchievementProgress>> loadProgress() async {
    final prefs = await _prefs;
    final games = prefs.getInt(_gamesKey) ?? 0;
    final quiz = prefs.getInt(_quizKey) ?? 0;
    final memory = prefs.getInt(_memoryKey) ?? 0;
    final best2048 = prefs.getInt(_best2048Key) ?? 0;

    return <AchievementProgress>[
      AchievementProgress(
        id: 'first_game',
        title: 'أول خطوة',
        description: 'ابدأ أول لعبة من ألعاب صاحبي.',
        iconName: 'sports_esports',
        current: games,
        target: 1,
      ),
      AchievementProgress(
        id: 'five_games',
        title: 'لاعب نشيط',
        description: 'ابدأ خمس جولات أو ألعاب.',
        iconName: 'emoji_events',
        current: games,
        target: 5,
      ),
      AchievementProgress(
        id: 'quiz_five',
        title: 'معلوماتك قوية',
        description: 'أجب عن خمسة أسئلة إجابة صحيحة.',
        iconName: 'quiz',
        current: quiz,
        target: 5,
      ),
      AchievementProgress(
        id: 'quiz_twenty',
        title: 'خبير المعلومات',
        description: 'أجب عن عشرين سؤالًا إجابة صحيحة.',
        iconName: 'school',
        current: quiz,
        target: 20,
      ),
      AchievementProgress(
        id: 'memory_three',
        title: 'ذاكرة حديد',
        description: 'أكمل لعبة الذاكرة ثلاث مرات.',
        iconName: 'psychology',
        current: memory,
        target: 3,
      ),
      AchievementProgress(
        id: 'tile_512',
        title: 'دمج ذكي',
        description: 'وصل إلى بلاطة 512 في لعبة 2048.',
        iconName: 'grid_4x4',
        current: best2048,
        target: 512,
      ),
      AchievementProgress(
        id: 'tile_1024',
        title: 'عبقري الأرقام',
        description: 'وصل إلى بلاطة 1024 في لعبة 2048.',
        iconName: 'military_tech',
        current: best2048,
        target: 1024,
      ),
    ];
  }

  Future<int> get totalGamesStarted async {
    final prefs = await _prefs;
    return prefs.getInt(_gamesKey) ?? 0;
  }
}
