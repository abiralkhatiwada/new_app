import 'dart:async';
import 'dart:io';
import 'dart:ui'; 
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
import '../admin/admin_notifications_sender.dart'; 
import 'profile_page.dart'; 

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

  // Admin 8-second tap
  Timer? _adminTapTimer;
  bool _isAdminTimerActive = false;

  final Color primaryColor = const Color(0xFF4E2780); // Deep Purple
  final Color accentColor = const Color(0xFFFFDE59); // Bright Yellow/Gold
  final String officeSsid = "INFIVITY";

  int unreadNotificationCount = 0;

  @override
  void initState() {
    super.initState();

    _checkDeviceRegistration();
    _checkTodayStatus();

    final notificationService = InAppNotificationService();
    notificationService.saveToken(widget.employeeId);

    FirebaseFirestore.instance
        .collection('employees')
        .doc(widget.employeeId)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      int count = snapshot.docs.length;
      setState(() {
        unreadNotificationCount = count;
      });

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

    if (!mounted) return;

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
    _adminTapTimer?.cancel();
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
        final registeredEmployee = deviceDoc.data()?['employee_id'];

        if (registeredEmployee == widget.employeeId) {
          setState(() {
            isDeviceRegistered = true;
          });
          _showSnack('✅ Device already registered to you.');
        } else {
          _showSnack(
            '⚠️ This device is already registered to another employee ($registeredEmployee). Registration denied.',
          );
        }
      } else {
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

          timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
            if (mounted) {
              setState(() {
                elapsed = DateTime.now().difference(checkInTime!);
              });
            }
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
        timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
          if (mounted) {
            setState(() {
              elapsed = DateTime.now().difference(checkInTime!);
            });
          }
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

  String _formatElapsedDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    final milliseconds = duration.inMilliseconds.remainder(1000);

    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String threeDigits(int n) => n.toString().padLeft(3, '0').substring(0, 2);

    return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}.${threeDigits(milliseconds)}';
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: primaryColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ---------------- Custom UI Widgets ----------------

  Widget _buildStatusChip(String label, IconData icon, Color color) {
    return Chip(
      avatar: Icon(icon, color: Colors.white, size: 18),
      label: Text(
        label,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      backgroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }

  Widget _buildAttendanceTimer(String timeStr) {
    return Card(
      elevation: 15,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      shadowColor: primaryColor.withOpacity(0.5),
      child: Container(
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [primaryColor.withOpacity(0.9), primaryColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            Text(
              'TOTAL TIME SPENT',
              style: TextStyle(
                fontSize: 14,
                color: accentColor.withOpacity(0.8),
                letterSpacing: 2,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              timeStr,
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w900,
                color: accentColor,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String text,
    required VoidCallback? onPressed,
    required Color color,
    required IconData icon,
  }) {
    final bool isEnabled = onPressed != null;

    return Container(
      width: double.infinity,
      height: 60,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        boxShadow: isEnabled
            ? [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  spreadRadius: 1,
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ]
            : [],
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon,
            color: isEnabled ? primaryColor : const Color.fromARGB(179, 0, 0, 0)),
        label: Text(
          text,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isEnabled ? primaryColor : const Color.fromARGB(179, 0, 0, 0),
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor:
              isEnabled ? accentColor : const Color.fromARGB(255, 132, 94, 94),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: isEnabled ? 8 : 0,
        ),
      ),
    );
  }

  Widget _buildNotificationIcon() {
    return Padding(
      padding: const EdgeInsets.only(right: 16.0, top: 8.0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            onTapDown: (_) {
              if (!_isAdminTimerActive) {
                _isAdminTimerActive = true;
                _adminTapTimer = Timer(const Duration(seconds: 8), () {
                  _isAdminTimerActive = false;
                  if (mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SendNotificationPage()),
                    );
                  }
                });
              }
            },
            onTapUp: (_) {
              if (_isAdminTimerActive) {
                _adminTapTimer?.cancel();
                _isAdminTimerActive = false;
                if (mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            NotificationPage(userId: widget.employeeId)),
                  );
                }
              }
            },
            onTapCancel: () {
              if (_isAdminTimerActive) {
                _adminTapTimer?.cancel();
                _isAdminTimerActive = false;
              }
            },
            child:
                const Icon(Icons.notifications, size: 30, color: Colors.white),
          ),
          if (unreadNotificationCount > 0)
            Positioned(
              right: 2,
              top: 2,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 3,
                      offset: Offset(0, 2),
                    )
                  ],
                ),
                constraints:
                    const BoxConstraints(minWidth: 20, minHeight: 20),
                child: Text(
                  unreadNotificationCount > 99
                      ? '99+'
                      : '$unreadNotificationCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    final timeStr = _formatElapsedDuration(elapsed);
    final isRegisterEnabled = !isDeviceRegistered && !isLoadingDevice;

    final checkInButtonColor = isCheckedIn ? Colors.grey : primaryColor;
    final checkOutButtonColor =
        (isCheckedIn && !isCheckedOut) ? Colors.redAccent : Colors.grey;
    final registerButtonColor = isDeviceRegistered ? Colors.green : primaryColor;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: primaryColor,
        elevation: 0,
        title: Text(
          'Hi, ${widget.employeeName.split(' ').first}',
          style: TextStyle(color: accentColor, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white, size: 28),
          onPressed: () {
            // ---------------- CHANGED TO BOTTOM SHEET ----------------
            showModalBottomSheet(
              context: context,
              isScrollControlled: true, // Needed to control height
              backgroundColor: Colors.transparent, // Lets ProfilePage handle curve
              builder: (context) => ProfilePage(
                employeeId: widget.employeeId,
                employeeName: widget.employeeName,
              ),
            );
            // ---------------------------------------------------------
          },
        ),
        actions: [_buildNotificationIcon()],
      ),
      body: Center(
        child: isLoadingDevice
            ? CircularProgressIndicator(color: primaryColor)
            : SingleChildScrollView(
                padding: const EdgeInsets.all(25.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: [
                        _buildStatusChip(
                          isDeviceRegistered
                              ? 'Device Registered'
                              : 'Device Not Registered',
                          isDeviceRegistered ? Icons.security : Icons.warning,
                          isDeviceRegistered ? Colors.green : Colors.orange,
                        ),
                        _buildStatusChip(
                          isCheckedOut
                              ? 'Day Completed'
                              : isCheckedIn
                                  ? 'Checked In'
                                  : 'Awaiting Check-in',
                          isCheckedOut
                              ? Icons.done_all
                              : isCheckedIn
                                  ? Icons.access_time_filled
                                  : Icons.info_outline,
                          isCheckedOut
                              ? Colors.blueAccent
                              : isCheckedIn
                                  ? Colors.deepOrange
                                  : primaryColor.withOpacity(0.7),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                    _buildAttendanceTimer(timeStr),
                    const SizedBox(height: 40),
                    _buildActionButton(
                      text: isDeviceRegistered
                          ? 'Device Registered'
                          : 'Register Device',
                      onPressed: isRegisterEnabled ? _registerDevice : null,
                      color: registerButtonColor,
                      icon: isDeviceRegistered
                          ? Icons.check_circle_outline
                          : Icons.phone_android,
                    ),
                    _buildActionButton(
                      text: 'Check In',
                      onPressed: (!isCheckedIn && isDeviceRegistered)
                          ? _checkIn
                          : null,
                      color: checkInButtonColor,
                      icon: Icons.login,
                    ),
                    _buildActionButton(
                      text: 'Check Out',
                      onPressed:
                          (isCheckedIn && !isCheckedOut) ? _checkOut : null,
                      color: checkOutButtonColor,
                      icon: Icons.logout,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}