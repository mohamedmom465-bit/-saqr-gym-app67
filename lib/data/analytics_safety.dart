/// Small helpers for keeping historical analytics honest.
///
/// A historical workout should use a body weight captured at workout time.
/// If that value was not stored by an older record, callers should return
/// null rather than silently substituting today's weight.
double? historicalWorkoutWeight({
  required double? bodyWeightAtWorkout,
}) {
  return bodyWeightAtWorkout;
}

String calorieEstimateLabel({required bool usesHistoricalWeight}) {
  return usesHistoricalWeight
      ? 'تقدير تقريبي للسعرات'
      : 'تقدير تقريبي للسعرات — الوزن التاريخي غير متوفر';
}
