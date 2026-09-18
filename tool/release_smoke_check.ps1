$ErrorActionPreference = "Stop"

Write-Host "SAQR GYM release smoke check"

if (!(Test-Path "pubspec.yaml")) {
  throw "pubspec.yaml is missing."
}

if (!(Test-Path "lib")) {
  throw "lib/ is missing."
}

$generatedDb = Get-ChildItem -Path "lib" -Recurse -Filter "app_database.g.dart" -ErrorAction SilentlyContinue
if ($generatedDb.Count -eq 0) {
  Write-Warning "Generated Drift file lib/data/db/app_database.g.dart is not present. Run the project's generator before building."
}

if (!(Test-Path "android")) {
  Write-Warning "android/ is not present. Generate Android platform files before a device/release build."
}

Write-Host "Static project structure checks completed."
Write-Host "Next commands in a Flutter SDK environment:"
Write-Host "  flutter pub get"
Write-Host "  dart format lib test"
Write-Host "  flutter analyze"
Write-Host "  flutter test"
Write-Host "  flutter build apk --debug"
