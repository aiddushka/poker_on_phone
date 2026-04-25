import 'dart:math';

import 'package:flutter/material.dart';
import 'package:pocker_in_phone/game/poker_hand.dart';
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
  final _evaluator = PokerHandEvaluator();
  List<GamePlayer> _players = const [];
  List<PlayingCard> _myCards = const [];
  List<PlayingCard> _communityCards = const [];
  Map<String, List<int>> _holeCardIdsByPlayer = const {};
  List<int> _allCommunityCardIds = const [];
  List<String> _seatOrderIds = const [];
  int _pot = 0;
  int _currentBet = 20;
  int _raiseValue = 20;
  int _dealerSeatIndex = 0;
  int _turnSeatIndex = 0;
  int _streetIndex = 0;
  Set<String> _actedThisStreet = <String>{};
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
      _startNewRoundAndBroadcast(firstRound: true);
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
        final seatsRaw =
            (message.payload['seatOrderIds'] as List<dynamic>?) ?? [];
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
          _dealerSeatIndex = message.payload['dealerSeatIndex'] as int? ?? 0;
          _turnSeatIndex = message.payload['turnSeatIndex'] as int? ?? 0;
          _streetIndex = message.payload['streetIndex'] as int? ?? 0;
          _actedThisStreet =
              ((message.payload['actedThisStreet'] as List<dynamic>?) ?? [])
                  .cast<String>()
                  .toSet();
          _holeCardIdsByPlayer = {
            for (final entry in holeCardsRaw.entries)
              entry.key: (entry.value as List<dynamic>).cast<int>(),
          };
          _allCommunityCardIds = communityRaw.cast<int>();
          _seatOrderIds = seatsRaw.cast<String>();
          _myCards = myCardsRaw.map((id) => _cardFromId(id as int)).toList();
          _communityCards = _allCommunityCardIds
              .take(_visibleCommunityCountForStreet(_streetIndex))
              .map(_cardFromId)
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

  Future<void> _startNewRoundAndBroadcast({bool firstRound = false}) async {
    final deck = PlayingCard.standardDeck()..shuffle(_random);
    if (firstRound || _seatOrderIds.isEmpty) {
      _seatOrderIds = _players.map((p) => p.id).toList()..shuffle(_random);
      _dealerSeatIndex = _random.nextInt(_seatOrderIds.length);
    } else {
      _dealerSeatIndex = (_dealerSeatIndex + 1) % _seatOrderIds.length;
    }
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
    _streetIndex = 0;
    _actedThisStreet = <String>{};
    _turnSeatIndex = _nextActiveSeatAfter(_dealerSeatIndex);
    _status = 'Префлоп. Ход: ${_playerNameBySeat(_turnSeatIndex)}';
    _holeCardIdsByPlayer = holeCards;
    _allCommunityCardIds = community;
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
      'dealerSeatIndex': _dealerSeatIndex,
      'turnSeatIndex': _turnSeatIndex,
      'streetIndex': _streetIndex,
      'actedThisStreet': _actedThisStreet.toList(),
      'seatOrderIds': _seatOrderIds,
      'holeCards':
          holeCards ??
          {
            for (final p in _players)
              p.id: _holeCardIdsByPlayer[p.id] ?? <int>[],
          },
      'communityCards': communityCards ?? _allCommunityCardIds,
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
    final playerSeat = _seatOrderIds.indexOf(playerId);
    if (playerSeat != _turnSeatIndex) {
      return;
    }
    final player = _players[index];
    if (player.folded) return;
    switch (action) {
      case 'fold':
        _players[index] = player.copyWith(folded: true);
        _status = '${player.name} сбросил карты';
        _actedThisStreet.add(player.id);
        break;
      case 'check':
        _status = '${player.name} чек';
        _actedThisStreet.add(player.id);
        break;
      case 'call':
        final pay = _currentBet.clamp(0, player.credits);
        _pot += pay;
        _players[index] = player.copyWith(credits: player.credits - pay);
        _status = '${player.name} колл $_currentBet';
        _actedThisStreet.add(player.id);
        break;
      case 'raise':
        final total = _currentBet + raiseBy;
        final pay = total.clamp(0, player.credits);
        _pot += pay;
        _currentBet = total;
        _players[index] = player.copyWith(credits: player.credits - pay);
        _actedThisStreet = {player.id};
        _status = '${player.name} рейз +$raiseBy';
        break;
    }
    _advanceTurnOrStreet();
    _broadcastGameState();
  }

  void _advanceTurnOrStreet() {
    final active = _activePlayerIds();
    if (active.length <= 1) {
      final winnerId = active.isEmpty ? _players.first.id : active.first;
      final winIndex = _players.indexWhere((p) => p.id == winnerId);
      if (winIndex >= 0) {
        final winner = _players[winIndex];
        _players[winIndex] = winner.copyWith(credits: winner.credits + _pot);
        _status = '${winner.name} выиграл банк $_pot (все сбросили)';
        _pot = 0;
      }
      return;
    }

    if (_actedThisStreet.length >= active.length) {
      _streetIndex++;
      _actedThisStreet = <String>{};
      _turnSeatIndex = _nextActiveSeatAfter(_dealerSeatIndex);
      if (_streetIndex >= 4) {
        _resolveShowdown();
      } else {
        _status =
            '${_streetLabel(_streetIndex)}. Ход: ${_playerNameBySeat(_turnSeatIndex)}';
      }
      return;
    }

    _turnSeatIndex = _nextActiveSeatAfter(_turnSeatIndex);
    _status =
        '${_streetLabel(_streetIndex)}. Ход: ${_playerNameBySeat(_turnSeatIndex)}';
  }

  void _resolveShowdown() {
    final active = _activePlayerIds();
    var bestCategory = PokerHandCategory.highCard;
    String? winnerId;
    String bestTitle = 'Старшая карта';
    for (final playerId in active) {
      final sevenIds = <int>[
        ...(_holeCardIdsByPlayer[playerId] ?? const []),
        ..._allCommunityCardIds.take(5),
      ];
      final cards = sevenIds.map(_cardFromId).toList();
      final result = _evaluator.evaluateBestOfSeven(cards);
      if (result.category.index >= bestCategory.index) {
        bestCategory = result.category;
        bestTitle = result.title;
        winnerId = playerId;
      }
    }
    if (winnerId == null) return;
    final winIndex = _players.indexWhere((p) => p.id == winnerId);
    if (winIndex < 0) return;
    final winner = _players[winIndex];
    _players[winIndex] = winner.copyWith(credits: winner.credits + _pot);
    _status = 'Шоудаун: ${winner.name} победил ($bestTitle), банк $_pot';
    _pot = 0;
  }

  int _nextActiveSeatAfter(int seatIndex) {
    if (_seatOrderIds.isEmpty) return 0;
    var next = seatIndex;
    for (var i = 0; i < _seatOrderIds.length; i++) {
      next = (next + 1) % _seatOrderIds.length;
      final id = _seatOrderIds[next];
      final player = _players.firstWhere((p) => p.id == id);
      if (!player.folded && player.credits > 0) {
        return next;
      }
    }
    return seatIndex;
  }

  List<String> _activePlayerIds() {
    return _players
        .where((p) => !p.folded && p.credits >= 0)
        .map((p) => p.id)
        .toList();
  }

  String _playerNameBySeat(int seatIndex) {
    if (_seatOrderIds.isEmpty) return '-';
    final id = _seatOrderIds[seatIndex];
    final player = _players.firstWhere((p) => p.id == id);
    return player.name;
  }

  int _visibleCommunityCountForStreet(int street) {
    switch (street) {
      case 0:
        return 0;
      case 1:
        return 3;
      case 2:
        return 4;
      default:
        return 5;
    }
  }

  String _streetLabel(int street) {
    switch (street) {
      case 0:
        return 'Префлоп';
      case 1:
        return 'Флоп';
      case 2:
        return 'Терн';
      case 3:
        return 'Ривер';
      default:
        return 'Шоудаун';
    }
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

  Widget _tablePlayer({
    required GamePlayer player,
    required bool isDealer,
    required bool isTurn,
    required bool isMe,
  }) {
    final baseSize = MediaQuery.of(context).size.shortestSide;
    final nameSize = (baseSize * 0.022).clamp(12, 18).toDouble();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isTurn ? Colors.amber.withValues(alpha: 0.2) : Colors.black26,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isTurn ? Colors.amber : Colors.white24,
          width: isTurn ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            player.name,
            style: TextStyle(fontSize: nameSize, fontWeight: FontWeight.w700),
          ),
          Text(
            '${player.credits} AidCoin',
            style: TextStyle(fontSize: (nameSize - 1).clamp(11, 16)),
          ),
          Text(
            player.folded ? 'Сбросил' : (isMe ? 'Вы' : 'В игре'),
            style: TextStyle(fontSize: (nameSize - 2).clamp(10, 14)),
          ),
          if (isDealer)
            const Text('Дилер', style: TextStyle(color: Colors.orange)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    final tableRadius = min(screen.height * 0.28, screen.width * 0.22);
    final centerX = screen.width * 0.36;
    final centerY = screen.height * 0.46;
    final canAct =
        _seatOrderIds.isNotEmpty &&
        _seatOrderIds[_turnSeatIndex] == widget.meId &&
        _streetIndex < 4;

    return Scaffold(
      appBar: AppBar(title: const Text('Игровой стол')),
      body: Row(
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Center(
                    child: Container(
                      width: tableRadius * 2.2,
                      height: tableRadius * 2.2,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F5C3A),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24, width: 3),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: centerX - 40,
                  top: centerY - tableRadius - 48,
                  child: const Chip(
                    avatar: Icon(Icons.casino, size: 18),
                    label: Text('Дилер'),
                  ),
                ),
                ..._seatOrderIds.asMap().entries.map((entry) {
                  final i = entry.key;
                  final playerId = entry.value;
                  final player = _players.firstWhere((p) => p.id == playerId);
                  final angle = (-pi / 2) + (2 * pi * i / _seatOrderIds.length);
                  final x = centerX + tableRadius * cos(angle) - 70;
                  final y = centerY + tableRadius * sin(angle) - 40;
                  return Positioned(
                    left: x,
                    top: y,
                    child: _tablePlayer(
                      player: player,
                      isDealer: i == _dealerSeatIndex,
                      isTurn: i == _turnSeatIndex,
                      isMe: player.id == widget.meId,
                    ),
                  );
                }),
                Positioned(
                  left: centerX - 95,
                  top: centerY - 45,
                  child: Column(
                    children: [
                      Text(
                        'Банк: $_pot',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text('Этап: ${_streetLabel(_streetIndex)}'),
                      Text(_status),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        children: _communityCards.map(_cardChip).toList(),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 24,
                  bottom: 24,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ваши карты',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        children: _myCards.map(_cardChip).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 250,
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 16),
            decoration: const BoxDecoration(
              color: Color(0x22000000),
              border: Border(left: BorderSide(color: Colors.white24)),
            ),
            child: Column(
              children: [
                Text(
                  'Текущая ставка: $_currentBet',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Center(
                    child: RotatedBox(
                      quarterTurns: 3,
                      child: Slider(
                        min: 10,
                        max: 300,
                        divisions: 29,
                        value: _raiseValue.toDouble(),
                        label: '$_raiseValue',
                        onChanged: canAct
                            ? (v) => setState(() => _raiseValue = v.toInt())
                            : null,
                      ),
                    ),
                  ),
                ),
                Text('Рейз: $_raiseValue'),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: canAct ? () => _sendAction('fold') : null,
                    child: const Text('Сбросить'),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: canAct ? () => _sendAction('check') : null,
                    child: const Text('Чек'),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: canAct ? () => _sendAction('call') : null,
                    child: const Text('Колл'),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: canAct ? () => _sendAction('raise') : null,
                    child: const Text('Повысить'),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  canAct
                      ? 'Ваш ход'
                      : 'Ожидание хода ${_seatOrderIds.isEmpty ? '' : _playerNameBySeat(_turnSeatIndex)}',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
