# SAQR GYM — Fix 06

- Added explicit SessionSource enum
- Added historical analytics safety helpers
- Added safer recommendation/incomplete-set wording helpers
- Added explicit PR metric types
- Added explicit streak completion helper
- Added machine-readable Quick-log source marker

This batch prepares safer Quick-log/analytics/UI semantics without guessing the generated Drift schema. Existing persisted records remain compatible; wiring a new session-source column requires a proper Drift migration and generated code pass.
