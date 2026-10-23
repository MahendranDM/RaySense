import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import 'api_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const Color _bg = Color(0xFF050505);
  static const Color _panel = Color(0xFF0D0D0D);
  static const Color _panelAlt = Color(0xFF111111);
  static const Color _border = Color(0xFF202020);
  static const Color _gold = Color(0xFFFFD166);
  static const Color _muted = Color(0xFF858585);

  Map<String, dynamic>? _system;
  Map<String, dynamic>? _latestPerformance;
  Map<String, dynamic>? _mlForecast;
  List<dynamic> _generations = [];
  List<dynamic> _forecasts = [];
  List<dynamic> _weather = [];
  List<dynamic> _alerts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final systems = await ApiService.getSolarSystems();
      if (systems.isEmpty) throw Exception('No solar system found.');

      // Keep the ML forecast request and existing Django integrations.
      Map<String, dynamic>? ml;
      try {
        ml = await ApiService.getMLWeatherForecast();
      } catch (_) {
        // Other dashboard panels can still display if ML forecast is unavailable.
      }

      final results = await Future.wait<dynamic>([
        ApiService.getGenerationRecords(),
        ApiService.getForecasts(),
        ApiService.getTodayPerformance(),
        ApiService.getWeatherRecords(),
        ApiService.getAlerts(),
      ]);

      if (!mounted) return;
      setState(() {
        _system = Map<String, dynamic>.from(systems.first as Map);
        _generations = results[0] as List<dynamic>;
        _forecasts = results[1] as List<dynamic>;
        _latestPerformance = Map<String, dynamic>.from(results[2] as Map);
        _weather = results[3] as List<dynamic>;
        _alerts = results[4] as List<dynamic>;
        _mlForecast = ml;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  double _num(dynamic value) => double.tryParse(value?.toString() ?? '') ?? 0.0;

  dynamic _firstValue(Map? map, List<String> keys) {
    if (map == null) return null;
    for (final key in keys) {
      if (map[key] != null && map[key].toString().trim().isNotEmpty) return map[key];
    }
    return null;
  }

  String _fmt(dynamic value, {int digits = 2}) {
    if (value == null) return '—';
    final n = double.tryParse(value.toString());
    return n == null ? value.toString() : n.toStringAsFixed(digits);
  }

  DateTime? _date(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString())?.toLocal();
  }

  String _dateLabel(dynamic value) {
    final date = _date(value);
    if (date == null) return '—';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String get _systemName => _system?['system_name']?.toString() ?? 'Solar System';
  String get _location => _system?['location']?.toString() ?? 'Location unavailable';
  String get _capacity => '${_fmt(_system?['capacity_kw'])} kW';
  String get _panelCount => '${_system?['panel_count'] ?? '—'} panels';
  String get _panelType => _system?['panel_type']?.toString() ?? '—';
  String get _installation => _dateLabel(_system?['installation_date']);
  String get _performance => _firstValue(_latestPerformance, ['performance_percentage']) == null
      ? '—'
      : '${_fmt(_firstValue(_latestPerformance, ['performance_percentage']))}%';

  Map<String, dynamic>? get _latestGeneration {
    if (_generations.isEmpty) return null;
    final sorted = List<dynamic>.from(_generations);
    sorted.sort((a, b) {
      final da = _date((a as Map)['recorded_at']) ?? DateTime(1970);
      final db = _date((b as Map)['recorded_at']) ?? DateTime(1970);
      return db.compareTo(da);
    });
    return Map<String, dynamic>.from(sorted.first as Map);
  }

  Map<String, dynamic>? get _latestWeather {
    if (_weather.isEmpty) return null;
    final sorted = List<dynamic>.from(_weather);
    sorted.sort((a, b) {
      final da = _date((a as Map)['recorded_at'] ?? (a as Map)['created_at']) ?? DateTime(1970);
      final db = _date((b as Map)['recorded_at'] ?? (b as Map)['created_at']) ?? DateTime(1970);
      return db.compareTo(da);
    });
    return Map<String, dynamic>.from(sorted.first as Map);
  }

  double get _todayGeneration {
    final now = DateTime.now();
    var total = 0.0;
    for (final item in _generations) {
      if (item is! Map) continue;
      final date = _date(item['recorded_at']);
      if (date != null && date.year == now.year && date.month == now.month && date.day == now.day) {
        total += _num(item['energy_generated_kwh']);
      }
    }
    return total;
  }

  dynamic get _forecastValue {
    final performance = _firstValue(_latestPerformance, ['predicted_generation_kwh']);
    if (performance != null) return performance;
    final ml = _firstValue(_mlForecast, ['predicted_generation_kwh', 'generation_kwh', 'prediction']);
    if (ml != null) return ml;
    if (_forecasts.isNotEmpty && _forecasts.first is Map) {
      return _firstValue(_forecasts.first as Map, ['predicted_generation_kwh', 'generation_kwh']);
    }
    return null;
  }

  String get _modelName => _firstValue(_mlForecast, ['model_name', 'model', 'model_used'])?.toString()
      ?? (_forecasts.isNotEmpty && _forecasts.first is Map
          ? (_firstValue(_forecasts.first as Map, ['model_name', 'model'])?.toString() ?? 'ML model')
          : 'ML model');

  String get _weatherValue {
    final w = _latestWeather;
    if (w == null) return '—';
    return '—';
  }

  List<Map<String, dynamic>> get _recentGenerations {
    final records = _generations.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    records.sort((a, b) {
      final da = _date(a['recorded_at']) ?? DateTime(1970);
      final db = _date(b['recorded_at']) ?? DateTime(1970);
      return db.compareTo(da);
    });
    return records.take(4).toList();
  }

  List<Map<String, dynamic>> get _recentAlerts {
    final records = _alerts.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    records.sort((a, b) {
      final da = _date(a['created_at'] ?? a['recorded_at']) ?? DateTime(1970);
      final db = _date(b['created_at'] ?? b['recorded_at']) ?? DateTime(1970);
      return db.compareTo(da);
    });
    return records.where((a) => a['is_resolved'] != true).take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        surfaceTintColor: _bg,
        elevation: 0,
        titleSpacing: 20,
        title: const Row(
          children: [
            _BrandMark(),
            SizedBox(width: 10),
            Text('RaySense', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 19)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh dashboard',
            onPressed: _loading ? null : _loadDashboard,
            icon: const Icon(Icons.refresh_rounded, color: _gold),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        color: _gold,
        backgroundColor: _panelAlt,
        onRefresh: _loadDashboard,
        child: _loading
            ? ListView(children: [
                SizedBox(height: 220),
                Center(child: CircularProgressIndicator(color: _gold)),
                SizedBox(height: 16),
                Center(child: Text('Loading solar dashboard…', style: TextStyle(color: _muted))),
              ])
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                children: [
                  const Text('SOLAR INTELLIGENCE', style: TextStyle(color: _gold, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 2)),
                  const SizedBox(height: 8),
                  const Text('Dashboard', style: TextStyle(color: Colors.white, fontSize: 32, height: 1.1, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text('Monitor your solar system, generation and AI-powered forecasts.', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    _errorBanner(_error!),
                  ],
                  const SizedBox(height: 20),
                  LayoutBuilder(builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 620 ? 4 : 2;
                    final cardWidth = (constraints.maxWidth - (columns - 1) * 10) / columns;
                    final latest = _latestGeneration;
                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        SizedBox(width: cardWidth, child: _MetricCard(title: 'Latest Generation', value: latest == null ? '— kWh' : '${_fmt(latest['energy_generated_kwh'])} kWh', foot: _dateLabel(latest?['recorded_at']), icon: Icons.bolt_rounded)),
                        SizedBox(width: cardWidth, child: _MetricCard(title: "Today's AI Forecast", value: _forecastValue == null ? '— kWh' : '${_fmt(_forecastValue)} kWh', foot: _modelName, icon: Icons.auto_graph_rounded)),
                        SizedBox(width: cardWidth, child: _MetricCard(title: 'Installed Capacity', value: _capacity, foot: _panelCount, icon: Icons.solar_power_rounded)),
                        SizedBox(width: cardWidth, child: _MetricCard(title: 'Performance', value: _performance, foot: _latestPerformance?['status']?.toString() ?? 'Latest status', icon: Icons.speed_rounded)),
                      ],
                    );
                  }),
                  const SizedBox(height: 14),
                  LayoutBuilder(builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 760;
                    final chart = _Panel(
                      title: 'Solar Generation',
                      subtitle: 'Recent recorded generation',
                      trailing: const Text('kWh', style: TextStyle(color: _gold, fontWeight: FontWeight.w700)),
                      child: SizedBox(height: 210, child: _generationChart()),
                    );
                    final system = _Panel(
                      title: 'Solar System',
                      subtitle: 'System information',
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const _BrandMark(size: 40),
                        const SizedBox(height: 12),
                        Text(_systemName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                        const SizedBox(height: 4),
                        Text(_location, style: const TextStyle(color: _muted, fontSize: 11)),
                        const SizedBox(height: 14),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          _MiniInfo(label: 'Capacity', value: _capacity),
                          _MiniInfo(label: 'Panels', value: _panelCount),
                          _MiniInfo(label: 'Panel Type', value: _panelType),
                          _MiniInfo(label: 'Installation', value: _installation),
                        ]),
                      ]),
                    );
                    if (wide) {
                      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(flex: 7, child: chart),
                        const SizedBox(width: 12),
                        Expanded(flex: 4, child: system),
                      ]);
                    }
                    return Column(children: [chart, const SizedBox(height: 12), system]);
                  }),
                  const SizedBox(height: 14),
                  LayoutBuilder(builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 760;
                    final forecast = _Panel(
                      title: 'AI Generation Forecast',
                      subtitle: 'Machine-learning prediction',
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF191508),
                          border: Border.all(color: const Color(0xFF30260C)),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Row(children: [
                          Container(width: 42, height: 42, decoration: BoxDecoration(color: _gold, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.auto_awesome, color: _bg)),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(_forecastValue == null ? 'No forecast available' : '${_fmt(_forecastValue)} kWh', style: const TextStyle(color: _gold, fontWeight: FontWeight.w800, fontSize: 20)),
                            const SizedBox(height: 3),
                            const Text('Predicted solar generation', style: TextStyle(color: _muted, fontSize: 11)),
                            const SizedBox(height: 7),
                            _Tag(_modelName),
                          ])),
                        ]),
                      ),
                    );
                    final weather = _Panel(
                      title: 'Latest Weather',
                      subtitle: 'Recorded weather conditions',
                      child: _weatherGrid(),
                    );
                    if (wide) {
                      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(flex: 7, child: forecast),
                        const SizedBox(width: 12),
                        Expanded(flex: 4, child: weather),
                      ]);
                    }
                    return Column(children: [forecast, const SizedBox(height: 12), weather]);
                  }),
                  const SizedBox(height: 14),
                  LayoutBuilder(builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 760;
                    final generation = _Panel(
                      title: 'Recent Generation',
                      subtitle: 'Latest available records',
                      child: _generationTable(),
                    );
                    final alerts = _Panel(
                      title: 'Solar Alerts',
                      subtitle: 'System notifications',
                      child: _alertsList(),
                    );
                    if (wide) {
                      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(flex: 6, child: generation),
                        const SizedBox(width: 12),
                        Expanded(flex: 5, child: alerts),
                      ]);
                    }
                    return Column(children: [generation, const SizedBox(height: 12), alerts]);
                  }),
                  const SizedBox(height: 28),
                  Center(child: RichText(text: const TextSpan(style: TextStyle(fontSize: 10, color: _muted), children: [
                    TextSpan(text: 'RaySense', style: TextStyle(color: _gold, fontWeight: FontWeight.w800)),
                    TextSpan(text: ' · AI-Powered Solar Energy Intelligence'),
                  ]))),
                ],
              ),
      ),
    );
  }

  Widget _generationChart() {
    final records = _recentGenerations.reversed.toList();
    if (records.isEmpty) return const _EmptyState('No generation records available.');
    final spots = <FlSpot>[];
    for (var i = 0; i < records.length; i++) {
      spots.add(FlSpot(i.toDouble(), _num(records[i]['energy_generated_kwh'])));
    }
    final maxY = spots.map((e) => e.y).fold<double>(0, (a, b) => a > b ? a : b);
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY <= 0 ? 1 : maxY * 1.25,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          getDrawingHorizontalLine: (_) => const FlLine(color: Color(0xFF1B1B1B), strokeWidth: 1),
          getDrawingVerticalLine: (_) => const FlLine(color: Color(0xFF171717), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 26,
            getTitlesWidget: (value, meta) {
              final index = value.toInt();
              if (index < 0 || index >= records.length) return const SizedBox.shrink();
              final date = _date(records[index]['recorded_at']);
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(date == null ? '' : '${date.day}/${date.month}', style: const TextStyle(color: _muted, fontSize: 9)),
              );
            },
          )),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            color: _gold,
            barWidth: 2.5,
            dotData: FlDotData(show: true, getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(radius: 3, color: _gold, strokeWidth: 0)),
            belowBarData: BarAreaData(show: true, color: _gold.withValues(alpha: 0.06)),
          ),
        ],
      ),
    );
  }

  Widget _weatherGrid() {
    final w = _latestWeather;
    final fields = [
      ('Temperature', _firstValue(w, ['temperature', 'temperature_c', 'temperature_celsius']), '°C'),
      ('Humidity', _firstValue(w, ['humidity', 'humidity_percent']), '%'),
      ('Cloud Cover', _firstValue(w, ['cloud_cover', 'cloud_cover_percent']), '%'),
      ('Solar Irradiance', _firstValue(w, ['solar_irradiance', 'irradiance', 'solar_irradiance_w_m2']), ' W/m²'),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: fields.map((f) {
        final value = f.$2 == null ? '—' : '${_fmt(f.$2, digits: 1)}${f.$3}';
        return SizedBox(width: 140, child: _MiniInfo(label: f.$1, value: value));
      }).toList(),
    );
  }

  Widget _generationTable() {
    final records = _recentGenerations;
    if (records.isEmpty) return const _EmptyState('No generation records available.');
    return Column(children: [
      const Row(children: [
        Expanded(child: Text('DATE', style: TextStyle(color: _muted, fontSize: 9, fontWeight: FontWeight.w700))),
        Expanded(child: Text('ENERGY', style: TextStyle(color: _muted, fontSize: 9, fontWeight: FontWeight.w700))),
        Expanded(child: Text('POWER', style: TextStyle(color: _muted, fontSize: 9, fontWeight: FontWeight.w700))),
      ]),
      const SizedBox(height: 8),
      const Divider(color: _border, height: 1),
      for (final r in records) ...[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(children: [
            Expanded(child: Text(_dateLabel(r['recorded_at']), style: const TextStyle(color: _muted, fontSize: 10))),
            Expanded(child: Text('${_fmt(r['energy_generated_kwh'])} kWh', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700))),
            Expanded(child: Text('${_fmt(_firstValue(r, ['power_output_kw', 'power_kw', 'power_generated_kw', 'power']))} kW', style: const TextStyle(color: _muted, fontSize: 10))),
          ]),
        ),
        const Divider(color: _border, height: 1),
      ],
    ]);
  }

  Widget _alertsList() {
    final records = _recentAlerts;
    if (records.isEmpty) return const _EmptyState('No unresolved alerts.');
    return Column(
      children: records.map((a) {
        final title = _firstValue(a, ['title', 'alert_type', 'type', 'name'])?.toString() ?? 'Solar alert';
        final message = _firstValue(a, ['message', 'description', 'details'])?.toString() ?? 'Review this system notification.';
        final created = _dateLabel(a['created_at'] ?? a['recorded_at']);
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _panelAlt,
            borderRadius: BorderRadius.circular(12),
            border: const Border(left: BorderSide(color: Color(0xFFFFB547), width: 3)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11)),
            const SizedBox(height: 5),
            Text(message, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _muted, fontSize: 10, height: 1.4)),
            const SizedBox(height: 6),
            Text(created, style: const TextStyle(color: Color(0xFF666666), fontSize: 9)),
          ]),
        );
      }).toList(),
    );
  }

  Widget _errorBanner(String message) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: const Color(0xFF241111), border: Border.all(color: const Color(0xFF633333)), borderRadius: BorderRadius.circular(12)),
    child: Text('Some dashboard data could not be loaded: $message', style: const TextStyle(color: Color(0xFFFFB4AB), fontSize: 11)),
  );
}

class _BrandMark extends StatelessWidget {
  final double size;
  const _BrandMark({this.size = 34});

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: _DashboardScreenState._gold, borderRadius: BorderRadius.circular(size * .28)),
    child: Icon(Icons.sunny, color: _DashboardScreenState._bg, size: size * .58),
  );
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String foot;
  final IconData icon;
  const _MetricCard({required this.title, required this.value, required this.foot, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF12120F), Color(0xFF090909)]),
      border: Border.all(color: _DashboardScreenState._border),
      borderRadius: BorderRadius.circular(15),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _DashboardScreenState._muted, fontSize: 10)),
      const SizedBox(height: 12),
      Icon(icon, color: _DashboardScreenState._gold, size: 20),
      const SizedBox(height: 8),
      FittedBox(alignment: Alignment.centerLeft, fit: BoxFit.scaleDown, child: Text(value, style: const TextStyle(color: _DashboardScreenState._gold, fontWeight: FontWeight.w800, fontSize: 20))),
      const SizedBox(height: 5),
      Text(foot, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF666666), fontSize: 9)),
    ]),
  );
}

class _Panel extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;
  const _Panel({required this.title, required this.subtitle, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: _DashboardScreenState._panel, border: Border.all(color: _DashboardScreenState._border), borderRadius: BorderRadius.circular(16)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
          const SizedBox(height: 3),
          Text(subtitle, style: const TextStyle(color: _DashboardScreenState._muted, fontSize: 10)),
        ])),
        if (trailing != null) trailing!,
      ]),
      const SizedBox(height: 14),
      child,
    ]),
  );
}

class _MiniInfo extends StatelessWidget {
  final String label;
  final String value;
  const _MiniInfo({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Container(
    width: 128,
    constraints: const BoxConstraints(minHeight: 58),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: const Color(0xFF131313), border: Border.all(color: const Color(0xFF202020)), borderRadius: BorderRadius.circular(11)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: Color(0xFF777777), fontSize: 9)),
      const SizedBox(height: 6),
      Text(value, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
    ]),
  );
}

class _Tag extends StatelessWidget {
  final String text;
  const _Tag(this.text);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: const Color(0xFF28210E), borderRadius: BorderRadius.circular(20)),
    child: Text(text, style: const TextStyle(color: Color(0xFFB6A16A), fontSize: 9)),
  );
}

class _EmptyState extends StatelessWidget {
  final String text;
  const _EmptyState(this.text);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Center(child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF777777), fontSize: 11))),
  );
}
