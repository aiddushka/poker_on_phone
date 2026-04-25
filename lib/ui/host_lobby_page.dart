import 'dart:io';

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
  final _myNameController = TextEditingController(text: 'Host');
  final _connectedPlayers = <String>[];
  String _hostAddress = '0.0.0.0:5055';
  int _startingCredits = 1000;
  bool _hosting = false;

  @override
  void initState() {
    super.initState();
    _lan.peerConnected.listen((peer) {
      if (!mounted) return;
      setState(() {
        if (!_connectedPlayers.contains(peer)) {
          _connectedPlayers.add(peer);
        }
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
        ? 'Host'
        : _myNameController.text.trim();
    final players = [myName, ..._connectedPlayers.map((e) => 'Player $e')];
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GameRoomPage(
          playerNames: players,
          startingCredits: _startingCredits,
          meName: myName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Host LAN Lobby')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _myNameController,
              decoration: const InputDecoration(labelText: 'Your Name'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _portController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Port'),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: _hosting ? null : _startHosting,
                  child: const Text('Host LAN'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('IP and port for Join: $_hostAddress'),
            const SizedBox(height: 16),
            Text(
              'Starting credits: $_startingCredits AidCoin',
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
              'Connected devices (${_connectedPlayers.length}):',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _connectedPlayers.isEmpty
                  ? const Center(child: Text('No players joined yet'))
                  : ListView.builder(
                      itemCount: _connectedPlayers.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          leading: const Icon(Icons.devices),
                          title: Text(_connectedPlayers[index]),
                        );
                      },
                    ),
            ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _hosting ? _openGame : null,
                child: const Text('START GAME'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
