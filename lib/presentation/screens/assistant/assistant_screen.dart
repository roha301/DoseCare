import 'package:flutter/material.dart';
import 'package:medimate/core/constants/app_colors.dart';
import 'package:medimate/core/constants/app_typography.dart';
import 'package:medimate/presentation/controllers/app_controller.dart';

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final TextEditingController _messageController = TextEditingController();
  late List<Map<String, dynamic>> _messages;

  @override
  void initState() {
    super.initState();
    final name = AppController.instance.user?.name.split(' ').first ?? 'there';
    _messages = [
      {
        'isUser': false,
        'text':
            'Hello $name, I am your DoseCare schedule assistant. I can summarize information recorded in this app, but I do not provide medical advice.',
      },
    ];
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _sendMessage(String query) {
    if (query.trim().isEmpty) return;

    setState(() {
      _messages.add({'isUser': true, 'text': query});
    });
    _messageController.clear();

    final q = query.toLowerCase();
    final controller = AppController.instance;
    final meds = controller.medicines;
    final timeline = controller.todayTimeline;

    String response;

    if (meds.isEmpty) {
      response =
          'You currently have no medications in your cabinet. Tap the "+" button at the bottom to add your prescriptions and schedules.';
    } else if (q.contains('today') || q.contains('schedule') || q.contains('next')) {
      final pending = timeline.where((t) => t.isPending).toList();
      final taken = timeline.where((t) => t.isTaken).toList();

      if (pending.isEmpty && taken.isEmpty) {
        response = 'You have ${meds.length} medications in your cabinet, but none are scheduled for today.';
      } else if (pending.isEmpty) {
        response = 'All ${taken.length} scheduled doses for today have been completed! Great job on your adherence!';
      } else {
        final nextMed = pending.first;
        response =
            'You have ${pending.length} pending dose(s) today. Your next dose is ${nextMed.medicine.name} (${nextMed.medicine.dosage}) scheduled at ${nextMed.schedule.timeOfDay}.';
      }
    } else if (q.contains('low') || q.contains('refill') || q.contains('stock')) {
      final lowMeds = meds.where((m) => m.isLowStock).toList();
      if (lowMeds.isNotEmpty) {
        response =
            'Alert: You have ${lowMeds.length} prescription running low! ${lowMeds.first.name} has only ${lowMeds.first.remainingQuantity} doses remaining. You can request a refill on the Meds tab.';
      } else {
        response = 'Good news! All ${meds.length} medications in your inventory are well-stocked above their alert thresholds.';
      }
    } else if (q.contains('morning') || q.contains('taken') || q.contains('did i take')) {
      final taken = timeline.where((t) => t.isTaken).toList();
      if (taken.isNotEmpty) {
        final names = taken.map((t) => t.medicine.name).join(', ');
        response = 'Yes! You have recorded ${taken.length} dose(s) today: $names.';
      } else {
        response = 'No doses have been marked as taken yet today. Check your timeline on the Today tab to record your doses.';
      }
    } else if (q.contains('interaction') || q.contains('safe') || q.contains('combine')) {
      final names = meds.map((m) => m.name).join(', ');
      response =
              'Your recorded medicines are: $names. This app can show limited local interaction warnings, but a pharmacist or prescriber must verify any new medicine or combination.';
    } else {
      response =
          'I am here to help you stay healthy! You can ask "What is my next dose?", "Which pills are running low?", or "What did I take today?".';
    }

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _messages.add({'isUser': false, 'text': response});
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = [
      'What medicines do I take today?',
      'Which pills are running low?',
      'Did I take my morning dose?',
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.secondaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.smart_toy_rounded, color: AppColors.onSecondaryContainer, size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              'DoseCare Assistant',
              style: AppTypography.headlineSm(color: AppColors.primary),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (ctx, i) {
                final msg = _messages[i];
                final isUser = msg['isUser'] as bool;

                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                    decoration: BoxDecoration(
                      color: isUser ? AppColors.primary : AppColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isUser ? 16 : 4),
                        bottomRight: Radius.circular(isUser ? 4 : 16),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      msg['text'] as String,
                      style: AppTypography.bodyMd(
                        color: isUser ? Colors.white : AppColors.onSurface,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: suggestions.map((s) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    label: Text(s),
                    backgroundColor: AppColors.surfaceContainerLow,
                    labelStyle: AppTypography.labelSm(color: AppColors.primary),
                    onPressed: () => _sendMessage(s),
                  ),
                );
              }).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    onSubmitted: _sendMessage,
                    decoration: const InputDecoration(
                      hintText: 'Ask about your medicines...',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: AppColors.primary),
                  icon: const Icon(Icons.send_rounded, color: Colors.white),
                  onPressed: () => _sendMessage(_messageController.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
