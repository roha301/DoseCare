import 'package:flutter/material.dart';
import 'package:medimate/core/constants/app_colors.dart';
import 'package:medimate/core/constants/app_typography.dart';
import 'package:medimate/presentation/screens/today/today_screen.dart';
import 'package:medimate/presentation/screens/inventory/inventory_screen.dart';
import 'package:medimate/presentation/screens/add_medicine/add_medicine_screen.dart';
import 'package:medimate/presentation/screens/insights/insights_screen.dart';
import 'package:medimate/presentation/screens/profile/profile_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  void _onTabSelected(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      TodayScreen(
        onNavigateToAdd: () => _onTabSelected(2),
        onNavigateToMeds: () => _onTabSelected(1),
        onNavigateToProfile: () => _onTabSelected(4),
      ),
      InventoryScreen(
        onAddMedicine: () => _onTabSelected(2),
      ),
      AddMedicineScreen(
        onSaved: () => _onTabSelected(0),
      ),
      const InsightsScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.95),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 68,
            child: Row(
              children: [
                Expanded(child: _buildNavItem(0, Icons.calendar_today_rounded, 'Today')),
                Expanded(child: _buildNavItem(1, Icons.medication_rounded, 'Meds')),
                Expanded(child: _buildAddButton(2)),
                Expanded(child: _buildNavItem(3, Icons.bar_chart_rounded, 'Insights')),
                Expanded(child: _buildNavItem(4, Icons.person_rounded, 'Profile')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? AppColors.primary : AppColors.onSurfaceVariant;

    return InkWell(
      onTap: () => _onTabSelected(index),
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(height: 3),
            Text(
              label,
              style: AppTypography.labelSm(color: color).copyWith(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton(int index) {
    final isSelected = _currentIndex == index;

    return InkWell(
      onTap: () => _onTabSelected(index),
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 2),
            Text(
              'Add',
              style: AppTypography.labelSm(
                color: isSelected ? AppColors.primary : AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
