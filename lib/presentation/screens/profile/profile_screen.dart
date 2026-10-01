import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dosecare/core/constants/app_colors.dart';
import 'package:dosecare/core/constants/app_typography.dart';
import 'package:dosecare/core/auth/auth_service.dart';
import 'package:dosecare/core/notifications/notification_service.dart';
import 'package:dosecare/data/models/user_model.dart';
import 'package:dosecare/presentation/controllers/app_controller.dart';
import 'package:dosecare/presentation/widgets/dosecare_logo.dart';
import 'package:dosecare/presentation/screens/profile/caregiver_alerts_history_screen.dart';


class ProfileScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const ProfileScreen({super.key, this.onBack});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AppController _controller = AppController.instance;

  bool _notificationsEnabled = true;
  bool _remindersEnabled = true;
  bool _lowStockAlerts = true;
  bool _doseTakenAlerts = true;
  bool _caregiverSync = true;
  bool _dailyCaregiverReport = false;
  bool _emailDailyReport = false;
  bool _emailWeeklyReport = false;
  bool _appLockEnabled = false;
  String _alarmSound = 'Serene Bell';
  String? _deviceAlarmSoundUri;
  int _snoozeDuration = 10;
  bool _googleSignInInProgress = false;

  // ── Patient profile fields ──────────────────────────────────────────────────
  String _bloodGroup = '';
  String _doctorName = '';
  String _doctorPhone = '';
  String _doctorSpecialization = '';
  String _allergies = '';
  String _emergencyContact = '';
  // New extended fields
  String _maritalStatus = '';
  String _height = '';      // cm
  String _weight = '';      // kg
  String _occupation = '';
  List<String> _conditions = [];
  String _insuranceProvider = '';

  // ── Dropdown option lists ───────────────────────────────────────────────────
  static const List<String> _bloodGroups = ['A+', 'A−', 'B+', 'B−', 'O+', 'O−', 'AB+', 'AB−'];
  static const List<String> _maritalOptions = ['Married', 'Not Married'];
  static const List<String> _occupations = [
    'Student', 'Employed (Private)', 'Employed (Government)',
    'Self-Employed / Business', 'Homemaker', 'Retired', 'Unemployed', 'Other',
  ];
  static const List<String> _specializations = [
    'General Physician', 'Cardiologist', 'Diabetologist / Endocrinologist',
    'Neurologist', 'Pulmonologist', 'Gastroenterologist', 'Nephrologist',
    'Orthopedic Surgeon', 'Dermatologist', 'Psychiatrist',
    'Gynecologist / Obstetrician', 'Ophthalmologist', 'ENT Specialist',
    'Oncologist', 'Rheumatologist', 'Urologist', 'Other',
  ];
  static const List<String> _conditionOptions = [
    'Diabetes', 'Hypertension', 'Heart Disease', 'Asthma / COPD',
    'Thyroid Disorder', 'Kidney Disease', 'Liver Disease',
    'Arthritis / Joint Pain', 'Epilepsy / Seizures', 'Parkinson\'s Disease',
    'Alzheimer\'s / Dementia', 'Cancer', 'Anemia',
    'Anxiety / Depression', 'Migraine', 'Obesity',
    'High Cholesterol', 'Osteoporosis',
  ];
  static const Map<String, String> _countryCodes = {
    'India': '+91',
    'United States': '+1',
    'United Kingdom': '+44',
    'Australia': '+61',
    'UAE': '+971',
    'Singapore': '+65',
  };

  String _countryCodeFor(String phone) {
    final trimmed = phone.trim();
    return _countryCodes.values.firstWhere(
      (code) => trimmed.startsWith(code),
      orElse: () => '+91',
    );
  }

  String _nationalNumber(String phone, String code) {
    final trimmed = phone.trim();
    return trimmed.startsWith(code)
        ? trimmed.substring(code.length).trim()
        : trimmed;
  }

  Widget _countryCodePicker({
    required String value,
    required ValueChanged<String?> onChanged,
  }) {
    return SizedBox(
      width: 96,
      child: DropdownButtonFormField<String>(
        value: value,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Code',
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        ),
        // Keep the selected field compact, while the menu still shows the
        // matching country name to make choosing a code unambiguous.
        selectedItemBuilder: (context) => _countryCodes.values
            .map((code) => Align(
                  alignment: Alignment.centerLeft,
                  child: Text(code),
                ))
            .toList(),
        items: _countryCodes.entries
            .map(
              (entry) => DropdownMenuItem(
                value: entry.value,
                child: Text('${entry.value} ${entry.key}'),
              ),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onStateChange);
    _loadPrefs();
  }

  @override
  void dispose() {
    _controller.removeListener(_onStateChange);
    super.dispose();
  }

  void _onStateChange() {
    if (mounted) setState(() {});
  }

  Future<void> _signInWithGoogle() async {
    if (_googleSignInInProgress) return;

    setState(() => _googleSignInInProgress = true);
    try {
      final credential = await AuthService.instance.signInWithGoogle();
      if (!mounted || credential == null) return;
      final profileWasPrefilled = await _prefillProfileFromGoogle(
        credential.user?.displayName,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            profileWasPrefilled
                ? 'Signed in and added your Google name to your profile.'
                : 'Signed in as ${credential.user?.email ?? 'your Google account'}.',
          ),
          backgroundColor: AppColors.adherenceGreenText,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Google sign-in failed. Please try again.'),
          backgroundColor: AppColors.alertCoral,
        ),
      );
    } finally {
      if (mounted) setState(() => _googleSignInInProgress = false);
    }
  }

  /// Google only shares basic account information. Seed a new local profile
  /// with the account name, but never replace a name the patient has saved.
  Future<bool> _prefillProfileFromGoogle(String? googleDisplayName) async {
    final name = googleDisplayName?.trim() ?? '';
    final current = _controller.user;
    final hasSavedName = current != null &&
        current.name.trim().isNotEmpty &&
        current.name.trim().toLowerCase() != 'user';
    if (name.isEmpty || hasSavedName) return false;

    await _controller.updateUserProfile(
      (current ??
              UserModel(
                name: '',
                age: 0,
                gender: '',
                createdAt: DateTime.now().toIso8601String(),
              ))
          .copyWith(name: name),
    );
    return true;
  }

  Future<void> _signOutOfGoogle() async {
    try {
      await AuthService.instance.signOut();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Signed out of Google.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not sign out. Please try again.'),
          backgroundColor: AppColors.alertCoral,
        ),
      );
    }
  }

  Widget _googleAccountCard() {
    return StreamBuilder(
      stream: AuthService.instance.authStateChanges,
      builder: (context, snapshot) {
        final firebaseUser = snapshot.data;
        final signedIn = firebaseUser != null;
        final accountName = firebaseUser?.displayName?.trim();
        final photoUrl = firebaseUser?.photoURL?.trim();
        final initial = (accountName?.isNotEmpty ?? false)
            ? accountName![0].toUpperCase()
            : 'G';

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: signedIn
                    ? AppColors.primaryFixed
                    : AppColors.surfaceContainerHigh,
                backgroundImage: photoUrl?.isNotEmpty == true
                    ? NetworkImage(photoUrl!)
                    : null,
                child: photoUrl?.isNotEmpty == true
                    ? null
                    : Text(
                        initial,
                        style: AppTypography.titleMd(color: AppColors.primary)
                            .copyWith(fontWeight: FontWeight.bold),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      signedIn ? 'Google account connected' : 'Back up with Google',
                      style: AppTypography.labelMd(color: AppColors.onSurface)
                          .copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      signedIn
                          ? firebaseUser!.email ?? 'Signed in to Firebase'
                          : 'Sign in securely with your Google account.',
                      style: AppTypography.bodySm(color: AppColors.onSurfaceVariant),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (signedIn)
                TextButton(
                  onPressed: _signOutOfGoogle,
                  child: const Text('Sign out'),
                )
              else
                ElevatedButton(
                  onPressed: _googleSignInInProgress ? null : _signInWithGoogle,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _googleSignInInProgress
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Sign in'),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _bloodGroup = prefs.getString('patient_blood_group') ?? '';
      _doctorName = prefs.getString('patient_doctor_name') ?? '';
      _doctorPhone = prefs.getString('patient_doctor_phone') ?? '';
      _doctorSpecialization = prefs.getString('patient_doctor_specialization') ?? '';
      _allergies = prefs.getString('patient_allergies') ?? '';
      _emergencyContact = prefs.getString('patient_emergency_contact') ?? '';
      _maritalStatus = prefs.getString('patient_marital_status') ?? '';
      _height = prefs.getString('patient_height') ?? '';
      _weight = prefs.getString('patient_weight') ?? '';
      _occupation = prefs.getString('patient_occupation') ?? '';
      _conditions = prefs.getStringList('patient_conditions') ?? [];
      _insuranceProvider = prefs.getString('patient_insurance') ?? '';
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _remindersEnabled = prefs.getBool('reminders_enabled') ?? true;
      _lowStockAlerts = prefs.getBool('low_stock_alerts') ?? true;
      _doseTakenAlerts = prefs.getBool('dose_taken_alerts') ?? true;
      _caregiverSync = prefs.getBool('caregiver_alerts_enabled') ?? false;
      _dailyCaregiverReport = prefs.getBool('daily_caregiver_report_enabled') ?? false;
      _emailDailyReport = prefs.getBool('caregiver_email_daily_enabled') ?? false;
      _emailWeeklyReport = prefs.getBool('caregiver_email_weekly_enabled') ?? false;
      _appLockEnabled = prefs.getBool('app_lock_enabled') ?? false;
      _alarmSound = prefs.getString('alarm_sound') ?? 'Device alarm tone';
      _deviceAlarmSoundUri = prefs.getString('device_alarm_sound_uri');
      if (_deviceAlarmSoundUri?.isEmpty ?? true) _deviceAlarmSoundUri = null;
      _snoozeDuration = prefs.getInt('snooze_duration') ?? 10;
    });
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('patient_blood_group', _bloodGroup);
    await prefs.setString('patient_doctor_name', _doctorName);
    await prefs.setString('patient_doctor_phone', _doctorPhone);
    await prefs.setString('patient_doctor_specialization', _doctorSpecialization);
    await prefs.setString('patient_allergies', _allergies);
    await prefs.setString('patient_emergency_contact', _emergencyContact);
    await prefs.setString('patient_marital_status', _maritalStatus);
    await prefs.setString('patient_height', _height);
    await prefs.setString('patient_weight', _weight);
    await prefs.setString('patient_occupation', _occupation);
    await prefs.setStringList('patient_conditions', _conditions);
    await prefs.setString('patient_insurance', _insuranceProvider);
    await prefs.setBool('notifications_enabled', _notificationsEnabled);
    await prefs.setBool('reminders_enabled', _remindersEnabled);
    await prefs.setBool('low_stock_alerts', _lowStockAlerts);
    await prefs.setBool('dose_taken_alerts', _doseTakenAlerts);
    await prefs.setBool('caregiver_alerts_enabled', _caregiverSync);
    await prefs.setBool('daily_caregiver_report_enabled', _dailyCaregiverReport);
    await prefs.setBool('caregiver_email_daily_enabled', _emailDailyReport);
    await prefs.setBool('caregiver_email_weekly_enabled', _emailWeeklyReport);
    await prefs.setBool('app_lock_enabled', _appLockEnabled);
    await prefs.setString('alarm_sound', _alarmSound);
    await prefs.setString('device_alarm_sound_uri', _deviceAlarmSoundUri ?? '');
    await prefs.setInt('snooze_duration', _snoozeDuration);
  }

  void _showEditProfileDialog() {
    final current = _controller.user;
    final currentName = (current?.name != null && current!.name != 'User' && current.name.isNotEmpty)
        ? current.name
        : '';

    final nameCtrl = TextEditingController(text: currentName);
    final ageCtrl = TextEditingController(text: (current?.age != null && current!.age > 0) ? current.age.toString() : '');
    final caregiverPhoneCtrl = TextEditingController(
        text: (current?.caregiverPhone != null && current!.caregiverPhone!.isNotEmpty)
            ? current.caregiverPhone
            : _emergencyContact);
    final caregiverEmailCtrl = TextEditingController(
        text: (current?.caregiverEmail != null && current!.caregiverEmail!.isNotEmpty)
            ? current.caregiverEmail
            : '');
    final allergiesCtrl = TextEditingController(text: _allergies);
    final doctorCtrl = TextEditingController(text: _doctorName);
    final doctorPhoneCtrl = TextEditingController(text: _doctorPhone);
    final heightCtrl = TextEditingController(text: _height);
    final weightCtrl = TextEditingController(text: _weight);
    final insuranceCtrl = TextEditingController(text: _insuranceProvider);
    final customConditionCtrl = TextEditingController();

    String? localGender = const ['Male', 'Female', 'Other'].contains(current?.gender) ? current!.gender : null;
    String? localBloodGroup = _bloodGroups.contains(_bloodGroup) ? _bloodGroup : null;
    String? localMarital = _maritalOptions.contains(_maritalStatus) ? _maritalStatus : null;
    String? localOccupation = _occupations.contains(_occupation) ? _occupation : null;
    String? localSpecialization = _specializations.contains(_doctorSpecialization) ? _doctorSpecialization : null;
    List<String> localConditions = List.from(_conditions);
    bool showCustomConditionInput = false;
    String caregiverCountryCode = _countryCodeFor(caregiverPhoneCtrl.text);
    caregiverPhoneCtrl.text =
        _nationalNumber(caregiverPhoneCtrl.text, caregiverCountryCode);
    String doctorCountryCode = _countryCodeFor(doctorPhoneCtrl.text);
    doctorPhoneCtrl.text = _nationalNumber(doctorPhoneCtrl.text, doctorCountryCode);

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.badge_rounded, color: AppColors.primary),
              const SizedBox(width: 8),
              const Expanded(child: Text('Edit Patient Profile', overflow: TextOverflow.ellipsis)),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Section 1: Personal ─────────────────────────────────────
                  _dlgSection('Personal Information', Icons.person_outline_rounded),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Patient Full Name *', hintText: 'Enter your full name', isDense: true),
                  ),
                  const SizedBox(height: 10),

                  // Age + Gender row
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: ageCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Age', hintText: '25', isDense: true),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: localGender,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Gender', isDense: true),
                          hint: const Text('Select', style: TextStyle(fontSize: 13)),
                          items: const [
                            DropdownMenuItem(value: 'Male', child: Text('Male')),
                            DropdownMenuItem(value: 'Female', child: Text('Female')),
                            DropdownMenuItem(value: 'Other', child: Text('Other')),
                          ],
                          onChanged: (v) => setDlgState(() => localGender = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Blood Group + Marital Status row
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: localBloodGroup,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Blood Group', isDense: true),
                          hint: const Text('Select', style: TextStyle(fontSize: 13)),
                          items: _bloodGroups
                              .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                              .toList(),
                          onChanged: (v) => setDlgState(() => localBloodGroup = v),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: localMarital,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Marital Status', isDense: true),
                          hint: const Text('Select', style: TextStyle(fontSize: 13)),
                          items: _maritalOptions
                              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                              .toList(),
                          onChanged: (v) => setDlgState(() => localMarital = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Height + Weight row
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: heightCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Height (cm)', hintText: '165', isDense: true),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: weightCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Weight (kg)', hintText: '65', isDense: true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Occupation
                  DropdownButtonFormField<String>(
                    value: localOccupation,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Occupation', isDense: true),
                    hint: const Text('Select occupation', style: TextStyle(fontSize: 13)),
                    items: _occupations
                        .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                        .toList(),
                    onChanged: (v) => setDlgState(() => localOccupation = v),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),

                  // ── Section 2: Chronic Conditions ───────────────────────────
                  _dlgSection('Chronic Conditions', Icons.favorite_border_rounded),
                  const SizedBox(height: 4),
                  Text('Tap to select all that apply:', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: _conditionOptions.map((cond) {
                      final selected = localConditions.contains(cond);
                      return FilterChip(
                        label: Text(cond, style: TextStyle(fontSize: 12, color: selected ? Colors.white : AppColors.onSurface)),
                        selected: selected,
                        selectedColor: AppColors.primary,
                        checkmarkColor: Colors.white,
                        backgroundColor: AppColors.surfaceContainerLow,
                        side: BorderSide(color: selected ? AppColors.primary : AppColors.outlineVariant),
                        onSelected: (val) {
                          setDlgState(() {
                            if (val) {
                              localConditions.add(cond);
                            } else {
                              localConditions.remove(cond);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  ActionChip(
                    avatar: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add custom condition'),
                    onPressed: () =>
                        setDlgState(() => showCustomConditionInput = true),
                  ),
                  if (showCustomConditionInput) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: customConditionCtrl,
                            autofocus: true,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Condition name',
                              hintText: 'e.g. Psoriasis',
                              isDense: true,
                            ),
                            onSubmitted: (value) {
                              final condition = value.trim();
                              if (condition.isEmpty) return;
                              setDlgState(() {
                                if (!localConditions.any(
                                  (item) => item.toLowerCase() == condition.toLowerCase(),
                                )) {
                                  localConditions.add(condition);
                                }
                              });
                              // Keep the focused field mounted during submission.
                              // Removing an autofocus TextField here can leave Flutter
                              // with stale inherited-widget dependents.
                              customConditionCtrl.clear();
                            },
                          ),
                        ),
                        IconButton(
                          tooltip: 'Add condition',
                          icon: const Icon(Icons.check_rounded),
                          color: AppColors.primary,
                          onPressed: () {
                            final condition = customConditionCtrl.text.trim();
                            if (condition.isEmpty) return;
                            setDlgState(() {
                              if (!localConditions.any(
                                (item) => item.toLowerCase() == condition.toLowerCase(),
                              )) {
                                localConditions.add(condition);
                              }
                            });
                            customConditionCtrl.clear();
                          },
                        ),
                        IconButton(
                          tooltip: 'Cancel',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => setDlgState(() {
                            customConditionCtrl.clear();
                            showCustomConditionInput = false;
                          }),
                        ),
                      ],
                    ),
                  ],
                  if (localConditions.any(
                    (condition) => !_conditionOptions.contains(condition),
                  )) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: localConditions
                          .where((condition) => !_conditionOptions.contains(condition))
                          .map(
                            (condition) => InputChip(
                              label: Text(condition),
                              onDeleted: () => setDlgState(
                                () => localConditions.remove(condition),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Divider(),

                  // ── Section 3: Doctor & Medical ─────────────────────────────
                  _dlgSection('Doctor & Medical Details', Icons.medical_services_outlined),
                  const SizedBox(height: 8),
                  TextField(
                    controller: doctorCtrl,
                    decoration: const InputDecoration(labelText: 'Primary Doctor Name', hintText: 'Dr. Sharma', isDense: true),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: localSpecialization,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Doctor Specialization', isDense: true),
                    hint: const Text('Select specialization', style: TextStyle(fontSize: 13)),
                    items: _specializations
                        .map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (v) => setDlgState(() => localSpecialization = v),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _countryCodePicker(
                        value: doctorCountryCode,
                        onChanged: (value) =>
                            setDlgState(() => doctorCountryCode = value!),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: doctorPhoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Doctor / Clinic Phone',
                            hintText: '98765 43210',
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: allergiesCtrl,
                    decoration: const InputDecoration(labelText: 'Known Allergies', hintText: 'e.g. Penicillin, Dust (or None)', isDense: true),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: insuranceCtrl,
                    decoration: const InputDecoration(labelText: 'Insurance Provider', hintText: 'e.g. Star Health, PMJAY, None', isDense: true),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),

                  // ── Section 4: Caregiver ────────────────────────────────────
                  _dlgSection('Caregiver & Emergency Contact', Icons.supervisor_account_rounded),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _countryCodePicker(
                        value: caregiverCountryCode,
                        onChanged: (value) =>
                            setDlgState(() => caregiverCountryCode = value!),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: caregiverPhoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Caregiver / Emergency Phone',
                            hintText: '98765 43210',
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: caregiverEmailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Caregiver Email', hintText: 'caregiver@example.com', isDense: true),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final newName = nameCtrl.text.trim();
                if (newName.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Please enter your name')),
                  );
                  return;
                }
                final newAge = int.tryParse(ageCtrl.text) ?? 0;
                final updated = UserModel(
                  id: current?.id ?? 1,
                  name: newName,
                  age: newAge,
                  gender: localGender ?? 'Not specified',
                  caregiverEmail: caregiverEmailCtrl.text.trim(),
                  caregiverPhone: caregiverPhoneCtrl.text.trim().isEmpty
                      ? ''
                      : '$caregiverCountryCode ${caregiverPhoneCtrl.text.trim()}',
                  appLockPin: current?.appLockPin ?? '',
                  createdAt: current?.createdAt ?? DateTime.now().toIso8601String(),
                );

                final pendingCondition = customConditionCtrl.text.trim();
                if (pendingCondition.isNotEmpty &&
                    !localConditions.any(
                      (item) => item.toLowerCase() == pendingCondition.toLowerCase(),
                    )) {
                  localConditions.add(pendingCondition);
                }

                final savedBloodGroup = localBloodGroup ?? '';
                final savedMaritalStatus = localMarital ?? '';
                final savedHeight = heightCtrl.text.trim();
                final savedWeight = weightCtrl.text.trim();
                final savedOccupation = localOccupation ?? '';
                final savedConditions = List<String>.from(localConditions);
                final savedDoctorName = doctorCtrl.text.trim();
                final savedSpecialization = localSpecialization ?? '';
                final savedDoctorPhone = doctorPhoneCtrl.text.trim().isEmpty
                    ? ''
                    : '$doctorCountryCode ${doctorPhoneCtrl.text.trim()}';
                final savedAllergies = allergiesCtrl.text.trim();
                final savedInsuranceProvider = insuranceCtrl.text.trim();
                final savedEmergencyContact = caregiverPhoneCtrl.text.trim().isEmpty
                    ? ''
                    : '$caregiverCountryCode ${caregiverPhoneCtrl.text.trim()}';

                // The controller refresh notifies ProfileScreen listeners. Close the
                // dialog before that rebuild so its inherited widgets are not removed
                // while the dialog still depends on them.
                Navigator.of(ctx).pop();
                if (!mounted) return;

                setState(() {
                  _bloodGroup = savedBloodGroup;
                  _maritalStatus = savedMaritalStatus;
                  _height = savedHeight;
                  _weight = savedWeight;
                  _occupation = savedOccupation;
                  _conditions = savedConditions;
                  _doctorName = savedDoctorName;
                  _doctorSpecialization = savedSpecialization;
                  _doctorPhone = savedDoctorPhone;
                  _allergies = savedAllergies;
                  _insuranceProvider = savedInsuranceProvider;
                  _emergencyContact = savedEmergencyContact;
                });
                await _savePrefs();
                await _controller.updateUserProfile(updated);

                if (!mounted) return;
                if (mounted) {
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✓ Patient Profile saved successfully!'),
                      backgroundColor: AppColors.primary,
                    ),
                  );
                }
              },
              child: const Text('Save Profile'),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      // showDialog's future resolves as soon as Navigator.pop() runs, which is
      // before the dialog's exit transition finishes playing. Disposing these
      // controllers immediately can race with that still-animating subtree
      // (especially since Save also triggers a controller-wide notifyListeners
      // rebuild in the same frame), throwing "TextEditingController used after
      // being disposed". Wait out the transition first.
      Future.delayed(const Duration(milliseconds: 300), () {
        nameCtrl.dispose();
        ageCtrl.dispose();
        caregiverPhoneCtrl.dispose();
        caregiverEmailCtrl.dispose();
        allergiesCtrl.dispose();
        doctorCtrl.dispose();
        doctorPhoneCtrl.dispose();
        heightCtrl.dispose();
        weightCtrl.dispose();
        insuranceCtrl.dispose();
        customConditionCtrl.dispose();
      });
    });
  }

  /// Ensures a caregiver email address and Gmail credentials are both set
  /// before an "Email Daily/Weekly Report" toggle is allowed to turn on.
  Future<bool> _requireCaregiverEmailReady() async {
    final caregiverEmail = _controller.user?.caregiverEmail?.trim() ?? '';
    if (caregiverEmail.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add a caregiver email in your profile first.')),
        );
      }
      return false;
    }
    return true;
  }

  void _showConfigureCaregiverEmailDialog() async {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('DoseCare Email Reports'),
        content: const Text(
          'The sender is securely managed by DoseCare through Firebase. '
          'Add the caregiver email in Edit Profile, sign in with Google, '
          'and turn on the report toggle. No Gmail password is required.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
    return;

    // Kept below temporarily for source compatibility with older installs.
    final existingAddress = await _controller.getCaregiverEmailSenderAddress();
    if (!mounted) return;
    final addressCtrl = TextEditingController(text: existingAddress ?? '');
    final passwordCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.mail_outline_rounded, color: AppColors.primary),
            const SizedBox(width: 8),
            const Expanded(child: Text('Configure Caregiver Email', overflow: TextOverflow.ellipsis)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DoseCare sends the PDF reports through your own Gmail account, branded as "DoseCare" in the sender name. '
                'Use a Google App Password, not your regular Gmail password — generate one at myaccount.google.com/apppasswords '
                '(requires 2-Step Verification to be enabled).',
                style: AppTypography.bodySm(color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: addressCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Your Gmail address', hintText: 'you@gmail.com', isDense: true),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: passwordCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Google App Password',
                  hintText: existingAddress != null && existingAddress.isNotEmpty ? 'Leave blank to keep the saved password' : '16-character app password',
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () async {
              final address = addressCtrl.text.trim();
              final password = passwordCtrl.text.trim();
              if (address.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Enter a Gmail address.')),
                );
                return;
              }
              if (password.isEmpty && (existingAddress == null || existingAddress.isEmpty)) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Enter your Google App Password.')),
                );
                return;
              }
              final messenger = ScaffoldMessenger.of(context);
              Navigator.of(ctx).pop();
              if (password.isNotEmpty) {
                await _controller.saveCaregiverEmailCredentials(address, password);
              } else {
                await _controller.saveCaregiverEmailAddressOnly(address);
              }
              if (mounted) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('✓ Caregiver email settings saved'), backgroundColor: AppColors.primary),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ).whenComplete(() {
      Future.delayed(const Duration(milliseconds: 300), () {
        addressCtrl.dispose();
        passwordCtrl.dispose();
      });
    });
  }

  /// Helper for section headers inside the edit dialog.
  Widget _dlgSection(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 6),
        Text(title, style: AppTypography.labelSm(color: AppColors.primary).copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _infoChip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: AppTypography.labelSm(color: color).copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmWipeData() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete All Data?'),
        content: const Text(
          'This will reset medications, schedules, and dose logs to a clean state.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.alertCoral),
            onPressed: () async {
              Navigator.pop(ctx);
              await _controller.clearAllData();
              if (mounted) {
                await _loadPrefs();
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All data wiped successfully. Clean state restored.'),
                    backgroundColor: AppColors.alertCoral,
                  ),
                );
              }
            },
            child: const Text('Delete Everything', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _controller.user;
    final hasProfile = user?.name != null && user!.name != 'User' && user.name.isNotEmpty;
    final displayName = hasProfile ? user.name : null;
    final age = user?.age ?? 0;
    final gender = (user?.gender != null && user!.gender != 'Not specified') ? user.gender : null;
    final caregiverPhone = (user?.caregiverPhone != null && user!.caregiverPhone!.isNotEmpty)
        ? user.caregiverPhone!
        : _emergencyContact;
    final caregiverEmail = (user?.caregiverEmail != null && user!.caregiverEmail!.isNotEmpty)
        ? user.caregiverEmail!
        : null;

    final totalMeds = _controller.medicines.length;
    final streak = _controller.adherenceStats['streakDays'] ?? 0;
    final adherenceRate = _controller.adherenceStats['adherenceRate'] ?? 0;
    final historyCount = _controller.allHistoryLogs.length;

    // BMI calculation
    final heightCm = double.tryParse(_height);
    final weightKg = double.tryParse(_weight);
    String? bmiStr;
    String? bmiLabel;
    if (heightCm != null && heightCm > 0 && weightKg != null && weightKg > 0) {
      final bmi = weightKg / ((heightCm / 100) * (heightCm / 100));
      bmiStr = bmi.toStringAsFixed(1);
      if (bmi < 18.5) {
        bmiLabel = 'Underweight';
      } else if (bmi < 25) {
        bmiLabel = 'Normal';
      } else if (bmi < 30) {
        bmiLabel = 'Overweight';
      } else {
        bmiLabel = 'Obese';
      }
    }

    final profileFieldsCompleted = [
      displayName,
      if (_bloodGroup.isNotEmpty) _bloodGroup,
      if (_doctorName.isNotEmpty) _doctorName,
      if (_allergies.isNotEmpty) _allergies,
      if (caregiverPhone.isNotEmpty) caregiverPhone,
      if (_maritalStatus.isNotEmpty) _maritalStatus,
      if (_height.isNotEmpty) _height,
      if (_conditions.isNotEmpty) _conditions,
      if (_occupation.isNotEmpty) _occupation,
    ].length;

    return Scaffold(
      appBar: AppBar(
        leading: widget.onBack != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: widget.onBack,
              )
            : null,
        title: Text(
          'Profile & Settings',
          style: AppTypography.headlineSm(color: AppColors.primary).copyWith(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note_rounded, color: AppColors.primary, size: 26),
            tooltip: 'Edit Profile',
            onPressed: _showEditProfileDialog,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Patient Medical ID & Profile Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.4)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: AppColors.primaryFixed,
                            child: const Icon(Icons.person_rounded, size: 36, color: AppColors.primary),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: AppColors.adherenceGreen,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.check, color: Colors.white, size: 10),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName ?? 'Personal Profile',
                              style: AppTypography.headlineSm(color: AppColors.onSurface).copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              displayName != null
                                  ? [
                                      if (age > 0) 'Age $age',
                                      ?gender,
                                      if (_bloodGroup.isNotEmpty) _bloodGroup,
                                      if (_maritalStatus.isNotEmpty) _maritalStatus,
                                    ].join(' · ')
                                  : 'No details added yet',
                              style: AppTypography.bodySm(
                                color: displayName != null ? AppColors.onSurfaceVariant : AppColors.outline,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: Icon(displayName != null ? Icons.edit_rounded : Icons.person_add_rounded, size: 14),
                        label: Text(
                          displayName != null ? 'Edit' : 'Add Details',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        onPressed: _showEditProfileDialog,
                      ),
                    ],
                  ),
                  if (bmiStr != null || _occupation.isNotEmpty || _height.isNotEmpty || _weight.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (_height.isNotEmpty || _weight.isNotEmpty)
                          _infoChip(
                            [
                              if (_height.isNotEmpty) '$_height cm',
                              if (_weight.isNotEmpty) '$_weight kg',
                            ].join(' · '),
                            Icons.straighten_rounded,
                            AppColors.primary,
                          ),
                        if (bmiStr != null)
                          _infoChip(
                            'BMI $bmiStr ($bmiLabel)',
                            Icons.monitor_weight_outlined,
                            bmiLabel == 'Normal' ? AppColors.adherenceGreenText : AppColors.alertCoral,
                          ),
                        if (_occupation.isNotEmpty)
                          _infoChip(
                            _occupation,
                            Icons.work_outline_rounded,
                            AppColors.onSurfaceVariant,
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 14),

                  // Doctor & Clinic Row (interactive tap-to-add)
                  InkWell(
                    onTap: _showEditProfileDialog,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.medical_services_outlined, size: 18, color: AppColors.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Primary Physician', style: AppTypography.labelSm(color: AppColors.outline).copyWith(fontSize: 11)),
                                Text(
                                  _doctorName.isNotEmpty
                                      ? [
                                          _doctorName,
                                          if (_doctorSpecialization.isNotEmpty) _doctorSpecialization,
                                          if (_doctorPhone.isNotEmpty) _doctorPhone,
                                        ].join(' · ')
                                      : 'Tap to add doctor & clinic details',
                                  style: AppTypography.labelMd(
                                    color: _doctorName.isNotEmpty ? AppColors.onSurface : AppColors.outline,
                                  ).copyWith(fontWeight: _doctorName.isNotEmpty ? FontWeight.w600 : FontWeight.normal),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.outline),
                        ],
                      ),
                    ),
                  ),

                  // Caregiver Row (interactive tap-to-add)
                  InkWell(
                    onTap: _showEditProfileDialog,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.supervisor_account_rounded, size: 18, color: AppColors.secondary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Caregiver & Emergency Contact', style: AppTypography.labelSm(color: AppColors.outline).copyWith(fontSize: 11)),
                                Text(
                                  caregiverPhone.isNotEmpty
                                      ? ([caregiverPhone, if (caregiverEmail != null && caregiverEmail.isNotEmpty) caregiverEmail].join(' · '))
                                      : 'Tap to add emergency phone & email',
                                  style: AppTypography.labelMd(
                                    color: caregiverPhone.isNotEmpty ? AppColors.onSurface : AppColors.outline,
                                  ).copyWith(fontWeight: caregiverPhone.isNotEmpty ? FontWeight.w600 : FontWeight.normal),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.outline),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),

                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.health_and_safety_outlined, color: AppColors.primary, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            profileFieldsCompleted >= 5
                                ? 'Your medical profile is ready for quick reference.'
                                : 'Add medical details so this screen is useful in an emergency.',
                            style: AppTypography.bodySm(color: AppColors.onSurfaceVariant),
                          ),
                        ),
                        TextButton(
                          onPressed: _showEditProfileDialog,
                          child: Text(profileFieldsCompleted >= 5 ? 'Review' : 'Complete'),
                        ),
                      ],
                    ),
                  ),

                  // Insurance row
                  if (_insuranceProvider.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.shield_outlined, size: 18, color: AppColors.secondary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Health Insurance', style: AppTypography.labelSm(color: AppColors.outline).copyWith(fontSize: 11)),
                              Text(_insuranceProvider, style: AppTypography.labelMd(color: AppColors.onSurface).copyWith(fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Known Allergies
                  if (_allergies.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.alertCoral),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Allergies & Sensitivities', style: AppTypography.labelSm(color: AppColors.outline).copyWith(fontSize: 11)),
                              Text(_allergies, style: AppTypography.labelMd(color: AppColors.onSurface).copyWith(fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Chronic Conditions chips
                  if (_conditions.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.favorite_border_rounded, size: 18, color: AppColors.alertCoral),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Chronic Conditions', style: AppTypography.labelSm(color: AppColors.outline).copyWith(fontSize: 11)),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: _conditions.map((c) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.alertCoral.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: AppColors.alertCoral.withValues(alpha: 0.3)),
                                  ),
                                  child: Text(c, style: AppTypography.labelSm(color: AppColors.alertCoral).copyWith(fontSize: 11)),
                                )).toList(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ] else if (!_allergies.isNotEmpty && displayName == null) ...[
                    Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.outline),
                        const SizedBox(width: 10),
                        Expanded(child: Text('No details added yet. Tap edit to fill in your profile.', style: AppTypography.bodySm(color: AppColors.outline))),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.adherenceGreenLight,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.history_rounded, color: AppColors.adherenceGreenText),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Medication record', style: AppTypography.labelMd(color: AppColors.adherenceGreenText).copyWith(fontWeight: FontWeight.bold)),
                        Text(
                          '$historyCount recent dose ${historyCount == 1 ? 'entry is' : 'entries are'} saved on this device.',
                          style: AppTypography.bodySm(color: AppColors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            const SizedBox(height: 16),

            // 2. Google authentication
            _googleAccountCard(),

            const SizedBox(height: 24),

            // 3. Health & Adherence Overview (3 Cards)
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      children: [
                        Text('$totalMeds', style: AppTypography.headlineSm(color: AppColors.primary).copyWith(fontWeight: FontWeight.bold, fontSize: 22)),
                        const SizedBox(height: 2),
                        Text('Active Meds', style: AppTypography.labelSm(color: AppColors.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      children: [
                        Text('$streak Days', style: AppTypography.headlineSm(color: AppColors.secondary).copyWith(fontWeight: FontWeight.bold, fontSize: 22)),
                        const SizedBox(height: 2),
                        Text('Streak', style: AppTypography.labelSm(color: AppColors.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      children: [
                        Text('$adherenceRate%', style: AppTypography.headlineSm(color: AppColors.adherenceGreen).copyWith(fontWeight: FontWeight.bold, fontSize: 22)),
                        const SizedBox(height: 2),
                        Text('Adherence', style: AppTypography.labelSm(color: AppColors.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 4. Sound & Snooze Preferences
            Row(
              children: [
                const Icon(Icons.volume_up_rounded, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Sound & Reminder Preferences',
                  style: AppTypography.headlineSm(color: AppColors.onSurface).copyWith(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Alarm Tone
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Alarm Tone', style: AppTypography.labelMd(color: AppColors.onSurface)),
                        const SizedBox(height: 2),
                        Text(
                          _deviceAlarmSoundUri != null
                              ? 'Custom device alarm tone selected'
                              : 'Default system alarm tone',
                          style: AppTypography.bodySm(color: AppColors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton.icon(
                        onPressed: () => NotificationService.instance.previewAlarmSound(
                          'Device alarm tone',
                          customToneUri: _deviceAlarmSoundUri,
                        ),
                        icon: const Icon(Icons.play_arrow_rounded, size: 18),
                        label: const Text('Preview'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      const SizedBox(width: 6),
                      ElevatedButton.icon(
                        onPressed: () async {
                          final uri = await NotificationService.instance.pickDeviceAlarmSound(_deviceAlarmSoundUri);
                          if (uri != null && mounted) {
                            setState(() {
                              _deviceAlarmSoundUri = uri;
                              _alarmSound = 'Device alarm tone';
                            });
                            await _savePrefs();
                          }
                        },
                        icon: const Icon(Icons.music_note_rounded, size: 15),
                        label: const Text('Change'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Snooze Duration
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Default Snooze', style: AppTypography.labelMd(color: AppColors.onSurface)),
                      Text('Reminder repeat interval', style: AppTypography.bodySm(color: AppColors.onSurfaceVariant)),
                    ],
                  ),
                  DropdownButton<int>(
                    value: _snoozeDuration,
                    underline: const SizedBox(),
                    items: [5, 10, 15, 30].map((m) => DropdownMenuItem(value: m, child: Text('$m mins', style: AppTypography.labelSm(color: AppColors.primary)))).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _snoozeDuration = val);
                        _savePrefs();
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 5. Caregiver Supervision
            Row(
              children: [
                const Icon(Icons.family_restroom_rounded, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text('Caregiver Supervision', style: AppTypography.headlineSm(color: AppColors.onSurface).copyWith(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 10),
            _buildToggleTile(
              'Share with Caregiver',
              defaultTargetPlatform == TargetPlatform.android
                  ? 'SMS the saved caregiver 15 minutes after an unrecorded dose'
                  : 'Automatic SMS alerts are only available on Android.',
              _caregiverSync,
              (v) async {
                final caregiverPhone = _controller.user?.caregiverPhone?.trim() ?? '';
                if (v && caregiverPhone.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Add a caregiver phone number in your profile first.')),
                  );
                  return;
                }
                if (v && !await NotificationService.instance.requestCaregiverSmsPermission()) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('SMS permission is required to alert the caregiver.')),
                    );
                  }
                  return;
                }
                setState(() => _caregiverSync = v);
                await _savePrefs();
                await _controller.resyncCaregiverAlerts();
              },
              enabled: defaultTargetPlatform == TargetPlatform.android,
            ),
            _buildToggleTile(
              'Daily report at 11 PM',
              defaultTargetPlatform == TargetPlatform.android
                  ? 'SMS a daily medication summary to the saved caregiver'
                  : 'Automatic SMS alerts are only available on Android.',
              _dailyCaregiverReport,
              (v) async {
                final caregiverPhone = _controller.user?.caregiverPhone?.trim() ?? '';
                if (v && caregiverPhone.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Add a caregiver phone number in your profile first.')),
                  );
                  return;
                }
                if (v && !await NotificationService.instance.requestCaregiverSmsPermission()) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('SMS permission is required to send daily reports.')),
                    );
                  }
                  return;
                }
                setState(() => _dailyCaregiverReport = v);
                await _savePrefs();
                await _controller.resyncCaregiverAlerts();
              },
              enabled: defaultTargetPlatform == TargetPlatform.android,
            ),
            GestureDetector(
              onTap: defaultTargetPlatform == TargetPlatform.android ? _showConfigureCaregiverEmailDialog : null,
              child: Opacity(
                opacity: defaultTargetPlatform == TargetPlatform.android ? 1.0 : 0.55,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.mail_outline_rounded, size: 20, color: AppColors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Configure Caregiver Email', style: AppTypography.labelMd(color: AppColors.onSurface).copyWith(fontWeight: FontWeight.w600)),
                            Text(
                              defaultTargetPlatform == TargetPlatform.android
                                  ? 'Set the Gmail address DoseCare sends reports from'
                                  : 'Only available on Android.',
                              style: AppTypography.bodySm(color: AppColors.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
            ),
            _buildToggleTile(
              'Email Daily Report',
              defaultTargetPlatform == TargetPlatform.android
                  ? 'PDF adherence report emailed to the caregiver nightly around 11:30 PM'
                  : 'Automatic email reports are only available on Android.',
              _emailDailyReport,
              (v) async {
                if (v && !await _requireCaregiverEmailReady()) return;
                setState(() => _emailDailyReport = v);
                await _savePrefs();
                await _controller.resyncEmailReports();
              },
              enabled: defaultTargetPlatform == TargetPlatform.android,
            ),
            _buildToggleTile(
              'Email Weekly Report',
              defaultTargetPlatform == TargetPlatform.android
                  ? 'PDF adherence report emailed to the caregiver Sunday nights'
                  : 'Automatic email reports are only available on Android.',
              _emailWeeklyReport,
              (v) async {
                if (v && !await _requireCaregiverEmailReady()) return;
                setState(() => _emailWeeklyReport = v);
                await _savePrefs();
                await _controller.resyncEmailReports();
              },
              enabled: defaultTargetPlatform == TargetPlatform.android,
            ),
            GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CaregiverAlertsHistoryScreen()),
                );
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.history_rounded, size: 20, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Caregiver Alert History', style: AppTypography.labelMd(color: AppColors.onSurface).copyWith(fontWeight: FontWeight.w600)),
                          Text('See every alert sent and mark it acknowledged', style: AppTypography.bodySm(color: AppColors.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.onSurfaceVariant),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),


            // 7. Data Management
            Row(
              children: [
                const Icon(Icons.storage_rounded, color: AppColors.alertCoral, size: 20),
                const SizedBox(width: 8),
                Text('Data Management', style: AppTypography.headlineSm(color: AppColors.onSurface).copyWith(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.alertCoral.withValues(alpha: 0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Reset All Data', style: AppTypography.labelMd(color: AppColors.alertCoral).copyWith(fontWeight: FontWeight.bold)),
                        Text('Wipe all medicines, schedules, and dose history cleanly', style: AppTypography.bodySm(color: AppColors.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _confirmWipeData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.alertCoralBg,
                      foregroundColor: AppColors.alertCoral,
                      elevation: 0,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Reset All', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 8. Notification Alert Options
            Row(
              children: [
                const Icon(Icons.notifications_active_rounded, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Notification Alerts',
                    style: AppTypography.headlineSm(color: AppColors.onSurface).copyWith(fontSize: 16, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.adherenceGreenLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _notificationsEnabled ? 'Active' : 'Off',
                    style: AppTypography.labelSm(color: AppColors.adherenceGreenText).copyWith(fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            _buildToggleTile(
              'Medication Reminders',
              'Alarms when it is time to take your scheduled medications',
              _remindersEnabled,
              (v) async {
                setState(() => _remindersEnabled = v);
                await _savePrefs();
                await _controller.syncReminderSchedule();
              },
              icon: Icons.alarm_rounded,
              iconColor: AppColors.primary,
            ),
            _buildToggleTile(
              'Low Med Alerts',
              'Warns when your medicine stock falls below alert threshold',
              _lowStockAlerts,
              (v) async {
                setState(() => _lowStockAlerts = v);
                await _savePrefs();
                if (v) await _controller.refreshData(syncReminders: false);
              },
              icon: Icons.inventory_2_outlined,
              iconColor: AppColors.alertCoral,
            ),
            _buildToggleTile(
              'Dose Taken Alerts',
              'Confirms whenever a dose is marked and recorded as taken',
              _doseTakenAlerts,
              (v) async {
                setState(() => _doseTakenAlerts = v);
                await _savePrefs();
              },
              icon: Icons.check_circle_outline_rounded,
              iconColor: AppColors.adherenceGreen,
            ),
            _buildToggleTile(
              'Master Notification Service',
              'System status bar heads-up banners, sound, and lockscreen alerts',
              _notificationsEnabled,
              (v) async {
                final messenger = ScaffoldMessenger.of(context);
                setState(() => _notificationsEnabled = v);
                await _savePrefs();
                await _controller.syncReminderSchedule();
                if (v) {
                  final granted = await NotificationService.instance.requestPermission();
                  if (!mounted) return;
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        granted
                            ? '✓ Real-time notifications active with sound & banner!'
                            : '⚠️ Notification permission required in device settings.',
                      ),
                      backgroundColor: granted ? AppColors.primary : AppColors.alertCoral,
                    ),
                  );
                }
              },
              icon: Icons.toggle_on_rounded,
              iconColor: AppColors.primary,
            ),

            const SizedBox(height: 24),

            // 9. Footer with DoseCare Logo
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const DoseCareLogo(size: 42, borderRadius: 10),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DoseCare — Medication Management',
                          style: AppTypography.labelMd(color: AppColors.primary).copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Version 1.2.0 • Real-time on-device schedule and adherence monitoring.',
                          style: AppTypography.bodySm(color: AppColors.outline),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleTile(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged, {
    IconData? icon,
    Color? iconColor,
    bool enabled = true,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Opacity(
        opacity: enabled ? 1.0 : 0.55,
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: iconColor ?? AppColors.primary),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.labelMd(color: AppColors.onSurface).copyWith(fontWeight: FontWeight.w600)),
                  Text(subtitle, style: AppTypography.bodySm(color: AppColors.onSurfaceVariant)),
                ],
              ),
            ),
            Switch(
              value: enabled ? value : false,
              activeTrackColor: AppColors.primary,
              activeThumbColor: Colors.white,
              onChanged: enabled ? onChanged : null,
            ),
          ],
        ),
      ),
    );
  }
}
