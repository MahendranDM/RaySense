import 'package:flutter/foundation.dart';

import 'dart:io';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'auth_service.dart';

class ApiService {
 
static String get baseUrl {
  if (kIsWeb) {
    return 'http://127.0.0.1:8000';
  }

  if (Platform.isAndroid) {
    return 'http://127.0.0.1:8000';
  }

  return 'http://127.0.0.1:8000';
}

 // ------------------------------------------------------------
  // AUTHENTICATION
  // ------------------------------------------------------------

  static Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/users/login/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      final token = data['token'];

      if (token != null) {
        await AuthService.saveToken(token);
      }

      return data as Map<String, dynamic>;
    }

    throw Exception(data['detail'] ?? 'Login failed: ${response.statusCode}');
  }

  // ------------------------------------------------------------
  // REGISTRATION
  // ------------------------------------------------------------

  static Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    required String password2,
    required String systemName,
    required String location,
    required double latitude,
    required double longitude,
    required double capacityKw,
    required int panelCount,
    required String panelType,
    required String installationDate,
    String provider = '',
    String consumerCategory = '',
    String? billFilePath,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/users/register/'),
    );

    // Account information
    request.fields['username'] = username;
    request.fields['email'] = email;
    request.fields['password'] = password;
    request.fields['password2'] = password2;

    // Solar system information
    request.fields['system_name'] = systemName;
    request.fields['location'] = location;
    request.fields['latitude'] = latitude.toString();
    request.fields['longitude'] = longitude.toString();
    request.fields['capacity_kw'] = capacityKw.toString();
    request.fields['panel_count'] = panelCount.toString();
    request.fields['panel_type'] = panelType;
    request.fields['installation_date'] = installationDate;

    // Electricity information
    request.fields['provider'] = provider;
    request.fields['consumer_category'] = consumerCategory;

    // Optional electricity bill
    if (billFilePath != null && billFilePath.isNotEmpty) {
      request.files.add(
        await http.MultipartFile.fromPath('bill_file', billFilePath),
      );
    }

    final streamedResponse = await request.send();

    final response = await http.Response.fromStream(streamedResponse);

    final data = jsonDecode(response.body);

    if (response.statusCode == 201) {
      return data as Map<String, dynamic>;
    }

    if (data is Map<String, dynamic>) {
      if (data['detail'] != null) {
        throw Exception(data['detail'].toString());
      }

      throw Exception(
        data.entries.map((entry) => '${entry.key}: ${entry.value}').join('\n'),
      );
    }

    throw Exception(
      'Registration failed: '
      '${response.statusCode}',
    );
  }

  // ------------------------------------------------------------
  // CURRENT USER
  // ------------------------------------------------------------

  static Future<Map<String, dynamic>> getMe() async {
    final token = await AuthService.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('User is not logged in.');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/api/users/me/'),
      headers: {'Authorization': 'Token $token'},
    );

    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return data as Map<String, dynamic>;
    }

    if (response.statusCode == 401) {
      await AuthService.clearToken();
    }

    throw Exception(data['detail'] ?? 'Failed to load user profile.');
  }

  // ------------------------------------------------------------
  // LOGOUT
  // ------------------------------------------------------------

  static Future<void> logout() async {
    final token = await AuthService.getToken();

    if (token == null || token.isEmpty) {
      return;
    }

    final response = await http.post(
      Uri.parse('$baseUrl/api/users/logout/'),
      headers: {'Authorization': 'Token $token'},
    );

    await AuthService.clearToken();

    if (response.statusCode != 200) {
      throw Exception('Logout failed: ${response.statusCode} ${response.body}');
    }
  }

  // ------------------------------------------------------------
  // CHECK LOGIN STATUS
  // ------------------------------------------------------------

  static Future<bool> isLoggedIn() async {
    return await AuthService.isLoggedIn();
  }

  // ------------------------------------------------------------
  // SOLAR SYSTEMS
  // ------------------------------------------------------------

  static Future<List<dynamic>> getSolarSystems() async {
    final token = await AuthService.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Authentication token not found.');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/api/solar/systems/'),
      headers: {'Authorization': 'Token $token'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    if (response.statusCode == 401) {
      await AuthService.clearToken();

      throw Exception('Authentication failed. Please login again.');
    }

    throw Exception(
      'Failed to load solar systems: '
      '${response.statusCode} '
      '${response.body}',
    );
  }

  // ------------------------------------------------------------
  // UPDATE SOLAR SYSTEM
  // ------------------------------------------------------------

  static Future<Map<String, dynamic>> updateSolarSystem({
    required int systemId,
    required String systemName,
    required String location,
    required double capacityKw,
    required double electricityRate,
    required int panelCount,
    required String panelType,
    String? installationDate,
  }) async {
    final token = await AuthService.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Authentication token not found.');
    }

    final response = await http.patch(
      Uri.parse('$baseUrl/api/solar/systems/$systemId/'),
      headers: {
        'Authorization': 'Token $token',
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
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    if (response.statusCode == 401) {
      await AuthService.clearToken();

      throw Exception('Authentication failed. Please login again.');
    }

    throw Exception(
      'Failed to update solar system: '
      '${response.statusCode} '
      '${response.body}',
    );
  }

  // ------------------------------------------------------------
  // FORECAST RECORDS
  // ------------------------------------------------------------

  static Future<List<dynamic>> getForecasts() async {
    final token = await AuthService.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Authentication token not found.');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/api/forecasting/records/'),
      headers: {'Authorization': 'Token $token'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    if (response.statusCode == 401) {
      await AuthService.clearToken();

      throw Exception('Authentication failed. Please login again.');
    }

    throw Exception(
      'Failed to load forecasts: '
      '${response.statusCode} '
      '${response.body}',
    );
  }

  // ------------------------------------------------------------
  // PERFORMANCE RECORDS
  // ------------------------------------------------------------

  static Future<List<dynamic>> getPerformance() async {
    final token = await AuthService.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Authentication token not found.');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/api/performance/records/'),
      headers: {'Authorization': 'Token $token'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    if (response.statusCode == 401) {
      await AuthService.clearToken();

      throw Exception('Authentication failed. Please login again.');
    }

    throw Exception(
      'Failed to load performance records: '
      '${response.statusCode} '
      '${response.body}',
    );
  }

  // ------------------------------------------------------------
  // TODAY'S PERFORMANCE
  // ------------------------------------------------------------

  static Future<Map<String, dynamic>> getTodayPerformance() async {
    final token = await AuthService.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Authentication token not found.');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/api/performance/today/'),
      headers: {'Authorization': 'Token $token'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    if (response.statusCode == 401) {
      await AuthService.clearToken();

      throw Exception('Authentication failed. Please login again.');
    }

    throw Exception(
      'Failed to load today performance: '
      '${response.statusCode} '
      '${response.body}',
    );
  }

  // ------------------------------------------------------------
  // ALERTS
  // ------------------------------------------------------------

  static Future<List<dynamic>> getAlerts() async {
    final token = await AuthService.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Authentication token not found.');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/api/alerts/records/'),
      headers: {'Authorization': 'Token $token'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    if (response.statusCode == 401) {
      await AuthService.clearToken();

      throw Exception('Authentication failed. Please login again.');
    }

    throw Exception(
      'Failed to load alerts: '
      '${response.statusCode} '
      '${response.body}',
    );
  }

  // ------------------------------------------------------------
  // RESOLVE / UPDATE ALERT
  // ------------------------------------------------------------

  static Future<Map<String, dynamic>> resolveAlert({
    required int alertId,
    required bool isResolved,
  }) async {
    final token = await AuthService.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Authentication token not found.');
    }

    final response = await http.patch(
      Uri.parse('$baseUrl/api/alerts/records/$alertId/'),
      headers: {
        'Authorization': 'Token $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'is_resolved': isResolved}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    if (response.statusCode == 401) {
      await AuthService.clearToken();

      throw Exception('Authentication failed. Please login again.');
    }

    throw Exception(
      'Failed to update alert: '
      '${response.statusCode} '
      '${response.body}',
    );
  }

  // ------------------------------------------------------------
  // GENERATE WEATHER ALERT
  // ------------------------------------------------------------

  static Future<Map<String, dynamic>> generateWeatherAlert({
    required int solarSystemId,
  }) async {
    final token = await AuthService.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Authentication token not found.');
    }

    final response = await http.post(
      Uri.parse('$baseUrl/api/alerts/weather-generate/'),
      headers: {
        'Authorization': 'Token $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'solar_system_id': solarSystemId}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    if (response.statusCode == 401) {
      await AuthService.clearToken();

      throw Exception('Authentication failed. Please login again.');
    }

    throw Exception(
      'Failed to generate weather alert: '
      '${response.statusCode} '
      '${response.body}',
    );
  }

  // ------------------------------------------------------------
  // GENERATION RECORDS
  // ------------------------------------------------------------

  static Future<List<dynamic>> getGenerationRecords() async {
    final token = await AuthService.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Authentication token not found.');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/api/solar/generation/'),
      headers: {'Authorization': 'Token $token'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    if (response.statusCode == 401) {
      await AuthService.clearToken();

      throw Exception('Authentication failed. Please login again.');
    }

    throw Exception(
      'Failed to load generation records: '
      '${response.statusCode} '
      '${response.body}',
    );
  }

  // ------------------------------------------------------------
  // REAL ML WEATHER FORECAST
  // ------------------------------------------------------------

  static Future<Map<String, dynamic>> getMLWeatherForecast() async {
    final token = await AuthService.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Authentication token not found.');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/api/forecasting/weather-predict/'),
      headers: {'Authorization': 'Token $token'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    if (response.statusCode == 401) {
      await AuthService.clearToken();

      throw Exception('Authentication failed. Please login again.');
    }

    throw Exception(
      'Failed to load ML forecast: '
      '${response.statusCode} '
      '${response.body}',
    );
  }

  // ------------------------------------------------------------
  // WEATHER RECORDS
  // ------------------------------------------------------------

  static Future<List<dynamic>> getWeatherRecords() async {
    final token = await AuthService.getToken();

    if (token == null || token.isEmpty) {
      throw Exception('Authentication token not found.');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/api/weather/records/'),
      headers: {'Authorization': 'Token $token'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }

    if (response.statusCode == 401) {
      await AuthService.clearToken();

      throw Exception('Authentication failed. Please login again.');
    }

    throw Exception(
      'Failed to load weather records: '
      '${response.statusCode} '
      '${response.body}',
    );
  }
}
