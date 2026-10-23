import 'package:flutter/material.dart';
import 'api_service.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  // Website-matching colors
  static const Color pageColor = Color(0xFFF5F6F8);
  static const Color cardColor = Colors.white;
  static const Color navy = Color(0xFF111827);
  static const Color textColor = Color(0xFF334155);
  static const Color muted = Color(0xFF94A3B8);
  static const Color gold = Color(0xFFF5B800);
  static const Color border = Color(0xFFE5E7EB);
  static const Color softBackground = Color(0xFFF8FAFC);

  bool loading = true;
  String? errorMessage;

  List<dynamic> systems = [];
  List<dynamic> generationRecords = [];
  List<dynamic> forecasts = [];
  List<dynamic> performanceRecords = [];
  List<dynamic> alerts = [];

  @override
  void initState() {
    super.initState();
    loadReport();
  }

  // ----------------------------------------------------------
  // LOAD DATA FROM EXISTING API SERVICE
  // ----------------------------------------------------------

  Future<void> loadReport() async {
    if (mounted) {
      setState(() {
        loading = true;
        errorMessage = null;
      });
    }

    try {
      final results = await Future.wait<dynamic>([
        ApiService.getSolarSystems(),
        ApiService.getGenerationRecords(),
        ApiService.getForecasts(),
        ApiService.getPerformance(),
        ApiService.getAlerts(),
      ]);

      if (!mounted) return;

      setState(() {
        systems = _asList(results[0]);
        generationRecords = _asList(results[1]);
        forecasts = _asList(results[2]);
        performanceRecords = _asList(results[3]);
        alerts = _asList(results[4]);
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
        errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  List<dynamic> _asList(dynamic value) {
    if (value is List) return value;

    // Some APIs return {"results": [...]}
    if (value is Map && value['results'] is List) {
      return value['results'] as List;
    }

    return [];
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  double _number(dynamic value) {
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  String _text(dynamic value, [String fallback = '—']) {
    if (value == null || value.toString().trim().isEmpty) {
      return fallback;
    }
    return value.toString();
  }

  String _money(double value) => '₹${value.toStringAsFixed(2)}';

  String _date(dynamic value) {
    if (value == null || value.toString().isEmpty) return '—';

    final date = DateTime.tryParse(value.toString());

    if (date == null) return value.toString();

    return '${date.day.toString().padLeft(2, '0')} '
        '${_month(date.month)} ${date.year}';
  }

  String _dateTime(dynamic value) {
    if (value == null || value.toString().isEmpty) return '—';

    final date = DateTime.tryParse(value.toString());

    if (date == null) return value.toString();

    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'pm' : 'am';

    return '${_date(date.toIso8601String())}, '
        '$hour:$minute $period';
  }

  String _month(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];

    return months[month - 1];
  }

  String _todayString() {
    final now = DateTime.now();

    return '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  // ----------------------------------------------------------
  // SOLAR SYSTEM
  // ----------------------------------------------------------

  Map<String, dynamic>? get currentSystem {
    if (systems.isEmpty) return null;
    return _asMap(systems.first);
  }

  // ----------------------------------------------------------
  // GENERATION METRICS
  // ----------------------------------------------------------

  double get totalGeneration {
    return generationRecords.fold<double>(
      0,
      (total, item) {
        final row = _asMap(item);
        return total + _number(row?['energy_generated_kwh']);
      },
    );
  }

  double get electricityRate {
    final system = currentSystem;

    // Support the rate field names used by different API serializers.
    return _number(
      system?['electricity_rate'] ??
      system?['electricity_tariff'] ??
      system?['tariff_rate'],
    );
  }

  double get estimatedSavings {
    return totalGeneration * electricityRate;
  }

  // ----------------------------------------------------------
  // FORECASTS
  // ----------------------------------------------------------

  List<Map<String, dynamic>> get sortedForecasts {
    final rows = forecasts
        .map(_asMap)
        .whereType<Map<String, dynamic>>()
        .toList();

    rows.sort((a, b) {
      final dateA =
          DateTime.tryParse('${a['forecast_date'] ?? ''}') ??
          DateTime(1900);

      final dateB =
          DateTime.tryParse('${b['forecast_date'] ?? ''}') ??
          DateTime(1900);

      return dateA.compareTo(dateB);
    });

    return rows;
  }

  Map<String, dynamic>? get todayForecast {
    final today = _todayString();

    for (final forecast in sortedForecasts) {
      final date = _text(forecast['forecast_date'], '');

      if (date.startsWith(today)) {
        return forecast;
      }
    }

    return null;
  }

  double get todayForecastValue {
    return _number(
      todayForecast?['predicted_generation_kwh'],
    );
  }

  String get forecastModel {
    final forecast = todayForecast ??
        (sortedForecasts.isNotEmpty ? sortedForecasts.last : null);

    return _text(forecast?['model_name'], 'XGBoost');
  }

  // ----------------------------------------------------------
  // PERFORMANCE
  // ----------------------------------------------------------

  List<Map<String, dynamic>> get sortedPerformance {
    final rows = performanceRecords
        .map(_asMap)
        .whereType<Map<String, dynamic>>()
        .toList();

    rows.sort((a, b) {
      final dateA = DateTime.tryParse(
            '${a['evaluation_date'] ?? a['created_at'] ?? ''}',
          ) ??
          DateTime(1900);

      final dateB = DateTime.tryParse(
            '${b['evaluation_date'] ?? b['created_at'] ?? ''}',
          ) ??
          DateTime(1900);

      return dateB.compareTo(dateA);
    });

    return rows;
  }

  Map<String, dynamic>? get latestPerformance {
    if (sortedPerformance.isEmpty) return null;
    return sortedPerformance.first;
  }

  double get performancePercentage {
    final row = latestPerformance;

    return _number(
      row?['forecast_achievement_percentage'] ??
      row?['performance_percentage'],
    );
  }

  double get recordedPerformanceGeneration {
    return _number(
      latestPerformance?['actual_generation_kwh'] ??
      latestPerformance?['recorded_generation_kwh'],
    );
  }

  double get predictedPerformanceGeneration {
    return _number(
      latestPerformance?['predicted_generation_kwh'],
    );
  }

  double get performanceDeviation {
    final row = latestPerformance;

    if (row == null) {
      return recordedPerformanceGeneration -
          predictedPerformanceGeneration;
    }

    return _number(
      row['deviation_kwh'] ??
      row['deviation'],
    );
  }

  List<Map<String, dynamic>> get sortedGenerationRecords {
    final rows = generationRecords
        .map(_asMap)
        .whereType<Map<String, dynamic>>()
        .toList();
    rows.sort((a, b) {
      final da = DateTime.tryParse('${a['recorded_at'] ?? ''}') ?? DateTime(1900);
      final db = DateTime.tryParse('${b['recorded_at'] ?? ''}') ?? DateTime(1900);
      return db.compareTo(da);
    });
    return rows;
  }
  double get _reportActualGeneration {
    if (latestPerformance != null &&
        _number(latestPerformance!['actual_generation_kwh'] ??
                latestPerformance!['recorded_generation_kwh']) > 0) {
      return recordedPerformanceGeneration;
    }
    if (sortedGenerationRecords.isNotEmpty) {
      final row = sortedGenerationRecords.first;
      return _number(row['energy_generated_kwh'] ??
          row['energy_generated'] ?? row['generation_kwh'] ??
          row['energy_generated_kwh']);
    }
    return 0;
  }

  double get _reportPredictedGeneration {
    if (predictedPerformanceGeneration > 0) {
      return predictedPerformanceGeneration;
    }
    if (sortedForecasts.isNotEmpty) {
      final row = sortedForecasts.first;
      return _number(row['predicted_generation_kwh'] ??
          row['predicted_generation'] ?? row['predicted_generation_kwh'] ??
          row['predicted_generation_kwh']);
    }
    return 0;
  }

  bool get hasPerformanceData {
    final row = latestPerformance;
    if (row != null) {
      final actual = row['actual_generation_kwh'] ??
          row['recorded_generation_kwh'];
      final predicted = row['predicted_generation_kwh'];
      if (actual != null && predicted != null && _number(predicted) > 0) {
        return true;
      }
    }
    return _reportActualGeneration > 0 &&
        _reportPredictedGeneration > 0;
  }

  // ----------------------------------------------------------
  // ALERTS
  // ----------------------------------------------------------

  bool _isResolved(dynamic item) {
    final row = _asMap(item);
    final value = row?['is_resolved'];

    return value == true ||
        value == 1 ||
        value?.toString().toLowerCase() == 'true';
  }

  int get activeAlertCount {
    return alerts.where((item) => !_isResolved(item)).length;
  }

  int get resolvedAlertCount {
    return alerts.where(_isResolved).length;
  }

  // ----------------------------------------------------------
  // MAIN SCREEN
  // ----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageColor,

      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: navy,
        elevation: 0,
        surfaceTintColor: Colors.white,

        title: const Row(
          children: [
            Icon(
              Icons.description_outlined,
              color: gold,
              size: 25,
            ),
            SizedBox(width: 10),
            Text(
              'Reports',
              style: TextStyle(
                color: navy,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),

        actions: [
          IconButton(
            tooltip: 'Refresh report',
            onPressed: loading ? null : loadReport,
            icon: const Icon(Icons.refresh),
          ),

          const SizedBox(width: 8),
        ],

        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(
            height: 1,
            color: border,
          ),
        ),
      ),

      body: loading
          ? const Center(
              child: CircularProgressIndicator(
                color: gold,
              ),
            )
          : RefreshIndicator(
              color: gold,
              onRefresh: loadReport,

              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),

                children: [
                  _buildPageHeader(),

                  const SizedBox(height: 18),

                  _buildMetadata(),

                  const SizedBox(height: 22),

                  if (errorMessage != null)
                    _buildError(),

                  _buildSystemOverview(),

                  const SizedBox(height: 18),

                  _buildKeyMetrics(),

                  const SizedBox(height: 18),

                  _buildForecastSummary(),

                  const SizedBox(height: 18),

                  _buildPerformanceAndAlerts(),

                  const SizedBox(height: 18),

                  _buildGenerationRecords(),

                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  // ----------------------------------------------------------
  // PAGE HEADER
  // ----------------------------------------------------------

  Widget _buildPageHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Reports',
          style: TextStyle(
            color: navy,
            fontSize: 29,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
          ),
        ),

        const SizedBox(height: 7),

        Text(
          'Consolidated overview of your solar system, '
          'AI forecasts, performance and alerts.',
          style: TextStyle(
            color: Colors.blueGrey.shade600,
            fontSize: 13,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  // ----------------------------------------------------------
  // METADATA CHIPS
  // ----------------------------------------------------------

  Widget _buildMetadata() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _metadataChip(
          Icons.bolt,
          'System',
          _text(currentSystem?['system_name'], 'No system'),
        ),

        _metadataChip(
          Icons.auto_awesome,
          'Model',
          forecastModel,
        ),

        _metadataChip(
          Icons.schedule,
          'Generated',
          _dateTime(DateTime.now().toIso8601String()),
        ),
      ],
    );
  }

  Widget _metadataChip(
    IconData icon,
    String label,
    String value,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 9,
      ),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: border),
      ),

      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: gold,
          ),

          const SizedBox(width: 6),

          Text(
            '$label: ',
            style: const TextStyle(
              color: muted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),

          Text(
            value,
            style: const TextStyle(
              color: navy,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // ERROR CARD
  // ----------------------------------------------------------

  Widget _buildError() {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(15),

      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: const Color(0xFFFECDD3),
        ),
      ),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline,
            color: Color(0xFFBE123C),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Unable to load all report data',
                  style: TextStyle(
                    color: Color(0xFF9F1239),
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  errorMessage!,
                  style: const TextStyle(
                    color: Color(0xFF9F1239),
                    fontSize: 12,
                  ),
                ),

                const SizedBox(height: 8),

                TextButton(
                  onPressed: loadReport,
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // GENERIC REPORT CARD
  // ----------------------------------------------------------

  Widget _reportCard({
    required String title,
    required String subtitle,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: border),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(19, 18, 19, 15),

            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: navy,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                      const SizedBox(height: 5),

                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: muted,
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),

                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  trailing,
                ],
              ],
            ),
          ),

          const Divider(
            height: 1,
            color: Color(0xFFEEF1F4),
          ),

          Padding(
            padding: const EdgeInsets.all(18),
            child: child,
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // SYSTEM OVERVIEW
  // ----------------------------------------------------------

  Widget _buildSystemOverview() {
    final system = currentSystem;

    final items = <MapEntry<String, String>>[
      MapEntry(
        'System Name',
        _text(system?['system_name']),
      ),

      MapEntry(
        'Location',
        _text(system?['location']),
      ),

      MapEntry(
        'Capacity',
        '${_number(system?['capacity_kw']).toStringAsFixed(2)} kW',
      ),

      MapEntry(
        'Panel Count',
        _text(system?['panel_count']),
      ),

      MapEntry(
        'Panel Type',
        _text(system?['panel_type']),
      ),

      MapEntry(
        'Installation Date',
        _date(system?['installation_date']),
      ),

      MapEntry(
        'Electricity Rate',
        '${_money(electricityRate)} / kWh',
      ),

      MapEntry(
        'Coordinates',
        '${_text(system?['latitude'], '—')}, '
        '${_text(system?['longitude'], '—')}',
      ),
    ];

    return _reportCard(
      title: 'Solar System Overview',
      subtitle: 'Configuration and installation details',

      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 650 ? 4 :
              constraints.maxWidth >= 380 ? 2 : 1;

          final spacing = 10.0;

          final width =
              (constraints.maxWidth - (columns - 1) * spacing) /
                  columns;

          return Wrap(
            spacing: spacing,
            runSpacing: spacing,

            children: items.map((item) {
              return SizedBox(
                width: width,

                child: Container(
                  constraints: const BoxConstraints(
                    minHeight: 80,
                  ),

                  padding: const EdgeInsets.all(13),

                  decoration: BoxDecoration(
                    color: softBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFEEF2F6),
                    ),
                  ),

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.key,
                        style: const TextStyle(
                          color: muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 7),

                      Text(
                        item.value,
                        style: const TextStyle(
                          color: navy,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  // ----------------------------------------------------------
  // KEY METRICS
  // ----------------------------------------------------------

  Widget _buildKeyMetrics() {
    final metrics = [
      _Metric(
        title: 'Total Recorded Generation',
        value: totalGeneration.toStringAsFixed(2),
        unit: 'kWh',
        note: '${generationRecords.length} generation records',
        icon: Icons.bolt,
        iconColor: const Color(0xFFB45309),
        iconBackground: const Color(0xFFFFF5E5),
      ),

      _Metric(
        title: "Today's AI Forecast",
        value: todayForecast == null
            ? '—'
            : todayForecastValue.toStringAsFixed(2),
        unit: 'kWh',
        note: forecastModel,
        icon: Icons.auto_graph,
        iconColor: const Color(0xFF2563EB),
        iconBackground: const Color(0xFFEFF6FF),
      ),

      _Metric(
        title: 'Forecast Achievement',
        value: hasPerformanceData
            ? performancePercentage.toStringAsFixed(2)
            : '—',
        unit: '%',
        note: hasPerformanceData
            ? 'Generation compared with forecast'
            : 'No completed performance data',
        icon: Icons.analytics_outlined,
        iconColor: const Color(0xFF15803D),
        iconBackground: const Color(0xFFECFDF5),
      ),

      _Metric(
        title: 'Active Alerts',
        value: activeAlertCount.toString(),
        unit: 'alerts',
        note: 'Requiring attention',
        icon: Icons.notifications_active_outlined,
        iconColor: const Color(0xFFB45309),
        iconBackground: const Color(0xFFFFF7E6),
      ),
    ];

    return _reportCard(
      title: 'Key Metrics',
      subtitle: 'Current summary from RaySense',

      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 650 ? 4 :
              constraints.maxWidth >= 380 ? 2 : 1;

          const spacing = 10.0;

          final width =
              (constraints.maxWidth - (columns - 1) * spacing) /
                  columns;

          return Wrap(
            spacing: spacing,
            runSpacing: spacing,

            children: metrics.map((metric) {
              return SizedBox(
                width: width,
                child: _buildMetricCard(metric),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildMetricCard(_Metric metric) {
    return Container(
      constraints: const BoxConstraints(
        minHeight: 145,
      ),

      padding: const EdgeInsets.all(14),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            metric.title,
            style: const TextStyle(
              color: muted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: FittedBox(
                  alignment: Alignment.centerLeft,
                  fit: BoxFit.scaleDown,

                  child: Text(
                    metric.value,
                    style: const TextStyle(
                      color: navy,
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 6),

              Container(
                width: 34,
                height: 34,

                decoration: BoxDecoration(
                  color: metric.iconBackground,
                  borderRadius: BorderRadius.circular(10),
                ),

                child: Icon(
                  metric.icon,
                  color: metric.iconColor,
                  size: 19,
                ),
              ),
            ],
          ),

          const SizedBox(height: 3),

          Text(
            metric.unit,
            style: const TextStyle(
              color: muted,
              fontSize: 10,
            ),
          ),

          const SizedBox(height: 7),

          Text(
            metric.note,
            style: const TextStyle(
              color: muted,
              fontSize: 9,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // AI FORECAST SUMMARY
  // ----------------------------------------------------------

  Widget _buildForecastSummary() {
    final rows = sortedForecasts.reversed.toList();

    return _reportCard(
      title: 'AI Forecast Summary',
      subtitle: 'Solar generation predictions from the RaySense model',

      trailing: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 9,
          vertical: 6,
        ),

        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(20),
        ),

        child: Text(
          forecastModel,
          style: const TextStyle(
            color: Color(0xFF2563EB),
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      child: rows.isEmpty
          ? _emptyState(
              Icons.auto_graph,
              'No forecast records available.',
            )
          : Column(
              children: [
                for (final row in rows.take(10))
                  _forecastRow(row),
              ],
            ),
    );
  }

  Widget _forecastRow(Map<String, dynamic> row) {
    final model = _text(row['model_name'], 'XGBoost');

    final confidence = row['confidence_score'];

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(12),

      decoration: BoxDecoration(
        color: softBackground,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: const Color(0xFFF0F2F5),
        ),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 14,
                color: muted,
              ),

              const SizedBox(width: 7),

              Expanded(
                child: Text(
                  _date(row['forecast_date']),
                  style: const TextStyle(
                    color: navy,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 5,
                ),

                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(20),
                ),

                child: Text(
                  model,
                  style: const TextStyle(
                    color: Color(0xFF2563EB),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _smallData(
                  'Predicted Generation',
                  '${_number(row['predicted_generation_kwh']).toStringAsFixed(2)} kWh',
                ),
              ),

              Expanded(
                child: _smallData(
                  'Confidence',
                  confidence == null
                      ? 'Not available'
                      : '${_number(confidence).toStringAsFixed(2)}%',
                ),
              ),
            ],
          ),

          const SizedBox(height: 9),

          Text(
            'Created: ${_dateTime(row['created_at'])}',
            style: const TextStyle(
              color: muted,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallData(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: muted,
            fontSize: 10,
          ),
        ),

        const SizedBox(height: 5),

        Text(
          value,
          style: const TextStyle(
            color: navy,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  // ----------------------------------------------------------
  // PERFORMANCE ANALYSIS AND ALERT SUMMARY
  // ----------------------------------------------------------

  Widget _buildPerformanceAndAlerts() {
    return Column(
      children: [
        _buildPerformance(),

        const SizedBox(height: 18),

        _buildAlertSummary(),
      ],
    );
  }

  Widget _buildPerformance() {
    final performance = latestPerformance;

    final status = _text(
      performance?['status'],
      'Pending',
    );

    final source = _text(
      performance?['data_source'],
      'Source not confirmed',
    );

    return _reportCard(
      title: 'Performance Analysis',
      subtitle: 'Latest solar performance evaluation',

      child: performance == null
          ? _emptyState(
              Icons.analytics_outlined,
              'No performance analysis is available.',
            )
          : Column(
              children: [
                Center(
                  child: Container(
                    width: 145,
                    height: 145,

                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: softBackground,
                      border: Border.all(
                        color: gold,
                        width: 9,
                      ),
                    ),

                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          hasPerformanceData
                              ? '${performancePercentage.toStringAsFixed(2)}%'
                              : '—',

                          style: const TextStyle(
                            color: navy,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),

                        const SizedBox(height: 4),

                        const Text(
                          'Forecast Achievement',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: muted,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                Wrap(
                  spacing: 7,
                  runSpacing: 7,

                  children: [
                    _statusBadge(
                      status.toUpperCase(),
                      _statusColor(status),
                    ),

                    _statusBadge(
                      source.toUpperCase(),
                      source.toUpperCase() == 'ACTUAL'
                          ? const Color(0xFF15803D)
                          : const Color(0xFFB45309),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                LayoutBuilder(
                  builder: (context, constraints) {
                    const spacing = 9.0;

                    final columns =
                        constraints.maxWidth >= 450 ? 2 : 1;

                    final width =
                        (constraints.maxWidth -
                            (columns - 1) * spacing) /
                            columns;

                    final values = [
                      MapEntry(
                        'Recorded Generation',
                        hasPerformanceData
                            ? '${recordedPerformanceGeneration.toStringAsFixed(2)} kWh'
                            : 'Not available',
                      ),

                      MapEntry(
                        'Predicted Generation',
                        predictedPerformanceGeneration > 0
                            ? '${predictedPerformanceGeneration.toStringAsFixed(2)} kWh'
                            : 'Not available',
                      ),

                      MapEntry(
                        'Deviation',
                        hasPerformanceData
                            ? '${performanceDeviation > 0 ? '+' : ''}${performanceDeviation.toStringAsFixed(2)} kWh'
                            : 'Not available',
                      ),

                      MapEntry(
                        'Evaluation Date',
                        _date(
                          performance['evaluation_date'] ??
                              performance['date'],
                        ),
                      ),
                    ];

                    return Wrap(
                      spacing: spacing,
                      runSpacing: spacing,

                      children: values.map((item) {
                        return SizedBox(
                          width: width,

                          child: Container(
                            padding: const EdgeInsets.all(12),

                            decoration: BoxDecoration(
                              color: softBackground,
                              borderRadius: BorderRadius.circular(11),
                            ),

                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.key,
                                  style: const TextStyle(
                                    color: muted,
                                    fontSize: 10,
                                  ),
                                ),

                                const SizedBox(height: 6),

                                Text(
                                  item.value,
                                  style: const TextStyle(
                                    color: navy,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),

                const SizedBox(height: 14),

                const Text(
                  'Performance results depend on the available generation '
                  'and forecast records. Demonstration data should not be '
                  'treated as verified real-world production.',
                  style: TextStyle(
                    color: muted,
                    fontSize: 10,
                    height: 1.6,
                  ),
                ),
              ],
            ),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'excellent':
      case 'good':
      case 'completed':
        return const Color(0xFF15803D);

      case 'warning':
        return const Color(0xFFB45309);

      case 'poor':
      case 'critical':
      case 'failed':
        return const Color(0xFFDC2626);

      default:
        return const Color(0xFF64748B);
    }
  }

  Widget _statusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),

      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(20),
      ),

      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  // ----------------------------------------------------------
  // ALERT SUMMARY
  // ----------------------------------------------------------

  Widget _buildAlertSummary() {
    final recentAlerts = alerts.take(5).toList();

    return _reportCard(
      title: 'Alert Summary',
      subtitle: 'System events requiring attention',

      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _alertStat(
                  'Total',
                  alerts.length,
                ),
              ),

              const SizedBox(width: 9),

              Expanded(
                child: _alertStat(
                  'Active',
                  activeAlertCount,
                ),
              ),

              const SizedBox(width: 9),

              Expanded(
                child: _alertStat(
                  'Resolved',
                  resolvedAlertCount,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          if (recentAlerts.isEmpty)
            _emptyState(
              Icons.notifications_none,
              'No alerts available.',
            )
          else
            ...recentAlerts.map((item) {
              final alert = _asMap(item);

              if (alert == null) {
                return const SizedBox.shrink();
              }

              final severity = _text(
                alert['severity'],
                'Info',
              );

              final resolved = _isResolved(alert);

              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 13),

                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Color(0xFFEEF1F4),
                    ),
                  ),
                ),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            _text(alert['title'], 'System Alert'),
                            style: const TextStyle(
                              color: navy,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),

                        const SizedBox(width: 7),

                        _statusBadge(
                          severity,
                          severity.toLowerCase() == 'critical'
                              ? const Color(0xFFDC2626)
                              : severity.toLowerCase() == 'warning'
                                  ? const Color(0xFFB45309)
                                  : const Color(0xFF2563EB),
                        ),
                      ],
                    ),

                    const SizedBox(height: 7),

                    Text(
                      _text(alert['message'], 'No additional details.'),
                      style: const TextStyle(
                        color: textColor,
                        fontSize: 11,
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(height: 7),

                    _statusBadge(
                      resolved ? 'Resolved' : 'Active',
                      resolved
                          ? const Color(0xFF15803D)
                          : const Color(0xFFC2410C),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _alertStat(String label, int value) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 13,
      ),

      decoration: BoxDecoration(
        color: softBackground,
        borderRadius: BorderRadius.circular(11),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: muted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            '$value',
            style: const TextStyle(
              color: navy,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------
  // GENERATION RECORDS
  // ----------------------------------------------------------

  Widget _buildGenerationRecords() {
    final rows = generationRecords.map(_asMap)
        .whereType<Map<String, dynamic>>()
        .toList();

    rows.sort((a, b) {
      final dateA =
          DateTime.tryParse('${a['recorded_at'] ?? ''}') ??
          DateTime(1900);

      final dateB =
          DateTime.tryParse('${b['recorded_at'] ?? ''}') ??
          DateTime(1900);

      return dateB.compareTo(dateA);
    });

    return _reportCard(
      title: 'Generation Records',
      subtitle: 'Recorded solar energy production',

      child: rows.isEmpty
          ? _emptyState(
              Icons.bolt_outlined,
              'No generation records are available.',
            )
          : Column(
              children: rows.take(10).map((row) {
                final source = _text(
                  row['data_source'],
                  'UNKNOWN',
                ).toUpperCase();

                final sourceColor =
                    source == 'ACTUAL'
                        ? const Color(0xFF15803D)
                        : source == 'SIMULATED'
                            ? const Color(0xFFB45309)
                            : const Color(0xFF2563EB);

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(13),

                  decoration: BoxDecoration(
                    color: softBackground,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: const Color(0xFFF0F2F5),
                    ),
                  ),

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.schedule,
                            size: 14,
                            color: muted,
                          ),

                          const SizedBox(width: 7),

                          Expanded(
                            child: Text(
                              _dateTime(row['recorded_at']),
                              style: const TextStyle(
                                color: navy,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: _smallData(
                              'Energy Generated',
                              '${_number(row['energy_generated_kwh']).toStringAsFixed(2)} kWh',
                            ),
                          ),

                          Expanded(
                            child: _smallData(
                              'Power Output',
                              '${_number(row['power_output_kw']).toStringAsFixed(2)} kW',
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      _statusBadge(
                        source,
                        sourceColor,
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  // ----------------------------------------------------------
  // EMPTY STATE
  // ----------------------------------------------------------

  Widget _emptyState(
    IconData icon,
    String message,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 15,
        vertical: 28,
      ),

      child: Column(
        children: [
          Icon(
            icon,
            color: muted,
            size: 30,
          ),

          const SizedBox(height: 10),

          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: muted,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// METRIC MODEL
// ============================================================

class _Metric {
  final String title;
  final String value;
  final String unit;
  final String note;
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;

  const _Metric({
    required this.title,
    required this.value,
    required this.unit,
    required this.note,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
  });
}




