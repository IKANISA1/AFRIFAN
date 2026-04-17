/// Barrel re-export for all club domain models.
///
/// Decomposed from the original monolithic club_models.dart into:
///   ✅ domain/contribution_models.dart — ContributionGroup
///   ✅ domain/fan_models.dart          — FanMembership, FanClub
///   ✅ domain/match_models.dart        — ClubMatch, ClubTicket
///   ✅ domain/shop_models.dart         — ClubProduct, CartItem, ClubShopOrder
library;

export 'domain/contribution_models.dart';
export 'domain/fan_models.dart';
export 'domain/match_models.dart';
export 'domain/shop_models.dart';
