import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game/game_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Lock to portrait — the game is designed for a vertical screen.
  SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
  ]);
  runApp(const ReefFeastApp());
}

class ReefFeastApp extends StatelessWidget {
  const ReefFeastApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Reef Feast',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1B86B5)),
      ),
      home: const GameScreen(),
    );
  }
}
