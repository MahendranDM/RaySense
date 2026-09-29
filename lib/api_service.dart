import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl =
      'http://127.0.0.1:8000';

  // ------------------------------------------------------------
  // Solar Systems
  // ------------------------------------------------------------

  static Future<List<dynamic>> getSolarSystems() async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/api/solar/systems/',
      ),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    throw Exception(
      'Failed to load solar systems: '
      '${response.statusCode}',
    );
  }

  // ------------------------------------------------------------
  // Update Solar System
  // ------------------------------------------------------------

  static Future<Map<String, dynamic>>
      updateSolarSystem({
    required int systemId,
    required String systemName,
    required String location,
    required double capacityKw,
    required double electricityRate,
    required int panelCount,
    required String panelType,
    String? installationDate,
  }) async {
    final response = await http.patch(
      Uri.parse(
        '$baseUrl/api/solar/systems/$systemId/',
      ),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'system_name': systemName,
        'location': location,
        'capacity_kw': capacityKw,
        'electricity_rate': electricityRate,
        'panel_count': panelCount,
        'panel_type': panelType,
        'installation_date': installationDate,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body)
          as Map<String, dynamic>;
    }

    throw Exception(
      'Failed to update solar system: '
      '${response.statusCode} '
      '${response.body}',
    );
  }

  // ------------------------------------------------------------
  // Forecast Records
  // ------------------------------------------------------------

  static Future<List<dynamic>> getForecasts() async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/api/forecasting/records/',
      ),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    throw Exception(
      'Failed to load forecasts: '
      '${response.statusCode}',
    );
  }

  // ------------------------------------------------------------
  // Performance Records
  // ------------------------------------------------------------

  static Future<List<dynamic>> getPerformance() async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/api/performance/records/',
      ),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    throw Exception(
      'Failed to load performance records: '
      '${response.statusCode}',
    );
  }

  // ------------------------------------------------------------
  // TODAY'S PERFORMANCE
  //
  // Backend automatically calculates:
  // - Today's actual generation
  // - Today's expected generation
  // - Deviation
  // - Performance percentage
  // - Performance status
  //
  // Endpoint:
  // /api/performance/today/
  // ------------------------------------------------------------

  static Future<Map<String, dynamic>>
      getTodayPerformance() async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/api/performance/today/',
      ),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body)
          as Map<String, dynamic>;
    }

    throw Exception(
      'Failed to load today performance: '
      '${response.statusCode} '
      '${response.body}',
    );
  }

  // ------------------------------------------------------------
  // Alerts
  // ------------------------------------------------------------

  static Future<List<dynamic>> getAlerts() async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/api/alerts/records/',
      ),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    throw Exception(
      'Failed to load alerts: '
      '${response.statusCode}',
    );
  }

  // ------------------------------------------------------------
  // Resolve / Update Alert
  // ------------------------------------------------------------

  static Future<Map<String, dynamic>> resolveAlert({
    required int alertId,
    required bool isResolved,
  }) async {
    final response = await http.patch(
      Uri.parse(
        '$baseUrl/api/alerts/records/$alertId/',
      ),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'is_resolved': isResolved,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body)
          as Map<String, dynamic>;
    }

    throw Exception(
      'Failed to update alert: '
      '${response.statusCode} '
      '${response.body}',
    );
  }

  // ------------------------------------------------------------
  // Generate Weather Alert
  // ------------------------------------------------------------

  static Future<Map<String, dynamic>>
      generateWeatherAlert({
    required int solarSystemId,
  }) async {
    final response = await http.post(
      Uri.parse(
        '$baseUrl/api/alerts/weather-generate/',
      ),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'solar_system_id': solarSystemId,
      }),
    );

    if (response.statusCode == 200 ||
        response.statusCode == 201) {
      return jsonDecode(response.body)
          as Map<String, dynamic>;
    }

    throw Exception(
      'Failed to generate weather alert: '
      '${response.statusCode} '
      '${response.body}',
    );
  }

  // ------------------------------------------------------------
  // Generation Records
  // ------------------------------------------------------------

  static Future<List<dynamic>>
      getGenerationRecords() async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/api/solar/generation/',
      ),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    throw Exception(
      'Failed to load generation records: '
      '${response.statusCode}',
    );
  }

  // ------------------------------------------------------------
  // REAL ML WEATHER FORECAST
  //
  // Django gets:
  // latitude
  // longitude
  // system capacity
  //
  // directly from SolarSystem in the database.
  // ------------------------------------------------------------

  static Future<Map<String, dynamic>>
      getMLWeatherForecast() async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/api/forecasting/weather-predict/',
      ),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body)
          as Map<String, dynamic>;
    }

    throw Exception(
      'Failed to load ML forecast: '
      '${response.statusCode} '
      '${response.body}',
    );
  }

  // ------------------------------------------------------------
  // Weather Records
  // ------------------------------------------------------------

  static Future<List<dynamic>>
      getWeatherRecords() async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/api/weather/records/',
      ),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    throw Exception(
      'Failed to load weather records: '
      '${response.statusCode}',
    );
  }
}