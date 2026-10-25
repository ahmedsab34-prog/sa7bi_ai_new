import '../ai_service.dart';
import '../models/ai_service_models.dart';

/// خدمات الحديث الشريف والتفسير والبحث الديني.
class AiReligiousService {
  AiReligiousService._();

  /// تحميل كتب الحديث.
  static Future<List<HadithBook>> getHadithBooks() {
    return AiService.getHadithBooks();
  }

  /// البحث في الأحاديث.
  static Future<List<HadithItem>> searchHadith({
    String query = '',
    String? book,
    int limit = 20,
  }) {
    return AiService.searchHadith(
      query: query,
      book: book,
      limit: limit,
    );
  }

  /// تحميل كتب التفسير.
  static Future<List<TafsirBook>> getTafsirBooks() {
    return AiService.getTafsirBooks();
  }

  /// البحث في التفسير.
  static Future<List<TafsirItem>> searchTafsir({
    required int tafsirId,
    String? query,
    int? sura,
  }) {
    return AiService.searchTafsir(
      tafsirId: tafsirId,
      query: query,
      sura: sura,
    );
  }

  /// الحصول على رابط صوت التفسير إن كان متاحًا.
  static Future<TafsirAudioResult?> getTafsirAudio({
    required int tafsirId,
    required int sura,
  }) {
    return AiService.getTafsirAudio(
      tafsirId: tafsirId,
      sura: sura,
    );
  }

  /// البحث الموحد في المحتوى الديني.
  static Future<List<dynamic>> searchReligiousContent({
    required String type,
    String query = '',
  }) {
    return AiService.searchReligiousContent(
      type: type,
      query: query,
    );
  }
}
