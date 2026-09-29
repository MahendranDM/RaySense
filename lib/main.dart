import 'package:flutter/material.dart';

import 'main_navigation.dart';

void main() {
  runApp(const RaySenseApp());
}

class RaySenseApp
    extends StatelessWidget {
  const RaySenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      title: 'RaySense',

      theme: ThemeData(
        useMaterial3: true,

        colorScheme:
            ColorScheme.fromSeed(
          seedColor:
              Colors.orange,
        ),

        scaffoldBackgroundColor:
            const Color(
          0xFFF5F7FA,
        ),
      ),

      home:
          const MainNavigationScreen(),
    );
  }
}