import 'package:flutter/material.dart';
import 'package:pocker_in_phone/ui/home_page.dart';

void main() {
  runApp(const MentalPokerApp());
}

class MentalPokerApp extends StatelessWidget {
  const MentalPokerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mental Poker LAN',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0D5B39),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0A1A12),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}
