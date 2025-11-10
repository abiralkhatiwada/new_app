import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // ✅ For date formatting
import '../pages/attendance_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  bool _loading = false;

  final Color primaryColor = const Color(0xFF4E2780);
  final Color accentColor = const Color(0xFFFFDE59);

  // 🟢 Get device ID for device restriction
  Future<String> getDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id ?? "unknown";
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return iosInfo.identifierForVendor ?? "unknown";
    } else {
      return "unsupported-platform";
    }
  }

  // Login function
  void login() async {
    final id = _idController.text.trim();
    final name = _nameController.text.trim();
    if (id.isEmpty || name.isEmpty) {
      _showSnack('Please enter both ID and Name');
      return;
    }

    setState(() => _loading = true);

    try {
      final docRef = FirebaseFirestore.instance.collection('employees').doc(id);
      final docSnap = await docRef.get();

      if (!docSnap.exists) {
        _showSnack('Invalid Employee ID');
        setState(() => _loading = false);
        return;
      }

      final empName = docSnap.data()?['name'] ?? '';
      if (empName.toLowerCase() != name.toLowerCase()) {
        _showSnack('Name does not match Employee ID');
      } else {
        // Ensure employee document exists
        await docRef.set({'name': empName}, SetOptions(merge: true));

        // Get device ID
        String deviceId = await getDeviceId();
        if (deviceId.isEmpty || deviceId == "unsupported-platform") {
          _showSnack('Unable to fetch device information');
          setState(() => _loading = false);
          return;
        }

        // Check if this device is already registered to another employee
        final deviceDoc = await FirebaseFirestore.instance
            .collection('devices')
            .doc(deviceId)
            .get();

        if (deviceDoc.exists && deviceDoc['employee_id'] != id) {
          _showSnack('This device is already registered to another employee.');
          setState(() => _loading = false);
          return;
        }

        // Link this device to employee
        await FirebaseFirestore.instance.collection('devices').doc(deviceId).set({
          'employee_id': id,
          'employee_name': empName,
        }, SetOptions(merge: true));

        await docRef.set({
          'allowed_devices': FieldValue.arrayUnion([deviceId])
        }, SetOptions(merge: true));

        // ✅ Store session data
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('employeeId', id);
        await prefs.setString('employeeName', empName);
        await prefs.setString(
          'loginDate',
          DateFormat('yyyy-MM-dd').format(DateTime.now()),
        );

        // Navigate to AttendancePage
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => AttendancePage(
              employeeId: id,
              employeeName: empName,
            ),
          ),
        );
      }
    } catch (e) {
      _showSnack('Error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: Text(
          'Employee Login',
          style: TextStyle(color: accentColor),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _idController,
              decoration: const InputDecoration(
                labelText: 'Employee ID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Employee Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 30),
            _loading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: accentColor,
                      minimumSize: const Size(200, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Login',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
