import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:pocker_in_phone/core/i18n.dart';
import 'package:pocker_in_phone/network/lan_peer.dart';
import 'package:pocker_in_phone/ui/game_room_page.dart';

class JoinLobbyPage extends StatefulWidget {
  const JoinLobbyPage({super.key});

  @override
  State<JoinLobbyPage> createState() => _JoinLobbyPageState();
}

class _JoinLobbyPageState extends State<JoinLobbyPage> {
  final _lan = LanPeerService();
  final _nameController = TextEditingController(text: 'Игрок');
  final _hostController = TextEditingController();
  final _portController = TextEditingController(text: '5055');
  final _myId =
      'player-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(9999)}';
  Timer? _heartbeatTimer;
  String _status = 'Введите адрес хоста';
  bool _joined = false;

  @override
  void initState() {
    super.initState();
    _prefillHostHint();
    _lan.messages.listen((message) {
      if (!mounted) return;
      if (message.type == 'game_start') {
        final startingCredits = message.payload['startingCredits'] as int;
        final playerIds = (message.payload['playerIds'] as List<dynamic>)
            .cast<String>();
        final playerNames = Map<String, String>.from(
          message.payload['playerNames'] as Map,
        );
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => GameRoomPage(
              lan: _lan,
              isHost: false,
              meId: _myId,
              meName: playerNames[_myId] ?? _nameController.text.trim(),
              startingCredits: startingCredits,
              initialPlayerIds: playerIds,
              initialPlayerNames: playerNames,
            ),
          ),
        );
      } else {
        setState(() {
          _status = 'Событие: ${message.type}';
        });
      }
    });
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    if (_joined) {
      _lan.send(LanMessage('leave', {'playerId': _myId}));
    }
    _nameController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _lan.dispose();
    super.dispose();
  }

  Future<void> _prefillHostHint() async {
    final ip = await _detectLocalIpv4();
    if (!mounted) return;
    final parts = ip.split('.');
    if (parts.length == 4) {
      _hostController.text = '${parts[0]}.${parts[1]}.${parts[2]}.';
    }
  }

  Future<String> _detectLocalIpv4() async {
    final interfaces = await NetworkInterface.list(
      includeLoopback: false,
      type: InternetAddressType.IPv4,
    );
    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        if (!address.isLoopback) {
          return address.address;
        }
      }
    }
    return '0.0.0.0';
  }

  Future<void> _joinGame() async {
    final host = _hostController.text.trim();
    final port = int.tryParse(_portController.text.trim());
    if (host.isEmpty || port == null) {
      setState(() => _status = 'Некорректный IP или порт');
      return;
    }
    try {
      await _lan.join(host: host, port: port);
      final myName = _nameController.text.trim().isEmpty
          ? 'Игрок'
          : _nameController.text.trim();
      await _lan.send(
        LanMessage('join_hello', {'playerId': _myId, 'playerName': myName}),
      );
      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        _lan.send(LanMessage('heartbeat', {'playerId': _myId}));
      });
      if (!mounted) return;
      setState(() {
        _joined = true;
        _status = tr(context, 'waiting_host');
      });
    } catch (_) {
      setState(() => _status = 'Не удалось подключиться');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr(context, 'join_lobby'))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: tr(context, 'your_name')),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _hostController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: tr(context, 'host_ip'),
                hintText: '192.168.10.183',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _portController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: tr(context, 'port')),
            ),
            const SizedBox(height: 12),
            Align(alignment: Alignment.centerLeft, child: Text(_status)),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _joined ? null : _joinGame,
                child: Text(tr(context, 'connect_game')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
