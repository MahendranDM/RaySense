import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import 'api_service.dart';

class PerformanceScreen extends StatefulWidget {
  const PerformanceScreen({super.key});

  @override
  State<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends State<PerformanceScreen> {
  bool isLoading = true;
  String? errorMessage;

  Map<String, dynamic> todayData = {};
  List<Map<String, dynamic>> history = [];

  static const Color bg = Color(0xFFF5F5F4);
  static const Color navy = Color(0xFF111827);
  static const Color navyLight = Color(0xFF172033);
  static const Color gold = Color(0xFFFACC15);
  static const Color muted = Color(0xFF94A3B8);
  static const Color border = Color(0xFF1F2937);
  static const Color blue = Color(0xFF3B82F6);
  static const Color white = Colors.white;

  @override
  void initState() {
    super.initState();
    loadPerformance();
  }

  Future<void> loadPerformance() async {
    if (mounted) {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });
    }

    try {
      final results = await Future.wait([
        ApiService.getTodayPerformance(),
        ApiService.getPerformance(),
        ApiService.getGenerationRecords(),
        ApiService.getForecasts(),
      ]);

      if (!mounted) return;

      final today = Map<String, dynamic>.from(
        results[0] as Map,
      );

      final records = _toMaps(results[1] as List);
      final generations = _toMaps(results[2] as List);
      final forecasts = _toMaps(results[3] as List);

      final rows = _buildHistory(
        generations: generations,
        forecasts: forecasts,
        records: records,
      );

      setState(() {
        todayData = today;
        history = rows;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  List<Map<String, dynamic>> _toMaps(List<dynamic> data) {
    return data
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  double _num(dynamic value) {
    if (value == null) return 0;
    return double.tryParse(value.toString()) ?? 0;
  }

  double? _nullableNum(dynamic value) {
    if (value == null) return null;
    return double.tryParse(value.toString());
  }

  String _dateKey(dynamic value) {
    if (value == null) return '';
    final text = value.toString();
    if (text.length < 10) return '';
    return text.substring(0, 10);
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  String _formatDate(dynamic value) {
    final date = _parseDate(value);
    if (date == null) return '--';

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];

    return '${date.day.toString().padLeft(2, '0')} '
        '${months[date.month - 1]} ${date.year}';
  }

  String _kwh(dynamic value) {
    final n = _nullableNum(value);
    return n == null ? 'N/A' : '${n.toStringAsFixed(2)} kWh';
  }

  String _percentage(dynamic value) {
    final n = _nullableNum(value);
    return n == null ? 'N/A' : '${n.toStringAsFixed(2)}%';
  }

  String _todayDateKey() {
    final now = DateTime.now();
    return '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  String _previousDateKey(int daysAgo) {
    final date = DateTime.now().subtract(Duration(days: daysAgo));

    return '${date.year}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  List<Map<String, dynamic>> _buildHistory({
    required List<Map<String, dynamic>> generations,
    required List<Map<String, dynamic>> forecasts,
    required List<Map<String, dynamic>> records,
  }) {
    final generationByDate = <String, List<Map<String, dynamic>>>{};
    final forecastByDate = <String, Map<String, dynamic>>{};
    final performanceByDate = <String, Map<String, dynamic>>{};

    final today = _todayDateKey();

    // Index saved performance evaluations.
    for (final record in records) {
      final date = _dateKey(
        record['evaluation_date'] ?? record['date'],
      );
if (date.isEmpty || date.compareTo(today) >= 0) continue;
      

      performanceByDate.putIfAbsent(date, () => record);
    }

    // Group generation records by date.
    for (final record in generations) {
      final date = _dateKey(
        record['generation_date'] ??
            record['recorded_at'] ??
            record['created_at'],
      );

    if (date.isEmpty || date.compareTo(today) >= 0) continue;  

      final energy = _num(record['energy_generated_kwh']);
      if (energy < 0) continue;

      generationByDate.putIfAbsent(date, () => []).add(record);
    }

    // Index forecast records by date.
    for (final forecast in forecasts) {
      final date = _dateKey(
        forecast['forecast_date'] ??
            forecast['prediction_date'] ??
            forecast['created_at'],
      );
if (date.isEmpty || date.compareTo(today) >= 0) continue;
      

      forecastByDate.putIfAbsent(date, () => forecast);
    }

    final forecastValues = forecastByDate.values
        .map((item) => _num(item['predicted_generation_kwh']))
        .where((value) => value > 0)
        .toList();

    final baseline = forecastValues.isNotEmpty
        ? forecastValues.first
        : 18.82;

    final rows = <Map<String, dynamic>>[];

    for (int daysAgo = 1; daysAgo <= 20; daysAgo++) {
      final date = _previousDateKey(daysAgo);

      final savedPerformance = performanceByDate[date];
      final savedForecast = forecastByDate[date];
      final generationRecords = generationByDate[date] ?? [];

      final seed = date.codeUnits.fold<int>(
        0,
        (sum, code) => sum + code,
      );

      // Prefer an existing forecast. Missing values below are
      // demonstration values, not trained-model predictions.
      final predicted = savedPerformance != null
          ? _num(savedPerformance['predicted_generation_kwh'])
          : savedForecast != null
              ? _num(savedForecast['predicted_generation_kwh'])
              : baseline * (0.94 + (seed % 13) / 100);

      double actual = 0;
      String source = 'SIMULATED';
      bool hasGeneration = false;

      // Prefer ACTUAL records if any exist for this date.
      final actualRecords = generationRecords.where(
        (r) => (r['data_source'] ?? 'SIMULATED')
            .toString()
            .toUpperCase() == 'ACTUAL',
      ).toList();

      final selectedRecords = actualRecords.isNotEmpty
          ? actualRecords
          : generationRecords;

      if (selectedRecords.isNotEmpty) {
        actual = selectedRecords.fold<double>(
          0,
          (sum, record) =>
              sum + _num(record['energy_generated_kwh']),
        );

        source = actualRecords.isNotEmpty ? 'ACTUAL' : 'SIMULATED';
        hasGeneration = true;
      } else if (savedPerformance != null) {
        actual = _num(savedPerformance['actual_generation_kwh']);
        source = 'SAVED RECORD';
        hasGeneration = true;
      } else {
        actual = predicted * (0.62 + (seed % 19) / 100);
      }

      final deviation = actual - predicted;
      final percentage = predicted > 0
          ? (actual / predicted) * 100
          : 0.0;

      final status = source == 'SIMULATED'
          ? 'SIMULATED'
          : percentage >= 95
              ? 'Excellent'
              : percentage >= 85
                  ? 'Good'
                  : percentage >= 70
                      ? 'Warning'
                      : 'Poor';

      rows.add({
        'date': date,
        'actual': actual,
        'predicted': predicted,
        'deviation': deviation,
        'percentage': percentage,
        'source': source,
        'status': status,
        'has_generation': hasGeneration,
      });
    }

    return rows;
  }

  String get _systemName {
    return (todayData['solar_system'] ?? 'RaySense Web System').toString();
  }

  String get _source {
    if (todayData['is_simulated'] == true) return 'SIMULATED';
    if (todayData['data_source'] != null) {
      return todayData['data_source'].toString().toUpperCase();
    }
    return 'PENDING';
  }

  String get _status {
    return (todayData['status'] ?? 'PENDING').toString().toUpperCase();
  }

  double? get _actual => _nullableNum(
        todayData['actual_generation_kwh'],
      );

  double? get _predicted => _nullableNum(
        todayData['predicted_generation_kwh'],
      );

  double? get _fullForecast => _nullableNum(
        todayData['full_day_forecast_kwh'] ??
            todayData['predicted_generation_kwh'],
      );

  double? get _performance => _nullableNum(
        todayData['performance_percentage'],
      );

  double? get _deviation => _nullableNum(
        todayData['deviation_kwh'],
      );

  String get _modelName {
    return (todayData['model_name'] ?? 'Not available').toString();
  }

  Color _statusColor(String value) {
    final status = value.toLowerCase();

    if (status.contains('simulated')) {
      return const Color(0xFF94A3B8);
    }

    if (status.contains('excellent') || status.contains('good')) {
      return const Color(0xFF4ADE80);
    }

    if (status.contains('warning') || status.contains('pending')) {
      return gold;
    }

    if (status.contains('poor') || status.contains('critical')) {
      return const Color(0xFFF87171);
    }

    return muted;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: navy,
        foregroundColor: white,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.bolt_rounded, color: gold, size: 27),
            SizedBox(width: 10),
            Text(
              'RaySense  •  Performance',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: isLoading ? null : loadPerformance,
            icon: const Icon(Icons.refresh_rounded, color: gold),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: gold),
            )
          : errorMessage != null
              ? _errorView()
              : RefreshIndicator(
                  onRefresh: loadPerformance,
                  color: gold,
                  child: _body(),
                ),
    );
  }

  Widget _body() {
    final width = MediaQuery.sizeOf(context).width;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(width < 600 ? 14 : 24),
      children: [
        const Text(
          'PERFORMANCE ANALYTICS',
          style: TextStyle(
            color: Color(0xFF9A7600),
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Performance',
          style: TextStyle(
            color: navy,
            fontSize: 30,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Monitor how your solar system is performing against its AI forecast.',
          style: TextStyle(
            color: Color(0xFF475569),
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 22),

        _statusBanner(),
        const SizedBox(height: 18),

        _metrics(width),
        const SizedBox(height: 18),

        if (width >= 850)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: _overviewPanel(),
              ),
              const SizedBox(width: 18),
              Expanded(
                flex: 2,
                child: _previousDayPanel(),
              ),
            ],
          )
        else ...[
          _overviewPanel(),
          const SizedBox(height: 18),
          _previousDayPanel(),
        ],

        const SizedBox(height: 18),
        _historyPanel(width),
      ],
    );
  }

  Widget _statusBanner() {
    final simulated = todayData['is_simulated'] == true;

    final scope = todayData['evaluation_scope'] ??
        (simulated
            ? 'Demonstration data; not verified real-world production.'
            : 'Previous completed day performance');

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        border: Border.all(color: const Color(0xFFF0D77A)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFFDE68A).withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.bolt_rounded,
              color: Color(0xFFF59E0B),
              size: 25,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _systemName,
                  style: const TextStyle(
                    color: navy,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  scope.toString(),
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _badge(_status, _statusColor(_status)),
        ],
      ),
    );
  }

  Widget _metrics(double width) {
    final columns = width >= 1050 ? 4 : width >= 600 ? 2 : 1;

    return GridView.count(
      crossAxisCount: columns,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 14,
      mainAxisSpacing: 14,
      childAspectRatio: columns == 4 ? 1.65 : columns == 2 ? 1.8 : 3.0,
      children: [
        _metricCard(
          title: 'Recorded Generation',
          value: _actual == null ? 'N/A' : _actual!.toStringAsFixed(2),
          unit: 'kWh on evaluation date',
          icon: Icons.wb_sunny_rounded,
        ),
        _metricCard(
          title: 'Predicted Generation',
          value: _predicted == null ? 'N/A' : _predicted!.toStringAsFixed(2),
          unit: 'kWh predicted',
          icon: Icons.diamond_outlined,
        ),
        _metricCard(
          title: 'Full-Day Forecast',
          value: _fullForecast == null
              ? 'N/A'
              : _fullForecast!.toStringAsFixed(2),
          unit: 'kWh forecast',
          icon: Icons.radio_button_unchecked_rounded,
        ),
        _metricCard(
          title: 'Performance',
          value: _performance == null
              ? 'N/A'
              : '${_performance!.toStringAsFixed(2)}%',
          unit: 'forecast achievement',
          icon: Icons.trending_up_rounded,
        ),
      ],
    );
  }

  Widget _metricCard({
    required String title,
    required String value,
    required String unit,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: navy,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                height: 34,
                width: 34,
                decoration: BoxDecoration(
                  color: gold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: gold, size: 19),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFF8FAFC),
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            unit,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _overviewPanel() {
    final actual = _actual ?? 0;
    final predicted = _predicted ?? 0;
    final forecast = _fullForecast ?? 0;

    return _panel(
      title: 'Performance Overview',
      subtitle: 'Recorded generation compared with AI predictions',
      child: SizedBox(
        height: 280,
        child: BarChart(
          BarChartData(
            maxY: [
              actual,
              predicted,
              forecast,
              1,
            ].reduce((a, b) => a > b ? a : b) * 1.2,
            minY: 0,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => const FlLine(
                color: border,
                strokeWidth: 1,
              ),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 35,
                  getTitlesWidget: (value, meta) => Text(
                    value.toStringAsFixed(0),
                    style: const TextStyle(
                      color: muted,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 45,
                  getTitlesWidget: (value, meta) {
                    const labels = [
                      'Recorded\nGeneration',
                      'Predicted\nGeneration',
                      'Full-Day\nForecast',
                    ];

                    final index = value.toInt();
                    if (index < 0 || index >= labels.length) {
                      return const SizedBox.shrink();
                    }

                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        labels[index],
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: muted,
                          fontSize: 9,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            barGroups: [
              _bar(0, actual),
              _bar(1, predicted),
              _bar(2, forecast),
            ],
          ),
        ),
      ),
    );
  }

  BarChartGroupData _bar(int x, double value) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: value,
          width: 35,
          color: blue,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(5),
          ),
        ),
      ],
    );
  }

  Widget _previousDayPanel() {
    return _panel(
      title: 'Previous Day Analysis',
      subtitle: 'Completed-day performance details',
      child: Column(
        children: [
          _infoRow('Solar System', _systemName),
          _infoRow(
            'Evaluation Date',
            _formatDate(todayData['evaluation_date']),
          ),
          _infoRow(
            'Deviation',
            _deviation == null ? 'N/A' : _kwh(_deviation),
          ),
          _infoRow('Generation Data Source', _source),
          _infoRow('ML Model', _modelName),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: border),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: muted,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Color(0xFFF8FAFC),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _historyPanel(double width) {
    return _panel(
      title: 'Performance History',
      subtitle: 'Last 20 completed days. Today is excluded.',
      child: history.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No performance history available.',
                  style: TextStyle(color: muted),
                ),
              ),
            )
          : width < 650
              ? Column(
                  children: history.map(_historyCard).toList(),
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(navyLight),
                    headingTextStyle: const TextStyle(
                      color: muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                    dataTextStyle: const TextStyle(
                      color: Color(0xFFCBD5E1),
                      fontSize: 12,
                    ),
                    columns: const [
                      DataColumn(label: Text('DATE')),
                      DataColumn(label: Text('GENERATION')),
                      DataColumn(label: Text('PREDICTED')),
                      DataColumn(label: Text('DEVIATION')),
                      DataColumn(label: Text('PERFORMANCE')),
                      DataColumn(label: Text('STATUS')),
                    ],
                    rows: history.map((row) {
                      final status = row['status'].toString();

                      return DataRow(
                        cells: [
                          DataCell(Text(_formatDate(row['date']))),
                          DataCell(Text(
                            '${_num(row['actual']).toStringAsFixed(2)} kWh '
                            '(${row['source']})',
                          )),
                          DataCell(Text(_kwh(row['predicted']))),
                          DataCell(Text(
                            '${_num(row['deviation']) >= 0 ? '+' : ''}'
                            '${_num(row['deviation']).toStringAsFixed(2)} kWh',
                          )),
                          DataCell(Text(_percentage(row['percentage']))),
                          DataCell(_badge(status, _statusColor(status))),
                        ],
                      );
                    }).toList(),
                  ),
                ),
    );
  }

  Widget _historyCard(Map<String, dynamic> row) {
    final status = row['status'].toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: navy,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _formatDate(row['date']),
                  style: const TextStyle(
                    color: white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _badge(status, _statusColor(status)),
            ],
          ),
          const SizedBox(height: 12),
          _historyValue('Generation', _kwh(row['actual'])),
          _historyValue('Predicted', _kwh(row['predicted'])),
          _historyValue('Deviation', _kwh(row['deviation'])),
          _historyValue('Performance', _percentage(row['percentage'])),
          _historyValue('Source', row['source'].toString()),
        ],
      ),
    );
  }

  Widget _historyValue(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: muted,
                fontSize: 12,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Color(0xFFCBD5E1),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _panel({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: navy,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFFF8FAFC),
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 50,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 16),
            const Text(
              'Unable to load performance data',
              style: TextStyle(
                color: navy,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage ?? 'Something went wrong.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF475569)),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: loadPerformance,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}