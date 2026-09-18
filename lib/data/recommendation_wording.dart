String restRecommendationForStreak(int streak) {
  if (streak < 6) return '';
  return 'لديك $streak أيام متتالية من التدريب — قد يكون يوم راحة مناسبًا حسب شدة تمرينك وإحساسك بالتعب.';
}

String incompleteSetsLabel(int completed, int target) {
  if (completed >= target) return 'مكتمل';
  return 'مجموعات غير مكتملة ($completed/$target)';
}
