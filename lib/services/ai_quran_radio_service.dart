
import '../ai_service.dart' show AiService;
import '../models/ai_service_models.dart';

/// خدمات القرآن الكريم ومحطات الراديو.
/// تعتمد على AiService الحالية للحفاظ على توافق التطبيق.
class AiQuranRadioService {
  AiQuranRadioService._();

  /// تحميل قائمة القراء والسور والمصاحف.
  static Future<QuranCatalog?> getQuranCatalog() {
    return AiService.getQuranCatalog();
  }

  /// تحميل الدول المتاحة لمحطات الراديو.
  static Future<List<RadioCountry>> getRadioCountries() {
    return AiService.getRadioCountries();
  }

  /// تحميل محطات الراديو حسب رمز الدولة.
  static Future<List<RadioStation>> getRadioStations(
    String country,
  ) {
    return AiService.getRadioStations(country);
  }
}
