import 'dart:math';

import 'package:flutter/material.dart';
import 'package:pocker_in_phone/crypto/sra.dart';
import 'package:pocker_in_phone/game/playing_card.dart';
import 'package:pocker_in_phone/game/poker_hand.dart';
import 'package:pocker_in_phone/network/lan_peer.dart';

class PokerTablePage extends StatefulWidget {
  const PokerTablePage({super.key});

  @override
  State<PokerTablePage> createState() => _PokerTablePageState();
}

class _PokerTablePageState extends State<PokerTablePage> {
  final _sra = SraCrypto();
  final _lan = LanPeerService();
  final _evaluator = PokerHandEvaluator();
  final _random = Random.secure();

  List<PlayingCard> _playerCards = const [];
  PokerHandResult? _result;
  String _status = 'Ready';
  bool _isHosting = false;

  @override
  void initState() {
    super.initState();
    _lan.messages.listen((message) {
      setState(() {
        _status = 'LAN message: ${message.type}';
      });
    });
  }

  @override
  void dispose() {
    _lan.dispose();
    super.dispose();
  }

  Future<void> _host() async {
    try {
      await _lan.host(port: 5055);
      setState(() {
        _isHosting = true;
        _status = 'Hosting on port 5055';
      });
    } catch (_) {
      setState(() => _status = 'Hosting failed');
    }
  }

  Future<void> _join() async {
    try {
      await _lan.join(host: '192.168.0.100', port: 5055);
      setState(() => _status = 'Connected to host');
    } catch (_) {
      setState(() => _status = 'Connection failed');
    }
  }

  Future<void> _dealMentalPokerRound() async {
    final deck = PlayingCard.standardDeck()..shuffle(_random);
    final keys = List.generate(3, (_) => _sra.generateKeyPair());

    final encryptedDeck = deck.map((card) {
      var value = _sra.encodeCardId(card.id);
      for (final key in keys) {
        value = key.encrypt(value);
      }
      return value;
    }).toList()..shuffle(_random);

    final hand = <PlayingCard>[];
    for (var i = 0; i < 5; i++) {
      var value = encryptedDeck[i];
      for (final key in keys.reversed) {
        value = key.decrypt(value);
      }
      final cardId = _sra.decodeCardId(value);
      hand.add(deck.firstWhere((c) => c.id == cardId));
    }

    setState(() {
      _playerCards = hand;
      _result = _evaluator.evaluate5(hand);
      _status = 'New encrypted round dealt';
    });

    await _lan.send(
      LanMessage('round_dealt', {
        'hand': hand.map((c) => c.shortLabel).toList(),
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mental Poker LAN (SRA)')),
      body: Column(
        children: [
          const SizedBox(height: 16),
          Text(_status, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: _playerCards
                .asMap()
                .entries
                .map(
                  (entry) => AnimatedContainer(
                    duration: Duration(milliseconds: 250 + entry.key * 120),
                    curve: Curves.easeOutBack,
                    transform: Matrix4.translationValues(
                      0,
                      _playerCards.isEmpty ? 30 : 0,
                      0,
                    ),
                    width: 70,
                    height: 96,
                    decoration: BoxDecoration(
                      color: const Color(0xFF173E2A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black45,
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        entry.value.shortLabel,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 20),
          Text(
            _result?.title ?? 'Deal cards to evaluate hand',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: _isHosting ? null : _host,
                  icon: const Icon(Icons.wifi_tethering),
                  label: const Text('Host LAN'),
                ),
                FilledButton.icon(
                  onPressed: _join,
                  icon: const Icon(Icons.link),
                  label: const Text('Join LAN'),
                ),
                FilledButton.icon(
                  onPressed: _dealMentalPokerRound,
                  icon: const Icon(Icons.casino),
                  label: const Text('Deal Round'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
