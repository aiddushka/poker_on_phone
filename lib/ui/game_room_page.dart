import 'dart:math';

import 'package:flutter/material.dart';
import 'package:pocker_in_phone/game/playing_card.dart';
import 'package:pocker_in_phone/network/lan_peer.dart';

class GamePlayer {
  const GamePlayer({
    required this.id,
    required this.name,
    required this.credits,
    this.folded = false,
  });

  final String id;
  final String name;
  final int credits;
  final bool folded;

  GamePlayer copyWith({String? name, int? credits, bool? folded}) {
    return GamePlayer(
      id: id,
      name: name ?? this.name,
      credits: credits ?? this.credits,
      folded: folded ?? this.folded,
    );
  }
}

class GameRoomPage extends StatefulWidget {
  const GameRoomPage({
    super.key,
    required this.lan,
    required this.isHost,
    required this.meId,
    required this.meName,
    this.startingCredits = 1000,
    this.initialPlayerIds = const [],
    this.initialPlayerNames = const {},
  });

  final LanPeerService lan;
  final bool isHost;
  final String meId;
  final String meName;
  final int startingCredits;
  final List<String> initialPlayerIds;
  final Map<String, String> initialPlayerNames;

  @override
  State<GameRoomPage> createState() => _GameRoomPageState();
}

class _GameRoomPageState extends State<GameRoomPage> {
  final _random = Random.secure();
  List<GamePlayer> _players = const [];
  List<PlayingCard> _myCards = const [];
  List<PlayingCard> _communityCards = const [];
  Map<String, List<int>> _holeCardIdsByPlayer = const {};
  List<int> _communityCardIds = const [];
  int _pot = 0;
  int _currentBet = 20;
  int _raiseValue = 20;
  String _status = 'Ожидание начала игры';

  @override
  void initState() {
    super.initState();
    widget.lan.messages.listen(_handleNetworkMessage);
    if (widget.isHost) {
      _players = widget.initialPlayerIds
          .map(
            (id) => GamePlayer(
              id: id,
              name: widget.initialPlayerNames[id] ?? id,
              credits: widget.startingCredits,
            ),
          )
          .toList();
      _startNewRoundAndBroadcast();
    }
  }

  void _handleNetworkMessage(LanMessage message) {
    if (!mounted) return;
    switch (message.type) {
      case 'game_state':
        final playersRaw = (message.payload['players'] as List<dynamic>)
            .cast<Map<dynamic, dynamic>>();
        final holeCardsRaw = Map<String, dynamic>.from(
          (message.payload['holeCards'] as Map<dynamic, dynamic>?) ?? {},
        );
        final myCardsRaw = (holeCardsRaw[widget.meId] as List<dynamic>?) ?? [];
        final communityRaw =
            (message.payload['communityCards'] as List<dynamic>?) ?? [];
        setState(() {
          _players = playersRaw
              .map(
                (p) => GamePlayer(
                  id: p['id'] as String,
                  name: p['name'] as String,
                  credits: p['credits'] as int,
                  folded: p['folded'] as bool,
                ),
              )
              .toList();
          _pot = message.payload['pot'] as int;
          _currentBet = message.payload['currentBet'] as int;
          _status = message.payload['status'] as String;
          _holeCardIdsByPlayer = {
            for (final entry in holeCardsRaw.entries)
              entry.key: (entry.value as List<dynamic>).cast<int>(),
          };
          _communityCardIds = communityRaw.cast<int>();
          _myCards = myCardsRaw.map((id) => _cardFromId(id as int)).toList();
          _communityCards = communityRaw
              .map((id) => _cardFromId(id as int))
              .toList();
        });
        break;
      case 'player_action':
        if (widget.isHost) {
          final playerId = message.payload['playerId'] as String;
          final action = message.payload['action'] as String;
          final raiseBy = (message.payload['raiseBy'] as int?) ?? 0;
          _applyActionAsHost(
            playerId: playerId,
            action: action,
            raiseBy: raiseBy,
          );
        }
        break;
    }
  }

  PlayingCard _cardFromId(int id) => PlayingCard.standardDeck()[id];

  Future<void> _startNewRoundAndBroadcast() async {
    final deck = PlayingCard.standardDeck()..shuffle(_random);
    final holeCards = <String, List<int>>{};
    for (var i = 0; i < _players.length; i++) {
      holeCards[_players[i].id] = [deck[i * 2].id, deck[i * 2 + 1].id];
    }
    final community = [
      deck[_players.length * 2].id,
      deck[_players.length * 2 + 1].id,
      deck[_players.length * 2 + 2].id,
      deck[_players.length * 2 + 3].id,
      deck[_players.length * 2 + 4].id,
    ];
    _pot = 0;
    _currentBet = 20;
    _status = 'Игра началась. Префлоп';
    _holeCardIdsByPlayer = holeCards;
    _communityCardIds = community;
    _players = _players
        .map((p) => p.copyWith(credits: widget.startingCredits, folded: false))
        .toList();
    await _broadcastGameState(holeCards: holeCards, communityCards: community);
  }

  Future<void> _broadcastGameState({
    Map<String, List<int>>? holeCards,
    List<int>? communityCards,
  }) async {
    final payload = {
      'players': _players
          .map(
            (p) => {
              'id': p.id,
              'name': p.name,
              'credits': p.credits,
              'folded': p.folded,
            },
          )
          .toList(),
      'pot': _pot,
      'currentBet': _currentBet,
      'status': _status,
      'holeCards':
          holeCards ??
          {
            for (final p in _players)
              p.id: _holeCardIdsByPlayer[p.id] ?? <int>[],
          },
      'communityCards': communityCards ?? _communityCardIds,
    };
    _handleNetworkMessage(LanMessage('game_state', payload));
    await widget.lan.send(LanMessage('game_state', payload));
  }

  Future<void> _sendAction(String action) async {
    final payload = {
      'playerId': widget.meId,
      'action': action,
      'raiseBy': _raiseValue,
    };
    if (widget.isHost) {
      _applyActionAsHost(
        playerId: widget.meId,
        action: action,
        raiseBy: _raiseValue,
      );
      return;
    }
    await widget.lan.send(LanMessage('player_action', payload));
  }

  void _applyActionAsHost({
    required String playerId,
    required String action,
    required int raiseBy,
  }) {
    final index = _players.indexWhere((p) => p.id == playerId);
    if (index < 0) return;
    final player = _players[index];
    switch (action) {
      case 'fold':
        _players[index] = player.copyWith(folded: true);
        _status = '${player.name} сбросил карты';
        break;
      case 'check':
        _status = '${player.name} чек';
        break;
      case 'call':
        final pay = _currentBet.clamp(0, player.credits);
        _pot += pay;
        _players[index] = player.copyWith(credits: player.credits - pay);
        _status = '${player.name} колл $_currentBet';
        break;
      case 'raise':
        final total = _currentBet + raiseBy;
        final pay = total.clamp(0, player.credits);
        _pot += pay;
        _currentBet = total;
        _players[index] = player.copyWith(credits: player.credits - pay);
        _status = '${player.name} рейз +$raiseBy';
        break;
    }
    _broadcastGameState();
  }

  Widget _cardChip(PlayingCard card) {
    return Container(
      width: 58,
      height: 84,
      decoration: BoxDecoration(
        color: const Color(0xFF173E2A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white24),
      ),
      alignment: Alignment.center,
      child: Text(
        card.shortLabel,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Игровой стол')),
      body: Column(
        children: [
          const SizedBox(height: 10),
          Text(
            'Банк: $_pot AidCoin',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Text('Текущая ставка: $_currentBet AidCoin'),
          const SizedBox(height: 4),
          Text(_status),
          const SizedBox(height: 10),
          Text('Ваши карты', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Wrap(spacing: 8, children: _myCards.map(_cardChip).toList()),
          const SizedBox(height: 12),
          Text('Общие карты', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Wrap(spacing: 8, children: _communityCards.map(_cardChip).toList()),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: _players.length,
              itemBuilder: (context, index) {
                final player = _players[index];
                return ListTile(
                  leading: Icon(
                    player.folded ? Icons.block : Icons.person,
                    color: player.folded
                        ? Colors.redAccent
                        : Colors.greenAccent,
                  ),
                  title: Text(player.name),
                  subtitle: Text(player.folded ? 'Сбросил' : 'В игре'),
                  trailing: Text('${player.credits} AidCoin'),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text('Рейз:'),
                Expanded(
                  child: Slider(
                    min: 10,
                    max: 200,
                    divisions: 19,
                    value: _raiseValue.toDouble(),
                    label: '$_raiseValue',
                    onChanged: (v) => setState(() => _raiseValue = v.toInt()),
                  ),
                ),
                Text('$_raiseValue'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton(
                  onPressed: () => _sendAction('fold'),
                  child: const Text('Сбросить'),
                ),
                OutlinedButton(
                  onPressed: () => _sendAction('check'),
                  child: const Text('Чек'),
                ),
                FilledButton(
                  onPressed: () => _sendAction('call'),
                  child: const Text('Колл'),
                ),
                FilledButton(
                  onPressed: () => _sendAction('raise'),
                  child: const Text('Повысить'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
