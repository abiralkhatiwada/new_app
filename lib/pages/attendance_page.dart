import 'dart:async';
import 'dart:io';
import 'package:Infivity/notifications_page.dart';
import 'package:Infivity/services/in_app_notification_service.dart';
import 'package:Infivity/services/wifi_service.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:location/location.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../pages/login_page.dart';

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
  bool isDeviceRegistered = false;
  bool isLoadingDevice = true;
  Duration elapsed = Duration.zero;
  Timer? timer;
  Timer? _autoLogoutTimer;
  DateTime? checkInTime;

  final Color primaryColor = const Color(0xFF4E2780);
  final Color accentColor = const Color(0xFFFFDE59);
  final String officeSsid = "INFIVITY";

  @override
  void initState() {
    super.initState();

    _checkDeviceRegistration();
    _checkTodayStatus();

    // Save FCM token
    final _notificationService = InAppNotificationService();
    _notificationService.saveToken(widget.employeeId);

    // Listen to Firestore in-app notifications
    FirebaseFirestore.instance
        .collection('employees')
        .doc(widget.employeeId)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          if (data != null) {
            _showSnack('🔔 ${data['title'] ?? 'New notification'}');
          }
        }
      }
    });

    _setupAutoLogout();
  }

  // ---------------- Auto Logout ----------------
  Future<void> _setupAutoLogout() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(today);
    final lastActiveDate = prefs.getString('lastActiveDate');

    if (lastActiveDate != null && lastActiveDate != todayStr) {
      _showSnack('Session expired. Please log in again.');
      await prefs.remove('lastActiveDate');
      _logout();
      return;
    }

    await prefs.setString('lastActiveDate', todayStr);

    final midnight = DateTime(today.year, today.month, today.day + 1);
    final durationUntilMidnight = midnight.difference(today);

    _autoLogoutTimer = Timer(durationUntilMidnight, () async {
      _showSnack('Session ended. You have been logged out automatically.');
      await prefs.remove('lastActiveDate');
      _logout();
    });
  }

  // ---------------- Logout Function ----------------
  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('lastActiveDate');

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    _autoLogoutTimer?.cancel();
    super.dispose();
  }

  // ---------------- Device ID ----------------
  Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();

    String? savedId = prefs.getString('device_id');
    if (savedId != null) return savedId;

    final deviceInfo = DeviceInfoPlugin();
    String newId;

    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      newId = '${androidInfo.model}_${const Uuid().v4()}';
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      newId = iosInfo.identifierForVendor ?? const Uuid().v4();
    } else {
      newId = const Uuid().v4();
    }

    await prefs.setString('device_id', newId);
    return newId;
  }

 // ---------------- Device Registration Status ----------------
Future<void> _checkDeviceRegistration() async {
  try {
    final deviceId = await getDeviceId();
    final deviceRef =
        FirebaseFirestore.instance.collection('devices').doc(deviceId);
    final deviceDoc = await deviceRef.get();

    if (deviceDoc.exists) {
      // Device is already registered
      final registeredEmployee = deviceDoc.data()?['employee_id'];

      if (registeredEmployee == widget.employeeId) {
        // Device belongs to this employee → all good
        setState(() {
          isDeviceRegistered = true;
        });
        _showSnack('✅ Device already registered to you.');
      } else {
        // Device belongs to someone else → block registration
        _showSnack(
          '⚠️ This device is already registered to another employee ($registeredEmployee). Registration denied.',
        );
      }
    } else {
      // Device not yet registered → register once
      await deviceRef.set({
        'employee_id': widget.employeeId,
        'registered_at': DateTime.now().toIso8601String(),
      });

      setState(() {
        isDeviceRegistered = true;
      });

      _showSnack('✅ Device successfully registered.');
    }
  } catch (e) {
    setState(() {
      isLoadingDevice = false;
    });
    _showSnack('❌ Error checking device registration: $e');
  } finally {
    setState(() {
      isLoadingDevice = false;
    });
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

  // ---------------- Register Device ----------------
  Future<void> _registerDevice() async {
    if (isDeviceRegistered) {
      _showSnack('This device is already registered for you.');
      return;
    }

    try {
      final deviceId = await getDeviceId();
      final employeeId = widget.employeeId;
      final employeeName = widget.employeeName;

      final deviceDocRef =
          FirebaseFirestore.instance.collection('devices').doc(deviceId);

      final deviceDoc = await deviceDocRef.get();

      if (deviceDoc.exists) {
        final registeredTo = deviceDoc.data()?['employee_id'];
        if (registeredTo == employeeId) {
          setState(() {
            isDeviceRegistered = true;
          });
          _showSnack('This device is already registered for you.');
        } else {
          _showSnack(
              '❌ This device is already registered to another employee ($registeredTo).');
        }
        return;
      }

      await deviceDocRef.set({
        'employee_id': employeeId,
        'employee_name': employeeName,
        'registered_at': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance
          .collection('employees')
          .doc(employeeId)
          .set({
        'allowed_devices': FieldValue.arrayUnion([deviceId])
      }, SetOptions(merge: true));

      setState(() {
        isDeviceRegistered = true;
      });

      _showSnack('✅ Device registered successfully!');
    } catch (e) {
      _showSnack('Device registration failed: $e');
    }
  }

  // ---------------- Check In ----------------
  Future<void> _checkIn() async {
    if (!isDeviceRegistered) {
      _showSnack('Please register your device before checking in.');
      return;
    }

    try {
      final deviceId = await getDeviceId();
      final deviceDoc = await FirebaseFirestore.instance
          .collection('devices')
          .doc(deviceId)
          .get();

      if (!deviceDoc.exists ||
          deviceDoc.data()?['employee_id'] != widget.employeeId) {
        _showSnack('❌ This device is not authorized for check-in.');
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
        _showSnack(
            'You must be connected to the office WiFi ($officeSsid) to check in.');
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
      final deviceDoc = await FirebaseFirestore.instance
          .collection('devices')
          .doc(deviceId)
          .get();

      if (!deviceDoc.exists ||
          deviceDoc.data()?['employee_id'] != widget.employeeId) {
        _showSnack('❌ This device is not authorized for check-out.');
        return;
      }

      final isOfficeWifi =
          await WifiService.isOnOfficeWifi(context, officeSsid: officeSsid);

      if (!isOfficeWifi) {
        _showSnack(
            'You must be connected to the office WiFi ($officeSsid) to check out.');
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

  // ---------------- Notification Widget ----------------
  Widget _buildNotificationIcon() {
    final notificationsStream = FirebaseFirestore.instance
        .collection('employees')
        .doc(widget.employeeId)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: notificationsStream,
      builder: (context, snapshot) {
        int unreadCount = 0;
        if (snapshot.hasData) {
          unreadCount = snapshot.data!.docs.length;
        }

        return Padding(
          padding: const EdgeInsets.only(right: 16.0, top: 8.0),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications, size: 30, color: Colors.white),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          NotificationPage(userId: widget.employeeId),
                    ),
                  );
                },
              ),
              if (unreadCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints:
                        const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      unreadCount > 99 ? '99+' : '$unreadCount',
                      style: const TextStyle(
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
        );
      },
    );
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    final timeStr = formatSeconds(elapsed.inSeconds);
    final isRegisterEnabled = !isDeviceRegistered && !isLoadingDevice;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: primaryColor,
        leading: IconButton(
          icon: Transform(
            alignment: Alignment.center,
            transform: Matrix4.rotationY(3.1416),
            child: const Icon(Icons.logout, color: Colors.white),
          ),
          onPressed: _logout,
          tooltip: 'Logout',
        ),
        title: Text(
          'Welcome, ${widget.employeeName}',
          style: TextStyle(color: accentColor),
        ),
        centerTitle: true,
        actions: [_buildNotificationIcon()],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(25.0),
          child: isLoadingDevice
              ? const CircularProgressIndicator()
              : Column(
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
                      onPressed: isRegisterEnabled ? _registerDevice : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isRegisterEnabled
                            ? primaryColor
                            : Colors.grey[400],
                        foregroundColor: accentColor,
                        minimumSize: const Size(200, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        isDeviceRegistered
                            ? 'Device Registered'
                            : 'Register Device',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed:
                          (!isCheckedIn && isDeviceRegistered) ? _checkIn : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: (!isCheckedIn && isDeviceRegistered)
                            ? primaryColor
                            : Colors.grey[400],
                        foregroundColor: accentColor,
                        minimumSize: const Size(200, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Check In',
                        style:
                            TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: (isCheckedIn && !isCheckedOut) ? _checkOut : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            (isCheckedIn && !isCheckedOut)
                                ? primaryColor
                                : Colors.grey[400],
                        foregroundColor: accentColor,
                        minimumSize: const Size(200, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Check Out',
                        style:
                            TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
