# ECG Prediction Testing with Python

This directory contains a Python script for testing the ECG TensorFlow Lite model with CSV data input.

## 🔍 Model Information

- **Model**: TensorFlow Lite model (`assets/models/model.tflite`)
- **Size**: ~1MB
- **Input**: 187 ECG data points (normalized to 0-1 range)
- **Output**: 5 classes
  - Class 0: Normal
  - Class 1: Arrhythmia Type 1
  - Class 2: Tachycardia  
  - Class 3: Bradycardia
  - Class 4: Arrhythmia Type 2

## 🚀 Quick Start

### 1. Install Dependencies

```bash
pip install -r requirements.txt
```

### 2. Run the Script

```bash
python ecg_prediction_test.py
```

### 3. Choose Input Method

The script provides 3 ways to input ECG data:

**Option 1: Load from CSV file**
- Prepare a CSV file with 187 comma-separated values
- Example: `sample_ecg_data.csv`

**Option 2: Manual input**
- Paste CSV data directly when prompted
- Format: `0.977,0.926,0.681,0.245,...`

**Option 3: Use sample data**
- Uses built-in sample data (Normal class example)

## 📊 Data Format

Your CSV data should contain **187 floating-point values** representing ECG readings:

```csv
0.977941,0.926471,0.681373,0.245098,0.154412,0.191176,...
```

### Data Requirements:
- **187 values** (will pad with zeros if fewer, truncate if more)
- **Floating-point numbers** between 0.0 and 1.0 (or any range - script will normalize)
- **Comma-separated** format

## 🧪 Testing with Sample Data

Use the provided sample data files:

1. **`sample_ecg_data.csv`** - Normal ECG example (187 values)
2. **`ecg_test_examples.txt`** - Multiple examples from different classes

## 📋 Example Output

```
🩺 ECG PREDICTION RESULTS
============================================================
🏆 Predicted Class: Normal
🎯 Confidence: 85.3%
🟢 Risk Assessment: No Risk of Heart Attack

📊 Detailed Probabilities:
----------------------------------------
Normal               ██████████████████████████████  85.3%
Arrhythmia Type 1    ███████░░░░░░░░░░░░░░░░░░░░░░░░  8.2%
Tachycardia          ██░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  3.1%
Bradycardia          █░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  2.8%
Arrhythmia Type 2    ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  0.6%
============================================================
```

## 🔧 How It Works

1. **Data Preprocessing**: 
   - Ensures 187 data points (pads or truncates)
   - Applies MinMaxScaler normalization (0-1 range)
   - Reshapes to model input format [1, 187, 1]

2. **Model Inference**:
   - Loads TensorFlow Lite model
   - Runs prediction
   - Applies softmax to get probabilities

3. **Result Processing**:
   - Maps output to class names
   - Calculates confidence scores
   - Provides risk assessment

## 📁 Files

- `ecg_prediction_test.py` - Main prediction script
- `requirements.txt` - Python dependencies  
- `sample_ecg_data.csv` - Sample ECG data (Normal class)
- `ECG_Prediction_README.md` - This documentation
- `assets/models/model.tflite` - TensorFlow Lite model

## 🩺 Medical Disclaimer

⚠️ **This tool is for educational/testing purposes only and should NOT be used for actual medical diagnosis. Always consult healthcare professionals for medical advice.**

## 🐛 Troubleshooting

**Model not found error:**
- Make sure you're running the script from the project root directory
- Check that `assets/models/model.tflite` exists

**Import errors:**
- Install dependencies: `pip install -r requirements.txt`
- Make sure you have Python 3.7+ installed

**Invalid data errors:**
- Ensure your CSV data contains only numeric values
- Check that values are comma-separated
- Verify file encoding (should be UTF-8)

## 📞 Support

If you encounter issues, check:
1. Model file exists at correct path
2. CSV data format is correct
3. All dependencies are installed
4. Python version is 3.7 or higher 