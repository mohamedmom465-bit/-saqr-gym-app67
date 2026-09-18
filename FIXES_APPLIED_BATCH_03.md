# SAQR GYM — Fix 03 batch

Applied conservatively on top of Fix 02:

- Added lib/data/operation_lock.dart
- Centralized Quick-log marker in lib/services/notifications.dart
- Updated 1RM documentation in README.md

Note: the operation lock utility is added as a reusable building block; wiring it into every persistence path is intentionally not guessed without a full build/test pass.
