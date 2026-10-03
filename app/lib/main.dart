import 'package:flutter/material.dart';

import 'ui/mode_selection_screen.dart';

void main() {
  runApp(const FitBackApp());
}

class FitBackApp extends StatelessWidget {
  const FitBackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FitBack',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFF6B35),
          surface: Color(0xFF111111),
        ),
        useMaterial3: true,
      ),
      home: const ModeSelectionScreen(),
    );
  }
}
