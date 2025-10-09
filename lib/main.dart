import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'pages/login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Attendance App',
      theme: ThemeData(
        primaryColor: const Color(0xFF4e2780),
        colorScheme: ColorScheme.fromSwatch().copyWith(secondary: const Color(0xFFffde59)),
      ),
      debugShowCheckedModeBanner: false,
      home: const LoginPage(),
    );
  }
}
