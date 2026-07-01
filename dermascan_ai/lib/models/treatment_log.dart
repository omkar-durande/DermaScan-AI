/// Treatment log entry for tracking skin condition progress
class TreatmentLog {
  final String id;
  final String userId;
  final String disease;
  final DateTime date;
  final String treatment;
  final String? notes;
  final String improvement; // 'worse', 'same', 'better'
  final String? photoUrl;
  final String? photoPath;

  TreatmentLog({
    required this.id,
    required this.userId,
    required this.disease,
    required this.date,
    required this.treatment,
    this.notes,
    required this.improvement,
    this.photoUrl,
    this.photoPath,
  });

  factory TreatmentLog.fromFirestore(Map<String, dynamic> json, String docId) {
    return TreatmentLog(
      id: docId,
      userId: json['userId'] as String? ?? '',
      disease: json['disease'] as String? ?? '',
      date: json['date'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['date'] as int)
          : DateTime.now(),
      treatment: json['treatment'] as String? ?? '',
      notes: json['notes'] as String?,
      improvement: json['improvement'] as String? ?? 'same',
      photoUrl: json['photoUrl'] as String?,
      photoPath: json['photoPath'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'disease': disease,
      'date': date.millisecondsSinceEpoch,
      'treatment': treatment,
      'notes': notes,
      'improvement': improvement,
      'photoUrl': photoUrl,
      'photoPath': photoPath,
    };
  }

  /// Get improvement emoji
  String get improvementEmoji {
    switch (improvement) {
      case 'worse':
        return '📉';
      case 'same':
        return '➡️';
      case 'better':
        return '📈';
      default:
        return '➡️';
    }
  }
}
