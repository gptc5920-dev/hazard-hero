import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';

class PasswordDigest {
  const PasswordDigest({required this.hash, required this.salt});
  final String hash;
  final String salt;
}

abstract interface class PasswordHasher {
  Future<PasswordDigest> hash(String password);
  Future<bool> verify(
    String password, {
    required String hash,
    required String salt,
  });
}

class ArgonPasswordHasher implements PasswordHasher {
  ArgonPasswordHasher({Argon2id? algorithm})
    : _algorithm =
          algorithm ??
          Argon2id(
            memory: 19456,
            parallelism: 1,
            iterations: 2,
            hashLength: 32,
          );

  final Argon2id _algorithm;

  @override
  Future<PasswordDigest> hash(String password) async {
    _validate(password);
    final random = Random.secure();
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    final key = await _algorithm.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
    return PasswordDigest(
      hash: base64Encode(await key.extractBytes()),
      salt: base64Encode(salt),
    );
  }

  @override
  Future<bool> verify(
    String password, {
    required String hash,
    required String salt,
  }) async {
    final key = await _algorithm.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: base64Decode(salt),
    );
    final actual = await key.extractBytes();
    final expected = base64Decode(hash);
    if (actual.length != expected.length) return false;
    var difference = 0;
    for (var i = 0; i < actual.length; i++) {
      difference |= actual[i] ^ expected[i];
    }
    return difference == 0;
  }

  void _validate(String password) {
    if (password.length < 10) {
      throw const FormatException(
        'Password must contain at least 10 characters.',
      );
    }
  }
}
