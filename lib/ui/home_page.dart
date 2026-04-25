import 'package:flutter/material.dart';
import 'package:pocker_in_phone/ui/host_lobby_page.dart';
import 'package:pocker_in_phone/ui/join_lobby_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Покер по LAN')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 260,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const HostLobbyPage()),
                    );
                  },
                  icon: const Icon(Icons.wifi_tethering),
                  label: const Text('Создать стол'),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: 260,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const JoinLobbyPage()),
                    );
                  },
                  icon: const Icon(Icons.link),
                  label: const Text('Подключиться'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
