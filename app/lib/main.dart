import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'providers/player_provider.dart';
import 'ui/screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => PlayerProvider(),
      child: const EspMusicApp(),
    ),
  );
}

class EspMusicApp extends StatelessWidget {
  const EspMusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ESP Music',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF181825),
        primaryColor: const Color(0xFF89B4FA),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF89B4FA),
          secondary: Color(0xFFA6E3A1),
          surface: Color(0xFF1E1E2E),
          background: Color(0xFF181825),
        ),
        textTheme: GoogleFonts.plusJakartaSansTextTheme(
          ThemeData.dark().textTheme,
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
