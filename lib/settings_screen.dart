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
  String electricityRate = '₹7.00 / kWh';

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
                '₹${rateValue.toStringAsFixed(2)} / kWh';
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
              '₹${rateValue.toStringAsFixed(2)} / kWh';
        } else {
          electricityRate =
              '₹${result['electricity_rate']} / kWh';
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
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,

        title: const Row(
          children: [
            Icon(
              Icons.settings_outlined,
              color: Colors.orange,
            ),

            SizedBox(width: 10),

            Text(
              'Settings',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),

      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Colors.orange,
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),

              children: [
                const Text(
                  'System Settings',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  'Manage your RaySense system',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 15,
                  ),
                ),

                const SizedBox(height: 24),

                // =====================================================
                // Solar System
                // =====================================================

                _SettingsSection(
                  title: 'Solar System',
                  children: [
                    _SettingsTile(
                      icon: Icons.solar_power,
                      title: 'Solar System',
                      subtitle: systemName,
                      onTap: _editSolarSystem,
                    ),

                    _SettingsTile(
                      icon: Icons.location_on_outlined,
                      title: 'Location',
                      subtitle: location,
                      onTap: _editSolarSystem,
                    ),

                    _SettingsTile(
                      icon: Icons.battery_charging_full,
                      title: 'System Capacity',
                      subtitle: capacity,
                      onTap: _editSolarSystem,
                    ),

                    _SettingsTile(
                      icon: Icons.grid_view,
                      title: 'Panel Count',
                      subtitle: panelCount,
                      onTap: _editSolarSystem,
                    ),

                    _SettingsTile(
                      icon: Icons.view_module_outlined,
                      title: 'Panel Type',
                      subtitle: panelType,
                      onTap: _editSolarSystem,
                    ),

                    _SettingsTile(
                      icon: Icons.calendar_today_outlined,
                      title: 'Installation Date',
                      subtitle: installationDate,
                      onTap: _showInstallationDate,
                    ),

                    _SettingsTile(
                      icon: Icons.currency_rupee,
                      title: 'Electricity Rate',
                      subtitle: electricityRate,
                      onTap: _editSolarSystem,
                    ),

                    _SettingsTile(
                      icon: Icons.edit_outlined,
                      title: 'Edit Solar System',
                      subtitle:
                          'Update system information',
                      onTap: _editSolarSystem,
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // =====================================================
                // Notifications
                // =====================================================

                _SettingsSection(
                  title: 'Notifications',
                  children: [
                    _SettingsTile(
                      icon: Icons.notifications_outlined,
                      title: 'Alerts',
                      subtitle:
                          'Receive solar system alerts',

                      trailing: Switch(
                        value: alertsEnabled,

                        onChanged: (value) {
                          setState(() {
                            alertsEnabled = value;
                          });
                        },

                        activeThumbColor:
                            Colors.orange,
                      ),

                      onTap: () {
                        setState(() {
                          alertsEnabled =
                              !alertsEnabled;
                        });
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // =====================================================
                // Application
                // =====================================================

                _SettingsSection(
                  title: 'Application',
                  children: [
                    _SettingsTile(
                      icon: Icons.info_outline,
                      title: 'About RaySense',
                      subtitle:
                          'AI-based solar monitoring system',

                      onTap: () {
                        showAboutDialog(
                          context: context,
                          applicationName: 'RaySense',
                          applicationVersion: '1.0.0',

                          applicationIcon:
                              const Icon(
                            Icons.wb_sunny,
                            color: Colors.orange,
                            size: 35,
                          ),

                          children: const [
                            Text(
                              'RaySense is an AI-based solar energy monitoring, forecasting and performance management system.',
                            ),
                          ],
                        );
                      },
                    ),

                    _SettingsTile(
                      icon: Icons.code,
                      title: 'Technology',
                      subtitle:
                          'Flutter • Django • MySQL • Machine Learning',
                      onTap: () {},
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                Center(
                  child: Text(
                    'RaySense v1.0.0',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 13,
                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
    );
  }
}

// =====================================================
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
          .replaceAll('₹', '')
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
                  'Electricity Rate (₹/kWh)',
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