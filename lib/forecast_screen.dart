import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:raysense_app/api_service.dart';

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

  static const Color _page = Color(0xFFF6F6F4);
  static const Color _gold = Color(0xFFF5C542);
  static const Color _ink = Color(0xFF171717);
  static const Color _muted = Color(0xFF777777);
  static const Color _border = Color(0xFFE8E8E8);

  @override
  void initState() {
    super.initState();
    loadForecast();
  }

  Future<void> loadForecast() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // Keep the existing Django API and ML forecasting integration.
      final systems = await ApiService.getSolarSystems();
      final data = await ApiService.getMLWeatherForecast();

      if (!mounted) return;

      setState(() {
        solarSystem =
            systems.isNotEmpty
                ? Map<String, dynamic>.from(systems[0])
                : null;

        forecastData = data;
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

  List<Map<String, dynamic>> get _predictions {
    final raw = forecastData?['predictions'];

    if (raw is! List) return [];

    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList()
      ..sort(
        (a, b) => _dateTime(a['time']).compareTo(_dateTime(b['time'])),
      );
  }

  DateTime _dateTime(dynamic value) {
    if (value == null) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    return DateTime.tryParse(value.toString()) ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  double _num(dynamic value) {
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _fmt(dynamic value, [int digits = 2]) {
    if (value == null ||
        double.tryParse(value.toString()) == null) {
      return '—';
    }

    return _num(value).toStringAsFixed(digits);
  }

  String _date(dynamic value) {
    if (value == null || value.toString().isEmpty) {
      return '—';
    }

    final d = DateTime.tryParse(value.toString());

    if (d == null) return value.toString();

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

    return '${d.day.toString().padLeft(2, '0')} '
        '${months[d.month - 1]} ${d.year}';
  }

  String _dateTimeLabel(dynamic value) {
    final d = _dateTime(value);

    if (d.millisecondsSinceEpoch == 0) return '—';

    final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final minute = d.minute.toString().padLeft(2, '0');
    final ampm = d.hour >= 12 ? 'PM' : 'AM';

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

    return '${d.day} ${months[d.month - 1]}, '
        '$hour:$minute $ampm';
  }

  String _systemName() =>
      forecastData?['system_name']?.toString() ??
      solarSystem?['system_name']?.toString() ??
      solarSystem?['name']?.toString() ??
      'Solar System';

  String _systemLocation() =>
      forecastData?['system_location']?.toString() ??
      solarSystem?['location']?.toString() ??
      '—';

  String _capacity() {
    final value =
        forecastData?['system_capacity_kw'] ??
        solarSystem?['capacity_kw'];

    return value == null ? '—' : '${_fmt(value)} kW';
  }

  double _generationFor(String key) =>
      _num(forecastData?[key]?['generation_kwh']);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _page,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _ink,
        elevation: 0,
        surfaceTintColor: Colors.white,
        titleSpacing: 20,
        title: const Row(
          children: [
            Icon(
              Icons.wb_sunny_rounded,
              color: _gold,
              size: 26,
            ),
            SizedBox(width: 10),
            Flexible(
              child: Text(
                'RaySense  •  AI Forecast',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh forecast',
            onPressed: isLoading ? null : loadForecast,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: isLoading
          ? _loadingView()
          : errorMessage != null
              ? _errorView()
              : RefreshIndicator(
                  onRefresh: loadForecast,
                  color: _gold,
                  child: _forecastBody(),
                ),
    );
  }

  Widget _loadingView() => Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(32),
          constraints: const BoxConstraints(maxWidth: 480),
          decoration: _cardDecoration(),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 42,
                height: 42,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: _gold,
                ),
              ),
              SizedBox(height: 22),
              Text(
                'Generating AI Forecast',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Fetching weather conditions and calculating '
                'solar generation predictionsâ€¦',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _muted,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      );

  Widget _errorView() => Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(26),
          constraints: const BoxConstraints(maxWidth: 520),
          decoration: _cardDecoration(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 48,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 14),
              const Text(
                'Unable to load forecast',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                errorMessage ?? 'Something went wrong.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: _muted),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: loadForecast,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _gold,
                  foregroundColor: _ink,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _forecastBody() {
    final predictions = _predictions;

    final first = predictions.isNotEmpty
        ? predictions.first
        : <String, dynamic>{};

    final width = MediaQuery.sizeOf(context).width;

    final columns = width >= 1100
        ? 4
        : width >= 650
            ? 2
            : 1;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        width < 600 ? 14 : 28,
        24,
        width < 600 ? 14 : 28,
        32,
      ),
      children: [
        const Text(
          'ARTIFICIAL INTELLIGENCE',
          style: TextStyle(
            color: Color(0xFFB28A12),
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.6,
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          'AI Forecast',
          style: TextStyle(
            color: _ink,
            fontSize: 30,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          'XGBoost-powered solar generation forecasting '
          'using weather data.',
          style: TextStyle(
            color: _muted,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 24),

        // Solar system information cards.
        GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: width >= 1100
              ? 2.5
              : width >= 650
                  ? 2.7
                  : 3.3,
          children: [
            _infoCard(
              Icons.grid_view_rounded,
              'Solar System',
              _systemName(),
            ),
            _infoCard(
              Icons.location_on_outlined,
              'Location',
              _systemLocation(),
            ),
            _infoCard(
              Icons.bolt_rounded,
              'System Capacity',
              _capacity(),
            ),
            _infoCard(
              Icons.auto_awesome_rounded,
              'AI Model',
              forecastData?['model']?.toString() ?? 'XGBoost',
              highlight: true,
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Generation outlook.
        _panel(
          eyebrow: 'GENERATION OUTLOOK',
          title: 'Solar Generation Forecast',
          subtitle:
              'Predicted energy production based on forecasted '
              'weather conditions.',
          trailing: _badge(
            '${forecastData?['forecast_hours'] ?? 168}-Hour AI Forecast',
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final count = constraints.maxWidth > 650 ? 3 : 1;

              return GridView.count(
                crossAxisCount: count,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: count == 1 ? 2.7 : 1.22,
                children: [
                  _dayCard(
                    'TODAY',
                    forecastData?['today'],
                    Icons.wb_sunny_rounded,
                    active: true,
                  ),
                  _dayCard(
                    'TOMORROW',
                    forecastData?['tomorrow'],
                    Icons.wb_sunny_outlined,
                  ),
                  _dayCard(
                    'DAY AFTER',
                    forecastData?['day_after_tomorrow'],
                    Icons.sunny_snowing,
                  ),
                ],
              );
            },
          ),
        ),

        // Short-term prediction.
        _panel(
          eyebrow: 'SHORT-TERM PREDICTION',
          title: 'Upcoming Generation',
          subtitle: 'AI prediction for the next several hours.',
          child: LayoutBuilder(
            builder: (context, constraints) {
              final count = constraints.maxWidth > 650 ? 4 : 2;

              return GridView.count(
                crossAxisCount: count,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.65,
                children: [
                  _shortCard(
                    'NEXT 1 HOUR',
                    _fmt(
                      forecastData?['next_1_hour']?['generation_kwh'],
                    ),
                    'kWh',
                  ),
                  _shortCard(
                    'NEXT 5 HOURS',
                    _fmt(
                      forecastData?['next_5_hours']?['generation_kwh'],
                    ),
                    'kWh',
                  ),
                  _shortCard(
                    'NEXT 12 HOURS',
                    _fmt(
                      forecastData?['next_12_hours']?['generation_kwh'],
                    ),
                    'kWh',
                    highlight: true,
                  ),
                  _shortCard(
                    'FORECAST RANGE',
                    '${forecastData?['forecast_hours'] ?? predictions.length}',
                    'hours',
                  ),
                ],
              );
            },
          ),
        ),

        // Hourly generation chart.
        _panel(
          eyebrow: 'AI PREDICTION CURVE',
          title: 'Hourly Solar Generation',
          subtitle: 'Predicted generation across the forecast period.',
          child: SizedBox(
            height: 280,
            child: predictions.isEmpty
                ? const Center(
                    child: Text(
                      'No prediction data available.',
                      style: TextStyle(color: _muted),
                    ),
                  )
                : LineChart(
                    LineChartData(
                      minY: 0,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (_) => const FlLine(
                          color: Color(0xFFEDEDED),
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
                            reservedSize: 42,
                            getTitlesWidget: (v, meta) => Text(
                              v.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 10,
                                color: _muted,
                              ),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 34,
                            interval: (predictions.length / 5)
                                .clamp(1, 100)
                                .toDouble(),
                            getTitlesWidget: (v, meta) {
                              final i = v.toInt();

                              if (i < 0 || i >= predictions.length) {
                                return const SizedBox.shrink();
                              }

                              final d = _dateTime(predictions[i]['time']);

                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  '${d.day}/${d.month}\n'
                                  '${d.hour.toString().padLeft(2, '0')}:00',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 9,
                                    color: _muted,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipItems: (spots) => spots
                              .map(
                                (s) => LineTooltipItem(
                                  '${s.y.toStringAsFixed(2)} kWh',
                                  const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: List.generate(
                            predictions.length,
                            (i) => FlSpot(
                              i.toDouble(),
                              _num(
                                predictions[i]['predicted_generation_kwh'],
                              ),
                            ),
                          ),
                          isCurved: true,
                          color: const Color(0xFFE5AF12),
                          barWidth: 3,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: _gold.withValues(alpha: 0.18),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),

        // Weather inputs.
        _panel(
          eyebrow: 'WEATHER INPUTS',
          title: 'Forecast Weather Conditions',
          subtitle: 'Weather variables used by the AI forecasting model.',
          child: GridView.count(
            crossAxisCount: width >= 850
                ? 3
                : width >= 560
                    ? 2
                    : 1,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: width < 560 ? 3.4 : 2.5,
            children: [
              _weatherCard(
                Icons.thermostat_rounded,
                'Temperature',
                '${_fmt(first['temperature'], 1)} °C',
              ),
              _weatherCard(
                Icons.water_drop_outlined,
                'Humidity',
                '${_fmt(first['humidity'], 0)} %',
              ),
              _weatherCard(
                Icons.wb_sunny_outlined,
                'Solar Radiation',
                '${_fmt(first['solar_radiation'], 1)} W/m²',
              ),
              _weatherCard(
                Icons.air_rounded,
                'Wind Speed',
                '${_fmt(first['wind_speed'], 1)} m/s',
              ),
              _weatherCard(
                Icons.speed_rounded,
                'Pressure',
                '${_fmt(first['pressure'], 2)} kPa',
              ),
              _weatherCard(
                Icons.navigation_rounded,
                'Wind Direction',
                '${_fmt(first['wind_direction'], 0)}°',
              ),
            ],
          ),
        ),

        // Detailed forecast table.
        _panel(
          eyebrow: '168-HOUR DATA',
          title: 'Detailed Forecast',
          subtitle:
              'Hour-by-hour weather and generation prediction.',
          child: predictions.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'No hourly forecast records available.',
                    style: TextStyle(color: _muted),
                  ),
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 710,
                    ),
                    child: Column(
                      children: [
                        // Table heading row.
                        Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 10,
                          ),
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFF7DC),
                            border: Border(
                              bottom: BorderSide(color: _border),
                            ),
                          ),
                          child: const Row(
                            children: [
                              _TableHead('Date & Time', 150),
                              _TableHead('Temperature', 100),
                              _TableHead('Humidity', 85),
                              _TableHead('Solar Radiation', 125),
                              _TableHead('Wind Speed', 100),
                              _TableHead('Predicted Generation', 150),
                            ],
                          ),
                        ),

                        // Vertically scrollable table rows.
                        SizedBox(  width: 760,
  height: 420,
  child: ListView.builder(
                            itemCount: predictions.length,
                            itemBuilder: (context, index) {
                              final p = predictions[index];

                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 11,
                                  horizontal: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: index.isEven
                                      ? Colors.white
                                      : const Color(0xFFFCFCFB),
                                  border: const Border(
                                    bottom: BorderSide(color: _border),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    _TableCell(
                                      _dateTimeLabel(p['time']),
                                      150,
                                    ),
                                    _TableCell(
                                      '${_fmt(p['temperature'], 1)} °C',
                                      100,
                                    ),
                                    _TableCell(
                                      '${_fmt(p['humidity'], 0)} %',
                                      85,
                                    ),
                                    _TableCell(
                                      '${_fmt(p['solar_radiation'], 0)} W/m²',
                                      125,
                                    ),
                                    _TableCell(
                                      '${_fmt(p['wind_speed'], 1)} m/s',
                                      100,
                                    ),
                                    _TableCell(
                                      '${_fmt(p['predicted_generation_kwh'])} kWh',
                                      150,
                                      bold: true,
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  BoxDecoration _cardDecoration({bool highlight = false}) =>
      BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: highlight
              ? const Color(0xFFF0D77A)
              : _border,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 18,
            offset: Offset(0, 4),
          ),
        ],
      );

  Widget _infoCard(
    IconData icon,
    String title,
    String value, {
    bool highlight = false,
  }) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(highlight: highlight),
        child: Row(
          children: [
            Container(
              width: 43,
              height: 43,
              decoration: BoxDecoration(
                color: _gold.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                icon,
                color: const Color(0xFF9A7600),
                size: 23,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _panel({
    required String eyebrow,
    required String title,
    required String subtitle,
    required Widget child,
    Widget? trailing,
  }) =>
      Container(
        margin: const EdgeInsets.only(bottom: 18),
        padding: const EdgeInsets.all(20),
        decoration: _cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        eyebrow,
                        style: const TextStyle(
                          color: Color(0xFFB28A12),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.3,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        title,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 12,
                          height: 1.45,
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
            const SizedBox(height: 20),
            child,
          ],
        ),
      );

  Widget _badge(String text) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 11,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7DC),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0xFF8C6B00),
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      );

  Widget _dayCard(
    String label,
    dynamic data,
    IconData icon, {
    bool active = false,
  }) {
    final map = data is Map
        ? Map<String, dynamic>.from(data)
        : <String, dynamic>{};

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: active
            ? const Color(0xFFFFFBED)
            : const Color(0xFFFCFCFB),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: active
              ? const Color(0xFFF0D77A)
              : _border,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _muted,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _date(map['date']),
            style: const TextStyle(
              color: _muted,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 10),
          Icon(
            icon,
            color: const Color(0xFFE3AD10),
            size: 28,
          ),
          const SizedBox(height: 8),
          Text(
            _fmt(map['generation_kwh']),
            style: const TextStyle(
              color: _ink,
              fontSize: 27,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Text(
            'kWh predicted',
            style: TextStyle(
              color: _muted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _shortCard(
    String label,
    String value,
    String unit, {
    bool highlight = false,
  }) =>
      Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: highlight
              ? const Color(0xFFFFFBED)
              : const Color(0xFFFCFCFB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: highlight
                ? const Color(0xFFF0D77A)
                : _border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: _muted,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: .5,
              ),
            ),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text(
              unit,
              style: const TextStyle(
                color: _muted,
                fontSize: 11,
              ),
            ),
          ],
        ),
      );

  Widget _weatherCard(
    IconData icon,
    String title,
    String value,
  ) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFCFCFB),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: const Color(0xFFB28A12),
              size: 25,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    value,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _TableHead extends StatelessWidget {
  final String label;
  final double width;

  const _TableHead(this.label, this.width);

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF6F6546),
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
      );
}

class _TableCell extends StatelessWidget {
  final String value;
  final double width;
  final bool bold;

  const _TableCell(
    this.value,
    this.width, {
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        width: width,
        child: Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: const Color(0xFF292929),
            fontSize: 11,
            fontWeight: bold
                ? FontWeight.w800
                : FontWeight.w500,
          ),
        ),
      );
}








