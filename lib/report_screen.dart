import 'package:flutter/material.dart';

import 'api_service.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  bool isLoading = true;

  List<dynamic> generationRecords = [];
  List<dynamic> forecastRecords = [];
  List<dynamic> performanceRecords = [];

  Map<String, dynamic>? solarSystem;

  @override
  void initState() {
    super.initState();
    loadReportData();
  }

  // =====================================================
  // LOAD REPORT DATA
  // =====================================================

  Future<void> loadReportData() async {
    try {
      final generation =
          await ApiService.getGenerationRecords();

      final forecasts =
          await ApiService.getForecasts();

      final performance =
          await ApiService.getPerformance();

      final systems =
          await ApiService.getSolarSystems();

      if (!mounted) return;

      setState(() {
        generationRecords = generation;
        forecastRecords = forecasts;
        performanceRecords = performance;

        if (systems.isNotEmpty) {
          solarSystem =
              Map<String, dynamic>.from(
            systems[0],
          );
        }

        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to load report data: $e',
          ),
        ),
      );
    }
  }

  // =====================================================
  // NUMBER HELPER
  // =====================================================

  double _number(dynamic value) {
    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        0.0;
  }

  // =====================================================
  // ELECTRICITY RATE
  // =====================================================

  double get electricityRate {
    final value =
        solarSystem?['electricity_rate'];

    return double.tryParse(
          value?.toString() ?? '',
        ) ??
        0.0;
  }

  // =====================================================
  // TOTAL GENERATION
  // =====================================================

  double get totalGeneration {
    double total = 0;

    for (final record in generationRecords) {
      total += _number(
        record['energy_generated_kwh'],
      );
    }

    return total;
  }

  // =====================================================
  // LATEST FORECAST RECORDS
  // =====================================================

  List<dynamic> get latestForecastRecords {
    if (forecastRecords.isEmpty) {
      return [];
    }

    final sortedRecords =
        List<dynamic>.from(
      forecastRecords,
    );

    // Sort newest forecast date first.
    sortedRecords.sort(
      (a, b) {
        final dateA =
            DateTime.tryParse(
                  a['forecast_date']
                          ?.toString() ??
                      '',
                ) ??
                DateTime(1900);

        final dateB =
            DateTime.tryParse(
                  b['forecast_date']
                          ?.toString() ??
                      '',
                ) ??
                DateTime(1900);

        return dateB.compareTo(dateA);
      },
    );

    // Current backend generates a 3-day forecast.
    final selected =
        sortedRecords.take(3).toList();

    // Display in chronological order.
    selected.sort(
      (a, b) {
        final dateA =
            DateTime.tryParse(
                  a['forecast_date']
                          ?.toString() ??
                      '',
                ) ??
                DateTime(1900);

        final dateB =
            DateTime.tryParse(
                  b['forecast_date']
                          ?.toString() ??
                      '',
                ) ??
                DateTime(1900);

        return dateA.compareTo(dateB);
      },
    );

    return selected;
  }

  // =====================================================
  // LATEST PREDICTED GENERATION
  // =====================================================

  double get latestPredictedGeneration {
    double total = 0;

    for (final record in latestForecastRecords) {
      total += _number(
        record['predicted_generation_kwh'],
      );
    }

    return total;
  }

  // =====================================================
  // LATEST FORECAST COUNT
  // =====================================================

  int get latestForecastCount {
    return latestForecastRecords.length;
  }

  // =====================================================
  // LATEST FORECAST DATE RANGE
  // =====================================================

  String get latestForecastDateRange {
    final records =
        latestForecastRecords;

    if (records.isEmpty) {
      return 'No forecast data';
    }

    final firstDate =
        records.first['forecast_date']
            ?.toString();

    final lastDate =
        records.last['forecast_date']
            ?.toString();

    if (firstDate == null ||
        lastDate == null) {
      return 'Latest forecast period';
    }

    if (firstDate == lastDate) {
      return firstDate;
    }

    return '$firstDate to $lastDate';
  }

  // =====================================================
  // TOTAL SAVINGS
  // =====================================================

  double get totalSavings {
    return totalGeneration *
        electricityRate;
  }

  // =====================================================
  // LATEST COMPLETED PERFORMANCE RECORD
  //
  // IMPORTANT:
  // Pending records are ignored.
  //
  // Example:
  //
  // 2026-09-29 -> Pending -> 0.00%
  // 2026-09-28 -> Poor    -> 45.26%
  //
  // The completed 2026-09-28 record is selected.
  // =====================================================

  Map<String, dynamic>?
      get latestPerformanceRecord {
    if (performanceRecords.isEmpty) {
      return null;
    }

    final records =
        <Map<String, dynamic>>[];

    for (final record
        in performanceRecords) {
      if (record is Map) {
        final item =
            Map<String, dynamic>.from(
          record,
        );

        final status =
            item['status']
                ?.toString()
                .trim()
                .toLowerCase();

        // Ignore incomplete/current-day
        // performance records.
        if (status == 'pending') {
          continue;
        }

        records.add(item);
      }
    }

    if (records.isEmpty) {
      return null;
    }

    // Sort latest completed record first.
    records.sort(
      (a, b) {
        // ---------------------------------------------
        // First compare evaluation date
        // ---------------------------------------------

        final dateA =
            DateTime.tryParse(
                  a['evaluation_date']
                          ?.toString() ??
                      '',
                ) ??
                DateTime(1900);

        final dateB =
            DateTime.tryParse(
                  b['evaluation_date']
                          ?.toString() ??
                      '',
                ) ??
                DateTime(1900);

        final dateComparison =
            dateB.compareTo(dateA);

        if (dateComparison != 0) {
          return dateComparison;
        }

        // ---------------------------------------------
        // If dates are equal, compare created_at
        // ---------------------------------------------

        final createdA =
            DateTime.tryParse(
                  a['created_at']
                          ?.toString() ??
                      '',
                ) ??
                DateTime(1900);

        final createdB =
            DateTime.tryParse(
                  b['created_at']
                          ?.toString() ??
                      '',
                ) ??
                DateTime(1900);

        return createdB.compareTo(
          createdA,
        );
      },
    );

    return records.first;
  }

  // =====================================================
  // LATEST PERFORMANCE VALUE
  // =====================================================

  double get latestPerformance {
    final record =
        latestPerformanceRecord;

    if (record == null) {
      return 0;
    }

    return _number(
      record['performance_percentage'],
    );
  }

  // =====================================================
  // LATEST PERFORMANCE DATE
  // =====================================================

  String get latestPerformanceDate {
    final record =
        latestPerformanceRecord;

    if (record == null) {
      return 'No completed performance data';
    }

    final date =
        record['evaluation_date']
            ?.toString();

    if (date == null ||
        date.isEmpty) {
      return 'Latest completed performance';
    }

    return date;
  }

  // =====================================================
  // LATEST PERFORMANCE STATUS
  // =====================================================

  String get latestPerformanceStatus {
    final record =
        latestPerformanceRecord;

    if (record == null) {
      return 'No status';
    }

    final status =
        record['status']?.toString();

    if (status == null ||
        status.isEmpty) {
      return 'Completed';
    }

    return status;
  }

  // =====================================================
  // BUILD
  // =====================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF5F7FA),

      // =================================================
      // APP BAR
      // =================================================

      appBar: AppBar(
        title: const Text(
          'Solar Report',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),

        backgroundColor:
            Colors.white,

        foregroundColor:
            Colors.black,

        elevation: 0,

        actions: [
          IconButton(
            onPressed:
                isLoading
                    ? null
                    : loadReportData,

            icon:
                const Icon(
              Icons.refresh,
            ),
          ),
        ],
      ),

      // =================================================
      // BODY
      // =================================================

      body: isLoading
          ? const Center(
              child:
                  CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh:
                  loadReportData,

              child:
                  SingleChildScrollView(
                physics:
                    const AlwaysScrollableScrollPhysics(),

                padding:
                    const EdgeInsets.all(16),

                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [

                    // ===================================
                    // REPORT TITLE
                    // ===================================

                    const Text(
                      'Solar Performance Report',

                      style:
                          TextStyle(
                        fontSize: 22,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(
                      height: 6,
                    ),

                    Text(
                      'Overview of your solar generation, forecast, performance and savings.',

                      style:
                          TextStyle(
                        color:
                            Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),

                    const SizedBox(
                      height: 20,
                    ),

                    // ===================================
                    // TOTAL GENERATION
                    // ===================================

                    _buildReportCard(
                      icon:
                          Icons.bolt,

                      title:
                          'Total Generation',

                      value:
                          '${totalGeneration.toStringAsFixed(2)} kWh',

                      subtitle:
                          '${generationRecords.length} generation records',
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    // ===================================
                    // LATEST FORECAST
                    // ===================================

                    _buildReportCard(
                      icon:
                          Icons.auto_graph,

                      title:
                          'Latest Forecast',

                      value:
                          '${latestPredictedGeneration.toStringAsFixed(2)} kWh',

                      subtitle:
                          latestForecastRecords.isEmpty
                              ? 'No forecast records'
                              : '$latestForecastCount forecast records • $latestForecastDateRange',
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    // ===================================
                    // ESTIMATED SAVINGS
                    // ===================================

                    _buildReportCard(
                      icon:
                          Icons.currency_rupee,

                      title:
                          'Estimated Savings',

                      value:
                          '₹${totalSavings.toStringAsFixed(2)}',

                      subtitle:
                          'Based on ₹${electricityRate.toStringAsFixed(2)} per kWh',
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    // ===================================
                    // LATEST COMPLETED PERFORMANCE
                    // ===================================

                    _buildReportCard(
                      icon:
                          Icons.analytics,

                      title:
                          'Latest Performance',

                      value:
                          '${latestPerformance.toStringAsFixed(2)}%',

                      subtitle:
                          latestPerformanceRecord ==
                                  null
                              ? 'No completed performance data'
                              : '$latestPerformanceStatus • $latestPerformanceDate',
                    ),

                    const SizedBox(
                      height: 24,
                    ),

                    // ===================================
                    // REPORT SUMMARY
                    // ===================================

                    const Text(
                      'Report Summary',

                      style:
                          TextStyle(
                        fontSize: 18,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    Container(
                      width:
                          double.infinity,

                      padding:
                          const EdgeInsets.all(18),

                      decoration:
                          BoxDecoration(
                        color:
                            Colors.white,

                        borderRadius:
                            BorderRadius.circular(
                          16,
                        ),

                        border:
                            Border.all(
                          color:
                              Colors.grey.shade200,
                        ),
                      ),

                      child:
                          Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,

                        children: [

                          _summaryRow(
                            'Generation Records',

                            generationRecords
                                .length
                                .toString(),
                          ),

                          _summaryRow(
                            'Latest Forecast Records',

                            latestForecastCount
                                .toString(),
                          ),

                          _summaryRow(
                            'Performance Records',

                            performanceRecords
                                .length
                                .toString(),
                          ),

                          _summaryRow(
                            'Electricity Rate',

                            '₹${electricityRate.toStringAsFixed(2)} / kWh',
                          ),

                          _summaryRow(
                            'Latest Forecast',

                            '${latestPredictedGeneration.toStringAsFixed(2)} kWh',
                          ),

                          _summaryRow(
                            'Latest Performance',

                            '${latestPerformance.toStringAsFixed(2)}%',
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(
                      height: 20,
                    ),

                    // ===================================
                    // INFORMATION
                    // ===================================

                    Container(
                      width:
                          double.infinity,

                      padding:
                          const EdgeInsets.all(16),

                      decoration:
                          BoxDecoration(
                        color:
                            Colors.orange.shade50,

                        borderRadius:
                            BorderRadius.circular(
                          16,
                        ),
                      ),

                      child:
                          Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,

                        children: [

                          const Icon(
                            Icons.info_outline,

                            color:
                                Colors.orange,
                          ),

                          const SizedBox(
                            width: 12,
                          ),

                          Expanded(
                            child:
                                Text(
                              'Savings are estimated using the total recorded generated energy and the configured electricity rate. The forecast value represents the latest available forecast period. Performance uses the latest completed solar-day evaluation.',

                              style:
                                  const TextStyle(
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  // =====================================================
  // REPORT CARD
  // =====================================================

  Widget _buildReportCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Container(
      width:
          double.infinity,

      padding:
          const EdgeInsets.all(18),

      decoration:
          BoxDecoration(
        color:
            Colors.white,

        borderRadius:
            BorderRadius.circular(
          16,
        ),

        border:
            Border.all(
          color:
              Colors.grey.shade200,
        ),

        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(
              alpha: 0.03,
            ),

            blurRadius: 8,

            offset:
                const Offset(
              0,
              3,
            ),
          ),
        ],
      ),

      child:
          Row(
        children: [

          // =============================================
          // ICON
          // =============================================

          Container(
            width: 50,
            height: 50,

            decoration:
                BoxDecoration(
              color:
                  Colors.orange.shade50,

              shape:
                  BoxShape.circle,
            ),

            child:
                Icon(
              icon,
              color:
                  Colors.orange,
            ),
          ),

          const SizedBox(
            width: 14,
          ),

          // =============================================
          // TEXT
          // =============================================

          Expanded(
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [

                Text(
                  title,

                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.w600,
                    fontSize: 14,
                  ),
                ),

                const SizedBox(
                  height: 4,
                ),

                Text(
                  value,

                  style:
                      const TextStyle(
                    fontSize: 21,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height: 2,
                ),

                Text(
                  subtitle,

                  style:
                      TextStyle(
                    fontSize: 12,
                    color:
                        Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // SUMMARY ROW
  // =====================================================

  Widget _summaryRow(
    String title,
    String value,
  ) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 8,
      ),

      child:
          Row(
        mainAxisAlignment:
            MainAxisAlignment.spaceBetween,

        children: [

          Expanded(
            child:
                Text(
              title,

              style:
                  TextStyle(
                color:
                    Colors.grey.shade700,
              ),
            ),
          ),

          const SizedBox(
            width: 12,
          ),

          Text(
            value,

            textAlign:
                TextAlign.end,

            style:
                const TextStyle(
              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}