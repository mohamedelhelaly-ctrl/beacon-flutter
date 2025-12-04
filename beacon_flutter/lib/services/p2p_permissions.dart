import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  /// Request permissions required for Wi-Fi Direct
  static Future<bool> requestP2PPermissions() async {
    print('[PermissionService] Requesting permissions...');

    // Always required (Android 6+ uses location for WiFi scanning)
    final location = await Permission.location.request();
    print('[PermissionService] Location: $location');
    if (!location.isGranted) {
      print('[PermissionService] Location permission NOT granted.');
      return false;
    }

    // Detect SDK
    final sdk = _getAndroidSDK();
    print('[PermissionService] SDK Detected: $sdk');

    // Android 13+ (API 33) requires NEARBY_WIFI_DEVICES
    if (sdk >= 40) {
      print('[PermissionService] Requesting Nearby WiFi permission...');
      final nearby = await Permission.nearbyWifiDevices.request();
      print('[PermissionService] Nearby Result: $nearby');

      if (!nearby.isGranted) {
        print('[PermissionService] Nearby WiFi permission NOT granted.');
        return false;
      }
    } else {
      // Android 12 and below DO NOT need this permission
      print('[PermissionService] Nearby permission SKIPPED for SDK < 33');
    }

    print('[PermissionService] All required permissions granted!');
    return true;
  }

  /// Safely detect Android SDK
  static int _getAndroidSDK() {
    try {
      final release = Platform.operatingSystemVersion;
      final match = RegExp(r'Android (\d+)').firstMatch(release);
      if (match != null) return int.parse(match.group(1)!);
    } catch (_) {}
    return 33; // fallback
  }
}
