import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:media_kit/media_kit.dart';
import 'package:guptik_desktop/services/admin/admin_shim.dart';
import 'package:window_manager/window_manager.dart';
import 'screens/auth/login_signup_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/auth/boot_screen.dart';
import 'package:video_player_win/video_player_win.dart';
import 'theme/app_chrome.dart';
import 'widgets/window_header.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  if (Platform.isWindows) {
    WindowsVideoPlayer.registerWith();
  }

  // 1. Initialize Window Manager (for Desktop)
  await windowManager.ensureInitialized();
  WindowOptions windowOptions = const WindowOptions(
    size: Size(1280, 800),
    center: true, 
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
    title: 'GupTik',
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    try {
      await windowManager.setIcon('lib/assets/logonobg.png');
    } catch (_) {}
    await windowManager.show();
    await windowManager.focus();
  });

  // 2. INITIALIZE SUPABASE (Critical Step)
  
  // This must happen before any screen tries to access the database.
  await Supabase.initialize(
    url: 'https://aqmcriergkczfkkdgkzc.supabase.co',
    anonKey:'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFxbWNyaWVyZ2tjemZra2Rna3pjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI1MzU1NTUsImV4cCI6MjA5ODExMTU1NX0.GTFeWOWlfPBpQabdhwNhR0TGFg3oLzf4AOGkBbs2lP0',

    // url: 'https://general-base.myqrmart.com',
    // anonKey: 'eyJhbGciOiAiSFMyNTYiLCAidHlwIjogIkpXVCJ9.eyJyb2xlIjogImFub24iLCAiaXNzIjogInN1cGFiYXNlIiwgImlhdCI6IDE3ODMyMDM3OTAsICJleHAiOiAyMDk4NTYzNzkwfQ.NMI3uwDrk6jC_mf334CKM7vIEr2GrA9EqIBiKzp6cfo',

      // 'x-role': 'anon',
    // },
    
  );

  // 3. Check Login State
  final prefs = await SharedPreferences.getInstance();
  final bool loggedIn = prefs.getBool('is_logged_in') ?? false;

  runApp(
    MyApp(startScreen: loggedIn ? const BootScreen() : const LoginSignupScreen()),
  );
}

class MyApp extends StatelessWidget {
  final Widget startScreen;
  const MyApp({super.key, required this.startScreen});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      title: 'GupTik',
      theme: Chrome.dark(
        GoogleFonts.jetBrainsMonoTextTheme(Theme.of(context).textTheme),
      ),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            children: [
              const WindowHeader(title: 'GupTik'),
              Expanded(child: child ?? const SizedBox.shrink()),
            ],
          ),
        );
      },
      home: startScreen,
    );
  }
}

// last up1112dated on 03032026
