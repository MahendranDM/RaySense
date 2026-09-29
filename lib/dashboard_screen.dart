import 'package:flutter/material.dart';

import 'api_service.dart';
import 'forecast_screen.dart';
import 'weather_screen.dart';
import 'generation_screen.dart';
import 'alert_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() =>
      _DashboardScreenState();
}

class _DashboardScreenState
    extends State<DashboardScreen> {

  Map<String, dynamic>? solarSystem;

  Map<String, dynamic>? latestGeneration;

  // All generation records.
  // Used to calculate today's total generation.
  List<dynamic> generationRecords = [];

  Map<String, dynamic>? latestForecast;

  // Today's calculated performance.
  Map<String, dynamic>? latestPerformance;

  bool isLoading = true;

  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadDashboardData();
  }

  // =====================================================
  // LOAD DASHBOARD DATA
  // =====================================================

  Future<void> loadDashboardData() async {
    try {
      final systems =
          await ApiService.getSolarSystems();

      final generations =
          await ApiService.getGenerationRecords();

      final forecasts =
          await ApiService.getForecasts();

      // Get today's calculated performance
      // directly from Django backend.
      final todayPerformance =
          await ApiService.getTodayPerformance();

      if (!mounted) return;

      if (systems.isNotEmpty) {
        setState(() {

          solarSystem =
              Map<String, dynamic>.from(
            systems[0],
          );

          // Store ALL generation records.
          generationRecords =
              generations;

          // Latest generation record.
          if (generations.isNotEmpty) {
            latestGeneration =
                Map<String, dynamic>.from(
              generations[0],
            );
          }

          // Latest forecast record.
          if (forecasts.isNotEmpty) {
            latestForecast =
                Map<String, dynamic>.from(
              forecasts[0],
            );
          }

          // IMPORTANT:
          // Use today's backend performance.
          latestPerformance =
              Map<String, dynamic>.from(
            todayPerformance,
          );

          isLoading = false;
          errorMessage = null;
        });

      } else {

        setState(() {
          isLoading = false;
          errorMessage =
              'No solar system found.';
        });
      }

    } catch (e) {

      if (!mounted) return;

      setState(() {
        isLoading = false;

        // SHOW THE REAL ERROR
        // instead of hiding it.
        errorMessage =
            'Error: $e';
      });
    }
  }

  // =====================================================
  // SOLAR SYSTEM INFORMATION
  // =====================================================

  String get systemName {
    return solarSystem?['system_name']
            ?.toString() ??
        'Solar System';
  }

  String get location {
    return solarSystem?['location']
            ?.toString() ??
        'Unknown location';
  }

  String get capacity {
    final value =
        solarSystem?['capacity_kw'];

    if (value == null) {
      return '--';
    }

    return '$value kW';
  }

  String get panelCount {
    final value =
        solarSystem?['panel_count'];

    if (value == null) {
      return '--';
    }

    return '$value Panels';
  }

  String get panelType {
    return solarSystem?['panel_type']
            ?.toString() ??
        '--';
  }

  // =====================================================
  // ELECTRICITY RATE
  // =====================================================

  double get electricityRate {

    final value =
        solarSystem?['electricity_rate'];

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        0.0;
  }

  // =====================================================
  // NUMBER HELPER
  // =====================================================

  double _number(dynamic value) {

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        0.0;
  }

  // =====================================================
  // CHECK WHETHER RECORD IS FROM TODAY
  // =====================================================

  bool _isToday(dynamic value) {

    if (value == null) {
      return false;
    }

    final recordedAt =
        DateTime.tryParse(
      value.toString(),
    );

    if (recordedAt == null) {
      return false;
    }

    final localTime =
        recordedAt.toLocal();

    final now =
        DateTime.now();

    return localTime.year == now.year &&
        localTime.month == now.month &&
        localTime.day == now.day;
  }

  // =====================================================
  // TODAY'S GENERATION
  // =====================================================

  double get generationValue {

    double total = 0.0;

    for (final record
        in generationRecords) {

      if (_isToday(
        record['recorded_at'],
      )) {

        total += _number(
          record['energy_generated_kwh'],
        );
      }
    }

    return total;
  }

  String get generation {

    return '${generationValue.toStringAsFixed(2)} kWh';
  }

  // =====================================================
  // EXPECTED GENERATION
  // =====================================================

  String get expectedGeneration {

    // Today's backend performance.
    final performanceValue =
        latestPerformance?[
            'predicted_generation_kwh'];

    if (performanceValue != null) {

      final number =
          double.tryParse(
                performanceValue.toString(),
              ) ??
              0.0;

      return '${number.toStringAsFixed(2)} kWh';
    }

    // Fallback to forecast.
    final forecastValue =
        latestForecast?[
            'predicted_generation_kwh'];

    if (forecastValue == null) {
      return '-- kWh';
    }

    final number =
        double.tryParse(
              forecastValue.toString(),
            ) ??
            0.0;

    return '${number.toStringAsFixed(2)} kWh';
  }

  // =====================================================
  // PERFORMANCE
  // =====================================================

  String get performancePercentage {

    final value =
        latestPerformance?[
            'performance_percentage'];

    if (value == null) {
      return '--%';
    }

    final number =
        double.tryParse(
              value.toString(),
            ) ??
            0.0;

    return '${number.toStringAsFixed(2)}%';
  }

  String get performanceStatus {

    return latestPerformance?['status']
            ?.toString() ??
        'Unknown';
  }

  // =====================================================
  // ESTIMATED SAVINGS
  // =====================================================

  double get estimatedSavings {

    return generationValue *
        electricityRate;
  }

  String get savings {

    return '₹${estimatedSavings.toStringAsFixed(2)}';
  }

  // =====================================================
  // BUILD
  // =====================================================

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(

        elevation: 0,

        backgroundColor:
            Colors.white,

        title: const Row(

          children: [

            Icon(
              Icons.wb_sunny,
              color: Colors.orange,
              size: 30,
            ),

            SizedBox(width: 10),

            Text(
              'RaySense',
              style: TextStyle(
                fontWeight:
                    FontWeight.bold,
                fontSize: 23,
              ),
            ),
          ],
        ),

        actions: [

          IconButton(
            onPressed: () {
              loadDashboardData();
            },
            icon: const Icon(
              Icons.refresh,
            ),
          ),

          const SizedBox(width: 8),
        ],
      ),

      body: SafeArea(

        child: RefreshIndicator(

          onRefresh:
              loadDashboardData,

          child:
              SingleChildScrollView(

            physics:
                const AlwaysScrollableScrollPhysics(),

            padding:
                const EdgeInsets.all(16),

            child: Column(

              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [

                // =====================================================
                // DASHBOARD TITLE
                // =====================================================

                const Text(
                  'Solar Dashboard',

                  style: TextStyle(
                    fontSize: 28,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 6),

                Text(

                  isLoading
                      ? 'Loading solar system...'
                      : errorMessage ??
                          '$systemName • $location',

                  style: TextStyle(
                    fontSize: 15,
                    color:
                        errorMessage != null
                            ? Colors.red
                            : Colors.grey.shade600,
                  ),
                ),

                const SizedBox(height: 20),

                // =====================================================
                // TODAY'S GENERATION
                // =====================================================

                Container(

                  width:
                      double.infinity,

                  padding:
                      const EdgeInsets.all(22),

                  decoration:
                      BoxDecoration(

                    gradient:
                        const LinearGradient(

                      colors: [

                        Color(0xFFFFB300),

                        Color(0xFFFF8F00),

                      ],
                    ),

                    borderRadius:
                        BorderRadius.circular(
                      20,
                    ),

                    boxShadow: [

                      BoxShadow(

                        color: Colors
                            .orange
                            .withValues(
                          alpha: 0.25,
                        ),

                        blurRadius: 12,

                        offset:
                            const Offset(
                          0,
                          6,
                        ),
                      ),
                    ],
                  ),

                  child: Column(

                    crossAxisAlignment:
                        CrossAxisAlignment.start,

                    children: [

                      const Row(

                        children: [

                          Icon(
                            Icons.bolt,
                            color:
                                Colors.white,
                            size: 28,
                          ),

                          SizedBox(width: 8),

                          Text(
                            "Today's Generation",

                            style:
                                TextStyle(
                              color:
                                  Colors.white,
                              fontSize: 17,
                              fontWeight:
                                  FontWeight.w500,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(
                        height: 12,
                      ),

                      Text(

                        isLoading
                            ? 'Loading...'
                            : generation,

                        style:
                            const TextStyle(
                          color:
                              Colors.white,
                          fontSize: 38,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      const SizedBox(
                        height: 5,
                      ),

                      const Text(
                        'Energy generated today',

                        style:
                            TextStyle(
                          color:
                              Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // =====================================================
                // EXPECTED + PERFORMANCE
                // =====================================================

                Row(

                  children: [

                    Expanded(

                      child:
                          _StatCard(

                        icon:
                            Icons.auto_graph,

                        title:
                            'Expected',

                        value:
                            isLoading
                                ? 'Loading...'
                                : expectedGeneration,
                      ),
                    ),

                    const SizedBox(
                        width: 12),

                    Expanded(

                      child:
                          _StatCard(

                        icon:
                            Icons.speed,

                        title:
                            'Performance',

                        value:
                            isLoading
                                ? 'Loading...'
                                : performancePercentage,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // =====================================================
                // SAVINGS
                // =====================================================

                Container(

                  width:
                      double.infinity,

                  padding:
                      const EdgeInsets.all(20),

                  decoration:
                      BoxDecoration(

                    color:
                        Colors.white,

                    borderRadius:
                        BorderRadius.circular(
                      18,
                    ),

                    border: Border.all(
                      color:
                          Colors.green.shade100,
                    ),

                    boxShadow: [

                      BoxShadow(

                        color: Colors
                            .black
                            .withValues(
                          alpha: 0.03,
                        ),

                        blurRadius: 8,

                        offset:
                            const Offset(
                          0,
                          3,
                        ),
                      ),
                    ],
                  ),

                  child: Row(

                    children: [

                      Container(

                        padding:
                            const EdgeInsets.all(
                          12,
                        ),

                        decoration:
                            BoxDecoration(

                          color: Colors
                              .green
                              .shade50,

                          shape:
                              BoxShape.circle,
                        ),

                        child: Icon(

                          Icons
                              .currency_rupee,

                          color: Colors
                              .green
                              .shade600,

                          size: 30,
                        ),
                      ),

                      const SizedBox(
                          width: 14),

                      Expanded(

                        child:
                            Column(

                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,

                          children: [

                            const Text(
                              'Estimated Savings',

                              style:
                                  TextStyle(
                                fontSize:
                                    17,
                                fontWeight:
                                    FontWeight
                                        .bold,
                              ),
                            ),

                            const SizedBox(
                                height: 5),

                            Text(

                              isLoading
                                  ? 'Calculating...'
                                  : savings,

                              style:
                                  TextStyle(

                                color: Colors
                                    .green
                                    .shade700,

                                fontSize:
                                    25,

                                fontWeight:
                                    FontWeight
                                        .bold,
                              ),
                            ),

                            const SizedBox(
                                height: 4),

                            Text(

                              isLoading
                                  ? 'Please wait...'
                                  : 'Based on ${generationValue.toStringAsFixed(2)} kWh × ₹${electricityRate.toStringAsFixed(2)}/kWh',

                              style:
                                  TextStyle(

                                color: Colors
                                    .grey
                                    .shade600,

                                fontSize:
                                    12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // =====================================================
                // SYSTEM PERFORMANCE
                // =====================================================

                Container(

                  width:
                      double.infinity,

                  padding:
                      const EdgeInsets.all(18),

                  decoration:
                      BoxDecoration(

                    color:
                        Colors.white,

                    borderRadius:
                        BorderRadius.circular(
                      18,
                    ),

                    border: Border.all(
                      color:
                          Colors.green.shade100,
                    ),
                  ),

                  child: Row(

                    children: [

                      Container(

                        padding:
                            const EdgeInsets.all(
                          12,
                        ),

                        decoration:
                            BoxDecoration(

                          color: Colors
                              .green
                              .shade50,

                          shape:
                              BoxShape.circle,
                        ),

                        child: Icon(

                          performanceStatus ==
                                  'Excellent'
                              ? Icons.check_circle
                              : performanceStatus ==
                                      'Good'
                                  ? Icons.check_circle
                                  : performanceStatus ==
                                          'Pending'
                                      ? Icons
                                          .hourglass_empty
                                      : Icons
                                          .warning,

                          color:
                              performanceStatus ==
                                      'Pending'
                                  ? Colors.orange
                                  : Colors
                                      .green
                                      .shade600,

                          size: 30,
                        ),
                      ),

                      const SizedBox(
                          width: 14),

                      Expanded(

                        child:
                            Column(

                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,

                          children: [

                            const Text(
                              'System Performance',

                              style:
                                  TextStyle(
                                fontSize:
                                    16,
                                fontWeight:
                                    FontWeight
                                        .bold,
                              ),
                            ),

                            const SizedBox(
                                height: 4),

                            Text(

                              isLoading
                                  ? 'Loading...'
                                  : performanceStatus,

                              style:
                                  TextStyle(
                                color:
                                    performanceStatus ==
                                            'Pending'
                                        ? Colors
                                            .orange
                                        : Colors
                                            .green,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // =====================================================
                // QUICK ACCESS
                // =====================================================

                const Text(
                  'Quick Access',

                  style: TextStyle(
                    fontSize: 20,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 14),

                // Generation + Weather
                Row(

                  children: [

                    Expanded(

                      child:
                          _FeatureCard(

                        icon:
                            Icons.bolt,

                        title:
                            'Generation',

                        onTap: () {

                          Navigator.push(

                            context,

                            MaterialPageRoute(

                              builder:
                                  (context) =>
                                      const GenerationScreen(),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(
                        width: 12),

                    Expanded(

                      child:
                          _FeatureCard(

                        icon:
                            Icons
                                .cloud_outlined,

                        title:
                            'Weather',

                        onTap: () {

                          Navigator.push(

                            context,

                            MaterialPageRoute(

                              builder:
                                  (context) =>
                                      const WeatherScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Forecast + Alerts
                Row(

                  children: [

                    Expanded(

                      child:
                          _FeatureCard(

                        icon:
                            Icons.auto_graph,

                        title:
                            'Forecast',

                        onTap: () {

                          Navigator.push(

                            context,

                            MaterialPageRoute(

                              builder:
                                  (context) =>
                                      const ForecastScreen(),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(
                        width: 12),

                    Expanded(

                      child:
                          _FeatureCard(

                        icon: Icons
                            .notifications_outlined,

                        title:
                            'Alerts',

                        onTap: () {

                          Navigator.push(

                            context,

                            MaterialPageRoute(

                              builder:
                                  (context) =>
                                      const AlertScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 25),

                // =====================================================
                // SYSTEM INFORMATION
                // =====================================================

                const Text(
                  'System Information',

                  style: TextStyle(
                    fontSize: 20,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                Container(

                  width:
                      double.infinity,

                  padding:
                      const EdgeInsets.all(18),

                  decoration:
                      BoxDecoration(

                    color:
                        Colors.white,

                    borderRadius:
                        BorderRadius.circular(
                      18,
                    ),
                  ),

                  child: Column(

                    children: [

                      _InfoRow(

                        icon:
                            Icons.solar_power,

                        title:
                            'System Capacity',

                        value:
                            isLoading
                                ? 'Loading...'
                                : capacity,
                      ),

                      const Divider(
                        height: 22,
                      ),

                      _InfoRow(

                        icon:
                            Icons.grid_view,

                        title:
                            'Panel Count',

                        value:
                            isLoading
                                ? 'Loading...'
                                : panelCount,
                      ),

                      const Divider(
                        height: 22,
                      ),

                      _InfoRow(

                        icon:
                            Icons
                                .category_outlined,

                        title:
                            'Panel Type',

                        value:
                            isLoading
                                ? 'Loading...'
                                : panelType,
                      ),

                      const Divider(
                        height: 22,
                      ),

                      _InfoRow(

                        icon:
                            Icons
                                .location_on_outlined,

                        title:
                            'Location',

                        value:
                            isLoading
                                ? 'Loading...'
                                : location,
                      ),

                      const Divider(
                        height: 22,
                      ),

                      _InfoRow(

                        icon:
                            Icons.currency_rupee,

                        title:
                            'Electricity Rate',

                        value:
                            isLoading
                                ? 'Loading...'
                                : '₹${electricityRate.toStringAsFixed(2)} / kWh',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =====================================================
// STATISTICS CARD
// =====================================================

class _StatCard
    extends StatelessWidget {

  final IconData icon;

  final String title;

  final String value;

  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(
      BuildContext context) {

    return Container(

      padding:
          const EdgeInsets.all(18),

      decoration:
          BoxDecoration(

        color:
            Colors.white,

        borderRadius:
            BorderRadius.circular(
          18,
        ),
      ),

      child: Column(

        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [

          Icon(
            icon,
            color:
                Colors.orange,
            size: 28,
          ),

          const SizedBox(
              height: 12),

          Text(

            title,

            style: TextStyle(
              color:
                  Colors.grey.shade600,
              fontSize: 14,
            ),
          ),

          const SizedBox(height: 5),

          Text(

            value,

            style:
                const TextStyle(
              fontSize: 18,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================
// FEATURE CARD
// =====================================================

class _FeatureCard
    extends StatelessWidget {

  final IconData icon;

  final String title;

  final VoidCallback onTap;

  const _FeatureCard({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(
      BuildContext context) {

    return Material(

      color:
          Colors.transparent,

      child: InkWell(

        onTap: onTap,

        borderRadius:
            BorderRadius.circular(
          18,
        ),

        child: Container(

          padding:
              const EdgeInsets.symmetric(

            vertical: 22,

            horizontal: 12,
          ),

          decoration:
              BoxDecoration(

            color:
                Colors.white,

            borderRadius:
                BorderRadius.circular(
              18,
            ),
          ),

          child: Column(

            children: [

              Icon(

                icon,

                size: 32,

                color:
                    Colors.orange,
              ),

              const SizedBox(
                  height: 10),

              Text(

                title,

                style:
                    const TextStyle(

                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================================================
// INFORMATION ROW
// =====================================================

class _InfoRow
    extends StatelessWidget {

  final IconData icon;

  final String title;

  final String value;

  const _InfoRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(
      BuildContext context) {

    return Row(

      children: [

        Icon(

          icon,

          color:
              Colors.orange,

          size: 25,
        ),

        const SizedBox(
            width: 14),

        Expanded(

          child: Text(

            title,

            style: TextStyle(

              color:
                  Colors.grey.shade700,
            ),
          ),
        ),

        Flexible(

          child: Text(

            value,

            textAlign:
                TextAlign.end,

            style:
                const TextStyle(

              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}