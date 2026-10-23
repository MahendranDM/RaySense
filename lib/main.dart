import 'package:flutter/material.dart';

import 'api_service.dart';
import 'login_screen.dart';
import 'main_navigation.dart';

const Color rsBlack = Color(0xFF050505);
const Color rsBlackSoft = Color(0xFF0B0B0B);
const Color rsCard = Color(0xFF111111);
const Color rsCardAlt = Color(0xFF151515);
const Color rsGold = Color(0xFFFFD166);
const Color rsGoldBright = Color(0xFFFFCA28);
const Color rsAmber = Color(0xFFFFB703);
const Color rsText = Color(0xFFF7F7F7);
const Color rsMuted = Color(0xFFA5A5A5);

void main() {
  runApp(const RaySenseApp());
}

class RaySenseApp extends StatelessWidget {
  const RaySenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: rsGold,
      brightness: Brightness.dark,
      surface: rsCard,
      onSurface: rsText,
      primary: rsGoldBright,
      onPrimary: rsBlack,
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'RaySense',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: rsBlack,
        canvasColor: rsBlack,
        cardColor: rsCard,
        dialogBackgroundColor: rsCard,
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: rsCard,
          modalBackgroundColor: rsCard,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: rsBlackSoft,
          indicatorColor: rsGold.withValues(alpha: 0.16),
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              color: states.contains(WidgetState.selected) ? rsGold : rsMuted,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w500,
              fontSize: 11,
            ),
          ),
          iconTheme: WidgetStateProperty.resolveWith(
            (states) => IconThemeData(
              color: states.contains(WidgetState.selected) ? rsGold : rsMuted,
            ),
          ),
        ),
        cardTheme: CardThemeData(
          color: rsCard,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0x29FFD166)),
          ),
        ),
        dividerColor: const Color(0x29FFD166),
        appBarTheme: const AppBarTheme(
          backgroundColor: rsBlack,
          foregroundColor: rsText,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: rsText,
            fontSize: 21,
            fontWeight: FontWeight.bold,
          ),
          iconTheme: IconThemeData(color: rsGold),
        ),
        textTheme: ThemeData.dark().textTheme.apply(
          bodyColor: rsText,
          displayColor: rsText,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: rsCardAlt,
          labelStyle: const TextStyle(color: rsMuted),
          hintStyle: const TextStyle(color: rsMuted),
          prefixIconColor: rsGold,
          suffixIconColor: rsGold,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0x29FFD166)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0x29FFD166)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: rsGold, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.redAccent),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: rsGoldBright,
            foregroundColor: rsBlack,
            disabledBackgroundColor: rsCardAlt,
            disabledForegroundColor: rsMuted,
            elevation: 0,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: rsGold,
            side: const BorderSide(color: rsGold),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: rsGold),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: rsGoldBright,
          foregroundColor: rsBlack,
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(color: rsGold),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: rsCardAlt,
          contentTextStyle: TextStyle(color: rsText),
          behavior: SnackBarBehavior.floating,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: rsBlackSoft,
          selectedItemColor: rsGold,
          unselectedItemColor: rsMuted,
          type: BottomNavigationBarType.fixed,
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool? _isLoggedIn;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    try {
      final loggedIn = await ApiService.isLoggedIn();

      if (!mounted) return;

      setState(() {
        _isLoggedIn = loggedIn;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoggedIn = false;
      });
    }
  }

  void _handleLoginSuccess() {
    setState(() {
      _isLoggedIn = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoggedIn == null) {
      return const _LoadingScreen();
    }

    if (_isLoggedIn!) {
      return const MainNavigationScreen();
    }

    return LoginScreen(onLoginSuccess: _handleLoginSuccess);
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: rsBlack,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wb_sunny_rounded, color: rsGold, size: 64),
            SizedBox(height: 20),
            Text(
              'RaySense',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: rsText,
              ),
            ),
            SizedBox(height: 20),
            CircularProgressIndicator(color: rsGold, strokeWidth: 3),
          ],
        ),
      ),
    );
  }
}
