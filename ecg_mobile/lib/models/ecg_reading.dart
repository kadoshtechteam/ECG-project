class ECGReading {
  final int? id;
  final int userId;
  final DateTime timestamp;
  final List<double> ecgData;
  final int duration; // Duration in seconds
  final double? heartRate;
  final String? notes;

  ECGReading({
    this.id,
    required this.userId,
    required this.timestamp,
    required this.ecgData,
    required this.duration,
    this.heartRate,
    this.notes,
  });

  // Convert ECGReading object to Map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'ecg_data': ecgData.join(','), // Store as comma-separated string
      'duration': duration,
      'heart_rate': heartRate,
      'notes': notes,
    };
  }

  // Create ECGReading object from Map (database retrieval)
  factory ECGReading.fromMap(Map<String, dynamic> map) {
    return ECGReading(
      id: map['id'],
      userId: map['user_id'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
      ecgData: (map['ecg_data'] as String)
          .split(',')
          .map((e) => double.tryParse(e.trim()) ?? 0.0)
          .toList(),
      duration: map['duration'],
      heartRate: map['heart_rate']?.toDouble(),
      notes: map['notes'],
    );
  }

  // Create a copy of ECGReading with updated fields
  ECGReading copyWith({
    int? id,
    int? userId,
    DateTime? timestamp,
    List<double>? ecgData,
    int? duration,
    double? heartRate,
    String? notes,
  }) {
    return ECGReading(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      timestamp: timestamp ?? this.timestamp,
      ecgData: ecgData ?? this.ecgData,
      duration: duration ?? this.duration,
      heartRate: heartRate ?? this.heartRate,
      notes: notes ?? this.notes,
    );
  }

  // Calculate basic statistics
  double get minValue => ecgData.reduce((a, b) => a < b ? a : b);
  double get maxValue => ecgData.reduce((a, b) => a > b ? a : b);
  double get averageValue => ecgData.reduce((a, b) => a + b) / ecgData.length;

  // Get sampling rate (assuming standard ECG sampling)
  double get samplingRate => ecgData.length / duration;

  @override
  String toString() {
    return 'ECGReading{id: $id, userId: $userId, timestamp: $timestamp, '
        'dataPoints: ${ecgData.length}, duration: ${duration}s, '
        'heartRate: $heartRate}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ECGReading &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          userId == other.userId &&
          timestamp == other.timestamp;

  @override
  int get hashCode => id.hashCode ^ userId.hashCode ^ timestamp.hashCode;
}
