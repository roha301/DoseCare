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
  /// Maps common brand names to the generic ingredient the interaction rules
  /// are written against, so a prescription entered as "Ecosprin" still
  /// matches a rule keyed on "aspirin".
  static const Map<String, String> _brandAliases = {
    'ecosprin': 'aspirin',
    'disprin': 'aspirin',
    'ecotrin': 'aspirin',
    'loprin': 'aspirin',
    'crocin': 'paracetamol',
    'dolo': 'paracetamol',
    'calpol': 'paracetamol',
    'tylenol': 'paracetamol',
    'panadol': 'paracetamol',
    'glycomet': 'metformin',
    'glucophage': 'metformin',
    'coumadin': 'warfarin',
    'jantoven': 'warfarin',
    'lipitor': 'atorvastatin',
    'zocor': 'simvastatin',
    'biaxin': 'clarithromycin',
    'prilosec': 'omeprazole',
    'omez': 'omeprazole',
    'plavix': 'clopidogrel',
    'zestril': 'lisinopril',
    'prinivil': 'lisinopril',
    'aldactone': 'spironolactone',
    'viagra': 'sildenafil',
    'revatio': 'sildenafil',
    'eltroxin': 'levothyroxine',
    'synthroid': 'levothyroxine',
    'thyronorm': 'levothyroxine',
    'lanoxin': 'digoxin',
    'ultram': 'tramadol',
    'flagyl': 'metronidazole',
    'brufen': 'ibuprofen',
    'advil': 'ibuprofen',
    'motrin': 'ibuprofen',
    'naprosyn': 'naproxen',
    'aleve': 'naproxen',
    'zoloft': 'sertraline',
    'prozac': 'fluoxetine',
    'lasix': 'furosemide',
    'nitrostat': 'nitroglycerin',
    'eskalith': 'lithium',
    'lithobid': 'lithium',
    'hydrodiuril': 'hydrochlorothiazide',
    'moduretic': 'amiloride',
    'inderal': 'propranolol',
    'humalog': 'insulin',
    'lantus': 'insulin',
    'novolog': 'insulin',
  };

  static final List<Map<String, dynamic>> _interactionRules = [
    {
      'drugs': ['lisinopril', 'spironolactone'],
      'severity': 'High',
      'description': 'Concurrent use of ACE inhibitors and potassium-sparing diuretics significantly elevates blood potassium.',
      'advice': 'Risk of hyperkalemia. Frequent serum potassium monitoring is recommended.',
    },
    {
      'drugs': ['lisinopril', 'amiloride'],
      'severity': 'High',
      'description': 'Combining an ACE inhibitor with another potassium-sparing diuretic compounds hyperkalemia risk.',
      'advice': 'Avoid combination unless closely monitored by a physician with regular potassium checks.',
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
      'drugs': ['simvastatin', 'clarithromycin'],
      'severity': 'High',
      'description': 'Clarithromycin strongly inhibits the enzyme that clears simvastatin, raising serum levels sharply.',
      'advice': 'High risk of rhabdomyolysis. Simvastatin should generally be withheld during the antibiotic course.',
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
    {
      'drugs': ['warfarin', 'ibuprofen'],
      'severity': 'High',
      'description': 'NSAIDs impair platelet function and irritate the GI lining on top of Warfarin\'s anticoagulant effect.',
      'advice': 'Significant bleeding risk. Prefer paracetamol for pain relief while on Warfarin.',
    },
    {
      'drugs': ['warfarin', 'naproxen'],
      'severity': 'High',
      'description': 'Naproxen combined with Warfarin substantially raises the risk of gastrointestinal bleeding.',
      'advice': 'Avoid concurrent use; discuss alternative analgesics with the prescriber.',
    },
    {
      'drugs': ['warfarin', 'amoxicillin'],
      'severity': 'Moderate',
      'description': 'Antibiotics can disrupt gut flora that produce vitamin K, potentiating Warfarin and raising INR.',
      'advice': 'More frequent INR monitoring is recommended during and after the antibiotic course.',
    },
    {
      'drugs': ['sertraline', 'ibuprofen'],
      'severity': 'Moderate',
      'description': 'SSRIs impair platelet aggregation; combined with an NSAID this raises GI bleeding risk.',
      'advice': 'Use the lowest effective NSAID dose for the shortest time, or prefer paracetamol.',
    },
    {
      'drugs': ['fluoxetine', 'ibuprofen'],
      'severity': 'Moderate',
      'description': 'SSRIs impair platelet aggregation; combined with an NSAID this raises GI bleeding risk.',
      'advice': 'Use the lowest effective NSAID dose for the shortest time, or prefer paracetamol.',
    },
    {
      'drugs': ['digoxin', 'furosemide'],
      'severity': 'High',
      'description': 'Loop diuretics can deplete potassium and magnesium, increasing the risk of Digoxin-induced arrhythmia.',
      'advice': 'Monitor electrolytes and Digoxin levels closely; consider a potassium-sparing agent.',
    },
    {
      'drugs': ['digoxin', 'hydrochlorothiazide'],
      'severity': 'High',
      'description': 'Thiazide diuretics can deplete potassium, increasing the risk of Digoxin-induced arrhythmia.',
      'advice': 'Monitor electrolytes and Digoxin levels closely.',
    },
    {
      'drugs': ['levothyroxine', 'calcium'],
      'severity': 'Moderate',
      'description': 'Calcium supplements bind Levothyroxine in the gut and reduce its absorption.',
      'advice': 'Separate dosing by at least 4 hours.',
    },
    {
      'drugs': ['levothyroxine', 'iron'],
      'severity': 'Moderate',
      'description': 'Iron supplements bind Levothyroxine in the gut and reduce its absorption.',
      'advice': 'Separate dosing by at least 4 hours.',
    },
    {
      'drugs': ['sertraline', 'phenelzine'],
      'severity': 'High',
      'description': 'Combining an SSRI with an MAOI can precipitate life-threatening serotonin syndrome.',
      'advice': 'This combination is generally contraindicated; a washout period is required when switching agents.',
    },
    {
      'drugs': ['fluoxetine', 'phenelzine'],
      'severity': 'High',
      'description': 'Combining an SSRI with an MAOI can precipitate life-threatening serotonin syndrome.',
      'advice': 'This combination is generally contraindicated; a washout period is required when switching agents.',
    },
    {
      'drugs': ['sildenafil', 'nitroglycerin'],
      'severity': 'High',
      'description': 'Both drugs lower blood pressure through nitric-oxide pathways; combined use can cause severe, life-threatening hypotension.',
      'advice': 'Never combine. Seek emergency care if nitrate use is required after recent sildenafil use.',
    },
    {
      'drugs': ['lithium', 'ibuprofen'],
      'severity': 'Moderate',
      'description': 'NSAIDs reduce renal clearance of Lithium, which can raise Lithium levels to toxic range.',
      'advice': 'Monitor Lithium levels if an NSAID must be used; prefer paracetamol where possible.',
    },
    {
      'drugs': ['lithium', 'hydrochlorothiazide'],
      'severity': 'Moderate',
      'description': 'Thiazide diuretics reduce Lithium excretion, which can raise Lithium levels to toxic range.',
      'advice': 'Requires closer Lithium level monitoring after starting or adjusting the diuretic.',
    },
    {
      'drugs': ['tramadol', 'sertraline'],
      'severity': 'High',
      'description': 'Tramadol has serotonergic activity; combined with an SSRI it raises the risk of serotonin syndrome.',
      'advice': 'Use with caution and watch for agitation, tremor, or fever; discuss alternatives with the prescriber.',
    },
    {
      'drugs': ['tramadol', 'fluoxetine'],
      'severity': 'High',
      'description': 'Tramadol has serotonergic activity; combined with an SSRI it raises the risk of serotonin syndrome.',
      'advice': 'Use with caution and watch for agitation, tremor, or fever; discuss alternatives with the prescriber.',
    },
    {
      'drugs': ['metronidazole', 'alcohol'],
      'severity': 'High',
      'description': 'Metronidazole can cause a disulfiram-like reaction with alcohol: flushing, nausea, and palpitations.',
      'advice': 'Avoid all alcohol during treatment and for at least 48 hours after the last dose.',
    },
    {
      'drugs': ['insulin', 'propranolol'],
      'severity': 'Moderate',
      'description': 'Non-selective beta-blockers can mask the warning signs of hypoglycemia (tremor, palpitations).',
      'advice': 'Monitor blood glucose more closely; be alert for sweating as the remaining hypoglycemia cue.',
    },
  ];

  /// Normalizes free-text medicine names for matching: lowercases, strips
  /// dosage-form/strength noise, and resolves known brand names to the
  /// generic ingredient the rules above are keyed on.
  static String _normalize(String input) {
    var s = input.trim().toLowerCase();
    s = s.replaceAll(RegExp(r'\d+(\.\d+)?\s*(mg|mcg|g|ml|iu)\b'), ' ');
    s = s.replaceAll(
      RegExp(r'\b(tablet|tablets|tab|tabs|capsule|capsules|cap|caps|syrup|injection|inj|drops|cream|ointment)\b'),
      ' ',
    );
    s = s.replaceAll(RegExp(r'[^a-z\s]'), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (s.isEmpty) return s;
    final words = s.split(' ').map((w) => _brandAliases[w] ?? w);
    return words.join(' ');
  }

  static bool _containsDrug(String normalizedName, String drug) {
    if (normalizedName.isEmpty) return false;
    return RegExp(r'\b' + RegExp.escape(drug) + r'\b').hasMatch(normalizedName);
  }

  /// Checks if [newMedicineName] interacts with any medicine in [currentMedicineNames]
  static List<InteractionResult> checkInteractions(
    String newMedicineName,
    List<String> currentMedicineNames,
  ) {
    final List<InteractionResult> found = [];
    final targetNorm = _normalize(newMedicineName);

    for (final existing in currentMedicineNames) {
      final currentNorm = _normalize(existing);
      if (targetNorm.isNotEmpty && targetNorm == currentNorm) continue;

      for (final rule in _interactionRules) {
        final List<String> pair = List<String>.from(rule['drugs']);
        final drug1 = pair[0];
        final drug2 = pair[1];

        final match1 = _containsDrug(targetNorm, drug1) && _containsDrug(currentNorm, drug2);
        final match2 = _containsDrug(targetNorm, drug2) && _containsDrug(currentNorm, drug1);

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
