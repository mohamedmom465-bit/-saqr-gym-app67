@echo off
setlocal
cd /d "%~dp0.."

if not exist lib\data\db\app_database.g.dart (
  echo [FAIL] Drift generated file is missing.
  echo Run: dart run build_runner build --delete-conflicting-outputs
  exit /b 1
)

if not exist android\app\src\main\AndroidManifest.xml (
  echo [FAIL] Android platform project is missing.
  echo Run: flutter create --platforms=android .
  exit /b 1
)

echo [OK] Generated Flutter/Drift prerequisites are present.
