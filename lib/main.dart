import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:project_1/pages/home_screen.dart';
import 'package:project_1/pages/login_page.dart';

// Create material color from a single color
MaterialColor createMaterialColor(Color color) {
  List<double> strengths = <double>[.05, .1, .2, .3, .4, .5, .6, .7, .8, .9];
  Map<int, Color> swatch = {};
  final int r = color.red, g = color.green, b = color.blue;

  for (var strength in strengths) {
    final double ds = 0.5 - strength;
    swatch[(strength * 1000).round()] = Color.fromRGBO(
      r + ((ds < 0 ? r : (255 - r)) * ds).round(),
      g + ((ds < 0 ? g : (255 - g)) * ds).round(),
      b + ((ds < 0 ? b : (255 - b)) * ds).round(),
      1,
    );
  }
  return MaterialColor(color.value, swatch);
}

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();
// Background message handler
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp();

  // Initialize Firebase App Check
  await FirebaseAppCheck.instance.activate();

  // Initialize Firebase Messaging
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
      // Define routes for navigation
      initialRoute: '/',
      routes: {
        '/': (context) => StreamBuilder<User?>(
              stream: _auth.authStateChanges(),
              builder: (context, snapshot) {
                // Show loading indicator while checking auth state
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Scaffold(
                    body: Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                // If user is authenticated, show HomeScreen
                if (snapshot.hasData && snapshot.data != null) {
                  return HomeScreen();
                }

                // If user is not authenticated, show LoginPage
                return AuthScreen();
              },
            ),
        '/home': (context) => HomeScreen(),
      },
    );
  }
}
