@echo off
setlocal
cd /d "%~dp0.."

echo [1/6] Creating Android + iOS platform files...
flutter create --platforms=android,ios .
if errorlevel 1 exit /b 1

echo [2/6] Applying Android notification/camera configuration...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0configure_android.ps1"
if errorlevel 1 exit /b 1

echo [3/6] Verifying Android configuration...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0verify_android_setup.ps1"
if errorlevel 1 exit /b 1

echo [4/6] Getting packages...
flutter pub get
if errorlevel 1 exit /b 1

echo [5/6] Generating Drift code...
dart run build_runner build --delete-conflicting-outputs
if errorlevel 1 exit /b 1

echo [6/6] Done. Run tool\build_apk.bat to analyze and build.
