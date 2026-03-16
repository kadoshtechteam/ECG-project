import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/ecg_provider.dart';
import '../models/ecg_reading.dart';
import '../models/prediction.dart';

class PredictionScreen extends StatefulWidget {
  const PredictionScreen({super.key});

  @override
  State<PredictionScreen> createState() => _PredictionScreenState();
}

class _PredictionScreenState extends State<PredictionScreen> {
  ECGReading? selectedReading;
  Prediction? currentPrediction;
  bool isAnalyzing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final ecgProvider = Provider.of<ECGProvider>(context, listen: false);

    if (authProvider.currentUser != null) {
      ecgProvider.loadReadings(authProvider.currentUser!.id!);
    }
  }

  Future<void> _runPrediction(ECGReading reading) async {
    setState(() {
      isAnalyzing = true;
      selectedReading = reading;
      currentPrediction = null;
    });

    try {
      await Future.delayed(const Duration(seconds: 2));
      final prediction = _generateDummyPrediction(reading);

      setState(() {
        currentPrediction = prediction;
        isAnalyzing = false;
      });
    } catch (e) {
      setState(() {
        isAnalyzing = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error during prediction: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Prediction _generateDummyPrediction(ECGReading reading) {
    final heartRate = reading.heartRate ?? 75;

    PredictionResult result;
    double confidence;
    Map<String, double> detailedResults;

    if (heartRate > 100) {
      result = PredictionResult.tachycardia;
      confidence = 0.85 + (heartRate - 100) / 500;
      detailedResults = {
        'normal': 0.10,
        'arrhythmia': 0.15,
        'tachycardia': confidence,
        'bradycardia': 0.05,
        'heart_attack': 0.10,
      };
    } else if (heartRate < 60) {
      result = PredictionResult.bradycardia;
      confidence = 0.80 + (60 - heartRate) / 200;
      detailedResults = {
        'normal': 0.15,
        'arrhythmia': 0.10,
        'tachycardia': 0.05,
        'bradycardia': confidence,
        'heart_attack': 0.10,
      };
    } else {
      result = PredictionResult.normal;
      confidence = 0.90 - (heartRate - 75).abs() / 100;
      detailedResults = {
        'normal': confidence,
        'arrhythmia': 0.05,
        'tachycardia': 0.05,
        'bradycardia': 0.05,
        'heart_attack': 0.02,
      };
    }

    return Prediction(
      readingId: reading.id!,
      predictionResult: result,
      confidence: confidence.clamp(0.5, 0.99),
      createdAt: DateTime.now(),
      detailedResults: detailedResults,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Prediction Center'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Consumer2<AuthProvider, ECGProvider>(
        builder: (context, authProvider, ecgProvider, child) {
          if (ecgProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (ecgProvider.readings.isEmpty) {
            return _buildEmptyState();
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.psychology, color: Colors.white, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AI-Powered Analysis',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Select an ECG reading below to get AI prediction results',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  'Select ECG Reading for Analysis',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                _buildReadingsTable(ecgProvider.readings),

                const SizedBox(height: 24),

                if (selectedReading != null) ...[
                  Text(
                    'Analysis Results',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildPredictionResults(),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.monitor_heart_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              'No ECG Readings Available',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Generate some ECG readings from the dashboard first to use the AI prediction feature.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to Dashboard'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadingsTable(List<ECGReading> readings) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'Date & Time',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Heart Rate',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Action',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...readings.map((reading) {
            final isSelected = selectedReading?.id == reading.id;

            return Container(
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                    : null,
                border: Border(
                  bottom: BorderSide(color: Colors.grey[200]!, width: 1),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat(
                              'MMM dd, yyyy',
                            ).format(reading.timestamp),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            DateFormat('HH:mm:ss').format(reading.timestamp),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            Icons.favorite,
                            size: 16,
                            color: _getHeartRateColor(reading.heartRate ?? 0),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${reading.heartRate?.toStringAsFixed(0) ?? 'N/A'} BPM',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: _getHeartRateColor(
                                    reading.heartRate ?? 0,
                                  ),
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: ElevatedButton.icon(
                          onPressed: isAnalyzing
                              ? null
                              : () => _runPrediction(reading),
                          icon: isAnalyzing && isSelected
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Icon(Icons.psychology, size: 16),
                          label: Text(
                            isAnalyzing && isSelected
                                ? 'Analyzing...'
                                : 'Predict',
                            style: const TextStyle(fontSize: 12),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.secondary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            minimumSize: const Size(80, 32),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildPredictionResults() {
    if (isAnalyzing) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'AI is analyzing your ECG reading...',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'This may take a few seconds',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    if (currentPrediction == null) {
      return Container();
    }

    final resultInfo = _getPredictionResultInfo(
      currentPrediction!.predictionResult,
    );

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: resultInfo['color'].withOpacity(0.3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: resultInfo['color'].withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: resultInfo['color'].withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  resultInfo['icon'],
                  size: 48,
                  color: resultInfo['color'],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                resultInfo['title'],
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: resultInfo['color'],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Confidence: ${(currentPrediction!.confidence * 100).toStringAsFixed(1)}%',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: Colors.grey[700]),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  resultInfo['description'],
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Detailed Analysis',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ...currentPrediction!.detailedResults?.entries.map((entry) {
                    final categoryName = _formatCategoryName(entry.key);
                    final probability = entry.value;
                    final color = _getCategoryColor(entry.key);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                categoryName,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                '${(probability * 100).toStringAsFixed(1)}%',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: color,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: probability,
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                          ),
                        ],
                      ),
                    );
                  }).toList() ??
                  [],
            ],
          ),
        ),
      ],
    );
  }

  Map<String, dynamic> _getPredictionResultInfo(PredictionResult result) {
    switch (result) {
      case PredictionResult.normal:
        return {
          'title': 'Normal Heart Rhythm',
          'icon': Icons.favorite,
          'color': Colors.green,
          'description':
              'Your ECG shows a normal heart rhythm. No immediate concerns detected.',
        };
      case PredictionResult.arrhythmia:
        return {
          'title': 'Arrhythmia Detected',
          'icon': Icons.warning,
          'color': Colors.orange,
          'description':
              'Irregular heart rhythm detected. Consider consulting with a healthcare provider.',
        };
      case PredictionResult.tachycardia:
        return {
          'title': 'Tachycardia Detected',
          'icon': Icons.speed,
          'color': Colors.red,
          'description':
              'Fast heart rate detected. Monitor your condition and consult a doctor if symptoms persist.',
        };
      case PredictionResult.bradycardia:
        return {
          'title': 'Bradycardia Detected',
          'icon': Icons.slow_motion_video,
          'color': Colors.blue,
          'description':
              'Slow heart rate detected. This may be normal for athletes or may require medical attention.',
        };
      case PredictionResult.unknown:
      default:
        return {
          'title': 'Unknown Result',
          'icon': Icons.help_outline,
          'color': Colors.grey,
          'description':
              'Unable to determine result. Please try again or consult a healthcare provider.',
        };
    }
  }

  String _formatCategoryName(String category) {
    switch (category) {
      case 'normal':
        return 'Normal';
      case 'arrhythmia':
        return 'Arrhythmia';
      case 'tachycardia':
        return 'Tachycardia';
      case 'bradycardia':
        return 'Bradycardia';
      case 'heart_attack':
        return 'Heart Attack Risk';
      default:
        return category;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'normal':
        return Colors.green;
      case 'arrhythmia':
        return Colors.orange;
      case 'tachycardia':
        return Colors.red;
      case 'bradycardia':
        return Colors.blue;
      case 'heart_attack':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Color _getHeartRateColor(double heartRate) {
    if (heartRate < 60) return Colors.blue;
    if (heartRate > 100) return Colors.red;
    return Colors.green;
  }
}
