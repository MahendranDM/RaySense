import 'package:flutter/material.dart';

import 'alert_screen.dart';
import 'dashboard_screen.dart';
import 'forecast_screen.dart';
import 'performance_screen.dart';
import 'report_screen.dart';
import 'settings_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({
    super.key,
  });

  @override
  State<MainNavigationScreen> createState() =>
      _MainNavigationScreenState();
}

class _MainNavigationScreenState
    extends State<MainNavigationScreen> {
  int selectedIndex = 0;

  final List<Widget> screens = const [
    DashboardScreen(),
    ForecastScreen(),
    PerformanceScreen(),
    AlertScreen(),
    ReportScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: selectedIndex,
        children: screens,
      ),

      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,

        onDestinationSelected: (index) {
          setState(() {
            selectedIndex = index;
          });
        },

        destinations: const [
          NavigationDestination(
            icon: Icon(
              Icons.dashboard_outlined,
            ),
            selectedIcon: Icon(
              Icons.dashboard,
            ),
            label: 'Dashboard',
          ),

          NavigationDestination(
            icon: Icon(
              Icons.auto_graph_outlined,
            ),
            selectedIcon: Icon(
              Icons.auto_graph,
            ),
            label: 'Forecast',
          ),

          NavigationDestination(
            icon: Icon(
              Icons.analytics_outlined,
            ),
            selectedIcon: Icon(
              Icons.analytics,
            ),
            label: 'Performance',
          ),

          NavigationDestination(
            icon: Icon(
              Icons.notifications_outlined,
            ),
            selectedIcon: Icon(
              Icons.notifications,
            ),
            label: 'Alerts',
          ),

          NavigationDestination(
            icon: Icon(
              Icons.description_outlined,
            ),
            selectedIcon: Icon(
              Icons.description,
            ),
            label: 'Reports',
          ),

          NavigationDestination(
            icon: Icon(
              Icons.settings_outlined,
            ),
            selectedIcon: Icon(
              Icons.settings,
            ),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}