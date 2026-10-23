import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'api_service.dart';

class GenerationScreen extends StatefulWidget {
  const GenerationScreen({super.key});

  @override
  State<GenerationScreen> createState() => _GenerationScreenState();
}

class _GenerationScreenState extends State<GenerationScreen> {
  static const Color bg = Color(0xFF101014);
  static const Color card = Color(0xFF19191F);
  static const Color gold = Color(0xFFFFBE2E);
  static const Color muted = Color(0xFFB5B5C0);
  static const Color border = Color(0xFF33333D);

  List<Map<String, dynamic>> records = [];
  List<Map<String, dynamic>> systems = [];

  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    loadData();
  }

  double number(dynamic value) {
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  // Prefer the backend's local calendar date.
  String dateKey(Map<String, dynamic> record) {
    final dailyDate = record['generation_date']?.toString();

    if (dailyDate != null && dailyDate.length >= 10) {
      return dailyDate.substring(0, 10);
    }

    final timestamp = record['recorded_at']?.toString();

    if (timestamp != null && timestamp.length >= 10) {
      return timestamp.substring(0, 10);
    }

    return '';
  }

  DateTime? parseDate(String key) {
    try {
      final parts = key.split('-');

      if (parts.length != 3) return null;

      return DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
    } catch (_) {
      return null;
    }
  }

  String formatDate(String key) {
    final date = parseDate(key);

    if (date == null) {
      return key.isEmpty ? 'Date unavailable' : key;
    }

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${date.day.toString().padLeft(2, '0')} '
        '${months[date.month - 1]} ${date.year}';
  }

  Future<void> loadData() async {
    if (mounted) {
      setState(() {
        loading = true;
        error = null;
      });
    }

    try {
      final results = await Future.wait([
        ApiService.getGenerationRecords(),
        ApiService.getSolarSystems(),
      ]);

      if (!mounted) return;

      final loadedRecords = results[0]
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      loadedRecords.sort(
        (a, b) => dateKey(b).compareTo(dateKey(a)),
      );

      final loadedSystems = results[1]
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      setState(() {
        records = loadedRecords;
        systems = loadedSystems;
        loading = false;
        error = null;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        loading = false;
        error =
            'Unable to load generation data. Check your login and connection.';
      });
    }
  }

  Map<String, dynamic>? get system {
    return systems.isEmpty ? null : systems.first;
  }

  List<Map<String, dynamic>> get simulated {
    return records.where((record) {
      return record['data_source']?.toString().toUpperCase() ==
          'SIMULATED';
    }).toList();
  }

  Map<String, dynamic>? get yesterdayRecord {
    final yesterday = DateTime.now().subtract(
      const Duration(days: 1),
    );

    final key =
        '${yesterday.year.toString().padLeft(4, '0')}-'
        '${yesterday.month.toString().padLeft(2, '0')}-'
        '${yesterday.day.toString().padLeft(2, '0')}';

    for (final record in simulated) {
      if (dateKey(record) == key) {
        return record;
      }
    }

    return null;
  }

  String sourceLabel(Map<String, dynamic> record) {
    switch (record['data_source']?.toString().toUpperCase()) {
      case 'SIMULATED':
        return 'Simulated estimate';

      case 'ACTUAL':
        return 'Actual measurement';

      default:
        return 'Source not specified';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.bolt, color: gold),
            SizedBox(width: 10),
            Text(
              'Generation',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: loadData,
            tooltip: 'Refresh generation data',
            icon: const Icon(
              Icons.refresh,
              color: gold,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: gold,
        backgroundColor: card,
        onRefresh: loadData,
        child: loading
            ? ListView(
                children: const [
                  SizedBox(height: 240),
                  Center(
                    child: CircularProgressIndicator(
                      color: gold,
                    ),
                  ),
                ],
              )
            : error != null
                ? ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      const SizedBox(height: 140),
                      const Icon(
                        Icons.cloud_off,
                        color: gold,
                        size: 42,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: ElevatedButton(
                          onPressed: loadData,
                          child: const Text('Try again'),
                        ),
                      ),
                    ],
                  )
                : ListView(
                    physics:
                        const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    children: [
                      const Text(
                        'SOLAR MONITORING',
                        style: TextStyle(
                          color: gold,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.7,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Solar Generation',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 27,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Daily generation estimates and historical records.',
                        style: TextStyle(color: muted),
                      ),
                      const SizedBox(height: 18),

                      _disclaimer(),

                      const SizedBox(height: 16),

                      _summaryGrid(),

                      const SizedBox(height: 14),

                      _systemCard(),

                      const SizedBox(height: 24),

                      _title('Daily Generation Trend'),

                      const SizedBox(height: 6),

                      const Text(
                        'Historical generation only. Forecast information is not shown here.',
                        style: TextStyle(
                          color: muted,
                          fontSize: 13,
                        ),
                      ),

                      const SizedBox(height: 12),

                      _chart(),

                      const SizedBox(height: 24),

                      _title('Generation History'),

                      const SizedBox(height: 6),

                      const Text(
                        'Newest date first. Each record is labelled by its source.',
                        style: TextStyle(
                          color: muted,
                          fontSize: 13,
                        ),
                      ),

                      const SizedBox(height: 12),

                      if (records.isEmpty)
                        _empty(
                          'No generation records are available yet.',
                        )
                      else
                        ...records.map(_historyCard),
                    ],
                  ),
      ),
    );
  }

  Widget _disclaimer() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF262014),
        borderRadius: BorderRadius.circular(14),
        border: const Border(
          left: BorderSide(
            color: gold,
            width: 4,
          ),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: gold,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SIMULATED DATA — NOT ACTUAL MEASUREMENTS',
                  style: TextStyle(
                    color: gold,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                SizedBox(height: 7),
                Text(
                  'Simulated values are demonstration estimates based on your registered solar system. They are not measured electricity production.',
                  style: TextStyle(
                    color: Colors.white,
                    height: 1.4,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryGrid() {
    final solarSystem = system;
    final yesterday = yesterdayRecord;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 12) / 2;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: width,
              child: _summary(
                'Yesterday\'s Generation',
                yesterday == null
                    ? 'No record'
                    : '${number(yesterday['energy_generated_kwh']).toStringAsFixed(2)} kWh',
                Icons.bolt,
                note: 'Simulated estimate',
              ),
            ),
            SizedBox(
              width: width,
              child: _summary(
                'Solar Panel Type',
                (solarSystem?['panel_type']
                            ?.toString()
                            .trim()
                            .isNotEmpty ??
                        false)
                    ? solarSystem!['panel_type'].toString()
                    : 'Not specified',
                Icons.solar_power,
              ),
            ),
            SizedBox(
              width: width,
              child: _summary(
                'Number of Panels',
                solarSystem == null
                    ? '--'
                    : '${solarSystem['panel_count'] ?? '--'}',
                Icons.grid_view,
              ),
            ),
            SizedBox(
              width: width,
              child: _summary(
                'Installed Capacity',
                solarSystem == null
                    ? '--'
                    : '${number(solarSystem['capacity_kw']).toStringAsFixed(2)} kW',
                Icons.electrical_services,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _summary(
    String title,
    String value,
    IconData icon, {
    String? note,
  }) {
    return Container(
      constraints: const BoxConstraints(
        minHeight: 125,
      ),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: gold,
            size: 24,
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              color: muted,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          if (note != null) ...[
            const SizedBox(height: 4),
            Text(
              note,
              style: const TextStyle(
                color: muted,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _systemCard() {
    final solarSystem = system;

    if (solarSystem == null) {
      return _empty(
        'Solar system configuration could not be loaded.',
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'REGISTERED SOLAR SYSTEM',
            style: TextStyle(
              color: gold,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            solarSystem['system_name']?.toString() ??
                'Solar system',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            solarSystem['location']?.toString() ??
                'Location not specified',
            style: const TextStyle(
              color: muted,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _title(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 21,
      ),
    );
  }

  Widget _chart() {
    final rows = simulated
      ..sort(
        (a, b) => dateKey(a).compareTo(dateKey(b)),
      );

    if (rows.isEmpty) {
      return _empty(
        'No simulated daily generation estimates are available.',
      );
    }

    final spots = <FlSpot>[];

    for (var i = 0; i < rows.length; i++) {
      spots.add(
        FlSpot(
          i.toDouble(),
          number(rows[i]['energy_generated_kwh']),
        ),
      );
    }

    final highest = spots.fold<double>(
      0,
      (maximum, spot) =>
          spot.y > maximum ? spot.y : maximum,
    );

    return Container(
      height: 265,
      padding: const EdgeInsets.fromLTRB(
        6,
        16,
        14,
        10,
      ),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: border),
      ),
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: highest <= 0 ? 10 : highest * 1.2,
          gridData: FlGridData(
            show: true,
            getDrawingHorizontalLine: (_) =>
                const FlLine(
              color: border,
              strokeWidth: 0.6,
            ),
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
                reservedSize: 36,
                getTitlesWidget: (value, _) {
                  return Text(
                    value.toStringAsFixed(0),
                    style: const TextStyle(
                      color: muted,
                      fontSize: 10,
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                interval: rows.length > 8
                    ? (rows.length / 5).ceilToDouble()
                    : 1,
                getTitlesWidget: (value, _) {
                  final index = value.toInt();

                  if (index < 0 || index >= rows.length) {
                    return const SizedBox.shrink();
                  }

                  final date = parseDate(
                    dateKey(rows[index]),
                  );

                  if (date == null) {
                    return const SizedBox.shrink();
                  }

                  return Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      '${date.day}/${date.month}',
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
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: gold,
              barWidth: 2.5,
              dotData: FlDotData(
                show: rows.length <= 35,
                getDotPainter: (
                  spot,
                  percent,
                  barData,
                  index,
                ) {
                  return FlDotCirclePainter(
                    radius: 3,
                    color: gold,
                    strokeColor: card,
                    strokeWidth: 1,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                color: gold.withValues(alpha: 0.10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _historyCard(Map<String, dynamic> record) {
    final isSimulated =
        record['data_source']?.toString().toUpperCase() ==
            'SIMULATED';

    final power = record['power_output_kw'];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.calendar_today,
                color: gold,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  formatDate(dateKey(record)),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: isSimulated
                      ? const Color(0xFF332813)
                      : const Color(0xFF173126),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSimulated
                        ? gold
                        : const Color(0xFF56C596),
                  ),
                ),
                child: Text(
                  sourceLabel(record),
                  style: TextStyle(
                    color: isSimulated
                        ? gold
                        : const Color(0xFF77D8AE),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _metric(
                  'GENERATION',
                  '${number(record['energy_generated_kwh']).toStringAsFixed(2)} kWh',
                ),
              ),
              Expanded(
                child: _metric(
                  'POWER OUTPUT',
                  power == null
                      ? 'Not available'
                      : '${number(power).toStringAsFixed(3)} kW',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: muted,
            fontSize: 10,
            letterSpacing: 0.7,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(
            color: gold,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _empty(String message) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: muted,
        ),
      ),
    );
  }
}
