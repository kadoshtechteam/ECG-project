import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/ecg_provider.dart';
import '../models/ecg_reading.dart';
import '../models/prediction.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
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
      ecgProvider.setCurrentUserId(authProvider.currentUser!.id!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(
              Icons.monitor_heart,
              color: Theme.of(context).colorScheme.primary,
              size: 28,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'MLHADP',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
                Text(
                  'AI Heart Monitor',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.7),
                      ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              return PopupMenuButton(
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'profile',
                    child: Row(
                      children: [
                        Icon(Icons.account_circle),
                        SizedBox(width: 8),
                        Text('Profile'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.exit_to_app),
                        SizedBox(width: 8),
                        Text('Logout'),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'logout') {
                    authProvider.logout();
                    Navigator.of(context).pushReplacementNamed('/login');
                  }
                },
              );
            },
          ),
        ],
      ),
      body: Consumer2<AuthProvider, ECGProvider>(
        builder: (context, authProvider, ecgProvider, child) {
          if (ecgProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome Card with Gradient
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.7),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.monitor_heart,
                              color: Theme.of(context).colorScheme.onPrimary,
                              size: 32,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Welcome, ${authProvider.currentUser?.username ?? 'User'}!',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onPrimary,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Your AI-powered heart health monitoring center',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onPrimary
                                              .withValues(alpha: 0.9),
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // BPM Display Card
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF48FB1).withValues(alpha: 0.08),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFF48FB1).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.favorite,
                            color: Color(0xFFF48FB1),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _calculateCurrentBPM(ecgProvider),
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: const Color(0xFFF48FB1),
                                          ),
                                    ),
                                  ),
                                  if (ecgProvider.isRecordingLive) ...[
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.red.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color:
                                              Colors.red.withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 6,
                                            height: 6,
                                            decoration: const BoxDecoration(
                                              color: Colors.red,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          const Text(
                                            'LIVE',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.red,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const Text(
                                'Current Heart Rate',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                ecgProvider.isRecordingLive
                                    ? 'Live monitoring in progress'
                                    : ecgProvider.persistedLiveHeartRate != null
                                        ? 'From last live test'
                                        : 'Real-time monitoring',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          ecgProvider.isRecordingLive
                              ? Icons.radio_button_checked
                              : Icons.trending_up,
                          color: ecgProvider.isRecordingLive
                              ? Colors.red
                              : Colors.green,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Latest ECG Chart
                _buildLatestECGChart(ecgProvider),
                const SizedBox(height: 12),

                // Action Buttons
                _buildActionButtons(),
                const SizedBox(height: 16),

                // Recent Readings List
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Readings',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                if (ecgProvider.readings.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFF8BBD9).withValues(alpha: 0.3),
                          const Color(0xFFE91E63).withValues(alpha: 0.1),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFE91E63).withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFE91E63,
                            ).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.monitor_heart_outlined,
                            size: 48,
                            color: const Color(0xFFE91E63),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Start Your Heart Health Journey',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFE91E63),
                                  ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No ECG readings yet. Generate sample data to explore AI-powered heart attack detection features.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                else
                  Column(
                    children: ecgProvider.readings
                        .take(5)
                        .map((reading) => _buildEnhancedReadingCard(reading))
                        .toList(),
                  ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showTestSelectionDialog(),
        label: const Text('Start Test'),
        icon: const Icon(Icons.play_arrow),
      ),
    );
  }

  Widget _buildLatestECGChart(ECGProvider ecgProvider) {
    final bool hasReadings = ecgProvider.readings.isNotEmpty;
    final bool hasLiveData = ecgProvider.liveECGData.isNotEmpty;

    // Get the most recent reading (including manual tests)
    ECGReading? latestReading;
    if (hasReadings) {
      final sortedReadings = List<ECGReading>.from(ecgProvider.readings);
      sortedReadings.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      latestReading = sortedReadings.first;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              hasLiveData
                  ? 'Live ECG Monitor'
                  : hasReadings
                      ? 'Latest ECG Reading'
                      : 'ECG Monitor',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            if (hasLiveData)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: ecgProvider.isRecordingLive
                      ? Colors.red.withValues(alpha: 0.1)
                      : Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      ecgProvider.isRecordingLive
                          ? Icons.fiber_manual_record
                          : Icons.monitor_heart,
                      size: 12,
                      color: ecgProvider.isRecordingLive
                          ? Colors.red
                          : Colors.green,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      ecgProvider.isRecordingLive ? 'LIVE' : 'DATA',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: ecgProvider.isRecordingLive
                            ? Colors.red
                            : Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                SizedBox(
                  height: 150,
                  child: hasLiveData
                      ? LineChart(_buildLiveECGChart(ecgProvider.liveECGData))
                      : hasReadings
                          ? LineChart(_buildECGChart(latestReading!))
                          : Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.show_chart_rounded,
                                    size: 40,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No ECG data available',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Start live monitoring to see real-time data',
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                ),
                const SizedBox(height: 6),
                if (hasLiveData)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Live data: ${ecgProvider.liveECGData.length} points',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontSize: 12,
                              color: Colors.blue[700],
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      if (ecgProvider.isRecordingLive)
                        Row(
                          children: [
                            SizedBox(
                              width: 8,
                              height: 8,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.red,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Recording...',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.red,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                    ],
                  )
                else
                  Text(
                    hasReadings && latestReading != null
                        ? 'Recorded: ${DateFormat('MMM dd, yyyy HH:mm').format(latestReading.timestamp)}'
                        : 'Start a test to see the chart',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 12,
                        ),
                  ),
              ],
            ),
          ),
        ),
        // Latest Prediction Result (from any source including manual tests)
        if (ecgProvider.lastPrediction != null) ...[
          const SizedBox(height: 16),
          _buildLatestPredictionCard(ecgProvider.lastPrediction!),
        ],
      ],
    );
  }

  LineChartData _buildLiveECGChart(List<double> liveData) {
    List<FlSpot> spots = [];
    for (int i = 0; i < liveData.length; i++) {
      spots.add(
        FlSpot(i.toDouble(), liveData[i] * 1000),
      ); // Scale for better visibility
    }

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: true,
        verticalInterval: 20,
        horizontalInterval: 200,
      ),
      titlesData: const FlTitlesData(show: false),
      borderData: FlBorderData(
        show: true,
        border: Border.all(color: Colors.grey, width: 0.5),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: false,
          color: const Color(0xFF2196F3), // Blue for live data
          barWidth: 1.5,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: const Color(0xFF2196F3).withValues(alpha: 0.1),
          ),
        ),
      ],
    );
  }

  Widget _buildLatestPredictionCard(Prediction prediction) {
    Color resultColor = Colors.blue;
    IconData resultIcon = Icons.favorite;

    switch (prediction.predictionResult) {
      case PredictionResult.normal:
        resultColor = Colors.green;
        resultIcon = Icons.favorite;
        break;
      case PredictionResult.arrhythmia:
        resultColor = Colors.orange;
        resultIcon = Icons.warning;
        break;
      case PredictionResult.tachycardia:
        resultColor = Colors.red;
        resultIcon = Icons.speed;
        break;
      case PredictionResult.bradycardia:
        resultColor = Colors.purple;
        resultIcon = Icons.slow_motion_video;
        break;
      case PredictionResult.unknown:
        resultColor = Colors.grey;
        resultIcon = Icons.help;
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Latest AI Analysis',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 6),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: resultColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        resultIcon,
                        color: resultColor,
                        size: 24,
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
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: resultColor,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${(prediction.confidence * 100).toStringAsFixed(1)}% confidence',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Colors.grey[600],
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Analyzed: ${DateFormat('MMM dd, HH:mm').format(prediction.createdAt)}',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey[500],
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (prediction.detailedResults != null &&
                    prediction.detailedResults!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Text(
                    'Detailed Analysis',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  ...prediction.detailedResults!.entries.map((entry) {
                    final percentage = ((entry.value as double) * 100);
                    if (percentage < 1) return const SizedBox.shrink();

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            entry.key.replaceAll('_', ' ').toUpperCase(),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Text(
                            '${percentage.toStringAsFixed(1)}%',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(title, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _buildReadingCard(ECGReading reading) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          Icons.monitor_heart,
          color: _getHeartRateColor(reading.heartRate ?? 0),
        ),
        title: Text(
          'Heart Rate: ${reading.heartRate?.toStringAsFixed(0) ?? 'N/A'} BPM',
        ),
        subtitle: Text(
          DateFormat('MMM dd, yyyy HH:mm').format(reading.timestamp),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          // TODO: Navigate to reading details
        },
      ),
    );
  }

  Widget _buildEnhancedReadingCard(ECGReading reading) {
    Color heartRateColor = _getHeartRateColor(reading.heartRate ?? 0);
    String riskLevel =
        (reading.heartRate ?? 0) < 60 || (reading.heartRate ?? 0) > 100
            ? 'High'
            : 'Normal';

    return GestureDetector(
      onTap: () {
        Navigator.of(context).pushNamed('/prediction');
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: heartRateColor.withValues(alpha: 0.1),
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
          ],
          border: Border.all(
            color: heartRateColor.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: heartRateColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.monitor_heart,
                      color: heartRateColor,
                      size: 14,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                '${reading.heartRate?.toStringAsFixed(0) ?? 'N/A'} BPM',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: heartRateColor,
                                      fontSize: 13,
                                    ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 3,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: riskLevel == 'Normal'
                                    ? Colors.green.withValues(alpha: 0.1)
                                    : Colors.orange.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                riskLevel,
                                style: TextStyle(
                                  color: riskLevel == 'Normal'
                                      ? Colors.green
                                      : Colors.orange,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 1),
                        Text(
                          DateFormat(
                            'MMM dd • HH:mm',
                          ).format(reading.timestamp),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.grey[600], fontSize: 10),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: Colors.grey[400], size: 14),
                ],
              ),
              const SizedBox(height: 3),
              // Enhanced ECG preview
              Container(
                height: 30,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: heartRateColor.withValues(alpha: 0.2),
                    width: 0.5,
                  ),
                ),
                child: Stack(
                  children: [
                    CustomPaint(
                      painter: MiniECGPainter(
                        reading.ecgData.take(40).toList(),
                        heartRateColor,
                      ),
                      size: Size.infinite,
                    ),
                    Positioned(
                      bottom: 1,
                      right: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 2,
                          vertical: 0.5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: Text(
                          '${reading.ecgData.length} pts',
                          style: TextStyle(
                            fontSize: 7,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
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

  LineChartData _buildECGChart(ECGReading reading) {
    List<FlSpot> spots = [];
    for (int i = 0; i < reading.ecgData.length; i++) {
      spots.add(
        FlSpot(i.toDouble(), reading.ecgData[i] * 1000),
      ); // Scale for better visibility
    }

    return LineChartData(
      gridData: const FlGridData(show: false),
      titlesData: const FlTitlesData(show: false),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: false,
          color: const Color(0xFFE91E63),
          barWidth: 1,
          dotData: const FlDotData(show: false),
        ),
      ],
    );
  }

  String _calculateAverageHeartRate(List<ECGReading> readings) {
    if (readings.isEmpty) return '0 BPM';

    double total = 0;
    int count = 0;

    for (var reading in readings) {
      if (reading.heartRate != null) {
        total += reading.heartRate!;
        count++;
      }
    }

    if (count == 0) return '0 BPM';
    return '${(total / count).toStringAsFixed(0)} BPM';
  }

  Color _getHeartRateColor(double heartRate) {
    if (heartRate < 60) return const Color(0xFF9C27B0); // Bradycardia - Purple
    if (heartRate > 100) return const Color(0xFFE91E63); // Tachycardia - Pink
    return const Color(0xFF4CAF50); // Normal - Green
  }

  // Enhanced stat card with more visual appeal
  Widget _buildEnhancedStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String subtitle,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(icon, color: color, size: 12),
                ),
                const Spacer(),
                Icon(Icons.trending_up, color: Colors.green, size: 8),
              ],
            ),
            const SizedBox(height: 2),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: color,
                        fontSize: 14,
                      ),
                ),
              ),
            ),
            Flexible(
              child: Text(
                title,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Flexible(
              child: Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                      fontSize: 8,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Quick stat widget for welcome card
  Widget _buildQuickStat(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.onPrimary, size: 16),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onPrimary.withValues(alpha: 0.8),
                  ),
            ),
          ],
        ),
      ],
    );
  }

  // Calculate health score based on readings
  int _calculateHealthScore(List<ECGReading> readings) {
    if (readings.isEmpty) return 85; // Default good score

    double totalScore = 0;
    int validReadings = 0;

    for (var reading in readings) {
      if (reading.heartRate != null) {
        double hr = reading.heartRate!;
        double score = 100;

        // Deduct points for abnormal heart rates
        if (hr < 60 || hr > 100) {
          score -= 20;
        }
        if (hr < 50 || hr > 120) {
          score -= 30;
        }

        totalScore += score;
        validReadings++;
      }
    }

    return validReadings > 0 ? (totalScore / validReadings).round() : 85;
  }

  // Calculate risk level
  String _calculateRiskLevel(List<ECGReading> readings) {
    if (readings.isEmpty) return 'Low';

    int abnormalCount = 0;
    for (var reading in readings) {
      if (reading.heartRate != null) {
        double hr = reading.heartRate!;
        if (hr < 60 || hr > 100) abnormalCount++;
      }
    }

    double abnormalRatio = abnormalCount / readings.length;
    if (abnormalRatio > 0.5) return 'High';
    if (abnormalRatio > 0.2) return 'Medium';
    return 'Low';
  }

  // Get last reading time
  String _getLastReadingTime(List<ECGReading> readings) {
    if (readings.isEmpty) return 'Never';

    DateTime now = DateTime.now();
    Duration diff = now.difference(readings.first.timestamp);

    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _showTestSelectionDialog(),
            icon: const Icon(Icons.play_arrow, size: 18),
            label: const Text(
              'Start Test',
              style: TextStyle(fontSize: 14),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.secondary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  // Calculate current BPM from live data or latest reading
  String _calculateCurrentBPM(ECGProvider ecgProvider) {
    // Priority 1: If currently recording live, show live BPM
    if (ecgProvider.isRecordingLive) {
      if (ecgProvider.liveECGData.length < 50) {
        return 'Starting...';
      }
      final liveHeartRate = ecgProvider.getCurrentLiveHeartRate();
      if (liveHeartRate != null && liveHeartRate > 0) {
        return '${liveHeartRate.round()} BPM (Live)';
      }
      return 'Calculating...';
    }

    // Priority 2: If we have persisted live heart rate (from stopped live test), show it
    final persistedHeartRate = ecgProvider.persistedLiveHeartRate;
    if (persistedHeartRate != null && persistedHeartRate > 0) {
      return '${persistedHeartRate.round()} BPM (Last Live)';
    }

    // Priority 3: If there's current live data but not recording, calculate from it
    if (ecgProvider.liveECGData.isNotEmpty) {
      final liveHeartRate = ecgProvider.getCurrentLiveHeartRate();
      if (liveHeartRate != null && liveHeartRate > 0) {
        return '${liveHeartRate.round()} BPM (Live Data)';
      }
    }

    // Priority 4: Use the most recent reading's heart rate (including manual tests)
    if (ecgProvider.readings.isNotEmpty) {
      // Sort readings by timestamp to get the most recent
      final sortedReadings = List<ECGReading>.from(ecgProvider.readings);
      sortedReadings.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      final latestReading = sortedReadings.first;
      if (latestReading.heartRate != null) {
        return '${latestReading.heartRate!.round()} BPM';
      }
    }

    // Priority 5: Calculate average from all readings
    if (ecgProvider.readings.isNotEmpty) {
      double total = 0;
      int count = 0;
      for (var reading in ecgProvider.readings) {
        if (reading.heartRate != null) {
          total += reading.heartRate!;
          count++;
        }
      }
      if (count > 0) {
        return '${(total / count).round()} BPM (Avg)';
      }
    }

    // Default when no data
    return '-- BPM';
  }

  // Show test selection dialog
  void _showTestSelectionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFFE91E63).withValues(alpha: 0.1),
                  const Color(0xFF2196F3).withValues(alpha: 0.1),
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE91E63).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.monitor_heart,
                    size: 40,
                    color: Color(0xFFE91E63),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Choose Test Type',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFE91E63),
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Select how you want to perform your ECG test',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Live Test Card
                _buildTestOptionCard(
                  title: 'Live Test',
                  subtitle: 'Real-time ECG monitoring with Module',
                  icon: Icons.sensors,
                  color: const Color(0xFFE91E63),
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pushNamed('/live_ecg');
                  },
                ),
                const SizedBox(height: 16),

                // Manual Test Card
                _buildTestOptionCard(
                  title: 'Manual Test',
                  subtitle: 'Test with Patient\'s External CSV Data',
                  icon: Icons.science,
                  color: const Color(0xFF2196F3),
                  onTap: () {
                    Navigator.of(context).pop();
                    // Navigate to live_ecg screen in manual mode
                    Navigator.of(context).pushNamed('/live_ecg',
                        arguments: {'startInManualMode': true});
                  },
                ),
                const SizedBox(height: 20),

                // Cancel Button
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Build test option card
  Widget _buildTestOptionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: color,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

// Custom painter for mini ECG preview
class MiniECGPainter extends CustomPainter {
  final List<double> data;
  final Color color;

  MiniECGPainter(this.data, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty || size.width <= 0 || size.height <= 0) return;

    // Draw grid lines (simplified for small size)
    final gridPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.15) // More subtle
      ..strokeWidth = 0.3 // Thinner for small height
      ..style = PaintingStyle.stroke;

    // Draw only 1 horizontal grid line for 30px height
    final y = size.height / 2;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);

    // Draw fewer vertical grid lines
    for (int i = 1; i < 5; i++) {
      final x = (size.width / 5) * i;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    // Draw ECG line
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5 // Reduced from 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();

    // Ensure we have valid data
    if (data.length < 2) return;

    final double stepX = size.width / (data.length - 1);

    // Find min/max for proper scaling with bounds checking
    double maxY = data.first;
    double minY = data.first;

    for (double value in data) {
      if (value > maxY) maxY = value;
      if (value < minY) minY = value;
    }

    final double rangeY = maxY - minY == 0 ? 1.0 : maxY - minY;

    // Increased padding for smaller height
    final double padding = size.height * 0.25; // Increased for 30px height

    for (int i = 0; i < data.length; i++) {
      final double x = i * stepX;
      final double normalizedY = (data[i] - minY) / rangeY;
      final double y =
          size.height - padding - (normalizedY * (size.height - 2 * padding));

      // Strict clamping to prevent any overflow
      final double clampedY = y.clamp(padding, size.height - padding);

      if (i == 0) {
        path.moveTo(x, clampedY);
      } else {
        path.lineTo(x, clampedY);
      }
    }

    canvas.drawPath(path, paint);

    // Draw baseline indicator (more subtle for small size)
    final baselinePaint = Paint()
      ..color = color.withValues(alpha: 0.2) // More subtle
      ..strokeWidth = 0.5 // Thinner
      ..style = PaintingStyle.stroke;

    final baselineY =
        size.height - padding - (0.5 * (size.height - 2 * padding));
    canvas.drawLine(
      Offset(0, baselineY),
      Offset(size.width, baselineY),
      baselinePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is! MiniECGPainter ||
        oldDelegate.data != data ||
        oldDelegate.color != color;
  }
}
