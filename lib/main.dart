import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:moneymanager/View_Auth.dart';
import 'package:moneymanager/View_BottomTab.dart';
import 'package:moneymanager/firebase_options.dart';
import 'package:moneymanager/uid/uid.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Ensure bindings are initialized

  await Firebase.initializeApp(
    options:
        DefaultFirebaseOptions.currentPlatform, // Uses auto-generated options
  );

  bool isLoggedIn = await getLoginStatus();

  runApp(MyApp(isLoggedIn: isLoggedIn));
}

Future<bool> getLoginStatus() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool isLoggedIn = prefs.getBool("isLoggedIn") ?? false;
  if (isLoggedIn) {
    userId.initUid();
  }
  return isLoggedIn;
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      
      home: isLoggedIn ? BottomTab() : AuthPage(),
    );
  }
}

