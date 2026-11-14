
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../config/app_config.dart';
import 'social_guest_session_service.dart';
import 'social_session_storage.dart';

/// Optional realtime event channel for Sa7bi Connect private conversations.
///
/// REST remains the source of truth for loading/sending messages. This socket
/// only carries live updates and typing state, so the chat can safely keep its
/// existing polling fallback when WebSocket is unavailable on a weak network.
class SocialRealtimeService {
  SocialRealtimeService._();

  static final SocialRealtimeService instance = SocialRealtimeService._();

  static const Duration _connectTimeout = Duration(seconds: 12);
  static const Duration _pingInterval = Duration(seconds: 25);

  final StreamController<SocialRealtimeEvent> _events =
      StreamController<SocialRealtimeEvent>.broadcast(sync: true);

  WebSocket? _socket;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;
  Future<void>? _connecting;

  String? _conversationId;
  bool _shouldReconnect = false;
  int _reconnectAttempt = 0;

  Stream<SocialRealtimeEvent> get events => _events.stream;

  bool get isConnected => _socket?.readyState == WebSocket.open;

  String? get activeConversationId => _conversationId;

  /// Opens a live connection for one private conversation.
  /// Reconnects automatically with a capped exponential delay.
  Future<void> connect(String conversationId) async {
    final cleaned = conversationId.trim();
    if (cleaned.isEmpty) return;

    if (_conversationId == cleaned && isConnected) return;

    await disconnect();
    _conversationId = cleaned;
    _shouldReconnect = true;
    _reconnectAttempt = 0;
    await _connectCurrent();
  }

  /// Stops the socket and disables automatic reconnection.
  Future<void> disconnect() async {
    _shouldReconnect = false;
    _conversationId = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    final socket = _socket;
    _socket = null;

    final subscription = _subscription;
    _subscription = null;
    if (subscription != null) {
      try {
        await subscription.cancel();
      } catch (_) {}
    }

    if (socket != null) {
      try {
        await socket.close(WebSocketStatus.normalClosure, 'Chat closed');
      } catch (_) {}
    }

    _emit('transport.disconnected');
  }

  /// Sends an ephemeral typing signal. It never sends message text.
  void setTyping(bool isTyping) {
    _sendEvent({'type': isTyping ? 'typing.start' : 'typing.stop'});
  }

  /// Sends a lightweight application-level ping when needed by the UI.
  void ping() {
    _sendEvent({'type': 'ping'});
  }

  void _sendEvent(Map<String, dynamic> event) {
    final socket = _socket;
    if (socket == null || socket.readyState != WebSocket.open) return;

    try {
      socket.add(jsonEncode(event));
    } catch (_) {
      _emit('transport.send_error');
    }
  }

  Future<void> _connectCurrent() async {
    if (!_shouldReconnect || _conversationId == null || isConnected) return;

    final pending = _connecting;
    if (pending != null) {
      await pending;
      return;
    }

    final conversationId = _conversationId!;
    final task = _openSocket(conversationId);
    _connecting = task;

    try {
      await task;
    } finally {
      if (identical(_connecting, task)) {
        _connecting = null;
      }
    }
  }

  Future<void> _openSocket(String conversationId) async {
    WebSocket? candidate;

    try {
      await SocialGuestSessionService.instance.ensureSession();
      final token = await SocialSessionStorage.instance.readToken();

      if (token == null || token.isEmpty) {
        throw const SocketException('Social session token is missing.');
      }

      final httpsUri = Uri.parse(
        AppConfig.buildBackendUrl('/v1/social/realtime'),
      );
      final socketUri = httpsUri.replace(
        scheme: httpsUri.scheme == 'https' ? 'wss' : 'ws',
        queryParameters: {'conversationId': conversationId},
      );

      candidate = await WebSocket.connect(
        socketUri.toString(),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ).timeout(_connectTimeout);

      if (!_shouldReconnect || _conversationId != conversationId) {
        await candidate.close(
          WebSocketStatus.normalClosure,
          'Conversation changed',
        );
        return;
      }

      candidate.pingInterval = _pingInterval;
      _socket = candidate;
      _reconnectAttempt = 0;
      _emit('transport.connected');

      final activeSocket = candidate;
      _subscription = activeSocket.listen(
        _handleSocketData,
        onError: (Object error, StackTrace stackTrace) {
          _handleSocketEnd(activeSocket, error: error);
        },
        onDone: () => _handleSocketEnd(activeSocket),
        cancelOnError: true,
      );
    } catch (error) {
      if (candidate != null && !identical(candidate, _socket)) {
        try {
          await candidate.close(
            WebSocketStatus.goingAway,
            'Connection setup failed',
          );
        } catch (_) {}
      }

      _emit('transport.connection_error', details: _safeError(error));
      _scheduleReconnect();
    }
  }

  void _handleSocketData(dynamic data) {
    String raw;

    if (data is String) {
      raw = data;
    } else if (data is List<int>) {
      try {
        raw = utf8.decode(data, allowMalformed: true);
      } catch (_) {
        return;
      }
    } else {
      return;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;

      _events.add(
        SocialRealtimeEvent.fromJson(
          Map<String, dynamic>.from(decoded),
        ),
      );
    } catch (_) {
      // Ignore malformed frames; REST polling remains available.
    }
  }

  void _handleSocketEnd(WebSocket socket, {Object? error}) {
    if (!identical(_socket, socket)) return;

    _socket = null;
    _subscription = null;
    _emit(
      error == null ? 'transport.disconnected' : 'transport.connection_error',
      details: error == null ? null : _safeError(error),
    );
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (!_shouldReconnect || _conversationId == null) return;
    if (_reconnectTimer?.isActive == true) return;

    _reconnectAttempt++;
    final seconds = switch (_reconnectAttempt) {
      1 => 1,
      2 => 2,
      3 => 4,
      4 => 8,
      5 => 15,
      _ => 30,
    };

    _reconnectTimer = Timer(Duration(seconds: seconds), () {
      _reconnectTimer = null;
      unawaited(_connectCurrent());
    });
  }

  void _emit(String type, {String? details}) {
    if (_events.isClosed) return;
    _events.add(
      SocialRealtimeEvent(
        type: type,
        data: <String, dynamic>{
          'type': type,
          if (details != null) 'details': details,
        },
      ),
    );
  }

  String _safeError(Object error) {
    final value = error.toString();
    if (value.length <= 180) return value;
    return value.substring(0, 180);
  }
}

class SocialRealtimeEvent {
  const SocialRealtimeEvent({
    required this.type,
    required this.data,
  });

  final String type;
  final Map<String, dynamic> data;

  String? get conversationId =>
      data['conversationId'] is String
          ? data['conversationId'] as String
          : null;

  factory SocialRealtimeEvent.fromJson(Map<String, dynamic> json) {
    return SocialRealtimeEvent(
      type: json['type'] is String ? json['type'] as String : 'unknown',
      data: json,
    );
  }
}
