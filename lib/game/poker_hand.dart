import 'dart:collection';

import 'package:pocker_in_phone/game/playing_card.dart';

enum PokerHandCategory {
  highCard,
  pair,
  twoPair,
  threeOfKind,
  straight,
  flush,
  fullHouse,
  fourOfKind,
  straightFlush,
  royalFlush,
}

class PokerHandResult {
  const PokerHandResult(this.category, this.title);

  final PokerHandCategory category;
  final String title;
}

class PokerHandEvaluator {
  PokerHandResult evaluate5(List<PlayingCard> cards) {
    if (cards.length != 5) {
      throw ArgumentError('Poker evaluator expects exactly 5 cards.');
    }

    final ranks = cards.map((c) => c.rank.value).toList()..sort();
    final suits = cards.map((c) => c.suit).toSet();
    final isFlush = suits.length == 1;
    final isStraight = _isStraight(ranks);
    final counts = HashMap<int, int>();
    for (final rank in ranks) {
      counts[rank] = (counts[rank] ?? 0) + 1;
    }
    final grouped = counts.values.toList()..sort((a, b) => b.compareTo(a));

    if (isFlush && isStraight && ranks.last == 14 && ranks.first == 10) {
      return const PokerHandResult(PokerHandCategory.royalFlush, 'Royal Flush');
    }
    if (isFlush && isStraight) {
      return const PokerHandResult(
        PokerHandCategory.straightFlush,
        'Straight Flush',
      );
    }
    if (grouped.first == 4) {
      return const PokerHandResult(
        PokerHandCategory.fourOfKind,
        'Four of a Kind',
      );
    }
    if (grouped.first == 3 && grouped.length > 1 && grouped[1] == 2) {
      return const PokerHandResult(PokerHandCategory.fullHouse, 'Full House');
    }
    if (isFlush) {
      return const PokerHandResult(PokerHandCategory.flush, 'Flush');
    }
    if (isStraight) {
      return const PokerHandResult(PokerHandCategory.straight, 'Straight');
    }
    if (grouped.first == 3) {
      return const PokerHandResult(
        PokerHandCategory.threeOfKind,
        'Three of a Kind',
      );
    }
    if (grouped.length > 1 && grouped[0] == 2 && grouped[1] == 2) {
      return const PokerHandResult(PokerHandCategory.twoPair, 'Two Pair');
    }
    if (grouped.first == 2) {
      return const PokerHandResult(PokerHandCategory.pair, 'Pair');
    }
    return const PokerHandResult(PokerHandCategory.highCard, 'High Card');
  }

  PokerHandResult evaluateBestOfSeven(List<PlayingCard> cards) {
    if (cards.length < 5) {
      throw ArgumentError('At least 5 cards are required.');
    }
    PokerHandResult? best;
    for (var i = 0; i < cards.length - 4; i++) {
      for (var j = i + 1; j < cards.length - 3; j++) {
        for (var k = j + 1; k < cards.length - 2; k++) {
          for (var l = k + 1; l < cards.length - 1; l++) {
            for (var m = l + 1; m < cards.length; m++) {
              final current = evaluate5([
                cards[i],
                cards[j],
                cards[k],
                cards[l],
                cards[m],
              ]);
              if (best == null ||
                  current.category.index > best.category.index) {
                best = current;
              }
            }
          }
        }
      }
    }
    return best!;
  }

  bool _isStraight(List<int> sortedRanks) {
    final isWheel = sortedRanks.join(',') == '2,3,4,5,14';
    if (isWheel) {
      return true;
    }
    for (var i = 1; i < sortedRanks.length; i++) {
      if (sortedRanks[i] != sortedRanks[i - 1] + 1) {
        return false;
      }
    }
    return true;
  }
}
