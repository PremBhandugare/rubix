
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:rubix/screens/AuthScr.dart';
import 'package:rubix/screens/splash.dart';
import 'package:rubix/screens/tabScr.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform
  );
  runApp(const App());
}
 
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Rubix',
      theme: ThemeData().copyWith(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
            seedColor:Colors.orange),
            primaryColor: Colors.orange,
        textTheme: GoogleFonts.openSansTextTheme(),    
      ),
      home:StreamBuilder(
        stream: FirebaseAuth.instance.authStateChanges(), 
        builder: (ctx,snapshot){
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SplashScr();
          }

          if (snapshot.hasData) {
            return  TabScr();
          }

          return const LoginScr();
        }
        ),
    );
  }
}