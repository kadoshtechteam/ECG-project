import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/ecg_provider.dart';
import '../services/database_helper.dart';

class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  String _debugInfo = 'Loading debug information...';

  @override
  void initState() {
    super.initState();
    _loadDebugInfo();
  }

  Future<void> _loadDebugInfo() async {
    try {
      final StringBuffer info = StringBuffer();

      // Database path info
      Directory documentsDirectory = await getApplicationDocumentsDirectory();
      String dbPath = path.join(documentsDirectory.path, 'ecg_mobile.db');
      bool dbExists = await File(dbPath).exists();

      info.writeln('=== DATABASE INFO ===');
      info.writeln('Path: $dbPath');
      info.writeln('Exists: $dbExists');

      if (dbExists) {
        FileStat stat = await File(dbPath).stat();
        info.writeln('Size: ${stat.size} bytes');
        info.writeln('Modified: ${stat.modified}');
      }

      // Auth info - only access if widget is still mounted
      if (!mounted) return;

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      info.writeln('\n=== AUTH INFO ===');
      info.writeln('Logged in: ${authProvider.isLoggedIn}');
      if (authProvider.currentUser != null) {
        final user = authProvider.currentUser!;
        info.writeln('User ID: ${user.id}');
        info.writeln('Username: ${user.username}');
        info.writeln('Email: ${user.email}');
        info.writeln('Created: ${user.createdAt}');
      }

      // ECG data info
      final ecgProvider = Provider.of<ECGProvider>(context, listen: false);
      info.writeln('\n=== ECG DATA INFO ===');
      info.writeln('Total readings: ${ecgProvider.readings.length}');

      if (ecgProvider.readings.isNotEmpty) {
        info.writeln('Latest reading:');
        final latest = ecgProvider.readings.first;
        info.writeln('  ID: ${latest.id}');
        info.writeln('  Timestamp: ${latest.timestamp}');
        info.writeln('  Heart Rate: ${latest.heartRate}');
        info.writeln('  Data points: ${latest.ecgData.length}');
        info.writeln('  Notes: ${latest.notes}');
      }

      // Database statistics
      if (authProvider.currentUser != null) {
        final db = DatabaseHelper();
        int readingCount = await db.getECGReadingCount(
          authProvider.currentUser!.id!,
        );
        Map<String, int> predictionStats = await db.getPredictionStats(
          authProvider.currentUser!.id!,
        );

        info.writeln('\n=== DATABASE STATS ===');
        info.writeln('Reading count: $readingCount');
        info.writeln('Prediction stats: $predictionStats');
      }

      if (mounted) {
        setState(() {
          _debugInfo = info.toString();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _debugInfo = 'Error loading debug info: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Information'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _loadDebugInfo,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Text(
                    _debugInfo,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Clear All Data'),
                    content: const Text(
                      'This will delete all ECG readings and predictions. Are you sure?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () async {
                          final db = DatabaseHelper();
                          await db.clearAllData();
                          final ecgProvider = Provider.of<ECGProvider>(
                            context,
                            listen: false,
                          );
                          final authProvider = Provider.of<AuthProvider>(
                            context,
                            listen: false,
                          );
                          if (authProvider.currentUser != null) {
                            await ecgProvider.loadReadings(
                              authProvider.currentUser!.id!,
                            );
                          }
                          _loadDebugInfo();
                          Navigator.pop(context);
                        },
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.delete),
              label: const Text('Clear All Data'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 40),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
