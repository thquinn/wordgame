import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;

class RoomPresence {
  final Map<String, dynamic> payload;
  RoomPresence(this.payload);
}

class RoomPresenceEntry {
  final List<RoomPresence> presences;
  RoomPresenceEntry(Map<String, dynamic> payload)
      : presences = [RoomPresence(payload)];
}

/// The room's live transport. Game rules and rendering stay in the Flutter app.
class RoomChannel {
  static const serverUrl = String.fromEnvironment(
    'ROOM_SERVER_URL',
    defaultValue: 'ws://127.0.0.1:8787',
  );

  final String roomID;
  final String username;
  final void Function(Map<String, dynamic>?, {required bool created}) onGame;
  final void Function() onPresence;
  final void Function(Map<String, dynamic>) onNotification;
  final void Function(Map<String, dynamic>) onAssist;

  html.WebSocket? _socket;
  Timer? _reconnectTimer;
  Timer? _presenceTimer;
  Completer<void>? _ready;
  final Map<int, Completer<Map<String, dynamic>>> _requests = {};
  final Map<String, Map<String, dynamic>> _players = {};
  Map<String, dynamic> _latestPresence;
  String? _sessionID;
  String? _adminID;
  String? joinTime;
  int _nextRequestID = 1;
  int _reconnectAttempt = 0;
  bool _disposed = false;
  bool connected = false;

  RoomChannel({
    required this.roomID,
    required this.username,
    required Map<String, dynamic> initialPresence,
    required this.onGame,
    required this.onPresence,
    required this.onNotification,
    required this.onAssist,
  }) : _latestPresence = initialPresence;

  bool get isAdmin => connected && _sessionID != null && _sessionID == _adminID;
  String get adminUsername => _players[_adminID]?['username'] as String? ?? '';

  List<RoomPresenceEntry> presenceState() =>
      _players.values.map((payload) => RoomPresenceEntry(payload)).toList();

  Future<void> connect() async {
    _ready = Completer<void>();
    _open();
    await _ready!.future.timeout(const Duration(seconds: 12));
  }

  Uri _roomUri() {
    final base = Uri.parse(serverUrl);
    final scheme = switch (base.scheme) {
      'https' => 'wss',
      'http' => 'ws',
      'ws' || 'wss' => base.scheme,
      _ => throw FormatException('ROOM_SERVER_URL must use http(s) or ws(s)'),
    };
    return base.replace(
        scheme: scheme, path: '/room', queryParameters: {'room': roomID});
  }

  void _open() {
    if (_disposed) return;
    try {
      final socket = html.WebSocket(_roomUri().toString());
      _socket = socket;
      socket.onOpen.listen((_) {
        if (!identical(_socket, socket)) return;
        socket.send(jsonEncode({
          'type': 'join',
          'username': username,
          'presence': _latestPresence,
        }));
      });
      socket.onMessage.listen((event) => _receive(event.data));
      socket.onClose.listen((_) => _closed(socket));
      socket.onError.listen((_) => socket.close());
    } catch (error) {
      if (_ready != null && !_ready!.isCompleted) _ready!.completeError(error);
      _scheduleReconnect();
    }
  }

  void _receive(dynamic raw) {
    if (raw is! String) return;
    Map<String, dynamic> message;
    try {
      message = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return;
    }
    switch (message['type']) {
      case 'welcome':
        _sessionID = message['session_id'] as String?;
        joinTime = message['join_time'] as String?;
        connected = true;
        _reconnectAttempt = 0;
        _setRoster(message);
        onGame(_gameFromMessage(message), created: false);
        if (_ready != null && !_ready!.isCompleted) _ready!.complete();
      case 'roster':
        _setRoster(message);
      case 'player_updated':
        final id = message['session_id'];
        final payload = message['payload'];
        if (id is String && payload is Map) {
          _players[id] = Map<String, dynamic>.from(payload);
          onPresence();
        }
      case 'game_created':
        onGame(_gameFromMessage(message), created: true);
      case 'game_updated':
        onGame(_gameFromMessage(message), created: false);
      case 'broadcast':
        final payload = message['payload'];
        if (payload is! Map) return;
        final value = Map<String, dynamic>.from(payload);
        if (message['event'] == 'notification') onNotification(value);
        if (message['event'] == 'assist') onAssist(value);
      case 'result':
        final id = message['request_id'];
        if (id is int) _requests.remove(id)?.complete(message);
    }
  }

  Map<String, dynamic>? _gameFromMessage(Map<String, dynamic> message) {
    final value = message['game'];
    return value is Map ? Map<String, dynamic>.from(value) : null;
  }

  void _setRoster(Map<String, dynamic> message) {
    _players.clear();
    for (final entry in (message['players'] as List? ?? const [])) {
      if (entry is! Map ||
          entry['session_id'] is! String ||
          entry['payload'] is! Map) continue;
      _players[entry['session_id'] as String] =
          Map<String, dynamic>.from(entry['payload'] as Map);
    }
    _adminID = message['admin_id'] as String?;
    onPresence();
  }

  void _closed(html.WebSocket socket) {
    if (!identical(_socket, socket)) return;
    _presenceTimer?.cancel();
    _presenceTimer = null;
    connected = false;
    _socket = null;
    _players.clear();
    onPresence();
    for (final request in _requests.values) {
      if (!request.isCompleted)
        request.completeError(StateError('Room connection closed'));
    }
    _requests.clear();
    if (_disposed) return;
    if (_ready != null && !_ready!.isCompleted) {
      _ready!.completeError(StateError('Could not join room'));
    }
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_disposed || _reconnectTimer != null) return;
    final seconds = 1 << _reconnectAttempt.clamp(0, 5);
    _reconnectAttempt++;
    _reconnectTimer = Timer(Duration(seconds: seconds), () {
      _reconnectTimer = null;
      _open();
    });
  }

  Future<void> track(Map<String, dynamic> presence) async {
    _latestPresence = presence;
    if (_sessionID != null) {
      _players[_sessionID!] = {
        'username': username,
        'join_time': joinTime,
        'cursor': presence['cursor'],
        'provisional_tiles': presence['provisional_tiles'],
      };
      onPresence();
    }
    if (connected && _socket?.readyState == 1 && _presenceTimer == null) {
      _presenceTimer = Timer(const Duration(milliseconds: 40), () {
        _presenceTimer = null;
        if (connected && _socket?.readyState == 1) {
          _socket!.send(jsonEncode({
            'type': 'presence',
            'presence': _latestPresence,
          }));
        }
      });
    }
  }

  Future<void> sendBroadcastMessage(
      {required String event, required Map<String, dynamic> payload}) async {
    if (!connected || _socket?.readyState != 1) return;
    _socket!.send(
        jsonEncode({'type': 'broadcast', 'event': event, 'payload': payload}));
  }

  Future<Map<String, dynamic>> _command(
      String type, Map<String, dynamic> data) async {
    if (!connected || _socket?.readyState != 1)
      throw StateError('Room is reconnecting');
    final id = _nextRequestID++;
    final response = Completer<Map<String, dynamic>>();
    _requests[id] = response;
    _socket!.send(jsonEncode({'type': type, 'request_id': id, ...data}));
    try {
      return await response.future.timeout(const Duration(seconds: 12));
    } finally {
      _requests.remove(id);
    }
  }

  Future<Map<String, dynamic>> startGame() => _command('start_game', {});

  Future<Map<String, dynamic>> commitMove(
          int version, Map<String, dynamic> state) =>
      _command('commit_move', {'version': version, 'state': state});

  void dispose() {
    _disposed = true;
    _reconnectTimer?.cancel();
    _presenceTimer?.cancel();
    _socket?.close();
    _socket = null;
    connected = false;
  }
}
