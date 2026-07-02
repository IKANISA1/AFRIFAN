import 'package:feat_gamification/src/models/reward_store_content.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reward store catalog parses bundled payload shape', () {
    const payload = '''
      {
        "reward_options": [
          {
            "reward": "Mobile Airtime",
            "cost": "500 pts",
            "category": "Utility",
            "notes": "Via MoMo API integration"
          },
          {
            "reward": "Partner Voucher",
            "cost": "1000 pts",
            "category": "Utility",
            "notes": "Restaurant or retail partner reward"
          }
        ]
      }
    ''';

    final options = RewardStoreContent.parseOptions(payload);

    expect(options, isNotEmpty);
    expect(options.first.reward, 'Mobile Airtime');
    expect(options.last.cost, '1000 pts');
  });
}
