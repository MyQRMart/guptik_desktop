import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/auth/qr_login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. INITIALIZE SUPABASE (This was missing)
  await Supabase.initialize(
    url: 'https://base.myqrmart.com',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImlzcyI6InN1cGFiYXNlLWJhc2UifQ.QL7hHqH2Ko_LNAuS--BgqHrDLFCCl3j0uQPB-FjoC4w',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Guptik Desktop',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        primaryColor: const Color(0xFF0EA5E9),
        textTheme: GoogleFonts.rajdhaniTextTheme(Theme.of(context).textTheme).apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),
      ),
      home: const QrLoginScreen(),
    );
  }
}