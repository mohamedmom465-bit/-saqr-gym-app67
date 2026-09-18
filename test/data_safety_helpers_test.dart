import 'package:flutter_test/flutter_test.dart';

import 'package:saqr_gym/data/session_source.dart';
import 'package:saqr_gym/data/streak_safety.dart';
import 'package:saqr_gym/data/recommendation_wording.dart';

void main() {
  group('SessionSource', () {
    test('round-trips quick log', () {
      expect(SessionSourceCodec.fromValue('quick_log'),
          SessionSource.quickLog);
      expect(SessionSource.quickLog.value, 'quick_log');
    });

    test('unknown source is manual for backward compatibility', () {
      expect(SessionSourceCodec.fromValue('legacy'), SessionSource.manual);
    });
  });

  group('streak safety', () {
    test('quick log does not count', () {
      expect(
        countsAsCompletedTrainingDay(
          hasSession: true,
          isQuickLog: true,
          completedSets: 10,
        ),
        isFalse,
      );
    });

    test('completed manual session counts', () {
      expect(
        countsAsCompletedTrainingDay(
          hasSession: true,
          isQuickLog: false,
          completedSets: 1,
        ),
        isTrue,
      );
    });
  });

  group('recommendation wording', () {
    test('does not issue rest recommendation before threshold', () {
      expect(restRecommendationForStreak(5), isEmpty);
    });

    test('labels incomplete sets explicitly', () {
      expect(incompleteSetsLabel(3, 4), contains('3/4'));
    });
  });
}
