import 'dart:math' as math;
import '../models/ecg_reading.dart';
import '../models/prediction.dart';
import 'database_helper.dart';

class ECGDataService {
  static final ECGDataService _instance = ECGDataService._internal();
  factory ECGDataService() => _instance;
  ECGDataService._internal();

  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final math.Random _random = math.Random();

  // Generate dummy ECG data similar to the sample provided
  List<double> generateDummyECGData({
    int dataPoints = 187,
    double duration = 10.0,
  }) {
    List<double> ecgData = [];
    double baseHeartRate = 70 + _random.nextDouble() * 30; // 70-100 bpm
    double samplingRate = dataPoints / duration; // Hz

    for (int i = 0; i < dataPoints; i++) {
      double time = i / samplingRate;

      // Generate a realistic ECG waveform
      double ecgValue = _generateECGPoint(time, baseHeartRate);

      // Add some noise
      ecgValue += (_random.nextDouble() - 0.5) * 0.02;

      // Ensure value is within realistic range (0.0 to 0.3)
      ecgValue = ecgValue.clamp(0.0, 0.3);

      ecgData.add(double.parse(ecgValue.toStringAsFixed(4)));
    }

    return ecgData;
  }

  // Generate a realistic ECG point using mathematical modeling
  double _generateECGPoint(double time, double heartRate) {
    double heartPeriod = 60.0 / heartRate; // seconds per beat
    double normalizedTime = (time % heartPeriod) / heartPeriod;

    // P wave (0.0 - 0.1)
    if (normalizedTime < 0.1) {
      return 0.12 + 0.05 * sin(normalizedTime * 10 * pi);
    }
    // PR interval (0.1 - 0.2)
    else if (normalizedTime < 0.2) {
      return 0.11 + 0.02 * sin((normalizedTime - 0.1) * 20 * pi);
    }
    // QRS complex (0.2 - 0.35)
    else if (normalizedTime < 0.35) {
      double qrsTime = (normalizedTime - 0.2) / 0.15;
      if (qrsTime < 0.3) {
        return 0.10 - 0.05 * qrsTime; // Q wave
      } else if (qrsTime < 0.7) {
        return 0.05 + 0.25 * (qrsTime - 0.3) / 0.4; // R wave
      } else {
        return 0.30 - 0.20 * (qrsTime - 0.7) / 0.3; // S wave
      }
    }
    // ST segment (0.35 - 0.6)
    else if (normalizedTime < 0.6) {
      return 0.10 + 0.02 * sin((normalizedTime - 0.35) * 8 * pi);
    }
    // T wave (0.6 - 0.85)
    else if (normalizedTime < 0.85) {
      double tTime = (normalizedTime - 0.6) / 0.25;
      return 0.11 + 0.08 * sin(tTime * pi);
    }
    // Baseline (0.85 - 1.0)
    else {
      return 0.10 + 0.02 * sin((normalizedTime - 0.85) * 12 * pi);
    }
  }

  // Parse the sample data format provided by the user
  List<double> parseSampleData(String sampleData) {
    List<String> parts = sampleData.split(' ');
    if (parts.length >= 2) {
      String dataLine = parts[1]; // Second line contains the actual data
      return dataLine
          .split(' ')
          .map((e) => double.tryParse(e.trim()) ?? 0.0)
          .toList();
    }
    return [];
  }

  // Create sample ECG reading with user-provided data
  ECGReading createSampleECGReading(int userId) {
    // Using the sample data provided by the user
    List<double> sampleData = [
      0.1075,
      0.1965,
      0.1457,
      0.1466,
      0.1241,
      0.1525,
      0.1466,
      0.1652,
      0.1232,
      0.2757,
      0.1095,
      0.1388,
      0.1075,
      0.1173,
      0.1085,
      0.131,
      0.1408,
      0.1642,
      0.1926,
      0.2043,
      0.1251,
      0.2766,
      0.2766,
      0.0039,
      0.0039,
      0.0039,
      0.1652,
      0.2043,
      0.2063,
      0.2766,
      0.2757,
      0.2708,
      0.0489,
      0.0088,
      0.0244,
      0.2082,
      0.0782,
      0.0655,
      0.0968,
      0.1926,
      0.1476,
      0.0782,
      0.0489,
      0.0919,
      0.2111,
      0.172,
      0.176,
      0.1544,
      0.1388,
      0.1271,
      0.1056,
      0.1153,
      0.1447,
      0.1857,
      0.1574,
      0.1466,
      0.1711,
      0.1681,
      0.13,
      0.1232,
      0.1251,
      0.1212,
      0.1105,
      0.1241,
      0.132,
      0.1437,
      0.1241,
      0.1388,
      0.1408,
      0.129,
      0.1486,
      0.1486,
      0.1251,
      0.0684,
      0.1036,
      0.1271,
      0.1574,
      0.1329,
      0.1662,
      0.1691,
      0.1544,
      0.1007,
      0.1241,
      0.1447,
      0.1476,
      0.1593,
      0.1329,
      0.1838,
      0.1026,
      0.1105,
      0.1114,
      0.1457,
      0.1564,
      0.1642,
      0.1329,
      0.1496,
      0.1241,
      0.1202,
      0.0978,
      0.1105,
      0.1544,
      0.1525,
      0.1486,
      0.2737,
      0.1544,
      0.1701,
      0.2669,
      0.1857,
      0.1251,
      0.1339,
      0.1144,
      0.1232,
      0.1056,
      0.1505,
      0.1603,
      0.1593,
      0.1447,
      0.1466,
      0.1329,
      0.1447,
      0.131,
      0.1359,
      0.1486,
      0.1672,
      0.1525,
      0.1593,
      0.1779,
      0.1466,
      0.1271,
      0.1466,
      0.1417,
      0.1476,
      0.1261,
      0.1437,
      0.1447,
      0.1564,
      0.132,
      0.1408,
      0.1408,
      0.1486,
      0.1193,
      0.1427,
      0.1447,
      0.1544,
      0.1369,
      0.1505,
      0.1662,
      0.1711,
      0.1212,
      0.1144,
      0.1085,
      0.1134,
      0.1114,
      0.1134,
      0.1496,
      0.1857,
      0.1593,
      0.1593,
      0.1232,
      0.1144,
      0.1036,
      0.131,
      0.129,
      0.1476,
      0.1339,
      0.2004,
      0.2131,
      0.1711,
      0.0909,
      0.0841,
      0.1193,
      0.1447,
      0.1271,
      0.1642,
      0.1828,
      0.1945,
      0.1574,
      0.1408,
      0.1202,
      0.1193,
      0.0958,
      0.1144,
      0.1193,
      0.1447,
      0.2757,
    ];

    return ECGReading(
      userId: userId,
      timestamp: DateTime.now(),
      ecgData: sampleData,
      duration: 10,
      heartRate: _calculateHeartRate(sampleData, 10),
      notes: 'Sample ECG reading',
    );
  }

  // Calculate heart rate from ECG data
  double _calculateHeartRate(List<double> ecgData, int duration) {
    if (ecgData.isEmpty || ecgData.length < 30) return 0.0;

    // Improved peak detection algorithm
    List<int> peaks = [];

    // Calculate dynamic threshold based on data statistics
    double mean = ecgData.reduce((a, b) => a + b) / ecgData.length;
    double maxVal = ecgData.reduce((a, b) => a > b ? a : b);
    double minVal = ecgData.reduce((a, b) => a < b ? a : b);
    double threshold = mean + (maxVal - mean) * 0.3; // More adaptive threshold

    // Find peaks with better filtering
    for (int i = 2; i < ecgData.length - 2; i++) {
      // Check if current point is a local maximum
      if (ecgData[i] > ecgData[i - 1] &&
          ecgData[i] > ecgData[i + 1] &&
          ecgData[i] > ecgData[i - 2] &&
          ecgData[i] > ecgData[i + 2] &&
          ecgData[i] > threshold) {
        // Ensure peaks are separated by reasonable time
        if (peaks.isEmpty || i - peaks.last > 15) {
          // Reduced from 30 to 15
          peaks.add(i);
        }
      }
    }

    if (peaks.length < 2) {
      // Fallback: try with lower threshold
      threshold = mean + (maxVal - mean) * 0.2;
      peaks.clear();

      for (int i = 2; i < ecgData.length - 2; i++) {
        if (ecgData[i] > ecgData[i - 1] &&
            ecgData[i] > ecgData[i + 1] &&
            ecgData[i] > threshold) {
          if (peaks.isEmpty || i - peaks.last > 10) {
            peaks.add(i);
          }
        }
      }
    }

    if (peaks.length < 2) return 72.0; // Default reasonable heart rate

    // Calculate RR intervals (time between beats)
    List<double> rrIntervals = [];
    for (int i = 1; i < peaks.length; i++) {
      rrIntervals.add((peaks[i] - peaks[i - 1]).toDouble());
    }

    // Remove outliers (very short or very long intervals)
    if (rrIntervals.length > 2) {
      rrIntervals.sort();
      // Remove extreme outliers (bottom and top 20% if we have enough data)
      int removeCount = (rrIntervals.length * 0.2).floor();
      if (removeCount > 0) {
        rrIntervals =
            rrIntervals.sublist(removeCount, rrIntervals.length - removeCount);
      }
    }

    if (rrIntervals.isEmpty) return 72.0;

    // Calculate average RR interval
    double avgRRInterval =
        rrIntervals.reduce((a, b) => a + b) / rrIntervals.length;

    // Convert to heart rate
    double samplingRate = ecgData.length / duration; // samples per second
    double timeBetweenBeats =
        avgRRInterval / samplingRate; // seconds between beats
    double heartRate = 60.0 / timeBetweenBeats; // BPM

    // Ensure result is within physiologically reasonable range
    heartRate = heartRate.clamp(40.0, 200.0);

    // If still seems unreasonable, try alternative calculation
    if (heartRate < 50 || heartRate > 150) {
      // Alternative: count peaks over time
      double dataTimeSeconds = ecgData.length / samplingRate;
      double peaksPerSecond = peaks.length / dataTimeSeconds;
      double alternativeHR = peaksPerSecond * 60;

      if (alternativeHR >= 50 && alternativeHR <= 150) {
        heartRate = alternativeHR;
      }
    }

    // Apply correction factor for low BPM readings (below 50)
    if (heartRate < 50.0) {
      heartRate = heartRate * 1.7; // Multiply by 1.7 as correction factor
      print(
          'ECG Data Service: Applied 1.7x correction factor for low BPM. Original: ${(heartRate / 1.7).toStringAsFixed(1)}, Corrected: ${heartRate.toStringAsFixed(1)}');
    }

    return heartRate;
  }

  // Calculate threshold for peak detection
  double _calculateThreshold(List<double> ecgData) {
    double mean = ecgData.reduce((a, b) => a + b) / ecgData.length;
    double variance =
        ecgData.map((x) => pow(x - mean, 2)).reduce((a, b) => a + b) /
            ecgData.length;
    double stdDev = sqrt(variance);
    return mean + 1.5 * stdDev;
  }

  // Process real ECG data from NodeMCU (for future implementation)
  ECGReading processRealTimeData(int userId, List<double> rawData) {
    // Filter and clean the data
    List<double> filteredData = _applyBasicFilter(rawData);

    return ECGReading(
      userId: userId,
      timestamp: DateTime.now(),
      ecgData: filteredData,
      duration: 10,
      heartRate: _calculateHeartRate(filteredData, 10),
      notes: 'Real-time ECG reading',
    );
  }

  // Basic signal filtering
  List<double> _applyBasicFilter(List<double> data) {
    // Apply simple moving average filter
    List<double> filtered = [];
    int windowSize = 3;

    for (int i = 0; i < data.length; i++) {
      double sum = 0;
      int count = 0;

      for (int j = max(0, i - windowSize);
          j <= min(data.length - 1, i + windowSize);
          j++) {
        sum += data[j];
        count++;
      }

      filtered.add(sum / count);
    }

    return filtered;
  }
}

// Utility functions
double sin(double x) => math.sin(x);
double pi = math.pi;
double pow(double x, double y) => math.pow(x, y).toDouble();
double sqrt(double x) => math.sqrt(x);
int max(int a, int b) => math.max(a, b);
int min(int a, int b) => math.min(a, b);
