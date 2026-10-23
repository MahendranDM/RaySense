import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'api_service.dart';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  static const _page = Color(0xFFF4F6FA);
  static const _navy = Color(0xFF111827);
  static const _navyDeep = Color(0xFF0B1220);
  static const _gold = Color(0xFFFFC94A);
  static const _muted = Color(0xFF9AA6BA);
  static const _border = Color(0xFF263247);

  bool _loading = true;
  String? _error;
  Map<String, dynamic> _forecast = {};
  List<Map<String, dynamic>> _predictions = [];

  @override
  void initState() {
    super.initState();
    _loadWeather();
  }

  Future<void> _loadWeather() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // This is the same endpoint used by the Django Weather page.
      final response = await ApiService.getMLWeatherForecast();
      final raw = response['predictions'];
      final predictions = raw is List
          ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() {
        _forecast = response;
        _predictions = predictions..sort((a, b) => _timeOf(a).compareTo(_timeOf(b)));
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

  DateTime _timeOf(Map<String, dynamic> item) {
    final value = item['time'] ?? item['recorded_at'] ?? item['timestamp'];
    return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  double? _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  String _fmt(dynamic value, {int digits = 1, String suffix = ''}) {
    final n = _number(value);
    if (n == null) return '—';
    return '${n.toStringAsFixed(digits)}$suffix';
  }

  String _date(DateTime date, {bool withTime = false}) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final d = '${date.day} ${months[date.month - 1]} ${date.year}';
    if (!withTime) return d;
    return '$d, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic>? get _current {
    if (_predictions.isEmpty) return null;
    final now = DateTime.now();
    return _predictions.reduce((a, b) {
      final da = _timeOf(a).difference(now).inSeconds.abs();
      final db = _timeOf(b).difference(now).inSeconds.abs();
      return da <= db ? a : b;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _page,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF17191F),
        elevation: 0,
        titleSpacing: 18,
        title: const Row(children: [
          DecoratedBox(
            decoration: BoxDecoration(color: _gold, borderRadius: BorderRadius.all(Radius.circular(10))),
            child: SizedBox(width: 34, height: 34, child: Icon(Icons.wb_sunny_rounded, color: Color(0xFF111827), size: 22)),
          ),
          SizedBox(width: 10),
          Text('RaySense', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        ]),
        actions: [
          IconButton(
            tooltip: 'Refresh weather',
            onPressed: _loading ? null : _loadWeather,
            icon: const Icon(Icons.refresh_rounded, color: _gold),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _gold))
          : RefreshIndicator(
              onRefresh: _loadWeather,
              color: _gold,
              child: _error != null
                  ? ListView(padding: const EdgeInsets.all(24), children: [
                      const SizedBox(height: 80),
                      const Icon(Icons.cloud_off_outlined, color: _gold, size: 48),
                      const SizedBox(height: 14),
                      const Text('Weather data could not be loaded', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF667085))),
                      const SizedBox(height: 18),
                      Center(child: FilledButton.icon(onPressed: _loadWeather, icon: const Icon(Icons.refresh), label: const Text('Try again'))),
                    ])
                  : _buildContent(),
            ),
    );
  }

  Widget _buildContent() {
    final current = _current;
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 850;
    final systemName = (_forecast['system_name'] ?? 'Solar System').toString();
    final systemLocation = (_forecast['system_location'] ?? 'Location unavailable').toString();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(width < 600 ? 14 : 24, 22, width < 600 ? 14 : 24, 30),
      children: [
        const Text('WEATHER INTELLIGENCE', style: TextStyle(color: Color(0xFF9A6B00), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.8)),
        const SizedBox(height: 8),
        const Text('Weather', style: TextStyle(color: Color(0xFF111827), fontSize: 30, fontWeight: FontWeight.w900, height: 1.1)),
        const SizedBox(height: 7),
        const Text('Live weather conditions used by RaySense for solar energy forecasting.', style: TextStyle(color: Color(0xFF667085), fontSize: 13)),
        const SizedBox(height: 20),
        _locationBanner(systemName, systemLocation),
        const SizedBox(height: 16),
        if (current == null)
          _emptyPanel('No weather forecast data available', 'The weather API returned no prediction records.')
        else ...[
          _metricGrid(current, width),
          const SizedBox(height: 14),
          _dailySummary(width),
          const SizedBox(height: 14),
          if (wide)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 6, child: _chartPanel()),
              const SizedBox(width: 14),
              Expanded(flex: 4, child: _conditionsPanel(current)),
            ])
          else ...[
            _chartPanel(),
            const SizedBox(height: 14),
            _conditionsPanel(current),
          ],
          const SizedBox(height: 14),
          _hourlyTable(width),
        ],
        const SizedBox(height: 20),
        const Center(child: Text.rich(TextSpan(children: [
          TextSpan(text: 'RaySense', style: TextStyle(color: Color(0xFF9A6B00), fontWeight: FontWeight.bold)),
          TextSpan(text: ' · AI-Powered Solar Energy Intelligence', style: TextStyle(color: Color(0xFF7B8494))),
        ]), textAlign: TextAlign.center, style: TextStyle(fontSize: 11))),
      ],
    );
  }

  Widget _locationBanner(String name, String location) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(color: const Color(0xFFFFF8E5), borderRadius: BorderRadius.circular(13), border: Border.all(color: const Color(0xFFF1DDA1))),
        child: Wrap(alignment: WrapAlignment.spaceBetween, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.location_on_rounded, color: Color(0xFFB77C00), size: 22),
            const SizedBox(width: 10),
            ConstrainedBox(constraints: const BoxConstraints(maxWidth: 260), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF202938), fontSize: 13, fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(location, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF667085), fontSize: 11)),
            ])),
          ]),
          Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7), decoration: BoxDecoration(color: const Color(0xFFFFE7A3), borderRadius: BorderRadius.circular(20)), child: const Text('XGBoost Forecast', style: TextStyle(color: Color(0xFF855B00), fontSize: 10, fontWeight: FontWeight.w800))),
        ]),
      );

  Widget _metricGrid(Map<String, dynamic> current, double width) {
    final count = width >= 1050 ? 5 : width >= 650 ? 3 : 2;
    final items = <_MetricData>[
      _MetricData('Current Temperature', _fmt(current['temperature'], digits: 1), '°C', Icons.thermostat_rounded),
      _MetricData('Humidity', _fmt(current['humidity'], digits: 0), '%', Icons.water_drop_outlined),
      _MetricData('Wind Speed', _fmt(current['wind_speed'], digits: 1), 'm/s', Icons.air_rounded),
      _MetricData('Pressure', _fmt(current['pressure'], digits: 2), 'kPa', Icons.speed_rounded),
      _MetricData('Solar Radiation', _fmt(current['solar_radiation'], digits: 1), 'W/m²', Icons.wb_sunny_outlined),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      final gap = 10.0;
      final cardWidth = (constraints.maxWidth - gap * (count - 1)) / count;
      return Wrap(spacing: gap, runSpacing: gap, children: items.map((m) => SizedBox(width: cardWidth, child: _metricCard(m))).toList());
    });
  }

  Widget _metricCard(_MetricData data) => Container(
        constraints: const BoxConstraints(minHeight: 116),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF172033), Color(0xFF101827)]), borderRadius: BorderRadius.circular(13), border: Border.all(color: _border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Expanded(child: Text(data.title, style: const TextStyle(color: _muted, fontSize: 11, fontWeight: FontWeight.w600))), Icon(data.icon, color: _gold, size: 18)]),
          const SizedBox(height: 13),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(data.value, style: const TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w900))),
          const SizedBox(height: 2),
          Text(data.unit, style: const TextStyle(color: _muted, fontSize: 10)),
        ]),
      );

  Widget _dailySummary(double width) {
    final keys = [
      ('TODAY', _forecast['today']),
      ('TOMORROW', _forecast['tomorrow']),
      ('DAY AFTER TOMORROW', _forecast['day_after_tomorrow']),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      final cardWidth = (constraints.maxWidth - 20) / (width < 480 ? 1 : 3);
      return Wrap(spacing: 10, runSpacing: 10, children: keys.map((entry) {
        final data = entry.$2 is Map ? Map<String, dynamic>.from(entry.$2 as Map) : <String, dynamic>{};
        final date = DateTime.tryParse(data['date']?.toString() ?? '');
        return SizedBox(width: cardWidth, child: Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: _navy, borderRadius: BorderRadius.circular(12), border: Border.all(color: _border)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(entry.$1, style: const TextStyle(color: _gold, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
          const SizedBox(height: 7),
          Text(date == null ? 'Date unavailable' : _date(date), style: const TextStyle(color: _muted, fontSize: 11)),
          const SizedBox(height: 8),
          Text('${_fmt(data['generation_kwh'], digits: 2)} kWh', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          const Text('Predicted generation', style: TextStyle(color: _muted, fontSize: 10)),
        ])));
      }).toList());
    });
  }

  Widget _chartPanel() {
    final points = _predictions.take(48).toList();
    return _panel('Weather & Solar Radiation', 'Hourly weather conditions used by the forecasting model', SizedBox(height: 240, child: points.length < 2 ? const Center(child: Text('Not enough records to draw a chart.', style: TextStyle(color: _muted, fontSize: 12))) : _WeatherChart(points: points, timeOf: _timeOf, number: _number)));
  }

  Widget _conditionsPanel(Map<String, dynamic> current) {
    final rows = <(String, String)>[
      ('Temperature', _fmt(current['temperature'], digits: 1, suffix: ' °C')),
      ('Humidity', _fmt(current['humidity'], digits: 0, suffix: '%')),
      ('Wind Speed', _fmt(current['wind_speed'], digits: 1, suffix: ' m/s')),
      ('Wind Direction', _fmt(current['wind_direction'], digits: 0, suffix: '°')),
      ('Pressure', _fmt(current['pressure'], digits: 2, suffix: ' kPa')),
      ('Solar Radiation', _fmt(current['solar_radiation'], digits: 1, suffix: ' W/m²')),
      ('Forecast Time', _date(_timeOf(current), withTime: true)),
    ];
    return _panel('Current Conditions', 'Live weather inputs', Column(children: rows.map((r) => Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _border, width: .7))), child: Row(children: [Expanded(child: Text(r.$1, style: const TextStyle(color: _muted, fontSize: 12))), const SizedBox(width: 12), Flexible(child: Text(r.$2, textAlign: TextAlign.right, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)))]))).toList()));
  }

  Widget _hourlyTable(double width) {
    const headers = ['TIME', 'TEMP', 'HUMIDITY', 'WIND', 'PRESSURE', 'SOLAR RADIATION', 'PREDICTED GENERATION'];
    return _panel('15-Hour Weather Forecast', 'Weather inputs and predicted solar generation from the forecast API', _predictions.isEmpty
        ? const Padding(padding: EdgeInsets.all(24), child: Text('No hourly forecast data available.', style: TextStyle(color: _muted)))
        : SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
            headingRowHeight: 42,
            dataRowMinHeight: 42,
            dataRowMaxHeight: 54,
            horizontalMargin: 10,
            columnSpacing: width < 600 ? 20 : 28,
            headingTextStyle: const TextStyle(color: _muted, fontSize: 10, fontWeight: FontWeight.w900),
            dataTextStyle: const TextStyle(color: Color(0xFFD9E0EB), fontSize: 11),
            columns: headers.map((h) => DataColumn(label: Text(h))).toList(),
            rows: _predictions.map((item) => DataRow(cells: [
              DataCell(Text(_date(_timeOf(item), withTime: true))),
              DataCell(Text(_fmt(item['temperature'], digits: 1, suffix: ' °C'))),
              DataCell(Text(_fmt(item['humidity'], digits: 0, suffix: '%'))),
              DataCell(Text('${_fmt(item['wind_speed'], digits: 1)} m/s / ${_fmt(item['wind_direction'], digits: 0)}°')),
              DataCell(Text(_fmt(item['pressure'], digits: 2, suffix: ' kPa'))),
              DataCell(Text(_fmt(item['solar_radiation'], digits: 1, suffix: ' W/m²'))),
              DataCell(Text(_fmt(item['predicted_generation_kwh'], digits: 2, suffix: ' kWh'), style: const TextStyle(color: _gold, fontWeight: FontWeight.w900))),
            ])).toList(),
          )));
  }

  Widget _panel(String title, String subtitle, Widget child) => Container(
        margin: const EdgeInsets.only(bottom: 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: _navy, borderRadius: BorderRadius.circular(14), border: Border.all(color: _border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: _muted, fontSize: 11)),
          const SizedBox(height: 15),
          child,
        ]),
      );

  Widget _emptyPanel(String title, String message) => Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(color: _navy, borderRadius: BorderRadius.circular(14), border: Border.all(color: _border)), child: Column(children: [const Icon(Icons.cloud_queue_rounded, color: _gold, size: 38), const SizedBox(height: 12), Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), const SizedBox(height: 6), Text(message, textAlign: TextAlign.center, style: const TextStyle(color: _muted, fontSize: 12))]));
}

class _MetricData {
  final String title;
  final String value;
  final String unit;
  final IconData icon;
  const _MetricData(this.title, this.value, this.unit, this.icon);
}

class _WeatherChart extends StatelessWidget {
  final List<Map<String, dynamic>> points;
  final DateTime Function(Map<String, dynamic>) timeOf;
  final double? Function(dynamic) number;
  const _WeatherChart({required this.points, required this.timeOf, required this.number});

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _WeatherChartPainter(points, timeOf, number), child: const SizedBox.expand());
}

class _WeatherChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> points;
  final DateTime Function(Map<String, dynamic>) timeOf;
  final double? Function(dynamic) number;
  _WeatherChartPainter(this.points, this.timeOf, this.number);

  static const gold = Color(0xFFFFC94A);
  static const blue = Color(0xFF49B6FF);
  static const grid = Color(0xFF273247);
  static const muted = Color(0xFF8793A7);

  @override
  void paint(Canvas canvas, Size size) {
    const left = 34.0, right = 10.0, top = 12.0, bottom = 28.0;
    final chart = Rect.fromLTRB(left, top, size.width - right, size.height - bottom);
    final gridPaint = Paint()..color = grid..strokeWidth = .7;
    for (var i = 0; i <= 4; i++) {
      final y = chart.top + chart.height * i / 4;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), gridPaint);
    }
    for (var i = 0; i <= 5; i++) {
      final x = chart.left + chart.width * i / 5;
      canvas.drawLine(Offset(x, chart.top), Offset(x, chart.bottom), gridPaint);
    }
    final temps = points.map((p) => (number(p['temperature'])?.toDouble())).whereType<double>().toList();
    final radiation = points.map((p) => (number(p['solar_radiation'])?.toDouble())).whereType<double>().toList();
    if (temps.isEmpty || radiation.isEmpty) return;
    final tMin = math.min(0.0, temps.reduce(math.min)).toDouble();
    final tMax = math.max(tMin + 1.0, temps.reduce(math.max)).toDouble();
    final rMax = math.max(1.0, radiation.reduce(math.max)).toDouble();
    List<Offset> offsets(List<double?> values, double min, double max) {
      final valid = <Offset>[];
      for (var i = 0; i < values.length; i++) {
        final v = values[i];
        if (v == null) continue;
        final x = chart.left + (points.length <= 1 ? .5 : i / (points.length - 1)) * chart.width;
        final y = chart.bottom - (((v - min) / (max - min)).clamp(0.0, 1.0).toDouble() * chart.height);
        valid.add(Offset(x, y));
      }
      return valid;
    }
    void drawLine(List<Offset> pts, Color color) {
      if (pts.length < 2) return;
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final p in pts.skip(1)) { path.lineTo(p.dx, p.dy); }
      canvas.drawPath(path, Paint()..color = color..strokeWidth = 2.2..style = PaintingStyle.stroke..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
    }
    final tempPoints = offsets(points.map((p) => (number(p['temperature'])?.toDouble())).toList(), tMin, tMax);
    final radPoints = offsets(points.map((p) => (number(p['solar_radiation'])?.toDouble())).toList(), 0, rMax);
    drawLine(radPoints, blue);
    drawLine(tempPoints, gold);
    for (final p in [if (tempPoints.isNotEmpty) tempPoints.first, if (tempPoints.isNotEmpty) tempPoints.last]) { canvas.drawCircle(p, 3, Paint()..color = gold); }
    for (final p in [if (radPoints.isNotEmpty) radPoints.first, if (radPoints.isNotEmpty) radPoints.last]) { canvas.drawCircle(p, 3, Paint()..color = blue); }
    final labelPaint = TextPainter(textDirection: TextDirection.ltr);
    for (var i = 0; i <= 5; i++) {
      final idx = ((points.length - 1) * i / 5).round();
      final dt = timeOf(points[idx]);
      final text = '${dt.day}/${dt.month}';
      labelPaint.text = TextSpan(text: text, style: const TextStyle(color: muted, fontSize: 9));
      labelPaint.layout();
      final x = (chart.left + chart.width * i / 5 - labelPaint.width / 2).clamp(0.0, size.width - labelPaint.width).toDouble();
      labelPaint.paint(canvas, Offset(x, chart.bottom + 8));
    }
    final legend = TextPainter(textDirection: TextDirection.ltr);
    legend.text = const TextSpan(children: [TextSpan(text: '● ', style: TextStyle(color: gold, fontSize: 10)), TextSpan(text: 'Temperature  ', style: TextStyle(color: muted, fontSize: 10)), TextSpan(text: '● ', style: TextStyle(color: blue, fontSize: 10)), TextSpan(text: 'Solar radiation', style: TextStyle(color: muted, fontSize: 10))]);
    legend.layout(maxWidth: size.width);
    legend.paint(canvas, Offset(math.max(0, size.width - legend.width), 0));
  }

  @override
  bool shouldRepaint(covariant _WeatherChartPainter oldDelegate) => oldDelegate.points != points;
}
