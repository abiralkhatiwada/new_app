import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';

class WifiService {
  /// Ensure the app has location permission AND system location services are enabled.
  /// If permission is permanently denied, opens app settings.
  /// If location services are off, opens location settings.
  static Future<bool> ensurePermissionsAndServices(BuildContext context) async {
    // 1) Request location permission
    var status = await Permission.locationWhenInUse.request();

    if (status.isPermanentlyDenied) {
      // Tell the user they must enable permission in app settings
      await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Permission required'),
          content: const Text('Location permission is permanently denied. Open app settings to grant it.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
            TextButton(onPressed: () { openAppSettings(); Navigator.pop(c, true); }, child: const Text('Open settings')),
          ],
        ),
      );
      return false;
    }

    if (!status.isGranted) return false;

    // 2) Check system location service
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Ask user to enable location services (will open device location settings)
      await showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Enable Location'),
          content: const Text('Location services must be enabled to read WiFi name. Please enable Location in system settings.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
            TextButton(onPressed: () { Geolocator.openLocationSettings(); Navigator.pop(c); }, child: const Text('Open settings')),
          ],
        ),
      );
      // Re-check after user returns
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
    }

    return serviceEnabled;
  }

  /// Returns the current SSID (cleaned of quotes), or null if unavailable.
  static Future<String?> getCurrentSsid() async {
    final info = NetworkInfo();
    String? ssid = await info.getWifiName();
    if (ssid == null) return null;
    return ssid.replaceAll('"', '');
  }

  /// Combined helper: ensure permissions/services and then test if on the office wifi.
  static Future<bool> isOnOfficeWifi(BuildContext context, {required String officeSsid}) async {
    final ok = await ensurePermissionsAndServices(context);
    if (!ok) return false;

    final ssid = await getCurrentSsid();
    debugPrint('Detected SSID abiral: $ssid');
    if (ssid == null) return false;
    return ssid == officeSsid;
  }
}
