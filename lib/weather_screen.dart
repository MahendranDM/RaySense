import 'package:flutter/material.dart';
import 'api_service.dart';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  List<dynamic> weatherRecords = [];

  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadWeather();
  }

  Future<void> loadWeather() async {
    try {
      final data = await ApiService.getWeatherRecords();

      if (!mounted) return;

      setState(() {
        weatherRecords = data;
        isLoading = false;
        errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = 'Unable to load weather data.';
      });
    }
  }

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
              Icons.cloud_outlined,
              color: Colors.orange,
            ),
            SizedBox(width: 10),
            Text(
              'Weather',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),

      body: RefreshIndicator(
        onRefresh: loadWeather,

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
                        child: Text(
                          errorMessage!,
                          style: const TextStyle(
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  )
                : weatherRecords.isEmpty
                    ? ListView(
                        children: const [
                          SizedBox(height: 180),
                          Center(
                            child: Text(
                              'No weather records found.',
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
                          const Text(
                            'Solar Weather',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 6),

                          Text(
                            'Weather conditions affecting solar generation',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 15,
                            ),
                          ),

                          const SizedBox(height: 20),

                          _buildCurrentWeatherCard(
                            weatherRecords[0],
                          ),

                          const SizedBox(height: 24),

                          const Text(
                            'Weather Parameters',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 12),

                          _buildParameterGrid(
                            weatherRecords[0],
                          ),

                          const SizedBox(height: 24),

                          const Text(
                            'Weather History',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 12),

                          ...weatherRecords.map(
                            (weather) =>
                                _buildHistoryCard(weather),
                          ),

                          const SizedBox(height: 20),
                        ],
                      ),
      ),
    );
  }

  Widget _buildCurrentWeatherCard(
    dynamic weather,
  ) {
    final temperature =
        weather['temperature'] ?? '--';

    final humidity =
        weather['humidity'] ?? '--';

    final cloudCover =
        weather['cloud_cover'] ?? '--';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),

      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF42A5F5),
            Color(0xFF1976D2),
          ],
        ),

        borderRadius: BorderRadius.circular(22),

        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(
              alpha: 0.20,
            ),
            blurRadius: 12,
            offset: const Offset(0, 6),
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
                Icons.wb_sunny,
                color: Colors.white,
                size: 32,
              ),

              SizedBox(width: 10),

              Text(
                'Current Conditions',
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
            '$temperature °C',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 42,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 10),

          Text(
            'Humidity: $humidity%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            'Cloud Cover: $cloudCover%',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParameterGrid(
    dynamic weather,
  ) {
    final temperature =
        weather['temperature'] ?? '--';

    final humidity =
        weather['humidity'] ?? '--';

    final cloudCover =
        weather['cloud_cover'] ?? '--';

    final windSpeed =
        weather['wind_speed'] ?? '--';

    final irradiance =
        weather['solar_irradiance'] ?? '--';

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _WeatherParameterCard(
                icon: Icons.thermostat,
                title: 'Temperature',
                value: '$temperature °C',
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: _WeatherParameterCard(
                icon: Icons.water_drop_outlined,
                title: 'Humidity',
                value: '$humidity%',
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _WeatherParameterCard(
                icon: Icons.cloud_outlined,
                title: 'Cloud Cover',
                value: '$cloudCover%',
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: _WeatherParameterCard(
                icon: Icons.air,
                title: 'Wind Speed',
                value: '$windSpeed',
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        _WeatherParameterCard(
          icon: Icons.wb_sunny_outlined,
          title: 'Solar Irradiance',
          value: '$irradiance W/m²',
        ),
      ],
    );
  }

  Widget _buildHistoryCard(
    dynamic weather,
  ) {
    final date =
        weather['recorded_at'] ?? '--';

    final temperature =
        weather['temperature'] ?? '--';

    final humidity =
        weather['humidity'] ?? '--';

    final irradiance =
        weather['solar_irradiance'] ?? '--';

    return Container(
      margin: const EdgeInsets.only(
        bottom: 12,
      ),

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
              color: Colors.blue.shade50,
              shape: BoxShape.circle,
            ),

            child: const Icon(
              Icons.cloud_outlined,
              color: Colors.blue,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                Text(
                  date.toString(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  '$temperature °C • $humidity% humidity',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          Column(
            crossAxisAlignment:
                CrossAxisAlignment.end,

            children: [
              const Icon(
                Icons.wb_sunny,
                color: Colors.orange,
                size: 20,
              ),

              const SizedBox(height: 4),

              Text(
                '$irradiance W/m²',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


// Weather Parameter Card

class _WeatherParameterCard
    extends StatelessWidget {

  final IconData icon;
  final String title;
  final String value;

  const _WeatherParameterCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(18),
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          Icon(
            icon,
            color: Colors.orange,
            size: 28,
          ),

          const SizedBox(height: 12),

          Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}