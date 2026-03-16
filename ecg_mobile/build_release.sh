#!/bin/bash

# ECG Heart Monitor - Release Build Script
# This script automates the process of building a release APK

set -e  # Exit on any error

echo "🏥 ECG Heart Monitor - Release Build Script"
echo "==========================================="

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we're in the project root
if [ ! -f "pubspec.yaml" ]; then
    print_error "Please run this script from the project root directory"
    exit 1
fi

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    print_error "Flutter is not installed or not in PATH"
    exit 1
fi

# Check if keystore configuration exists
if [ ! -f "android/key.properties" ]; then
    print_warning "No signing configuration found (android/key.properties)"
    print_status "You can still build an unsigned APK or set up signing later"
    echo ""
    echo "To set up signing:"
    echo "1. cd android"
    echo "2. keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload"
    echo "3. cp key.properties.template key.properties"
    echo "4. Edit key.properties with your keystore details"
    echo ""
    read -p "Continue without signing? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Ask user which build type they want
echo ""
echo "Select build type:"
echo "1) APK (for direct distribution)"
echo "2) App Bundle (for Google Play Store)"
echo "3) Both"
echo "4) APK - Minimal optimization (if standard build fails)"
echo ""
read -p "Enter choice (1-4): " build_choice

# Clean previous builds
print_status "Cleaning previous builds..."
flutter clean

# Get dependencies
print_status "Getting dependencies..."
flutter pub get

# Build based on user choice
case $build_choice in
    1)
        print_status "Building release APK..."
        flutter build apk --release
        
        if [ $? -eq 0 ]; then
            print_success "APK build completed!"
            echo ""
            echo "📱 Your APK is located at:"
            echo "   build/app/outputs/flutter-apk/app-release.apk"
        else
            print_error "APK build failed!"
            exit 1
        fi
        ;;
    2)
        print_status "Building App Bundle..."
        flutter build appbundle --release
        
        if [ $? -eq 0 ]; then
            print_success "App Bundle build completed!"
            echo ""
            echo "📦 Your App Bundle is located at:"
            echo "   build/app/outputs/bundle/release/app-release.aab"
        else
            print_error "App Bundle build failed!"
            exit 1
        fi
        ;;
    3)
        print_status "Building release APK..."
        flutter build apk --release
        
        if [ $? -eq 0 ]; then
            print_success "APK build completed!"
            
            print_status "Building App Bundle..."
            flutter build appbundle --release
            
            if [ $? -eq 0 ]; then
                print_success "App Bundle build completed!"
                echo ""
                echo "📱 Your APK is located at:"
                echo "   build/app/outputs/flutter-apk/app-release.apk"
                echo ""
                echo "📦 Your App Bundle is located at:"
                echo "   build/app/outputs/bundle/release/app-release.aab"
            else
                print_error "App Bundle build failed!"
                exit 1
            fi
        else
            print_error "APK build failed!"
            exit 1
        fi
        ;;
    4)
        print_status "Building release APK with minimal optimization..."
        print_status "This uses less aggressive ProGuard settings to avoid compatibility issues..."
        
        # Use gradle directly for the releaseMinimal build variant
        cd android
        ./gradlew assembleReleaseMinimal
        cd ..
        
        if [ $? -eq 0 ]; then
            print_success "APK with minimal optimization build completed!"
            echo ""
            echo "📱 Your APK is located at:"
            echo "   build/app/outputs/apk/releaseMinimal/app-releaseMinimal.apk"
        else
            print_error "APK with minimal optimization build failed!"
            print_status "Trying standard Flutter build without ProGuard..."
            
            # Fallback to standard Flutter build
            flutter build apk --release --no-shrink
            
            if [ $? -eq 0 ]; then
                print_success "Standard APK build completed!"
                echo ""
                echo "📱 Your APK is located at:"
                echo "   build/app/outputs/flutter-apk/app-release.apk"
            else
                print_error "All build attempts failed!"
                exit 1
            fi
        fi
        ;;
    *)
        print_error "Invalid choice. Please run the script again."
        exit 1
        ;;
esac

# Show build information
echo ""
echo "📊 Build Information:"
echo "   Package: com.ecgmobile.ecg_mobile"
echo "   Min SDK: 21 (Android 5.0)"
echo "   Optimizations: ProGuard enabled, resources shrunk"
echo "   ML Model: TensorFlow Lite integrated"

# Check if we can get file sizes
if [ -f "build/app/outputs/flutter-apk/app-release.apk" ]; then
    apk_size=$(du -h "build/app/outputs/flutter-apk/app-release.apk" | cut -f1)
    echo "   APK Size: $apk_size"
fi

if [ -f "build/app/outputs/bundle/release/app-release.aab" ]; then
    aab_size=$(du -h "build/app/outputs/bundle/release/app-release.aab" | cut -f1)
    echo "   App Bundle Size: $aab_size"
fi

echo ""
print_success "Build completed successfully! 🎉"

# Ask if user wants to install the APK
if [ -f "build/app/outputs/flutter-apk/app-release.apk" ]; then
    echo ""
    read -p "Install APK on connected device? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Installing APK..."
        adb install build/app/outputs/flutter-apk/app-release.apk
        
        if [ $? -eq 0 ]; then
            print_success "APK installed successfully!"
        else
            print_warning "APK installation failed. Make sure a device is connected and USB debugging is enabled."
        fi
    fi
fi

echo ""
echo "🏥 ECG Heart Monitor app is ready for distribution!"
echo ""
echo "Next steps:"
echo "• Test the app thoroughly on different devices"
echo "• For Play Store: Upload the .aab file"
echo "• For direct distribution: Share the .apk file"
echo ""
echo "Happy monitoring! ❤️" 