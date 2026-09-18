/// Guard for destructive "reset all" actions.
///
/// The UI should require an explicit confirmation and pass `true` here.
/// Keeping the guard in a reusable helper prevents accidental direct calls.
void requireResetConfirmation(bool confirmed) {
  if (!confirmed) {
    throw StateError('Reset All requires explicit confirmation.');
  }
}
