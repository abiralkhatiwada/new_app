import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

  void login() async {
  final id = _idController.text.trim();
  final name = _nameController.text.trim();
  if (id.isEmpty || name.isEmpty) {
    _showSnack('Please enter both ID and Name');
    return;
  }

  setState(() => _loading = true);

  try {
    final docRef =
        FirebaseFirestore.instance.collection('employees').doc(id);
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
      // ✅ Ensure employee document exists (important for admin or new users)
      await docRef.set({'name': empName}, SetOptions(merge: true));

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('employee_id', id);

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
      backgroundColor: Colors.white, // ✅ light background
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: const Text('Employee Login'),
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
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
