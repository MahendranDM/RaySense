import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'api_service.dart';

class ForecastScreen extends StatefulWidget {
  const ForecastScreen({super.key});

  @override
  State<ForecastScreen> createState() => _ForecastScreenState();
}

class _ForecastScreenState extends State<ForecastScreen> {
  Map<String, dynamic>? forecastData;
  Map<String, dynamic>? solarSystem;

  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadForecast();
  }

  // =====================================================
  // Load Solar System + Forecast
  // =====================================================

  Future<void> loadForecast() async {
    try {
      if (mounted) {
        setState(() {
          isLoading = true;
          errorMessage = null;
        });
      }

      // -------------------------------------------------
      // Load Solar System from Django / MySQL
      // -------------------------------------------------

      final systems = await ApiService.getSolarSystems();

      if (systems.isEmpty) {
        throw Exception('No solar system found.');
      }

      final system = Map<String, dynamic>.from(systems[0]);

      // -------------------------------------------------
      // Read saved system capacity
      // -------------------------------------------------

      final capacityValue = double.tryParse(
        system['capacity_kw']?.toString() ?? '',
      );

      if (capacityValue == null || capacityValue <= 0) {
        throw Exception('Invalid system capacity.');
      }

      // -------------------------------------------------
      // Request ML forecast
      // Django now reads location + capacity
      // directly from the database.
      // -------------------------------------------------

      final data = await ApiService.getMLWeatherForecast();

      if (!mounted) return;

      setState(() {
        solarSystem = system;
        forecastData = data;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = 'Unable to load AI forecast.';
      });
    }
  }

  // =====================================================
  // Get Generation
  // =====================================================

  double _getGeneration(String key) {
    final value = forecastData?[key]?['generation_kwh'];

    if (value == null) {
      return 0.0;
    }

    return double.tryParse(value.toString()) ?? 0.0;
  }

  // =====================================================
  // Format kWh
  // =====================================================

  String _formatKwh(double value) {
    return '${value.toStringAsFixed(2)} kWh';
  }

  // =====================================================
  // Saved System Capacity
  // =====================================================

  double get systemCapacityKw {
    final value = solarSystem?['capacity_kw'];

    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  // =====================================================
  // System Name
  // =====================================================

  String get systemName {
    return solarSystem?['system_name']?.toString() ?? 'Solar System';
  }

  // =====================================================
  // System Location
  // =====================================================

  String get systemLocation {
    return solarSystem?['location']?.toString() ?? 'Unknown location';
  }

  // =====================================================
  // Build
  // =====================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Row(
          children: [
            Icon(
              Icons.auto_graph,
              color: Colors.orange,
            ),
            SizedBox(width: 10),
            Text(
              'Solar Forecast',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: loadForecast,
            icon: const Icon(
              Icons.refresh,
              color: Colors.orange,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: loadForecast,
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: Colors.orange,
                ),
              )
            : errorMessage != null
                ? ListView(
                    children: [
                      const SizedBox(height: 180),
                      Center(
                        child: Column(
                          children: [
                            const Icon(
                              Icons.cloud_off,
                              size: 50,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 15),
                            Text(
                              errorMessage!,
                              style: const TextStyle(
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 15),
                            ElevatedButton(
                              onPressed: loadForecast,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : forecastData == null
                    ? ListView(
                        children: const [
                          SizedBox(height: 180),
                          Center(
                            child: Text(
                              'No forecast data available.',
                              style: TextStyle(
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      )
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          // =====================================================
                          // Title
                          // =====================================================

                          const Text(
                            'AI Solar Forecast',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 6),

                          Text(
                            'XGBoost-based solar generation prediction',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 15,
                            ),
                          ),

                          const SizedBox(height: 20),

                          // =====================================================
                          // Main Forecast
                          // =====================================================

                          _buildMainForecastCard(),

                          const SizedBox(height: 22),

                          const Text(
                            'Generation Forecast',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 12),

                          _buildForecastCard(
                            icon: Icons.access_time,
                            title: 'Next 1 Hour',
                            value: _formatKwh(
                              _getGeneration('next_1_hour'),
                            ),
                          ),

                          _buildForecastCard(
                            icon: Icons.schedule,
                            title: 'Next 5 Hours',
                            value: _formatKwh(
                              _getGeneration('next_5_hours'),
                            ),
                          ),

                          _buildForecastCard(
                            icon: Icons.timelapse,
                            title: 'Next 12 Hours',
                            value: _formatKwh(
                              _getGeneration('next_12_hours'),
                            ),
                          ),

                          _buildForecastCard(
                            icon: Icons.today,
                            title: 'Tomorrow',
                            value: _formatKwh(
                              _getGeneration('tomorrow'),
                            ),
                            subtitle: forecastData?['tomorrow']?['date']
                                ?.toString(),
                          ),

                          _buildForecastCard(
                            icon: Icons.calendar_month,
                            title: 'Day After Tomorrow',
                            value: _formatKwh(
                              _getGeneration('day_after_tomorrow'),
                            ),
                            subtitle: forecastData?['day_after_tomorrow']?['date']
                                ?.toString(),
                          ),

                          const SizedBox(height: 22),

                          // =====================================================
                          // Generation Chart
                          // =====================================================

                          _buildGenerationChart(),

                          const SizedBox(height: 22),

                          // =====================================================
                          // Model Information
                          // =====================================================

                          _buildModelInformation(),

                          const SizedBox(height: 22),

                          // =====================================================
                          // Hourly Forecast
                          // =====================================================

                          _buildHourlyForecast(),

                          const SizedBox(height: 20),
                        ],
                      ),
      ),
    );
  }

  // =====================================================
  // Main Forecast Card
  // =====================================================

  Widget _buildMainForecastCard() {
    final tomorrow = _getGeneration('tomorrow');

    final model = forecastData?['model'] ?? 'XGBoost';

    final capacity =
        forecastData?['system_capacity_kw'] ?? systemCapacityKw;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFB300),
            Color(0xFFFF8F00),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.auto_graph,
                color: Colors.white,
                size: 30,
              ),
              SizedBox(width: 10),
              Text(
                'Tomorrow Prediction',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          Text(
            _formatKwh(tomorrow),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 40,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'Expected solar generation',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 15,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            'Model: $model',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            'System capacity: $capacity kW',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            'System: $systemName',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            'Location: $systemLocation',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // Forecast Card
  // =====================================================

  Widget _buildForecastCard({
    required IconData icon,
    required String title,
    required String value,
    String? subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.orange,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),

                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),

          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 17,
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // Generation Chart
  // =====================================================

  Widget _buildGenerationChart() {
    final predictions = forecastData?['predictions'];

    if (predictions == null ||
        predictions is! List ||
        predictions.isEmpty) {
      return const SizedBox.shrink();
    }

    final visiblePredictions = predictions.take(24).toList();

    final spots = <FlSpot>[];

    double maxGeneration = 0.0;

    for (int i = 0; i < visiblePredictions.length; i++) {
      final item = visiblePredictions[i];

      final generation = double.tryParse(
            item['predicted_generation_kwh']?.toString() ?? '0',
          ) ??
          0.0;

      if (generation > maxGeneration) {
        maxGeneration = generation;
      }

      spots.add(
        FlSpot(
          i.toDouble(),
          generation,
        ),
      );
    }

    final chartMaxY =
        maxGeneration <= 0 ? 1.0 : maxGeneration * 1.2;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.show_chart,
                color: Colors.orange,
              ),
              SizedBox(width: 10),
              Text(
                'Generation Trend',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          Text(
            'Predicted solar generation for the next 24 hours',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 13,
            ),
          ),

          const SizedBox(height: 20),

          SizedBox(
            height: 260,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: chartMaxY,

                gridData: const FlGridData(
                  show: true,
                  drawVerticalLine: false,
                ),

                borderData: FlBorderData(
                  show: false,
                ),

                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: false,
                    ),
                  ),

                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: false,
                    ),
                  ),

                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 42,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 10,
                          ),
                        );
                      },
                    ),
                  ),

                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval:
                          visiblePredictions.length > 8 ? 3 : 1,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();

                        if (index < 0 ||
                            index >= visiblePredictions.length) {
                          return const SizedBox.shrink();
                        }

                        final time =
                            visiblePredictions[index]['time']
                                    ?.toString() ??
                                '';

                        String label = '--';

                        if (time.length >= 16) {
                          label = time.substring(11, 16);
                        }

                        return Padding(
                          padding: const EdgeInsets.only(
                            top: 8,
                          ),
                          child: Text(
                            label,
                            style: const TextStyle(
                              fontSize: 9,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map(
                        (spot) {
                          return LineTooltipItem(
                            '${spot.y.toStringAsFixed(2)} kWh',
                            const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      ).toList();
                    },
                  ),
                ),

                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    barWidth: 3,
                    dotData: const FlDotData(
                      show: false,
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // Model Information
  // =====================================================

  Widget _buildModelInformation() {
    final model = forecastData?['model'] ?? 'XGBoost';

    final hours = forecastData?['forecast_hours'] ?? 0;

    // Get coordinates from the API response first.
    // If unavailable, use the saved SolarSystem values.
    final responseLatitude =
        forecastData?['latitude'] ??
            solarSystem?['latitude'] ??
            'N/A';

    final responseLongitude =
        forecastData?['longitude'] ??
            solarSystem?['longitude'] ??
            'N/A';

    final responseCapacity =
        forecastData?['system_capacity_kw'] ??
            systemCapacityKw;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.psychology,
                color: Colors.orange,
              ),
              SizedBox(width: 10),
              Text(
                'AI Model Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          _buildInfoRow(
            'Machine Learning Model',
            model.toString(),
          ),

          _buildInfoRow(
            'Forecast Horizon',
            '$hours hours',
          ),

          _buildInfoRow(
            'Latitude',
            responseLatitude.toString(),
          ),

          _buildInfoRow(
            'Longitude',
            responseLongitude.toString(),
          ),

          _buildInfoRow(
            'System Capacity',
            '${_formatCapacity(responseCapacity)} kW',
          ),

          _buildInfoRow(
            'System Location',
            systemLocation,
          ),
        ],
      ),
    );
  }

  // =====================================================
  // Format Capacity
  // =====================================================

  String _formatCapacity(dynamic value) {
    final number = double.tryParse(
          value.toString(),
        ) ??
        0.0;

    return number.toStringAsFixed(1);
  }

  // =====================================================
  // Information Row
  // =====================================================

  Widget _buildInfoRow(
    String title,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 8,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
          ),

          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // Hourly Forecast
  // =====================================================

  Widget _buildHourlyForecast() {
    final predictions = forecastData?['predictions'];

    if (predictions == null ||
        predictions is! List ||
        predictions.isEmpty) {
      return const SizedBox.shrink();
    }

    final visiblePredictions = predictions.take(24).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Hourly Forecast',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 12),

        ...visiblePredictions.map(
          (item) {
            final time =
                item['time']?.toString() ?? '--';

            final prediction = double.tryParse(
                  item['predicted_generation_kwh']
                          ?.toString() ??
                      '0',
                ) ??
                0.0;

            final temperature =
                item['temperature']?.toString() ?? '--';

            final radiation =
                item['solar_radiation']?.toString() ?? '--';

            return Container(
              margin: const EdgeInsets.only(
                bottom: 8,
              ),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.schedule,
                    color: Colors.orange,
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          time,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 3),

                        Text(
                          '$temperature°C • '
                          'Radiation $radiation W/m²',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Text(
                    '${prediction.toStringAsFixed(2)} kWh',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}