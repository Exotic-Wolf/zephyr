import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DeviceSessionService {
  DeviceSessionService._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _deviceIdKey = 'install_device_id';

  static Future<String> getDeviceId() async {
    final String? existing = await _storage.read(key: _deviceIdKey);
    if (existing != null && existing.trim().isNotEmpty) {
      return existing.trim();
    }

    final String generated = _generateDeviceId();
    await _storage.write(key: _deviceIdKey, value: generated);
    return generated;
  }

  static String _generateDeviceId() {
    final Random random = Random.secure();
    final String entropy = List<int>.generate(
      16,
      (_) => random.nextInt(256),
    ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    return 'mobile-${DateTime.now().microsecondsSinceEpoch}-$entropy';
  }
}
