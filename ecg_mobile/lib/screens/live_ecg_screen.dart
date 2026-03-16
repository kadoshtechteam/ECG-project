import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../providers/auth_provider.dart';
import '../providers/ecg_provider.dart';
import '../models/prediction.dart';
import '../models/ecg_reading.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';

class LiveECGScreen extends StatefulWidget {
  const LiveECGScreen({super.key});

  @override
  State<LiveECGScreen> createState() => _LiveECGScreenState();
}

class _LiveECGScreenState extends State<LiveECGScreen> {
  final TextEditingController _ipController = TextEditingController(
    text: '192.168.4.1',
  );
  final TextEditingController _portController = TextEditingController(
    text: '80',
  );
  final TextEditingController _csvController = TextEditingController();
  bool _showSettings = false;
  bool _showManualTest = false;
  Prediction? _displayedPrediction;
  bool _isTestingManualData = false;

  // Flag to show/hide export ECG data section
  // Set to false to hide export functionality
  // Set to true when you want to enable export features
  bool _showExportSection = false;

  @override
  void initState() {
    super.initState();
    // Check if we should start in manual mode
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null && args['startInManualMode'] == true) {
        setState(() {
          _showManualTest = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    _csvController.dispose();
    super.dispose();
  }

  void _clearLiveData(ECGProvider ecgProvider) {
    debugPrint('Live ECG Screen: User manually clearing live data');
    // Only clear the data, preserve the sufficient data flag if data was already collected
    ecgProvider.clearLiveData();
  }

  String _getCurrentBPMText(ECGProvider ecgProvider) {
    if (ecgProvider.isRecordingLive) {
      if (ecgProvider.liveECGData.length < 50) {
        return 'Starting...';
      }

      final liveHeartRate = ecgProvider.getCurrentLiveHeartRate();
      if (liveHeartRate != null && liveHeartRate > 0) {
        return '${liveHeartRate.round()} BPM';
      }
      return 'Calculating...';
    }

    // Not recording - check for persisted heart rate first, then current data
    final persistedHeartRate = ecgProvider.persistedLiveHeartRate;
    if (persistedHeartRate != null && persistedHeartRate > 0) {
      return '${persistedHeartRate.round()} BPM';
    }

    // Fall back to current data if available
    if (ecgProvider.liveECGData.isNotEmpty) {
      final liveHeartRate = ecgProvider.getCurrentLiveHeartRate();
      if (liveHeartRate != null && liveHeartRate > 0) {
        return '${liveHeartRate.round()} BPM';
      }
    }

    return '--';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live ECG Monitor'),
        backgroundColor: const Color(0xFFE91E63),
        foregroundColor: Colors.white,
        actions: [
          // Toggle switch for Manual/Live mode
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Live',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        _showManualTest ? FontWeight.normal : FontWeight.bold,
                    color: _showManualTest ? Colors.white70 : Colors.white,
                  ),
                ),
                const SizedBox(width: 6),
                Switch(
                  value: _showManualTest,
                  onChanged: (value) {
                    setState(() {
                      _showManualTest = value;
                      if (value) {
                        // Clear any previous prediction when switching to manual mode
                        _displayedPrediction = null;
                      }
                    });
                  },
                  activeColor: Colors.white,
                  activeTrackColor: Colors.blue,
                  inactiveThumbColor: Colors.white70,
                  inactiveTrackColor: Colors.pink[300],
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                const SizedBox(width: 6),
                Text(
                  'Manual',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        _showManualTest ? FontWeight.bold : FontWeight.normal,
                    color: _showManualTest ? Colors.white : Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _showSettings = !_showSettings;
              });
            },
            icon: Icon(_showSettings ? Icons.close : Icons.settings),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: Consumer<ECGProvider>(
        builder: (context, ecgProvider, child) {
          return SingleChildScrollView(
            child: Column(
              children: [
                // Settings Panel
                if (_showSettings) _buildSettingsPanel(ecgProvider),

                // Manual Test Panel
                if (_showManualTest) _buildManualTestPanel(),

                // Connection Status (only show in live mode)
                if (!_showManualTest) _buildConnectionStatus(ecgProvider),

                // Control Buttons (only show in live mode)
                if (!_showManualTest) _buildControlButtons(ecgProvider),
                if (!_showManualTest) const SizedBox(height: 8),

                // ECG Chart - Use Container with fixed height instead of Expanded
                Container(
                  height: 300, // Fixed height instead of Expanded
                  child: _showManualTest
                      ? (_csvController.text.isNotEmpty
                          ? _buildManualTestChart()
                          : _buildEmptyManualChart())
                      : _buildLiveECGChart(ecgProvider),
                ),

                // Data Info with inline Predict Button
                _buildDataInfoWithPredict(ecgProvider),

                // Compact Prediction Result
                if (_displayedPrediction != null)
                  _buildCompactPredictionResult(_displayedPrediction!),

                // Add some bottom padding for better scrolling
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSettingsPanel(ECGProvider ecgProvider) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'NodeMCU ECG Monitor Settings',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: const Text(
              '📶 Instructions:\n'
              '1. Upload the ECG sensor code to your NodeMCU\n'
              '2. Connect to "ECG Monitor" WiFi (Password: 12341234)\n'
              '3. Use IP: 192.168.4.1 (default AP mode)\n'
              '4. Attach ECG electrodes before starting',
              style: TextStyle(fontSize: 12, color: Colors.blue),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _ipController,
                  decoration: const InputDecoration(
                    labelText: 'IP Address',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _portController,
                  decoration: const InputDecoration(
                    labelText: 'Port',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  style: const TextStyle(fontSize: 14),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  ecgProvider.setNodeMCUParameters(
                    _ipController.text.trim(),
                    int.tryParse(_portController.text) ?? 80,
                  );
                },
                icon: const Icon(Icons.save, size: 16),
                label: const Text('Save'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: ecgProvider.isLoading
                    ? null
                    : () async {
                        await ecgProvider.testNodeMCUConnection();
                      },
                icon: const Icon(Icons.wifi_find, size: 16),
                label: const Text('Test'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionStatus(ECGProvider ecgProvider) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ecgProvider.isConnectedToNodeMCU
            ? Colors.green[50]
            : Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: ecgProvider.isConnectedToNodeMCU ? Colors.green : Colors.red,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            ecgProvider.isConnectedToNodeMCU ? Icons.wifi : Icons.wifi_off,
            color: ecgProvider.isConnectedToNodeMCU ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ecgProvider.isConnectedToNodeMCU
                      ? 'Connected'
                      : 'Disconnected',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: ecgProvider.isConnectedToNodeMCU
                        ? Colors.green[700]
                        : Colors.red[700],
                  ),
                ),
                Text(
                  ecgProvider.nodeMCUStatus,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          if (ecgProvider.isRecordingLive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, color: Colors.white, size: 8),
                  SizedBox(width: 4),
                  Text(
                    'RECORDING',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildControlButtons(ECGProvider ecgProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // First row: Connect/Disconnect and Record/Stop
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: ecgProvider.isLoading
                      ? null
                      : ecgProvider.isConnectedToNodeMCU
                          ? () => ecgProvider.disconnectFromNodeMCU()
                          : () => ecgProvider.connectToNodeMCU(),
                  icon: Icon(
                    ecgProvider.isConnectedToNodeMCU ? Icons.close : Icons.wifi,
                    size: 18,
                  ),
                  label: Text(
                    ecgProvider.isConnectedToNodeMCU ? 'Disconnect' : 'Connect',
                    style: const TextStyle(fontSize: 14),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ecgProvider.isConnectedToNodeMCU
                        ? Colors.red
                        : const Color(0xFFE91E63),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: !ecgProvider.isConnectedToNodeMCU
                      ? null
                      : ecgProvider.isRecordingLive
                          ? () => ecgProvider.stopLiveRecording()
                          : () => ecgProvider.startLiveRecording(),
                  icon: Icon(
                    ecgProvider.isRecordingLive ? Icons.stop : Icons.play_arrow,
                    size: 18,
                  ),
                  label: Text(
                    ecgProvider.isRecordingLive ? 'Stop' : 'Record',
                    style: const TextStyle(fontSize: 14),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ecgProvider.isRecordingLive
                        ? Colors.orange
                        : Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),

          // Second row: Clear button (only show if there's data to clear)
          if (ecgProvider.liveECGData.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: ecgProvider.isRecordingLive
                    ? null // Disable while recording
                    : () => _clearLiveData(ecgProvider),
                icon: const Icon(Icons.clear_all, size: 18),
                label: const Text(
                  'Clear Chart & Reset',
                  style: TextStyle(fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLiveECGChart(ECGProvider ecgProvider) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Live ECG Signal',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ecgProvider.liveECGData.isEmpty
                ? _buildNoDataWidget()
                : LineChart(_buildLiveChartData(ecgProvider.liveECGData)),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDataWidget() {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.sensors_off_rounded,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 12),
              Text(
                'No ECG Data Available',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 4),
              Text(
                'Connect to ECG module and start recording to see live data.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Column(
                  children: [
                    const Text(
                      '🔧 Quick Setup:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '1. Connect your phone to the "ECG Monitor" WiFi network.\n'
                      '2. Tap the settings icon ⚙️ to confirm the IP address.\n'
                      '3. Press the "Connect" button to begin.',
                      style: TextStyle(fontSize: 12, color: Colors.orange[700]),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  LineChartData _buildLiveChartData(List<double> ecgData) {
    // Show last 200 points for real-time scrolling effect
    int displayPoints = ecgData.length > 200 ? 200 : ecgData.length;
    int startIndex = ecgData.length > 200 ? ecgData.length - 200 : 0;

    List<FlSpot> spots = [];
    for (int i = 0; i < displayPoints; i++) {
      spots.add(
        FlSpot(
          i.toDouble(),
          ecgData[startIndex + i] * 1000, // Scale for better visibility
        ),
      );
    }

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: true,
        drawHorizontalLine: true,
        horizontalInterval: 50,
        verticalInterval: 20,
        getDrawingHorizontalLine: (value) {
          return FlLine(color: Colors.grey.withOpacity(0.3), strokeWidth: 0.5);
        },
        getDrawingVerticalLine: (value) {
          return FlLine(color: Colors.grey.withOpacity(0.3), strokeWidth: 0.5);
        },
      ),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 35,
            getTitlesWidget: (value, meta) {
              return SizedBox(
                width: 35,
                height: 16,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value.toInt().toString(),
                    style: const TextStyle(fontSize: 8),
                  ),
                ),
              );
            },
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 20,
            getTitlesWidget: (value, meta) {
              return SizedBox(
                width: 25,
                height: 20,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value.toInt().toString(),
                    style: const TextStyle(fontSize: 8),
                  ),
                ),
              );
            },
          ),
        ),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: false,
          color: const Color(0xFFE91E63),
          barWidth: 1.5,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
        ),
      ],
      minX: 0,
      maxX: displayPoints.toDouble(),
    );
  }

  Widget _buildDataInfoWithPredict(ECGProvider ecgProvider) {
    // Calculate current analog reading (reverse the normalization)
    double currentAnalogReading = 0.0;
    if (ecgProvider.liveECGData.isNotEmpty) {
      double normalizedValue = ecgProvider.liveECGData.last;
      currentAnalogReading = (normalizedValue / 0.3) * 1024.0;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Data stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildInfoItem(
                'Data Points',
                '${ecgProvider.liveECGData.length}',
                Icons.data_usage,
              ),
              _buildInfoItem(
                'Heart Rate',
                _getCurrentBPMText(ecgProvider),
                Icons.favorite,
              ),
              _buildInfoItem(
                'Status',
                ecgProvider.isRecordingLive ? 'Recording' : 'Idle',
                ecgProvider.isRecordingLive
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
              ),
            ],
          ),

          // Predict button row
          if (ecgProvider.hasCollectedSufficientData) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: ecgProvider.isLoading
                        ? null
                        : () async {
                            // Get ECG data from live buffer or most recent reading
                            List<double> ecgData;
                            if (ecgProvider.liveECGData.length >= 187) {
                              ecgData =
                                  ecgProvider.liveECGData.take(187).toList();
                              debugPrint(
                                  'Live ECG Screen: Using live data for prediction (${ecgData.length} points)');
                            } else if (ecgProvider.readings.isNotEmpty) {
                              // Use the most recent reading if live data was cleared
                              ecgData = ecgProvider.readings.first.ecgData;
                              debugPrint(
                                  'Live ECG Screen: Using saved reading for prediction (${ecgData.length} points)');
                            } else {
                              debugPrint(
                                  'Live ECG Screen: No ECG data available for prediction');
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'No ECG data available for prediction'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            final tempReading = ECGReading(
                              id: 0,
                              userId: 0,
                              timestamp: DateTime.now(),
                              ecgData: ecgData,
                              duration: 10,
                            );

                            debugPrint(
                                'Live ECG Screen: Running prediction on ${ecgData.length} data points');
                            final prediction = await ecgProvider
                                .runPredictionOnReading(tempReading);
                            setState(() {
                              _displayedPrediction = prediction;
                            });

                            if (mounted && prediction != null) {
                              debugPrint(
                                  'Live ECG Screen: Prediction complete - ${prediction.predictionResult}');
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'Prediction complete! Result: ${prediction.predictionResult.toString().split('.').last}'),
                                  backgroundColor: Colors.blue,
                                  duration: const Duration(seconds: 3),
                                ),
                              );
                            } else {
                              debugPrint(
                                  'Live ECG Screen: Prediction failed or was null');
                            }
                          },
                    icon: ecgProvider.isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.psychology, size: 16),
                    label: Text(
                      ecgProvider.isLoading ? 'Analyzing...' : 'Run Prediction',
                      style: const TextStyle(fontSize: 14),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 16),
                    ),
                  ),
                ),
              ],
            ),
          ],

          // Export section - show when enabled and we have data to export
          if (_showExportSection &&
              (ecgProvider.liveECGData.isNotEmpty ||
                  ecgProvider.readings.isNotEmpty)) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            Row(
              children: [
                const Icon(Icons.file_download, size: 16, color: Colors.green),
                const SizedBox(width: 6),
                const Text(
                  'Export ECG Data',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Export buttons row
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await _exportECGDataToCSV(ecgProvider);
                    },
                    icon: const Icon(Icons.save_alt, size: 14),
                    label: const Text(
                      'Save CSV',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      List<double> dataToExport;
                      if (ecgProvider.liveECGData.isNotEmpty &&
                          ecgProvider.liveECGData.length >= 187) {
                        dataToExport =
                            ecgProvider.liveECGData.take(187).toList();
                      } else if (ecgProvider.readings.isNotEmpty) {
                        dataToExport = ecgProvider.readings.first.ecgData;
                      } else {
                        return;
                      }
                      await _copyECGDataToClipboard(dataToExport);
                    },
                    icon: const Icon(Icons.copy, size: 14),
                    label: const Text(
                      'Copy CSV',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      List<double> dataToExport;
                      if (ecgProvider.liveECGData.isNotEmpty &&
                          ecgProvider.liveECGData.length >= 187) {
                        dataToExport =
                            ecgProvider.liveECGData.take(187).toList();
                      } else if (ecgProvider.readings.isNotEmpty) {
                        dataToExport = ecgProvider.readings.first.ecgData;
                      } else {
                        return;
                      }
                      await _copyRawECGDataToClipboard(dataToExport);
                    },
                    icon: const Icon(Icons.content_copy, size: 14),
                    label: const Text(
                      'Copy Raw',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 12),
                    ),
                  ),
                ),
              ],
            ),

            // Export help text
            const SizedBox(height: 6),
            Text(
              'Save CSV: Exports formatted data to file | Copy CSV: Full format to clipboard | Copy Raw: Simple comma-separated values',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 18,
          color: const Color(0xFFE91E63),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildCompactPredictionResult(Prediction prediction) {
    // Get color based on prediction result
    Color resultColor = Colors.blue;
    IconData resultIcon = Icons.favorite;
    String riskAssessment = "Unknown Risk";
    bool isHighRisk = false;

    switch (prediction.predictionResult) {
      case PredictionResult.normal:
        resultColor = Colors.green;
        resultIcon = Icons.favorite;
        riskAssessment = "No Risk of Heart Attack";
        isHighRisk = false;
        break;
      case PredictionResult.arrhythmia:
      case PredictionResult.tachycardia:
      case PredictionResult.bradycardia:
        resultColor = Colors.orange;
        resultIcon = Icons.warning;
        riskAssessment = "Risk of Heart Attack";
        isHighRisk = true;
        break;
      case PredictionResult.unknown:
        resultColor = Colors.grey;
        resultIcon = Icons.help;
        riskAssessment = "Unable to Determine Risk";
        isHighRisk = false;
        break;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: resultColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: resultColor.withOpacity(0.3), width: 2),
      ),
      child: Column(
        children: [
          // Main prediction result
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: resultColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  resultIcon,
                  color: resultColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      prediction.predictionResult
                          .toString()
                          .split('.')
                          .last
                          .toUpperCase(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: resultColor,
                      ),
                    ),
                    Text(
                      'Confidence: ${(prediction.confidence * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 13,
                        color: resultColor.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _displayedPrediction = null;
                  });
                },
                icon: Icon(
                  Icons.close,
                  color: resultColor,
                  size: 20,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Risk Assessment - Prominent display
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isHighRisk
                  ? Colors.red.withOpacity(0.1)
                  : Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isHighRisk ? Colors.red : Colors.green,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isHighRisk
                      ? Icons.warning_rounded
                      : Icons.check_circle_rounded,
                  color: isHighRisk ? Colors.red : Colors.green,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Risk Assessment',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        riskAssessment,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color:
                              isHighRisk ? Colors.red[700] : Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Show detailed probabilities if available (helpful for manual testing)
          if (prediction.detailedResults != null &&
              prediction.detailedResults!.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.analytics, size: 16, color: resultColor),
                const SizedBox(width: 6),
                Text(
                  'Detailed Analysis',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: resultColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...prediction.detailedResults!.entries
                .where((entry) =>
                    (entry.value as double) * 100 >= 1) // Only show >= 1%
                .map(
                  (entry) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          entry.key.replaceAll('_', ' ').toUpperCase(),
                          style: const TextStyle(fontSize: 11),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: resultColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${((entry.value as double) * 100).toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: resultColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ],

          // Add timestamp for manual test results
          const SizedBox(height: 8),
          Text(
            'Analyzed: ${DateFormat('MMM dd, HH:mm:ss').format(prediction.createdAt)}',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[500],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  // Manual test methods
  List<double>? _parseCSVData(String csvText) {
    try {
      // Remove any whitespace and split by comma
      String cleanText = csvText.trim();
      if (cleanText.isEmpty) {
        return null;
      }

      // Split by comma and parse as doubles
      List<String> parts = cleanText.split(',');
      List<double> data = [];

      for (String part in parts) {
        double? value = double.tryParse(part.trim());
        if (value != null) {
          data.add(value);
        }
      }

      // Check if we have enough data points (need at least 187)
      if (data.length < 187) {
        // Show error in a post-frame callback to avoid build-time issues
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Not enough data: got ${data.length} values, need at least 187. Please provide more CSV data.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        });
        return null;
      }

      // If we have more than 187 points, silently truncate to first 187
      if (data.length > 187) {
        data = data.take(187).toList();
        // Silent truncation - no notification to avoid build-time errors
      }

      return data;
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error parsing CSV data: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }
  }

  Future<void> _runManualTest() async {
    if (_csvController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please paste CSV data first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isTestingManualData = true;
    });

    try {
      // Parse CSV data
      List<double>? ecgData = _parseCSVData(_csvController.text);
      if (ecgData == null) {
        return;
      }

      final ecgProvider = Provider.of<ECGProvider>(context, listen: false);

      // Get current user ID from the ECG provider
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.currentUser?.id ?? 0;

      // Create ECG reading with proper user ID and heart rate calculation
      final double heartRate = _calculateHeartRateFromData(ecgData);

      final ecgReading = ECGReading(
        userId: userId,
        timestamp: DateTime.now(),
        ecgData: ecgData,
        duration: 10,
        heartRate: heartRate,
        notes: 'Manual test with patient CSV data',
      );

      // Save the reading to database first
      await ecgProvider.addReading(ecgReading);

      // Get the saved reading (with proper ID) for prediction
      final savedReading = ecgProvider.readings.isNotEmpty
          ? ecgProvider.readings.first
          : ecgReading;

      // Run prediction on the saved reading
      final prediction = await ecgProvider.runPredictionOnReading(savedReading);

      setState(() {
        _displayedPrediction = prediction;
      });

      // Force refresh of readings to ensure dashboard updates
      if (userId > 0) {
        await ecgProvider.loadReadings(userId);
      }

      if (mounted && prediction != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Manual test complete! Result: ${prediction.predictionResult.toString().split('.').last}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error running manual test: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isTestingManualData = false;
      });
    }
  }

  // CSV Export methods
  String _formatECGDataAsCSV(List<double> ecgData,
      {bool includeTimestamp = true}) {
    final StringBuffer csvBuffer = StringBuffer();

    // Add header with timestamp if requested
    if (includeTimestamp) {
      final timestamp =
          DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
      csvBuffer.writeln('# ECG Data Export - $timestamp');
      csvBuffer.writeln('# Total Points: ${ecgData.length}');
      csvBuffer.writeln('# Sampling Rate: ~20Hz (estimated)');
      csvBuffer.writeln(
          '# Duration: ~${(ecgData.length / 20).toStringAsFixed(1)} seconds');
      csvBuffer.writeln('#');
    }

    // Add CSV header
    csvBuffer.writeln('Index,ECG_Value,Time_Seconds');

    // Add data points
    for (int i = 0; i < ecgData.length; i++) {
      final timeSeconds =
          (i / 20.0).toStringAsFixed(3); // Assuming 20Hz sampling
      csvBuffer.writeln('$i,${ecgData[i]},${timeSeconds}');
    }

    return csvBuffer.toString();
  }

  String _formatECGDataAsRawCSV(List<double> ecgData) {
    // Simple comma-separated format for easy import
    return ecgData.join(',');
  }

  Future<void> _exportECGDataToCSV(ECGProvider ecgProvider) async {
    try {
      List<double> dataToExport;
      String filename;

      // Determine what data to export
      if (ecgProvider.liveECGData.isNotEmpty &&
          ecgProvider.liveECGData.length >= 187) {
        dataToExport = ecgProvider.liveECGData.take(187).toList();
        filename =
            'live_ecg_data_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
      } else if (ecgProvider.readings.isNotEmpty) {
        dataToExport = ecgProvider.readings.first.ecgData;
        filename =
            'saved_ecg_data_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No ECG data available to export'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Format as CSV
      final csvContent = _formatECGDataAsCSV(dataToExport);

      // Try to save to file
      try {
        if (Platform.isAndroid || Platform.isIOS) {
          // Mobile platforms - save to Downloads or Documents
          Directory? directory;
          if (Platform.isAndroid) {
            directory = await getExternalStorageDirectory();
          } else {
            directory = await getApplicationDocumentsDirectory();
          }

          if (directory != null) {
            final file = File('${directory.path}/$filename');
            await file.writeAsString(csvContent);

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('ECG data exported to: ${file.path}'),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 4),
                  action: SnackBarAction(
                    label: 'Copy Path',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: file.path));
                    },
                  ),
                ),
              );
            }
          }
        } else {
          // Desktop platforms - save to user directory
          final directory = await getApplicationDocumentsDirectory();
          final file = File('${directory.path}/$filename');
          await file.writeAsString(csvContent);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('ECG data exported to: ${file.path}'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 4),
                action: SnackBarAction(
                  label: 'Copy Path',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: file.path));
                  },
                ),
              ),
            );
          }
        }
      } catch (fileError) {
        // If file saving fails, copy to clipboard as fallback
        debugPrint('File save failed: $fileError');
        await _copyECGDataToClipboard(dataToExport);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting ECG data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _copyECGDataToClipboard(List<double> ecgData) async {
    try {
      final csvContent = _formatECGDataAsCSV(ecgData);
      await Clipboard.setData(ClipboardData(text: csvContent));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ECG data copied to clipboard as CSV'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error copying to clipboard: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _copyRawECGDataToClipboard(List<double> ecgData) async {
    try {
      final rawCSV = _formatECGDataAsRawCSV(ecgData);
      await Clipboard.setData(ClipboardData(text: rawCSV));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Raw ECG data copied to clipboard (comma-separated)'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error copying to clipboard: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildManualTestPanel() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      constraints: const BoxConstraints(
        maxHeight: 280, // Constrain overall height
      ),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[300]!),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Compact header
            Row(
              children: [
                const Icon(Icons.science, color: Colors.blue, size: 18),
                const SizedBox(width: 6),
                const Text(
                  'Manual ECG Test',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    _csvController.text =
                        '0.977,0.926,0.681,0.245,0.154,0.056,0.067,0.049,0.054,0.037,0.022,0.064,0.021,0.037,0.037,0.033,0.034,0.043,0.034,0.033,0.028,0.028,0.036,0.033,0.025,0.032,0.033,0.031,0.031,0.035,0.029,0.031,0.033,0.033,0.032,0.034,0.031,0.034,0.033,0.031,0.031,0.031,0.032,0.032,0.032,0.031,0.031,0.032,0.032,0.031,0.031,0.032,0.032,0.031,0.031,0.031,0.032,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.031,0.000';
                  },
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                  ),
                  child: const Text(
                    'Sample',
                    style: TextStyle(fontSize: 11, color: Colors.blue),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Very compact instructions
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: const Text(
                '🔬 Paste comma-separated values below (need ≥187, extra values auto-truncated)',
                style: TextStyle(fontSize: 10, color: Colors.blue),
              ),
            ),
            const SizedBox(height: 8),

            // Compact CSV input
            Container(
              height: 80, // Fixed height instead of constraints
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
                color: Colors.white,
              ),
              child: TextField(
                controller: _csvController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  hintText: 'Paste CSV data...',
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 10),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(8),
                ),
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.black87,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Compact buttons
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 32,
                    child: ElevatedButton.icon(
                      onPressed: _isTestingManualData ? null : _runManualTest,
                      icon: _isTestingManualData
                          ? const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.play_arrow, size: 14),
                      label: Text(
                        _isTestingManualData ? 'Testing...' : 'Run Test',
                        style: const TextStyle(fontSize: 11),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 32,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _csvController.clear();
                        setState(() {
                          _displayedPrediction = null;
                        });
                      },
                      icon: const Icon(Icons.clear, size: 12),
                      label:
                          const Text('Clear', style: TextStyle(fontSize: 11)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManualTestChart() {
    List<double>? csvData = _parseCSVData(_csvController.text);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.science, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Manual Test ECG Data',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (csvData != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${csvData.length} points',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: csvData == null || csvData.isEmpty
                ? _buildManualTestNoDataWidget()
                : LineChart(_buildManualTestChartData(csvData)),
          ),
        ],
      ),
    );
  }

  Widget _buildManualTestNoDataWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.insert_chart_outlined,
            size: 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 12),
          Text(
            'No Valid CSV Data',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
          const SizedBox(height: 4),
          Text(
            'Paste comma-separated values in the text field above (need at least 187 values).',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  LineChartData _buildManualTestChartData(List<double> csvData) {
    List<FlSpot> spots = [];
    for (int i = 0; i < csvData.length; i++) {
      spots
          .add(FlSpot(i.toDouble(), csvData[i] * 1000)); // Scale for visibility
    }

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: true,
        drawHorizontalLine: true,
        horizontalInterval: 50,
        verticalInterval: 20,
        getDrawingHorizontalLine: (value) {
          return FlLine(color: Colors.grey.withOpacity(0.3), strokeWidth: 0.5);
        },
        getDrawingVerticalLine: (value) {
          return FlLine(color: Colors.grey.withOpacity(0.3), strokeWidth: 0.5);
        },
      ),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 35,
            getTitlesWidget: (value, meta) {
              return SizedBox(
                width: 35,
                height: 16,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value.toInt().toString(),
                    style: const TextStyle(fontSize: 8),
                  ),
                ),
              );
            },
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 20,
            interval: 30,
            getTitlesWidget: (value, meta) {
              return SizedBox(
                width: 25,
                height: 20,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value.toInt().toString(),
                    style: const TextStyle(fontSize: 8),
                  ),
                ),
              );
            },
          ),
        ),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: false,
          color: Colors.blue, // Different color for manual test
          barWidth: 1.5,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: Colors.blue.withOpacity(0.1),
          ),
        ),
      ],
      minX: 0,
      maxX: csvData.length.toDouble(),
    );
  }

  Widget _buildEmptyManualChart() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.science, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Manual Test ECG Data',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Waiting for data',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.file_upload_outlined,
                      size: 40,
                      color: Colors.blue[300],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Paste Patient\'s ECG Data (187 values)',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Calculate heart rate from ECG data using improved peak detection
  double _calculateHeartRateFromData(List<double> ecgData) {
    if (ecgData.length < 50) return 0.0;

    // Improved peak detection algorithm
    List<int> peaks = [];

    // Calculate adaptive threshold
    double mean = ecgData.reduce((a, b) => a + b) / ecgData.length;
    double maxVal = ecgData.reduce((a, b) => a > b ? a : b);
    double threshold = mean + (maxVal - mean) * 0.5;

    // Find peaks with better filtering
    for (int i = 3; i < ecgData.length - 3; i++) {
      if (ecgData[i] > ecgData[i - 1] &&
          ecgData[i] > ecgData[i + 1] &&
          ecgData[i] > ecgData[i - 2] &&
          ecgData[i] > ecgData[i + 2] &&
          ecgData[i] > ecgData[i - 3] &&
          ecgData[i] > ecgData[i + 3] &&
          ecgData[i] > threshold) {
        // For 187 samples representing ~10 seconds, normal HR peaks should be ~25-35 samples apart
        if (peaks.isEmpty || i - peaks.last > 25) {
          peaks.add(i);
        }
      }
    }

    if (peaks.length < 2) return 0.0;

    // Calculate RR intervals
    List<double> rrIntervals = [];
    for (int i = 1; i < peaks.length; i++) {
      rrIntervals.add((peaks[i] - peaks[i - 1]).toDouble());
    }

    // Remove outliers (too short/long intervals)
    rrIntervals.removeWhere((interval) => interval < 15 || interval > 80);

    if (rrIntervals.isEmpty) return 0.0;

    // Calculate average RR interval
    double avgRRInterval =
        rrIntervals.reduce((a, b) => a + b) / rrIntervals.length;

    // Assuming 187 samples = 10 seconds, so ~18.7 Hz sampling rate
    double samplesPerSecond = 18.7;
    double timeBetweenBeats = avgRRInterval / samplesPerSecond;
    double heartRate = 60.0 / timeBetweenBeats;

    // Alternative calculation if result seems unreasonable
    if (heartRate < 50 || heartRate > 150) {
      double dataTimeSeconds = ecgData.length / samplesPerSecond;
      double peaksPerSecond = peaks.length / dataTimeSeconds;
      double alternativeHR = peaksPerSecond * 60;

      if (alternativeHR >= 50 && alternativeHR <= 150) {
        heartRate = alternativeHR;
      }
    }

    // Apply correction factor for low BPM readings (below 50)
    if (heartRate < 50.0) {
      heartRate = heartRate * 1.7; // Multiply by 1.7 as correction factor
      debugPrint(
          'Manual Test: Applied 1.7x correction factor for low BPM. Original: ${(heartRate / 1.7).toStringAsFixed(1)}, Corrected: ${heartRate.toStringAsFixed(1)}');
    }

    // Return reasonable heart rate range
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
    double stdDev = (variance / ecgData.length).abs().round().toDouble();

    return mean + (stdDev * 0.5); // Use half standard deviation above mean
  }
}
