import 'package:flutter/material.dart';
import 'package:dosecare/core/constants/app_colors.dart';
import 'package:dosecare/core/constants/app_typography.dart';
import 'package:dosecare/core/database/database_helper.dart';
import 'package:dosecare/data/models/medicine_model.dart';
import 'package:dosecare/data/models/schedule_model.dart';
import 'package:dosecare/presentation/controllers/app_controller.dart';
import 'package:dosecare/presentation/widgets/pill_visualizer.dart';
import 'package:dosecare/presentation/widgets/date_range_calendar_view.dart';
import 'package:dosecare/presentation/widgets/interaction_warning_dialog.dart';
import 'package:dosecare/presentation/widgets/dosecare_logo.dart';

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
  TextEditingController? _autocompleteTextController;
  int _formResetVersion = 0;

  static const List<String> _availableUnits = ['mg', 'mcg', 'g', 'ml', 'IU', 'drops', 'puffs', '%'];
  static final RegExp _strengthRegex = RegExp(
    r'(\d+(?:\.\d+)?)\s*(mg|mcg|g|ml|iu(?:\/ml)?|drops|puffs|%)\b',
    caseSensitive: false,
  );

  String _selectedUnit = 'mg';
  String _selectedShape = 'capsule';
  String _selectedColor = 'teal';
  String _selectedFood = 'With Food';
  String _selectedFrequency = 'Every day';
  DateTime _courseStartDate = DateTime.now();
  DateTime _courseEndDate = DateTime.now().add(const Duration(days: 6));
  // A practical starting schedule that can be edited, removed, or expanded.
  // PRN medicines still deliberately create no scheduled reminders.
  final List<Map<String, dynamic>> _reminderSlots = [
    {'label': 'Morning', 'time': '08:00', 'icon': Icons.wb_sunny_rounded, 'color': AppColors.primary},
    {'label': 'Evening', 'time': '20:00', 'icon': Icons.bedtime_rounded, 'color': AppColors.secondary},
  ];

  void _resetForm() {
    FocusManager.instance.primaryFocus?.unfocus();
    _autocompleteTextController?.clear();
    _autocompleteTextController = null;
    _nameController.clear();
    _strengthController.clear();
    _imprintController.clear();
    _totalQtyController.text = '30';
    _thresholdController.text = '5';
    setState(() {
      // Recreate Autocomplete after each save. Its internal text controller
      // otherwise retains the previously selected medicine.
      _formResetVersion++;
      _selectedUnit = 'mg';
      _selectedShape = 'capsule';
      _selectedColor = 'teal';
      _selectedFood = 'With Food';
      _selectedFrequency = 'Every day';
      _courseStartDate = DateTime.now();
      _courseEndDate = DateTime.now().add(const Duration(days: 6));
      _reminderSlots.clear();
      _reminderSlots.addAll([
        {'label': 'Morning', 'time': '08:00', 'icon': Icons.wb_sunny_rounded, 'color': AppColors.primary},
        {'label': 'Evening', 'time': '20:00', 'icon': Icons.bedtime_rounded, 'color': AppColors.secondary},
      ]);
    });
    _formKey.currentState?.reset();
  }

  void _applyMedicineSelection(String selection) {
    if (selection.trim().isEmpty) return;

    // 1. Check if power/unit is present in the selected name
    final match = _strengthRegex.firstMatch(selection);
    if (match != null) {
      _strengthController.text = match.group(1) ?? '';
      final rawUnit = (match.group(2) ?? 'mg').toLowerCase();
      if (rawUnit.startsWith('iu')) {
        _selectedUnit = 'IU';
      } else if (rawUnit == 'mcg') {
        _selectedUnit = 'mcg';
      } else if (rawUnit == 'g') {
        _selectedUnit = 'g';
      } else if (rawUnit == 'ml') {
        _selectedUnit = 'ml';
      } else if (rawUnit == 'drops') {
        _selectedUnit = 'drops';
      } else if (rawUnit == 'puffs') {
        _selectedUnit = 'puffs';
      } else if (rawUnit == '%') {
        _selectedUnit = '%';
      } else {
        _selectedUnit = 'mg';
      }
    } else {
      // Power is not mentioned in name: clear strength so user can manually add
      _strengthController.clear();
      _selectedUnit = 'mg';
    }

    // 2. Set clean medication name (strip power so it does not duplicate in dosage)
    final cleanName = selection
        .replaceAll(_strengthRegex, '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final displayName = cleanName.isNotEmpty ? cleanName : selection;

    _nameController.text = displayName;
    if (_autocompleteTextController != null && _autocompleteTextController!.text != displayName) {
      _autocompleteTextController!.text = displayName;
    }

    // 3. Smart Form Factor Detection
    final lower = selection.toLowerCase();
    if (lower.contains('syrup') || lower.contains('liquid') || lower.contains('suspension') || lower.contains('drops') || lower.contains('solution') || lower.contains('gel') || lower.contains('lotion')) {
      _selectedShape = 'liquid';
      if (match == null) _selectedUnit = 'ml';
      if (_totalQtyController.text == '30' || _totalQtyController.text.isEmpty) {
        _totalQtyController.text = '100';
      }
    } else if (lower.contains('inhaler') || lower.contains('puff') || lower.contains('spray') || lower.contains('rotahaler') || lower.contains('respicap')) {
      _selectedShape = 'inhaler';
      if (match == null) _selectedUnit = 'puffs';
      if (_totalQtyController.text == '30' || _totalQtyController.text.isEmpty) {
        _totalQtyController.text = '120';
      }
    } else if (lower.contains('shot') || lower.contains('injection') || lower.contains('vaccine') || lower.contains('pen') || lower.contains('vial')) {
      _selectedShape = 'injection';
      if (match == null) _selectedUnit = 'ml';
      if (_totalQtyController.text == '30' || _totalQtyController.text.isEmpty) {
        _totalQtyController.text = '10';
      }
    } else if (lower.contains('capsule') || lower.contains('cap')) {
      _selectedShape = 'capsule';
    } else if (lower.contains('tablet') || lower.contains('tab')) {
      _selectedShape = 'round';
    }

    setState(() {});
  }

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
      if (proceed != true || !mounted) return;
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
    );

    final isPrn = _selectedFrequency == 'As needed (PRN)';
    if (!isPrn && _reminderSlots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one reminder time, or choose As needed (PRN).')),
      );
      return;
    }
    final isSpecificDates = _selectedFrequency == 'Specific dates';
    final frequencyType = isPrn
        ? 'as_needed'
        : _selectedFrequency == 'Every 2 days'
            ? 'alternate'
            : isSpecificDates
                ? 'specific_dates'
                : 'daily';

    final startDateStr = isSpecificDates
        ? '${_courseStartDate.year.toString().padLeft(4, '0')}-${_courseStartDate.month.toString().padLeft(2, '0')}-${_courseStartDate.day.toString().padLeft(2, '0')}'
        : null;
    final endDateStr = isSpecificDates
        ? '${_courseEndDate.year.toString().padLeft(4, '0')}-${_courseEndDate.month.toString().padLeft(2, '0')}-${_courseEndDate.day.toString().padLeft(2, '0')}'
        : null;

    // PRN doses are logged manually and deliberately do not create an alarm.
    final medId = isPrn
        ? await AppController.instance.addMedicineWithoutSchedule(newMedicine)
        : await AppController.instance.addMedicineWithSchedule(
            medicine: newMedicine,
            timeOfDay: _reminderSlots.first['time'].toString(),
            periodLabel: _reminderSlots.first['label'].toString(),
            frequencyType: frequencyType,
            startDate: startDateStr,
            endDate: endDateStr,
          );

    // Save additional slots if more than 1
    if (!isPrn && _reminderSlots.length > 1) {
      for (int i = 1; i < _reminderSlots.length; i++) {
        final slot = _reminderSlots[i];
        final rawTime = slot['time'].toString();
        await DatabaseHelper.instance.insertSchedule(
          ScheduleModel(
            medicineId: medId,
            timeOfDay: rawTime,
            periodLabel: slot['label'].toString(),
            doseCount: 1,
            frequencyType: frequencyType,
            startDate: startDateStr,
            endDate: endDateStr,
          ),
        );
      }
      await AppController.instance.refreshData();
    }



    // Reset form to clean initial state
    _resetForm();

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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Clear / Reset Form',
            onPressed: () {
              _resetForm();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Form reset to default'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Medication Identity Form
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

  // Comprehensive medicine database for auto-search
  static const List<String> _medicineDatabase = [
    // ─── Antibiotics ───────────────────────────────────────────────────────────
    'Amoxicillin 250mg', 'Amoxicillin 500mg', 'Amoxicillin-Clavulanate 625mg',
    'Azithromycin 250mg', 'Azithromycin 500mg',
    'Ciprofloxacin 250mg', 'Ciprofloxacin 500mg',
    'Doxycycline 100mg', 'Metronidazole 400mg', 'Metronidazole 500mg',
    'Cephalexin 250mg', 'Cephalexin 500mg', 'Clindamycin 300mg',
    'Levofloxacin 250mg', 'Levofloxacin 500mg', 'Trimethoprim-Sulfamethoxazole 480mg',
    'Ofloxacin 200mg', 'Ofloxacin 400mg', 'Norfloxacin 400mg',
    'Cefixime 100mg', 'Cefixime 200mg', 'Cefpodoxime 100mg', 'Cefpodoxime 200mg',
    'Nitrofurantoin 50mg', 'Nitrofurantoin 100mg',
    'Clarithromycin 250mg', 'Clarithromycin 500mg',
    'Erythromycin 250mg', 'Erythromycin 500mg',
    'Piperacillin-Tazobactam 4.5g Injection',
    // Indian branded antibiotics
    'Augmentin 625mg', 'Azee 500mg', 'Cifran 500mg', 'Ciplox 500mg',
    'Mox 500mg', 'Taxim-O 200mg', 'Zenflox 200mg',

    // ─── Pain & Fever ──────────────────────────────────────────────────────────
    'Paracetamol 325mg', 'Paracetamol 500mg', 'Paracetamol 650mg',
    'Ibuprofen 200mg', 'Ibuprofen 400mg', 'Ibuprofen 600mg',
    'Aspirin 75mg', 'Aspirin 150mg', 'Aspirin 325mg',
    'Diclofenac 50mg', 'Diclofenac 75mg', 'Naproxen 250mg', 'Naproxen 500mg',
    'Tramadol 50mg', 'Tramadol 100mg', 'Mefenamic Acid 250mg', 'Mefenamic Acid 500mg',
    'Aceclofenac 100mg', 'Aceclofenac + Paracetamol', 'Ketorolac 10mg',
    'Etoricoxib 60mg', 'Etoricoxib 90mg', 'Celecoxib 100mg', 'Celecoxib 200mg',
    'Tapentadol 50mg', 'Tapentadol 100mg',
    // Indian branded pain & fever
    'Dolo 650mg', 'Calpol 500mg', 'Crocin 500mg', 'Crocin 650mg',
    'Combiflam Tablet', 'Combiflam Plus',
    'Voveran 50mg', 'Zerodol 100mg', 'Zerodol-P', 'Hifenac-P',
    'Brufen 400mg', 'Nise 100mg',

    // ─── Diabetes ──────────────────────────────────────────────────────────────
    'Metformin 500mg', 'Metformin 850mg', 'Metformin 1000mg',
    'Glibenclamide 5mg', 'Glimepiride 1mg', 'Glimepiride 2mg', 'Glimepiride 4mg',
    'Voglibose 0.2mg', 'Voglibose 0.3mg', 'Sitagliptin 100mg', 'Teneligliptin 20mg',
    'Dapagliflozin 5mg', 'Dapagliflozin 10mg', 'Empagliflozin 10mg', 'Empagliflozin 25mg',
    'Canagliflozin 100mg', 'Linagliptin 5mg', 'Saxagliptin 5mg', 'Alogliptin 25mg',
    'Pioglitazone 15mg', 'Pioglitazone 30mg', 'Gliclazide 30mg', 'Gliclazide 80mg',
    // Indian diabetes brands
    'Glycomet 500mg', 'Glycomet 850mg', 'Glycomet GP1', 'Glycomet GP2',
    'Jalra-M 50/500mg', 'Janumet 50/500mg', 'Glucophage 500mg',
    'Galvus 50mg', 'Trajenta 5mg', 'Forxiga 10mg', 'Jardiance 10mg',
    // Insulins
    'Insulin Regular 40IU/ml', 'Insulin Regular 100IU/ml',
    'Insulin NPH 40IU/ml', 'Insulin NPH 100IU/ml',
    'Insulin Glargine (Lantus) 100IU/ml', 'Insulin Detemir 100IU/ml',
    'Insulin Lispro 100IU/ml', 'Insulin Aspart 100IU/ml',
    'Huminsulin 30/70', 'Novomix 30 FlexPen',

    // ─── Blood Pressure & Heart ────────────────────────────────────────────────
    'Amlodipine 2.5mg', 'Amlodipine 5mg', 'Amlodipine 10mg',
    'Atenolol 25mg', 'Atenolol 50mg', 'Atenolol 100mg',
    'Losartan 25mg', 'Losartan 50mg', 'Losartan 100mg',
    'Telmisartan 20mg', 'Telmisartan 40mg', 'Telmisartan 80mg',
    'Enalapril 2.5mg', 'Enalapril 5mg', 'Enalapril 10mg',
    'Ramipril 2.5mg', 'Ramipril 5mg', 'Metoprolol 25mg', 'Metoprolol 50mg',
    'Furosemide 20mg', 'Furosemide 40mg', 'Spironolactone 25mg',
    'Rosuvastatin 5mg', 'Rosuvastatin 10mg', 'Rosuvastatin 20mg',
    'Atorvastatin 10mg', 'Atorvastatin 20mg', 'Atorvastatin 40mg',
    'Carvedilol 3.125mg', 'Carvedilol 6.25mg', 'Carvedilol 12.5mg',
    'Bisoprolol 2.5mg', 'Bisoprolol 5mg', 'Bisoprolol 10mg',
    'Nebivolol 5mg', 'Olmesartan 20mg', 'Olmesartan 40mg',
    'Valsartan 40mg', 'Valsartan 80mg', 'Valsartan 160mg',
    'Candesartan 4mg', 'Candesartan 8mg', 'Candesartan 16mg',
    'Hydrochlorothiazide 12.5mg', 'Hydrochlorothiazide 25mg',
    'Chlorthalidone 12.5mg', 'Chlorthalidone 25mg',
    'Nifedipine 10mg', 'Nifedipine 20mg Retard',
    'Digoxin 0.25mg', 'Isosorbide Dinitrate 5mg', 'Isosorbide Mononitrate 20mg',
    'Clopidogrel 75mg', 'Warfarin 1mg', 'Warfarin 2mg', 'Warfarin 5mg',
    'Rivaroxaban 10mg', 'Rivaroxaban 15mg', 'Rivaroxaban 20mg',
    'Apixaban 2.5mg', 'Apixaban 5mg',
    // Indian BP brands
    'Telma 40mg', 'Telma-H 40mg', 'Telma-AM 40mg',
    'Stamlo 5mg', 'Stamlo Beta', 'Amlokind 5mg', 'Tazloc 40mg',
    'Olsar 20mg', 'Valent 80mg', 'Cardivas 6.25mg',

    // ─── Gastroenterology ─────────────────────────────────────────────────────
    'Omeprazole 10mg', 'Omeprazole 20mg', 'Omeprazole 40mg',
    'Pantoprazole 20mg', 'Pantoprazole 40mg', 'Rabeprazole 20mg',
    'Domperidone 10mg', 'Ondansetron 4mg', 'Ondansetron 8mg',
    'Ranitidine 150mg', 'Famotidine 20mg', 'Esomeprazole 20mg', 'Esomeprazole 40mg',
    'Lansoprazole 15mg', 'Lansoprazole 30mg',
    'Metoclopramide 10mg', 'Itopride 50mg', 'Mosapride 2.5mg', 'Mosapride 5mg',
    'Loperamide 2mg', 'Dicyclomine 10mg', 'Mebeverine 135mg', 'Drotaverine 40mg',
    'Bisacodyl 5mg', 'Senna 7.5mg', 'Lactulose 10g/15ml',
    'Probiotics (Saccharomyces boulardii)', 'Probiotics (Lactobacillus)', 'ORS Sachet',
    // Indian gastro brands
    'Omez 20mg', 'Pan 40mg', 'Pantop 40mg', 'Nexpro 40mg',
    'Razo 20mg', 'Nexpro-L', 'Pan-D Capsule', 'Gelusil Tablet',
    'Digene Tablet', 'Digene Gel 200ml', 'Eno Fruit Salt Sachet',
    'Becosules Capsule', 'Normogesic Tablet',

    // ─── Respiratory & Allergy ────────────────────────────────────────────────
    'Cetirizine 5mg', 'Cetirizine 10mg', 'Fexofenadine 120mg', 'Fexofenadine 180mg',
    'Loratadine 10mg', 'Desloratadine 5mg', 'Levocetirizine 2.5mg', 'Levocetirizine 5mg',
    'Chlorpheniramine 4mg', 'Hydroxyzine 10mg', 'Hydroxyzine 25mg',
    'Montelukast 4mg', 'Montelukast 5mg', 'Montelukast 10mg',
    'Salbutamol 2mg', 'Salbutamol 4mg', 'Salbutamol Inhaler 100mcg',
    'Budesonide Inhaler 200mcg', 'Fluticasone Inhaler 125mcg',
    'Ipratropium Inhaler 20mcg', 'Tiotropium 18mcg',
    'Salmeterol + Fluticasone Inhaler', 'Formoterol + Budesonide Inhaler',
    'Theophylline 100mg', 'Theophylline 200mg', 'Theophylline 300mg',
    'Dextromethorphan 15mg', 'Bromhexine 8mg', 'Ambroxol 30mg', 'Ambroxol 75mg',
    'Codeine 10mg',
    // Indian respiratory brands
    'Asthalin Inhaler 100mcg', 'Budecort Inhaler 200mcg',
    'Foracort 400 Inhaler', 'Seroflo 250 Inhaler',
    'Ascoril LS Syrup 100ml', 'Grilinctus-BM Syrup 100ml',
    'Phensedyl Cough Syrup 100ml', 'Benadryl Cough Syrup 100ml',
    'Alex Syrup 100ml', 'Solvin Cold Tablet',

    // ─── Vitamins & Supplements ───────────────────────────────────────────────
    'Vitamin D3 1000 IU', 'Vitamin D3 2000 IU', 'Vitamin D3 60000 IU',
    'Vitamin B12 500mcg', 'Vitamin B12 1000mcg',
    'Calcium + Vitamin D3 500mg', 'Ferrous Sulfate 200mg',
    'Folic Acid 400mcg', 'Folic Acid 5mg', 'Zinc 10mg', 'Zinc 20mg',
    'Multivitamin Daily', 'Omega-3 Fish Oil 1000mg',
    'Iron + Folic Acid', 'Vitamin C 500mg', 'Vitamin E 400 IU',
    'Biotin 5mg', 'Biotin 10mg', 'B-Complex Tablet',
    'Vitamin B1 (Thiamine) 100mg', 'Pyridoxine (B6) 10mg', 'Niacin 500mg',
    'Magnesium Oxide 400mg', 'Magnesium Citrate 400mg',
    'Chromium 200mcg', 'Selenium 200mcg', 'Copper 2mg',
    'Coenzyme Q10 100mg', 'Lycopene 5000mcg',
    // Indian supplement brands
    'Becosules Z Capsule', 'Neurobion Forte Tablet', 'Revital H Capsule',
    'Supradyn Daily Tablet', 'Shelcal 500mg', 'Calcidol 500mg',
    'Evion 400 Capsule', 'Surbex-Z Tablet', 'Zincovit Tablet',
    'Calcimax Forte', 'HealthOK Tablet', 'Limcee 500mg',

    // ─── Thyroid ──────────────────────────────────────────────────────────────
    'Levothyroxine 12.5mcg', 'Levothyroxine 25mcg',
    'Levothyroxine 50mcg', 'Levothyroxine 75mcg', 'Levothyroxine 100mcg',
    'Levothyroxine 125mcg', 'Levothyroxine 150mcg',
    'Carbimazole 5mg', 'Carbimazole 10mg', 'Propylthiouracil 50mg',
    // Indian thyroid brands
    'Eltroxin 50mcg', 'Thyronorm 25mcg', 'Thyronorm 50mcg', 'Thyronorm 75mcg',
    'Thyronorm 100mcg', 'Thyrox 50mcg', 'Neomercazole 5mg',

    // ─── Mental Health & Neurology ────────────────────────────────────────────
    'Sertraline 25mg', 'Sertraline 50mg', 'Sertraline 100mg',
    'Escitalopram 5mg', 'Escitalopram 10mg', 'Escitalopram 20mg',
    'Fluoxetine 10mg', 'Fluoxetine 20mg', 'Paroxetine 12.5mg', 'Paroxetine 25mg',
    'Venlafaxine 37.5mg', 'Venlafaxine 75mg', 'Duloxetine 20mg', 'Duloxetine 60mg',
    'Mirtazapine 7.5mg', 'Mirtazapine 15mg', 'Mirtazapine 30mg',
    'Alprazolam 0.25mg', 'Alprazolam 0.5mg', 'Clonazepam 0.25mg', 'Clonazepam 0.5mg',
    'Diazepam 2mg', 'Diazepam 5mg', 'Lorazepam 0.5mg', 'Lorazepam 1mg',
    'Gabapentin 100mg', 'Gabapentin 300mg', 'Pregabalin 75mg', 'Pregabalin 150mg',
    'Quetiapine 25mg', 'Quetiapine 50mg', 'Quetiapine 100mg',
    'Olanzapine 2.5mg', 'Olanzapine 5mg', 'Olanzapine 10mg',
    'Risperidone 0.5mg', 'Risperidone 1mg', 'Risperidone 2mg',
    'Haloperidol 0.5mg', 'Haloperidol 1.5mg', 'Lithium 300mg',
    'Valproate 200mg', 'Valproate 500mg', 'Carbamazepine 100mg', 'Carbamazepine 200mg',
    'Phenytoin 50mg', 'Phenytoin 100mg', 'Levetiracetam 250mg', 'Levetiracetam 500mg',
    'Donepezil 5mg', 'Donepezil 10mg', 'Memantine 5mg', 'Memantine 10mg',
    'Levodopa-Carbidopa 100/25mg', 'Pramipexole 0.25mg', 'Pramipexole 0.5mg',
    'Melatonin 1mg', 'Melatonin 3mg', 'Melatonin 5mg', 'Zolpidem 5mg', 'Zolpidem 10mg',
    'Amitriptyline 10mg', 'Amitriptyline 25mg', 'Nortriptyline 10mg', 'Nortriptyline 25mg',
    // Indian neuro/mental brands
    'Risdone 2mg', 'Olanex 5mg', 'Oleanz 5mg', 'Serenace 1.5mg',
    'Nexito 10mg', 'Stalopam 10mg', 'Zoloft 50mg',

    // ─── Women's Health ───────────────────────────────────────────────────────
    'Progesterone 100mg', 'Progesterone 200mg', 'Progesterone 400mg',
    'Dydrogesterone 10mg', 'Norethisterone 5mg',
    'Estradiol Valerate 1mg', 'Estradiol Valerate 2mg',
    'Mifepristone 200mg', 'Misoprostol 200mcg',
    'Clomiphene 25mg', 'Clomiphene 50mg', 'Letrozole 2.5mg',
    'Folic Acid 5mg (Pregnancy)', 'Iron Sucrose Injection 100mg',
    'Calcium + Folic Acid + Vitamin D3', 'Ferrous Ascorbate 100mg',
    // Indian women's health brands
    'Susten 200mg', 'Susten 400mg', 'Duphaston 10mg',
    'Ovral-G Tablet', 'Mala-D Tablet', 'Unwanted 72 Tablet',
    'Progynova 1mg', 'Progynova 2mg', 'Primolut-N 5mg',
    'Clofert 50mg', 'Fertyl 50mg',

    // ─── Urology & Kidney ─────────────────────────────────────────────────────
    'Tamsulosin 0.2mg', 'Tamsulosin 0.4mg', 'Alfuzosin 10mg',
    'Finasteride 1mg', 'Finasteride 5mg', 'Dutasteride 0.5mg',
    'Sildenafil 25mg', 'Sildenafil 50mg', 'Sildenafil 100mg',
    'Tadalafil 5mg', 'Tadalafil 10mg', 'Tadalafil 20mg',
    'Desmopressin 0.1mg', 'Tolterodine 2mg', 'Solifenacin 5mg',
    'Allopurinol 100mg', 'Allopurinol 300mg', 'Febuxostat 40mg', 'Febuxostat 80mg',

    // ─── Skin & Dermatology ───────────────────────────────────────────────────
    'Clotrimazole 1% Cream 15g', 'Miconazole 2% Cream 15g',
    'Terbinafine 1% Cream 15g', 'Ketoconazole 2% Cream 15g',
    'Betamethasone + Clotrimazole Cream', 'Clobetasol 0.05% Cream',
    'Hydrocortisone 1% Cream', 'Mometasone 0.1% Cream',
    'Tretinoin 0.025% Cream', 'Tretinoin 0.05% Cream',
    'Permethrin 5% Cream', 'Calamine Lotion 100ml', 'Mupirocin 2% Ointment',
    'Fusidic Acid 2% Cream', 'Soframycin Cream 30g',
    // Indian skin brands
    'Betadine Cream 10g', 'Boroline Cream 20g', 'Candid B Cream',
    'Panderm Cream', 'Tenovate Cream', 'Dermi-5 Cream',
    'Lobate Cream', 'Fucidin Cream 15g', 'T-Bact Ointment 5g',

    // ─── Eye Drops & Ear Drops ────────────────────────────────────────────────
    'Ciprofloxacin Eye Drops 0.3%', 'Ofloxacin Eye Drops 0.3%',
    'Tobramycin Eye Drops 0.3%', 'Gentamicin Eye Drops 0.3%',
    'Moxifloxacin Eye Drops 0.5%', 'Chloramphenicol Eye Drops 0.5%',
    'Prednisolone Eye Drops 1%', 'Dexamethasone Eye Drops 0.1%',
    'Betamethasone Eye Drops', 'Nepafenac Eye Drops 0.1%',
    'Latanoprost Eye Drops 0.005%', 'Timolol Eye Drops 0.5%',
    'Carboxymethylcellulose Eye Drops (Lubricant)',
    'Naphazoline + Chlorpheniramine Eye Drops',
    'Clotrimazole Ear Drops', 'Ofloxacin Ear Drops 0.3%',
    'Ciprofloxacin + Dexamethasone Ear Drops',
    'Carbamide Peroxide Ear Drops (Earwax Removal)',
    // Indian eye/ear brands
    'Cipla Eye Drops', 'Tobaflam Eye Drops', 'Zaha Eye Drops',
    'Moxi 0.5% Eye Drops', 'Moxicip 0.5%', 'Flurbiprofen Eye Drops',
    'Ocuflur Eye Drops', 'Ear Wax Softener Drops',

    // ─── Bone & Joint / Arthritis ────────────────────────────────────────────
    'Calcium Carbonate 500mg', 'Calcium Citrate 500mg',
    'Alendronate 70mg (Weekly)', 'Risedronate 35mg (Weekly)',
    'Ibandronate 150mg (Monthly)', 'Denosumab 60mg Injection',
    'Colchicine 0.5mg', 'Colchicine 1mg',
    'Teriparatide Injection 20mcg', 'Calcitonin Nasal Spray',
    'Methotrexate 2.5mg', 'Methotrexate 10mg',
    'Hydroxychloroquine 200mg', 'Sulfasalazine 500mg', 'Leflunomide 10mg', 'Leflunomide 20mg',
    'Chymoral Forte Tablet', 'Serratiopeptidase 5mg', 'Serratiopeptidase 10mg',
    'Diclofenac + Serratiopeptidase',
    // Indian bone/joint brands
    'Shelcal CT Tablet', 'Osteocalcium Tablet', 'Dynapar 75mg',
    'Voveran SR 100mg', 'Nucoxia 90mg', 'Arcoxia 60mg',

    // ─── Liver / Hepatology ───────────────────────────────────────────────────
    'Silymarin 140mg', 'Ursodeoxycholic Acid 150mg', 'Ursodeoxycholic Acid 300mg',
    'Ademetionine 400mg', 'N-Acetylcysteine 600mg',
    'Ornithine-Aspartate Sachet', 'Rifaximin 200mg', 'Rifaximin 400mg',
    'Tenofovir 300mg', 'Entecavir 0.5mg', 'Entecavir 1mg',
    'Sofosbuvir 400mg', 'Sofosbuvir + Ledipasvir 400/90mg',
    // Indian liver brands
    'Liv.52 Tablet', 'Liv.52 DS Tablet', 'Liv.52 Syrup 100ml',
    'Udiliv 300mg', 'Heptral 400mg', 'Zydus Liv.52',

    // ─── Cough / Cold / ENT ──────────────────────────────────────────────────
    'Cetirizine + Pseudoephedrine', 'Loratadine + Pseudoephedrine',
    'Xylometazoline Nasal Spray 0.05%', 'Xylometazoline Nasal Spray 0.1%',
    'Oxymetazoline Nasal Spray 0.05%', 'Fluticasone Nasal Spray',
    'Betamethasone Nasal Spray', 'Ipratropium Nasal Spray',
    'Bromhexine 8mg', 'Ambroxol 30mg', 'Guaifenesin 100mg',
    'Levosalbutamol 1mg', 'Levosalbutamol + Ambroxol Syrup',
    // Indian ENT brands
    'Sinarest Tablet', 'Coldact Capsule', 'D-Cold Total Tablet',
    'Otrivin Nasal Spray 0.1%', 'Nasivion Nasal Spray',
    'Ascoril LS Syrup 100ml', 'Grilinctus CD Syrup',
    'Koflet Lozenge', 'Strepsils Lozenge',

    // ─── Antacids / GI OTC ───────────────────────────────────────────────────
    'Aluminium Hydroxide + Magnesium Hydroxide', 'Magaldrate 400mg',
    'Sucralfate 1g', 'Simethicone 40mg',
    // Indian brands
    'Gelusil Tablet', 'Gelusil Gel 200ml', 'Digene Tablet', 'Digene Gel',
    'Eno Fruit Salt Original', 'Pudin Hara Capsule',

    // ─── Ayurvedic / Herbal (commonly prescribed in India) ───────────────────
    'Triphala Tablet', 'Triphala Churna 100g', 'Ashwagandha 300mg', 'Ashwagandha 600mg',
    'Shilajit 250mg', 'Brahmi 300mg', 'Shatavari 500mg',
    'Turmeric + Curcumin 500mg', 'Tulsi 500mg',
    'Haritaki Churna 100g', 'Giloy Ghan Vati',
    'Septilin Tablet', 'Bresol Tablet', 'Mentat Tablet',
    // Himalaya, Dabur, Baidyanath brands
    'Himalaya Liv.52', 'Himalaya Septilin', 'Himalaya Mentat',
    'Dabur Shilajit Gold Capsule', 'Dabur Ashwagandha Churna',
    'Baidyanath Vita-Ex Gold Plus',

    // ─── Liquids, Syrups & Suspensions ───────────────────────────────────────
    'Amoxicillin Oral Suspension 125mg/5ml', 'Amoxicillin Oral Suspension 250mg/5ml',
    'Paracetamol Pediatric Syrup 120mg/5ml', 'Paracetamol Pediatric Syrup 250mg/5ml',
    'Ibuprofen Oral Suspension 100mg/5ml', 'Cetirizine Syrup 5mg/5ml',
    'Antacid Liquid Gel 200ml', 'Lactulose Oral Solution 10g/15ml',
    'Dextromethorphan Syrup 100ml', 'Azithromycin Oral Suspension 200mg/5ml',
    'Zinc Sulfate Syrup 20mg/5ml', 'Salbutamol Syrup 2mg/5ml',
    'Multivitamin Liquid 200ml', 'Saline Nasal Spray 100ml',
    'Cough Syrup 100ml', 'Benadryl Cough Syrup 100ml',
    'ORS Sachet (Electrolyte)', 'Albendazole 400mg Tablet',
    'Mebendazole 100mg', 'Ivermectin 3mg', 'Ivermectin 6mg',
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
            key: ValueKey('medicine-autocomplete-$_formResetVersion'),
            displayStringForOption: (String option) {
              final clean = option
                  .replaceAll(_strengthRegex, '')
                  .replaceAll(RegExp(r'\s+'), ' ')
                  .trim();
              return clean.isNotEmpty ? clean : option;
            },
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
              _applyMedicineSelection(selection);
            },
            fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
              if (_autocompleteTextController != controller) {
                _autocompleteTextController = controller;
                controller.addListener(() {
                  if (_nameController.text != controller.text) {
                    _nameController.text = controller.text;
                  }
                });
              }
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
                            _strengthController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                ),
                onFieldSubmitted: (val) {
                  _applyMedicineSelection(val);
                  onFieldSubmitted();
                },
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
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                      key: ValueKey(_selectedUnit),
                      initialValue: _availableUnits.contains(_selectedUnit) ? _selectedUnit : 'mg',
                      decoration: const InputDecoration(),
                      items: _availableUnits.map((u) {
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
                  '${_selectedShape.toUpperCase()} • ${_selectedColor.toUpperCase()}${_strengthController.text.isNotEmpty ? ' • ${_strengthController.text} $_selectedUnit' : ''}',
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
    final frequencies = ['Every day', 'Specific dates', 'Every 2 days', 'As needed (PRN)'];
    final isPrn = _selectedFrequency == 'As needed (PRN)';
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
              if (isPrn)
                Text(
                  'Log from Today',
                  style: AppTypography.labelMd(color: AppColors.secondary).copyWith(fontWeight: FontWeight.bold),
                )
              else
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

          // Date Range Calendar View if 'Specific dates' selected
          if (_selectedFrequency == 'Specific dates') ...[
            DateRangeCalendarView(
              startDate: _courseStartDate,
              endDate: _courseEndDate,
              onRangeChanged: (range) {
                setState(() {
                  _courseStartDate = range.start;
                  _courseEndDate = range.end;
                });
              },
            ),
            const SizedBox(height: 16),
          ],

          if (isPrn) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'PRN medicines have no preset reminder. Use “Log PRN” on Today whenever you take a dose.',
                style: AppTypography.bodySm(color: AppColors.onSecondaryContainer),
              ),
            ),
            const SizedBox(height: 12),
          ] else ...[
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
                                '${slot['label']} • 1 ${_selectedShape.toUpperCase()}${_strengthController.text.isNotEmpty ? ' (${_strengthController.text} $_selectedUnit)' : ''}',
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
          ],
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
        ],
      ),
    );
  }
}
