import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Parent PIN service: salt + SHA-256 hashing, local + Firestore sync.
///
/// The PIN is never stored in plain text. The hash and salt are stored in
/// SharedPreferences on the child device and synced to Firestore via
/// rules/main (parentPinHash, parentPinSalt).
class PinService {
  static const String _prefPinHash = 'orbit_parent_pin_hash';
  static const String _prefPinSalt = 'orbit_parent_pin_salt';

  final SharedPreferences _prefs;

  PinService(this._prefs);

  /// Generates a random 16-character base64url salt.
  String _generateSalt() {
    final random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(256));
    return base64Url.encode(values);
  }

  /// Hashes a PIN with a salt using SHA-256.
  String _hashPin(String pin, String salt) {
    final input = '$pin:$salt';
    final bytes = utf8.encode(input);
    final digest = _sha256(bytes);
    return digest.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// SHA-256 implementation (pure Dart, no external packages).
  List<int> _sha256(List<int> data) {
    // Initial hash values
    var h0 = 0x6a09e667;
    var h1 = 0xbb67ae85;
    var h2 = 0x3c6ef372;
    var h3 = 0xa54ff53a;
    var h4 = 0x510e527f;
    var h5 = 0x9b05688c;
    var h6 = 0x1f83d9ab;
    var h7 = 0x5be0cd19;

    // Round constants
    final k = [
      0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1,
      0x923f82a4, 0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
      0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786,
      0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
      0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147,
      0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
      0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b,
      0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
      0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a,
      0x5b9cca4f, 0x682e6ff3, 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
      0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
    ];

    // Pre-processing: append padding
    final bitLen = data.length * 8;
    final msg = List<int>.from(data);
    msg.add(0x80);
    while ((msg.length % 64) != 56) {
      msg.add(0);
    }
    // Append length as big-endian 64-bit
    for (var i = 7; i >= 0; i--) {
      msg.add((bitLen >> (i * 8)) & 0xFF);
    }

    // Process chunks
    for (var chunkOffset = 0; chunkOffset < msg.length; chunkOffset += 64) {
      final w = List<int>.filled(64, 0);
      for (var i = 0; i < 16; i++) {
        w[i] = (msg[chunkOffset + i * 4] << 24) |
            (msg[chunkOffset + i * 4 + 1] << 16) |
            (msg[chunkOffset + i * 4 + 2] << 8) |
            (msg[chunkOffset + i * 4 + 3]);
      }
      for (var i = 16; i < 64; i++) {
        final s0 = _rotr(w[i - 15], 7) ^ _rotr(w[i - 15], 18) ^ (w[i - 15] >> 3);
        final s1 = _rotr(w[i - 2], 17) ^ _rotr(w[i - 2], 19) ^ (w[i - 2] >> 10);
        w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & 0xFFFFFFFF;
      }

      var a = h0;
      var b = h1;
      var c = h2;
      var d = h3;
      var e = h4;
      var f = h5;
      var g = h6;
      var hh = h7;

      for (var i = 0; i < 64; i++) {
        final S1 = _rotr(e, 6) ^ _rotr(e, 11) ^ _rotr(e, 25);
        final ch = (e & f) ^ (~e & g);
        final temp1 = (hh + S1 + ch + k[i] + w[i]) & 0xFFFFFFFF;
        final S0 = _rotr(a, 2) ^ _rotr(a, 13) ^ _rotr(a, 22);
        final maj = (a & b) ^ (a & c) ^ (b & c);
        final temp2 = (S0 + maj) & 0xFFFFFFFF;

        hh = g;
        g = f;
        f = e;
        e = (d + temp1) & 0xFFFFFFFF;
        d = c;
        c = b;
        b = a;
        a = (temp1 + temp2) & 0xFFFFFFFF;
      }

      h0 = (h0 + a) & 0xFFFFFFFF;
      h1 = (h1 + b) & 0xFFFFFFFF;
      h2 = (h2 + c) & 0xFFFFFFFF;
      h3 = (h3 + d) & 0xFFFFFFFF;
      h4 = (h4 + e) & 0xFFFFFFFF;
      h5 = (h5 + f) & 0xFFFFFFFF;
      h6 = (h6 + g) & 0xFFFFFFFF;
      h7 = (h7 + hh) & 0xFFFFFFFF;
    }

    return [
      (h0 >> 24) & 0xFF, (h0 >> 16) & 0xFF, (h0 >> 8) & 0xFF, h0 & 0xFF,
      (h1 >> 24) & 0xFF, (h1 >> 16) & 0xFF, (h1 >> 8) & 0xFF, h1 & 0xFF,
      (h2 >> 24) & 0xFF, (h2 >> 16) & 0xFF, (h2 >> 8) & 0xFF, h2 & 0xFF,
      (h3 >> 24) & 0xFF, (h3 >> 16) & 0xFF, (h3 >> 8) & 0xFF, h3 & 0xFF,
      (h4 >> 24) & 0xFF, (h4 >> 16) & 0xFF, (h4 >> 8) & 0xFF, h4 & 0xFF,
      (h5 >> 24) & 0xFF, (h5 >> 16) & 0xFF, (h5 >> 8) & 0xFF, h5 & 0xFF,
      (h6 >> 24) & 0xFF, (h6 >> 16) & 0xFF, (h6 >> 8) & 0xFF, h6 & 0xFF,
      (h7 >> 24) & 0xFF, (h7 >> 16) & 0xFF, (h7 >> 8) & 0xFF, h7 & 0xFF,
    ];
  }

  int _rotr(int x, int r) {
    return ((x >> r) | (x << (32 - r))) & 0xFFFFFFFF;
  }

  /// Returns true if a PIN has been set on this device.
  bool get hasPin {
    final hash = _prefs.getString(_prefPinHash);
    return hash != null && hash.isNotEmpty;
  }

  /// Sets the parent PIN. Generates a new salt, hashes the PIN, and stores
  /// both locally. Returns the hash and salt so the caller can sync to Firestore.
  Map<String, String> setPin(String pin) {
    if (pin.length < 4) {
      throw ArgumentError('PIN must be at least 4 digits.');
    }
    final salt = _generateSalt();
    final hash = _hashPin(pin, salt);

    _prefs.setString(_prefPinHash, hash);
    _prefs.setString(_prefPinSalt, salt);

    debugPrint('PinService: PIN set locally');

    return {'hash': hash, 'salt': salt};
  }

  /// Verifies an entered PIN against the stored hash and salt.
  bool verifyPin(String pin) {
    final hash = _prefs.getString(_prefPinHash);
    final salt = _prefs.getString(_prefPinSalt);
    if (hash == null || salt == null || hash.isEmpty || salt.isEmpty) {
      return false;
    }
    return _hashPin(pin, salt) == hash;
  }

  /// Clears the stored PIN (e.g. on unlink).
  Future<void> clearPin() async {
    await _prefs.remove(_prefPinHash);
    await _prefs.remove(_prefPinSalt);
    debugPrint('PinService: PIN cleared locally');
  }

  /// Loads the stored hash and salt, or null if no PIN is set.
  Map<String, String>? loadPin() {
    final hash = _prefs.getString(_prefPinHash);
    final salt = _prefs.getString(_prefPinSalt);
    if (hash == null || salt == null || hash.isEmpty || salt.isEmpty) {
      return null;
    }
    return {'hash': hash, 'salt': salt};
  }
}
