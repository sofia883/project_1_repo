import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:project_1/pages/home_screen.dart';
import 'package:project_1/pages/login_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:project_1/services/auth.dart';
import 'package:project_1/pages/user_listing_screen.dart';
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

// Main function remains similar but with auth state stream
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.debug,
      // Add error handling
    );
  } catch (e) {
    print('Firebase Initialization Error: $e');
  }

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  final AuthService _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorObservers: [routeObserver],
      debugShowCheckedModeBanner: false,
      title: 'Second-hand Marketplace',
      theme: ThemeData(
        primarySwatch: createMaterialColor(Color(0xFF90CAF9)),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: AppBarTheme(
          backgroundColor: createMaterialColor(Color(0xFF90CAF9)),
          foregroundColor: Colors.white,
        ),
        textTheme: TextTheme(
          headlineMedium: TextStyle(color: Colors.black87),
          bodyLarge: TextStyle(color: Colors.black87),
          bodyMedium: TextStyle(color: Colors.black54),
        ),
      ),
      home: StreamBuilder<User?>(
        stream: _authService.authStateChanges,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          if (snapshot.hasData) {
            return HomeScreen();
          }

          return PhoneAuthScreen();
        },
      ),
    );
  }
}
