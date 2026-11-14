import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../config/app_config.dart';
import 'social_guest_session_service.dart';
import 'social_session_storage.dart';

/// Optional realtime event channel for Sa7bi Connect private conversations.
///
/// REST remains the source of truth for loading and sending messages. The
/// socket carries live notifications and typing state only. The chat screen
/// keeps REST polling as a fallback for weak or unavailable networks.
class SocialRealtimeService {
  SocialRealtimeService._();

  static final SocialRealtimeService instance = SocialRealtimeService._();

  static const Duration _connectTimeout = Duration(seconds: 12);
  static const Duration _pingInterval = Duration(seconds: 25);

  static final RegExp _conversationIdPattern =
      RegExp(r'^[a-f0-9-]{36}$', caseSensitive: false);

  final StreamController<SocialRealtimeEvent> _events =
      StreamController<SocialRealtimeEvent>.broadcast(sync: true);

  final Set<int> _connectingGenerations = <int>{};

  WebSocket? _socket;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;

  String? _conversationId;
  bool _shouldReconnect = false;
  int _generation = 0;
  int _reconnectAttempt = 0;

  Stream<SocialRealtimeEvent> get events => _events.stream;

  bool get isConnected => _socket?.readyState == WebSocket.open;

  String? get activeConversationId => _conversationId;

  /// Opens a live connection for one private conversation.
  ///
  /// A generation number makes a late connection attempt harmless when the
  /// user leaves a conversation or opens another one before the handshake
  /// finishes.
  Future<void> connect(String conversationId) async {
    final cleaned = conversationId.trim();

    if (!_conversationIdPattern.hasMatch(cleaned)) {
      throw ArgumentError.value(
        conversationId,
        'conversationId',
        'A valid conversation UUID is required.',
      );
    }

    if (_conversationId == cleaned &&
        _shouldReconnect &&
        (isConnected || _connectingGenerations.contains(_generation))) {
      return;
    }

    await disconnect();

    _conversationId = cleaned;
    _shouldReconnect = true;
    _reconnectAttempt = 0;
    final generation = ++_generation;

    await _connectCurrent(generation);
  }

  /// Stops the socket and invalidates every in-flight connection attempt.
  Future<void> disconnect() async {
    final previousConversationId = _conversationId;

    _generation++;
    _shouldReconnect = false;
    _conversationId = null;
    _reconnectAttempt = 0;

    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    final socket = _socket;
    _socket = null;

    final subscription = _subscription;
    _subscription = null;

    if (subscription != null) {
      try {
        await subscription.cancel();
      } catch (_) {
        // A socket may already have ended while cancellation was requested.
      }
    }

    if (socket != null) {
      try {
        await socket.close(
          WebSocketStatus.normalClosure,
          'Chat closed',
        );
      } catch (_) {
        // The transport may already be closed.
      }
    }

    _emit(
      'transport.disconnected',
      conversationId: previousConversationId,
    );
  }

  /// Sends an ephemeral typing signal. Message text is never sent here.
  void setTyping(bool isTyping) {
    _sendEvent(<String, dynamic>{
      'type': isTyping ? 'typing.start' : 'typing.stop',
    });
  }

  /// Sends a lightweight application-level ping.
  void ping() {
    _sendEvent(const <String, dynamic>{'type': 'ping'});
  }

  void _sendEvent(Map<String, dynamic> event) {
    final socket = _socket;
    if (socket == null || socket.readyState != WebSocket.open) return;

    try {
      socket.add(jsonEncode(event));
    } catch (_) {
      _emit(
        'transport.send_error',
        conversationId: _conversationId,
      );
    }
  }

  Future<void> _connectCurrent(int generation) async {
    final conversationId = _conversationId;

    if (conversationId == null ||
        !_isCurrent(generation, conversationId) ||
        isConnected ||
        !_connectingGenerations.add(generation)) {
      return;
    }

    try {
      await _openSocket(conversationId, generation);
    } finally {
      _connectingGenerations.remove(generation);
    }
  }

  Future<WebSocket> _connectSocket(
    Uri socketUri,
    String token,
  ) async {
    final completer = Completer<WebSocket>();

    final timeoutTimer = Timer(_connectTimeout, () {
      if (!completer.isCompleted) {
        completer.completeError(
          TimeoutException(
            'WebSocket connection timed out.',
            _connectTimeout,
          ),
        );
      }
    });

    // Future.timeout alone does not cancel WebSocket.connect. Close a socket
    // that finishes after the timeout so it cannot become an orphaned socket.
    WebSocket.connect(
      socketUri.toString(),
      headers: <String, String>{
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    ).then(
      (socket) {
        if (completer.isCompleted) {
          unawaited(
            socket.close(
              WebSocketStatus.goingAway,
              'Connection timed out',
            ),
          );
        } else {
          completer.complete(socket);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
      },
    );

    try {
      return await completer.future;
    } finally {
      timeoutTimer.cancel();
    }
  }

  Future<void> _openSocket(
    String conversationId,
    int generation,
  ) async {
    WebSocket? candidate;

    try {
      await SocialGuestSessionService.instance.ensureSession();

      if (!_isCurrent(generation, conversationId)) return;

      final token = await SocialSessionStorage.instance.readToken();
      if (token == null || token.isEmpty) {
        throw const SocketException('Social session token is missing.');
      }

      if (!_isCurrent(generation, conversationId)) return;

      final httpsUri = Uri.parse(
        AppConfig.buildBackendUrl('/v1/social/realtime'),
      );

      final socketUri = httpsUri.replace(
        scheme: httpsUri.scheme == 'https' ? 'wss' : 'ws',
        queryParameters: <String, String>{
          'conversationId': conversationId,
        },
      );

      candidate = await _connectSocket(socketUri, token);

      // The user may have left this chat while the handshake was pending.
      if (!_isCurrent(generation, conversationId)) {
        await candidate.close(
          WebSocketStatus.normalClosure,
          'Conversation changed',
        );
        return;
      }

      candidate.pingInterval = _pingInterval;
      _socket = candidate;
      _reconnectAttempt = 0;

      _emit(
        'transport.connected',
        conversationId: conversationId,
      );

      final activeSocket = candidate;
      _subscription = activeSocket.listen(
        _handleSocketData,
        onError: (Object error, StackTrace stackTrace) {
          _handleSocketEnd(
            activeSocket,
            generation,
            error: error,
          );
        },
        onDone: () {
          _handleSocketEnd(activeSocket, generation);
        },
        cancelOnError: true,
      );
    } catch (error) {
      if (candidate != null && !identical(candidate, _socket)) {
        try {
          await candidate.close(
            WebSocketStatus.goingAway,
            'Connection setup failed',
          );
        } catch (_) {
          // Ignore cleanup errors after a failed handshake.
        }
      }

      if (!_isCurrent(generation, conversationId)) return;

      _emit(
        'transport.connection_error',
        conversationId: conversationId,
        details: _safeError(error),
      );
      _scheduleReconnect(generation, conversationId);
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

  void _handleSocketEnd(
    WebSocket socket,
    int generation, {
    Object? error,
  }) {
    // Ignore callbacks from an older socket after a chat switch/reconnect.
    if (!identical(_socket, socket)) return;

    _socket = null;
    _subscription = null;

    final conversationId = _conversationId;
    _emit(
      error == null
          ? 'transport.disconnected'
          : 'transport.connection_error',
      conversationId: conversationId,
      details: error == null ? null : _safeError(error),
    );

    if (conversationId != null) {
      _scheduleReconnect(generation, conversationId);
    }
  }

  void _scheduleReconnect(
    int generation,
    String conversationId,
  ) {
    if (!_isCurrent(generation, conversationId)) return;
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
      if (_isCurrent(generation, conversationId)) {
        unawaited(_connectCurrent(generation));
      }
    });
  }

  bool _isCurrent(int generation, String conversationId) {
    return _shouldReconnect &&
        _generation == generation &&
        _conversationId == conversationId;
  }

  void _emit(
    String type, {
    String? conversationId,
    String? details,
  }) {
    if (_events.isClosed) return;

    _events.add(
      SocialRealtimeEvent(
        type: type,
        data: <String, dynamic>{
          'type': type,
          if (conversationId != null) 'conversationId': conversationId,
          if (details != null) 'details': details,
        },
      ),
    );
  }

  String _safeError(Object error) {
    // Do not expose request URLs, headers, or session material in UI/logs.
    return error.runtimeType.toString();
  }
}

/// A decoded event from the private-conversation WebSocket.
class SocialRealtimeEvent {
  const SocialRealtimeEvent({
    required this.type,
    required this.data,
  });

  final String type;
  final Map<String, dynamic> data;

  String? get conversationId {
    final value = data['conversationId'];
    return value is String ? value : null;
  }

  bool? get isTyping {
    final value = data['isTyping'];
    return value is bool ? value : null;
  }

  bool? get isOnline {
    final value = data['online'];
    return value is bool ? value : null;
  }

  factory SocialRealtimeEvent.fromJson(Map<String, dynamic> json) {
    return SocialRealtimeEvent(
      type: json['type'] is String
          ? json['type'] as String
          : 'unknown',
      data: Map<String, dynamic>.from(json),
    );
  }
}
