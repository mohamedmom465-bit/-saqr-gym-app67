@echo off
setlocal
cd /d "%~dp0.."

if not exist android\app\src\main\AndroidManifest.xml (
  echo Android project missing. Running bootstrap...
  call "%~dp0bootstrap.bat"
  if errorlevel 1 exit /b 1
) else (
  echo [1/6] Re-applying Android configuration...
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0configure_android.ps1"
  if errorlevel 1 exit /b 1
)

echo [2/6] Verifying Android configuration...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0verify_android_setup.ps1"
if errorlevel 1 exit /b 1

echo [3/6] Getting packages...
flutter pub get
if errorlevel 1 exit /b 1

echo [4/6] Generating Drift code...
dart run build_runner build --delete-conflicting-outputs
if errorlevel 1 exit /b 1

echo [5/6] Running analyzer...
flutter analyze
if errorlevel 1 exit /b 1

echo [6/6] Building release APK...
flutter build apk --release
if errorlevel 1 exit /b 1

echo.
echo APK: build\app\outputs\flutter-apk\app-release.apk
