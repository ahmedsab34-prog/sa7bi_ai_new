import 'dart:convert';
import 'dart:typed_data';

/// نموذج موحد لرسالة المحادثة.
///
/// يحفظ:
/// - هل الرسالة من المستخدم أم من الذكاء الاصطناعي.
/// - النص.
/// - الصورة إن وجدت.
/// - هل الرسالة مرتبطة بفيديو.
/// - وقت إنشاء الرسالة.
/// - نوع الرسالة عند الحاجة للتطوير لاحقًا.
class ChatMessage {
  final bool isUser;
  final String text;
  final Uint8List? image;
  final bool isVideo;
  final DateTime createdAt;
  final String type;

  const ChatMessage({
    required this.isUser,
    required this.text,
    this.image,
    this.isVideo = false,
    required this.createdAt,
    this.type = 'text',
  });

  /// إنشاء رسالة نصية جديدة.
  factory ChatMessage.text({
    required bool isUser,
    required String text,
  }) {
    return ChatMessage(
      isUser: isUser,
      text: text,
      createdAt: DateTime.now(),
      type: 'text',
    );
  }

  /// إنشاء رسالة تحتوي على صورة.
  factory ChatMessage.image({
    required bool isUser,
    required String text,
    required Uint8List image,
  }) {
    return ChatMessage(
      isUser: isUser,
      text: text,
      image: image,
      createdAt: DateTime.now(),
      type: 'image',
    );
  }

  /// إنشاء رسالة مرتبطة بفيديو.
  factory ChatMessage.video({
    required bool isUser,
    required String text,
  }) {
    return ChatMessage(
      isUser: isUser,
      text: text,
      isVideo: true,
      createdAt: DateTime.now(),
      type: 'video',
    );
  }

  /// تحويل الرسالة إلى بيانات قابلة للحفظ في SharedPreferences.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'isUser': isUser,
      'user': isUser,
      'text': text,
      'video': isVideo,
      'type': type,
      'createdAt': createdAt.toIso8601String(),
      if (image != null) 'image': base64Encode(image!),
    };
  }

  /// استرجاع الرسالة من البيانات المحفوظة.
  factory ChatMessage.fromJson(
    Map<String, dynamic> json,
  ) {
    Uint8List? decodedImage;

    final encodedImage = json['image'];

    if (encodedImage is String &&
        encodedImage.trim().isNotEmpty) {
      try {
        decodedImage = base64Decode(
          encodedImage,
        );
      } catch (_) {
        decodedImage = null;
      }
    }

    DateTime createdAt = DateTime.now();

    final rawDate = json['createdAt'];

    if (rawDate is String &&
        rawDate.trim().isNotEmpty) {
      final parsed = DateTime.tryParse(
        rawDate,
      );

      if (parsed != null) {
        createdAt = parsed;
      }
    }

    final userValue =
        json['isUser'] ?? json['user'];

    return ChatMessage(
      isUser: userValue == true,
      text: json['text']?.toString() ?? '',
      image: decodedImage,
      isVideo: json['video'] == true,
      createdAt: createdAt,
      type: json['type']?.toString() ?? 'text',
    );
  }

  /// إنشاء نسخة معدلة من الرسالة.
  ChatMessage copyWith({
    bool? isUser,
    String? text,
    Uint8List? image,
    bool? isVideo,
    DateTime? createdAt,
    String? type,
  }) {
    return ChatMessage(
      isUser: isUser ?? this.isUser,
      text: text ?? this.text,
      image: image ?? this.image,
      isVideo: isVideo ?? this.isVideo,
      createdAt: createdAt ?? this.createdAt,
      type: type ?? this.type,
    );
  }
}
