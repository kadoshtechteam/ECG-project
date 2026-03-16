import tensorflow as tf
import numpy as np

def test_tflite_model(model_path):
    """
    Test if a TensorFlow Lite model can be loaded and run inference
    """
    try:
        # Load the TensorFlow Lite model
        interpreter = tf.lite.Interpreter(model_path=model_path)
        interpreter.allocate_tensors()
        
        # Get input and output details
        input_details = interpreter.get_input_details()
        output_details = interpreter.get_output_details()
        
        print("✅ Model loaded successfully!")
        print(f"Input shape: {input_details[0]['shape']}")
        print(f"Input type: {input_details[0]['dtype']}")
        print(f"Output shape: {output_details[0]['shape']}")
        print(f"Output type: {output_details[0]['dtype']}")
        
        # Test with dummy data
        input_shape = input_details[0]['shape']
        input_data = np.random.random(input_shape).astype(np.float32)
        
        # Run inference
        interpreter.set_tensor(input_details[0]['index'], input_data)
        interpreter.invoke()
        
        # Get output
        output_data = interpreter.get_tensor(output_details[0]['index'])
        print(f"✅ Inference successful!")
        print(f"Output shape: {output_data.shape}")
        print(f"Sample output: {output_data[0]}")
        
        return True
        
    except Exception as e:
        print(f"❌ Error testing model: {e}")
        return False

if __name__ == "__main__":
    model_path = "assets/models/model.tflite"
    print("Testing TensorFlow Lite model compatibility...")
    success = test_tflite_model(model_path)
    
    if success:
        print("\n🎉 Model is compatible with TensorFlow Lite!")
    else:
        print("\n⚠️  Model has compatibility issues. Please retrain with TensorFlow Lite compatible operations.") 