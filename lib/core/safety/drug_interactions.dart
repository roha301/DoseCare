class InteractionResult {
  final String medicineA;
  final String medicineB;
  final String severity; // High, Moderate, Low
  final String description;
  final String clinicalAdvice;

  InteractionResult({
    required this.medicineA,
    required this.medicineB,
    required this.severity,
    required this.description,
    required this.clinicalAdvice,
  });
}

class DrugSafetyEngine {
  static final List<Map<String, dynamic>> _interactionRules = [
    {
      'drugs': ['lisinopril', 'spironolactone'],
      'severity': 'High',
      'description': 'Concurrent use of ACE inhibitors and potassium-sparing diuretics significantly elevates blood potassium.',
      'advice': 'Risk of hyperkalemia. Frequent serum potassium monitoring is recommended.',
    },
    {
      'drugs': ['lisinopril', 'potassium'],
      'severity': 'High',
      'description': 'Combining Lisinopril with potassium supplements may cause severe hyperkalemia.',
      'advice': 'Consult physician before taking potassium supplements while on ACE inhibitors.',
    },
    {
      'drugs': ['aspirin', 'warfarin'],
      'severity': 'High',
      'description': 'Dual antiplatelet and anticoagulant effect dramatically increases internal bleeding risks.',
      'advice': 'Risk of hemorrhage. Strictly consult prescribing hematologist/cardiologist.',
    },
    {
      'drugs': ['aspirin', 'ibuprofen'],
      'severity': 'Moderate',
      'description': 'Ibuprofen may inhibit the cardioprotective antiplatelet effect of low-dose aspirin.',
      'advice': 'Take aspirin at least 30 minutes before or 8 hours after ibuprofen.',
    },
    {
      'drugs': ['atorvastatin', 'clarithromycin'],
      'severity': 'High',
      'description': 'Clarithromycin significantly increases Atorvastatin serum concentration.',
      'advice': 'Elevated risk of severe myopathy or rhabdomyolysis. Dose reduction or statin pause indicated.',
    },
    {
      'drugs': ['metformin', 'alcohol'],
      'severity': 'Moderate',
      'description': 'Excessive alcohol intake potentiates Metformin effect on lactate metabolism.',
      'advice': 'Avoid binge drinking or chronic excessive alcohol while on Metformin to prevent lactic acidosis.',
    },
    {
      'drugs': ['amoxicillin', 'methotrexate'],
      'severity': 'Moderate',
      'description': 'Penicillins may reduce the renal excretion of Methotrexate.',
      'advice': 'Monitor for signs of Methotrexate toxicity (leukopenia, oral ulcers).',
    },
    {
      'drugs': ['omeprazole', 'clopidogrel'],
      'severity': 'Moderate',
      'description': 'Omeprazole reduces the active metabolite conversion of Clopidogrel.',
      'advice': 'Potential reduction in antiplatelet efficacy. Consider Pantoprazole or H2-blocker alternative.',
    },
  ];

  /// Checks if [newMedicineName] interacts with any medicine in [currentMedicineNames]
  static List<InteractionResult> checkInteractions(
    String newMedicineName,
    List<String> currentMedicineNames,
  ) {
    final List<InteractionResult> found = [];
    final target = newMedicineName.trim().toLowerCase();

    for (final existing in currentMedicineNames) {
      final current = existing.trim().toLowerCase();
      if (target == current) continue;

      for (final rule in _interactionRules) {
        final List<String> pair = List<String>.from(rule['drugs']);
        final drug1 = pair[0].toLowerCase();
        final drug2 = pair[1].toLowerCase();

        final match1 = (target.contains(drug1) && current.contains(drug2));
        final match2 = (target.contains(drug2) && current.contains(drug1));

        if (match1 || match2) {
          found.add(
            InteractionResult(
              medicineA: newMedicineName,
              medicineB: existing,
              severity: rule['severity'] as String,
              description: rule['description'] as String,
              clinicalAdvice: rule['advice'] as String,
            ),
          );
        }
      }
    }

    return found;
  }
}
