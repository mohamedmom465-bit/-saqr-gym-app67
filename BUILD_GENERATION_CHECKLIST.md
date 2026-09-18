# Build / Generation Checklist

Before release:

- Run `flutter pub get`.
- Run the project's Drift generation command so `app_database.g.dart` is
  generated from the current schema.
- Run `dart format`.
- Run `flutter analyze`.
- Run `flutter test`.
- Run an Android debug build.
- Run a release build after Android setup verification.
- Verify that generated platform folders/files are present when the project
  is intended to ship as a complete Flutter application.

This checklist deliberately does not fabricate generated files; they must be
produced by the project's actual generator/toolchain.
