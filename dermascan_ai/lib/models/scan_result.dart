/// Model for scan prediction results from the FastAPI backend
class ScanResult {
  final String id;
  final String userId;
  final String disease;
  final String fullName;
  final String severity;
  final double confidence;
  final Map<String, double> allScores;
  final String? imageUrl;
  final String? imagePath;
  final String? warning;
  final String? notes;
  final DateTime timestamp;

  ScanResult({
    required this.id,
    required this.userId,
    required this.disease,
    required this.fullName,
    required this.severity,
    required this.confidence,
    required this.allScores,
    this.imageUrl,
    this.imagePath,
    this.warning,
    this.notes,
    required this.timestamp,
  });

  /// Create from FastAPI /predict response
  factory ScanResult.fromPrediction(Map<String, dynamic> json, String userId) {
    final prediction = json['prediction'] as Map<String, dynamic>;
    final allScoresRaw = prediction['all_scores'] as Map<String, dynamic>;
    final allScores = allScoresRaw.map(
      (key, value) => MapEntry(key, (value as num).toDouble()),
    );

    final disease = prediction['predicted_class'] as String;
    final confidence = (prediction['confidence'] as num).toDouble();

    String? warning;
    if (disease == 'MEL') {
      warning = 'URGENT: Melanoma detected. See a dermatologist immediately.';
    } else if (confidence < 0.7) {
      warning = 'Low confidence result. Consider retaking the photo.';
    }

    return ScanResult(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: userId,
      disease: disease,
      fullName: prediction['disease_name'] as String,
      severity: prediction['severity'] as String,
      confidence: confidence,
      allScores: allScores,
      warning: warning,
      timestamp: DateTime.now(),
    );
  }

  /// Create from Firestore document
  factory ScanResult.fromFirestore(Map<String, dynamic> json, String docId) {
    final allScoresRaw = json['allScores'] as Map<String, dynamic>? ?? {};
    final allScores = allScoresRaw.map(
      (key, value) => MapEntry(key, (value as num).toDouble()),
    );

    return ScanResult(
      id: docId,
      userId: json['userId'] as String? ?? '',
      disease: json['disease'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      severity: json['severity'] as String? ?? 'low',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      allScores: allScores,
      imageUrl: json['imageUrl'] as String?,
      imagePath: json['imagePath'] as String?,
      warning: json['warning'] as String?,
      notes: json['notes'] as String?,
      timestamp: json['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int)
          : DateTime.now(),
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'disease': disease,
      'fullName': fullName,
      'severity': severity,
      'confidence': confidence,
      'allScores': allScores,
      'imageUrl': imageUrl,
      'imagePath': imagePath,
      'warning': warning,
      'notes': notes,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  /// Whether this result needs urgent medical attention
  bool get isUrgent => severity == 'critical' || severity == 'high';

  /// Whether confidence is low
  bool get isLowConfidence => confidence < 0.7;

  /// Sorted scores (highest first)
  List<MapEntry<String, double>> get sortedScores {
    final entries = allScores.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }
}
