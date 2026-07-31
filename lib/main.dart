import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:farmigrow_ai/theme/app_theme.dart';
import 'package:farmigrow_ai/screens/splash_screen.dart';
import 'package:farmigrow_ai/screens/login_screen.dart';
import 'package:farmigrow_ai/screens/home_screen.dart';
import 'package:farmigrow_ai/services/fcm_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _runMigrations();

  // Initialize Firebase
  await Firebase.initializeApp();

  // Initialize FCM push notifications
  await FCMService.init();

  runApp(const FarmiGrowApp());
}

Future<void> _runMigrations() async {
  final prefs = await SharedPreferences.getInstance();
  final migrated = prefs.getBool('migrated_v23_cleared_demo_farms') ?? false;
  if (!migrated) {
    await prefs.remove('user_farms_v3');
    await prefs.setBool('migrated_v23_cleared_demo_farms', true);
  }
}

class FarmiGrowApp extends StatelessWidget {
  const FarmiGrowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FarmiGrow AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const AuthGate(),
      routes: {
        '/': (context) => const AuthGate(),
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}

/// Decides whether to show Login or Home screen based on auth state.
/// Firebase Auth persists the session across app restarts automatically.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Still loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }
        // Logged in
        if (snapshot.hasData && snapshot.data != null) {
          return const HomeScreen();
        }
        // Not logged in
        return const LoginScreen();
      },
    );
  }
}
