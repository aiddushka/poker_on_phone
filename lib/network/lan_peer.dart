import 'dart:async';
import 'dart:convert';
import 'dart:io';

class LanMessage {
  const LanMessage(this.type, this.payload);

  final String type;
  final Map<String, dynamic> payload;

  Map<String, dynamic> toJson() => {'type': type, 'payload': payload};

  static LanMessage fromJson(Map<String, dynamic> json) {
    return LanMessage(
      json['type'] as String,
      Map<String, dynamic>.from(json['payload'] as Map),
    );
  }
}

class LanPeerService {
  ServerSocket? _server;
  Socket? _client;
  final _messageController = StreamController<LanMessage>.broadcast();
  final _connections = <Socket>{};

  Stream<LanMessage> get messages => _messageController.stream;

  Future<void> host({required int port}) async {
    _server = await ServerSocket.bind(InternetAddress.anyIPv4, port);
    _server!.listen((socket) {
      _connections.add(socket);
      _listenSocket(socket);
    });
  }

  Future<void> join({required String host, required int port}) async {
    _client = await Socket.connect(
      host,
      port,
      timeout: const Duration(seconds: 3),
    );
    _listenSocket(_client!);
  }

  Future<void> send(LanMessage message) async {
    final line = '${jsonEncode(message.toJson())}\n';
    if (_client != null) {
      _client!.write(line);
      return;
    }
    for (final connection in _connections) {
      connection.write(line);
    }
  }

  void _listenSocket(Socket socket) {
    socket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      final data = jsonDecode(line) as Map<String, dynamic>;
      _messageController.add(LanMessage.fromJson(data));
    });
  }

  Future<void> dispose() async {
    for (final c in _connections) {
      await c.close();
    }
    _connections.clear();
    await _client?.close();
    await _server?.close();
    await _messageController.close();
  }
}
