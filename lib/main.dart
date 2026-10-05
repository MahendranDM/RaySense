import 'package:flutter/material.dart';

import 'api_service.dart';
import 'login_screen.dart';
import 'main_navigation.dart';

void main() {
  runApp(const RaySenseApp());
}

class RaySenseApp extends StatelessWidget {
  const RaySenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'RaySense',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.orange,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
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
    final loggedIn = await ApiService.isLoggedIn();

    if (!mounted) {
      return;
    }

    setState(() {
      _isLoggedIn = loggedIn;
    });
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

    return LoginScreen(
      onLoginSuccess: _handleLoginSuccess,
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF5F7FA),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.wb_sunny_rounded,
              color: Colors.orange,
              size: 64,
            ),
            SizedBox(height: 20),
            Text(
              'RaySense',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Color(0xFF172033),
              ),
            ),
            SizedBox(height: 20),
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
