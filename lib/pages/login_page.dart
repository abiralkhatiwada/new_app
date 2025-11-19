import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

import 'package:flutter/material.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:intl/intl.dart'; // ✅ For date formatting

import '../pages/attendance_page.dart'; // Assuming this path is correct



class LoginPage extends StatefulWidget {

  const LoginPage({super.key});



  @override

  State<LoginPage> createState() => _LoginPageState();

}



class _LoginPageState extends State<LoginPage> {

  final TextEditingController _idController = TextEditingController();

  final TextEditingController _nameController = TextEditingController();

  bool _loading = false;



  // Original colors maintained

  final Color primaryColor = const Color(0xFF4E2780); // Deep Purple

  final Color accentColor = const Color(0xFFFFDE59); // Bright Yellow/Gold

  final Color textColor = const Color(0xFF1A1A1A); // Dark text for contrast



  // 🟢 Get device ID for device restriction

  Future<String> getDeviceId() async {

    final deviceInfo = DeviceInfoPlugin();

    if (Platform.isAndroid) {

      final androidInfo = await deviceInfo.androidInfo;

      // Using device ID or a suitable identifier

      return androidInfo.id ?? "unknown_android";

    } else if (Platform.isIOS) {

      final iosInfo = await deviceInfo.iosInfo;

      // identifierForVendor is often used on iOS

      return iosInfo.identifierForVendor ?? "unknown_ios";

    } else {

      return "unsupported-platform";

    }

  }



  // Login function (Logic unchanged)

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

        setState(() => _loading = false);

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

      _showSnack('Login Error: ${e.toString()}');

    } finally {

      setState(() => _loading = false);

    }

  }



  void _showSnack(String msg) {

    ScaffoldMessenger.of(context).showSnackBar(

      SnackBar(content: Text(msg)),

    );

  }



  // --- START: UI Enhancements ---

  Widget _buildTextField({

    required TextEditingController controller,

    required String labelText,

    required IconData icon,

  }) {

    return Padding(

      padding: const EdgeInsets.symmetric(vertical: 10.0),

      child: TextField(

        controller: controller,

        cursorColor: primaryColor,

        decoration: InputDecoration(

          labelText: labelText,

          labelStyle: TextStyle(color: primaryColor),

          prefixIcon: Icon(icon, color: accentColor),

          // Polished Border Styling

          border: OutlineInputBorder(

            borderRadius: BorderRadius.circular(15.0),

            borderSide: BorderSide(color: primaryColor.withOpacity(0.5)),

          ),

          // Focused Border

          focusedBorder: OutlineInputBorder(

            borderRadius: BorderRadius.circular(15.0),

            borderSide: BorderSide(color: primaryColor, width: 2.0),

          ),

          // Subtle background fill

          filled: true,

          fillColor: accentColor.withOpacity(0.1),

        ),

      ),

    );

  }



  @override

  Widget build(BuildContext context) {

    return Scaffold(

      // Using a slightly off-white background for depth

      backgroundColor: const Color(0xFFF5F5F5),

      appBar: AppBar(

        backgroundColor: primaryColor,

        // Adjusted title style for better presence

        title: Text(

          'Secure Employee Login',

          style: TextStyle(

            color: accentColor,

            fontWeight: FontWeight.w600,

          ),

        ),

        centerTitle: true,

        elevation: 0, // No shadow for a flat app bar look

      ),

      body: Center(

        // Use SingleChildScrollView to prevent overflow on small devices

        child: SingleChildScrollView(

          padding: const EdgeInsets.all(24.0),

          child: Column(

            mainAxisAlignment: MainAxisAlignment.center,

            children: [

              // Custom Icon/Logo area

              Icon(

                Icons.fingerprint_rounded,

                size: 100,

                color: primaryColor,

              ),

              const SizedBox(height: 10),

              Text(

                'Verify Your Identity',

                style: TextStyle(

                  fontSize: 24,

                  fontWeight: FontWeight.bold,

                  color: textColor,

                ),

              ),

              const SizedBox(height: 30),



              // Login Card Container

              Card(

                elevation: 15,

                shape: RoundedRectangleBorder(

                  borderRadius: BorderRadius.circular(20),

                ),

                child: Padding(

                  padding: const EdgeInsets.all(20.0),

                  child: Column(

                    mainAxisSize: MainAxisSize.min,

                    children: [

                      // Employee ID Field

                      _buildTextField(

                        controller: _idController,

                        labelText: 'Employee ID',

                        icon: Icons.person_outline,

                      ),



                      // Employee Name Field

                      _buildTextField(

                        controller: _nameController,

                        labelText: 'Employee Name',

                        icon: Icons.badge_outlined,

                      ),



                      const SizedBox(height: 30),



                      _loading

                        ? CircularProgressIndicator(color: primaryColor)

                        : Container(

                            width: double.infinity, // Makes the button take full width of the card

                            child: ElevatedButton(

                              onPressed: login,

                              style: ElevatedButton.styleFrom(

                                backgroundColor: primaryColor,

                                foregroundColor: accentColor,

                                padding: const EdgeInsets.symmetric(vertical: 15),

                                elevation: 8, // Added more elevation for a pop effect

                                shape: RoundedRectangleBorder(

                                  borderRadius: BorderRadius.circular(15), // Rounded corners

                                ),

                              ),

                              child: const Text(

                                'S I G N   I N',

                                style: TextStyle(

                                  fontSize: 18,

                                  fontWeight: FontWeight.w900,

                                  letterSpacing: 1.5,

                                ),

                              ),

                            ),

                          ),

                    ],

                  ),

              ),

              ),

            ],

        ),

      ),
      )
    );

  }

}