import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'api_service.dart';

class GenerationScreen extends StatefulWidget {
  const GenerationScreen({super.key});

  @override
  State<GenerationScreen> createState() =>
      _GenerationScreenState();
}

class _GenerationScreenState
    extends State<GenerationScreen> {

  List<dynamic> generationRecords = [];

  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadGeneration();
  }

  Future<void> loadGeneration() async {
    try {
      final data =
          await ApiService.getGenerationRecords();

      if (!mounted) return;

      setState(() {
        generationRecords = data;
        isLoading = false;
        errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage =
            'Unable to load generation data.';
      });
    }
  }

  double get totalGeneration {
    double total = 0;

    for (final record in generationRecords) {
      total +=
          double.tryParse(
                record['energy_generated_kwh']
                    .toString(),
              ) ??
              0;
    }

    return total;
  }

  double get averageGeneration {
    if (generationRecords.isEmpty) {
      return 0;
    }

    return totalGeneration /
        generationRecords.length;
  }

  double get latestPower {
    if (generationRecords.isEmpty) {
      return 0;
    }

    return double.tryParse(
          generationRecords[0]['power_output_kw']
              .toString(),
        ) ??
        0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF5F7FA),

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,

        title: const Row(
          children: [
            Icon(
              Icons.bolt,
              color: Colors.orange,
            ),

            SizedBox(width: 10),

            Text(
              'Generation',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),

      body: RefreshIndicator(
        onRefresh: loadGeneration,

        child: isLoading
            ? const Center(
                child:
                    CircularProgressIndicator(
                  color: Colors.orange,
                ),
              )
            : errorMessage != null
                ? ListView(
                    children: [
                      const SizedBox(
                        height: 180,
                      ),
                      Center(
                        child: Text(
                          errorMessage!,
                          style:
                              const TextStyle(
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  )
                : generationRecords.isEmpty
                    ? ListView(
                        children: const [
                          SizedBox(
                            height: 180,
                          ),
                          Center(
                            child: Text(
                              'No generation records found.',
                              style:
                                  TextStyle(
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      )
                    : ListView(
                        padding:
                            const EdgeInsets.all(
                          16,
                        ),
                        children: [

                          // Title
                          const Text(
                            'Solar Generation',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),

                          const SizedBox(
                            height: 6,
                          ),

                          Text(
                            'Historical solar energy production',
                            style: TextStyle(
                              color: Colors
                                  .grey
                                  .shade600,
                              fontSize: 15,
                            ),
                          ),

                          const SizedBox(
                            height: 20,
                          ),

                          // Summary Cards
                          Row(
                            children: [
                              Expanded(
                                child:
                                    _SummaryCard(
                                  icon:
                                      Icons.bolt,
                                  title:
                                      'Total Energy',
                                  value:
                                      '${totalGeneration.toStringAsFixed(2)} kWh',
                                ),
                              ),

                              const SizedBox(
                                width: 12,
                              ),

                              Expanded(
                                child:
                                    _SummaryCard(
                                  icon:
                                      Icons.speed,
                                  title:
                                      'Latest Power',
                                  value:
                                      '${latestPower.toStringAsFixed(2)} kW',
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(
                            height: 12,
                          ),

                          _SummaryCard(
                            icon:
                                Icons
                                    .analytics_outlined,
                            title:
                                'Average Generation',
                            value:
                                '${averageGeneration.toStringAsFixed(2)} kWh',
                          ),

                          const SizedBox(
                            height: 24,
                          ),

                          // Chart title
                          const Text(
                            'Generation Trend',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),

                          const SizedBox(
                            height: 12,
                          ),

                          _buildChart(),

                          const SizedBox(
                            height: 24,
                          ),

                          // History
                          const Text(
                            'Generation History',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),

                          const SizedBox(
                            height: 12,
                          ),

                          ...generationRecords
                              .map(
                            (record) =>
                                _buildHistoryCard(
                              record,
                            ),
                          ),

                          const SizedBox(
                            height: 20,
                          ),
                        ],
                      ),
      ),
    );
  }

  Widget _buildChart() {
    final records =
        generationRecords.reversed.toList();

    final spots = <FlSpot>[];

    for (int i = 0;
        i < records.length;
        i++) {

      final value =
          double.tryParse(
                records[i]
                        ['energy_generated_kwh']
                    .toString(),
              ) ??
              0;

      spots.add(
        FlSpot(
          i.toDouble(),
          value,
        ),
      );
    }

    double maxY = 0;

    for (final spot in spots) {
      if (spot.y > maxY) {
        maxY = spot.y;
      }
    }

    if (maxY == 0) {
      maxY = 10;
    } else {
      maxY += 5;
    }

    return Container(
      height: 300,
      padding: const EdgeInsets.fromLTRB(
        12,
        20,
        20,
        12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY,

          gridData: FlGridData(
            show: true,
          ),

          borderData: FlBorderData(
            show: false,
          ),

          titlesData: FlTitlesData(
            rightTitles:
                const AxisTitles(
              sideTitles:
                  SideTitles(
                showTitles: false,
              ),
            ),

            topTitles:
                const AxisTitles(
              sideTitles:
                  SideTitles(
                showTitles: false,
              ),
            ),

            leftTitles:
                AxisTitles(
              sideTitles:
                  SideTitles(
                showTitles: true,
                reservedSize: 45,
              ),
            ),

            bottomTitles:
                AxisTitles(
              sideTitles:
                  SideTitles(
                showTitles: true,
                reservedSize: 30,

                getTitlesWidget:
                    (value, meta) {
                  final index =
                      value.toInt();

                  if (index < 0 ||
                      index >= records.length) {
                    return const SizedBox();
                  }

                  if (index % 4 != 0 &&
                      index !=
                          records.length - 1) {
                    return const SizedBox();
                  }

                  final date =
                      records[index]
                          ['recorded_at']
                          .toString();

                  final shortDate =
                      date.length >= 10
                          ? date.substring(
                              5,
                              10,
                            )
                          : date;

                  return Text(
                    shortDate,
                    style:
                        const TextStyle(
                      fontSize: 10,
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

              barWidth: 3,

              dotData: FlDotData(
                show: true,
              ),

              belowBarData:
                  BarAreaData(
                show: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryCard(
    dynamic record,
  ) {
    final date =
        record['recorded_at'] ?? '--';

    final generation =
        record['energy_generated_kwh'] ??
            '--';

    final power =
        record['power_output_kw'] ??
            '--';

    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 12,
      ),

      padding:
          const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(18),
      ),

      child: Row(
        children: [

          Container(
            padding:
                const EdgeInsets.all(12),

            decoration:
                BoxDecoration(
              color:
                  Colors.orange.shade50,
              shape:
                  BoxShape.circle,
            ),

            child: const Icon(
              Icons.bolt,
              color: Colors.orange,
            ),
          ),

          const SizedBox(
            width: 14,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                Text(
                  date.toString(),
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.bold,
                    fontSize: 15,
                  ),
                ),

                const SizedBox(
                  height: 5,
                ),

                Text(
                  'Power Output: $power kW',
                  style: TextStyle(
                    color: Colors
                        .grey
                        .shade600,
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
              Text(
                '$generation kWh',
                style:
                    const TextStyle(
                  fontWeight:
                      FontWeight.bold,
                  fontSize: 17,
                ),
              ),

              const SizedBox(
                height: 4,
              ),

              const Text(
                'Generated',
                style:
                    TextStyle(
                  fontSize: 12,
                  color:
                      Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


// =====================================================
// Summary Card
// =====================================================

class _SummaryCard
    extends StatelessWidget {

  final IconData icon;
  final String title;
  final String value;

  const _SummaryCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding:
          const EdgeInsets.all(18),

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

          const SizedBox(
            height: 12,
          ),

          Text(
            title,
            style: TextStyle(
              color:
                  Colors.grey.shade600,
              fontSize: 14,
            ),
          ),

          const SizedBox(
            height: 5,
          ),

          Text(
            value,
            style:
                const TextStyle(
              fontSize: 18,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}