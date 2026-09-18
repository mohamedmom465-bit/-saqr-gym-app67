# SAQR GYM — Data Safety Test Plan

Run these before treating the release as stable:

1. Fresh install -> create first workout -> close/reopen -> verify data.
2. Active workout -> force close -> reopen -> verify active session recovery.
3. Finish workout -> force close before end screen finishes -> reopen -> verify
   the finished session remains recoverable and is persisted exactly once.
4. Save + automatic snapshot -> trigger restore -> verify no partial DB state.
5. Import valid backup -> verify DB and referenced images.
6. Import invalid/unsupported backup -> verify live data is unchanged.
7. Interrupt/fail import during staging -> verify live data is unchanged.
8. Restore with rollback copy -> verify rollback can recover the previous DB.
9. Reset All without confirmation -> must be rejected.
10. Reset All after explicit confirmation -> verify DB and associated storage
    are reset according to the product's intended behavior.
11. Quick-log -> verify it is excluded from workout analytics/streak.
12. Manual session with incomplete sets -> verify wording says incomplete sets.
13. Historical analytics without a stored workout-time body weight -> verify
    the UI does not silently substitute today's body weight.
14. Backup format 1 / 2 / unknown -> verify unsupported formats are rejected.

No test should treat a DB-open failure as permission to silently replace the
user's data with a default database.
