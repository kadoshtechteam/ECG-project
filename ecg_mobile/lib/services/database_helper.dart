import 'dart:async';
import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';

import '../models/user.dart';
import '../models/ecg_reading.dart';
import '../models/prediction.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // Public method to initialize database early
  Future<void> initialize() async {
    try {
      print('Initializing database...');
      await database; // This will trigger database creation if needed
      print('Database initialization completed');
    } catch (e) {
      print('Failed to initialize database: $e');
      rethrow;
    }
  }

  Future<Database> _initDatabase() async {
    try {
      Directory documentsDirectory = await getApplicationDocumentsDirectory();
      String path = join(documentsDirectory.path, 'ecg_mobile.db');

      // Debug: Print database path for verification
      print('ECG Database path: $path');
      print('Database exists: ${await File(path).exists()}');

      Database db = await openDatabase(
        path,
        version: 1,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );

      print('Database initialized successfully');
      return db;
    } catch (e) {
      print('Error initializing database: $e');
      rethrow;
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    try {
      print('Creating database tables...');

      // Create users table
      await db.execute('''
        CREATE TABLE users (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          username TEXT UNIQUE NOT NULL,
          email TEXT UNIQUE NOT NULL,
          password_hash TEXT NOT NULL,
          created_at INTEGER NOT NULL
        )
      ''');

      // Create ecg_readings table
      await db.execute('''
        CREATE TABLE ecg_readings (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id INTEGER NOT NULL,
          timestamp INTEGER NOT NULL,
          ecg_data TEXT NOT NULL,
          duration INTEGER NOT NULL,
          heart_rate REAL,
          notes TEXT,
          FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
        )
      ''');

      // Create predictions table
      await db.execute('''
        CREATE TABLE predictions (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          reading_id INTEGER NOT NULL,
          prediction_result TEXT NOT NULL,
          confidence REAL NOT NULL,
          created_at INTEGER NOT NULL,
          detailed_results TEXT,
          FOREIGN KEY (reading_id) REFERENCES ecg_readings (id) ON DELETE CASCADE
        )
      ''');

      // Create indexes for better performance
      await db.execute('''
        CREATE INDEX idx_ecg_readings_user_id ON ecg_readings(user_id)
      ''');

      await db.execute('''
        CREATE INDEX idx_ecg_readings_timestamp ON ecg_readings(timestamp)
      ''');

      await db.execute('''
        CREATE INDEX idx_predictions_reading_id ON predictions(reading_id)
      ''');

      print('Database tables created successfully');
    } catch (e) {
      print('Error creating database tables: $e');
      rethrow;
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle database schema upgrades here
    if (oldVersion < newVersion) {
      // Add migration logic here when needed
    }
  }

  // User CRUD Operations
  Future<int> insertUser(User user) async {
    final db = await database;
    return await db.insert('users', user.toMap());
  }

  Future<User?> getUserById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  Future<User?> getUserByUsername(String username) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: [username],
    );

    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  Future<User?> getUserByEmail(String email) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
    );

    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  Future<int> updateUser(User user) async {
    final db = await database;
    return await db.update(
      'users',
      user.toMap(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  Future<int> deleteUser(int id) async {
    final db = await database;
    return await db.delete('users', where: 'id = ?', whereArgs: [id]);
  }

  // ECG Reading CRUD Operations
  Future<int> insertECGReading(ECGReading reading) async {
    final db = await database;
    return await db.insert('ecg_readings', reading.toMap());
  }

  Future<ECGReading?> getECGReadingById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'ecg_readings',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return ECGReading.fromMap(maps.first);
    }
    return null;
  }

  Future<List<ECGReading>> getECGReadingsByUserId(
    int userId, {
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'ecg_readings',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'timestamp DESC',
      limit: limit,
      offset: offset,
    );

    return List.generate(maps.length, (i) {
      return ECGReading.fromMap(maps[i]);
    });
  }

  Future<List<ECGReading>> getAllECGReadings({int? limit, int? offset}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'ecg_readings',
      orderBy: 'timestamp DESC',
      limit: limit,
      offset: offset,
    );

    return List.generate(maps.length, (i) {
      return ECGReading.fromMap(maps[i]);
    });
  }

  Future<int> updateECGReading(ECGReading reading) async {
    final db = await database;
    return await db.update(
      'ecg_readings',
      reading.toMap(),
      where: 'id = ?',
      whereArgs: [reading.id],
    );
  }

  Future<int> deleteECGReading(int id) async {
    final db = await database;
    return await db.delete('ecg_readings', where: 'id = ?', whereArgs: [id]);
  }

  // Prediction CRUD Operations
  Future<int> insertPrediction(Prediction prediction) async {
    final db = await database;
    return await db.insert('predictions', prediction.toMap());
  }

  Future<Prediction?> getPredictionById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'predictions',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Prediction.fromMap(maps.first);
    }
    return null;
  }

  Future<List<Prediction>> getPredictionsByReadingId(int readingId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'predictions',
      where: 'reading_id = ?',
      whereArgs: [readingId],
      orderBy: 'created_at DESC',
    );

    return List.generate(maps.length, (i) {
      return Prediction.fromMap(maps[i]);
    });
  }

  Future<int> updatePrediction(Prediction prediction) async {
    final db = await database;
    return await db.update(
      'predictions',
      prediction.toMap(),
      where: 'id = ?',
      whereArgs: [prediction.id],
    );
  }

  Future<int> deletePrediction(int id) async {
    final db = await database;
    return await db.delete('predictions', where: 'id = ?', whereArgs: [id]);
  }

  // Utility Methods
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('predictions');
    await db.delete('ecg_readings');
    await db.delete('users');
  }

  Future<void> close() async {
    final db = await database;
    db.close();
  }

  // Statistics and Analytics
  Future<int> getECGReadingCount(int userId) async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ecg_readings WHERE user_id = ?',
      [userId],
    );
    return result.first['count'] as int;
  }

  Future<Map<String, int>> getPredictionStats(int userId) async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.rawQuery(
      '''
      SELECT p.prediction_result, COUNT(*) as count
      FROM predictions p
      INNER JOIN ecg_readings e ON p.reading_id = e.id
      WHERE e.user_id = ?
      GROUP BY p.prediction_result
    ''',
      [userId],
    );

    Map<String, int> stats = {};
    for (var row in result) {
      stats[row['prediction_result']] = row['count'] as int;
    }
    return stats;
  }
}
