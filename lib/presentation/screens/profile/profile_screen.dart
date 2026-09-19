import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medimate/core/constants/app_colors.dart';
import 'package:medimate/core/constants/app_typography.dart';
import 'package:medimate/core/notifications/notification_service.dart';
import 'package:medimate/data/models/user_model.dart';
import 'package:medimate/presentation/controllers/app_controller.dart';
import 'package:medimate/presentation/screens/assistant/assistant_screen.dart';
import 'package:medimate/presentation/widgets/dosecare_logo.dart';

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
  bool _appLockEnabled = false;
  String _alarmSound = 'Serene Bell';
  int _snoozeDuration = 10;

  String _bloodGroup = '';
  String _doctorName = '';
  String _doctorPhone = '';
  String _allergies = '';
  String _emergencyContact = '';

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

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _bloodGroup = prefs.getString('patient_blood_group') ?? '';
      _doctorName = prefs.getString('patient_doctor_name') ?? '';
      _doctorPhone = prefs.getString('patient_doctor_phone') ?? '';
      _allergies = prefs.getString('patient_allergies') ?? '';
      _emergencyContact = prefs.getString('patient_emergency_contact') ?? '';
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _remindersEnabled = prefs.getBool('reminders_enabled') ?? true;
      _lowStockAlerts = prefs.getBool('low_stock_alerts') ?? true;
      _doseTakenAlerts = prefs.getBool('dose_taken_alerts') ?? true;
      _caregiverSync = prefs.getBool('caregiver_alerts_enabled') ?? false;
      _appLockEnabled = prefs.getBool('app_lock_enabled') ?? false;
      _alarmSound = prefs.getString('alarm_sound') ?? 'Serene Bell';
      _snoozeDuration = prefs.getInt('snooze_duration') ?? 10;
    });
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('patient_blood_group', _bloodGroup);
    await prefs.setString('patient_doctor_name', _doctorName);
    await prefs.setString('patient_doctor_phone', _doctorPhone);
    await prefs.setString('patient_allergies', _allergies);
    await prefs.setString('patient_emergency_contact', _emergencyContact);
    await prefs.setBool('notifications_enabled', _notificationsEnabled);
    await prefs.setBool('reminders_enabled', _remindersEnabled);
    await prefs.setBool('low_stock_alerts', _lowStockAlerts);
    await prefs.setBool('dose_taken_alerts', _doseTakenAlerts);
    await prefs.setBool('caregiver_alerts_enabled', _caregiverSync);
    await prefs.setBool('app_lock_enabled', _appLockEnabled);
    await prefs.setString('alarm_sound', _alarmSound);
    await prefs.setInt('snooze_duration', _snoozeDuration);
  }

  void _showEditProfileDialog() {
    final current = _controller.user;
    final currentName = (current?.name != null && current!.name != 'User' && current.name.isNotEmpty)
        ? current.name
        : '';

    final nameCtrl = TextEditingController(text: currentName);
    final ageCtrl = TextEditingController(text: (current?.age != null && current!.age > 0) ? current.age.toString() : '');
    final genderCtrl = TextEditingController(text: (current?.gender != null && current!.gender != 'Not specified') ? current.gender : '');
    final bloodCtrl = TextEditingController(text: _bloodGroup);
    final doctorCtrl = TextEditingController(text: _doctorName);
    final doctorPhoneCtrl = TextEditingController(text: _doctorPhone);
    final caregiverPhoneCtrl = TextEditingController(
        text: (current?.caregiverPhone != null && current!.caregiverPhone!.isNotEmpty)
            ? current.caregiverPhone
            : _emergencyContact);
    final caregiverEmailCtrl = TextEditingController(
        text: (current?.caregiverEmail != null && current!.caregiverEmail!.isNotEmpty)
            ? current.caregiverEmail
            : '');
    final allergiesCtrl = TextEditingController(text: _allergies);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.badge_rounded, color: AppColors.primary),
            const SizedBox(width: 8),
            const Text('Edit Patient Profile'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Personal Information', style: AppTypography.labelSm(color: AppColors.primary).copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Patient Full Name', hintText: 'Enter your full name', isDense: true),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: ageCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Age', hintText: 'e.g. 25', isDense: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: const ['Male', 'Female', 'Other'].contains(genderCtrl.text) ? genderCtrl.text : null,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Gender', isDense: true),
                      hint: const Text('Select'),
                      items: const [
                        DropdownMenuItem(value: 'Male', child: Text('Male')),
                        DropdownMenuItem(value: 'Female', child: Text('Female')),
                        DropdownMenuItem(value: 'Other', child: Text('Other')),
                      ],
                      onChanged: (value) => genderCtrl.text = value ?? '',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: bloodCtrl,
                      decoration: const InputDecoration(labelText: 'Blood Group', hintText: 'O+', isDense: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              Text('Medical & Doctor Details', style: AppTypography.labelSm(color: AppColors.primary).copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: doctorCtrl,
                decoration: const InputDecoration(labelText: 'Primary Doctor', hintText: 'Dr. Name, Specialization', isDense: true),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: doctorPhoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Doctor Clinic Phone', hintText: '+91 XXXXX XXXXX', isDense: true),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: allergiesCtrl,
                decoration: const InputDecoration(labelText: 'Known Allergies', hintText: 'e.g. Penicillin, Dust (or None)', isDense: true),
              ),
              const SizedBox(height: 16),
              const Divider(),
              Text('Caregiver & Emergency Contact', style: AppTypography.labelSm(color: AppColors.primary).copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: caregiverPhoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Caregiver / Emergency Phone', hintText: '+91 XXXXX XXXXX', isDense: true),
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
              final newGender = genderCtrl.text.trim();
              final updated = UserModel(
                id: current?.id ?? 1,
                name: newName,
                age: newAge,
                gender: newGender.isNotEmpty ? newGender : 'Not specified',
                caregiverEmail: caregiverEmailCtrl.text.trim(),
                caregiverPhone: caregiverPhoneCtrl.text.trim(),
                appLockPin: current?.appLockPin ?? '',
                createdAt: current?.createdAt ?? DateTime.now().toIso8601String(),
              );

              _bloodGroup = bloodCtrl.text.trim();
              _doctorName = doctorCtrl.text.trim();
              _doctorPhone = doctorPhoneCtrl.text.trim();
              _allergies = allergiesCtrl.text.trim();
              _emergencyContact = caregiverPhoneCtrl.text.trim();

              await _savePrefs();
              await _controller.updateUserProfile(updated);

              if (ctx.mounted) Navigator.pop(ctx);
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
    final profileFieldsCompleted = [
      displayName,
      if (_bloodGroup.isNotEmpty) _bloodGroup,
      if (_doctorName.isNotEmpty) _doctorName,
      if (_allergies.isNotEmpty) _allergies,
      if (caregiverPhone.isNotEmpty) caregiverPhone,
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
                            radius: 34,
                            backgroundColor: AppColors.primaryFixed,
                            child: const Icon(Icons.person_rounded, size: 40, color: AppColors.primary),
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
                              child: const Icon(Icons.check, color: Colors.white, size: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (displayName != null) ...[
                              Text(
                                displayName,
                                style: AppTypography.headlineSm(color: AppColors.onSurface).copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                [
                                  if (age > 0) 'Age $age',
                                  ?gender,
                                  if (_bloodGroup.isNotEmpty) 'Blood: $_bloodGroup',
                                ].join(' • '),
                                style: AppTypography.bodySm(color: AppColors.onSurfaceVariant),
                              ),
                            ] else ...[
                              Text(
                                'Personal Profile',
                                style: AppTypography.headlineSm(color: AppColors.onSurface).copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'No details added yet',
                                style: AppTypography.bodySm(color: AppColors.outline),
                              ),
                            ],
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: Icon(displayName != null ? Icons.edit_rounded : Icons.person_add_rounded, size: 15),
                        label: Text(
                          displayName != null ? 'Edit' : 'Add Details',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        onPressed: _showEditProfileDialog,
                      ),
                    ],
                  ),
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
                                      ? (_doctorPhone.isNotEmpty ? '$_doctorName · $_doctorPhone' : _doctorName)
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
                  const SizedBox(height: 8),

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
                            profileFieldsCompleted >= 3
                                ? 'Your medical profile is ready for quick reference.'
                                : 'Add medical details so this screen is useful in an emergency.',
                            style: AppTypography.bodySm(color: AppColors.onSurfaceVariant),
                          ),
                        ),
                        TextButton(
                          onPressed: _showEditProfileDialog,
                          child: Text(profileFieldsCompleted >= 3 ? 'Review' : 'Complete'),
                        ),
                      ],
                    ),
                  ),

                  // Known Allergies
                  if (_allergies.isNotEmpty) ...[
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
                  ] else ...[
                    Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.outline),
                        const SizedBox(width: 10),
                        Text('No details added yet. Tap edit to fill in your profile.', style: AppTypography.bodySm(color: AppColors.outline)),
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

            // 2. Health & Adherence Overview (3 Cards)
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

            // 3. AI Assistant Quick Access
            InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AssistantScreen()),
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryContainer, AppColors.secondary],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 28),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI Medication Assistant',
                            style: AppTypography.headlineSm(color: Colors.white).copyWith(fontSize: 16),
                          ),
                          Text(
                            'Ask clinical questions, dose schedules, and refill warnings',
                            style: AppTypography.bodySm(color: Colors.white.withValues(alpha: 0.9)),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: Colors.white),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Alarm Tone', style: AppTypography.labelMd(color: AppColors.onSurface)),
                      Text('Loops until stopped or snoozed', style: AppTypography.bodySm(color: AppColors.onSurfaceVariant)),
                    ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      DropdownButton<String>(
                        value: _alarmSound,
                        underline: const SizedBox(),
                        items: ['Serene Bell', 'Gentle Chime', 'Clinic Pulse'].map((t) => DropdownMenuItem(value: t, child: Text(t, style: AppTypography.labelSm(color: AppColors.primary)))).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _alarmSound = val);
                            _savePrefs();
                          }
                        },
                      ),
                      TextButton.icon(
                        onPressed: () => NotificationService.instance.previewAlarmSound(_alarmSound),
                        icon: const Icon(Icons.play_arrow_rounded, size: 16),
                        label: const Text('Preview'),
                        style: TextButton.styleFrom(
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
              'SMS the saved caregiver 15 minutes after an unrecorded dose',
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
                await _controller.syncReminderSchedule();
              },
            ),
            const SizedBox(height: 20),

            // 6. Privacy & Protection
            Row(
              children: [
                const Icon(Icons.security_rounded, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text('Privacy & Protection', style: AppTypography.headlineSm(color: AppColors.onSurface).copyWith(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 10),
            _buildToggleTile(
              'App Lock',
              'Enable a device-level lock before storing a PIN',
              _appLockEnabled,
              (v) async {
                setState(() => _appLockEnabled = v);
                await _savePrefs();
              },
            ),
            const SizedBox(height: 24),

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
                          'DoseCare — AI Assisted Medication Management',
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
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
      ),
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
            value: value,
            activeTrackColor: AppColors.primary,
            activeThumbColor: Colors.white,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
