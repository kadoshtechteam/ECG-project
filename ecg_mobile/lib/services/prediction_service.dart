import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:ecg_mobile/models/prediction.dart';

class PredictionService {
  static const String _modelPath = 'assets/models/model.tflite';
  Interpreter? _interpreter;
  Future<void>? _loadModelFuture;

  PredictionService() {
    _loadModelFuture = _loadModel();
  }

  Future<void> _loadModel() async {
    try {
      // Load model with default options (no Flex delegate needed)
      final options = InterpreterOptions();
      _interpreter = await Interpreter.fromAsset(_modelPath, options: options);

      // Print input/output details for debugging
      debugPrint('Model loaded successfully');
      debugPrint('Input shape: ${_interpreter!.getInputTensor(0).shape}');
      debugPrint('Output shape: ${_interpreter!.getOutputTensor(0).shape}');
      debugPrint('Input type: ${_interpreter!.getInputTensor(0).type}');
      debugPrint('Output type: ${_interpreter!.getOutputTensor(0).type}');
    } catch (e) {
      debugPrint('Failed to load TensorFlow Lite model: $e');
      debugPrint('Model prediction features will be disabled.');
      _interpreter = null;
    }
  }

  Future<Prediction?> predict(List<double> ecgData, int readingId) async {
    // Ensure the model is loaded
    if (_interpreter == null) {
      await _loadModelFuture;
      if (_interpreter == null) {
        debugPrint('Interpreter initialization failed. Cannot predict.');
        return null;
      }
    }

    try {
      // Get input tensor info
      final inputTensor = _interpreter!.getInputTensor(0);
      final outputTensor = _interpreter!.getOutputTensor(0);
      final expectedLength = inputTensor.shape[1]; // Should be 187

      debugPrint('🔍 PREDICTION DEBUG START');
      debugPrint('Input tensor shape: ${inputTensor.shape}');
      debugPrint('Output tensor shape: ${outputTensor.shape}');
      debugPrint('📊 Input ECG data length: ${ecgData.length}');
      debugPrint('📊 Expected length: $expectedLength');

      // Ensure ECG data matches expected length (187)
      List<double> processedData = List.from(ecgData);

      if (processedData.length < expectedLength) {
        // Pad with zeros if too short
        while (processedData.length < expectedLength) {
          processedData.add(0.0);
        }
        debugPrint(
            '⚠️ Padded data from ${ecgData.length} to ${processedData.length}');
      } else if (processedData.length > expectedLength) {
        // Truncate if too long
        processedData = processedData.sublist(0, expectedLength);
        debugPrint(
            '⚠️ Truncated data from ${ecgData.length} to ${processedData.length}');
      }

      debugPrint(
          '📊 ECG data range: min=${processedData.reduce((a, b) => a < b ? a : b)}, max=${processedData.reduce((a, b) => a > b ? a : b)}');
      debugPrint(
          '📊 Raw ECG sample (first 10): ${processedData.take(10).toList()}');

      // Apply MinMaxScaler normalization (as used in training)
      // The training used: scaler = MinMaxScaler() which normalizes to [0,1] range
      debugPrint('🔢 Applying MinMaxScaler normalization (0-1 range)...');

      final minVal = processedData.reduce((a, b) => a < b ? a : b);
      final maxVal = processedData.reduce((a, b) => a > b ? a : b);
      final range = maxVal - minVal;

      debugPrint('🔢 MinMax stats: min=$minVal, max=$maxVal, range=$range');

      if (range > 0) {
        for (int i = 0; i < processedData.length; i++) {
          processedData[i] = (processedData[i] - minVal) / range;
        }
        debugPrint('✅ Applied MinMaxScaler normalization (0-1 range)');
      } else {
        debugPrint('⚠️ Range is 0, all values are the same');
        // Set all values to 0.5 (middle of 0-1 range) if no variation
        processedData = List.filled(expectedLength, 0.5);
      }

      debugPrint(
          '📊 Normalized sample (first 10): ${processedData.take(10).toList()}');

      // Create input tensor with proper shape [1, 187, 1] using Float32List
      debugPrint('🧠 Creating input tensor with shape: [1, 187, 1]');
      debugPrint('🧠 Processing ${processedData.length} ECG values');

      // Convert to Float32List for TensorFlow Lite compatibility
      final inputData = Float32List(1 * expectedLength * 1);
      for (int i = 0; i < expectedLength; i++) {
        inputData[i] = processedData[i];
      }

      // Reshape to [1, 187, 1] format as nested lists
      final input = [
        List.generate(expectedLength, (i) => [inputData[i]])
      ];

      debugPrint(
          '🧠 Input data sample (Float32): ${inputData.take(10).toList()}');

      // Create output tensor with proper shape [1, 5]
      final output = [List.filled(5, 0.0)];

      debugPrint('🧠 Running model inference...');

      // Run inference
      _interpreter!.run(input, output);

      debugPrint('🧠 Model inference completed');
      debugPrint('🧠 Raw model output: ${output[0]}');

      // Process the output - convert the first batch to Float32List
      final outputValues = Float32List.fromList(output[0].cast<double>());
      debugPrint('🔍 PREDICTION DEBUG END');

      final predictionResult = _processOutput(outputValues);

      return Prediction(
        id: DateTime.now().millisecondsSinceEpoch,
        readingId: readingId,
        predictionResult: predictionResult['result'],
        confidence: predictionResult['confidence'],
        createdAt: DateTime.now(),
        detailedResults: {
          'normal': predictionResult['probabilities'][0] +
              predictionResult['probabilities']
                  [4], // Combine Class 0 & 4 as Normal
          'arrhythmia': predictionResult['probabilities'][1],
          'tachycardia': predictionResult['probabilities'][2],
          'bradycardia': predictionResult['probabilities'][3],
        },
      );
    } catch (e) {
      debugPrint('Error during prediction: $e');
      debugPrint(
          'Prediction failed: Model not available or prediction returned null');
      return null;
    }
  }

  Map<String, dynamic> _processOutput(Float32List output) {
    debugPrint('🧮 Processing model output...');
    debugPrint('🧮 Raw output (5 classes): ${output.toList()}');

    // Apply softmax to get probabilities
    double sum = 0;
    final expOutput = Float32List(output.length);
    for (int i = 0; i < output.length; i++) {
      expOutput[i] = math.exp(output[i]);
      sum += expOutput[i];
    }

    debugPrint('🧮 After exp, sum: $sum');

    final probabilities = Float32List(output.length);
    for (int i = 0; i < output.length; i++) {
      probabilities[i] = expOutput[i] / sum;
    }

    debugPrint('🧮 Softmax probabilities: ${probabilities.toList()}');

    // Calculate combined probabilities for effective 4-class system
    final combinedNormal =
        probabilities[0] + probabilities[4]; // Class 0 + 4 = Normal
    final arrhythmia = probabilities[1];
    final tachycardia = probabilities[2];
    final bradycardia = probabilities[3];

    debugPrint('🧮 Combined probabilities:');
    debugPrint('   Normal (0+4): ${combinedNormal.toStringAsFixed(4)}');
    debugPrint('   Arrhythmia (1): ${arrhythmia.toStringAsFixed(4)}');
    debugPrint('   Tachycardia (2): ${tachycardia.toStringAsFixed(4)}');
    debugPrint('   Bradycardia (3): ${bradycardia.toStringAsFixed(4)}');

    // Find the highest combined probability
    double maxConfidence = combinedNormal;
    PredictionResult result = PredictionResult.normal;

    if (arrhythmia > maxConfidence) {
      maxConfidence = arrhythmia;
      result = PredictionResult.arrhythmia;
    }
    if (tachycardia > maxConfidence) {
      maxConfidence = tachycardia;
      result = PredictionResult.tachycardia;
    }
    if (bradycardia > maxConfidence) {
      maxConfidence = bradycardia;
      result = PredictionResult.bradycardia;
    }

    debugPrint(
        '🧮 Highest combined confidence: ${maxConfidence.toStringAsFixed(4)} for $result');

    debugPrint(
        '🧮 Final prediction: $result with confidence: ${(maxConfidence * 100).toStringAsFixed(1)}%');

    return {
      'result': result,
      'confidence': maxConfidence,
      'probabilities': probabilities.toList(),
    };
  }

  /// Test method to verify model loading and basic prediction functionality
  Future<bool> testModel() async {
    try {
      // Ensure model is loaded
      if (_interpreter == null) {
        await _loadModelFuture;
        if (_interpreter == null) {
          debugPrint('❌ Model test failed: Interpreter not available');
          return false;
        }
      }

      debugPrint('🧪 Testing model with sample ECG data...');

      // Create sample ECG data (187 points with realistic values)
      List<double> testData = List.generate(187, (i) {
        // Generate a simple sine wave with some variation
        double time = i / 187.0;
        return 0.1 +
            0.05 * math.sin(2 * math.pi * time * 5) +
            0.02 * math.sin(2 * math.pi * time * 20);
      });

      // Run prediction on test data
      final result = await predict(testData, 0);

      if (result != null) {
        debugPrint('✅ Model test successful!');
        debugPrint('   Result: ${result.predictionResult}');
        debugPrint(
            '   Confidence: ${(result.confidence * 100).toStringAsFixed(1)}%');
        return true;
      } else {
        debugPrint('❌ Model test failed: Prediction returned null');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Model test failed with error: $e');
      return false;
    }
  }

  void dispose() {
    _interpreter?.close();
  }
}
