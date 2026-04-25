enum CardSuit { clubs, diamonds, hearts, spades }

enum CardRank {
  two(2),
  three(3),
  four(4),
  five(5),
  six(6),
  seven(7),
  eight(8),
  nine(9),
  ten(10),
  jack(11),
  queen(12),
  king(13),
  ace(14);

  const CardRank(this.value);
  final int value;
}

class PlayingCard {
  const PlayingCard({required this.suit, required this.rank, required this.id});

  final CardSuit suit;
  final CardRank rank;
  final int id;

  String get shortLabel {
    final rankLabel = switch (rank) {
      CardRank.ace => 'A',
      CardRank.king => 'K',
      CardRank.queen => 'Q',
      CardRank.jack => 'J',
      CardRank.ten => '10',
      _ => rank.value.toString(),
    };
    final suitLabel = switch (suit) {
      CardSuit.clubs => '♣',
      CardSuit.diamonds => '♦',
      CardSuit.hearts => '♥',
      CardSuit.spades => '♠',
    };
    return '$rankLabel$suitLabel';
  }

  static List<PlayingCard> standardDeck() {
    var index = 0;
    final cards = <PlayingCard>[];
    for (final suit in CardSuit.values) {
      for (final rank in CardRank.values) {
        cards.add(PlayingCard(suit: suit, rank: rank, id: index));
        index++;
      }
    }
    return cards;
  }
}
