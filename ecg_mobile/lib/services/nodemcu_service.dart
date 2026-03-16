import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/ecg_reading.dart';

class NodeMCUService {
  static final NodeMCUService _instance = NodeMCUService._internal();
  factory NodeMCUService() => _instance;
  NodeMCUService._internal();

  // NodeMCU configuration
  String _nodeMCUIP = '192.168.4.1'; // Default AP mode IP
  int _nodeMCUPort = 80;
  bool _isConnected = false;
  Timer? _pollingTimer;

  // Stream controllers for real-time data
  final StreamController<List<double>> _ecgDataController =
      StreamController<List<double>>.broadcast();
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();
  final StreamController<String> _statusController =
      StreamController<String>.broadcast();

  // Getters for streams
  Stream<List<double>> get ecgDataStream => _ecgDataController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;
  Stream<String> get statusStream => _statusController.stream;

  // Getters for current state
  bool get isConnected => _isConnected;
  String get nodeMCUIP => _nodeMCUIP;
  int get nodeMCUPort => _nodeMCUPort;

  // Buffer for accumulating ECG data points
  List<double> _ecgBuffer = [];
  static const int ECG_READING_SIZE = 187; // Standard ECG reading size
  static const Duration POLLING_INTERVAL = Duration(
    milliseconds: 50, // Faster polling: 20Hz instead of 10Hz
  ); // Changed from 100ms to 50ms for faster data collection

  // Add flag to track if we should keep accumulating data
  bool _isRecording = false;

  /// Set NodeMCU connection parameters
  void setConnectionParameters(String ip, int port) {
    _nodeMCUIP = ip;
    _nodeMCUPort = port;
    _updateStatus('Connection parameters updated: $_nodeMCUIP:$_nodeMCUPort');
  }

  /// Connect to NodeMCU in AP mode
  Future<bool> connectToNodeMCU() async {
    try {
      _updateStatus(
        'Attempting to connect to NodeMCU at $_nodeMCUIP:$_nodeMCUPort...',
      );

      // Test connection with a simple HTTP request to the actual endpoint
      final response = await http.get(
        Uri.parse('http://$_nodeMCUIP:$_nodeMCUPort/getDustDensity'),
        headers: {'Content-Type': 'text/plain'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        _isConnected = true;
        _connectionController.add(true);
        _updateStatus('Successfully connected to NodeMCU');

        // Start polling for ECG data
        _startPolling();
        return true;
      } else {
        throw Exception(
          'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        );
      }
    } catch (e) {
      _isConnected = false;
      _connectionController.add(false);
      _updateStatus('Failed to connect: $e');
      return false;
    }
  }

  /// Disconnect from NodeMCU
  void disconnect() {
    _stopPolling();
    _isConnected = false;
    _connectionController.add(false);
    _updateStatus('Disconnected from NodeMCU');
  }

  /// Start polling for ECG data
  void _startPolling() {
    _stopPolling(); // Stop any existing timer

    _pollingTimer = Timer.periodic(POLLING_INTERVAL, (timer) async {
      if (_isConnected) {
        await _fetchECGData();
      } else {
        timer.cancel();
      }
    });
  }

  /// Stop polling for ECG data
  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  /// Fetch ECG data from NodeMCU
  Future<void> _fetchECGData() async {
    try {
      final response = await http.get(
        Uri.parse('http://$_nodeMCUIP:$_nodeMCUPort/getDustDensity'),
        headers: {'Content-Type': 'text/plain'},
      ).timeout(const Duration(seconds: 2));

      if (response.statusCode == 200) {
        // The Arduino code returns a single analog reading as plain text
        String rawValue = response.body.trim();
        double ecgValue = double.tryParse(rawValue) ?? 0.0;

        // Convert from Arduino analog reading (0-1024) to normalized ECG value (0.0-0.3)
        double normalizedValue = (ecgValue / 1024.0) * 0.3;

        _processECGData([normalizedValue]);
      } else if (response.statusCode != 204) {
        _updateStatus('HTTP ${response.statusCode}: Failed to fetch ECG data');
      }
    } catch (e) {
      if (e is SocketException || e.toString().contains('Connection refused')) {
        // Connection lost
        _isConnected = false;
        _connectionController.add(false);
        _updateStatus('Connection lost: $e');
        _stopPolling();
      } else {
        _updateStatus('Error fetching data: $e');
      }
    }
  }

  /// Process incoming ECG data and emit complete readings
  void _processECGData(List<double> newDataPoints) {
    // Add new data points to buffer
    _ecgBuffer.addAll(newDataPoints);

    // Emit current buffer data for real-time display
    _ecgDataController.add(List.from(_ecgBuffer));

    // Keep data available even after reaching 187 points
    // Don't automatically remove data - let the provider manage it
    if (_ecgBuffer.length >= ECG_READING_SIZE) {
      // Emit complete reading but keep buffer intact
      List<double> completeReading = _ecgBuffer.take(ECG_READING_SIZE).toList();
      _emitCompleteReading(completeReading);
    }

    // Only prevent buffer from growing too large (double the target size)
    if (_ecgBuffer.length > ECG_READING_SIZE * 2) {
      // Keep the most recent ECG_READING_SIZE points
      _ecgBuffer =
          _ecgBuffer.skip(_ecgBuffer.length - ECG_READING_SIZE).toList();
    }
  }

  /// Emit a complete ECG reading
  void _emitCompleteReading(List<double> ecgData) {
    // This will be handled by the ECG provider to save to database
    // For now, just update status
    _updateStatus('Complete ECG reading received (${ecgData.length} points)');
  }

  /// Test connection to NodeMCU
  Future<bool> testConnection() async {
    try {
      _updateStatus('Testing connection to $_nodeMCUIP:$_nodeMCUPort...');

      final response = await http.get(
        Uri.parse('http://$_nodeMCUIP:$_nodeMCUPort/getDustDensity'),
        headers: {'Content-Type': 'text/plain'},
      ).timeout(const Duration(seconds: 3));

      bool success = response.statusCode == 200;
      if (success) {
        String rawValue = response.body.trim();
        double ecgValue = double.tryParse(rawValue) ?? 0.0;
        _updateStatus(
          'Connection test successful - Current reading: $ecgValue',
        );
      } else {
        _updateStatus('Connection test failed: HTTP ${response.statusCode}');
      }

      return success;
    } catch (e) {
      _updateStatus('Connection test failed: $e');
      return false;
    }
  }

  /// Send command to NodeMCU (simplified since Arduino code doesn't handle commands)
  Future<bool> sendCommand(
    String command, {
    Map<String, dynamic>? parameters,
  }) async {
    if (!_isConnected) {
      _updateStatus('Cannot send command: Not connected to NodeMCU');
      return false;
    }

    // Since the Arduino code doesn't have command handling, we'll just log this
    _updateStatus(
      'Note: Arduino code doesn\'t support commands. Command "$command" logged.',
    );
    return true;
  }

  /// Start ECG recording on NodeMCU
  Future<bool> startECGRecording() async {
    _isRecording = true;
    return await sendCommand('start_recording');
  }

  /// Stop ECG recording on NodeMCU
  Future<bool> stopECGRecording() async {
    _isRecording = false;
    return await sendCommand('stop_recording');
  }

  /// Calibrate ECG sensor
  Future<bool> calibrateECG() async {
    return await sendCommand('calibrate');
  }

  /// Update status and emit to stream
  void _updateStatus(String status) {
    print('NodeMCU Service: $status');
    _statusController.add(status);
  }

  /// Get complete ECG reading as ECGReading object
  ECGReading? createECGReading(int userId, List<double> ecgData) {
    if (ecgData.length < ECG_READING_SIZE) {
      return null;
    }

    return ECGReading(
      userId: userId,
      timestamp: DateTime.now(),
      ecgData: ecgData.take(ECG_READING_SIZE).toList(),
      duration: 10, // Assuming 10 second readings
      heartRate: _calculateHeartRate(ecgData.take(ECG_READING_SIZE).toList()),
      notes: 'Live ECG reading from NodeMCU',
    );
  }

  /// Calculate heart rate from ECG data (improved)
  double _calculateHeartRate(List<double> ecgData) {
    if (ecgData.isEmpty || ecgData.length < 30)
      return 72.0; // Default reasonable value

    // Improved peak detection
    List<int> peaks = [];

    // Calculate dynamic threshold
    double mean = ecgData.reduce((a, b) => a + b) / ecgData.length;
    double maxVal = ecgData.reduce((a, b) => a > b ? a : b);
    double threshold = mean + (maxVal - mean) * 0.3;

    // Find peaks with better filtering
    for (int i = 2; i < ecgData.length - 2; i++) {
      if (ecgData[i] > ecgData[i - 1] &&
          ecgData[i] > ecgData[i + 1] &&
          ecgData[i] > ecgData[i - 2] &&
          ecgData[i] > ecgData[i + 2] &&
          ecgData[i] > threshold) {
        if (peaks.isEmpty || i - peaks.last > 15) {
          peaks.add(i);
        }
      }
    }

    if (peaks.length < 2) {
      // Fallback with lower threshold
      threshold = mean + (maxVal - mean) * 0.2;
      peaks.clear();

      for (int i = 1; i < ecgData.length - 1; i++) {
        if (ecgData[i] > ecgData[i - 1] &&
            ecgData[i] > ecgData[i + 1] &&
            ecgData[i] > threshold) {
          if (peaks.isEmpty || i - peaks.last > 10) {
            peaks.add(i);
          }
        }
      }
    }

    if (peaks.length < 2) return 72.0; // Default value

    // Calculate RR intervals
    List<double> rrIntervals = [];
    for (int i = 1; i < peaks.length; i++) {
      rrIntervals.add((peaks[i] - peaks[i - 1]).toDouble());
    }

    // Remove outliers if we have enough data
    if (rrIntervals.length > 2) {
      rrIntervals.sort();
      int removeCount = (rrIntervals.length * 0.2).floor();
      if (removeCount > 0) {
        rrIntervals =
            rrIntervals.sublist(removeCount, rrIntervals.length - removeCount);
      }
    }

    if (rrIntervals.isEmpty) return 72.0;

    // Calculate average RR interval and convert to BPM
    double avgRRInterval =
        rrIntervals.reduce((a, b) => a + b) / rrIntervals.length;
    double samplingRate = ecgData.length / 10.0; // 10 second duration
    double timeBetweenBeats = avgRRInterval / samplingRate;
    double heartRate = 60.0 / timeBetweenBeats;

    // Ensure reasonable range
    heartRate = heartRate.clamp(40.0, 200.0);

    // Alternative calculation if result seems unreasonable
    if (heartRate < 50 || heartRate > 150) {
      double dataTimeSeconds = ecgData.length / samplingRate;
      double peaksPerSecond = peaks.length / dataTimeSeconds;
      double alternativeHR = peaksPerSecond * 60;

      if (alternativeHR >= 50 && alternativeHR <= 150) {
        heartRate = alternativeHR;
      }
    }

    return heartRate;
  }

  /// Calculate threshold for peak detection
  double _calculateThreshold(List<double> ecgData) {
    double mean = ecgData.reduce((a, b) => a + b) / ecgData.length;
    double variance =
        ecgData.map((x) => (x - mean) * (x - mean)).reduce((a, b) => a + b) /
            ecgData.length;
    double stdDev = variance > 0 ? variance.sqrt() : 0.0;
    return mean + 1.5 * stdDev;
  }

  /// Dispose resources
  void dispose() {
    _stopPolling();
    _ecgDataController.close();
    _connectionController.close();
    _statusController.close();
  }

  /// Clear the ECG buffer (useful when starting fresh recording)
  void clearBuffer() {
    _ecgBuffer.clear();
    _isRecording = false;
    _updateStatus('ECG buffer cleared - ready for fresh recording');
  }
}

// Extension for sqrt method
extension on double {
  double sqrt() => this >= 0 ? this.abs().squareRoot() : 0.0;

  double squareRoot() {
    if (this == 0) return 0;
    double x = this;
    double result = this;
    while ((result - x / result).abs() > 0.0001) {
      result = (result + x / result) / 2;
    }
    return result;
  }
}
