import 'dart:async';
import 'dart:io';
import 'package:Infivity/services/wifi_service.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:location/location.dart';
import 'package:device_info_plus/device_info_plus.dart';

class AttendancePage extends StatefulWidget {
  final String employeeId;
  final String employeeName;

  const AttendancePage({
    super.key,
    required this.employeeId,
    required this.employeeName,
  });

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  bool isCheckedIn = false;
  bool isCheckedOut = false;
  Duration elapsed = Duration.zero;
  Timer? timer;
  DateTime? checkInTime;

  final Color primaryColor = const Color(0xFF4E2780);
  final Color accentColor = const Color(0xFFFFDE59);
  final String officeSsid = "INFIVITY";

  @override
  void initState() {
    super.initState();
    _checkTodayStatus();
  }

  // ---------------- Device ID ----------------
  Future<String> getDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id;
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return iosInfo.identifierForVendor ?? "unknown";
    } else {
      return "unsupported-platform";
    }
  }

  // ---------------- Permission ----------------
  Future<bool> requestLocationPermission() async {
    var status = await Permission.location.status;
    if (status.isDenied || status.isRestricted) {
      status = await Permission.location.request();
    }
    return status.isGranted;
  }

  // ---------------- Load Today's Attendance ----------------
  Future<void> _checkTodayStatus() async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final docRef = FirebaseFirestore.instance
        .collection('employees')
        .doc(widget.employeeId)
        .collection('attendance')
        .doc(today);

    try {
      final doc = await docRef.get();
      if (doc.exists) {
        final data = doc.data()!;
        final checkIn = data['checkin_time'] != null
            ? (data['checkin_time'] as Timestamp).toDate()
            : null;
        final checkOut = data['checkout_time'] != null
            ? (data['checkout_time'] as Timestamp).toDate()
            : null;
        final spent = data['time_spent'] ?? 0;

        if (checkIn != null && checkOut == null) {
          setState(() {
            isCheckedIn = true;
            isCheckedOut = false;
            checkInTime = checkIn;
            elapsed = DateTime.now().difference(checkInTime!);
          });

          timer = Timer.periodic(const Duration(seconds: 1), (_) {
            setState(() {
              elapsed = DateTime.now().difference(checkInTime!);
            });
          });
        } else if (checkIn != null && checkOut != null) {
          setState(() {
            isCheckedIn = true;
            isCheckedOut = true;
            elapsed = Duration(seconds: spent);
          });
        }
      }
    } catch (e) {
      _showSnack('Failed to load today\'s attendance: $e');
    }
  }

  // ---------------- Register Device (One-Time) ----------------
  Future<void> _registerDevice() async {
    try {
      final deviceId = await getDeviceId();
      final docRef =
          FirebaseFirestore.instance.collection('employees').doc(widget.employeeId);
      await docRef.get();

      // 🟢 Added: Global device ownership check
      final deviceDoc = await FirebaseFirestore.instance
          .collection('devices')
          .doc(deviceId)
          .get();

      if (deviceDoc.exists) {
        final registeredTo = deviceDoc.data()?['employee_id'];
        if (registeredTo != widget.employeeId) {
          _showSnack('❌ This device is already registered to another employee.');
          return;
        } else {
          _showSnack('This device is already registered for you.');
          return;
        }
      }

      // Existing logic to save device under employee
      await docRef.set({
        'allowed_devices': FieldValue.arrayUnion([deviceId])
      }, SetOptions(merge: true));

      // 🟢 Added: Save globally in devices collection
      await FirebaseFirestore.instance
          .collection('devices')
          .doc(deviceId)
          .set({
        'employee_id': widget.employeeId,
        'employee_name': widget.employeeName,
      });

      _showSnack('✅ Device registered successfully!');
    } catch (e) {
      _showSnack('Device registration failed: $e');
    }
  }
  // ---------------- Check In ----------------
  Future<void> _checkIn() async {
    try {
      final deviceId = await getDeviceId();
      final employeeDoc = await FirebaseFirestore.instance
          .collection('employees')
          .doc(widget.employeeId)
          .get();
      final allowedDevices =
          List<String>.from(employeeDoc.data()?['allowed_devices'] ?? []);

      if (!allowedDevices.contains(deviceId)) {
        _showSnack('This device is not authorized for check-in.');
        return;
      }

      final permissionGranted = await requestLocationPermission();
      if (!permissionGranted) {
        _showSnack('Location permission is required for check-in.');
        return;
      }

      Location location = Location();
      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) {
          _showSnack('Please turn on location services to check in.');
          return;
        }
      }

      final isOfficeWifi =
          await WifiService.isOnOfficeWifi(context, officeSsid: officeSsid);

      if (!isOfficeWifi) {
        _showSnack('You must be connected to the office WiFi ($officeSsid) to check in.');
        return;
      }

      final now = FieldValue.serverTimestamp();
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

      await FirebaseFirestore.instance
          .collection('employees')
          .doc(widget.employeeId)
          .collection('attendance')
          .doc(today)
          .set({
        'date': today,
        'checkin_time': now,
        'checkout_time': null,
        'time_spent': 0,
      });

      setState(() {
        isCheckedIn = true;
        checkInTime = DateTime.now();
        elapsed = Duration.zero;
        timer = Timer.periodic(const Duration(seconds: 1), (_) {
          setState(() {
            elapsed = DateTime.now().difference(checkInTime!);
          });
        });
      });

      _showSnack('Checked in successfully!');
    } catch (e) {
      _showSnack('Check-in failed: $e');
    }
  }

  // ---------------- Check Out ----------------
  Future<void> _checkOut() async {
    try {
      final deviceId = await getDeviceId();
      final employeeDoc = await FirebaseFirestore.instance
          .collection('employees')
          .doc(widget.employeeId)
          .get();
      final allowedDevices =
          List<String>.from(employeeDoc.data()?['allowed_devices'] ?? []);

      if (!allowedDevices.contains(deviceId)) {
        _showSnack('This device is not authorized for check-out.');
        return;
      }

      final permissionGranted = await requestLocationPermission();
      if (!permissionGranted) {
        _showSnack('Location permission is required for check-out.');
        return;
      }

      Location location = Location();
      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) {
          _showSnack('Please turn on location services to check out.');
          return;
        }
      }

      final isOfficeWifi =
          await WifiService.isOnOfficeWifi(context, officeSsid: officeSsid);

      if (!isOfficeWifi) {
        _showSnack('You must be connected to the office WiFi ($officeSsid) to check out.');
        return;
      }

      if (checkInTime == null) return;

      timer?.cancel();
      final now = FieldValue.serverTimestamp();
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final totalSeconds = elapsed.inSeconds;

      await FirebaseFirestore.instance
          .collection('employees')
          .doc(widget.employeeId)
          .collection('attendance')
          .doc(today)
          .update({
        'checkout_time': now,
        'time_spent': totalSeconds,
      });

      setState(() {
        isCheckedOut = true;
        elapsed = Duration(seconds: totalSeconds);
      });

      _showSnack('✅ Checked out! Total time: ${formatSeconds(totalSeconds)}');
    } catch (e) {
      _showSnack('Check-out failed: $e');
    }
  }

  // ---------------- Helpers ----------------
  String formatSeconds(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: primaryColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = formatSeconds(elapsed.inSeconds);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: Text('Welcome, ${widget.employeeName}',
         style: TextStyle(color: accentColor),
         ),
        centerTitle: true,
        actions: [
    Padding(
      padding: const EdgeInsets.only(right: 16.0, top: 8.0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(
            icon: const Icon(
              Icons.notifications,
              size: 30,
            ),
            onPressed: () {
              // Handle tap on notification bell
            },
          ),

          // 🔴 Notification badge
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: const Text(
                '3', // you can make this dynamic
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    ),
  ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(25.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Today\'s Attendance',
                style: TextStyle(
                  fontSize: 22,
                  color: primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 25),
              Text(
                'Time Spent: $timeStr',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 50),
              ElevatedButton(
                onPressed: _registerDevice,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: accentColor,
                  minimumSize: const Size(200, 50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'Register Device',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: (!isCheckedIn) ? _checkIn : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: accentColor,
                  minimumSize: const Size(200, 50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'Check In',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: (isCheckedIn && !isCheckedOut) ? _checkOut : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: accentColor,
                  minimumSize: const Size(200, 50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'Check Out',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
