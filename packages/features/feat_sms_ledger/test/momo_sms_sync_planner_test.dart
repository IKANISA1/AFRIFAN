import 'package:feat_sms_ledger/src/services/momo_sms_sync_support.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MomoSmsSyncPlanner', () {
    test('resolveManualCutoff returns historicalCutoff if latestKnownMessageAt is null', () {
      final syncState = const MomoSmsSyncState(latestKnownMessageAt: null);
      final historicalCutoff = DateTime(2026, 1, 1).toUtc();
      
      final result = MomoSmsSyncPlanner.resolveManualCutoff(
        syncState: syncState,
        historicalCutoff: historicalCutoff,
      );
      
      expect(result, historicalCutoff);
    });

    test('resolveManualCutoff returns latestKnownMessageAt minus overlap window if after historicalCutoff', () {
      final latest = DateTime(2026, 6, 15).toUtc();
      final syncState = MomoSmsSyncState(latestKnownMessageAt: latest);
      final historicalCutoff = DateTime(2026, 1, 1).toUtc();
      
      final result = MomoSmsSyncPlanner.resolveManualCutoff(
        syncState: syncState,
        historicalCutoff: historicalCutoff,
      );
      
      final expected = latest.subtract(const Duration(hours: 12));
      expect(result, expected);
    });

    test('resolveManualCutoff returns historicalCutoff if overlap window pushes it before historicalCutoff', () {
      // Latest is just 1 hour after historical cutoff
      final historicalCutoff = DateTime(2026, 1, 1, 12, 0).toUtc();
      final latest = DateTime(2026, 1, 1, 13, 0).toUtc();
      final syncState = MomoSmsSyncState(latestKnownMessageAt: latest);
      
      final result = MomoSmsSyncPlanner.resolveManualCutoff(
        syncState: syncState,
        historicalCutoff: historicalCutoff,
      );
      
      // Since latest - 12h = 2026-01-01 01:00 which is BEFORE historicalCutoff (12:00)
      // It should bound to historicalCutoff
      expect(result, historicalCutoff);
    });

    test('lookbackDaysFor calculates correct days', () {
      final cutoff = DateTime(2026, 1, 1).toUtc();
      final now = DateTime(2026, 1, 10).toUtc();
      
      final days = MomoSmsSyncPlanner.lookbackDaysFor(cutoff: cutoff, now: now);
      expect(days, 9);
    });

    test('lookbackDaysFor clamps to 0 for negative difference', () {
      final cutoff = DateTime(2026, 1, 10).toUtc();
      final now = DateTime(2026, 1, 1).toUtc();
      
      final days = MomoSmsSyncPlanner.lookbackDaysFor(cutoff: cutoff, now: now);
      expect(days, 0);
    });

    test('lookbackDaysFor clamps to 365 for large differences', () {
      final cutoff = DateTime(2024, 1, 1).toUtc();
      final now = DateTime(2026, 1, 1).toUtc();
      
      final days = MomoSmsSyncPlanner.lookbackDaysFor(cutoff: cutoff, now: now);
      expect(days, 365);
    });
  });

  group('MomoSmsSyncState', () {
    test('fromJson handles null values gracefully', () {
      final state = MomoSmsSyncState.fromJson({});
      
      expect(state.initialBackfillCompletedAt, isNull);
      expect(state.lastSuccessfulSyncAt, isNull);
      expect(state.latestKnownMessageAt, isNull);
      expect(state.hasInitialBackfill, isFalse);
    });
    
    test('toJson serializes dates properly', () {
      final date = DateTime(2026, 1, 1).toUtc();
      final state = MomoSmsSyncState(lastSuccessfulSyncAt: date);
      
      final json = state.toJson();
      
      expect(json['lastSuccessfulSyncAt'], date.toIso8601String());
      expect(json['initialBackfillCompletedAt'], isNull);
    });
  });
}
