import 'package:flutter/material.dart';

class GamePlayer {
  const GamePlayer({
    required this.name,
    required this.credits,
    this.folded = false,
  });

  final String name;
  final int credits;
  final bool folded;

  GamePlayer copyWith({String? name, int? credits, bool? folded}) {
    return GamePlayer(
      name: name ?? this.name,
      credits: credits ?? this.credits,
      folded: folded ?? this.folded,
    );
  }
}

class GameRoomPage extends StatefulWidget {
  const GameRoomPage({
    super.key,
    required this.playerNames,
    required this.startingCredits,
    required this.meName,
  });

  final List<String> playerNames;
  final int startingCredits;
  final String meName;

  @override
  State<GameRoomPage> createState() => _GameRoomPageState();
}

class _GameRoomPageState extends State<GameRoomPage> {
  late List<GamePlayer> _players;
  int _pot = 0;
  int _currentBet = 20;
  int _raiseValue = 20;
  String _status = 'Pre-flop';

  @override
  void initState() {
    super.initState();
    _players = widget.playerNames
        .map((name) => GamePlayer(name: name, credits: widget.startingCredits))
        .toList();
  }

  int get _myIndex => _players.indexWhere((p) => p.name == widget.meName);

  void _applyToMe(GamePlayer Function(GamePlayer me) update) {
    final index = _myIndex;
    if (index < 0) return;
    setState(() {
      _players[index] = update(_players[index]);
    });
  }

  void _fold() {
    _applyToMe((me) => me.copyWith(folded: true));
    setState(() => _status = '${widget.meName} folds');
  }

  void _check() {
    setState(() => _status = '${widget.meName} checks');
  }

  void _call() {
    _applyToMe((me) {
      final pay = _currentBet.clamp(0, me.credits);
      _pot += pay;
      return me.copyWith(credits: me.credits - pay);
    });
    setState(() => _status = '${widget.meName} calls $_currentBet');
  }

  void _raise() {
    _applyToMe((me) {
      final pay = (_currentBet + _raiseValue).clamp(0, me.credits);
      _pot += pay;
      _currentBet += _raiseValue;
      return me.copyWith(credits: me.credits - pay);
    });
    setState(() => _status = '${widget.meName} raises by $_raiseValue');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Poker Table')),
      body: Column(
        children: [
          const SizedBox(height: 12),
          Text(
            'Pot: $_pot AidCoin',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text('Current Bet: $_currentBet AidCoin'),
          const SizedBox(height: 4),
          Text(_status),
          const SizedBox(height: 12),
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
                  subtitle: Text(player.folded ? 'Folded' : 'In hand'),
                  trailing: Text('${player.credits} AidCoin'),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text('Raise:'),
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
                OutlinedButton(onPressed: _fold, child: const Text('Fold')),
                OutlinedButton(onPressed: _check, child: const Text('Check')),
                FilledButton(onPressed: _call, child: const Text('Call')),
                FilledButton(onPressed: _raise, child: const Text('Raise')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
