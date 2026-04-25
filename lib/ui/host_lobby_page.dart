import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:pocker_in_phone/network/lan_peer.dart';
import 'package:pocker_in_phone/ui/game_room_page.dart';

class HostLobbyPage extends StatefulWidget {
  const HostLobbyPage({super.key});

  @override
  State<HostLobbyPage> createState() => _HostLobbyPageState();
}

class _HostLobbyPageState extends State<HostLobbyPage> {
  final _lan = LanPeerService();
  final _portController = TextEditingController(text: '5055');
  final _myNameController = TextEditingController(text: 'Хост');
  final _connectedPlayers = <String, String>{};
  final _myId =
      'host-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(9999)}';
  String _hostAddress = '0.0.0.0:5055';
  int _startingCredits = 1000;
  bool _hosting = false;

  @override
  void initState() {
    super.initState();
    _lan.messages.listen((message) {
      if (message.type != 'join_hello' || !mounted) return;
      final playerId = message.payload['playerId'] as String;
      final playerName = message.payload['playerName'] as String;
      setState(() {
        _connectedPlayers[playerId] = playerName;
      });
    });
  }

  @override
  void dispose() {
    _portController.dispose();
    _myNameController.dispose();
    _lan.dispose();
    super.dispose();
  }

  Future<void> _startHosting() async {
    final port = int.tryParse(_portController.text.trim()) ?? 5055;
    await _lan.host(port: port);
    final ip = await _detectLocalIpv4();
    if (!mounted) return;
    setState(() {
      _hosting = true;
      _hostAddress = '$ip:$port';
    });
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

  void _openGame() {
    final myName = _myNameController.text.trim().isEmpty
        ? 'Хост'
        : _myNameController.text.trim();
    final playerNames = <String, String>{_myId: myName, ..._connectedPlayers};
    final playerIds = playerNames.keys.toList();
    _lan.send(
      LanMessage('game_start', {
        'startingCredits': _startingCredits,
        'playerIds': playerIds,
        'playerNames': playerNames,
      }),
    );
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameRoomPage(
          lan: _lan,
          isHost: true,
          meId: _myId,
          startingCredits: _startingCredits,
          meName: myName,
          initialPlayerIds: playerIds,
          initialPlayerNames: playerNames,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Лобби хоста')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _myNameController,
              decoration: const InputDecoration(labelText: 'Ваше имя'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _portController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Порт'),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: _hosting ? null : _startHosting,
                  child: const Text('Запустить стол'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Адрес для подключения: $_hostAddress'),
            const SizedBox(height: 16),
            Text(
              'Стартовые кредиты: $_startingCredits AidCoin',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Slider(
              min: 200,
              max: 5000,
              divisions: 48,
              value: _startingCredits.toDouble(),
              label: '$_startingCredits',
              onChanged: (v) => setState(() => _startingCredits = v.toInt()),
            ),
            const SizedBox(height: 10),
            Text(
              'Подключившиеся игроки (${_connectedPlayers.length}):',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _connectedPlayers.values.isEmpty
                  ? const Center(child: Text('Пока никто не подключился'))
                  : ListView.builder(
                      itemCount: _connectedPlayers.length,
                      itemBuilder: (context, index) {
                        final entry = _connectedPlayers.entries.elementAt(
                          index,
                        );
                        return ListTile(
                          leading: const Icon(Icons.devices),
                          title: Text(entry.value),
                          subtitle: Text(entry.key),
                        );
                      },
                    ),
            ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _hosting ? _openGame : null,
                child: const Text('НАЧАТЬ ИГРУ'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
