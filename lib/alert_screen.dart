import 'package:flutter/material.dart';

import 'api_service.dart';

class AlertScreen extends StatefulWidget {
  const AlertScreen({super.key});

  @override
  State<AlertScreen> createState() => _AlertScreenState();
}

class _AlertScreenState extends State<AlertScreen> {
  // ============================================================
  // RAYSENSE WEBSITE COLORS
  // ============================================================

  static const Color pageBackground = Color(0xFFF8FAFC);
  static const Color cardColor = Color(0xFFFFFFFF);

  static const Color primaryText = Color(0xFF111827);
  static const Color secondaryText = Color(0xFF64748B);
  static const Color mutedText = Color(0xFF94A3B8);

  static const Color borderColor = Color(0xFFE5E7EB);
  static const Color goldColor = Color(0xFFF5B800);

  static const Color activeColor = Color(0xFFDC2626);
  static const Color resolvedColor = Color(0xFF15803D);

  // ============================================================
  // STATE
  // ============================================================

  List<dynamic> alerts = [];

  bool isLoading = true;
  bool isRefreshing = false;

  String? errorMessage;

  String selectedFilter = 'all';

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    loadAlerts();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ============================================================
  // SAFE FIELD HELPERS
  // ============================================================

  String _stringValue(dynamic value, [String fallback = '']) {
    if (value == null) return fallback;

    final result = value.toString().trim();

    if (result.isEmpty || result.toLowerCase() == 'null') {
      return fallback;
    }

    return result;
  }

  bool _isResolved(dynamic alert) {
    if (alert is! Map) return false;

    final value = alert['is_resolved'];

    if (value == true) return true;

    if (value is num) return value == 1;

    return value?.toString().toLowerCase() == 'true';
  }

  String _severity(dynamic alert) {
    if (alert is! Map) return 'Info';

    final value = _stringValue(alert['severity'], 'Info');

    switch (value.toLowerCase()) {
      case 'critical':
        return 'Critical';

      case 'warning':
        return 'Warning';

      case 'info':
        return 'Info';

      default:
        return value;
    }
  }

  // ============================================================
  // LOAD ALERTS FROM DJANGO
  // ============================================================

  Future<void> loadAlerts({bool showLoader = true}) async {
    if (!mounted) return;

    setState(() {
      if (showLoader) {
        isLoading = true;
      }

      isRefreshing = !showLoader;
      errorMessage = null;
    });

    try {
      // Keep the existing Django weather-alert integration.
      // A weather API failure must not block existing alerts.

      try {
        final systems = await ApiService.getSolarSystems();

        if (systems.isNotEmpty && systems.first is Map) {
          final firstSystem = systems.first as Map;

          final systemId = int.tryParse(
            firstSystem['id']?.toString() ?? '',
          );

          if (systemId != null) {
            await ApiService.generateWeatherAlert(
              solarSystemId: systemId,
            );
          }
        }
      } catch (_) {
        // Existing alerts should still load if weather generation fails.
      }

      // Fetch persisted alerts using the existing authenticated API.
      final result = await ApiService.getAlerts();

      if (!mounted) return;

      setState(() {
        alerts = result.where((item) => item is Map).toList();
        errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = _friendlyError(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
          isRefreshing = false;
        });
      }
    }
  }

  String _friendlyError(Object error) {
    final message = error.toString();

    if (message.toLowerCase().contains('authentication')) {
      return 'Your session may have expired. Please log in again.';
    }

    if (message.toLowerCase().contains('socketexception') ||
        message.toLowerCase().contains('failed host lookup') ||
        message.toLowerCase().contains('connection refused')) {
      return 'Unable to connect to the RaySense server. '
          'Check your connection and backend server.';
    }

    return 'Unable to load alerts. Please try again.';
  }

  // ============================================================
  // FILTERED ALERTS
  // ============================================================

  List<dynamic> get filteredAlerts {
    switch (selectedFilter) {
      case 'active':
        return alerts.where((alert) => !_isResolved(alert)).toList();

      case 'resolved':
        return alerts.where(_isResolved).toList();

      case 'all':
      default:
        return alerts;
    }
  }

  // ============================================================
  // SUMMARY COUNTS
  // ============================================================

  int get totalCount => alerts.length;

  int get activeCount =>
      alerts.where((alert) => !_isResolved(alert)).length;

  int get criticalCount => alerts.where((alert) {
        return _severity(alert).toLowerCase() == 'critical';
      }).length;

  int get resolvedCount =>
      alerts.where(_isResolved).length;

  // ============================================================
  // RESOLVE ALERT
  // ============================================================

  Future<void> resolveAlert(dynamic alert) async {
    if (alert is! Map) return;

    final alertId = int.tryParse(
      alert['id']?.toString() ?? '',
    );

    if (alertId == null) {
      _showMessage(
        'This alert does not have a valid ID.',
        isError: true,
      );
      return;
    }

    if (_isResolved(alert)) return;

    try {
      // Update the actual Django database through the existing API.
      await ApiService.resolveAlert(
        alertId: alertId,
        isResolved: true,
      );

      if (!mounted) return;

      _showMessage('Alert marked as resolved.');

      // Reload authoritative data from Django.
      await loadAlerts(showLoader: false);
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Unable to resolve this alert. Please try again.',
        isError: true,
      );
    }
  }

  // ============================================================
  // SNACKBAR
  // ============================================================

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError
              ? const Color(0xFFB91C1C)
              : const Color(0xFF15803D),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageBackground,

      appBar: AppBar(
        backgroundColor: cardColor,
        foregroundColor: primaryText,
        elevation: 0,
        scrolledUnderElevation: 0,

        titleSpacing: 20,

        title: const Row(
          children: [
            Icon(
              Icons.notifications_active_outlined,
              color: goldColor,
              size: 25,
            ),
            SizedBox(width: 10),
            Text(
              'RaySense Alerts',
              style: TextStyle(
                color: primaryText,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),

        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(
            height: 1,
            thickness: 1,
            color: borderColor,
          ),
        ),

        actions: [
          IconButton(
            tooltip: 'Refresh alerts',
            onPressed: isRefreshing
                ? null
                : () => loadAlerts(showLoader: false),
            icon: isRefreshing
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: goldColor,
                    ),
                  )
                : const Icon(
                    Icons.refresh_rounded,
                    color: secondaryText,
                  ),
          ),
          const SizedBox(width: 8),
        ],
      ),

      body: RefreshIndicator(
        color: goldColor,
        backgroundColor: cardColor,
        onRefresh: () => loadAlerts(showLoader: false),

        child: isLoading
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 230),
                  Center(
                    child: CircularProgressIndicator(
                      color: goldColor,
                    ),
                  ),
                  SizedBox(height: 18),
                  Center(
                    child: Text(
                      'Loading alerts...',
                      style: TextStyle(
                        color: secondaryText,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              )
            : errorMessage != null
                ? _buildErrorState()
                : _buildContent(),
      ),
    );
  }

  // ============================================================
  // MAIN CONTENT
  // ============================================================

  Widget _buildContent() {
    return ListView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 32),

      children: [
        // Page heading
        const Text(
          'Alerts',
          style: TextStyle(
            color: primaryText,
            fontSize: 30,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.7,
          ),
        ),

        const SizedBox(height: 8),

        const Text(
          'Monitor important events and conditions affecting '
          'your solar system.',
          style: TextStyle(
            color: secondaryText,
            fontSize: 14,
            height: 1.6,
          ),
        ),

        const SizedBox(height: 26),

        // Summary heading
        const Text(
          'Overview',
          style: TextStyle(
            color: primaryText,
            fontSize: 19,
            fontWeight: FontWeight.w700,
          ),
        ),

        const SizedBox(height: 15),

        // Summary cards
        _buildSummaryGrid(),

        const SizedBox(height: 28),

        // Alert history panel
        _buildHistoryPanel(),
      ],
    );
  }

  // ============================================================
  // SUMMARY GRID
  // ============================================================

  Widget _buildSummaryGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 650 ? 4 : 2;

        const spacing = 12.0;

        final cardWidth =
            (constraints.maxWidth - spacing * (columns - 1)) /
                columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,

          children: [
            SizedBox(
              width: cardWidth,
              child: _SummaryCard(
                title: 'Total Alerts',
                value: totalCount,
                icon: Icons.notifications_none_rounded,
                iconBackground: const Color(0xFFFFF7E6),
                iconColor: const Color(0xFFB45309),
              ),
            ),

            SizedBox(
              width: cardWidth,
              child: _SummaryCard(
                title: 'Active Alerts',
                value: activeCount,
                icon: Icons.warning_amber_rounded,
                iconBackground: const Color(0xFFFFF7E6),
                iconColor: const Color(0xFFB45309),
              ),
            ),

            SizedBox(
              width: cardWidth,
              child: _SummaryCard(
                title: 'Critical',
                value: criticalCount,
                icon: Icons.error_outline_rounded,
                iconBackground: const Color(0xFFFFF1F2),
                iconColor: const Color(0xFFDC2626),
              ),
            ),

            SizedBox(
              width: cardWidth,
              child: _SummaryCard(
                title: 'Resolved',
                value: resolvedCount,
                icon: Icons.check_circle_outline_rounded,
                iconBackground: const Color(0xFFECFDF5),
                iconColor: const Color(0xFF15803D),
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // HISTORY PANEL
  // ============================================================

  Widget _buildHistoryPanel() {
    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 18,
            offset: Offset(0, 4),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                const Text(
                  'Alert History',
                  style: TextStyle(
                    color: primaryText,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 7),

                const Text(
                  'Review system alerts and resolve them when '
                  'the issue has been addressed.',
                  style: TextStyle(
                    color: mutedText,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 20),

                _buildFilters(),
              ],
            ),
          ),

          const Divider(
            height: 1,
            color: Color(0xFFEDF0F3),
          ),

          if (filteredAlerts.isEmpty)
            _buildEmptyState()
          else
            Padding(
              padding: const EdgeInsets.all(14),

              child: Column(
                children: [
                  for (int index = 0;
                      index < filteredAlerts.length;
                      index++) ...[
                    _buildAlertCard(filteredAlerts[index]),

                    if (index < filteredAlerts.length - 1)
                      const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // FILTER BUTTONS
  // ============================================================

  Widget _buildFilters() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,

      children: [
        _FilterButton(
          label: 'All',
          selected: selectedFilter == 'all',
          onTap: () => _setFilter('all'),
        ),

        _FilterButton(
          label: 'Active',
          selected: selectedFilter == 'active',
          onTap: () => _setFilter('active'),
        ),

        _FilterButton(
          label: 'Resolved',
          selected: selectedFilter == 'resolved',
          onTap: () => _setFilter('resolved'),
        ),
      ],
    );
  }

  void _setFilter(String filter) {
    setState(() {
      selectedFilter = filter;
    });
  }

  // ============================================================
  // ALERT CARD
  // ============================================================

  Widget _buildAlertCard(dynamic alert) {
    final title = _stringValue(
      alert['title'],
      'System Alert',
    );

    final message = _stringValue(
      alert['message'],
      'No additional details available.',
    );

    final type = _stringValue(
      alert['alert_type'],
      'System',
    );

    final severity = _severity(alert);

    final resolved = _isResolved(alert);

    final alertDate = _stringValue(
      alert['alert_date'],
      '',
    );

    final severityStyle = _severityStyle(severity);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: resolved
            ? const Color(0xFFFAFAFA)
            : cardColor,
        border: Border.all(
          color: borderColor,
        ),
        borderRadius: BorderRadius.circular(15),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          // Title, icon and severity
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Container(
                width: 44,
                height: 44,

                decoration: BoxDecoration(
                  color: severityStyle.background,
                  borderRadius: BorderRadius.circular(12),
                ),

                child: Icon(
                  _alertIcon(type),
                  color: severityStyle.foreground,
                  size: 23,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: primaryText,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      type,
                      style: const TextStyle(
                        color: secondaryText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              _SeverityBadge(
                label: severity,
                background: severityStyle.background,
                foreground: severityStyle.foreground,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Alert message
          Text(
            message,
            style: const TextStyle(
              color: secondaryText,
              fontSize: 13,
              height: 1.65,
            ),
          ),

          const SizedBox(height: 15),

          const Divider(
            height: 1,
            color: Color(0xFFEDF0F3),
          ),

          const SizedBox(height: 13),

          // Date
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              const Icon(
                Icons.schedule_rounded,
                size: 16,
                color: mutedText,
              ),

              const SizedBox(width: 7),

              Expanded(
                child: Text(
                  _formatDate(alertDate),
                  style: const TextStyle(
                    color: mutedText,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 13),

          // Status and action
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,

            children: [
              _StatusBadge(
                resolved: resolved,
              ),

              if (!resolved)
                OutlinedButton.icon(
                  onPressed: () => resolveAlert(alert),

                  icon: const Icon(
                    Icons.check_circle_outline_rounded,
                    size: 16,
                  ),

                  label: const Text('Resolve'),

                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF334155),
                    backgroundColor: Colors.white,
                    side: const BorderSide(
                      color: Color(0xFFDBE1E8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 13,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SEVERITY STYLE
  // ============================================================

  _SeverityColors _severityStyle(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return const _SeverityColors(
          background: Color(0xFFFFF1F2),
          foreground: Color(0xFFDC2626),
        );

      case 'warning':
        return const _SeverityColors(
          background: Color(0xFFFFF7E6),
          foreground: Color(0xFFB45309),
        );

      case 'info':
        return const _SeverityColors(
          background: Color(0xFFEFF6FF),
          foreground: Color(0xFF2563EB),
        );

      default:
        return const _SeverityColors(
          background: Color(0xFFF1F5F9),
          foreground: Color(0xFF475569),
        );
    }
  }

  // ============================================================
  // ALERT ICONS
  // ============================================================

  IconData _alertIcon(String type) {
    switch (type.toLowerCase()) {
      case 'performance':
        return Icons.speed_rounded;

      case 'generation':
        return Icons.bolt_rounded;

      case 'weather':
        return Icons.cloud_outlined;

      case 'maintenance':
        return Icons.build_outlined;

      case 'forecast':
        return Icons.auto_graph_rounded;

      case 'system':
        return Icons.settings_outlined;

      default:
        return Icons.notifications_none_rounded;
    }
  }

  // ============================================================
  // DATE FORMATTING
  // ============================================================

  String _formatDate(String value) {
    if (value.isEmpty) {
      return 'Date unavailable';
    }

    final parsed = DateTime.tryParse(value);

    if (parsed == null) {
      return value;
    }

    final localDate = parsed.toLocal();

    final date = localDate.day.toString().padLeft(2, '0');
    final month = localDate.month.toString().padLeft(2, '0');
    final year = localDate.year.toString();

    final hour = localDate.hour.toString().padLeft(2, '0');
    final minute = localDate.minute.toString().padLeft(2, '0');

    return '$date/$month/$year  $hour:$minute';
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState() {
    String title = 'No alerts found';
    String description =
        'Your solar system has no alerts to display.';

    if (selectedFilter == 'active') {
      title = 'No active alerts';
      description = 'All current alerts have been resolved.';
    } else if (selectedFilter == 'resolved') {
      title = 'No resolved alerts';
      description =
          'Resolved alerts will appear here after you address them.';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 22,
        vertical: 45,
      ),

      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,

            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(22),
            ),

            child: const Icon(
              Icons.notifications_none_rounded,
              color: Color(0xFF94A3B8),
              size: 35,
            ),
          ),

          const SizedBox(height: 18),

          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: primaryText,
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 9),

          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: mutedText,
              fontSize: 13,
              height: 1.6,
            ),
          ),

          const SizedBox(height: 18),

          TextButton.icon(
            onPressed: () => loadAlerts(),

            icon: const Icon(
              Icons.refresh_rounded,
              color: Color(0xFFB45309),
            ),

            label: const Text(
              'Refresh alerts',
              style: TextStyle(
                color: Color(0xFFB45309),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ERROR STATE
  // ============================================================

  Widget _buildErrorState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),

      padding: const EdgeInsets.all(24),

      children: [
        const SizedBox(height: 100),

        const Icon(
          Icons.cloud_off_outlined,
          size: 60,
          color: Color(0xFFDC2626),
        ),

        const SizedBox(height: 18),

        const Text(
          'Unable to load alerts',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: primaryText,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(height: 10),

        Text(
          errorMessage ?? 'Something went wrong.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: secondaryText,
            fontSize: 14,
            height: 1.6,
          ),
        ),

        const SizedBox(height: 22),

        Center(
          child: FilledButton.icon(
            onPressed: () => loadAlerts(),

            icon: const Icon(Icons.refresh_rounded),

            label: const Text('Try again'),

            style: FilledButton.styleFrom(
              backgroundColor: goldColor,
              foregroundColor: primaryText,
              padding: const EdgeInsets.symmetric(
                horizontal: 22,
                vertical: 13,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// SUMMARY CARD
// ============================================================

class _SummaryCard extends StatelessWidget {
  final String title;
  final int value;
  final IconData icon;
  final Color iconBackground;
  final Color iconColor;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(
        minHeight: 135,
      ),

      padding: const EdgeInsets.all(17),

      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              Container(
                width: 37,
                height: 37,

                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(11),
                ),

                child: Icon(
                  icon,
                  color: iconColor,
                  size: 21,
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          Text(
            value.toString(),
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 30,
              height: 1,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// FILTER BUTTON
// ============================================================

class _FilterButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),

      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 10,
        ),

        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF111827)
              : Colors.white,

          border: Border.all(
            color: selected
                ? const Color(0xFF111827)
                : const Color(0xFFDBE1E8),
          ),

          borderRadius: BorderRadius.circular(9),
        ),

        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? Colors.white
                : const Color(0xFF64748B),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ============================================================
// SEVERITY BADGE
// ============================================================

class _SeverityBadge extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;

  const _SeverityBadge({
    required this.label,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),

      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(30),
      ),

      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ============================================================
// STATUS BADGE
// ============================================================

class _StatusBadge extends StatelessWidget {
  final bool resolved;

  const _StatusBadge({
    required this.resolved,
  });

  @override
  Widget build(BuildContext context) {
    final color = resolved
        ? const Color(0xFF15803D)
        : const Color(0xFFDC2626);

    final background = resolved
        ? const Color(0xFFECFDF5)
        : const Color(0xFFFEF2F2);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),

      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(30),
      ),

      child: Row(
        mainAxisSize: MainAxisSize.min,

        children: [
          Icon(
            resolved
                ? Icons.check_circle_rounded
                : Icons.pending_outlined,
            size: 14,
            color: color,
          ),

          const SizedBox(width: 5),

          Text(
            resolved ? 'Resolved' : 'Active',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// SEVERITY COLORS
// ============================================================

class _SeverityColors {
  final Color background;
  final Color foreground;

  const _SeverityColors({
    required this.background,
    required this.foreground,
  });
}
