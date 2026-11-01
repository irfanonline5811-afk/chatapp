
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'splash_screen.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (!kIsWeb) {
    try {
      await GoogleSignIn.instance.initialize(
        serverClientId:
            '657341398347-br48mjomnduui2kdk9jl8d6fm8u9f9kl.apps.googleusercontent.com',
      );
    } catch (e) {
      debugPrint('Google Sign-In init error: $e');
    }
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Splash Screen',
      theme: ThemeData(

        iconTheme: IconThemeData(color: Colors.white),
      ),
      home: const SplashScreen(),
    );
  }
}


