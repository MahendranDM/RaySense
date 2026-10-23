import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

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

class _RegistrationScreenState extends State<RegistrationScreen> {
  static const Color bg = Color(0xFF050505);
  static const Color card = Color(0xFF111111);
  static const Color gold = Color(0xFFFFD166);
  static const Color yellow = Color(0xFFFFCA28);
  static const Color muted = Color(0xFF999999);

  final _formKey = GlobalKey<FormState>();

  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _phone = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _password2 = TextEditingController();

  final _systemName = TextEditingController();
  final _capacity = TextEditingController();
  final _panelCount = TextEditingController();
  final _installationDate = TextEditingController();

  final _location = TextEditingController();
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();

  final _provider = TextEditingController();

  String _panelType = 'Monocrystalline';
  String _consumerCategory = 'Domestic';

  bool _showPassword = false;
  bool _showPassword2 = false;
  bool _loading = false;
  bool _detectingLocation = false;

  String? _message;
  bool _messageError = true;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    _username.dispose();
    _email.dispose();
    _password.dispose();
    _password2.dispose();
    _systemName.dispose();
    _capacity.dispose();
    _panelCount.dispose();
    _installationDate.dispose();
    _location.dispose();
    _latitude.dispose();
    _longitude.dispose();
    _provider.dispose();
    super.dispose();
  }

  void _showMessage(String message, {bool error = true}) {
    setState(() {
      _message = message;
      _messageError = error;
    });
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required';
    }
    return null;
  }

  String? _number(String? value, {bool integer = false}) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required';
    }

    final number = integer
        ? int.tryParse(value.trim())
        : double.tryParse(value.trim());

    if (number == null || number <= 0) {
      return 'Enter a valid positive number';
    }

    return null;
  }

  InputDecoration _decoration(
    String hint, {
    IconData? icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF666666)),
      prefixIcon: icon == null
          ? null
          : Icon(icon, color: gold, size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFF171717),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 17,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(
          color: Color(0xFF383838),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(
          color: Color(0xFF383838),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(
          color: gold,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    required String hint,
    IconData? icon,
    TextInputType keyboardType = TextInputType.text,
    bool requiredField = true,
    bool obscure = false,
    Widget? suffix,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: RichText(
            text: TextSpan(
              text: label,
              style: const TextStyle(
                color: Color(0xFFD1D1D1),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              children: [
                if (requiredField)
                  const TextSpan(
                    text: ' *',
                    style: TextStyle(color: gold),
                  ),
              ],
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscure,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
          ),
          validator: validator ??
              (requiredField ? _required : null),
          decoration: _decoration(
            hint,
            icon: icon,
            suffix: suffix,
          ),
        ),
      ],
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFFD1D1D1),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        DropdownButtonFormField<String>(
          initialValue: value,
          dropdownColor: card,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
          ),
          decoration: _decoration('Select $label'),
          iconEnabledColor: gold,
          items: options.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(item),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _section({
    required int number,
    required String title,
    required String subtitle,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: gold.withValues(alpha: 0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 35,
                height: 35,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: yellow.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: gold.withValues(alpha: 0.25),
                  ),
                ),
                child: Text(
                  number.toString().padLeft(2, '0'),
                  style: const TextStyle(
                    color: gold,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Divider(color: Color(0xFF292929), height: 1),
          ),
          ...children.map(
            (child) => Padding(
              padding: const EdgeInsets.only(bottom: 17),
              child: child,
            ),
          ),
        ],
      ),
    );
  }

  Widget _responsiveGrid(List<Widget> children) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 600;

        if (!wide) {
          return Column(
            children: children
                .map(
                  (child) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: child,
                  ),
                )
                .toList(),
          );
        }

        final rows = <Widget>[];

        for (int i = 0; i < children.length; i += 2) {
          rows.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: children[i]),
                const SizedBox(width: 16),
                Expanded(
                  child: i + 1 < children.length
                      ? children[i + 1]
                      : const SizedBox(),
                ),
              ],
            ),
          );
        }

        return Column(children: rows);
      },
    );
  }

  Future<void> _detectLocation() async {
    setState(() => _detectingLocation = true);

    try {
      final enabled =
          await Geolocator.isLocationServiceEnabled();

      if (!enabled) {
        _showMessage(
          'Enable location services or enter your location and coordinates manually.',
        );
        return;
      }

      LocationPermission permission =
          await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showMessage(
          'Location permission was denied. Enter your location and coordinates manually.',
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition();

      _latitude.text = position.latitude.toStringAsFixed(7);
      _longitude.text = position.longitude.toStringAsFixed(7);

      String locationName =
          'Latitude ${position.latitude.toStringAsFixed(5)}, '
          'Longitude ${position.longitude.toStringAsFixed(5)}';

      try {

        // GPS coordinates are still saved if reverse lookup fails.
        // Location name can always be entered manually.
        // Keep the location request optional.
        // The server-side registration does not depend on this lookup.
        //
        // HTTP package is intentionally not added to this screen;
        // coordinates are available immediately.
        locationName = locationName;
      } catch (_) {
        // Keep the GPS coordinates.
      }

      if (!mounted) return;

      setState(() {
        if (_location.text.trim().isEmpty) {
          _location.text = locationName;
        }
      });

      _showMessage(
        'Location detected. Verify the location name before registering.',
        error: false,
      );
    } catch (e) {
      _showMessage(
        'Could not detect your location. Enter it manually.',
      );
    } finally {
      if (mounted) {
        setState(() => _detectingLocation = false);
      }
    }
  }

  Future<void> _register() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      _showMessage('Please correct the highlighted fields.');
      return;
    }

    if (_password.text != _password2.text) {
      _showMessage('Passwords do not match.');
      return;
    }

    final lat = double.tryParse(_latitude.text.trim());
    final lon = double.tryParse(_longitude.text.trim());

    if (lat == null || lon == null) {
      _showMessage(
        'Please detect your location or enter valid latitude and longitude.',
      );
      return;
    }

    if (lat < -90 || lat > 90 || lon < -180 || lon > 180) {
      _showMessage('Enter valid latitude and longitude values.');
      return;
    }

    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      final result = await ApiService.register(
        username: _username.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
        password2: _password2.text,
        systemName: _systemName.text.trim(),
        location: _location.text.trim(),
        latitude: lat,
        longitude: lon,
        capacityKw: double.parse(_capacity.text.trim()),
        panelCount: int.parse(_panelCount.text.trim()),
        panelType: _panelType,
        installationDate: _installationDate.text.trim(),
        provider: _provider.text.trim(),
        consumerCategory: _consumerCategory,
      );

      if (!mounted) return;

      _showMessage(
        result['message']?.toString() ??
            'Registration successful. You can now sign in.',
        error: false,
      );

      widget.onRegistrationSuccess?.call();

      await Future.delayed(const Duration(milliseconds: 1200));

      if (!mounted) return;

      // Return to the existing login screen in your app.
      Navigator.of(context).maybePop();
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Registration failed. Check your details and server connection.',
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: gold),
        title: const Row(
          children: [
            Icon(Icons.wb_sunny_rounded, color: yellow, size: 27),
            SizedBox(width: 10),
            Text(
              'RaySense',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: screenWidth < 600 ? 14 : 28,
          vertical: 24,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1050),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: Column(
                      children: [
                        Text(
                          '☀ START YOUR SOLAR JOURNEY',
                          style: TextStyle(
                            color: gold,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                        SizedBox(height: 18),
                        Text(
                          'Create your RaySense account.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            height: 1.2,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Add your solar system details to unlock monitoring, '
                          'weather intelligence, AI-powered forecasting '
                          'and performance analysis.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: muted,
                            height: 1.6,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  if (_message != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: _messageError
                            ? Colors.red.withValues(alpha: 0.10)
                            : yellow.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _messageError
                              ? Colors.redAccent.withValues(alpha: 0.5)
                              : gold.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        _message!,
                        style: TextStyle(
                          color: _messageError
                              ? Colors.redAccent
                              : gold,
                        ),
                      ),
                    ),
                  ],

                  _section(
                    number: 1,
                    title: 'Account Information',
                    subtitle: 'Your RaySense account',
                    children: [
                      _responsiveGrid([
                        _field(
                          label: 'First Name',
                          controller: _firstName,
                          hint: 'Your first name',
                          icon: Icons.person_outline,
                        ),
                        _field(
                          label: 'Last Name',
                          controller: _lastName,
                          hint: 'Your last name',
                          icon: Icons.person_outline,
                        ),
                        _field(
                          label: 'Phone Number',
                          controller: _phone,
                          hint: 'Your phone number',
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                        ),
                        _field(
                          label: 'Username',
                          controller: _username,
                          hint: 'Choose a username',
                          icon: Icons.account_circle_outlined,
                        ),
                        _field(
                          label: 'Email',
                          controller: _email,
                          hint: 'you@example.com',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Email is required';
                            }
                            if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                .hasMatch(value.trim())) {
                              return 'Enter a valid email';
                            }
                            return null;
                          },
                        ),
                        _field(
                          label: 'Password',
                          controller: _password,
                          hint: 'Minimum 8 characters',
                          icon: Icons.lock_outline,
                          obscure: !_showPassword,
                          suffix: IconButton(
                            onPressed: () {
                              setState(() {
                                _showPassword = !_showPassword;
                              });
                            },
                            icon: Icon(
                              _showPassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: gold,
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Password is required';
                            }
                            if (value.length < 8) {
                              return 'Use at least 8 characters';
                            }
                            return null;
                          },
                        ),
                        _field(
                          label: 'Confirm Password',
                          controller: _password2,
                          hint: 'Enter password again',
                          icon: Icons.lock_reset_outlined,
                          obscure: !_showPassword2,
                          suffix: IconButton(
                            onPressed: () {
                              setState(() {
                                _showPassword2 = !_showPassword2;
                              });
                            },
                            icon: Icon(
                              _showPassword2
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: gold,
                            ),
                          ),
                        ),
                      ]),
                    ],
                  ),

                  _section(
                    number: 2,
                    title: 'Solar System',
                    subtitle: 'System configuration',
                    children: [
                      _field(
                        label: 'System Name',
                        controller: _systemName,
                        hint: 'e.g. Home Solar System',
                        icon: Icons.solar_power,
                      ),
                      _responsiveGrid([
                        _field(
                          label: 'System Capacity (kW)',
                          controller: _capacity,
                          hint: 'e.g. 5',
                          icon: Icons.bolt,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (value) =>
                              _number(value),
                        ),
                        _field(
                          label: 'Number of Panels',
                          controller: _panelCount,
                          hint: 'e.g. 10',
                          icon: Icons.grid_view,
                          keyboardType: TextInputType.number,
                          validator: (value) =>
                              _number(value, integer: true),
                        ),
                        _dropdown(
                          label: 'Panel Type',
                          value: _panelType,
                          options: const [
                            'Monocrystalline',
                            'Polycrystalline',
                            'Thin Film',
                            'Other',
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _panelType = value);
                            }
                          },
                        ),
                        GestureDetector(
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(1990),
                              lastDate: DateTime.now(),
                              builder: (context, child) {
                                return Theme(
                                  data: ThemeData.dark().copyWith(
                                    colorScheme:
                                        const ColorScheme.dark(
                                      primary: yellow,
                                      surface: card,
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );

                            if (date != null) {
                              _installationDate.text =
                                  '${date.year.toString().padLeft(4, '0')}-'
                                  '${date.month.toString().padLeft(2, '0')}-'
                                  '${date.day.toString().padLeft(2, '0')}';
                            }
                          },
                          child: AbsorbPointer(
                            child: _field(
                              label: 'Installation Date',
                              controller: _installationDate,
                              hint: 'Select installation date',
                              icon: Icons.calendar_month_outlined,
                            ),
                          ),
                        ),
                      ]),
                    ],
                  ),

                  _section(
                    number: 3,
                    title: 'Location',
                    subtitle: 'Solar installation location',
                    children: [
                      _field(
                        label: 'Location',
                        controller: _location,
                        hint: 'e.g. Kochi, Kerala, India',
                        icon: Icons.location_on_outlined,
                      ),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: _detectingLocation
                              ? null
                              : _detectLocation,
                          icon: _detectingLocation
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: gold,
                                  ),
                                )
                              : const Icon(
                                  Icons.my_location,
                                  color: gold,
                                ),
                          label: Text(
                            _detectingLocation
                                ? 'Getting Location...'
                                : 'Use My Location',
                            style: const TextStyle(
                              color: gold,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: gold.withValues(alpha: 0.35),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(11),
                            ),
                          ),
                        ),
                      ),
                      const Text(
                        'You can enter the location manually or use your device location.',
                        style: TextStyle(
                          color: muted,
                          fontSize: 11,
                          height: 1.5,
                        ),
                      ),
                      _responsiveGrid([
                        _field(
                          label: 'Latitude',
                          controller: _latitude,
                          hint: 'e.g. 9.9312',
                          icon: Icons.map_outlined,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          validator: (value) {
                            final number = double.tryParse(
                              value?.trim() ?? '',
                            );
                            if (number == null ||
                                number < -90 ||
                                number > 90) {
                              return 'Enter valid latitude';
                            }
                            return null;
                          },
                        ),
                        _field(
                          label: 'Longitude',
                          controller: _longitude,
                          hint: 'e.g. 76.2673',
                          icon: Icons.public,
                          keyboardType:
                              const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          validator: (value) {
                            final number = double.tryParse(
                              value?.trim() ?? '',
                            );
                            if (number == null ||
                                number < -180 ||
                                number > 180) {
                              return 'Enter valid longitude';
                            }
                            return null;
                          },
                        ),
                      ]),
                    ],
                  ),

                  _section(
                    number: 4,
                    title: 'Electricity Information',
                    subtitle: 'Optional',
                    children: [
                      _responsiveGrid([
                        _field(
                          label: 'Electricity Provider',
                          controller: _provider,
                          hint: 'e.g. KSEB',
                          icon: Icons.electrical_services,
                          requiredField: false,
                        ),
                        _dropdown(
                          label: 'Consumer Category',
                          value: _consumerCategory,
                          options: const [
                            'Domestic',
                            'Commercial',
                            'Industrial',
                            'Other',
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(
                                () => _consumerCategory = value,
                              );
                            }
                          },
                        ),
                      ]),
                    ],
                  ),

                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: yellow,
                        foregroundColor: Colors.black,
                        disabledBackgroundColor:
                            yellow.withValues(alpha: 0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: _loading
                          ? const SizedBox(
                              height: 23,
                              width: 23,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : const Text(
                              'Create RaySense Account  →',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 15),

                  const Center(
                    child: Text(
                      'By creating an account, you agree to use RaySense '
                      'responsibly for solar energy monitoring and analysis.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF666666),
                        fontSize: 11,
                        height: 1.5,
                      ),
                    ),
                  ),

                  const SizedBox(height: 25),

                  const Center(
                    child: Text(
                      '© 2026 RaySense  •  AI  •  Solar Monitoring  •  Forecasting',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF666666),
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}