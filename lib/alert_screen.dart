import 'package:flutter/material.dart';
import 'api_service.dart';

class AlertScreen extends StatefulWidget {
  const AlertScreen({super.key});

  @override
  State<AlertScreen> createState() => _AlertScreenState();
}

class _AlertScreenState extends State<AlertScreen> {
  List<dynamic> alerts = [];

  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadAlerts();
  }

  // =====================================================
  // Load Alerts + Check Weather Alert
  // =====================================================

  Future<void> loadAlerts() async {
    if (mounted) {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });
    }

    // --------------------------------------------------
    // 1. Check weather conditions
    // --------------------------------------------------

    try {
      final systems = await ApiService.getSolarSystems();

      if (systems.isNotEmpty) {
        final systemId =
            int.tryParse(systems[0]['id'].toString());

        if (systemId != null) {
          await ApiService.generateWeatherAlert(
            solarSystemId: systemId,
          );
        }
      }
    } catch (_) {
      // Weather API failure should not prevent
      // existing alerts from being displayed.
    }

    // --------------------------------------------------
    // 2. Load alerts from Django
    // --------------------------------------------------

    try {
      final data = await ApiService.getAlerts();

      if (!mounted) return;

      setState(() {
        alerts = data;
        isLoading = false;
        errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = 'Unable to load alerts.';
      });
    }
  }

  // =====================================================
  // Resolve Alert
  // =====================================================

  Future<void> resolveAlert(
    int alertId,
  ) async {
    try {
      await ApiService.resolveAlert(
        alertId: alertId,
        isResolved: true,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Alert marked as resolved.',
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      // Reload alerts after resolving.
      await loadAlerts();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Failed to resolve alert.',
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // =====================================================
  // Alert Counts
  // =====================================================

  int get unresolvedCount {
    return alerts.where((alert) {
      return alert['is_resolved'] == false;
    }).length;
  }

  int get infoCount {
    return alerts.where((alert) {
      return alert['severity']
              ?.toString()
              .toLowerCase() ==
          'info';
    }).length;
  }

  int get warningCount {
    return alerts.where((alert) {
      return alert['severity']
              ?.toString()
              .toLowerCase() ==
          'warning';
    }).length;
  }

  int get criticalCount {
    return alerts.where((alert) {
      return alert['severity']
              ?.toString()
              .toLowerCase() ==
          'critical';
    }).length;
  }

  // =====================================================
  // Build
  // =====================================================

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
              Icons.notifications_outlined,
              color: Colors.orange,
            ),

            SizedBox(width: 10),

            Text(
              'Alerts',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),

      body: RefreshIndicator(
        onRefresh: loadAlerts,

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

                : alerts.isEmpty
                    ? ListView(
                        children: const [
                          SizedBox(height: 180),

                          Center(
                            child: Text(
                              'No alerts found.',
                              style: TextStyle(
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      )

                    : ListView(
                        padding:
                            const EdgeInsets.all(16),

                        children: [

                          // --------------------------------------------------
                          // Page Title
                          // --------------------------------------------------

                          const Text(
                            'System Alerts',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 6),

                          Text(
                            'Important notifications about your solar system',
                            style: TextStyle(
                              color:
                                  Colors.grey.shade600,
                              fontSize: 15,
                            ),
                          ),

                          const SizedBox(height: 20),

                          // --------------------------------------------------
                          // Summary
                          // --------------------------------------------------

                          Row(
                            children: [
                              Expanded(
                                child:
                                    _AlertSummaryCard(
                                  icon:
                                      Icons.notifications,
                                  title:
                                      'Total',
                                  value:
                                      alerts.length
                                          .toString(),
                                ),
                              ),

                              const SizedBox(
                                width: 12,
                              ),

                              Expanded(
                                child:
                                    _AlertSummaryCard(
                                  icon:
                                      Icons.warning_amber,
                                  title:
                                      'Active',
                                  value:
                                      unresolvedCount
                                          .toString(),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          Row(
                            children: [
                              Expanded(
                                child:
                                    _AlertSummaryCard(
                                  icon:
                                      Icons.info_outline,
                                  title:
                                      'Info',
                                  value:
                                      infoCount
                                          .toString(),
                                ),
                              ),

                              const SizedBox(
                                width: 12,
                              ),

                              Expanded(
                                child:
                                    _AlertSummaryCard(
                                  icon:
                                      Icons.warning_outlined,
                                  title:
                                      'Warnings',
                                  value:
                                      warningCount
                                          .toString(),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // --------------------------------------------------
                          // Recent Alerts
                          // --------------------------------------------------

                          const Text(
                            'Recent Alerts',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 12),

                          ...alerts.map(
                            (alert) =>
                                _buildAlertCard(
                              alert,
                            ),
                          ),

                          const SizedBox(height: 20),
                        ],
                      ),
      ),
    );
  }

  // =====================================================
  // Alert Card
  // =====================================================

  Widget _buildAlertCard(dynamic alert) {
    final type =
        alert['alert_type']?.toString() ??
            'System';

    final severity =
        alert['severity']?.toString() ??
            'Info';

    final title =
        alert['title']?.toString() ??
            'Alert';

    final message =
        alert['message']?.toString() ??
            '';

    final date =
        alert['alert_date']?.toString() ??
            '--';

    final isResolved =
        alert['is_resolved'] == true;

    final colors =
        _getSeverityColors(severity);

    final alertId =
        int.tryParse(
      alert['id']?.toString() ?? '',
    );

    return Container(
      margin: const EdgeInsets.only(
        bottom: 12,
      ),

      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(18),

        border: Border.all(
          color: colors['border']!,
        ),
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [

          // --------------------------------------------------
          // Top Row
          // --------------------------------------------------

          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [
              Container(
                padding:
                    const EdgeInsets.all(12),

                decoration:
                    BoxDecoration(
                  color:
                      colors['background'],
                  shape: BoxShape.circle,
                ),

                child: Icon(
                  _getAlertIcon(type),
                  color: colors['icon'],
                  size: 26,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [
                    Text(
                      title,
                      style:
                          const TextStyle(
                        fontSize: 17,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      type,
                      style: TextStyle(
                        color:
                            Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),

              // --------------------------------------------------
              // Severity
              // --------------------------------------------------

              Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),

                decoration:
                    BoxDecoration(
                  color:
                      colors['background'],
                  borderRadius:
                      BorderRadius.circular(20),
                ),

                child: Text(
                  severity,
                  style: TextStyle(
                    color: colors['icon'],
                    fontSize: 12,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // --------------------------------------------------
          // Message
          // --------------------------------------------------

          Text(
            message,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 14,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 14),

          const Divider(),

          const SizedBox(height: 8),

          // --------------------------------------------------
          // Status Row
          // --------------------------------------------------

          Row(
            children: [

              Icon(
                Icons.schedule_outlined,
                size: 18,
                color: Colors.grey.shade600,
              ),

              const SizedBox(width: 6),

              Expanded(
                child: Text(
                  date,
                  style: TextStyle(
                    color:
                        Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ),

              // ------------------------------------------------
              // Resolved
              // ------------------------------------------------

              if (isResolved) ...[
                const Icon(
                  Icons.check_circle,
                  size: 18,
                  color: Colors.green,
                ),

                const SizedBox(width: 5),

                const Text(
                  'Resolved',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight:
                        FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ]

              // ------------------------------------------------
              // Active + Resolve Button
              // ------------------------------------------------

              else ...[
                const Icon(
                  Icons.pending_outlined,
                  size: 18,
                  color: Colors.orange,
                ),

                const SizedBox(width: 5),

                const Text(
                  'Active',
                  style: TextStyle(
                    color: Colors.orange,
                    fontWeight:
                        FontWeight.w600,
                    fontSize: 12,
                  ),
                ),

                const SizedBox(width: 10),

                if (alertId != null)
                  TextButton(
                    onPressed: () {
                      resolveAlert(alertId);
                    },

                    style:
                        TextButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      minimumSize:
                          Size.zero,
                      tapTargetSize:
                          MaterialTapTargetSize
                              .shrinkWrap,
                    ),

                    child: const Text(
                      'Resolve',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight:
                            FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // =====================================================
  // Severity Colors
  // =====================================================

  Map<String, dynamic> _getSeverityColors(
    String severity,
  ) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return {
          'background':
              Colors.red.shade50,
          'icon':
              Colors.red.shade700,
          'border':
              Colors.red.shade100,
        };

      case 'warning':
        return {
          'background':
              Colors.orange.shade50,
          'icon':
              Colors.orange.shade700,
          'border':
              Colors.orange.shade100,
        };

      case 'info':
      default:
        return {
          'background':
              Colors.blue.shade50,
          'icon':
              Colors.blue.shade700,
          'border':
              Colors.blue.shade100,
        };
    }
  }

  // =====================================================
  // Alert Icons
  // =====================================================

  IconData _getAlertIcon(String type) {
    switch (type.toLowerCase()) {
      case 'performance':
        return Icons.speed;

      case 'weather':
        return Icons.cloud_outlined;

      case 'generation':
        return Icons.bolt;

      case 'forecast':
        return Icons.auto_graph;

      case 'system':
        return Icons.settings;

      default:
        return Icons.notifications_outlined;
    }
  }
}

// =====================================================
// Alert Summary Card
// =====================================================

class _AlertSummaryCard
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _AlertSummaryCard({
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

          const SizedBox(height: 12),

          Text(
            title,
            style: TextStyle(
              color:
                  Colors.grey.shade600,
              fontSize: 14,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            value,
            style:
                const TextStyle(
              fontSize: 22,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}