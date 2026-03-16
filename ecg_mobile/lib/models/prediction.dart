enum PredictionResult { normal, arrhythmia, tachycardia, bradycardia, unknown }

class Prediction {
  final int? id;
  final int readingId;
  final PredictionResult predictionResult;
  final double confidence;
  final DateTime createdAt;
  final Map<String, double>? detailedResults; // For storing probability scores

  Prediction({
    this.id,
    required this.readingId,
    required this.predictionResult,
    required this.confidence,
    required this.createdAt,
    this.detailedResults,
  });

  // Convert Prediction object to Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'reading_id': readingId,
      'prediction_result': predictionResult.name,
      'confidence': confidence,
      'created_at': createdAt.millisecondsSinceEpoch,
      'detailed_results': detailedResults != null
          ? _mapToString(detailedResults!)
          : null,
    };
  }

  // Create Prediction object from Map (database retrieval)
  factory Prediction.fromMap(Map<String, dynamic> map) {
    return Prediction(
      id: map['id'],
      readingId: map['reading_id'],
      predictionResult: PredictionResult.values.firstWhere(
        (e) => e.name == map['prediction_result'],
        orElse: () => PredictionResult.unknown,
      ),
      confidence: map['confidence'].toDouble(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
      detailedResults: map['detailed_results'] != null
          ? _stringToMap(map['detailed_results'])
          : null,
    );
  }

  // Helper method to convert Map to String for storage
  static String _mapToString(Map<String, double> map) {
    return map.entries.map((e) => '${e.key}:${e.value}').join(',');
  }

  // Helper method to convert String back to Map
  static Map<String, double> _stringToMap(String str) {
    Map<String, double> result = {};
    for (String pair in str.split(',')) {
      List<String> parts = pair.split(':');
      if (parts.length == 2) {
        result[parts[0]] = double.tryParse(parts[1]) ?? 0.0;
      }
    }
    return result;
  }

  // Create a copy of Prediction with updated fields
  Prediction copyWith({
    int? id,
    int? readingId,
    PredictionResult? predictionResult,
    double? confidence,
    DateTime? createdAt,
    Map<String, double>? detailedResults,
  }) {
    return Prediction(
      id: id ?? this.id,
      readingId: readingId ?? this.readingId,
      predictionResult: predictionResult ?? this.predictionResult,
      confidence: confidence ?? this.confidence,
      createdAt: createdAt ?? this.createdAt,
      detailedResults: detailedResults ?? this.detailedResults,
    );
  }

  // Get risk level based on prediction and confidence
  String get riskLevel {
    if (predictionResult == PredictionResult.normal && confidence > 0.8) {
      return 'Low Risk';
    } else if (confidence > 0.7) {
      return predictionResult == PredictionResult.normal
          ? 'Low Risk'
          : 'High Risk';
    } else {
      return 'Uncertain';
    }
  }

  // Get user-friendly description
  String get description {
    switch (predictionResult) {
      case PredictionResult.normal:
        return 'Normal heart rhythm detected';
      case PredictionResult.arrhythmia:
        return 'Irregular heart rhythm detected';
      case PredictionResult.tachycardia:
        return 'Fast heart rate detected';
      case PredictionResult.bradycardia:
        return 'Slow heart rate detected';
      case PredictionResult.unknown:
        return 'Unable to determine heart condition';
    }
  }

  @override
  String toString() {
    return 'Prediction{id: $id, readingId: $readingId, '
        'result: $predictionResult, confidence: ${(confidence * 100).toStringAsFixed(1)}%, '
        'createdAt: $createdAt}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Prediction &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          readingId == other.readingId;

  @override
  int get hashCode => id.hashCode ^ readingId.hashCode;
}
