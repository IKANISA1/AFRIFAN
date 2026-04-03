import 'dart:math';

/// Generates unique 6-digit numeric aliases for anonymous identities.
class AliasGenerator {
  static final Random _random = Random.secure();

  /// Generate a random 6-digit alias string.
  static String generate() {
    return (100000 + _random.nextInt(899999)).toString();
  }

  /// Format alias with dash: 882941 → 882-941
  static String format(String alias) {
    if (alias.length == 6) {
      return '${alias.substring(0, 3)}-${alias.substring(3)}';
    }
    return alias;
  }

  /// Mask a MOMO number: 0788123456 → 07XX***456
  static String maskMomo(String momo) {
    if (momo.length < 8) return momo;
    final prefix = momo.substring(0, 2);
    final suffix = momo.substring(momo.length - 3);
    return '${prefix}XX***$suffix';
  }
}
