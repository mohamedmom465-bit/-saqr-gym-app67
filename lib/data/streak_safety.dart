bool countsAsCompletedTrainingDay({
  required bool hasSession,
  required bool isQuickLog,
  required int completedSets,
  int minimumCompletedSets = 1,
}) {
  if (!hasSession || isQuickLog) return false;
  return completedSets >= minimumCompletedSets;
}
