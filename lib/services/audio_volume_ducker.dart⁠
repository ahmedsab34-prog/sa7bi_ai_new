/// يحفظ مستوى الصوت الذي اختاره المستخدم، ويطبّق خفضًا
/// مؤقتًا أثناء المقاطعات الصوتية دون فقدان المستوى الأصلي.
class AudioVolumeDucker {
  AudioVolumeDucker({
    double initialVolume = 1.0,
    this.duckFactor = 0.35,
  }) : _userVolume = _clamp(initialVolume) {
    if (duckFactor < 0.0 || duckFactor > 1.0) {
      throw ArgumentError.value(
        duckFactor,
        'duckFactor',
        'يجب أن تكون القيمة بين 0 و1.',
      );
    }
  }

  final double duckFactor;

  double _userVolume;
  bool _isDucked = false;

  double get userVolume => _userVolume;

  bool get isDucked => _isDucked;

  /// مستوى الصوت الفعلي الذي يجب تطبيقه على المشغّل.
  double get effectiveVolume =>
      _userVolume * (_isDucked ? duckFactor : 1.0);

  /// يحفظ اختيار المستخدم حتى لو كان الخفض المؤقت نشطًا.
  /// ويرجع مستوى الصوت الفعلي الجديد.
  double setUserVolume(double volume) {
    _userVolume = _clamp(volume);
    return effectiveVolume;
  }

  /// يبدأ الخفض المؤقت دون تغيير اختيار المستخدم.
  double beginDuck() {
    _isDucked = true;
    return effectiveVolume;
  }

  /// ينهي الخفض ويستعيد مستوى المستخدم الأصلي.
  double endDuck() {
    _isDucked = false;
    return effectiveVolume;
  }

  static double _clamp(double value) {
    if (!value.isFinite) {
      throw ArgumentError.value(
        value,
        'volume',
        'يجب أن يكون مستوى الصوت رقمًا محدودًا.',
      );
    }

    return value.clamp(0.0, 1.0).toDouble();
  }
}
