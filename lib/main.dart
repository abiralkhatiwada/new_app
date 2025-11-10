import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'pages/login_page.dart';
import 'pages/attendance_page.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart'; // 🌟 Added

// Background handler for FCM
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  print('🔔 Background message received: ${message.messageId}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Firebase Messaging
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  // Request notification permissions (iOS)
  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  print('User granted permission: ${settings.authorizationStatus}');

  // Subscribe all users to topic "allEmployees"
  await messaging.subscribeToTopic('allEmployees');
  print('Subscribed to topic: allEmployees');

  // Handle background messages
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // 🌟 Check if user is already logged in today
  final prefs = await SharedPreferences.getInstance();
  final employeeId = prefs.getString('employeeId');
  final employeeName = prefs.getString('employeeName');
  final loginDate = prefs.getString('loginDate');

  final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

  Widget home;

  if (employeeId != null && employeeName != null && loginDate == todayStr) {
    // ✅ Logged in today, stay in attendance page
    home = AttendancePage(employeeId: employeeId, employeeName: employeeName);
  } else {
    // 🌟 Auto logout for new day or missing credentials
    await prefs.clear();
    home = const LoginPage();
  }

  runApp(MyApp(home: home));
}

class MyApp extends StatelessWidget {
  final Widget home;
  const MyApp({super.key, required this.home});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Attendance App',
      theme: ThemeData(
        primaryColor: const Color(0xFF4e2780),
        colorScheme: ColorScheme.fromSwatch().copyWith(
          secondary: const Color(0xFFffde59),
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: home,
    );
  }
}
