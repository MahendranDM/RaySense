import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geocoding;

import 'api_service.dart';

class RegistrationScreen extends StatefulWidget {
  final VoidCallback? onRegistrationSuccess;

  const RegistrationScreen({
    super.key,
    this.onRegistrationSuccess,
  });

  @override
  State<RegistrationScreen> createState() =>
      _RegistrationScreenState();
}

class _RegistrationScreenState
    extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  // ------------------------------------------------------------
  // ACCOUNT
  // ------------------------------------------------------------

  final _usernameController =
      TextEditingController();

  final _emailController =
      TextEditingController();

  final _passwordController =
      TextEditingController();

  final _confirmPasswordController =
      TextEditingController();

  // ------------------------------------------------------------
  // SOLAR SYSTEM
  // ------------------------------------------------------------

  final _systemNameController =
      TextEditingController();

  final _locationController =
      TextEditingController();

  final _capacityController =
      TextEditingController();

  final _panelCountController =
      TextEditingController();

  // ------------------------------------------------------------
  // LOCATION
  // ------------------------------------------------------------

  double? _latitude;
  double? _longitude;

  bool _locationDetected = false;
  bool _isDetectingLocation = false;

  // ------------------------------------------------------------
  // ELECTRICITY
  // ------------------------------------------------------------

  final _providerController =
      TextEditingController();

  String? _selectedPanelType;
  String? _selectedConsumerCategory;

  DateTime? _installationDate;

  // ------------------------------------------------------------
  // BILL
  // ------------------------------------------------------------

  String? _billFilePath;
  String? _billFileName;

  // ------------------------------------------------------------
  // UI STATE
  // ------------------------------------------------------------

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  final List<String> _panelTypes = [
    'Monocrystalline',
    'Polycrystalline',
    'Thin Film',
    'Bifacial',
    'Other',
  ];

  final List<String> _consumerCategories = [
    'Domestic',
    'Commercial',
    'Industrial',
    'Agricultural',
    'Other',
  ];

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _systemNameController.dispose();
    _locationController.dispose();
    _capacityController.dispose();
    _panelCountController.dispose();
    _providerController.dispose();

    super.dispose();
  }

  // ------------------------------------------------------------
  // REGISTRATION
  // ------------------------------------------------------------

  Future<void> _register() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_installationDate == null) {
      _showMessage(
        'Please select the installation date.',
        isError: true,
      );
      return;
    }

    if (!_locationDetected ||
        _latitude == null ||
        _longitude == null) {
      _showMessage(
        'Please detect your device location before registering.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await ApiService.register(
        username:
            _usernameController.text.trim(),
        email:
            _emailController.text.trim(),
        password:
            _passwordController.text,
        password2:
            _confirmPasswordController.text,
        systemName:
            _systemNameController.text.trim(),
        location:
            _locationController.text.trim(),
        latitude:
            _latitude!,
        longitude:
            _longitude!,
        capacityKw:
            double.parse(
          _capacityController.text.trim(),
        ),
        panelCount:
            int.parse(
          _panelCountController.text.trim(),
        ),
        panelType:
            _selectedPanelType ?? '',
        installationDate:
            _formatDateForApi(
          _installationDate!,
        ),
        provider:
            _providerController.text.trim(),
        consumerCategory:
            _selectedConsumerCategory ?? '',
        billFilePath:
            _billFilePath,
      );

      if (!mounted) {
        return;
      }

      _showMessage(
        result['message']?.toString() ??
            'Registration successful.',
      );

      widget.onRegistrationSuccess?.call();
    } catch (e) {
      if (!mounted) {
        return;
      }

      String message = e.toString();

      if (message.startsWith('Exception: ')) {
        message = message.substring(11);
      }

      _showMessage(
        message,
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ------------------------------------------------------------
  // LOCATION
  // ------------------------------------------------------------

  Future<void> _detectLocation() async {
    if (_isDetectingLocation) {
      return;
    }

    setState(() {
      _isDetectingLocation = true;
    });

    try {
      final serviceEnabled =
          await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        if (!mounted) {
          return;
        }

        _showMessage(
          'Please turn on location services on your device.',
          isError: true,
        );
        return;
      }

      LocationPermission permission =
          await Geolocator.checkPermission();

      if (permission ==
          LocationPermission.denied) {
        permission =
            await Geolocator.requestPermission();
      }

      if (permission ==
          LocationPermission.denied) {
        if (!mounted) {
          return;
        }

        _showMessage(
          'Location permission was denied. Please allow location access to continue.',
          isError: true,
        );
        return;
      }

      if (permission ==
          LocationPermission.deniedForever) {
        if (!mounted) {
          return;
        }

        _showLocationSettingsDialog();
        return;
      }

      final position =
          await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(
          accuracy:
              LocationAccuracy.high,
        ),
      );

      if (!mounted) {
        return;
      }

      String readableLocation =
          'Latitude ${position.latitude.toStringAsFixed(6)}, '
          'Longitude ${position.longitude.toStringAsFixed(6)}';

      try {
        final placemarks =
            await geocoding.Geocoding().placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          final place = placemarks.first;

          final parts = <String>[
            if (place.locality != null &&
                place.locality!.isNotEmpty)
              place.locality!,
            if (place.administrativeArea != null &&
                place.administrativeArea!.isNotEmpty)
              place.administrativeArea!,
            if (place.country != null &&
                place.country!.isNotEmpty)
              place.country!,
          ];

          if (parts.isNotEmpty) {
            readableLocation = parts.join(', ');
          }
        }
      } catch (_) {
        // Keep coordinates if reverse geocoding fails.
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _locationController.text = readableLocation;
        _locationDetected = true;
      });

      _showMessage(
        'Location detected successfully.',
      );  if (!mounted) {
        return;
      }

      _showMessage(
        'Unable to detect your location. Please try again.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDetectingLocation = false;
        });
      }
    }
  }

  void _showLocationSettingsDialog() {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Location permission required',
          ),
          content: const Text(
            'Location permission has been permanently denied. Please enable it from the app settings to use device location.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                'Cancel',
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();

                await Geolocator.openAppSettings();
              },
              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(0xFFFFB300),
                foregroundColor:
                    Colors.white,
              ),
              child: const Text(
                'Open Settings',
              ),
            ),
          ],
        );
      },
    );
  }

  // ------------------------------------------------------------
  // DATE PICKER
  // ------------------------------------------------------------

  Future<void> _selectInstallationDate() async {
    final now = DateTime.now();

    final pickedDate = await showDatePicker(
      context: context,
      initialDate:
          _installationDate ?? now,
      firstDate:
          DateTime(1990),
      lastDate:
          now,
      helpText:
          'Select installation date',
      builder: (
        BuildContext context,
        Widget? child,
      ) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme:
                const ColorScheme.light(
              primary:
                  Color(0xFFFFB300),
              onPrimary:
                  Colors.white,
              surface:
                  Colors.white,
              onSurface:
                  Color(0xFF172033),
            ),
          ),
          child:
              child!,
        );
      },
    );

    if (pickedDate != null) {
      setState(() {
        _installationDate =
            pickedDate;
      });
    }
  }

  // ------------------------------------------------------------
  // BILL
  // ------------------------------------------------------------

  void _selectBillFile() {
    _showMessage(
      'Electricity bill upload will be enabled in the next step.',
    );
  }

  // ------------------------------------------------------------
  // HELPERS
  // ------------------------------------------------------------

  String _formatDateForApi(
    DateTime date,
  ) {
    final year =
        date.year.toString().padLeft(4, '0');

    final month =
        date.month.toString().padLeft(2, '0');

    final day =
        date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  String _formatDateForDisplay(
    DateTime date,
  ) {
    final day =
        date.day.toString().padLeft(2, '0');

    final month =
        date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
        behavior:
            SnackBarBehavior.floating,
        backgroundColor:
            isError
                ? const Color(0xFFD32F2F)
                : const Color(0xFF2E7D32),
      ),
    );
  }

  // ------------------------------------------------------------
  // VALIDATORS
  // ------------------------------------------------------------

  String? _validateUsername(
    String? value,
  ) {
    if (value == null ||
        value.trim().isEmpty) {
      return 'Please enter a username';
    }

    if (value.trim().length < 3) {
      return 'Username must contain at least 3 characters';
    }

    return null;
  }

  String? _validateEmail(
    String? value,
  ) {
    if (value == null ||
        value.trim().isEmpty) {
      return 'Please enter your email';
    }

    final emailRegex = RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    );

    if (!emailRegex.hasMatch(
      value.trim(),
    )) {
      return 'Please enter a valid email address';
    }

    return null;
  }

  String? _validatePassword(
    String? value,
  ) {
    if (value == null ||
        value.isEmpty) {
      return 'Please enter a password';
    }

    if (value.length < 8) {
      return 'Password must contain at least 8 characters';
    }

    return null;
  }

  String? _validateConfirmPassword(
    String? value,
  ) {
    if (value == null ||
        value.isEmpty) {
      return 'Please confirm your password';
    }

    if (value !=
        _passwordController.text) {
      return 'Passwords do not match';
    }

    return null;
  }

  String? _validateCapacity(
    String? value,
  ) {
    if (value == null ||
        value.trim().isEmpty) {
      return 'Please enter solar capacity';
    }

    final capacity =
        double.tryParse(
      value.trim(),
    );

    if (capacity == null ||
        capacity <= 0) {
      return 'Enter a valid capacity';
    }

    return null;
  }

  String? _validatePanelCount(
    String? value,
  ) {
    if (value == null ||
        value.trim().isEmpty) {
      return 'Please enter panel count';
    }

    final count =
        int.tryParse(
      value.trim(),
    );

    if (count == null ||
        count <= 0) {
      return 'Enter a valid panel count';
    }

    return null;
  }

  // ------------------------------------------------------------
  // BUILD
  // ------------------------------------------------------------

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF7F9FC),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),

            Expanded(
              child:
                  SingleChildScrollView(
                padding:
                    const EdgeInsets.fromLTRB(
                  20,
                  8,
                  20,
                  32,
                ),
                child:
                    ConstrainedBox(
                  constraints:
                      const BoxConstraints(
                    maxWidth: 620,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .stretch,
                      children: [
                        _buildHeader(),

                        const SizedBox(
                          height: 24,
                        ),

                        _buildProgress(),

                        const SizedBox(
                          height: 24,
                        ),

                        _buildAccountSection(),

                        const SizedBox(
                          height: 18,
                        ),

                        _buildSolarSection(),

                        const SizedBox(
                          height: 18,
                        ),

                        _buildLocationSection(),

                        const SizedBox(
                          height: 18,
                        ),

                        _buildElectricitySection(),

                        const SizedBox(
                          height: 18,
                        ),

                        _buildBillSection(),

                        const SizedBox(
                          height: 28,
                        ),

                        _buildRegisterButton(),

                        const SizedBox(
                          height: 18,
                        ),

                        _buildLoginLink(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // TOP BAR
  // ------------------------------------------------------------

  Widget _buildTopBar() {
    return Container(
      height: 64,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 16,
      ),
      decoration:
          const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFE7EBF2),
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed:
                _isLoading
                    ? null
                    : () {
                        Navigator.of(
                          context,
                        ).pop();
                      },
            icon: const Icon(
              Icons.arrow_back_rounded,
            ),
            color:
                const Color(0xFF172033),
          ),
          const SizedBox(
            width: 4,
          ),
          const Icon(
            Icons.wb_sunny_rounded,
            color:
                Color(0xFFFFB300),
            size: 27,
          ),
          const SizedBox(
            width: 10,
          ),
          const Text(
            'RaySense',
            style: TextStyle(
              fontSize: 20,
              fontWeight:
                  FontWeight.bold,
              color:
                  Color(0xFF172033),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // HEADER
  // ------------------------------------------------------------

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const SizedBox(
          height: 12,
        ),
        const Text(
          'Set up your solar system',
          style: TextStyle(
            fontSize: 30,
            fontWeight:
                FontWeight.bold,
            color:
                Color(0xFF172033),
            height: 1.15,
          ),
        ),
        const SizedBox(
          height: 10,
        ),
        const Text(
          'Tell RaySense about your solar installation so we can monitor performance, forecast generation and provide useful insights.',
          style: TextStyle(
            fontSize: 15,
            height: 1.55,
            color:
                Color(0xFF697386),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // PROGRESS
  // ------------------------------------------------------------

  Widget _buildProgress() {
    return Container(
      padding:
          const EdgeInsets.all(18),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color:
              const Color(0xFFE7EBF2),
        ),
      ),
      child: Row(
        children: [
          _buildProgressCircle(
            number: '1',
            active: true,
          ),
          Expanded(
            child: Container(
              height: 2,
              color:
                  const Color(0xFFFFB300),
            ),
          ),
          _buildProgressCircle(
            number: '2',
            active: true,
          ),
          Expanded(
            child: Container(
              height: 2,
              color:
                  const Color(0xFFFFB300),
            ),
          ),
          _buildProgressCircle(
            number: '3',
            active: true,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCircle({
    required String number,
    required bool active,
  }) {
    return Container(
      width: 34,
      height: 34,
      decoration:
          BoxDecoration(
        shape: BoxShape.circle,
        color: active
            ? const Color(0xFFFFB300)
            : const Color(0xFFE7EBF2),
      ),
      alignment:
          Alignment.center,
      child: Text(
        number,
        style: TextStyle(
          fontWeight:
              FontWeight.bold,
          color: active
              ? Colors.white
              : const Color(
                  0xFF697386,
                ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // ACCOUNT SECTION
  // ------------------------------------------------------------

  Widget _buildAccountSection() {
    return _buildSectionCard(
      icon:
          Icons.person_outline_rounded,
      title: 'Account information',
      subtitle:
          'Create your RaySense account.',
      children: [
        _buildTextField(
          controller:
              _usernameController,
          label: 'Username',
          hint:
              'Choose a username',
          icon:
              Icons.person_outline_rounded,
          validator:
              _validateUsername,
          textInputAction:
              TextInputAction.next,
        ),
        const SizedBox(
          height: 16,
        ),
        _buildTextField(
          controller:
              _emailController,
          label: 'Email address',
          hint:
              'example@email.com',
          icon:
              Icons.email_outlined,
          validator:
              _validateEmail,
          keyboardType:
              TextInputType.emailAddress,
          textInputAction:
              TextInputAction.next,
        ),
        const SizedBox(
          height: 16,
        ),
        _buildTextField(
          controller:
              _passwordController,
          label: 'Password',
          hint:
              'Minimum 8 characters',
          icon:
              Icons.lock_outline_rounded,
          obscureText:
              _obscurePassword,
          suffixIcon:
              IconButton(
            onPressed: () {
              setState(() {
                _obscurePassword =
                    !_obscurePassword;
              });
            },
            icon: Icon(
              _obscurePassword
                  ? Icons
                      .visibility_outlined
                  : Icons
                      .visibility_off_outlined,
            ),
          ),
          validator:
              _validatePassword,
          textInputAction:
              TextInputAction.next,
        ),
        const SizedBox(
          height: 16,
        ),
        _buildTextField(
          controller:
              _confirmPasswordController,
          label:
              'Confirm password',
          hint:
              'Re-enter your password',
          icon:
              Icons.lock_reset_rounded,
          obscureText:
              _obscureConfirmPassword,
          suffixIcon:
              IconButton(
            onPressed: () {
              setState(() {
                _obscureConfirmPassword =
                    !_obscureConfirmPassword;
              });
            },
            icon: Icon(
              _obscureConfirmPassword
                  ? Icons
                      .visibility_outlined
                  : Icons
                      .visibility_off_outlined,
            ),
          ),
          validator:
              _validateConfirmPassword,
          textInputAction:
              TextInputAction.next,
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // SOLAR SECTION
  // ------------------------------------------------------------

  Widget _buildSolarSection() {
    return _buildSectionCard(
      icon:
          Icons.solar_power_rounded,
      title:
          'Solar system details',
      subtitle:
          'Enter the basic specifications of your installation.',
      children: [
        _buildTextField(
          controller:
              _systemNameController,
          label:
              'System name',
          hint:
              'e.g. Home Solar System',
          icon:
              Icons.home_work_outlined,
          validator: (value) {
            if (value == null ||
                value.trim().isEmpty) {
              return 'Please enter a system name';
            }
            return null;
          },
          textInputAction:
              TextInputAction.next,
        ),
        const SizedBox(
          height: 16,
        ),
        Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildTextField(
                controller:
                    _capacityController,
                label:
                    'Capacity',
                hint:
                    'e.g. 5.0',
                icon:
                    Icons.bolt_outlined,
                suffixText:
                    'kW',
                validator:
                    _validateCapacity,
                keyboardType:
                    const TextInputType
                        .numberWithOptions(
                  decimal: true,
                ),
                textInputAction:
                    TextInputAction.next,
              ),
            ),
            const SizedBox(
              width: 14,
            ),
            Expanded(
              child: _buildTextField(
                controller:
                    _panelCountController,
                label:
                    'Panel count',
                hint:
                    'e.g. 10',
                icon:
                    Icons.grid_view_rounded,
                suffixText:
                    'panels',
                validator:
                    _validatePanelCount,
                keyboardType:
                    TextInputType.number,
                textInputAction:
                    TextInputAction.next,
              ),
            ),
          ],
        ),
        const SizedBox(
          height: 16,
        ),
        _buildDropdown(
          value:
              _selectedPanelType,
          label:
              'Panel type',
          hint:
              'Select panel type',
          icon:
              Icons.view_module_outlined,
          items:
              _panelTypes,
          onChanged: (value) {
            setState(() {
              _selectedPanelType =
                  value;
            });
          },
          validator: (value) {
            if (value == null ||
                value.isEmpty) {
              return 'Please select the panel type';
            }
            return null;
          },
        ),
        const SizedBox(
          height: 16,
        ),
        InkWell(
          onTap:
              _selectInstallationDate,
          borderRadius:
              BorderRadius.circular(14),
          child: InputDecorator(
            decoration:
                _inputDecoration(
              label:
                  'Installation date',
              hint:
                  'Select installation date',
              icon:
                  Icons
                      .calendar_today_outlined,
            ),
            child: Text(
              _installationDate ==
                      null
                  ? 'Select installation date'
                  : _formatDateForDisplay(
                      _installationDate!,
                    ),
              style: TextStyle(
                fontSize: 15,
                color:
                    _installationDate ==
                            null
                        ? const Color(
                            0xFF9AA3B2,
                          )
                        : const Color(
                            0xFF172033,
                          ),
              ),
            ),
          ),
        ),
        if (_installationDate ==
            null)
          const Padding(
            padding:
                EdgeInsets.only(
              top: 8,
              left: 12,
            ),
            child: Text(
              'Please select the installation date',
              style: TextStyle(
                fontSize: 12,
                color:
                    Color(0xFFD32F2F),
              ),
            ),
          ),
      ],
    );
  }

  // ------------------------------------------------------------
  // LOCATION SECTION
  // ------------------------------------------------------------

  Widget _buildLocationSection() {
    return _buildSectionCard(
      icon:
          Icons.location_on_outlined,
      title:
          'Installation location',
      subtitle:
          'RaySense uses your device location to identify where your solar system is installed.',
      children: [
        Container(
          padding:
              const EdgeInsets.all(16),
          decoration:
              BoxDecoration(
            color:
                const Color(0xFFFFF8E7),
            borderRadius:
                BorderRadius.circular(16),
            border: Border.all(
              color:
                  const Color(0xFFFFE2A3),
            ),
          ),
          child: Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration:
                    BoxDecoration(
                  color:
                      const Color(0xFFFFB300),
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),
                child:
                    const Icon(
                  Icons
                      .my_location_rounded,
                  color:
                      Colors.white,
                ),
              ),
              const SizedBox(
                width: 12,
              ),
              const Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      'Use device location',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight:
                            FontWeight.bold,
                        color:
                            Color(0xFF172033),
                      ),
                    ),
                    SizedBox(
                      height: 4,
                    ),
                    Text(
                      'Your GPS coordinates will be used to identify the installation area and support weather-based forecasting.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color:
                            Color(0xFF697386),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(
          height: 14,
        ),
        SizedBox(
          height: 50,
          width: double.infinity,
          child:
              OutlinedButton.icon(
            onPressed:
                _isLoading ||
                        _isDetectingLocation
                    ? null
                    : _detectLocation,
            icon: _isDetectingLocation
                ? const SizedBox(
                    width: 19,
                    height: 19,
                    child:
                        CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : Icon(
                    _locationDetected
                        ? Icons
                            .check_circle_outline
                        : Icons
                            .my_location_rounded,
                  ),
            label: Text(
              _isDetectingLocation
                  ? 'Detecting location...'
                  : _locationDetected
                      ? 'Location detected'
                      : 'Detect my location',
            ),
            style:
                OutlinedButton.styleFrom(
              foregroundColor:
                  _locationDetected
                      ? const Color(
                          0xFF2E7D32,
                        )
                      : const Color(
                          0xFFF39C00,
                        ),
              side: BorderSide(
                color:
                    _locationDetected
                        ? const Color(
                            0xFF2E7D32,
                          )
                        : const Color(
                            0xFFFFB300,
                          ),
              ),
              shape:
                  RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(
                  14,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(
          height: 16,
        ),
        _buildTextField(
          controller:
              _locationController,
          label:
              'Readable location',
          hint:
              'Your detected address will appear here',
          icon:
              Icons.place_outlined,
          validator: (value) {
            if (value == null ||
                value.trim().isEmpty) {
              return 'Location is required';
            }
            return null;
          },
          readOnly:
              _locationDetected,
          textInputAction:
              TextInputAction.next,
        ),
        if (_locationDetected) ...[
          const SizedBox(
            height: 14,
          ),
          Row(
            children: [
              Expanded(
                child:
                    _buildCoordinateBox(
                  label:
                      'Latitude',
                  value:
                      _latitude?.toStringAsFixed(
                            6,
                          ) ??
                          '--',
                ),
              ),
              const SizedBox(
                width: 12,
              ),
              Expanded(
                child:
                    _buildCoordinateBox(
                  label:
                      'Longitude',
                  value:
                      _longitude?.toStringAsFixed(
                            6,
                          ) ??
                          '--',
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildCoordinateBox({
    required String label,
    required String value,
  }) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
      ),
      decoration:
          BoxDecoration(
        color:
            const Color(0xFFF7F9FC),
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color:
              const Color(0xFFE0E5ED),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color:
                  Color(0xFF697386),
            ),
          ),
          const SizedBox(
            height: 3,
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight:
                  FontWeight.w600,
              color:
                  Color(0xFF172033),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // ELECTRICITY SECTION
  // ------------------------------------------------------------

  Widget _buildElectricitySection() {
    return _buildSectionCard(
      icon:
          Icons.electric_bolt_outlined,
      title:
          'Electricity information',
      subtitle:
          'These details help RaySense estimate savings and understand your electricity usage context.',
      children: [
        _buildTextField(
          controller:
              _providerController,
          label:
              'Electricity provider',
          hint:
              'e.g. KSEB',
          icon:
              Icons
                  .account_balance_outlined,
          textInputAction:
              TextInputAction.next,
        ),
        const SizedBox(
          height: 16,
        ),
        _buildDropdown(
          value:
              _selectedConsumerCategory,
          label:
              'Consumer category',
          hint:
              'Select consumer category',
          icon:
              Icons.category_outlined,
          items:
              _consumerCategories,
          onChanged: (value) {
            setState(() {
              _selectedConsumerCategory =
                  value;
            });
          },
        ),
        const SizedBox(
          height: 12,
        ),
        Container(
          padding:
              const EdgeInsets.all(13),
          decoration:
              BoxDecoration(
            color:
                const Color(0xFFF7F9FC),
            borderRadius:
                BorderRadius.circular(12),
          ),
          child: const Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 19,
                color:
                    Color(0xFF697386),
              ),
              SizedBox(
                width: 9,
              ),
              Expanded(
                child: Text(
                  'You do not need to know your electricity rate. RaySense can determine applicable tariff information later from supported provider and bill data.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color:
                        Color(0xFF697386),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // BILL SECTION
  // ------------------------------------------------------------

  Widget _buildBillSection() {
    return _buildSectionCard(
      icon:
          Icons.receipt_long_outlined,
      title:
          'Latest electricity bill',
      subtitle:
          'Optional. Upload your latest bill to help RaySense obtain electricity information.',
      children: [
        InkWell(
          onTap:
              _isLoading
                  ? null
                  : _selectBillFile,
          borderRadius:
              BorderRadius.circular(16),
          child: Container(
            width:
                double.infinity,
            padding:
                const EdgeInsets.all(20),
            decoration:
                BoxDecoration(
              color:
                  const Color(0xFFF9FAFC),
              borderRadius:
                  BorderRadius.circular(16),
              border: Border.all(
                color:
                    const Color(0xFFD8DEE9),
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration:
                      BoxDecoration(
                    color:
                        const Color(0xFFFFF3D0),
                    borderRadius:
                        BorderRadius.circular(
                      16,
                    ),
                  ),
                  child:
                      const Icon(
                    Icons
                        .cloud_upload_outlined,
                    size: 28,
                    color:
                        Color(0xFFFFB300),
                  ),
                ),
                const SizedBox(
                  height: 12,
                ),
                Text(
                  _billFileName ??
                      'Upload electricity bill',
                  textAlign:
                      TextAlign.center,
                  style:
                      const TextStyle(
                    fontSize: 15,
                    fontWeight:
                        FontWeight.w600,
                    color:
                        Color(0xFF172033),
                  ),
                ),
                const SizedBox(
                  height: 5,
                ),
                const Text(
                  'PDF, JPG or PNG • Optional',
                  textAlign:
                      TextAlign.center,
                  style:
                      TextStyle(
                    fontSize: 12,
                    color:
                        Color(0xFF697386),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(
          height: 12,
        ),
        const Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.lock_outline_rounded,
              size: 17,
              color:
                  Color(0xFF697386),
            ),
            SizedBox(
              width: 8,
            ),
            Expanded(
              child: Text(
                'Your bill is optional. You can skip this step and provide electricity information later.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color:
                      Color(0xFF697386),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // REGISTER BUTTON
  // ------------------------------------------------------------

  Widget _buildRegisterButton() {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed:
            _isLoading
                ? null
                : _register,
        style:
            ElevatedButton.styleFrom(
          backgroundColor:
              const Color(0xFFFFB300),
          foregroundColor:
              Colors.white,
          disabledBackgroundColor:
              const Color(0xFFFFD77A),
          elevation: 0,
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(15),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 25,
                height: 25,
                child:
                    CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color:
                      Colors.white,
                ),
              )
            : const Row(
                mainAxisAlignment:
                    MainAxisAlignment
                        .center,
                children: [
                  Text(
                    'Create RaySense account',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                  SizedBox(
                    width: 9,
                  ),
                  Icon(
                    Icons
                        .arrow_forward_rounded,
                    size: 21,
                  ),
                ],
              ),
      ),
    );
  }

  // ------------------------------------------------------------
  // LOGIN LINK
  // ------------------------------------------------------------

  Widget _buildLoginLink() {
    return Row(
      mainAxisAlignment:
          MainAxisAlignment.center,
      children: [
        const Text(
          'Already have an account? ',
          style: TextStyle(
            fontSize: 14,
            color:
                Color(0xFF697386),
          ),
        ),
        TextButton(
          onPressed:
              _isLoading
                  ? null
                  : () {
                      Navigator.of(
                        context,
                      ).pop();
                    },
          child: const Text(
            'Login',
            style: TextStyle(
              color:
                  Color(0xFFF39C00),
              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------
  // SECTION CARD
  // ------------------------------------------------------------

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Container(
      padding:
          const EdgeInsets.all(20),
      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color:
              const Color(0xFFE7EBF2),
        ),
        boxShadow: const [
          BoxShadow(
            color:
                Color(0x08000000),
            blurRadius: 14,
            offset:
                Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration:
                    BoxDecoration(
                  color:
                      const Color(0xFFFFF3D0),
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),
                child:
                    Icon(
                  icon,
                  color:
                      const Color(0xFFFFB300),
                  size: 23,
                ),
              ),
              const SizedBox(
                width: 12,
              ),
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
                        color:
                            Color(0xFF172033),
                      ),
                    ),
                    const SizedBox(
                      height: 4,
                    ),
                    Text(
                      subtitle,
                      style:
                          const TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color:
                            Color(0xFF697386),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 20,
          ),
          ...children,
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // TEXT FIELD
  // ------------------------------------------------------------

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    bool obscureText = false,
    bool readOnly = false,
    Widget? suffixIcon,
    String? suffixText,
  }) {
    return TextFormField(
      controller:
          controller,
      validator:
          validator,
      keyboardType:
          keyboardType,
      textInputAction:
          textInputAction,
      obscureText:
          obscureText,
      readOnly:
          readOnly,
      style:
          const TextStyle(
        fontSize: 15,
        color:
            Color(0xFF172033),
      ),
      decoration:
          _inputDecoration(
        label:
            label,
        hint:
            hint,
        icon:
            icon,
        suffixIcon:
            suffixIcon,
        suffixText:
            suffixText,
      ),
    );
  }

  // ------------------------------------------------------------
  // DROPDOWN
  // ------------------------------------------------------------

  Widget _buildDropdown({
    required String? value,
    required String label,
    required String hint,
    required IconData icon,
    required List<String> items,
    required ValueChanged<String?>
        onChanged,
    String? Function(String?)?
        validator,
  }) {
    return DropdownButtonFormField<
        String>(
      initialValue: value,
      validator:
          validator,
      onChanged:
          _isLoading
              ? null
              : onChanged,
      decoration:
          _inputDecoration(
        label:
            label,
        hint:
            hint,
        icon:
            icon,
      ),
      items: items
          .map(
            (item) =>
                DropdownMenuItem<
                    String>(
              value: item,
              child: Text(item),
            ),
          )
          .toList(),
    );
  }

  // ------------------------------------------------------------
  // INPUT DECORATION
  // ------------------------------------------------------------

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
    String? suffixText,
  }) {
    return InputDecoration(
      labelText:
          label,
      hintText:
          hint,
      prefixIcon:
          Icon(icon),
      suffixIcon:
          suffixIcon,
      suffixText:
          suffixText,
      filled: true,
      fillColor:
          Colors.white,
      labelStyle:
          const TextStyle(
        color:
            Color(0xFF697386),
      ),
      hintStyle:
          const TextStyle(
        color:
            Color(0xFF9AA3B2),
        fontSize: 14,
      ),
      border:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(14),
        borderSide:
            const BorderSide(
          color:
              Color(0xFFD8DEE9),
        ),
      ),
      enabledBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(14),
        borderSide:
            const BorderSide(
          color:
              Color(0xFFD8DEE9),
        ),
      ),
      focusedBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(14),
        borderSide:
            const BorderSide(
          color:
              Color(0xFFFFB300),
          width: 2,
        ),
      ),
      errorBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(14),
        borderSide:
            const BorderSide(
          color:
              Color(0xFFD32F2F),
        ),
      ),
      focusedErrorBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(14),
        borderSide:
            const BorderSide(
          color:
              Color(0xFFD32F2F),
          width: 2,
        ),
      ),
      contentPadding:
          const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 17,
      ),
    );
  }
}




