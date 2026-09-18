# SAQR GYM — Fix 05

- Added BackupImportGuard for envelope validation and isolated staging
- Added backup envelope validation in lib/data/store.dart
- Added restore rollback helper

This batch adds conservative safety primitives for import/restore: strict backup envelope validation, isolated staging support, and a rollback-copy helper for the live SQLite file. Existing flows should call these helpers around their actual import/restore transaction.
