import 'dart:math';

class SraKeyPair {
  const SraKeyPair({
    required this.primeModulus,
    required this.publicExponent,
    required this.privateExponent,
  });

  final BigInt primeModulus;
  final BigInt publicExponent;
  final BigInt privateExponent;

  BigInt encrypt(BigInt plain) => plain.modPow(publicExponent, primeModulus);
  BigInt decrypt(BigInt cipher) => cipher.modPow(privateExponent, primeModulus);
}

class SraCrypto {
  SraCrypto({Random? random}) : _random = random ?? Random.secure();

  final Random _random;

  SraKeyPair generateKeyPair({BigInt? primeModulus}) {
    final p = primeModulus ?? BigInt.from(65537);
    final phi = p - BigInt.one;

    BigInt e;
    do {
      e = BigInt.from(3 + _random.nextInt(5000));
    } while (_gcd(e, phi) != BigInt.one);

    final d = _modInverse(e, phi);
    return SraKeyPair(primeModulus: p, publicExponent: e, privateExponent: d);
  }

  BigInt encodeCardId(int cardId) => BigInt.from(cardId + 2);
  int decodeCardId(BigInt encoded) => (encoded - BigInt.from(2)).toInt();

  BigInt _gcd(BigInt a, BigInt b) {
    var x = a;
    var y = b;
    while (y != BigInt.zero) {
      final t = x % y;
      x = y;
      y = t;
    }
    return x;
  }

  BigInt _modInverse(BigInt a, BigInt m) {
    BigInt t = BigInt.zero;
    BigInt newT = BigInt.one;
    BigInt r = m;
    BigInt newR = a;

    while (newR != BigInt.zero) {
      final quotient = r ~/ newR;
      (t, newT) = (newT, t - quotient * newT);
      (r, newR) = (newR, r - quotient * newR);
    }

    if (r > BigInt.one) {
      throw StateError('No modular inverse for selected exponent.');
    }
    if (t < BigInt.zero) {
      t += m;
    }
    return t;
  }
}
