import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/registration_screen.dart';
import 'screens/report_issue_screen.dart';
import 'screens/map_screen.dart';
import 'screens/reports_list_screen.dart';
import 'firebase_options.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await Supabase.initialize(
    url: 'https://locqqjqbdrvoxqofedrh.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImxvY3FxanFiZHJ2b3hxb2ZlZHJoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDIzNzU1NDMsImV4cCI6MjA1Nzk1MTU0M30.rvpI3aHaYk5LrTsIBBO1tohslPc9Mfy6_iilktGD7nY',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CityFix',
      theme: ThemeData(primarySwatch: Colors.blue),
      debugShowCheckedModeBanner: false,
      home: SplashScreen(),
      routes: {
        '/home': (context) => HomeScreen(),
        '/login': (context) => LoginScreen(),
        '/register': (context) => RegistrationScreen(),
        '/report': (context) => ReportIssueScreen(),
        '/map': (context) => MapScreen(),
        '/reports': (context) => ReportsListScreen(),
      },
    );
  }
}
