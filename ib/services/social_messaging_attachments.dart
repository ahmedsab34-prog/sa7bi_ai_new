import 'dart:io';

import 'social_attachment_service.dart';
import 'social_community_service.dart';
import 'social_messaging_service.dart';

/// Attachment send helpers for existing private-chat and group services.
/// These extensions preserve the existing text-message API and database
/// schema; attachment metadata travels inside a versioned message envelope.
extension SocialPrivateAttachmentSending on SocialMessagingService {
  Future<SocialPrivateMessage> sendPrivateAttachment({
    required String conversationId,
    required File file,
    required String contentType,
    String caption = '',
  }) async {
    final bytes = await file.readAsBytes();
    final attachment = await SocialAttachmentService.instance.upload(
      scopeType: 'conversation',
      scopeId: conversationId,
      fileName: _fileName(file),
      contentType: contentType,
      bytes: bytes,
    );

    try {
      final messageText = SocialAttachmentMessageCodec.encode(
        attachment,
        caption: caption,
      );
      return await sendMessage(
        conversationId: conversationId,
        text: messageText,
      );
    } catch (_) {
      // Avoid leaving an inaccessible object when saving the chat message fails.
      try {
        await SocialAttachmentService.instance.delete(attachment.id);
      } catch (_) {}
      rethrow;
    }
  }
}

extension SocialGroupAttachmentSending on SocialCommunityService {
  Future<SocialGroupMessage> sendGroupAttachment({
    required String groupId,
    required File file,
    required String contentType,
    String caption = '',
  }) async {
    final bytes = await file.readAsBytes();
    final attachment = await SocialAttachmentService.instance.upload(
      scopeType: 'group',
      scopeId: groupId,
      fileName: _fileName(file),
      contentType: contentType,
      bytes: bytes,
    );

    try {
      final messageText = SocialAttachmentMessageCodec.encode(
        attachment,
        caption: caption,
      );
      return await sendGroupMessage(
        groupId: groupId,
        text: messageText,
      );
    } catch (_) {
      // Only the uploader can delete this attachment.
      try {
        await SocialAttachmentService.instance.delete(attachment.id);
      } catch (_) {}
      rethrow;
    }
  }
}

String _fileName(File file) {
  final path = file.uri.pathSegments.isEmpty
      ? 'attachment'
      : file.uri.pathSegments.last;
  return path.trim().isEmpty ? 'attachment' : path;
}
