import 'package:flutter/material.dart';
import 'package:medimate/core/constants/app_colors.dart';
import 'package:medimate/core/constants/app_typography.dart';
import 'package:medimate/data/models/medicine_model.dart';
import 'package:medimate/presentation/controllers/app_controller.dart';
import 'package:medimate/presentation/widgets/pill_visualizer.dart';
import 'package:medimate/presentation/widgets/dosecare_logo.dart';

class InventoryScreen extends StatefulWidget {
  final VoidCallback? onAddMedicine;

  const InventoryScreen({super.key, this.onAddMedicine});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final AppController _controller = AppController.instance;
  final TextEditingController _searchController = TextEditingController();
  String _activeFilter = 'all'; // all, low, daily, prn
  String? _toastMessage;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onStateChange);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _controller.removeListener(_onStateChange);
    super.dispose();
  }

  void _onStateChange() {
    if (mounted) setState(() {});
  }

  void _showRefillToast(String message) {
    setState(() => _toastMessage = message);
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _toastMessage = null);
    });
  }

  List<MedicineModel> _getFilteredMedicines() {
    final query = _searchController.text.trim().toLowerCase();
    return _controller.medicines.where((m) {
      final matchesSearch = m.name.toLowerCase().contains(query) ||
          m.brandName.toLowerCase().contains(query);

      if (!matchesSearch) return false;

      if (_activeFilter == 'low') return m.isLowStock;
      if (_activeFilter == 'daily') return m.type != 'inhaler';
      if (_activeFilter == 'prn') return m.type == 'inhaler' || m.foodInstruction.contains('as needed');
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _getFilteredMedicines();
    final lowCount = _controller.medicines.where((m) => m.isLowStock).length;

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
                  'Medications',
                  style: AppTypography.labelSm(color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dynamic Refill Toast
            if (_toastMessage != null) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: AppColors.onSecondaryContainer, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _toastMessage!,
                        style: AppTypography.labelMd(color: AppColors.onSecondaryContainer),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () => setState(() => _toastMessage = null),
                    ),
                  ],
                ),
              ),
            ],

            // 1. Search Bar
            TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search pill name, condition, Rx #...',
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.outline),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.cancel_rounded, color: AppColors.outline, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 12),

            // 2. Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('all', 'All (${_controller.medicines.length})'),
                  _buildFilterChip('low', 'Needs Refill ($lowCount)', isLowWarning: true),
                  _buildFilterChip('daily', 'Daily Routine'),
                  _buildFilterChip('prn', 'As Needed (PRN)'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 3. Low Stock Alert Banner (if any)
            if (lowCount > 0) ...[
              _buildLowStockBanner(lowCount),
              const SizedBox(height: 20),
            ],

            // 4. Medication Cards List
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.outlineVariant.withValues(alpha: 0.3)),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.medication_rounded, size: 28, color: AppColors.primary),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _controller.medicines.isEmpty ? 'No Medications in Inventory' : 'No Matching Medications',
                          style: AppTypography.headlineSm(color: AppColors.onSurface).copyWith(fontSize: 17),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _controller.medicines.isEmpty
                              ? 'Your dispensary cabinet is clean. Add your medications to track pill counts, auto-refills, and dosages.'
                              : 'No medications found matching your current search or filter chip.',
                          style: AppTypography.bodySm(color: AppColors.onSurfaceVariant),
                          textAlign: TextAlign.center,
                        ),
                        if (_controller.medicines.isEmpty) ...[
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () => widget.onAddMedicine?.call(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.add_rounded, size: 20),
                            label: const Text('Add Medication'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              )
            else
              ...filtered.map((med) => _buildMedicationCard(med)),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String key, String label, {bool isLowWarning = false}) {
    final isSelected = _activeFilter == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => setState(() => _activeFilter = key),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLowWarning) ...[
                Container(
                  width: 7,
                  height: 7,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: const BoxDecoration(color: AppColors.alertCoral, shape: BoxShape.circle),
                ),
              ],
              Text(
                label,
                style: AppTypography.labelMd(
                  color: isSelected ? Colors.white : AppColors.onSurfaceVariant,
                ).copyWith(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLowStockBanner(int lowCount) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.warning_rounded, color: AppColors.error, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        '$lowCount prescriptions running low!',
                        style: AppTypography.labelLg(color: AppColors.onErrorContainer).copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Action Needed',
                        style: AppTypography.labelSm(color: AppColors.error).copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                Builder(
                  builder: (context) {
                    final lowMeds = _controller.medicines.where((m) => m.isLowStock).toList();
                    final firstLow = lowMeds.isNotEmpty ? lowMeds.first : null;
                    return Text(
                      firstLow != null
                          ? '${firstLow.name} has only ${firstLow.remainingQuantity} doses remaining. Run-out expected in ~${firstLow.estimatedDaysRemaining(1)} days.'
                          : 'Your supplies are running low. Tap Reorder to refill now.',
                      style: AppTypography.bodySm(color: AppColors.onErrorContainer),
                    );
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () async {
                        await _controller.bulkReorderLowStock();
                        _showRefillToast('Added 30 doses to each low-stock medication.');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(130, 38),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      icon: const Icon(Icons.shopping_cart_checkout_rounded, size: 16),
                      label: const Text('Reorder All Low'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicationCard(MedicineModel med) {
    final percent = med.stockPercentage;
    final isLow = med.isLowStock;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PillVisualizer(
                shape: med.type,
                colorName: med.pillColor,
                imprintCode: med.imprintCode,
                width: 44,
                height: 44,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            med.name,
                            style: AppTypography.headlineSm(color: AppColors.onSurface).copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (med.brandName.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              med.brandName,
                              style: AppTypography.labelSm(color: AppColors.onSurfaceVariant),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${med.dosage} • ${med.type.toUpperCase()}',
                      style: AppTypography.bodySm(color: AppColors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isLow ? AppColors.alertCoralBg : AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${med.remainingQuantity} Left',
                  style: AppTypography.labelSm(
                    color: isLow ? AppColors.alertCoral : AppColors.onSurface,
                  ).copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Instruction tag
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.restaurant_rounded, size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    med.foodInstruction,
                    style: AppTypography.bodySm(color: AppColors.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Supply Tracker Bar
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Row(
                        children: [
                          Icon(
                            Icons.timelapse_rounded,
                            size: 14,
                            color: isLow ? AppColors.alertCoral : AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              () {
                                final unit = (med.type == 'liquid' || med.type == 'inhaler' || med.type == 'injection')
                                    ? 'doses'
                                    : 'pills';
                                return '${med.remainingQuantity} of ${med.totalQuantity} $unit left (${(percent * 100).round()}%)';
                              }(),
                              style: AppTypography.labelSm(
                                color: isLow ? AppColors.alertCoral : AppColors.onSurface,
                              ).copyWith(fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '~${med.estimatedDaysRemaining(1)}d supply',
                      style: AppTypography.bodySm(color: AppColors.onSurfaceVariant).copyWith(fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: percent,
                    minHeight: 7,
                    backgroundColor: AppColors.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isLow ? AppColors.alertCoral : AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Stock actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Update stock after purchasing medication.',
                style: AppTypography.bodySm(color: AppColors.outline).copyWith(fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    if (med.id != null) {
                      await _controller.refillMedicine(med.id!, 30);
                      final unit = (med.type == 'liquid' || med.type == 'inhaler' || med.type == 'injection')
                          ? 'doses'
                          : 'pills';
                      _showRefillToast('Added 30 $unit to ${med.name}.');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    minimumSize: const Size(0, 42),
                  ),
                  icon: const Icon(Icons.sync_rounded, size: 18),
                  label: const Text('Add 30 doses'),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: () => _showEditMedicineModal(med),
                style: OutlinedButton.styleFrom(
                  backgroundColor: AppColors.surfaceContainerHigh,
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  minimumSize: const Size(100, 42),
                ),
                icon: const Icon(Icons.edit_outlined, size: 16, color: AppColors.onSurfaceVariant),
                label: Text('Edit Dose', style: AppTypography.labelMd(color: AppColors.onSurface)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showEditMedicineModal(MedicineModel med) {
    final dosageCtrl = TextEditingController(text: med.dosage);
    int remaining = med.remainingQuantity;
    int threshold = med.lowStockThreshold;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Edit ${med.name}',
                        style: AppTypography.headlineSm(color: AppColors.onSurface).copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Dosage field
                  Text('Dosage / Strength', style: AppTypography.labelMd(color: AppColors.onSurfaceVariant)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: dosageCtrl,
                    decoration: const InputDecoration(hintText: 'e.g. 500 mg, 1 tablet'),
                  ),
                  const SizedBox(height: 14),

                  // Remaining Quantity Stepper
                  Builder(builder: (ctx2) {
                    final unitLbl = (med.type == 'liquid') ? 'ml' : (med.type == 'inhaler') ? 'puffs' : (med.type == 'injection') ? 'doses' : 'pills';
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${unitLbl[0].toUpperCase()}${unitLbl.substring(1)} Remaining in Supply', style: AppTypography.labelMd(color: AppColors.onSurfaceVariant)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            IconButton.filledTonal(
                              icon: const Icon(Icons.remove_rounded),
                              onPressed: remaining > 0 ? () => setModalState(() => remaining--) : null,
                            ),
                            const SizedBox(width: 16),
                            Text(
                              '$remaining $unitLbl',
                              style: AppTypography.headlineSm(color: AppColors.onSurface).copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 16),
                            IconButton.filledTonal(
                              icon: const Icon(Icons.add_rounded),
                              onPressed: () => setModalState(() => remaining++),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Low Stock Threshold Stepper
                        Text('Low Stock Alert Threshold', style: AppTypography.labelMd(color: AppColors.onSurfaceVariant)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            IconButton.filledTonal(
                              icon: const Icon(Icons.remove_rounded),
                              onPressed: threshold > 1 ? () => setModalState(() => threshold--) : null,
                            ),
                            const SizedBox(width: 16),
                            Text(
                              '$threshold $unitLbl',
                              style: AppTypography.headlineSm(color: AppColors.onSurface).copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 16),
                            IconButton.filledTonal(
                              icon: const Icon(Icons.add_rounded),
                              onPressed: () => setModalState(() => threshold++),
                            ),
                          ],
                        ),
                      ],
                    );
                  }),
                  const SizedBox(height: 20),

                  // Buttons: Save and Delete
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final updated = med.copyWith(
                              dosage: dosageCtrl.text.trim().isNotEmpty ? dosageCtrl.text.trim() : med.dosage,
                              remainingQuantity: remaining,
                              lowStockThreshold: threshold,
                            );
                            await _controller.updateMedicine(updated);
                            if (ctx.mounted) Navigator.pop(ctx);
                            _showRefillToast('Updated ${med.name} details ✓');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            minimumSize: const Size(0, 48),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.check_rounded, color: Colors.white),
                          label: const Text('Save Changes', style: TextStyle(color: Colors.white)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.alertCoralBg,
                          padding: const EdgeInsets.all(12),
                        ),
                        icon: const Icon(Icons.delete_outline_rounded, color: AppColors.alertCoral),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (dCtx) => AlertDialog(
                              title: Text('Delete ${med.name}?'),
                              content: const Text('This will remove this medication from your cabinet and schedule.'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.alertCoral),
                                  onPressed: () => Navigator.pop(dCtx, true),
                                  child: const Text('Delete', style: TextStyle(color: Colors.white)),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true && med.id != null) {
                            await _controller.deleteMedicine(med.id!);
                            if (ctx.mounted) Navigator.pop(ctx);
                            _showRefillToast('${med.name} removed from inventory.');
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
