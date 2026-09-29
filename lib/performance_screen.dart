import 'package:flutter/material.dart';
import 'api_service.dart';

class PerformanceScreen extends StatefulWidget {
  const PerformanceScreen({super.key});

  @override
  State<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends State<PerformanceScreen> {
  List<dynamic> performanceRecords = [];

  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadPerformance();
  }

  Future<void> loadPerformance() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final data = await ApiService.getPerformance();

      if (!mounted) return;

      setState(() {
        performanceRecords = data;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = 'Unable to load performance data.';
      });
    }
  }

  double _toDouble(dynamic value) {
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

 

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'excellent':
        return Colors.green;

      case 'good':
        return Colors.blue;

      case 'normal':
        return Colors.orange;

      case 'poor':
        return Colors.red;

      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'excellent':
        return Icons.check_circle;

      case 'good':
        return Icons.thumb_up;

      case 'normal':
        return Icons.info;

      case 'poor':
        return Icons.warning;

      default:
        return Icons.help;
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
              Icons.analytics,
              color: Colors.orange,
            ),
            SizedBox(width: 10),
            Text(
              'Performance',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),

        actions: [
          IconButton(
            onPressed: loadPerformance,
            icon: const Icon(
              Icons.refresh,
              color: Colors.orange,
            ),
          ),
        ],
      ),

      body: RefreshIndicator(
        onRefresh: loadPerformance,

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
                        child: Column(
                          children: [
                            const Icon(
                              Icons.analytics_outlined,
                              size: 55,
                              color: Colors.grey,
                            ),

                            const SizedBox(height: 15),

                            Text(
                              errorMessage!,
                              style: const TextStyle(
                                fontSize: 16,
                              ),
                            ),

                            const SizedBox(height: 15),

                            ElevatedButton(
                              onPressed: loadPerformance,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : performanceRecords.isEmpty
                    ? ListView(
                        children: const [
                          SizedBox(height: 180),

                          Center(
                            child: Text(
                              'No performance records found.',
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
                            'Solar Performance',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 6),

                          Text(
                            'Compare predicted and actual solar generation',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 15,
                            ),
                          ),

                          const SizedBox(height: 20),

                          _buildMainPerformanceCard(
                            performanceRecords.first,
                          ),

                          const SizedBox(height: 24),

                          const Text(
                            'Performance Details',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 12),

                          _buildPerformanceDetails(
                            performanceRecords.first,
                          ),

                          const SizedBox(height: 24),

                          const Text(
                            'Performance History',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 12),

                          ...performanceRecords.map(
                            (record) =>
                                _buildHistoryCard(record),
                          ),

                          const SizedBox(height: 20),
                        ],
                      ),
      ),
    );
  }

  Widget _buildMainPerformanceCard(
    dynamic record,
  ) {
    final performance =
        _toDouble(
          record['performance_percentage'],
        );

    final status =
        record['status']?.toString() ?? 'Unknown';

    final color = _statusColor(status);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),

      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFB300),
            Color(0xFFFF8F00),
          ],
        ),

        borderRadius: BorderRadius.circular(22),

        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(
              alpha: 0.25,
            ),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          const Row(
            children: [
              Icon(
                Icons.speed,
                color: Colors.white,
                size: 30,
              ),

              SizedBox(width: 10),

              Text(
                'System Performance',
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
            '${performance.toStringAsFixed(2)}%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 40,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'Overall generation performance',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 15,
            ),
          ),

          const SizedBox(height: 18),

          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),

            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),

            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _statusIcon(status),
                  color: color,
                  size: 20,
                ),

                const SizedBox(width: 7),

                Text(
                  status,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceDetails(
    dynamic record,
  ) {
    final actual =
        _toDouble(
          record['actual_generation_kwh'],
        );

    final predicted =
        _toDouble(
          record['predicted_generation_kwh'],
        );

    final deviation =
        _toDouble(
          record['deviation_kwh'],
        );

    final date =
        record['evaluation_date']?.toString() ?? '--';

    return Column(
      children: [
        _buildDetailCard(
          Icons.bolt,
          'Actual Generation',
          '${actual.toStringAsFixed(2)} kWh',
        ),

        _buildDetailCard(
          Icons.auto_graph,
          'Predicted Generation',
          '${predicted.toStringAsFixed(2)} kWh',
        ),

        _buildDetailCard(
          Icons.compare_arrows,
          'Deviation',
          '${deviation.toStringAsFixed(2)} kWh',
        ),

        _buildDetailCard(
          Icons.calendar_today,
          'Evaluation Date',
          date,
        ),
      ],
    );
  }

  Widget _buildDetailCard(
    IconData icon,
    String title,
    String value,
  ) {
    return Container(
      margin: const EdgeInsets.only(
        bottom: 10,
      ),

      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),

      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(11),

            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              shape: BoxShape.circle,
            ),

            child: Icon(
              icon,
              color: Colors.orange,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 15,
              ),
            ),
          ),

          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(
    dynamic record,
  ) {
    final date =
        record['evaluation_date']?.toString() ?? '--';

    final performance =
        _toDouble(
          record['performance_percentage'],
        );

    final status =
        record['status']?.toString() ?? 'Unknown';

    final color = _statusColor(status);

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
            padding: const EdgeInsets.all(11),

            decoration: BoxDecoration(
              color: color.withValues(
                alpha: 0.10,
              ),
              shape: BoxShape.circle,
            ),

            child: Icon(
              _statusIcon(status),
              color: color,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                Text(
                  date,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  status,
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          Text(
            '${performance.toStringAsFixed(2)}%',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 17,
            ),
          ),
        ],
      ),
    );
  }
}