# SAQR GYM — Fix 04

- Added atomic file write helper
- Added explicit Reset All confirmation guard
- Added non-destructive orphan-file scanner
- Guarded resetAll in lib/data/store.dart

The helpers are intentionally conservative. They provide atomic file writes, a reset confirmation guard, and a read-only orphan scanner. Existing import/restore flows should be wired to these helpers after a build/test pass rather than guessing their exact method signatures.
