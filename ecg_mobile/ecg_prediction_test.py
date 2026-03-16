#!/usr/bin/env python3
"""
ECG Prediction Test Script
==========================

This script allows you to test the ECG TensorFlow Lite model with CSV data.
It processes the input data the same way as the Flutter app and makes predictions.

Usage:
    python ecg_prediction_test.py

Requirements:
    pip install tensorflow numpy pandas
"""

import tensorflow as tf
import numpy as np
import csv
import sys
import os
from typing import List, Dict, Any

class ECGPredictor:
    def __init__(self, model_path: str):
        """Initialize the ECG predictor with the TensorFlow Lite model."""
        self.model_path = model_path
        self.interpreter = None
        self.input_details = None
        self.output_details = None
        self.class_names = [
            "Normal",
            "Arrhythmia Type 1", 
            "Tachycardia",
            "Bradycardia",
            "Normal"  # Class 4 also maps to Normal
        ]
        self.load_model()
    
    def load_model(self):
        """Load the TensorFlow Lite model."""
        try:
            # Load TFLite model and allocate tensors
            self.interpreter = tf.lite.Interpreter(model_path=self.model_path)
            self.interpreter.allocate_tensors()
            
            # Get input and output tensors
            self.input_details = self.interpreter.get_input_details()
            self.output_details = self.interpreter.get_output_details()
            
            print("✅ Model loaded successfully!")
            print(f"📊 Input shape: {self.input_details[0]['shape']}")
            print(f"📊 Output shape: {self.output_details[0]['shape']}")
            print(f"📊 Input type: {self.input_details[0]['dtype']}")
            print(f"📊 Output type: {self.output_details[0]['dtype']}")
            
        except Exception as e:
            print(f"❌ Failed to load model: {e}")
            sys.exit(1)
    
    def preprocess_data(self, ecg_data: List[float]) -> np.ndarray:
        """Preprocess ECG data using MinMaxScaler normalization (0-1 range)."""
        data = np.array(ecg_data, dtype=np.float32)
        
        # Expected length is 187
        expected_length = self.input_details[0]['shape'][1]  # Should be 187
        
        print(f"📊 Input data length: {len(data)}")
        print(f"📊 Expected length: {expected_length}")
        
        # Ensure data has correct length
        if len(data) < expected_length:
            # Pad with zeros if too short
            padding = expected_length - len(data)
            data = np.pad(data, (0, padding), mode='constant', constant_values=0)
            print(f"⚠️ Padded data with {padding} zeros")
        elif len(data) > expected_length:
            # Truncate if too long
            data = data[:expected_length]
            print(f"⚠️ Truncated data to {expected_length} points")
        
        print(f"📊 Raw data sample (first 10): {data[:10].tolist()}")
        
        # Apply MinMaxScaler normalization (0-1 range)
        min_val = np.min(data)
        max_val = np.max(data)
        data_range = max_val - min_val
        
        print(f"🔢 MinMax stats: min={min_val:.6f}, max={max_val:.6f}, range={data_range:.6f}")
        
        if data_range > 0:
            normalized_data = (data - min_val) / data_range
            print("✅ Applied MinMaxScaler normalization (0-1 range)")
        else:
            print("⚠️ Range is 0, all values are the same")
            normalized_data = np.full(expected_length, 0.5)  # Middle of 0-1 range
        
        print(f"📊 Normalized sample (first 10): {normalized_data[:10].tolist()}")
        
        # Reshape to match model input: [1, 187, 1]
        input_data = normalized_data.reshape(1, expected_length, 1).astype(np.float32)
        
        return input_data
    
    def predict(self, ecg_data: List[float]) -> Dict[str, Any]:
        """Make prediction on ECG data."""
        try:
            print("\n🧠 Starting prediction...")
            
            # Preprocess data
            input_data = self.preprocess_data(ecg_data)
            
            # Set the input tensor
            self.interpreter.set_tensor(self.input_details[0]['index'], input_data)
            
            # Run inference
            print("🧠 Running model inference...")
            self.interpreter.invoke()
            
            # Get the output
            output_data = self.interpreter.get_tensor(self.output_details[0]['index'])
            raw_output = output_data[0]  # Remove batch dimension
            
            print(f"🧮 Raw output (5 classes): {raw_output.tolist()}")
            
            # Apply softmax to get probabilities
            exp_output = np.exp(raw_output)
            probabilities = exp_output / np.sum(exp_output)
            
            print(f"🧮 Softmax probabilities: {probabilities.tolist()}")
            
            # Calculate combined probabilities for effective 4-class system
            combined_normal = probabilities[0] + probabilities[4]  # Class 0 + 4 = Normal
            arrhythmia = probabilities[1]
            tachycardia = probabilities[2]
            bradycardia = probabilities[3]
            
            print("🧮 Combined probabilities:")
            print(f"   Normal (0+4): {combined_normal:.4f}")
            print(f"   Arrhythmia (1): {arrhythmia:.4f}")
            print(f"   Tachycardia (2): {tachycardia:.4f}")
            print(f"   Bradycardia (3): {bradycardia:.4f}")
            
            # Find the class with highest combined probability
            combined_probs = {
                'Normal': combined_normal,
                'Arrhythmia Type 1': arrhythmia,
                'Tachycardia': tachycardia,
                'Bradycardia': bradycardia
            }
            
            predicted_class = max(combined_probs, key=combined_probs.get)
            confidence = combined_probs[predicted_class]
            
            print(f"🧮 Highest combined confidence: {confidence:.4f} for {predicted_class}")
            print(f"🧮 Final prediction: {predicted_class} with {confidence*100:.1f}% confidence")
            
            # Create detailed results - use combined probabilities
            detailed_results = combined_probs
            
            return {
                'predicted_class': predicted_class,
                'confidence': float(confidence),
                'probabilities': probabilities.tolist(),
                'detailed_results': detailed_results
            }
            
        except Exception as e:
            print(f"❌ Error during prediction: {e}")
            return None

def read_csv_data(file_path: str) -> List[float]:
    """Read ECG data from CSV file."""
    try:
        data = []
        with open(file_path, 'r') as file:
            # Try to detect if it's comma-separated values in a single line
            content = file.read().strip()
            if ',' in content:
                # Single line with comma-separated values
                values = content.split(',')
                for value in values:
                    try:
                        data.append(float(value.strip()))
                    except ValueError:
                        continue
            else:
                # Multiple lines, each with a single value
                file.seek(0)
                reader = csv.reader(file)
                for row in reader:
                    for value in row:
                        try:
                            data.append(float(value.strip()))
                        except ValueError:
                            continue
        
        print(f"📄 Read {len(data)} data points from CSV file")
        return data
        
    except Exception as e:
        print(f"❌ Error reading CSV file: {e}")
        return []

def read_manual_input() -> List[float]:
    """Read ECG data from manual input."""
    print("\n📝 Enter ECG data as comma-separated values (187 values expected):")
    print("   Example: 0.977,0.926,0.681,0.245,0.154,...")
    
    try:
        user_input = input("\nPaste your CSV data: ").strip()
        values = user_input.split(',')
        data = []
        for value in values:
            try:
                data.append(float(value.strip()))
            except ValueError:
                print(f"⚠️ Skipping invalid value: {value}")
                continue
        
        print(f"📄 Parsed {len(data)} data points from input")
        return data
        
    except Exception as e:
        print(f"❌ Error parsing input: {e}")
        return []

def print_prediction_results(results: Dict[str, Any]):
    """Print prediction results in a formatted way."""
    if not results:
        print("❌ No prediction results to display")
        return
    
    print("\n" + "="*60)
    print("🩺 ECG PREDICTION RESULTS")
    print("="*60)
    
    print(f"🏆 Predicted Class: {results['predicted_class']}")
    print(f"🎯 Confidence: {results['confidence']*100:.1f}%")
    
    # Risk assessment
    if results['predicted_class'] == 'Normal':
        risk_color = "🟢"
        risk_text = "No Risk of Heart Attack"
    else:
        risk_color = "🟠"
        risk_text = "Potential Risk - Consult a Doctor"
    
    print(f"{risk_color} Risk Assessment: {risk_text}")
    
    print(f"\n📊 Detailed Probabilities:")
    print("-" * 40)
    for class_name, probability in results['detailed_results'].items():
        bar_length = int(probability * 30)  # Scale to 30 chars
        bar = "█" * bar_length + "░" * (30 - bar_length)
        print(f"{class_name:<20} {bar} {probability*100:5.1f}%")
    
    print("="*60)

def main():
    """Main function to run the ECG prediction test."""
    print("🩺 ECG Prediction Test Script")
    print("=" * 50)
    
    # Check if model file exists
    model_path = "assets/models/model.tflite"
    if not os.path.exists(model_path):
        print(f"❌ Model file not found: {model_path}")
        print("   Make sure you're running this script from the project root directory.")
        sys.exit(1)
    
    # Initialize predictor
    predictor = ECGPredictor(model_path)
    
    while True:
        print("\n" + "="*50)
        print("📋 CHOOSE INPUT METHOD:")
        print("1. Load from CSV file")
        print("2. Manual input (paste CSV data)")
        print("3. Use sample data from ecg_test_examples.txt")
        print("0. Exit")
        
        choice = input("\nEnter your choice (0-3): ").strip()
        
        if choice == "0":
            print("👋 Goodbye!")
            break
        elif choice == "1":
            file_path = input("Enter CSV file path: ").strip()
            ecg_data = read_csv_data(file_path)
        elif choice == "2":
            ecg_data = read_manual_input()
        elif choice == "3":
            # Use sample data from the test examples
            sample_data = [
                0.977941,0.926471,0.681373,0.245098,0.154412,0.191176,0.151961,0.085784,0.058824,0.049020,
                0.044118,0.061275,0.066176,0.061275,0.049020,0.073529,0.061275,0.061275,0.066176,0.068627,
                0.095588,0.075980,0.093137,0.105392,0.115196,0.102941,0.117647,0.125000,0.142157,0.127451,
                0.151961,0.144608,0.164216,0.144608,0.159314,0.151961,0.154412,0.142157,0.151961,0.151961,
                0.147059,0.132353,0.127451,0.134804,0.137255,0.112745,0.107843,0.105392,0.107843,0.098039,
                0.093137,0.102941,0.100490,0.105392,0.102941,0.117647,0.105392,0.122549,0.127451,0.142157,
                0.147059,0.144608,0.174020,0.230392,0.237745,0.247549,0.230392,0.225490,0.198529,0.176471,
                0.132353,0.125000,0.117647,0.122549,0.112745,0.129902,0.115196,0.083333,0.000000,0.066176,
                0.306373,0.612745,0.860294,1.000000,0.958333,0.745098,0.303922,0.164216,0.205882,0.164216,
                0.102941,0.095588,0.090686,0.100490,0.095588,0.098039,0.093137,0.098039,0.095588,0.112745
            ]
            # Pad to 187 if needed
            while len(sample_data) < 187:
                sample_data.append(0.0)
            ecg_data = sample_data[:187]
            print(f"📄 Using sample data (Normal class) with {len(ecg_data)} points")
        else:
            print("❌ Invalid choice. Please try again.")
            continue
        
        if not ecg_data:
            print("❌ No data to process. Please try again.")
            continue
        
        # Make prediction
        results = predictor.predict(ecg_data)
        
        if results:
            print_prediction_results(results)
        else:
            print("❌ Prediction failed. Please check your data and try again.")
        
        # Ask if user wants to continue
        continue_choice = input("\n🔄 Do you want to make another prediction? (y/n): ").strip().lower()
        if continue_choice not in ['y', 'yes']:
            print("👋 Goodbye!")
            break

if __name__ == "__main__":
    main() 