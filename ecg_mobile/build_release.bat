@echo off
setlocal enabledelayedexpansion

REM ECG Heart Monitor - Release Build Script (Windows)
REM This script automates the process of building a release APK

echo 🏥 ECG Heart Monitor - Release Build Script
echo ===========================================
echo.

REM Check if we're in the project root
if not exist "pubspec.yaml" (
    echo [ERROR] Please run this script from the project root directory
    pause
    exit /b 1
)

REM Check if Flutter is installed
flutter --version >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Flutter is not installed or not in PATH
    pause
    exit /b 1
)

REM Check if keystore configuration exists
if not exist "android\key.properties" (
    echo [WARNING] No signing configuration found (android\key.properties^)
    echo [INFO] You can still build an unsigned APK or set up signing later
    echo.
    echo To set up signing:
    echo 1. cd android
    echo 2. keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
    echo 3. copy key.properties.template key.properties
    echo 4. Edit key.properties with your keystore details
    echo.
    set /p continue="Continue without signing? (y/N): "
    if /i not "!continue!"=="y" exit /b 1
)

REM Ask user which build type they want
echo.
echo Select build type:
echo 1^) APK (for direct distribution^)
echo 2^) App Bundle (for Google Play Store^)
echo 3^) Both
echo 4^) APK - Minimal optimization (if standard build fails^)
echo.
set /p build_choice="Enter choice (1-4): "

REM Clean previous builds
echo [INFO] Cleaning previous builds...
flutter clean

REM Get dependencies
echo [INFO] Getting dependencies...
flutter pub get

REM Build based on user choice
if "%build_choice%"=="1" (
    echo [INFO] Building release APK...
    flutter build apk --release
    
    if errorlevel 1 (
        echo [ERROR] APK build failed!
        pause
        exit /b 1
    ) else (
        echo [SUCCESS] APK build completed!
        echo.
        echo 📱 Your APK is located at:
        echo    build\app\outputs\flutter-apk\app-release.apk
    )
) else if "%build_choice%"=="2" (
    echo [INFO] Building App Bundle...
    flutter build appbundle --release
    
    if errorlevel 1 (
        echo [ERROR] App Bundle build failed!
        pause
        exit /b 1
    ) else (
        echo [SUCCESS] App Bundle build completed!
        echo.
        echo 📦 Your App Bundle is located at:
        echo    build\app\outputs\bundle\release\app-release.aab
    )
) else if "%build_choice%"=="3" (
    echo [INFO] Building release APK...
    flutter build apk --release
    
    if errorlevel 1 (
        echo [ERROR] APK build failed!
        pause
        exit /b 1
    ) else (
        echo [SUCCESS] APK build completed!
        
        echo [INFO] Building App Bundle...
        flutter build appbundle --release
        
        if errorlevel 1 (
            echo [ERROR] App Bundle build failed!
            pause
            exit /b 1
        ) else (
            echo [SUCCESS] App Bundle build completed!
            echo.
            echo 📱 Your APK is located at:
            echo    build\app\outputs\flutter-apk\app-release.apk
            echo.
            echo 📦 Your App Bundle is located at:
            echo    build\app\outputs\bundle\release\app-release.aab
        )
    )
) else if "%build_choice%"=="4" (
    echo [INFO] Building release APK with minimal optimization...
    flutter build apk --release --no-shrink
    
    if errorlevel 1 (
        echo [ERROR] APK build failed!
        pause
        exit /b 1
    ) else (
        echo [SUCCESS] APK build completed!
        echo.
        echo 📱 Your APK is located at:
        echo    build\app\outputs\flutter-apk\app-release.apk
    )
) else (
    echo [ERROR] Invalid choice. Please run the script again.
    pause
    exit /b 1
)

REM Show build information
echo.
echo 📊 Build Information:
echo    Package: com.ecgmobile.ecg_mobile
echo    Min SDK: 21 (Android 5.0^)
echo    Optimizations: ProGuard enabled, resources shrunk
echo    ML Model: TensorFlow Lite integrated

REM Check if we can get file sizes
if exist "build\app\outputs\flutter-apk\app-release.apk" (
    for %%A in ("build\app\outputs\flutter-apk\app-release.apk") do (
        set "apk_size=%%~zA"
        set /a "apk_mb=!apk_size! / 1048576"
        echo    APK Size: !apk_mb! MB
    )
)

if exist "build\app\outputs\bundle\release\app-release.aab" (
    for %%A in ("build\app\outputs\bundle\release\app-release.aab") do (
        set "aab_size=%%~zA"
        set /a "aab_mb=!aab_size! / 1048576"
        echo    App Bundle Size: !aab_mb! MB
    )
)

echo.
echo [SUCCESS] Build completed successfully! 🎉

REM Ask if user wants to install the APK
if exist "build\app\outputs\flutter-apk\app-release.apk" (
    echo.
    set /p install="Install APK on connected device? (y/N): "
    if /i "!install!"=="y" (
        echo [INFO] Installing APK...
        adb install build\app\outputs\flutter-apk\app-release.apk
        
        if errorlevel 1 (
            echo [WARNING] APK installation failed. Make sure a device is connected and USB debugging is enabled.
        ) else (
            echo [SUCCESS] APK installed successfully!
        )
    )
)

echo.
echo 🏥 ECG Heart Monitor app is ready for distribution!
echo.
echo Next steps:
echo • Test the app thoroughly on different devices
echo • For Play Store: Upload the .aab file
echo • For direct distribution: Share the .apk file
echo.
echo Happy monitoring! ❤️
echo.
pause 