import 'package:flutter/material.dart';
import 'api_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int? systemId;

  String systemName = 'RaySense Test System';
  String location = 'Kochi, Kerala';
  String capacity = '5.0 kW';
  String panelCount = '12 panels';
  String panelType = 'Monocrystalline';
  String installationDate = '01 January 2026';
  String electricityRate = 'â‚¹7.00 / kWh';

  bool alertsEnabled = true;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSolarSystem();
  }

  // =====================================================
  // Load Solar System
  // =====================================================

  Future<void> _loadSolarSystem() async {
    try {
      final systems = await ApiService.getSolarSystems();

      if (!mounted) return;

      if (systems.isNotEmpty) {
        final system = Map<String, dynamic>.from(systems[0]);

        setState(() {
          systemId = int.tryParse(
            system['id']?.toString() ?? '',
          );

          systemName =
              system['system_name']?.toString() ??
              'Solar System';

          location =
              system['location']?.toString() ??
              'Unknown location';

          final capacityValue = double.tryParse(
                system['capacity_kw']?.toString() ?? '',
              ) ??
              0.0;

          capacity =
              '${capacityValue.toStringAsFixed(1)} kW';

          panelCount =
              '${system['panel_count']?.toString() ?? '0'} panels';

          panelType =
              system['panel_type']?.toString() ??
              'Unknown';

          final installation =
              system['installation_date']?.toString();

          if (installation != null &&
              installation.isNotEmpty) {
            final date =
                DateTime.tryParse(installation);

            if (date != null) {
              installationDate =
                  '${date.day.toString().padLeft(2, '0')} '
                  '${_monthName(date.month)} '
                  '${date.year}';
            }
          }

          // =================================================
          // Load Electricity Rate from Django / MySQL
          // =================================================

          final rateValue = double.tryParse(
            system['electricity_rate']?.toString() ?? '',
          );

          if (rateValue != null) {
            electricityRate =
                'â‚¹${rateValue.toStringAsFixed(2)} / kWh';
          }

          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to load solar system: $e',
          ),
        ),
      );
    }
  }

  // =====================================================
  // Edit Solar System
  // =====================================================

  Future<void> _logout() async {
    try {
      await ApiService.logout();

      if (!mounted) return;

      Navigator.of(context).pushNamedAndRemoveUntil(
        '/',
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logout failed: $e'),
        ),
      );
    }
  }

  Future<void> _editSolarSystem() async {
    if (systemId == null) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Solar system ID not available.',
          ),
        ),
      );

      return;
    }

    final result =
        await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return _EditSolarSystemDialog(
          systemId: systemId!,
          systemName: systemName,
          location: location,
          capacity: capacity,
          panelCount: panelCount,
          panelType: panelType,
          electricityRate: electricityRate,
          installationDate: installationDate,
        );
      },
    );

    if (!mounted || result == null) {
      return;
    }

    setState(() {
      systemName =
          result['system_name']?.toString() ??
          systemName;

      location =
          result['location']?.toString() ??
          location;

      final updatedCapacity = double.tryParse(
        result['capacity_kw']?.toString() ?? '',
      );

      if (updatedCapacity != null) {
        capacity =
            '${updatedCapacity.toStringAsFixed(1)} kW';
      }

      panelCount =
          '${result['panel_count']?.toString() ?? panelCount.replaceAll(' panels', '')} panels';

      panelType =
          result['panel_type']?.toString() ??
          panelType;

      if (result['electricity_rate'] != null) {
        final rateValue = double.tryParse(
          result['electricity_rate']?.toString() ?? '',
        );

        if (rateValue != null) {
          electricityRate =
              'â‚¹${rateValue.toStringAsFixed(2)} / kWh';
        } else {
          electricityRate =
              'â‚¹${result['electricity_rate']} / kWh';
        }
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Solar system details saved to database.',
        ),
      ),
    );
  }

  // =====================================================
  // Installation Date
  // =====================================================

  DateTime? _parseInstallationDate(String value) {
    final parts = value.split(' ');

    if (parts.length != 3) {
      return null;
    }

    final day = int.tryParse(parts[0]);
    final year = int.tryParse(parts[2]);

    if (day == null || year == null) {
      return null;
    }

    const months = {
      'January': 1,
      'February': 2,
      'March': 3,
      'April': 4,
      'May': 5,
      'June': 6,
      'July': 7,
      'August': 8,
      'September': 9,
      'October': 10,
      'November': 11,
      'December': 12,
    };

    final month = months[parts[1]];

    if (month == null) {
      return null;
    }

    return DateTime(year, month, day);
  }

  void _showInstallationDate() {
    final currentDate =
        _parseInstallationDate(installationDate) ??
        DateTime(2026, 1, 1);

    showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    ).then((date) {
      if (date == null || !mounted) {
        return;
      }

      setState(() {
        installationDate =
            '${date.day.toString().padLeft(2, '0')} '
            '${_monthName(date.month)} '
            '${date.year}';
      });
    });
  }

  String _monthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return months[month - 1];
  }

  // =====================================================
  // Build Settings Screen
  // =====================================================

  @override
  Widget build(BuildContext context) {
    const orange = Color(0xFFFF9800);
    const ink = Color(0xFF172033);
    const muted = Color(0xFF64748B);
    const background = Color(0xFFF5F7FB);
    const border = Color(0xFFE8ECF2);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 22,
        title: const Row(
          children: [
            Icon(Icons.wb_sunny_rounded, color: orange, size: 25),
            SizedBox(width: 10),
            Text(
              'RaySense',
              style: TextStyle(
                color: ink,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 18),
            child: CircleAvatar(
              backgroundColor: const Color(0xFFFFF1D6),
              child: Icon(Icons.settings_rounded, color: orange),
            ),
          ),
        ],
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: orange),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 760;
                final horizontal = wide ? 24.0 : 16.0;

                Widget card({
                  required Widget child,
                  EdgeInsets padding = const EdgeInsets.all(20),
                }) {
                  return Container(
                    padding: padding,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: border),
                      boxShadow: [
                        BoxShadow(
                          color: ink.withValues(alpha: 0.035),
                          blurRadius: 18,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: child,
                  );
                }

                Widget heading(String title, String subtitle, IconData icon) {
                  return Row(
                    children: [
                      Container(
                        width: 43,
                        height: 43,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3DD),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(icon, color: orange, size: 23),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                color: ink,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              style: const TextStyle(
                                color: muted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }

                Widget detail(
                  String label,
                  String value,
                  IconData icon,
                ) {
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F8FC),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(icon, size: 20, color: orange),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                label,
                                style: const TextStyle(
                                  color: muted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                value,
                                style: const TextStyle(
                                  color: ink,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                Widget actionRow({
                  required IconData icon,
                  required String title,
                  required String subtitle,
                  required VoidCallback onTap,
                  Widget? trailing,
                  Color iconColor = orange,
                }) {
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onTap,
                      borderRadius: BorderRadius.circular(13),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF3DD),
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: Icon(icon, color: iconColor, size: 21),
                            ),
                            const SizedBox(width: 13),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: const TextStyle(
                                      color: ink,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    subtitle,
                                    style: const TextStyle(
                                      color: muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            trailing ??
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: Color(0xFF9AA4B2),
                                ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                Widget sectionTitle(String title) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12, top: 24),
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  );
                }

                return ListView(
                  padding: EdgeInsets.fromLTRB(
                    horizontal,
                    26,
                    horizontal,
                    32,
                  ),
                  children: [
                    const Text(
                      'Settings',
                      style: TextStyle(
                        color: ink,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 7),
                    const Text(
                      'Manage your account, solar installation and application preferences.',
                      style: TextStyle(
                        color: muted,
                        fontSize: 13,
                        height: 1.6,
                      ),
                    ),

                    sectionTitle('Solar installation'),

                    card(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF5E4),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 51,
                                  height: 51,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: const Icon(
                                    Icons.solar_power_rounded,
                                    color: orange,
                                    size: 29,
                                  ),
                                ),
                                const SizedBox(width: 13),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        systemName,
                                        style: const TextStyle(
                                          color: ink,
                                          fontSize: 17,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.location_on_outlined,
                                            size: 15,
                                            color: muted,
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              location,
                                              style: const TextStyle(
                                                color: muted,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE6F8EE),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    'Registered',
                                    style: TextStyle(
                                      color: Color(0xFF16834A),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 15),
                          GridView.count(
                            crossAxisCount: constraints.maxWidth >= 1000 ? 4 : 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            childAspectRatio: constraints.maxWidth >= 1000 ? 1.5 : 1.35,
                            children: [
                              detail('SYSTEM CAPACITY', capacity,
                                  Icons.bolt_rounded),
                              detail('SOLAR PANELS', panelCount,
                                  Icons.grid_view_rounded),
                              detail('PANEL TECHNOLOGY', panelType,
                                  Icons.view_module_rounded),
                              InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: _showInstallationDate,
                                child: detail(
                                  'INSTALLATION DATE',
                                  installationDate,
                                  Icons.calendar_month_rounded,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              border: Border.all(color: border),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.currency_rupee_rounded,
                                  color: orange,
                                  size: 23,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Electricity tariff',
                                        style: TextStyle(
                                          color: ink,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'INR 7.00 / kWh',
                                        style: TextStyle(
                                          color: muted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton(
                                  onPressed: _editSolarSystem,
                                  child: const Text(
                                    'EDIT',
                                    style: TextStyle(
                                      color: orange,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _editSolarSystem,
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              label: const Text('Edit solar system'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: orange,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 15),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(13),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    sectionTitle('Account & security'),

                    card(
                      child: Column(
                        children: [
                          heading(
                            'Account settings',
                            'Manage your RaySense session',
                            Icons.manage_accounts_outlined,
                          ),
                          const SizedBox(height: 15),
                          const Divider(color: border, height: 1),
                          actionRow(
                            icon: Icons.verified_user_outlined,
                            title: 'Account security',
                            subtitle: 'Your session is authenticated',
                            onTap: () {
                              showDialog<void>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Account security'),
                                  content: const Text(
                                    'You are signed in to RaySense. Your account uses the existing authenticated session.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Close'),
                                    ),
                                  ],
                                ),
                              );
                            },
                            trailing: const Icon(
                              Icons.check_circle_rounded,
                              color: Color(0xFF16A765),
                            ),
                          ),
                          const Divider(color: border, height: 1),
                          actionRow(
                            icon: Icons.logout_rounded,
                            title: 'Logout',
                            subtitle: 'Sign out of your RaySense account',
                            iconColor: const Color(0xFFDC4545),
                            onTap: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Log out?'),
                                  content: const Text(
                                    'Are you sure you want to sign out of RaySense?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: orange,
                                      ),
                                      child: const Text('Log out'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true && mounted) {
                                await _logout();
                              }
                            },
                          ),
                        ],
                      ),
                    ),

                    sectionTitle('Preferences'),

                    card(
                      child: Column(
                        children: [
                          heading(
                            'Notifications',
                            'Choose your alert preferences',
                            Icons.notifications_active_outlined,
                          ),
                          const SizedBox(height: 14),
                          const Divider(color: border, height: 1),
                          actionRow(
                            icon: Icons.notifications_outlined,
                            title: 'Solar system alerts',
                            subtitle: alertsEnabled
                                ? 'Notifications are enabled'
                                : 'Notifications are disabled',
                            onTap: () {
                              setState(() {
                                alertsEnabled = !alertsEnabled;
                              });
                            },
                            trailing: Switch(
                              value: alertsEnabled,
                              activeThumbColor: orange,
                              onChanged: (value) {
                                setState(() {
                                  alertsEnabled = value;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    sectionTitle('About RaySense'),

                    card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          heading(
                            'RaySense Solar Intelligence',
                            'AI-powered solar monitoring platform',
                            Icons.wb_sunny_outlined,
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'Monitor solar generation, forecast energy production and review your system performance through one unified application.',
                            style: TextStyle(
                              color: muted,
                              fontSize: 13,
                              height: 1.7,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              'Flutter',
                              'Django REST API',
                              'MySQL',
                              'Machine Learning',
                            ].map((technology) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 11,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3F5F9),
                                  borderRadius: BorderRadius.circular(9),
                                  border: Border.all(color: border),
                                ),
                                child: Text(
                                  technology,
                                  style: const TextStyle(
                                    color: ink,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 18),
                          const Divider(color: border),
                          Row(
                            children: [
                              const Icon(
                                Icons.info_outline_rounded,
                                color: orange,
                                size: 19,
                              ),
                              const SizedBox(width: 9),
                              const Expanded(
                                child: Text(
                                  'Application version',
                                  style: TextStyle(
                                    color: muted,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 11,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF3DD),
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: const Text(
                                  'v1.0.0',
                                  style: TextStyle(
                                    color: Color(0xFF9A5A00),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 25),
                    const Center(
                      child: Text(
                        'RaySense ? Solar Intelligence',
                        style: TextStyle(
                          color: Color(0xFF8A94A5),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

// Edit Solar System Dialog
// =====================================================

class _EditSolarSystemDialog
    extends StatefulWidget {
  final int systemId;

  final String systemName;
  final String location;
  final String capacity;
  final String panelCount;
  final String panelType;
  final String electricityRate;
  final String installationDate;

  const _EditSolarSystemDialog({
    required this.systemId,
    required this.systemName,
    required this.location,
    required this.capacity,
    required this.panelCount,
    required this.panelType,
    required this.electricityRate,
    required this.installationDate,
  });

  @override
  State<_EditSolarSystemDialog> createState() =>
      _EditSolarSystemDialogState();
}

class _EditSolarSystemDialogState
    extends State<_EditSolarSystemDialog> {
  late final TextEditingController nameController;
  late final TextEditingController locationController;
  late final TextEditingController capacityController;
  late final TextEditingController panelCountController;
  late final TextEditingController panelTypeController;
  late final TextEditingController rateController;

  bool isSaving = false;

  @override
  void initState() {
    super.initState();

    nameController =
        TextEditingController(
      text: widget.systemName,
    );

    locationController =
        TextEditingController(
      text: widget.location,
    );

    capacityController =
        TextEditingController(
      text: widget.capacity.replaceAll(
        ' kW',
        '',
      ),
    );

    panelCountController =
        TextEditingController(
      text: widget.panelCount.replaceAll(
        ' panels',
        '',
      ),
    );

    panelTypeController =
        TextEditingController(
      text: widget.panelType,
    );

    rateController =
        TextEditingController(
      text: widget.electricityRate
          .replaceAll('â‚¹', '')
          .replaceAll(' / kWh', ''),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    locationController.dispose();
    capacityController.dispose();
    panelCountController.dispose();
    panelTypeController.dispose();
    rateController.dispose();

    super.dispose();
  }

  // =====================================================
  // Parse Installation Date
  // =====================================================

  DateTime? _parseInstallationDate(
    String value,
  ) {
    final parts = value.split(' ');

    if (parts.length != 3) {
      return null;
    }

    final day = int.tryParse(parts[0]);
    final year = int.tryParse(parts[2]);

    if (day == null || year == null) {
      return null;
    }

    const months = {
      'January': 1,
      'February': 2,
      'March': 3,
      'April': 4,
      'May': 5,
      'June': 6,
      'July': 7,
      'August': 8,
      'September': 9,
      'October': 10,
      'November': 11,
      'December': 12,
    };

    final month = months[parts[1]];

    if (month == null) {
      return null;
    }

    return DateTime(
      year,
      month,
      day,
    );
  }

  // =====================================================
  // Save Solar System
  // =====================================================

  Future<void> _save() async {
    final name =
        nameController.text.trim();

    final location =
        locationController.text.trim();

    final capacity =
        double.tryParse(
      capacityController.text.trim(),
    );

    final panelCount =
        int.tryParse(
      panelCountController.text.trim(),
    );

    final panelType =
        panelTypeController.text.trim();

    final electricityRate =
        double.tryParse(
      rateController.text.trim(),
    );

    // -----------------------------------------------------
    // Validation
    // -----------------------------------------------------

    if (name.isEmpty ||
        location.isEmpty ||
        capacity == null ||
        capacity <= 0 ||
        panelCount == null ||
        panelCount <= 0 ||
        panelType.isEmpty ||
        electricityRate == null ||
        electricityRate < 0) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter valid values.',
          ),
        ),
      );

      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      // ---------------------------------------------------
      // Convert installation date to YYYY-MM-DD
      // ---------------------------------------------------

      String? backendInstallationDate;

      final parsedDate =
          _parseInstallationDate(
        widget.installationDate,
      );

      if (parsedDate != null) {
        backendInstallationDate =
            '${parsedDate.year}-'
            '${parsedDate.month.toString().padLeft(2, '0')}-'
            '${parsedDate.day.toString().padLeft(2, '0')}';
      }

      // ---------------------------------------------------
      // Update Django / MySQL
      // ---------------------------------------------------

      final updated =
          await ApiService.updateSolarSystem(
        systemId: widget.systemId,

        systemName: name,

        location: location,

        capacityKw: capacity,

        // IMPORTANT:
        // Save electricity rate to Django/MySQL.
        electricityRate: electricityRate,

        panelCount: panelCount,

        panelType: panelType,

        installationDate:
            backendInstallationDate,
      );

      if (!mounted) return;

      // ---------------------------------------------------
      // Return updated data to SettingsScreen
      // ---------------------------------------------------

      Navigator.of(context).pop({
        ...updated,

        'electricity_rate':
            electricityRate.toStringAsFixed(2),
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isSaving = false;
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Failed to save changes: $e',
          ),
        ),
      );
    }
  }

  // =====================================================
  // Text Field
  // =====================================================

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 14,
      ),

      child: TextField(
        controller: controller,
        keyboardType: keyboardType,

        decoration: InputDecoration(
          labelText: label,

          prefixIcon: Icon(
            icon,
            color: Colors.orange,
          ),

          border: OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(12),
          ),

          focusedBorder:
              OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(12),

            borderSide:
                const BorderSide(
              color: Colors.orange,
              width: 2,
            ),
          ),
        ),
      ),
    );
  }

  // =====================================================
  // Dialog UI
  // =====================================================

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Edit Solar System',
        style: TextStyle(
          fontWeight: FontWeight.bold,
        ),
      ),

      content: SingleChildScrollView(
        child: Column(
          mainAxisSize:
              MainAxisSize.min,

          children: [
            _field(
              controller:
                  nameController,
              label: 'System Name',
              icon: Icons.solar_power,
            ),

            _field(
              controller:
                  locationController,
              label: 'Location',
              icon:
                  Icons.location_on_outlined,
            ),

            _field(
              controller:
                  capacityController,
              label:
                  'System Capacity (kW)',
              icon:
                  Icons.battery_charging_full,
              keyboardType:
                  const TextInputType
                      .numberWithOptions(
                decimal: true,
              ),
            ),

            _field(
              controller:
                  panelCountController,
              label: 'Panel Count',
              icon: Icons.grid_view,
              keyboardType:
                  TextInputType.number,
            ),

            _field(
              controller:
                  panelTypeController,
              label: 'Panel Type',
              icon:
                  Icons.view_module_outlined,
            ),

            _field(
              controller:
                  rateController,
              label:
                  'Electricity Rate (â‚¹/kWh)',
              icon:
                  Icons.currency_rupee,
              keyboardType:
                  const TextInputType
                      .numberWithOptions(
                decimal: true,
              ),
            ),
          ],
        ),
      ),

      // =================================================
      // Buttons
      // =================================================

      actions: [
        TextButton(
          onPressed: isSaving
              ? null
              : () {
                  Navigator.of(context)
                      .pop();
                },

          child:
              const Text('Cancel'),
        ),

        ElevatedButton(
          style:
              ElevatedButton.styleFrom(
            backgroundColor:
                Colors.orange,
            foregroundColor:
                Colors.white,
          ),

          onPressed:
              isSaving ? null : _save,

          child: isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,

                  child:
                      CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

// =====================================================
// Settings Section
// =====================================================

class _SettingsSection
    extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    required this.children,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,

      children: [
        Text(
          title,
          style:
              const TextStyle(
            fontSize: 18,
            fontWeight:
                FontWeight.bold,
          ),
        ),

        const SizedBox(height: 10),

        // FIXED:
        // Material is used instead of Container so
        // ListTile ink splashes/background are rendered correctly.
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,

          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }
}

// =====================================================
// Settings Tile
// =====================================================

class _SettingsTile
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 6,
      ),

      leading: Container(
        padding:
            const EdgeInsets.all(
          10,
        ),

        decoration:
            BoxDecoration(
          color:
              Colors.orange.shade50,

          shape:
              BoxShape.circle,
        ),

        child: Icon(
          icon,
          color: Colors.orange,
        ),
      ),

      title: Text(
        title,
        style:
            const TextStyle(
          fontWeight:
              FontWeight.w600,
        ),
      ),

      subtitle: Padding(
        padding:
            const EdgeInsets.only(
          top: 3,
        ),

        child: Text(
          subtitle,
          style: TextStyle(
            color:
                Colors.grey.shade600,
          ),
        ),
      ),

      trailing:
          trailing ??
          const Icon(
            Icons.chevron_right,
            color: Colors.grey,
          ),

      onTap: onTap,
    );
  }
}

