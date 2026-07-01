/// DermaScan AI — Hardcoded Disease Information
class DiseaseData {
  DiseaseData._();

  static const Map<String, Map<String, dynamic>> diseases = {
    'NEV': {
      'full_name': 'Melanocytic Nevi (Mole)',
      'description':
          'A common benign growth of pigment-producing cells (melanocytes). '
              'Most moles are harmless and rarely become cancerous.',
      'symptoms': [
        'Round or oval shape',
        'Even colour throughout',
        'Well-defined border',
        'Usually smaller than 6mm',
      ],
      'remedies': [
        {
          'name': 'Aloe Vera Gel',
          'ingredients': ['Fresh aloe vera leaf or pure aloe gel'],
          'application': 'Apply fresh aloe vera gel directly to the mole area.',
          'frequency': 'Twice daily for 2-3 weeks',
        },
        {
          'name': 'Moisturizing Care',
          'ingredients': ['Gentle, fragrance-free moisturizer'],
          'application': 'Keep the area well moisturized to prevent irritation.',
          'frequency': 'Daily after bathing',
        },
        {
          'name': 'Sun Protection',
          'ingredients': ['SPF 30+ broad-spectrum sunscreen'],
          'application':
              'Apply sunscreen generously to prevent changes in the mole.',
          'frequency': 'Every 2 hours when outdoors',
        },
      ],
      'urgency': 'low',
      'icon': '🟢',
    },
    'BCC': {
      'full_name': 'Basal Cell Carcinoma',
      'description':
          'The most common type of skin cancer. It rarely spreads to other '
              'parts of the body but needs medical treatment. It typically '
              'develops in sun-exposed areas.',
      'symptoms': [
        'Pearly or waxy bump',
        'Flat, flesh-colored or brown scar-like lesion',
        'Bleeding or scabbing sore that heals and returns',
        'May have visible blood vessels',
      ],
      'remedies': [
        {
          'name': 'Strict Sun Avoidance',
          'ingredients': ['SPF 50+ sunscreen', 'Wide-brimmed hat'],
          'application':
              'Avoid direct sun exposure. Use SPF 50+ sunscreen on all exposed skin.',
          'frequency': 'Daily, reapply every 2 hours',
        },
        {
          'name': 'Protective Clothing',
          'ingredients': ['UPF-rated clothing', 'UV-blocking sunglasses'],
          'application': 'Wear long sleeves and UV-protective clothing outdoors.',
          'frequency': 'Whenever outdoors',
        },
      ],
      'urgency': 'high',
      'icon': '🟠',
    },
    'ACK': {
      'full_name': 'Actinic Keratosis',
      'description':
          'A rough, scaly patch on the skin caused by years of sun exposure. '
              'Considered pre-cancerous — can progress to squamous cell carcinoma '
              'if left untreated.',
      'symptoms': [
        'Rough, dry, scaly skin patch',
        'Flat to slightly raised patch',
        'Itching or burning sensation',
        'Usually on sun-exposed areas (face, ears, hands)',
      ],
      'remedies': [
        {
          'name': 'Daily Moisturizer',
          'ingredients': ['Rich emollient cream with ceramides'],
          'application':
              'Apply thick moisturizer to soften the rough patches.',
          'frequency': 'Twice daily',
        },
        {
          'name': 'Strict Sun Protection',
          'ingredients': ['SPF 50+ sunscreen', 'Protective clothing'],
          'application': 'Complete sun avoidance during peak hours (10am-4pm).',
          'frequency': 'Daily',
        },
        {
          'name': 'Green Tea Compress',
          'ingredients': ['Brewed green tea (cooled)'],
          'application':
              'Soak a cloth in cooled green tea and apply as a compress.',
          'frequency': '2-3 times daily for 15 minutes',
        },
      ],
      'urgency': 'medium',
      'icon': '🟡',
    },
    'SEK': {
      'full_name': 'Seborrheic Keratosis',
      'description':
          'A common, harmless benign skin growth that appears waxy or '
              'wart-like. Not caused by sun exposure and does not become cancerous.',
      'symptoms': [
        'Waxy, stuck-on appearance',
        'Round or oval shape',
        'Tan, brown, or black color',
        'Slightly elevated from skin surface',
      ],
      'remedies': [
        {
          'name': 'Leave Untreated',
          'ingredients': [],
          'application':
              'If not bothersome, no treatment needed. These are harmless growths.',
          'frequency': 'N/A',
        },
        {
          'name': 'Avoid Irritation',
          'ingredients': ['Soft bandage if in friction area'],
          'application': 'Avoid picking, scratching, or rubbing the growth.',
          'frequency': 'As needed',
        },
        {
          'name': 'Gentle Cleansing',
          'ingredients': ['Mild, soap-free cleanser'],
          'application': 'Clean the area gently to prevent infection if irritated.',
          'frequency': 'Daily',
        },
      ],
      'urgency': 'low',
      'icon': '🟢',
    },
    'SCC': {
      'full_name': 'Squamous Cell Carcinoma',
      'description':
          'The second most common form of skin cancer. Can spread to other '
              'parts of the body if not treated early. Usually caused by '
              'cumulative UV exposure.',
      'symptoms': [
        'Firm, red nodule',
        'Flat lesion with scaly, crusted surface',
        'Sore that heals and then reopens',
        'New sore or raised area on existing scar',
      ],
      'remedies': [
        {
          'name': 'Immediate Medical Consultation',
          'ingredients': [],
          'application':
              'IMPORTANT: See a dermatologist as soon as possible for proper diagnosis and treatment.',
          'frequency': 'Urgent — schedule within days',
        },
        {
          'name': 'Critical Sun Protection',
          'ingredients': ['SPF 50+ sunscreen', 'Full coverage clothing'],
          'application': 'Complete sun protection is critical to prevent worsening.',
          'frequency': 'Always when outdoors',
        },
      ],
      'urgency': 'high',
      'icon': '🟠',
    },
    'MEL': {
      'full_name': 'Melanoma',
      'description':
          'The most dangerous form of skin cancer. Develops in melanocytes '
              '(pigment-producing cells). Early detection and treatment is '
              'absolutely critical for survival.',
      'symptoms': [
        'Asymmetric shape (ABCDE rule: A)',
        'Irregular, ragged border (B)',
        'Multiple colours in one lesion (C)',
        'Diameter larger than 6mm (D)',
        'Evolving size, shape, or color (E)',
      ],
      'remedies': [
        {
          'name': '🚨 URGENT: See a Dermatologist Immediately',
          'ingredients': [],
          'application':
              'Do NOT delay. Melanoma requires immediate professional medical evaluation. '
              'Early treatment dramatically improves outcomes.',
          'frequency': 'IMMEDIATELY — within 24-48 hours',
        },
        {
          'name': 'Document Changes',
          'ingredients': ['Camera/phone for photos'],
          'application':
              'Take clear photos of the lesion with a ruler for scale to show your doctor.',
          'frequency': 'Before your appointment',
        },
      ],
      'urgency': 'critical',
      'icon': '🔴',
    },
  };

  /// Get disease info by code
  static Map<String, dynamic>? getDisease(String code) {
    return diseases[code.toUpperCase()];
  }

  /// Get full name by code
  static String getFullName(String code) {
    return diseases[code.toUpperCase()]?['full_name'] ?? code;
  }

  /// Get urgency by code
  static String getUrgency(String code) {
    return diseases[code.toUpperCase()]?['urgency'] ?? 'low';
  }

  /// Get all disease codes
  static List<String> get allCodes => diseases.keys.toList();
}
