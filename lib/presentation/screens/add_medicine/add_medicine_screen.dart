import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:medimate/core/constants/app_colors.dart';
import 'package:medimate/core/constants/app_typography.dart';
import 'package:medimate/core/database/database_helper.dart';
import 'package:medimate/data/models/medicine_model.dart';
import 'package:medimate/data/models/schedule_model.dart';
import 'package:medimate/presentation/controllers/app_controller.dart';
import 'package:medimate/presentation/widgets/pill_visualizer.dart';
import 'package:medimate/presentation/widgets/interaction_warning_dialog.dart';
import 'package:medimate/presentation/widgets/dosecare_logo.dart';

class AddMedicineScreen extends StatefulWidget {
  final VoidCallback? onSaved;

  const AddMedicineScreen({super.key, this.onSaved});

  @override
  State<AddMedicineScreen> createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends State<AddMedicineScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _strengthController = TextEditingController();
  final TextEditingController _totalQtyController = TextEditingController(text: '30');
  final TextEditingController _thresholdController = TextEditingController(text: '5');
  final TextEditingController _imprintController = TextEditingController();

  String _selectedUnit = 'mg';
  String _selectedShape = 'capsule';
  String _selectedColor = 'teal';
  String _selectedFood = 'With Food';
  String _selectedFrequency = 'Every day';
  final List<String> _pharmacyList = [
    'None (No Linked Pharmacy)',
    'Apollo Pharmacy',
    'MedPlus Pharmacy',
  ];
  String _selectedPharmacy = 'None (No Linked Pharmacy)';
  bool _autoRefillEnabled = true;

  final List<Map<String, dynamic>> _reminderSlots = [
    {
      'label': 'Morning',
      'time': '08:00',
      'icon': Icons.wb_sunny_rounded,
      'color': AppColors.primary,
    },
    {
      'label': 'Evening',
      'time': '20:00',
      'icon': Icons.bedtime_rounded,
      'color': AppColors.secondary,
    },
  ];

  final ImagePicker _picker = ImagePicker();
  bool _isScanning = false;
  String? _scannedPrescriptionPath;

  String _storeTime(TimeOfDay time) => '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

  String _displayTime(BuildContext context, String value) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(value);
    if (match == null) return value;
    return TimeOfDay(hour: int.parse(match.group(1)!), minute: int.parse(match.group(2)!)).format(context);
  }

  String _periodForHour(int hour) => hour < 12 ? 'Morning' : (hour < 17 ? 'Afternoon' : 'Evening');

  @override
  void dispose() {
    _nameController.dispose();
    _strengthController.dispose();
    _totalQtyController.dispose();
    _thresholdController.dispose();
    _imprintController.dispose();
    super.dispose();
  }

  Future<void> _handleScanPrescription() async {
    // Offer Camera or Quick Presets
    final choice = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Scan or Select Preset',
                  style: AppTypography.headlineSm(color: AppColors.onSurface).copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'Use your camera to scan an Rx label, or pick a sample preset to test:',
                  style: AppTypography.bodySm(color: AppColors.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.primaryContainer,
                    child: Icon(Icons.camera_alt_rounded, color: AppColors.primary),
                  ),
                  title: const Text('Open Camera Scanner'),
                  subtitle: const Text('Capture bottle label with OCR simulation'),
                  onTap: () => Navigator.pop(ctx, 'camera'),
                ),
                const Divider(),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.secondaryContainer,
                    child: Icon(Icons.medication_liquid_rounded, color: AppColors.secondary),
                  ),
                  title: const Text('Amoxicillin 500mg'),
                  subtitle: const Text('Capsule • Teal • Antibiotic'),
                  onTap: () => Navigator.pop(ctx, 'amox'),
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.surfaceContainerHigh,
                    child: Icon(Icons.circle_outlined, color: AppColors.primary),
                  ),
                  title: const Text('Paracetamol 650mg'),
                  subtitle: const Text('Round • White • Pain & Fever'),
                  onTap: () => Navigator.pop(ctx, 'para'),
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: AppColors.adherenceGreenLight,
                    child: Icon(Icons.egg_outlined, color: AppColors.adherenceGreen),
                  ),
                  title: const Text('Metformin 500mg'),
                  subtitle: const Text('Oval • White • Blood Glucose'),
                  onTap: () => Navigator.pop(ctx, 'met'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (choice == null) return;

    if (choice == 'amox') {
      _applyOcrData('Amoxicillin 500mg', '500', 'mg', 'capsule', 'teal', 'AMOX 500');
    } else if (choice == 'para') {
      _applyOcrData('Paracetamol 650mg', '650', 'mg', 'round', 'white', 'PARA 650');
    } else if (choice == 'met') {
      _applyOcrData('Metformin 500mg', '500', 'mg', 'oval', 'white', 'MET 500');
    } else if (choice == 'camera') {
      setState(() => _isScanning = true);
      try {
        final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
        if (photo != null) {
          _scannedPrescriptionPath = photo.path;
          _applyOcrData('Amoxicillin Clavulanate', '500', 'mg', 'capsule', 'teal', 'AMOX 500');
        } else {
          _applyOcrData('Amoxicillin 500mg', '500', 'mg', 'capsule', 'teal', 'AMOX 500');
        }
      } catch (e) {
        _applyOcrData('Amoxicillin 500mg', '500', 'mg', 'capsule', 'teal', 'AMOX 500');
      } finally {
        setState(() => _isScanning = false);
      }
    }
  }

  void _applyOcrData(String name, String strength, String unit, String shape, String color, String imprint) {
    setState(() {
      _nameController.text = name;
      _strengthController.text = strength;
      _selectedUnit = unit;
      _selectedShape = shape;
      _selectedColor = color;
      _imprintController.text = imprint;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Prescription filled! Set to $name ($strength $unit).'),
        backgroundColor: AppColors.adherenceGreen,
      ),
    );
  }

  Future<void> _saveMedicine() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final strength = _strengthController.text.trim();
    final totalQty = int.tryParse(_totalQtyController.text) ?? 30;
    final threshold = int.tryParse(_thresholdController.text) ?? 5;

    // 1. Safety Check for Drug-Drug Interactions
    final interactions = AppController.instance.checkSafety(name);
    if (interactions.isNotEmpty) {
      final proceed = await InteractionWarningDialog.show(context, interactions: interactions);
      if (proceed != true) return;
    }

    // 2. Build model
    final newMedicine = MedicineModel(
      name: name,
      type: _selectedShape,
      dosage: '$strength $_selectedUnit',
      pillColor: _selectedColor,
      imprintCode: _imprintController.text.trim(),
      totalQuantity: totalQty,
      remainingQuantity: totalQty,
      lowStockThreshold: threshold,
      foodInstruction: _selectedFood,
      pharmacyName: _selectedPharmacy == 'None (No Linked Pharmacy)' ? 'Direct Purchase' : _selectedPharmacy.split(' - ').first,
      rxNumber: 'RX-${DateTime.now().millisecondsSinceEpoch % 1000000}',
    );

    // 3. Save medicine with schedules for each reminder slot
    final medId = await AppController.instance.addMedicineWithSchedule(
      medicine: newMedicine,
      timeOfDay: _reminderSlots.first['time'].toString(),
      periodLabel: _reminderSlots.first['label'].toString(),
      frequencyType: _selectedFrequency == 'As needed' ? 'as_needed' : _selectedFrequency == 'Alternate days' ? 'alternate' : 'daily',
    );

    // Save additional slots if more than 1
    if (_reminderSlots.length > 1) {
      for (int i = 1; i < _reminderSlots.length; i++) {
        final slot = _reminderSlots[i];
        final rawTime = slot['time'].toString();
        await DatabaseHelper.instance.insertSchedule(
          ScheduleModel(
            medicineId: medId,
            timeOfDay: rawTime,
            periodLabel: slot['label'].toString(),
            doseCount: 1,
            frequencyType: _selectedFrequency == 'As needed' ? 'as_needed' : _selectedFrequency == 'Alternate days' ? 'alternate' : 'daily',
          ),
        );
      }
      await AppController.instance.refreshData();
    }

    if (_scannedPrescriptionPath != null) {
      await DatabaseHelper.instance.insertPrescription(
        medicineId: medId,
        imagePath: _scannedPrescriptionPath,
        rawOcrText: '$name $strength $_selectedUnit',
      );
    }

    // Reset controllers
    _nameController.clear();
    _strengthController.clear();
    _imprintController.clear();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$name added to daily schedule!'),
          backgroundColor: AppColors.primary,
        ),
      );
      widget.onSaved?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const DoseCareLogo(
              size: 34,
              borderRadius: 8,
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'DoseCare',
                  style: AppTypography.headlineSm(color: AppColors.primary).copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Add Dose',
                  style: AppTypography.labelSm(color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. OCR Scanner Banner
              _buildOcrScannerBanner(),
              const SizedBox(height: 20),

              // 3. Medication Identity Form
              _buildIdentitySection(),
              const SizedBox(height: 20),

              // 4. Live Pill Visualizer & Form Factor Grid
              _buildPillAppearanceSection(),
              const SizedBox(height: 20),

              // 5. Schedule & Food Instructions
              _buildScheduleSection(),
              const SizedBox(height: 20),

              // 6. Inventory & Low-Stock Alerts
              _buildInventorySection(),
              const SizedBox(height: 28),

              // Save Button
              ElevatedButton.icon(
                onPressed: _saveMedicine,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 22),
                label: Text(
                  'Save & Set Schedule',
                  style: AppTypography.labelLg(color: Colors.white).copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOcrScannerBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryContainer, AppColors.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.document_scanner_rounded, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Scan Prescription',
                  style: AppTypography.headlineSm(color: Colors.white),
                ),
                Text(
                  'Auto-fill Rx, strength & instructions in 2s',
                  style: AppTypography.bodySm(color: Colors.white.withValues(alpha: 0.9)),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: _isScanning ? null : _handleScanPrescription,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primary,
              minimumSize: const Size(100, 40),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            icon: _isScanning
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
                  )
                : const Icon(Icons.photo_camera_rounded, size: 18, color: AppColors.primary),
            label: Text(
              'Scan Bottle',
              style: AppTypography.labelSm(color: AppColors.primary).copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Comprehensive medicine database for auto-search
  static const List<String> _medicineDatabase = [
    // Antibiotics
    'Amoxicillin 250mg', 'Amoxicillin 500mg', 'Amoxicillin-Clavulanate 625mg',
    'Azithromycin 250mg', 'Azithromycin 500mg',
    'Ciprofloxacin 250mg', 'Ciprofloxacin 500mg',
    'Doxycycline 100mg', 'Metronidazole 400mg', 'Metronidazole 500mg',
    'Cephalexin 250mg', 'Cephalexin 500mg', 'Clindamycin 300mg',
    'Levofloxacin 250mg', 'Levofloxacin 500mg', 'Trimethoprim-Sulfamethoxazole 480mg',
    // Pain & Fever
    'Paracetamol 325mg', 'Paracetamol 500mg', 'Paracetamol 650mg',
    'Ibuprofen 200mg', 'Ibuprofen 400mg', 'Ibuprofen 600mg',
    'Aspirin 75mg', 'Aspirin 150mg', 'Aspirin 325mg',
    'Diclofenac 50mg', 'Diclofenac 75mg', 'Naproxen 250mg', 'Naproxen 500mg',
    'Tramadol 50mg', 'Tramadol 100mg', 'Mefenamic Acid 250mg', 'Mefenamic Acid 500mg',
    // Diabetes
    'Metformin 500mg', 'Metformin 850mg', 'Metformin 1000mg',
    'Glibenclamide 5mg', 'Glimepiride 1mg', 'Glimepiride 2mg', 'Glimepiride 4mg',
    'Voglibose 0.2mg', 'Voglibose 0.3mg', 'Sitagliptin 100mg', 'Teneligliptin 20mg',
    // Blood Pressure & Heart
    'Amlodipine 2.5mg', 'Amlodipine 5mg', 'Amlodipine 10mg',
    'Atenolol 25mg', 'Atenolol 50mg', 'Atenolol 100mg',
    'Losartan 25mg', 'Losartan 50mg', 'Losartan 100mg',
    'Telmisartan 20mg', 'Telmisartan 40mg', 'Telmisartan 80mg',
    'Enalapril 2.5mg', 'Enalapril 5mg', 'Enalapril 10mg',
    'Ramipril 2.5mg', 'Ramipril 5mg', 'Metoprolol 25mg', 'Metoprolol 50mg',
    'Furosemide 20mg', 'Furosemide 40mg', 'Spironolactone 25mg',
    'Rosuvastatin 5mg', 'Rosuvastatin 10mg', 'Rosuvastatin 20mg',
    'Atorvastatin 10mg', 'Atorvastatin 20mg', 'Atorvastatin 40mg',
    // Gastro
    'Omeprazole 10mg', 'Omeprazole 20mg', 'Omeprazole 40mg',
    'Pantoprazole 20mg', 'Pantoprazole 40mg', 'Rabeprazole 20mg',
    'Domperidone 10mg', 'Ondansetron 4mg', 'Ondansetron 8mg',
    'Ranitidine 150mg', 'Famotidine 20mg', 'Esomeprazole 20mg', 'Esomeprazole 40mg',
    // Respiratory / Allergy
    'Cetirizine 5mg', 'Cetirizine 10mg', 'Fexofenadine 120mg', 'Fexofenadine 180mg',
    'Loratadine 10mg', 'Montelukast 4mg', 'Montelukast 5mg', 'Montelukast 10mg',
    'Salbutamol 2mg', 'Salbutamol 4mg', 'Salbutamol Inhaler 100mcg',
    'Budesonide Inhaler 200mcg', 'Fluticasone Inhaler 125mcg',
    // Vitamins & Supplements
    'Vitamin D3 1000 IU', 'Vitamin D3 2000 IU', 'Vitamin D3 60000 IU',
    'Vitamin B12 500mcg', 'Vitamin B12 1000mcg',
    'Calcium + Vitamin D3 500mg', 'Ferrous Sulfate 200mg',
    'Folic Acid 400mcg', 'Folic Acid 5mg', 'Zinc 10mg', 'Zinc 20mg',
    'Multivitamin Daily', 'Omega-3 Fish Oil 1000mg',
    // Thyroid
    'Levothyroxine 25mcg', 'Levothyroxine 50mcg', 'Levothyroxine 75mcg', 'Levothyroxine 100mcg',
    // Mental Health / Neuro
    'Sertraline 25mg', 'Sertraline 50mg', 'Sertraline 100mg',
    'Escitalopram 5mg', 'Escitalopram 10mg', 'Escitalopram 20mg',
    'Alprazolam 0.25mg', 'Alprazolam 0.5mg', 'Clonazepam 0.25mg', 'Clonazepam 0.5mg',
    'Gabapentin 100mg', 'Gabapentin 300mg', 'Pregabalin 75mg', 'Pregabalin 150mg',
    'Levodopa-Carbidopa 100/25mg',
    // Others
    'Hydroxychloroquine 200mg', 'Prednisolone 5mg', 'Prednisolone 10mg',
    'Methylcobalamin 500mcg', 'Aceclofenac 100mg', 'Pantoprazole + Domperidone',
    'Clopidogrel 75mg', 'Warfarin 1mg', 'Warfarin 2mg', 'Warfarin 5mg',
    'Insulin Regular', 'Insulin NPH', 'Insulin Glargine',
    // Liquid, Syrups & Suspensions
    'Cough Syrup 100ml', 'Benadryl Cough Syrup 100ml',
    'Amoxicillin Oral Suspension 125mg/5ml', 'Amoxicillin Oral Suspension 250mg/5ml',
    'Paracetamol Pediatric Syrup 120mg/5ml', 'Paracetamol Pediatric Syrup 250mg/5ml',
    'Ibuprofen Oral Suspension 100mg/5ml', 'Cetirizine Syrup 5mg/5ml',
    'Antacid Liquid Gel 200ml', 'Lactulose Oral Solution 10g/15ml',
    'Dextromethorphan Syrup 100ml', 'Azithromycin Oral Suspension 200mg/5ml',
    'Zinc Sulfate Syrup 20mg/5ml', 'Salbutamol Syrup 2mg/5ml',
    'Multivitamin Liquid 200ml', 'Saline Nasal Spray 100ml',
  ];

  Widget _buildIdentitySection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.vaccines_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Medication Identity',
                style: AppTypography.headlineSm(color: AppColors.onSurface),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Auto-Search Medicine Name
          Text('Medication Name', style: AppTypography.labelMd(color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 6),
          Autocomplete<String>(
            optionsBuilder: (TextEditingValue textEditingValue) {
              final query = textEditingValue.text.trim();
              if (query.isEmpty) return const Iterable<String>.empty();
              final matches = _medicineDatabase
                  .where((med) => med.toLowerCase().contains(query.toLowerCase()))
                  .toList();
              // Allow adding user's custom medicine if not an exact match
              final exactMatch = matches.any((m) => m.toLowerCase() == query.toLowerCase());
              if (!exactMatch && query.length >= 2) {
                matches.add(query);
              }
              return matches;
            },
            onSelected: (String selection) {
              _nameController.text = selection;
              final lower = selection.toLowerCase();
              if (lower.contains('syrup') || lower.contains('liquid') || lower.contains('suspension') || lower.contains('drops') || lower.contains('solution') || lower.contains('gel')) {
                _selectedShape = 'liquid';
                _selectedUnit = 'ml';
                if (_totalQtyController.text == '30' || _totalQtyController.text.isEmpty) {
                  _totalQtyController.text = '100';
                }
              } else if (lower.contains('inhaler') || lower.contains('puff') || lower.contains('spray')) {
                _selectedShape = 'inhaler';
                _selectedUnit = 'puffs';
                if (_totalQtyController.text == '30' || _totalQtyController.text.isEmpty) {
                  _totalQtyController.text = '120';
                }
              } else if (lower.contains('shot') || lower.contains('injection') || lower.contains('vaccine')) {
                _selectedShape = 'injection';
                _selectedUnit = 'ml';
                if (_totalQtyController.text == '30' || _totalQtyController.text.isEmpty) {
                  _totalQtyController.text = '10';
                }
              }
              // Auto-fill strength if present in name e.g. "Amoxicillin 500mg"
              final match = RegExp(r'(\d+(?:\.\d+)?)\s*(mg|mcg|ml|IU|iu)').firstMatch(selection);
              if (match != null) {
                _strengthController.text = match.group(1) ?? '';
                final unitStr = match.group(2)?.toLowerCase() ?? 'mg';
                _selectedUnit = ['mg', 'mcg', 'ml', 'drops', 'puffs'].contains(unitStr) ? unitStr : 'mg';
              }
              setState(() {});
            },
            fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
              // Keep our controller in sync
              controller.addListener(() {
                if (_nameController.text != controller.text) {
                  _nameController.text = controller.text;
                }
              });
              return TextFormField(
                controller: controller,
                focusNode: focusNode,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.outline),
                  hintText: 'Search or type any medicine name...',
                  suffixIcon: controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.cancel_rounded, color: AppColors.outline, size: 18),
                          onPressed: () {
                            controller.clear();
                            _nameController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'Please enter medicine name' : null,
              );
            },
            optionsViewBuilder: (context, onSelected, options) {
              return Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(12),
                  color: AppColors.surfaceContainerLowest,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 220, maxWidth: 340),
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: options.length,
                      shrinkWrap: true,
                      itemBuilder: (context, index) {
                        final option = options.elementAt(index);
                        final isCustom = !_medicineDatabase.contains(option);
                        return InkWell(
                          onTap: () => onSelected(option),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            child: Row(
                              children: [
                                Icon(
                                  isCustom ? Icons.add_circle_outline_rounded : Icons.medication_rounded,
                                  size: 18,
                                  color: isCustom ? AppColors.adherenceGreen : AppColors.primary,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    isCustom ? 'Add "$option" as custom medicine' : option,
                                    style: AppTypography.labelMd(
                                      color: isCustom ? AppColors.primary : AppColors.onSurface,
                                    ).copyWith(fontWeight: isCustom ? FontWeight.bold : FontWeight.normal),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 6),
          Text(
            'Not listed? Type your custom medicine name above.',
            style: AppTypography.bodySm(color: AppColors.outline).copyWith(fontSize: 11),
          ),
          const SizedBox(height: 14),

          // Strength & Unit
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Strength', style: AppTypography.labelMd(color: AppColors.onSurfaceVariant)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _strengthController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(hintText: '500'),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Unit', style: AppTypography.labelMd(color: AppColors.onSurfaceVariant)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedUnit,
                      decoration: const InputDecoration(),
                      items: ['mg', 'mcg', 'ml', 'drops', 'puffs'].map((u) {
                        return DropdownMenuItem(value: u, child: Text(u));
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedUnit = val ?? 'mg'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPillAppearanceSection() {
    final shapes = [
      {'name': 'capsule', 'icon': Icons.medication_rounded, 'label': 'Capsule'},
      {'name': 'round', 'icon': Icons.circle_outlined, 'label': 'Round'},
      {'name': 'oval', 'icon': Icons.egg_outlined, 'label': 'Oval'},
      {'name': 'liquid', 'icon': Icons.water_drop_outlined, 'label': 'Liquid'},
      {'name': 'inhaler', 'icon': Icons.air_rounded, 'label': 'Inhaler'},
      {'name': 'injection', 'icon': Icons.vaccines_outlined, 'label': 'Shot'},
    ];

    final colors = [
      {'name': 'teal', 'color': AppColors.primary},
      {'name': 'white', 'color': Colors.white},
      {'name': 'blue', 'color': const Color(0xFF3B82F6)},
      {'name': 'yellow', 'color': const Color(0xFFFACC15)},
      {'name': 'amber', 'color': const Color(0xFFF59E0B)},
      {'name': 'purple', 'color': const Color(0xFF9333EA)},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.palette_outlined, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text('Pill Appearance', style: AppTypography.headlineSm(color: AppColors.onSurface)),
                ],
              ),
              Text(
                'Interactive Preview',
                style: AppTypography.labelSm(color: AppColors.secondary).copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Live 3D Simulation Slate
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                PillVisualizer(
                  shape: _selectedShape,
                  colorName: _selectedColor,
                  imprintCode: _imprintController.text,
                  width: 90,
                  height: 52,
                ),
                const SizedBox(height: 10),
                Text(
                  '${_selectedShape.toUpperCase()} • ${_selectedColor.toUpperCase()} • ${_strengthController.text} $_selectedUnit',
                  style: AppTypography.labelSm(color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Shape Grid
          Text('Select Form Factor', style: AppTypography.labelMd(color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 2.2,
            children: shapes.map((s) {
              final isSelected = _selectedShape == s['name'];
              return InkWell(
                onTap: () {
                  final shapeName = s['name'] as String;
                  setState(() {
                    _selectedShape = shapeName;
                    if (shapeName == 'liquid') {
                      if (_selectedUnit == 'mg') _selectedUnit = 'ml';
                      if (_totalQtyController.text == '30' || _totalQtyController.text.isEmpty) {
                        _totalQtyController.text = '100';
                      }
                    } else if (shapeName == 'inhaler') {
                      if (_selectedUnit == 'mg') _selectedUnit = 'puffs';
                      if (_totalQtyController.text == '30' || _totalQtyController.text.isEmpty) {
                        _totalQtyController.text = '120';
                      }
                    } else if (shapeName == 'injection') {
                      if (_selectedUnit == 'mg') _selectedUnit = 'ml';
                      if (_totalQtyController.text == '30' || _totalQtyController.text.isEmpty) {
                        _totalQtyController.text = '10';
                      }
                    }
                  });
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.surfaceContainerHighest : AppColors.surfaceContainerLowest,
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.outlineVariant.withValues(alpha: 0.5),
                      width: isSelected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        s['icon'] as IconData,
                        size: 18,
                        color: isSelected ? AppColors.primary : AppColors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        s['label'] as String,
                        style: AppTypography.labelSm(
                          color: isSelected ? AppColors.primary : AppColors.onSurfaceVariant,
                        ).copyWith(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // Color Swatches
          Text('Color Tint', style: AppTypography.labelMd(color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: colors.map((c) {
              final isSelected = _selectedColor == c['name'];
              return InkWell(
                onTap: () => setState(() => _selectedColor = c['name'] as String),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c['color'] as Color,
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.outlineVariant,
                      width: isSelected ? 3 : 1,
                    ),
                  ),
                  child: isSelected
                      ? Icon(
                          Icons.check_rounded,
                          size: 20,
                          color: c['name'] == 'white' || c['name'] == 'yellow' ? Colors.black : Colors.white,
                        )
                      : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleSection() {
    final frequencies = ['Every day', 'Specific days', 'Every 2 days', 'As needed (PRN)'];
    final foodChips = [
      {'label': 'With Food', 'icon': Icons.restaurant_menu_rounded},
      {'label': 'Before Food', 'icon': Icons.no_meals_rounded},
      {'label': 'After Food', 'icon': Icons.done_all_rounded},
      {'label': 'Empty Stomach', 'icon': Icons.water_drop_outlined},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  children: [
                    const Icon(Icons.alarm_rounded, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Frequency & Reminders',
                        style: AppTypography.headlineSm(color: AppColors.onSurface),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: const TimeOfDay(hour: 12, minute: 0),
                  );
                  if (picked != null) {
                    setState(() {
                      final period = _periodForHour(picked.hour);
                      _reminderSlots.add({
                        'label': period,
                        'time': _storeTime(picked),
                        'icon': picked.hour < 17 ? Icons.wb_sunny_rounded : Icons.bedtime_rounded,
                        'color': AppColors.primary,
                      });
                    });
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        'Add Time',
                        style: AppTypography.labelMd(color: AppColors.primary).copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 1. Frequency Pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: frequencies.map((freq) {
                final isSelected = _selectedFrequency == freq;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => setState(() => _selectedFrequency = freq),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : AppColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Text(
                        freq,
                        style: AppTypography.labelSm(
                          color: isSelected ? Colors.white : AppColors.onSurfaceVariant,
                        ).copyWith(fontWeight: isSelected ? FontWeight.bold : FontWeight.w500),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // 2. Reminder Slots List
          ..._reminderSlots.asMap().entries.map((entry) {
            final idx = entry.key;
            final slot = entry.value;
            final icon = slot['icon'] as IconData;
            final color = slot['color'] as Color;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, color: color, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _displayTime(context, slot['time'] as String),
                                style: AppTypography.headlineSm(color: AppColors.onSurface).copyWith(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${slot['label']} • 1 ${_selectedShape.toUpperCase()} (${_strengthController.text} $_selectedUnit)',
                                style: AppTypography.bodySm(color: AppColors.onSurfaceVariant),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.schedule_rounded, size: 18, color: AppColors.outline),
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: const TimeOfDay(hour: 8, minute: 0),
                          );
                          if (picked != null) {
                            setState(() {
                              _reminderSlots[idx]['time'] = _storeTime(picked);
                              _reminderSlots[idx]['label'] = _periodForHour(picked.hour);
                            });
                          }
                        },
                      ),
                      if (_reminderSlots.length > 1)
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.outline),
                          onPressed: () {
                            setState(() => _reminderSlots.removeAt(idx));
                          },
                        ),
                    ],
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 12),

          // 3. Food Intake Protocol
          Text('Food Intake Protocol', style: AppTypography.labelMd(color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 3.2,
            children: foodChips.map((fc) {
              final isSelected = _selectedFood.toLowerCase() == (fc['label'] as String).toLowerCase();
              return InkWell(
                onTap: () => setState(() => _selectedFood = fc['label'] as String),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primaryContainer : AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        fc['icon'] as IconData,
                        size: 18,
                        color: isSelected ? Colors.white : AppColors.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        fc['label'] as String,
                        style: AppTypography.labelMd(
                          color: isSelected ? Colors.white : AppColors.onSurface,
                        ).copyWith(fontWeight: isSelected ? FontWeight.bold : FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _showAddCustomPharmacyDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final addressCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.local_pharmacy_rounded, color: AppColors.primary),
            const SizedBox(width: 8),
            Text('Add Your Pharmacy', style: AppTypography.headlineSm(color: AppColors.onSurface)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enter your preferred or local pharmacy details:', style: AppTypography.bodySm(color: AppColors.onSurfaceVariant)),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Pharmacy Name *',
                hintText: 'e.g. Apollo Pharmacy, Care Chemist',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone (Optional)',
                hintText: 'e.g. +91 98765 43210',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: addressCtrl,
              decoration: const InputDecoration(
                labelText: 'Address / Branch (Optional)',
                hintText: 'Location or street',
              ),
            ),
          ],
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
            onPressed: () {
              final name = nameCtrl.text.trim();
              if (name.isNotEmpty) {
                setState(() {
                  if (!_pharmacyList.contains(name)) {
                    _pharmacyList.add(name);
                  }
                  _selectedPharmacy = name;
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Pharmacy "$name" linked successfully!'),
                    backgroundColor: AppColors.primary,
                  ),
                );
              }
            },
            child: const Text('Save & Select'),
          ),
        ],
      ),
    );
  }

  String get _stockTitle {
    switch (_selectedShape) {
      case 'liquid':
        return 'Volume in Bottle';
      case 'inhaler':
        return 'Puffs in Canister';
      case 'injection':
        return 'Doses in Pack';
      case 'capsule':
        return 'Capsules in Bottle';
      default:
        return 'Pills in Bottle';
    }
  }

  String get _stockUnitSuffix {
    switch (_selectedShape) {
      case 'liquid':
        return 'ml';
      case 'inhaler':
        return 'puffs';
      case 'injection':
        return 'doses';
      case 'capsule':
        return 'capsules';
      default:
        return 'pills';
    }
  }

  String get _stockHint {
    switch (_selectedShape) {
      case 'liquid':
        return '100';
      case 'inhaler':
        return '120';
      case 'injection':
        return '10';
      default:
        return '30';
    }
  }

  Widget _buildInventorySection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.inventory_2_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text('Refills & Inventory', style: AppTypography.headlineSm(color: AppColors.onSurface)),
            ],
          ),
          const SizedBox(height: 14),

          // Current Stock & Alert Threshold Stepper
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_stockTitle, style: AppTypography.labelMd(color: AppColors.onSurfaceVariant)),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _totalQtyController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: _stockHint,
                        suffixText: _stockUnitSuffix,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Alert Threshold', style: AppTypography.labelMd(color: AppColors.onSurfaceVariant)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          InkWell(
                            onTap: () {
                              final curr = int.tryParse(_thresholdController.text) ?? 5;
                              if (curr > 1) {
                                setState(() => _thresholdController.text = (curr - 1).toString());
                              }
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.remove_rounded, size: 16),
                            ),
                          ),
                          SizedBox(
                            width: 34,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _thresholdController.text,
                                style: AppTypography.headlineSm(color: AppColors.onSurface).copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '$_stockUnitSuffix left',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: AppTypography.labelSm(color: AppColors.outline),
                              ),
                            ],
                            ),
                          ),
                          InkWell(
                            onTap: () {
                              final curr = int.tryParse(_thresholdController.text) ?? 5;
                              setState(() => _thresholdController.text = (curr + 1).toString());
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.add_rounded, size: 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Pharmacy Refill Connector
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 4,
            children: [
              Text('Linked Pharmacy', style: AppTypography.labelMd(color: AppColors.onSurfaceVariant)),
              TextButton.icon(
                onPressed: _showAddCustomPharmacyDialog,
                icon: const Icon(Icons.add_rounded, size: 16, color: AppColors.primary),
                label: Text(
                  'Add Your Pharmacy',
                  style: AppTypography.labelSm(color: AppColors.primary).copyWith(fontWeight: FontWeight.bold),
                ),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            key: ValueKey(_selectedPharmacy),
            initialValue: _pharmacyList.contains(_selectedPharmacy) ? _selectedPharmacy : _pharmacyList.first,
            isExpanded: true,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.local_pharmacy_rounded, color: AppColors.outline),
            ),
            items: [
              ..._pharmacyList.map((p) {
                return DropdownMenuItem(
                  value: p,
                  child: Text(p, style: AppTypography.bodyMd(color: AppColors.onSurface), overflow: TextOverflow.ellipsis),
                );
              }),
              const DropdownMenuItem(
                value: '__ADD_NEW__',
                child: Row(
                  children: [
                    Icon(Icons.add_circle_outline_rounded, size: 18, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text('+ Add Your Pharmacy...', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
            onChanged: (val) {
              if (val == '__ADD_NEW__') {
                _showAddCustomPharmacyDialog();
              } else if (val != null) {
                setState(() => _selectedPharmacy = val);
              }
            },
          ),
          const SizedBox(height: 14),

          // Refill Auto-Order Banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.notifications_active_rounded, color: AppColors.secondary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Auto-request RX refill',
                        style: AppTypography.labelMd(color: AppColors.onSurface).copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Notify doctor when down to ${_thresholdController.text} doses',
                        style: AppTypography.bodySm(color: AppColors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _autoRefillEnabled,
                  activeTrackColor: AppColors.primary,
                  activeThumbColor: Colors.white,
                  onChanged: (val) => setState(() => _autoRefillEnabled = val),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
