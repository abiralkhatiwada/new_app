import 'dart:async';
import 'package:attend/services/wifi_service.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:location/location.dart'; 

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

    final doc = await docRef.get();
    if (doc.exists) {
      final data = doc.data()!;
      final checkIn = data['checkin_time'] != null
          ? DateTime.parse(data['checkin_time'])
          : null;
      final checkOut = data['checkout_time'] != null
          ? DateTime.parse(data['checkout_time'])
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
  }

  // ---------------- Check In ----------------
 

Future<void> _checkIn() async {
  // 1️⃣ Request permission
  final permissionGranted = await requestLocationPermission();
  if (!permissionGranted) {
    _showSnack('Location permission is required for check-in.');
    return;
  }

  // 2️⃣ Check if location service is enabled
  Location location = Location();
  bool serviceEnabled = await location.serviceEnabled();
  if (!serviceEnabled) {
    serviceEnabled = await location.requestService();
    if (!serviceEnabled) {
      _showSnack('Please turn on location services to check in.');
      return;
    }
  }

  // 3️⃣ Check if connected to the **office WiFi**
  final isOfficeWifi = await WifiService.isOnOfficeWifi(
    context,
    officeSsid: officeSsid, // "INFIVITY"
  );

  if (!isOfficeWifi) {
    _showSnack('You must be connected to the office WiFi ($officeSsid) to check in.');
    return;
  }

  // 4️⃣ Everything okay → write to Firestore
  final now = DateTime.now();
  final today = DateFormat('yyyy-MM-dd').format(now);

  try {
    await FirebaseFirestore.instance
        .collection('employees')
        .doc(widget.employeeId)
        .collection('attendance')
        .doc(today)
        .set({
      'date': today,
      'checkin_time': now.toIso8601String(),
      'checkout_time': null,
      'time_spent': 0,
    });

    setState(() {
      isCheckedIn = true;
      checkInTime = now;
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
    final permissionGranted = await requestLocationPermission();
  if (!permissionGranted) {
    _showSnack('Location permission is required for check-out.');
    return;
  }

  // 2️⃣ Check if location service is enabled
  Location location = Location();
  bool serviceEnabled = await location.serviceEnabled();
  if (!serviceEnabled) {
    serviceEnabled = await location.requestService();
    if (!serviceEnabled) {
      _showSnack('Please turn on location services to check out.');
      return;
    }
  }

  // 3️⃣ Check if connected to the **office WiFi**
  final isOfficeWifi = await WifiService.isOnOfficeWifi(
    context,
    officeSsid: officeSsid, // "INFIVITY"
  );

  if (!isOfficeWifi) {
    _showSnack('You must be connected to the office WiFi ($officeSsid) to check in.');
    return;
  }

    if (checkInTime == null) return;

    timer?.cancel();
    final now = DateTime.now();
    final totalSeconds = now.difference(checkInTime!).inSeconds;
    final today = DateFormat('yyyy-MM-dd').format(now);

    try {
      await FirebaseFirestore.instance
          .collection('employees')
          .doc(widget.employeeId)
          .collection('attendance')
          .doc(today)
          .update({
        'checkout_time': now.toIso8601String(),
        'time_spent': totalSeconds,
      });

      setState(() {
        isCheckedOut = true;
        elapsed = Duration(seconds: totalSeconds);
      });

      final formattedTime = formatSeconds(totalSeconds);
      _showSnack('✅ Checked out! Total time: $formattedTime');
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
        title: Text('Welcome, ${widget.employeeName}'),
        centerTitle: true,
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