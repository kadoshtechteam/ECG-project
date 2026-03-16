import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/ecg_reading.dart';
import '../models/prediction.dart';
import '../services/database_helper.dart';
import '../services/ecg_data_service.dart';
import '../services/nodemcu_service.dart';
import '../services/prediction_service.dart';

class ECGProvider with ChangeNotifier {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  final ECGDataService _ecgDataService = ECGDataService();
  final NodeMCUService _nodeMCUService = NodeMCUService();
  final PredictionService _predictionService = PredictionService();

  List<ECGReading> _readings = [];
  final List<Prediction> _predictions = [];
  bool _isLoading = false;
  ECGReading? _currentReading;
  int? _currentUserId;

  // NodeMCU State
  bool _isConnectedToNodeMCU = false;
  bool _isRecordingLive = false;
  String _nodeMCUStatus = 'Not connected';
  List<double> _liveECGData = [];
  StreamSubscription? _nodeMCUConnectionSubscription;
  StreamSubscription? _nodeMCUDataSubscription;
  StreamSubscription? _nodeMCUStatusSubscription;

  Prediction? _lastPrediction;
  double?
      _persistedLiveHeartRate; // Store the last calculated BPM when live test stops
  bool _hasCollectedSufficientData =
      false; // Track if we have enough data for prediction

  // Getters
  List<ECGReading> get readings => _readings;
  List<Prediction> get predictions => _predictions;
  bool get isLoading => _isLoading;
  ECGReading? get currentReading => _currentReading;

  // NodeMCU Getters
  bool get isConnectedToNodeMCU => _isConnectedToNodeMCU;
  bool get isRecordingLive => _isRecordingLive;
  String get nodeMCUStatus => _nodeMCUStatus;
  String get nodeMCUIP => _nodeMCUService.nodeMCUIP;
  int get nodeMCUPort => _nodeMCUService.nodeMCUPort;
  String get nodeMCUDataEndpoint => _nodeMCUService.activeDataEndpoint;
  List<double> get liveECGData => _liveECGData;
  Prediction? get lastPrediction => _lastPrediction;
  double? get persistedLiveHeartRate => _persistedLiveHeartRate;
  bool get hasCollectedSufficientData => _hasCollectedSufficientData;

  ECGProvider() {
    _nodeMCUConnectionSubscription = _nodeMCUService.connectionStream.listen((
      isConnected,
    ) {
      _isConnectedToNodeMCU = isConnected;
      if (!isConnected) {
        _isRecordingLive = false;
        _liveECGData.clear();
      }
      notifyListeners();
    });

    _nodeMCUDataSubscription = _nodeMCUService.ecgDataStream.listen((data) {
      if (_isRecordingLive) {
        _liveECGData = data;
        if (_liveECGData.length >= 187) {
          _hasCollectedSufficientData = true; // Mark that we have enough data
          debugPrint(
              'ECG Provider: Sufficient data collected (${_liveECGData.length} points) - prediction button should appear');
          stopLiveRecording();
          // Automatically save the live reading when enough data is collected
          _autoSaveLiveReading();
        }
        notifyListeners();
      }
    });

    _nodeMCUStatusSubscription = _nodeMCUService.statusStream.listen((status) {
      _nodeMCUStatus = status;
      notifyListeners();
    });

    // Test the ML model on initialization
    _testMLModel();
    unawaited(loadNodeMCUConfiguration());
  }

  /// Test the ML model to ensure it's working correctly
  Future<void> _testMLModel() async {
    try {
      debugPrint('🔬 Initializing ML model test...');
      final isWorking = await _predictionService.testModel();
      if (isWorking) {
        debugPrint('✅ ML model is working correctly');
      } else {
        debugPrint('⚠️ ML model test failed - predictions may not work');
      }
    } catch (e) {
      debugPrint('❌ ML model test error: $e');
    }
  }

  @override
  void dispose() {
    _nodeMCUConnectionSubscription?.cancel();
    _nodeMCUDataSubscription?.cancel();
    _nodeMCUStatusSubscription?.cancel();
    _predictionService.dispose();
    super.dispose();
  }

  // UI Methods
  Future<void> loadNodeMCUConfiguration() async {
    await _nodeMCUService.restoreSavedConnectionParameters();
    notifyListeners();
  }

  Future<void> setNodeMCUParameters(String ip, int port) async {
    await _nodeMCUService.setConnectionParameters(ip, port);
    notifyListeners();
  }

  Future<void> testNodeMCUConnection() async {
    _isLoading = true;
    notifyListeners();
    await _nodeMCUService.testConnection();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> connectToNodeMCU() async {
    _isLoading = true;
    notifyListeners();
    await _nodeMCUService.connectToNodeMCU();
    _isLoading = false;
    notifyListeners();
  }

  void disconnectFromNodeMCU() {
    _nodeMCUService.disconnect();
  }

  void startLiveRecording() {
    if (_isConnectedToNodeMCU) {
      _isRecordingLive = true;
      clearLiveDataForNewRecording(); // Use the new method that resets both data and flag
      _nodeMCUService.clearBuffer();
      _nodeMCUService.startECGRecording();
      debugPrint('ECG Provider: Started live recording');
      notifyListeners();
    }
  }

  void stopLiveRecording() {
    // Store the current live heart rate before stopping
    _persistedLiveHeartRate = getCurrentLiveHeartRate();
    _isRecordingLive = false;
    _nodeMCUService.stopECGRecording();
    notifyListeners();
  }

  void clearLiveData() {
    _liveECGData.clear();
    // Don't automatically reset the sufficient data flag here
    // Only reset when starting a new recording or manually requested
    _persistedLiveHeartRate = null; // Clear persisted BPM when clearing data
    debugPrint(
        'ECG Provider: Live data cleared, keeping sufficient data flag: $_hasCollectedSufficientData');
    notifyListeners();
  }

  // Private method to automatically save live reading when enough data is collected
  Future<void> _autoSaveLiveReading() async {
    if (_liveECGData.isNotEmpty && _currentUserId != null) {
      try {
        // Create a new reading from the live data with calculated heart rate
        final newReading = _ecgDataService.processRealTimeData(
          _currentUserId!,
          List.from(_liveECGData),
        );

        // Add to database and local list
        await addReading(newReading);

        debugPrint(
            'Auto-saved live reading with heart rate: ${newReading.heartRate?.toStringAsFixed(1)} BPM');

        // Don't clear live data immediately - keep it for prediction
        // The data will be cleared when starting a new recording or manually clearing
        notifyListeners();
      } catch (e) {
        debugPrint('Failed to auto-save live reading: $e');
      }
    }
  }

  Future<bool> saveLiveReading() async {
    if (_liveECGData.isEmpty || _currentUserId == null) return false;

    try {
      // Create a new reading from the live data
      final newReading = _ecgDataService.processRealTimeData(
        _currentUserId!,
        List.from(_liveECGData),
      );

      // Add to database and local list
      await addReading(newReading);

      // Clear live data
      _liveECGData.clear();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Failed to save live reading: $e');
      return false;
    }
  }

  Future<ECGReading?> saveLiveReadingAndGet() async {
    if (_liveECGData.isEmpty || _currentUserId == null) return null;

    try {
      final newReading = _ecgDataService.processRealTimeData(
        _currentUserId!,
        List.from(_liveECGData),
      );

      int id = await _databaseHelper.insertECGReading(newReading);
      final savedReading = newReading.copyWith(id: id);
      _readings.insert(0, savedReading);

      _liveECGData.clear();
      notifyListeners();
      return savedReading;
    } catch (e) {
      debugPrint('Failed to save and get live reading: $e');
      return null;
    }
  }

  Future<Prediction?> runPredictionOnReading(ECGReading reading) async {
    _isLoading = true;
    notifyListeners();

    try {
      final prediction =
          await _predictionService.predict(reading.ecgData, reading.id!);
      if (prediction != null) {
        await _databaseHelper.insertPrediction(prediction);
        _lastPrediction = prediction;
        debugPrint('Prediction completed successfully');
      } else {
        debugPrint(
            'Prediction failed: Model not available or prediction returned null');
      }

      _isLoading = false;
      notifyListeners();
      return prediction;
    } catch (e) {
      debugPrint('Error during prediction: $e');
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  /// Explicitly reset the sufficient data flag (separate from clearing data)
  void resetSufficientDataFlag() {
    _hasCollectedSufficientData = false;
    debugPrint('ECG Provider: Sufficient data flag reset');
    notifyListeners();
  }

  /// Clear live data and reset sufficient data flag (for new recording)
  void clearLiveDataForNewRecording() {
    _liveECGData.clear();
    _hasCollectedSufficientData = false;
    _persistedLiveHeartRate = null;
    debugPrint(
        'ECG Provider: Live data and sufficient data flag cleared for new recording');
    notifyListeners();
  }

  /// Set current user ID for auto-saving readings
  void setCurrentUserId(int userId) {
    _currentUserId = userId;
  }

  Future<void> loadReadings(int userId) async {
    _currentUserId = userId;
    _isLoading = true;
    notifyListeners();

    try {
      _readings = await _databaseHelper.getECGReadingsByUserId(userId);
      debugPrint(
        'ECG Provider: Loaded ${_readings.length} readings for user $userId',
      );

      // Debug: Print some info about the readings
      if (_readings.isNotEmpty) {
        debugPrint(
          'ECG Provider: First reading ID: ${_readings.first.id}, timestamp: ${_readings.first.timestamp}',
        );
      }
    } catch (e) {
      debugPrint('Error loading readings: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addReading(ECGReading reading) async {
    try {
      int id = await _databaseHelper.insertECGReading(reading);
      _readings.insert(0, reading.copyWith(id: id));
      debugPrint(
        'ECG Provider: Added reading with ID: $id, total readings: ${_readings.length}',
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding reading: $e');
    }
  }

  void setCurrentReading(ECGReading reading) {
    _currentReading = reading;
    notifyListeners();
  }

  // Calculate current heart rate from live ECG data
  double? getCurrentLiveHeartRate() {
    if (_liveECGData.isEmpty || _liveECGData.length < 50) return null;

    try {
      // Use a subset of live data for real-time heart rate calculation
      List<double> dataForCalculation = _liveECGData.length > 100
          ? _liveECGData.sublist(_liveECGData.length - 100)
          : _liveECGData;

      return _calculateLiveHeartRate(dataForCalculation);
    } catch (e) {
      debugPrint('Error calculating live heart rate: $e');
      return null;
    }
  }

  // Simple heart rate calculation for live data
  double _calculateLiveHeartRate(List<double> ecgData) {
    if (ecgData.length < 30) return 0.0;

    // Improved peak detection algorithm
    List<int> peaks = [];

    // Calculate dynamic threshold based on data statistics
    double mean = ecgData.reduce((a, b) => a + b) / ecgData.length;
    double maxVal = ecgData.reduce((a, b) => a > b ? a : b);
    double threshold = mean + (maxVal - mean) * 0.4; // More adaptive threshold

    // Find peaks with better filtering
    for (int i = 2; i < ecgData.length - 2; i++) {
      // Check if current point is a local maximum
      if (ecgData[i] > ecgData[i - 1] &&
          ecgData[i] > ecgData[i + 1] &&
          ecgData[i] > ecgData[i - 2] &&
          ecgData[i] > ecgData[i + 2] &&
          ecgData[i] > threshold) {
        // Ensure peaks are separated by reasonable time (avoid double counting)
        // For 70 BPM, peaks should be ~25-30 samples apart at ~18.5 Hz
        if (peaks.isEmpty || i - peaks.last > 20) {
          peaks.add(i);
        }
      }
    }

    if (peaks.length < 2) return 0.0;

    // Calculate RR intervals (time between beats)
    List<double> rrIntervals = [];
    for (int i = 1; i < peaks.length; i++) {
      rrIntervals.add((peaks[i] - peaks[i - 1]).toDouble());
    }

    // Remove outliers (very short or very long intervals)
    rrIntervals.removeWhere((interval) => interval < 10 || interval > 50);

    if (rrIntervals.isEmpty) return 0.0;

    // Calculate average RR interval
    double avgRRInterval =
        rrIntervals.reduce((a, b) => a + b) / rrIntervals.length;

    // Convert to heart rate
    // Assuming 18.5 Hz sampling rate for live ECG data
    double samplesPerSecond = 18.5;
    double timeBetweenBeats = avgRRInterval / samplesPerSecond;
    double heartRate = 60.0 / timeBetweenBeats;

    // Additional validation - if result seems too low/high, try different approach
    if (heartRate < 50 || heartRate > 150) {
      // Alternative calculation using peak count over time
      double dataTimeSeconds = ecgData.length / samplesPerSecond;
      double peaksPerSecond = peaks.length / dataTimeSeconds;
      double alternativeHR = peaksPerSecond * 60;

      // Use alternative if it's more reasonable
      if (alternativeHR >= 50 && alternativeHR <= 150) {
        heartRate = alternativeHR;
      }
    }

    // Clamp to physiologically reasonable range but allow lower values
    return heartRate.clamp(40.0, 200.0);
  }

  // Calculate threshold for peak detection
  double _calculateThreshold(List<double> ecgData) {
    if (ecgData.isEmpty) return 0.0;

    double sum = ecgData.reduce((a, b) => a + b);
    double mean = sum / ecgData.length;

    // Use mean + standard deviation as threshold
    double variance = 0.0;
    for (double value in ecgData) {
      variance += (value - mean) * (value - mean);
    }
    double stdDev = (variance / ecgData.length);
    if (stdDev > 0) {
      stdDev = stdDev; // Keep as is, no sqrt for simplicity in live calculation
    }

    return mean + (stdDev * 0.3); // Use smaller multiplier for live data
  }
}
