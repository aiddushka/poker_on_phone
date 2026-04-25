import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pocker_in_phone/core/i18n.dart';
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
  final _betController = TextEditingController(text: '20');
  final _nextCreditsController = TextEditingController(text: '1000');

  List<GamePlayer> _players = const [];
  Map<String, List<int>> _holeCardIdsByPlayer = const {};
  List<int> _allCommunityCardIds = const [];
  List<String> _seatOrderIds = const [];
  Map<String, int> _streetCommittedByPlayer = const {};

  int _pot = 0;
  int _currentBet = 20;
  int _raiseValue = 20;
  int _dealerSeatIndex = 0;
  int _turnSeatIndex = 0;
  int _streetIndex = 0;
  bool _isBettingOpen = false;
  bool _showTournamentLobby = false;
  bool _canOpenNewGameOverlay = false;
  int _configuredStartingCredits = 1000;
  String? _winnerName;
  String? _winnerCombo;
  int? _winnerPot;
  Set<String> _actedThisStreet = <String>{};
  String _status = 'status_waiting_start';
  String? _winnerBanner;

  String _t(String key, [Map<String, String> vars = const {}]) {
    var value = trRead(context, key);
    vars.forEach((k, v) => value = value.replaceAll('{$k}', v));
    return value;
  }

  @override
  void initState() {
    super.initState();
    _status = _t('status_waiting_start');
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
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
    _configuredStartingCredits = widget.startingCredits;
    _nextCreditsController.text = widget.startingCredits.toString();
  }

  @override
  void dispose() {
    _betController.dispose();
    _nextCreditsController.dispose();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
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
        final seatsRaw =
            (message.payload['seatOrderIds'] as List<dynamic>?) ?? [];
        final communityRaw =
            (message.payload['communityCards'] as List<dynamic>?) ?? [];
        final committedRaw = Map<String, dynamic>.from(
          (message.payload['streetCommittedByPlayer']
                  as Map<dynamic, dynamic>?) ??
              {},
        );
        setState(() {
          _showTournamentLobby =
              message.payload['showTournamentLobby'] as bool? ?? false;
          _canOpenNewGameOverlay =
              message.payload['canOpenNewGameOverlay'] as bool? ??
              _canOpenNewGameOverlay;
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
          _winnerBanner = message.payload['winnerBanner'] as String?;
          _winnerName = message.payload['winnerName'] as String?;
          _winnerCombo = message.payload['winnerCombo'] as String?;
          _winnerPot = message.payload['winnerPot'] as int?;
          _dealerSeatIndex = message.payload['dealerSeatIndex'] as int? ?? 0;
          _turnSeatIndex = message.payload['turnSeatIndex'] as int? ?? 0;
          _streetIndex = message.payload['streetIndex'] as int? ?? 0;
          _isBettingOpen = message.payload['isBettingOpen'] as bool? ?? false;
          _actedThisStreet =
              ((message.payload['actedThisStreet'] as List<dynamic>?) ?? [])
                  .cast<String>()
                  .toSet();
          _seatOrderIds = seatsRaw.cast<String>();
          _allCommunityCardIds = communityRaw.cast<int>();
          _holeCardIdsByPlayer = {
            for (final entry in holeCardsRaw.entries)
              entry.key: (entry.value as List<dynamic>).cast<int>(),
          };
          _streetCommittedByPlayer = {
            for (final entry in committedRaw.entries)
              entry.key: entry.value as int,
          };
          if (_winnerName != null &&
              _winnerCombo != null &&
              _winnerPot != null) {
            _winnerBanner = _t('status_winner_with_combo', {
              'name': _winnerName!,
              'combo': _winnerCombo!,
              'pot': _winnerPot.toString(),
            });
          }
          _betController.text = _currentBet.toString();
        });
        break;
      case 'player_action':
        if (!widget.isHost) return;
        _applyActionAsHost(
          playerId: message.payload['playerId'] as String,
          action: message.payload['action'] as String,
          raiseTo: (message.payload['raiseTo'] as int?) ?? _currentBet,
        );
        break;
      case 'tournament_lobby':
        setState(() {
          _showTournamentLobby = true;
          _winnerBanner =
              message.payload['winnerText'] as String? ?? _winnerBanner;
          _status = _winnerBanner ?? _status;
          _isBettingOpen = false;
        });
        break;
    }
  }

  PlayingCard _cardFromId(int id) => PlayingCard.standardDeck()[id];

  List<PlayingCard> get _myCards {
    final ids = _holeCardIdsByPlayer[widget.meId] ?? const [];
    return ids.map(_cardFromId).toList();
  }

  List<PlayingCard> get _communityCards {
    return _allCommunityCardIds
        .take(_visibleCommunityCountForStreet(_streetIndex))
        .map(_cardFromId)
        .toList();
  }

  Future<void> _startNewRoundAndBroadcast({bool firstRound = false}) async {
    final deck = PlayingCard.standardDeck()..shuffle(_random);
    if (firstRound || _seatOrderIds.isEmpty) {
      _seatOrderIds = _players.map((p) => p.id).toList()..shuffle(_random);
    } else {
      _seatOrderIds = [..._seatOrderIds.skip(1), _seatOrderIds.first];
    }
    _dealerSeatIndex = 0;
    final holeCards = <String, List<int>>{};
    for (var i = 0; i < _players.length; i++) {
      holeCards[_players[i].id] = [deck[i * 2].id, deck[i * 2 + 1].id];
    }
    _allCommunityCardIds = [
      deck[_players.length * 2].id,
      deck[_players.length * 2 + 1].id,
      deck[_players.length * 2 + 2].id,
      deck[_players.length * 2 + 3].id,
      deck[_players.length * 2 + 4].id,
    ];
    _holeCardIdsByPlayer = holeCards;
    _pot = 0;
    _currentBet = 20;
    _raiseValue = 20;
    _streetIndex = 0;
    _isBettingOpen = false;
    _showTournamentLobby = false;
    _canOpenNewGameOverlay = false;
    _actedThisStreet = {};
    _winnerBanner = null;
    _winnerName = null;
    _winnerCombo = null;
    _winnerPot = null;
    _streetCommittedByPlayer = {for (final p in _players) p.id: 0};
    _players = _players.map((p) => p.copyWith(folded: p.credits <= 0)).toList();
    if (firstRound) {
      _players = _players
          .map(
            (p) =>
                p.copyWith(credits: _configuredStartingCredits, folded: false),
          )
          .toList();
    }
    _turnSeatIndex = _firstActingSeatIndex();
    _status = _t('status_dealing');
    await _broadcastGameState();
    await Future<void>.delayed(const Duration(milliseconds: 900));
    _isBettingOpen = true;
    _status = _t('status_preflop_turn', {
      'name': _playerNameBySeat(_turnSeatIndex),
    });
    await _broadcastGameState();
  }

  Future<void> _broadcastGameState() async {
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
      'winnerBanner': _winnerBanner,
      'dealerSeatIndex': _dealerSeatIndex,
      'turnSeatIndex': _turnSeatIndex,
      'streetIndex': _streetIndex,
      'isBettingOpen': _isBettingOpen,
      'actedThisStreet': _actedThisStreet.toList(),
      'seatOrderIds': _seatOrderIds,
      'holeCards': _holeCardIdsByPlayer,
      'communityCards': _allCommunityCardIds,
      'streetCommittedByPlayer': _streetCommittedByPlayer,
      'showTournamentLobby': _showTournamentLobby,
      'canOpenNewGameOverlay': _canOpenNewGameOverlay,
      'winnerName': _winnerName,
      'winnerCombo': _winnerCombo,
      'winnerPot': _winnerPot,
    };
    _handleNetworkMessage(LanMessage('game_state', payload));
    await widget.lan.send(LanMessage('game_state', payload));
  }

  Future<void> _sendAction(String action, {int? raiseTo}) async {
    final payload = {
      'playerId': widget.meId,
      'action': action,
      'raiseTo': raiseTo ?? _currentBet,
    };
    if (widget.isHost) {
      _applyActionAsHost(
        playerId: widget.meId,
        action: action,
        raiseTo: payload['raiseTo'] as int,
      );
      return;
    }
    await widget.lan.send(LanMessage('player_action', payload));
  }

  void _applyActionAsHost({
    required String playerId,
    required String action,
    required int raiseTo,
  }) {
    final index = _players.indexWhere((p) => p.id == playerId);
    if (index < 0 || !_isBettingOpen) return;
    if (_seatOrderIds[_turnSeatIndex] != playerId) return;
    final player = _players[index];
    if (player.folded || player.credits <= 0) return;

    final committed = _streetCommittedByPlayer[player.id] ?? 0;
    switch (action) {
      case 'fold':
        _players[index] = player.copyWith(folded: true);
        _actedThisStreet.add(player.id);
        _status = '${player.name} сбросил';
        break;
      case 'check':
        if (committed != _currentBet) return;
        _actedThisStreet.add(player.id);
        _status = '${player.name} чек';
        break;
      case 'call':
        final need = (_currentBet - committed).clamp(0, player.credits);
        _pot += need;
        _streetCommittedByPlayer = {
          ..._streetCommittedByPlayer,
          player.id: committed + need,
        };
        _players[index] = player.copyWith(credits: player.credits - need);
        _actedThisStreet.add(player.id);
        _status = '${player.name} колл';
        break;
      case 'raise':
        final target = raiseTo.clamp(20, committed + player.credits);
        if (target <= _currentBet) {
          final need = (_currentBet - committed).clamp(0, player.credits);
          _pot += need;
          _streetCommittedByPlayer = {
            ..._streetCommittedByPlayer,
            player.id: committed + need,
          };
          _players[index] = player.copyWith(credits: player.credits - need);
          _actedThisStreet.add(player.id);
          _status = player.credits - need == 0
              ? '${player.name} all-in (колл)'
              : '${player.name} колл';
          break;
        }
        final need = target - committed;
        _pot += need;
        _streetCommittedByPlayer = {
          ..._streetCommittedByPlayer,
          player.id: target,
        };
        _players[index] = player.copyWith(credits: player.credits - need);
        _currentBet = target;
        _actedThisStreet = {player.id};
        _status = '${player.name} повысил до $target';
        break;
    }
    _advanceTurnOrStreet();
    _broadcastGameState();
  }

  void _advanceTurnOrStreet() {
    final active = _activeHandPlayerIds();
    if (active.length <= 1) {
      _awardSingleWinner(active.isEmpty ? _players.first.id : active.first);
      return;
    }
    if (_isStreetComplete()) {
      _streetIndex++;
      _actedThisStreet = {};
      _streetCommittedByPlayer = {for (final p in _players) p.id: 0};
      _currentBet = 0;
      _turnSeatIndex = _firstActingSeatIndex();
      if (_shouldAutoRunToShowdown()) {
        _streetIndex = 4;
        _status = _t('status_allin_showdown');
        _resolveShowdown();
        return;
      }
      if (_streetIndex >= 4) {
        _resolveShowdown();
      } else {
        _status = _t('status_stage_turn', {
          'stage': _streetLabel(_streetIndex),
          'name': _playerNameBySeat(_turnSeatIndex),
        });
      }
      return;
    }
    _turnSeatIndex = _nextActiveSeatAfter(_turnSeatIndex);
    if (_shouldAutoRunToShowdown()) {
      _streetIndex = 4;
      _status = _t('status_allin_showdown');
      _resolveShowdown();
      return;
    }
    _status = _t('status_stage_turn', {
      'stage': _streetLabel(_streetIndex),
      'name': _playerNameBySeat(_turnSeatIndex),
    });
  }

  bool _isStreetComplete() {
    final active = _activeHandPlayerIds();
    for (final id in active) {
      final player = _players.firstWhere((p) => p.id == id);
      final committed = _streetCommittedByPlayer[id] ?? 0;
      final matched = committed == _currentBet || player.credits == 0;
      final actedOrAllIn = _actedThisStreet.contains(id) || player.credits == 0;
      if (!actedOrAllIn || !matched) {
        return false;
      }
    }
    return true;
  }

  void _resolveShowdown() {
    final active = _activeHandPlayerIds();
    var bestCategory = PokerHandCategory.highCard;
    String? winnerId;
    String bestTitle = tr(context, 'combo_high_card');
    for (final playerId in active) {
      final sevenIds = <int>[
        ...(_holeCardIdsByPlayer[playerId] ?? const []),
        ..._allCommunityCardIds.take(5),
      ];
      final seven = sevenIds.map(_cardFromId).toList();
      final result = _evaluator.evaluateBestOfSeven(seven);
      if (result.category.index >= bestCategory.index) {
        bestCategory = result.category;
        bestTitle = result.title;
        winnerId = playerId;
      }
    }
    if (winnerId == null) return;
    final winner = _players.firstWhere((p) => p.id == winnerId);
    _winnerBanner = _t('status_winner_with_combo', {
      'name': winner.name,
      'combo': bestTitle,
      'pot': _pot.toString(),
    });
    _winnerName = winner.name;
    _winnerCombo = bestTitle;
    _winnerPot = _pot;
    _awardWinnerCredits(winnerId);
  }

  void _awardSingleWinner(String winnerId) {
    final winner = _players.firstWhere((p) => p.id == winnerId);
    final combo = _winnerComboOrNoShowdown(winnerId);
    _winnerBanner = _t('status_winner_with_combo', {
      'name': winner.name,
      'combo': combo,
      'pot': _pot.toString(),
    });
    _winnerName = winner.name;
    _winnerCombo = combo;
    _winnerPot = _pot;
    _awardWinnerCredits(winnerId);
  }

  String _winnerComboOrNoShowdown(String winnerId) {
    final visibleCommunity = _allCommunityCardIds
        .take(_visibleCommunityCountForStreet(_streetIndex))
        .toList();
    final hole = _holeCardIdsByPlayer[winnerId] ?? const <int>[];
    final all = [...hole, ...visibleCommunity];
    if (all.length < 5) {
      return tr(context, 'status_winner_no_showdown');
    }
    final cards = all.map(_cardFromId).toList();
    if (cards.length == 5) {
      return _evaluator.evaluate5(cards).title;
    }
    return _evaluator.evaluateBestOfSeven(cards).title;
  }

  void _awardWinnerCredits(String winnerId) {
    final idx = _players.indexWhere((p) => p.id == winnerId);
    if (idx >= 0) {
      final w = _players[idx];
      _players[idx] = w.copyWith(credits: w.credits + _pot);
    }
    _pot = 0;
    _isBettingOpen = false;
    _status = _winnerBanner ?? _t('status_round_finished');
    _scheduleNextRoundIfPossible();
  }

  void _scheduleNextRoundIfPossible() {
    final alive = _players.where((p) => p.credits > 0).toList();
    _showTournamentLobby = true;
    _canOpenNewGameOverlay = true;
    _isBettingOpen = false;
    if (alive.length < 2) {
      _status = _t('status_game_finished_winner', {
        'name': alive.isEmpty ? '-' : alive.first.name,
      });
      _winnerBanner = _status;
    } else {
      _status = tr(context, 'guest_waiting_hint');
      _winnerBanner = _winnerBanner ?? _status;
    }
    _broadcastGameState();
  }

  int _nextActiveSeatAfter(int seatIndex) {
    var next = seatIndex;
    for (var i = 0; i < _seatOrderIds.length; i++) {
      next = (next + 1) % _seatOrderIds.length;
      final p = _playerById(_seatOrderIds[next]);
      if (!p.folded && p.credits > 0) return next;
    }
    return seatIndex;
  }

  int _firstActingSeatIndex() {
    if (_seatOrderIds.isEmpty) return 0;
    final dealerPlayer = _playerById(_seatOrderIds[0]);
    if (!dealerPlayer.folded && dealerPlayer.credits > 0) {
      return 0;
    }
    return _nextActiveSeatAfter(0);
  }

  List<String> _activeHandPlayerIds() =>
      _players.where((p) => !p.folded).map((p) => p.id).toList();

  List<String> _activeCanActPlayerIds() => _players
      .where((p) => !p.folded && p.credits > 0)
      .map((p) => p.id)
      .toList();

  bool _shouldAutoRunToShowdown() {
    final handPlayers = _activeHandPlayerIds();
    final canActPlayers = _activeCanActPlayerIds();
    if (handPlayers.length <= 1) return false;
    return canActPlayers.length <= 1;
  }

  void _showHelpDialog() {
    showDialog<void>(
      context: context,
      builder: (context) {
        Widget combo(String name, String cards) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(cards, style: const TextStyle(fontSize: 18)),
              ],
            ),
          );
        }

        return AlertDialog(
          title: Text(tr(context, 'help_title')),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${tr(context, 'combinations')}:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                combo(tr(context, 'combo_royal_flush'), '10♥ J♥ Q♥ K♥ A♥'),
                combo(tr(context, 'combo_straight_flush'), '5♣ 6♣ 7♣ 8♣ 9♣'),
                combo(tr(context, 'combo_four_kind'), 'K♠ K♥ K♦ K♣ 2♣'),
                combo(tr(context, 'combo_full_house'), 'Q♠ Q♥ Q♦ 8♣ 8♦'),
                combo(tr(context, 'combo_flush'), '2♥ 5♥ 9♥ J♥ K♥'),
                combo(tr(context, 'combo_straight'), '4♣ 5♦ 6♠ 7♥ 8♣'),
                combo(tr(context, 'combo_three_kind'), '9♣ 9♦ 9♠ K♥ 2♦'),
                combo(tr(context, 'combo_two_pair'), 'A♣ A♦ 7♠ 7♥ 3♣'),
                combo(tr(context, 'combo_pair'), 'J♣ J♦ 4♠ 8♥ K♣'),
                combo(tr(context, 'combo_high_card'), 'A♣ 10♦ 8♠ 6♥ 3♣'),
                const SizedBox(height: 12),
                Text(
                  tr(context, 'game_description'),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  tr(context, 'help_intro_title'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(tr(context, 'help_intro_body')),
                const SizedBox(height: 10),
                Text(
                  tr(context, 'help_rounds_title'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(tr(context, 'help_rounds_body')),
                const SizedBox(height: 10),
                Text(
                  tr(context, 'help_actions_title'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(tr(context, 'help_actions_body')),
                const SizedBox(height: 10),
                Text(
                  tr(context, 'help_win_title'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(tr(context, 'help_win_body')),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(tr(context, 'close')),
            ),
          ],
        );
      },
    );
  }

  void _startNextTournamentFromHost() {
    final parsed = int.tryParse(_nextCreditsController.text.trim());
    if (parsed == null || parsed <= 0) return;
    if (_players.length < 2) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_t('status_min_two_players'))));
      return;
    }
    _configuredStartingCredits = parsed;
    for (var i = 0; i < _players.length; i++) {
      _players[i] = _players[i].copyWith(credits: parsed, folded: false);
    }
    _showTournamentLobby = false;
    _canOpenNewGameOverlay = false;
    _winnerBanner = null;
    _winnerName = null;
    _winnerCombo = null;
    _winnerPot = null;
    _status = _t('status_prepare_new_game');
    _startNewRoundAndBroadcast(firstRound: true);
  }

  void _removePlayerFromNextGame(String playerId) {
    if (playerId == widget.meId) return;
    _players = _players.where((p) => p.id != playerId).toList();
    _seatOrderIds = _seatOrderIds.where((id) => id != playerId).toList();
    _holeCardIdsByPlayer.remove(playerId);
    _streetCommittedByPlayer.remove(playerId);
    _broadcastGameState();
  }

  void _closeTournamentOverlay() {
    setState(() {
      _showTournamentLobby = false;
    });
    if (widget.isHost) {
      _broadcastGameState();
    }
  }

  void _reopenTournamentOverlay() {
    setState(() {
      _showTournamentLobby = true;
    });
    if (widget.isHost) {
      _broadcastGameState();
    }
  }

  GamePlayer _playerById(String id) => _players.firstWhere((p) => p.id == id);

  String _playerNameBySeat(int seatIndex) =>
      _seatOrderIds.isEmpty ? '-' : _playerById(_seatOrderIds[seatIndex]).name;

  int _seatNumberForIndex(int seatIndex) {
    if (_seatOrderIds.isEmpty) return 0;
    return (seatIndex - _dealerSeatIndex + _seatOrderIds.length) %
        _seatOrderIds.length;
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
        return tr(context, 'street_preflop');
      case 1:
        return tr(context, 'street_flop');
      case 2:
        return tr(context, 'street_turn');
      case 3:
        return tr(context, 'street_river');
      default:
        return tr(context, 'street_showdown');
    }
  }

  double _seatAngle(int i, int count) {
    if (count == 2) {
      return i == 0 ? 0 : pi;
    }
    const topGap = pi / 4;
    final start = -pi / 2 + (topGap / 2);
    final step = ((2 * pi) - topGap) / count;
    return start + (step * i);
  }

  Widget _cardChip(PlayingCard card) {
    return Container(
      width: 56,
      height: 80,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF173E2A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        card.shortLabel,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _seatWidget(
    GamePlayer p, {
    required bool isDealer,
    required bool isTurn,
    required int seatNo,
  }) {
    final isMe = p.id == widget.meId;
    final status = p.folded
        ? tr(context, 'player_not_in_game')
        : (isMe ? tr(context, 'player_you') : tr(context, 'player_in_game'));
    return Container(
      width: 132,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: isTurn ? Colors.amber.withValues(alpha: 0.2) : Colors.black26,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isTurn ? Colors.amber : Colors.white24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '[$seatNo] ${p.name}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text('${p.credits} AidCoin'),
          Text(status, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 3),
          if (isMe)
            Wrap(
              spacing: 3,
              children: _myCards
                  .map(
                    (c) => Container(
                      width: 24,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B3A2E),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Text(
                        c.shortLabel,
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final tableCenter = Offset(size.width * 0.33, size.height * 0.5);
    final radiusX = min(size.width * 0.24, 280.0);
    final radiusY = min(size.height * 0.28, 180.0);
    final canAct =
        _seatOrderIds.isNotEmpty &&
        _seatOrderIds[_turnSeatIndex] == widget.meId &&
        _streetIndex < 4 &&
        _isBettingOpen;

    final myPlayer = _playerById(widget.meId);
    final myCredits = myPlayer.credits;
    final myCommitted = _streetCommittedByPlayer[widget.meId] ?? 0;
    final needToCall = (_currentBet - myCommitted).clamp(0, myCredits);
    final canCheck = canAct && myCommitted == _currentBet;
    final canCall = canAct && myCredits > 0 && myCommitted < _currentBet;
    final canRaise =
        canAct &&
        myCredits > needToCall &&
        (myCommitted + myCredits) > _currentBet;
    final sliderMax = max(20, myCredits);

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Row(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Center(
                          child: Container(
                            width: radiusX * 2.3,
                            height: radiusY * 2.25,
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F5C3A),
                              borderRadius: BorderRadius.circular(260),
                              border: Border.all(
                                color: Colors.white24,
                                width: 3,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 8,
                        top: 4,
                        child: IconButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(Icons.arrow_back),
                        ),
                      ),
                      Positioned(
                        left: tableCenter.dx - 42,
                        top: tableCenter.dy - radiusY - 84,
                        child: Chip(
                          avatar: const Icon(Icons.casino, size: 18),
                          label: Text(tr(context, 'dealer')),
                        ),
                      ),
                      ..._seatOrderIds.asMap().entries.map((e) {
                        final i = e.key;
                        final p = _playerById(e.value);
                        final a = _seatAngle(i, _seatOrderIds.length);
                        final seatNo = _seatNumberForIndex(i);
                        final x = tableCenter.dx + radiusX * cos(a) - 66;
                        final y = tableCenter.dy + radiusY * sin(a) - 46;
                        return Positioned(
                          left: x,
                          top: y,
                          child: _seatWidget(
                            p,
                            isDealer: i == _dealerSeatIndex,
                            isTurn: i == _turnSeatIndex,
                            seatNo: seatNo,
                          ),
                        );
                      }),
                      Align(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${tr(context, 'stage')}: ${_streetLabel(_streetIndex)}',
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              children: _communityCards.map(_cardChip).toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 280,
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                  decoration: const BoxDecoration(
                    color: Color(0x22000000),
                    border: Border(left: BorderSide(color: Colors.white24)),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        Text(
                          '${tr(context, 'pot')}: $_pot',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text('${tr(context, 'current_bet')}: $_currentBet'),
                        Text(
                          _winnerBanner ?? _status,
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            SizedBox(
                              height: 150,
                              child: RotatedBox(
                                quarterTurns: 3,
                                child: Slider(
                                  value: _raiseValue
                                      .clamp(20, sliderMax)
                                      .toDouble(),
                                  min: 20,
                                  max: sliderMax.toDouble(),
                                  divisions: max(1, sliderMax - 20),
                                  onChanged: canRaise
                                      ? (v) {
                                          setState(
                                            () => _raiseValue = v.toInt(),
                                          );
                                          _betController.text = _raiseValue
                                              .toString();
                                        }
                                      : null,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                children: [
                                  TextField(
                                    controller: _betController,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: tr(context, 'bet_input_label'),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton(
                                      style: FilledButton.styleFrom(
                                        backgroundColor: Colors.red.shade700,
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: canAct
                                          ? () => _sendAction('fold')
                                          : null,
                                      child: Text(tr(context, 'fold')),
                                    ),
                                  ),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton(
                                      onPressed: canCheck
                                          ? () => _sendAction('check')
                                          : null,
                                      child: Text(tr(context, 'check_view')),
                                    ),
                                  ),
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton(
                                      onPressed: canCall
                                          ? () => _sendAction('call')
                                          : null,
                                      child: Text(tr(context, 'accept')),
                                    ),
                                  ),
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton(
                                      onPressed: canRaise
                                          ? () {
                                              final parsed = int.tryParse(
                                                _betController.text.trim(),
                                              );
                                              if (parsed == null ||
                                                  parsed < 20 ||
                                                  parsed >
                                                      (myCommitted +
                                                          myCredits) ||
                                                  parsed <= _currentBet) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      tr(
                                                        context,
                                                        'raise_validation',
                                                      ),
                                                    ),
                                                  ),
                                                );
                                                return;
                                              }
                                              _sendAction(
                                                'raise',
                                                raiseTo: parsed,
                                              );
                                            }
                                          : null,
                                      child: Text(tr(context, 'raise')),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    canAct
                                        ? tr(context, 'your_turn')
                                        : '${tr(context, 'waiting')}: ${_seatOrderIds.isEmpty ? '-' : _playerNameBySeat(_turnSeatIndex)}',
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton.tonalIcon(
                                      onPressed: _showHelpDialog,
                                      icon: const Icon(Icons.help_outline),
                                      label: Text(tr(context, 'help')),
                                    ),
                                  ),
                                  if (canAct && !canRaise && canCall)
                                    Text(
                                      tr(context, 'insufficient_raise'),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.orangeAccent,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (_showTournamentLobby)
              Positioned.fill(
                child: Container(
                  color: Colors.black54,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight:
                                  MediaQuery.of(context).size.height * 0.8,
                            ),
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Align(
                                    alignment: Alignment.topRight,
                                    child: IconButton(
                                      onPressed: _closeTournamentOverlay,
                                      icon: const Icon(Icons.close),
                                      tooltip: tr(context, 'close_tooltip'),
                                    ),
                                  ),
                                  Text(
                                    _winnerBanner ??
                                        (widget.isHost
                                            ? tr(context, 'new_game_window')
                                            : tr(context, 'waiting_new_game')),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    widget.isHost
                                        ? tr(context, 'host_waiting_hint')
                                        : tr(context, 'waiting_new_game'),
                                  ),
                                  const SizedBox(height: 12),
                                  if (widget.isHost) ...[
                                    TextField(
                                      controller: _nextCreditsController,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        labelText: tr(
                                          context,
                                          'new_game_credits',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text('${tr(context, 'user_management')}:'),
                                    const SizedBox(height: 6),
                                    SizedBox(
                                      height: 120,
                                      child: ListView(
                                        children: _players
                                            .map(
                                              (p) => ListTile(
                                                dense: true,
                                                title: Text(p.name),
                                                subtitle: Text(
                                                  '${tr(context, 'credits')}: ${p.credits}',
                                                ),
                                                trailing: p.id == widget.meId
                                                    ? const Icon(Icons.shield)
                                                    : IconButton(
                                                        icon: const Icon(
                                                          Icons.person_remove,
                                                        ),
                                                        tooltip: tr(
                                                          context,
                                                          'remove_next_game',
                                                        ),
                                                        onPressed: () =>
                                                            _removePlayerFromNextGame(
                                                              p.id,
                                                            ),
                                                      ),
                                              ),
                                            )
                                            .toList(),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      width: double.infinity,
                                      child: FilledButton(
                                        onPressed: _startNextTournamentFromHost,
                                        child: Text(
                                          tr(context, 'start_new_game'),
                                        ),
                                      ),
                                    ),
                                  ] else
                                    Text(tr(context, 'guest_waiting_hint')),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (_canOpenNewGameOverlay && !_showTournamentLobby)
              Positioned(
                right: 16,
                top: 16,
                child: FilledButton(
                  onPressed: _reopenTournamentOverlay,
                  child: Text(
                    widget.isHost
                        ? tr(context, 'start_new_game')
                        : tr(context, 'open_result_window'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
