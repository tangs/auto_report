import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

class AesKeyGenerator {
  static String getRandom(int length) {
    final sb = StringBuffer();
    final random = Random.secure();

    for (var i = 0; i < length; i++) {
      final choice = random.nextInt(2);
      if (choice == 0) {
        final letterCase = random.nextInt(2);
        if (letterCase == 0) {
          // Uppercase letter
          final letter = random.nextInt(26);
          sb.writeCharCode('A'.codeUnitAt(0) + letter);
        } else {
          // Lowercase letter
          final letter = random.nextInt(26);
          sb.writeCharCode('a'.codeUnitAt(0) + letter);
        }
      } else {
        // Digit
        final digit = random.nextInt(10);
        sb.writeCharCode('0'.codeUnitAt(0) + digit);
      }
    }

    return sb.toString();
  }

  static String getRandomIv(int length) {
    final sb = StringBuffer();
    final random = Random.secure();

    for (var i = 0; i < length; i++) {
      final choice = random.nextInt(16);
      if (choice < 10) {
        sb.write(choice.toString());
        // final letterCase = random.nextInt(2);
        // if (letterCase == 0) {
        //   // Uppercase letter
        //   final letter = random.nextInt(26);
        //   sb.writeCharCode('A'.codeUnitAt(0) + letter);
        // } else {
        //   // Lowercase letter
        //   final letter = random.nextInt(26);
        //   sb.writeCharCode('a'.codeUnitAt(0) + letter);
        // }
      } else {
        // Digit
        // final digit = random.nextInt(10);
        // sb.writeCharCode('0'.codeUnitAt(0) + digit);
        sb.write(String.fromCharCode('a'.codeUnitAt(0) + (choice - 10)));
      }
    }

    return sb.toString();
  }

  static const _keySize = 32;
  static String generateRandomKey() {
    final random = Random.secure();
    final key = Uint8List(_keySize);

    for (int i = 0; i < _keySize; i++) {
      key[i] = random.nextInt(256);
    }

    return base64Encode(key);
  }

  static const _keySize1 = 32;
  static String generateRandomKey1() {
    final random = Random.secure();
    final key = Uint8List(_keySize);

    for (int i = 0; i < _keySize; i++) {
      key[i] = random.nextInt(_keySize1);
    }

    return base64Encode(key);
  }

  static Uint8List generateRandomKeyBytes(int length) {
    final random = Random.secure();
    final key = Uint8List(length);

    for (int i = 0; i < length; i++) {
      key[i] = random.nextInt(256);
    }

    return key;
  }
}
