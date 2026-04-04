import 'package:feat_biopay/feat_biopay.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BiopayProfile', () {
    late BiopayProfile profile;

    setUp(() {
      profile = BiopayProfile.fromJson(<String, dynamic>{
        'id': 'prof-1',
        'public_id': '483912',
        'user_id': 'user-abc',
        'display_name': 'Marie Uwase',
        'route_type': 'phone_number',
        'recipient_value': '0781234567',
        'country_code': 'RW',
        'active': true,
        'consent_version': 'biopay-v1',
        'consent_at': '2026-01-15T08:00:00.000Z',
        'created_at': '2026-01-15T08:00:00.000Z',
      });
    });

    test('fromJson parses all core fields', () {
      expect(profile.id, 'prof-1');
      expect(profile.publicId, '483912');
      expect(profile.userId, 'user-abc');
      expect(profile.displayName, 'Marie Uwase');
      expect(profile.recipientValue, '0781234567');
      expect(profile.countryCode, 'RW');
      expect(profile.active, true);
      expect(profile.consentVersion, 'biopay-v1');
    });

    test('routeLabel for phoneNumber route', () {
      expect(profile.routeLabel, 'Mobile money number');
    });

    test('routeLabel for code route', () {
      final merchant = BiopayProfile.fromJson(<String, dynamic>{
        'id': 'p2',
        'public_id': '999',
        'user_id': 'u2',
        'display_name': 'Shop',
        'route_type': 'code',
        'recipient_value': 'MERCH001',
        'country_code': 'RW',
        'active': true,
        'consent_version': 'biopay-v1',
      });
      expect(merchant.routeLabel, 'Merchant code');
    });

    test('publicAlias prefers publicId', () {
      expect(profile.publicAlias, '483912');
    });

    test('publicAlias falls back to displayName when publicId empty', () {
      final noId = BiopayProfile.fromJson(<String, dynamic>{
        'id': 'p3',
        'public_id': '',
        'user_id': 'u3',
        'display_name': 'Fallback Name',
        'route_type': 'phone_number',
        'recipient_value': '0780000000',
        'country_code': 'RW',
        'active': true,
        'consent_version': 'v1',
      });
      expect(noId.publicAlias, 'Fallback Name');
    });

    test('formattedAlias formats as xxx-xxx', () {
      expect(profile.formattedAlias, '483-912');
    });

    test('maskedRecipientValue masks for 10-digit number', () {
      expect(profile.maskedRecipientValue, '078•••567');
    });

    test('maskedRecipientValue short values pass through', () {
      final short = BiopayProfile.fromJson(<String, dynamic>{
        'id': 'p4',
        'public_id': 'x',
        'user_id': 'u4',
        'display_name': 'Short',
        'route_type': 'code',
        'recipient_value': 'AB',
        'country_code': 'RW',
        'active': true,
        'consent_version': 'v1',
      });
      expect(short.maskedRecipientValue, 'AB');
    });

    test('toJson roundtrips correctly', () {
      final json = profile.toJson();
      expect(json['id'], 'prof-1');
      expect(json['public_id'], '483912');
      expect(json['route_type'], 'phone_number');
      expect(json['active'], true);
    });

    test('defaults route_type to phoneNumber for unknown values', () {
      final unknown = BiopayProfile.fromJson(<String, dynamic>{
        'id': 'p5',
        'public_id': 'x',
        'user_id': 'u5',
        'display_name': 'Unknown',
        'route_type': 'banana',
        'recipient_value': '000',
        'country_code': 'RW',
        'active': true,
        'consent_version': 'v1',
      });
      expect(unknown.routeLabel, 'Mobile money number');
    });

    test('handles null optional fields gracefully', () {
      final minimal = BiopayProfile.fromJson(<String, dynamic>{
        'id': 'p6',
        'public_id': 'min',
        'user_id': 'u6',
        'display_name': 'Min',
        'route_type': 'phone_number',
        'recipient_value': '000',
        'active': false,
      });
      expect(minimal.countryCode, isNotEmpty);
      expect(minimal.consentVersion, 'biopay-v1');
      expect(minimal.consentAt, isNull);
      expect(minimal.revokedAt, isNull);
    });
  });

  group('BiopayMatchResult', () {
    test('fromApiResponse creates match result with profile', () {
      final result = BiopayMatchResult.fromApiResponse(<String, dynamic>{
        'match': true,
        'score': 0.95,
        'profile_id': 'prof-1',
        'public_id': '483912',
        'user_id': 'user-abc',
        'display_name': 'Marie',
        'route_type': 'phone_number',
        'recipient_value': '0781234567',
        'country_code': 'RW',
        'match_receipt': 'receipt-xyz',
        'match_receipt_expires_at': '2099-01-01T00:00:00.000Z',
        'consent_version': 'biopay-v1',
      });

      expect(result.match, true);
      expect(result.score, 0.95);
      expect(result.profile, isNotNull);
      expect(result.profile!.publicId, '483912');
      expect(result.matchReceipt, 'receipt-xyz');
      expect(result.cached, false);
    });

    test('fromApiResponse handles non-match', () {
      final result = BiopayMatchResult.fromApiResponse(<String, dynamic>{
        'match': false,
        'score': 0.35,
      });

      expect(result.match, false);
      expect(result.score, 0.35);
      expect(result.profile, isNull);
      expect(result.matchReceipt, isNull);
    });

    test('fromCacheJson restores cached result', () {
      final original = BiopayMatchResult.fromApiResponse(<String, dynamic>{
        'match': true,
        'score': 0.92,
        'profile_id': 'p1',
        'public_id': '111',
        'user_id': 'u1',
        'display_name': 'Cached',
        'route_type': 'phone_number',
        'recipient_value': '0780000000',
        'country_code': 'RW',
        'consent_version': 'v1',
      });

      final json = original.toJson();
      json['cached'] = true;
      final restored = BiopayMatchResult.fromCacheJson(json);

      expect(restored.match, true);
      expect(restored.cached, true);
      expect(restored.profile, isNotNull);
    });

    test('copyWith updates cached flag', () {
      final result = BiopayMatchResult.fromApiResponse(<String, dynamic>{
        'match': true,
        'score': 0.9,
        'profile_id': 'p1',
        'public_id': '222',
        'user_id': 'u1',
        'display_name': 'Copy',
        'route_type': 'phone_number',
        'recipient_value': '000',
        'country_code': 'RW',
        'consent_version': 'v1',
      });

      expect(result.cached, false);
      final cached = result.copyWith(cached: true);
      expect(cached.cached, true);
      expect(cached.score, result.score);
    });
  });
}
