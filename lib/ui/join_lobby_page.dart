import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pocker_in_phone/network/lan_peer.dart';
import 'package:pocker_in_phone/ui/game_room_page.dart';

class JoinLobbyPage extends StatefulWidget {
  const JoinLobbyPage({super.key});

  @override
  State<JoinLobbyPage> createState() => _JoinLobbyPageState();
}

class _JoinLobbyPageState extends State<JoinLobbyPage> {
  final _lan = LanPeerService();
  final _nameController = TextEditingController(text: 'Player');
  final _hostController = TextEditingController();
  final _portController = TextEditingController(text: '5055');
  String _status = 'Enter host address';

  @override
  void initState() {
    super.initState();
    _prefillHostHint();
    _lan.messages.listen((message) {
      if (!mounted) return;
      setState(() {
        _status = 'Connected. Last event: ${message.type}';
      });
    });
  }

  @override
  void dispose() {
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
      setState(() => _status = 'Invalid host or port');
      return;
    }
    try {
      await _lan.join(host: host, port: port);
      final myName = _nameController.text.trim().isEmpty
          ? 'Player'
          : _nameController.text.trim();
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GameRoomPage(
            playerNames: [myName, 'Host'],
            startingCredits: 1000,
            meName: myName,
          ),
        ),
      );
    } catch (_) {
      setState(() => _status = 'Connection failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join LAN Lobby')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Your Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _hostController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Host IP',
                hintText: '192.168.10.183',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _portController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Port'),
            ),
            const SizedBox(height: 12),
            Align(alignment: Alignment.centerLeft, child: Text(_status)),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _joinGame,
                child: const Text('JOIN GAME'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
