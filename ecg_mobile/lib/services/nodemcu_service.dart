import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/ecg_reading.dart';

class NodeMCUService {
  NodeMCUService._internal();

  static final NodeMCUService _instance = NodeMCUService._internal();
  factory NodeMCUService() => _instance;

  static const String defaultNodeMCUIP = '192.168.4.1';
  static const int defaultNodeMCUPort = 80;
  static const String _healthEndpoint = '/health';
  static const String _commandEndpoint = '/command';
  static const List<String> _knownDataEndpoints = [
    '/ecg',
    '/getDustDensity',
  ];
  static const String _prefsIpKey = 'nodemcu_ip';
  static const String _prefsPortKey = 'nodemcu_port';
  static const String _prefsEndpointKey = 'nodemcu_endpoint';

  String _nodeMCUIP = defaultNodeMCUIP;
  int _nodeMCUPort = defaultNodeMCUPort;
  String _activeDataEndpoint = _knownDataEndpoints.first;
  bool _hasLoadedSavedConfiguration = false;
  bool _isConnected = false;
  bool _isRecording = false;
  Timer? _pollingTimer;

  final StreamController<List<double>> _ecgDataController =
      StreamController<List<double>>.broadcast();
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();
  final StreamController<String> _statusController =
      StreamController<String>.broadcast();

  Stream<List<double>> get ecgDataStream => _ecgDataController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;
  Stream<String> get statusStream => _statusController.stream;

  bool get isConnected => _isConnected;
  String get nodeMCUIP => _nodeMCUIP;
  int get nodeMCUPort => _nodeMCUPort;
  String get activeDataEndpoint => _activeDataEndpoint;

  List<double> _ecgBuffer = [];
  static const int ecgReadingSize = 187;
  static const Duration pollingInterval = Duration(milliseconds: 50);

  Future<void> restoreSavedConnectionParameters() async {
    if (_hasLoadedSavedConfiguration) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    _nodeMCUIP = prefs.getString(_prefsIpKey) ?? defaultNodeMCUIP;
    _nodeMCUPort = prefs.getInt(_prefsPortKey) ?? defaultNodeMCUPort;
    _activeDataEndpoint =
        prefs.getString(_prefsEndpointKey) ?? _knownDataEndpoints.first;
    _hasLoadedSavedConfiguration = true;
    _updateStatus(
      'Ready for ECG device at $_nodeMCUIP:$_nodeMCUPort ($_activeDataEndpoint)',
    );
  }

  Future<void> setConnectionParameters(String ip, int port) async {
    final sanitizedIp = ip.trim().isEmpty ? defaultNodeMCUIP : ip.trim();
    final sanitizedPort = port > 0 && port <= 65535 ? port : defaultNodeMCUPort;

    _nodeMCUIP = sanitizedIp;
    _nodeMCUPort = sanitizedPort;
    _activeDataEndpoint = _knownDataEndpoints.first;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsIpKey, _nodeMCUIP);
    await prefs.setInt(_prefsPortKey, _nodeMCUPort);
    await prefs.setString(_prefsEndpointKey, _activeDataEndpoint);

    _updateStatus(
      'Connection target saved: http://$_nodeMCUIP:$_nodeMCUPort$_activeDataEndpoint',
    );
  }

  Future<bool> connectToNodeMCU() async {
    try {
      await restoreSavedConnectionParameters();
      _updateStatus('Checking ECG device on $_nodeMCUIP:$_nodeMCUPort...');

      final discovered = await _discoverDevice();
      if (!discovered) {
        throw const HttpException(
          'Could not find a compatible ECG endpoint on the device',
        );
      }

      _isConnected = true;
      _connectionController.add(true);
      _updateStatus(
        'Connected to ECG device on $_nodeMCUIP:$_nodeMCUPort via $_activeDataEndpoint',
      );
      _startPolling();
      return true;
    } catch (e) {
      _isConnected = false;
      _connectionController.add(false);
      _updateStatus('Failed to connect: $e');
      return false;
    }
  }

  void disconnect() {
    _stopPolling();
    _isConnected = false;
    _isRecording = false;
    _connectionController.add(false);
    _updateStatus('Disconnected from ECG device');
  }

  void _startPolling() {
    _stopPolling();
    _pollingTimer = Timer.periodic(pollingInterval, (timer) async {
      if (!_isConnected) {
        timer.cancel();
        return;
      }
      await _fetchECGData();
    });
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<void> _fetchECGData() async {
    if (!_isRecording) {
      return;
    }

    try {
      final response = await _requestDataEndpoint(
        timeout: const Duration(seconds: 2),
        acceptedStatusCodes: const {200, 503},
      );

      if (response == null) {
        return;
      }

      if (response.statusCode == 503) {
        _updateStatus('Electrodes are not attached yet. Check both leads.');
        return;
      }

      final sample = _extractSampleValue(response.body);
      if (sample == null) {
        _updateStatus('Device responded with unreadable ECG data.');
        return;
      }

      final normalizedValue = (sample / 1024.0).clamp(0.0, 1.0) * 0.3;
      _processECGData([normalizedValue]);
    } on SocketException catch (e) {
      _handleConnectionLoss('Connection lost: $e');
    } on TimeoutException catch (e) {
      _handleConnectionLoss('Device stopped responding: $e');
    } catch (e) {
      _updateStatus('Error fetching ECG data: $e');
    }
  }

  void _handleConnectionLoss(String status) {
    _stopPolling();
    _isConnected = false;
    _isRecording = false;
    _connectionController.add(false);
    _updateStatus(status);
  }

  void _processECGData(List<double> newDataPoints) {
    _ecgBuffer.addAll(newDataPoints);
    _ecgDataController.add(List<double>.from(_ecgBuffer));

    if (_ecgBuffer.length >= ecgReadingSize) {
      final completeReading = _ecgBuffer.take(ecgReadingSize).toList();
      _emitCompleteReading(completeReading);
    }

    if (_ecgBuffer.length > ecgReadingSize * 2) {
      _ecgBuffer = _ecgBuffer.skip(_ecgBuffer.length - ecgReadingSize).toList();
    }
  }

  void _emitCompleteReading(List<double> ecgData) {
    _updateStatus('Complete ECG reading captured (${ecgData.length} samples)');
  }

  Future<bool> testConnection() async {
    try {
      await restoreSavedConnectionParameters();
      _updateStatus(
        'Testing ECG device at $_nodeMCUIP:$_nodeMCUPort. Confirm the phone is on the device Wi-Fi.',
      );

      final discovered = await _discoverDevice();
      if (!discovered) {
        _updateStatus(
          'No compatible ECG endpoint found. Check the port and upload the updated Arduino sketch.',
        );
        return false;
      }

      final response = await _requestDataEndpoint(
        timeout: const Duration(seconds: 3),
        acceptedStatusCodes: const {200, 503},
      );

      if (response == null) {
        _updateStatus('Device did not return any ECG data.');
        return false;
      }

      if (response.statusCode == 503) {
        _updateStatus(
          'Device is online on port $_nodeMCUPort, but the electrodes are currently off.',
        );
        return true;
      }

      final sample = _extractSampleValue(response.body);
      _updateStatus(
        sample == null
            ? 'Device responded, but the sample could not be parsed.'
            : 'Connection test successful. Current sample: ${sample.toStringAsFixed(0)}',
      );
      return sample != null;
    } catch (e) {
      _updateStatus('Connection test failed: $e');
      return false;
    }
  }

  Future<bool> _discoverDevice() async {
    final healthResponse = await _performRequest(
      _healthEndpoint,
      timeout: const Duration(seconds: 3),
      acceptedStatusCodes: const {200},
    );

    if (healthResponse != null) {
      final detectedEndpoint = _extractDataEndpoint(healthResponse.body);
      if (detectedEndpoint != null) {
        _activeDataEndpoint = detectedEndpoint;
        await _persistActiveEndpoint();
      }
      return true;
    }

    for (final endpoint in _knownDataEndpoints) {
      final response = await _performRequest(
        endpoint,
        timeout: const Duration(seconds: 3),
        acceptedStatusCodes: const {200, 503},
      );
      if (response != null) {
        _activeDataEndpoint = endpoint;
        await _persistActiveEndpoint();
        return true;
      }
    }

    return false;
  }

  Future<void> _persistActiveEndpoint() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsEndpointKey, _activeDataEndpoint);
  }

  Future<http.Response?> _requestDataEndpoint({
    required Duration timeout,
    required Set<int> acceptedStatusCodes,
  }) {
    return _performRequest(
      _activeDataEndpoint,
      timeout: timeout,
      acceptedStatusCodes: acceptedStatusCodes,
    );
  }

  Future<http.Response?> _performRequest(
    String path, {
    required Duration timeout,
    required Set<int> acceptedStatusCodes,
    Map<String, String>? queryParameters,
  }) async {
    final uri = Uri(
      scheme: 'http',
      host: _nodeMCUIP,
      port: _nodeMCUPort,
      path: path,
      queryParameters: queryParameters,
    );

    final response = await http.get(uri,
        headers: {'Content-Type': 'application/json'}).timeout(timeout);

    if (!acceptedStatusCodes.contains(response.statusCode)) {
      return null;
    }

    return response;
  }

  double? _extractSampleValue(String responseBody) {
    final trimmed = responseBody.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final plainValue = double.tryParse(trimmed);
    if (plainValue != null) {
      return plainValue;
    }

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) {
        final dynamic sampleCandidate = decoded['sample'] ??
            decoded['ecg'] ??
            decoded['value'] ??
            decoded['raw'];
        if (sampleCandidate is num) {
          return sampleCandidate.toDouble();
        }
        if (sampleCandidate is String) {
          return double.tryParse(sampleCandidate);
        }
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  String? _extractDataEndpoint(String responseBody) {
    try {
      final decoded = jsonDecode(responseBody);
      if (decoded is Map<String, dynamic>) {
        final dynamic endpoint = decoded['dataEndpoint'];
        if (endpoint is String && endpoint.startsWith('/')) {
          return endpoint;
        }
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  Future<bool> sendCommand(
    String command, {
    Map<String, dynamic>? parameters,
  }) async {
    if (!_isConnected) {
      _updateStatus(
          'Cannot send "$command" because the ECG device is not connected.');
      return false;
    }

    try {
      final queryParameters = <String, String>{'action': command};
      parameters?.forEach((key, value) {
        queryParameters[key] = value.toString();
      });

      final response = await _performRequest(
        _commandEndpoint,
        timeout: const Duration(seconds: 3),
        acceptedStatusCodes: const {200},
        queryParameters: queryParameters,
      );

      if (response == null) {
        _updateStatus('Device did not acknowledge "$command".');
        return false;
      }

      _updateStatus('Device acknowledged "$command".');
      return true;
    } catch (e) {
      _updateStatus('Failed to send "$command": $e');
      return false;
    }
  }

  Future<bool> startECGRecording() async {
    _isRecording = true;
    final success = await sendCommand('start_recording');
    if (!success) {
      _updateStatus(
        'Recording started locally. Update the device sketch if command support is missing.',
      );
    }
    return success;
  }

  Future<bool> stopECGRecording() async {
    _isRecording = false;
    return sendCommand('stop_recording');
  }

  Future<bool> calibrateECG() async {
    return sendCommand('calibrate');
  }

  void _updateStatus(String status) {
    stdout.writeln('NodeMCU Service: $status');
    _statusController.add(status);
  }

  ECGReading? createECGReading(int userId, List<double> ecgData) {
    if (ecgData.length < ecgReadingSize) {
      return null;
    }

    return ECGReading(
      userId: userId,
      timestamp: DateTime.now(),
      ecgData: ecgData.take(ecgReadingSize).toList(),
      duration: 10,
      heartRate: _calculateHeartRate(ecgData.take(ecgReadingSize).toList()),
      notes: 'Live ECG reading from ECG device',
    );
  }

  double _calculateHeartRate(List<double> ecgData) {
    if (ecgData.isEmpty || ecgData.length < 30) {
      return 72.0;
    }

    List<int> peaks = [];
    double mean = ecgData.reduce((a, b) => a + b) / ecgData.length;
    double maxVal = ecgData.reduce((a, b) => a > b ? a : b);
    double threshold = mean + (maxVal - mean) * 0.3;

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
      threshold = mean + (maxVal - mean) * 0.2;
      peaks = [];

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

    if (peaks.length < 2) {
      return 72.0;
    }

    List<double> rrIntervals = [];
    for (int i = 1; i < peaks.length; i++) {
      rrIntervals.add((peaks[i] - peaks[i - 1]).toDouble());
    }

    if (rrIntervals.length > 2) {
      rrIntervals.sort();
      final removeCount = (rrIntervals.length * 0.2).floor();
      if (removeCount > 0) {
        rrIntervals =
            rrIntervals.sublist(removeCount, rrIntervals.length - removeCount);
      }
    }

    if (rrIntervals.isEmpty) {
      return 72.0;
    }

    final avgRRInterval =
        rrIntervals.reduce((a, b) => a + b) / rrIntervals.length;
    final samplingRate = ecgData.length / 10.0;
    final timeBetweenBeats = avgRRInterval / samplingRate;
    double heartRate = 60.0 / timeBetweenBeats;
    heartRate = heartRate.clamp(40.0, 200.0);

    if (heartRate < 50 || heartRate > 150) {
      final dataTimeSeconds = ecgData.length / samplingRate;
      final peaksPerSecond = peaks.length / dataTimeSeconds;
      final alternativeHeartRate = peaksPerSecond * 60;
      if (alternativeHeartRate >= 50 && alternativeHeartRate <= 150) {
        heartRate = alternativeHeartRate;
      }
    }

    return heartRate;
  }

  void dispose() {
    _stopPolling();
    _ecgDataController.close();
    _connectionController.close();
    _statusController.close();
  }

  void clearBuffer() {
    _ecgBuffer.clear();
    _updateStatus('ECG buffer cleared. Ready for a fresh recording.');
  }
}
