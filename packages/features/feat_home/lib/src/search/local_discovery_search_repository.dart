import 'package:core_l10n/core_l10n.dart';
import 'package:core_theme/core_theme.dart';

import 'discovery_search.dart';

/// Privacy-safe discovery catalog.
///
/// It exposes product destinations and public supporter discovery entry
/// points, never phone numbers, account identifiers, OTPs, or private profile
/// fields. The result set is deliberately bounded.
class LocalDiscoverySearchRepository implements DiscoverySearchRepository {
  const LocalDiscoverySearchRepository();

  static const int maxResults = 30;

  static List<DiscoveryResult> catalog(AfriLocalizations l10n) =>
      <DiscoveryResult>[
        DiscoveryResult(
          id: 'supporter-directory',
          title: l10n.searchSupporterDirectoryTitle,
          description: l10n.searchSupporterDirectoryDescription,
          category: DiscoveryCategory.supporters,
          destination: '/membership/fans',
          icon: AfriIcons.friend,
          keywords: <String>['fan', 'fans', 'friend', 'community', 'supporter'],
        ),
        DiscoveryResult(
          id: 'fan-zone',
          title: l10n.searchFanZoneTitle,
          description: l10n.searchFanZoneDescription,
          category: DiscoveryCategory.supporters,
          destination: '/fanzone',
          icon: AfriIcons.fanzone,
          keywords: <String>['fans', 'community', 'prediction', 'reward'],
        ),
        DiscoveryResult(
          id: 'fan-registry',
          title: l10n.searchFanRegistryTitle,
          description: l10n.searchFanRegistryDescription,
          category: DiscoveryCategory.supporters,
          destination: '/membership/fans',
          icon: AfriIcons.members,
          keywords: <String>['fan', 'supporter', 'member', 'registry'],
        ),
        DiscoveryResult(
          id: 'fixtures',
          title: l10n.searchFixturesTitle,
          description: l10n.searchFixturesDescription,
          category: DiscoveryCategory.fixtures,
          destination: '/fanzone?section=league',
          icon: AfriIcons.fixture,
          keywords: <String>['match', 'matches', 'game', 'schedule', 'result'],
        ),
        DiscoveryResult(
          id: 'live-match',
          title: l10n.searchLiveMatchTitle,
          description: l10n.searchLiveMatchDescription,
          category: DiscoveryCategory.fixtures,
          destination: '/fanzone/match/live',
          icon: AfriIcons.live,
          keywords: <String>['score', 'live', 'match', 'commentary'],
        ),
        DiscoveryResult(
          id: 'standings',
          title: l10n.searchStandingsTitle,
          description: l10n.searchStandingsDescription,
          category: DiscoveryCategory.fixtures,
          destination: '/fanzone?section=league',
          icon: AfriIcons.league,
          keywords: <String>['table', 'league', 'rank', 'competition'],
        ),
        DiscoveryResult(
          id: 'tickets',
          title: l10n.searchTicketsTitle,
          description: l10n.searchTicketsDescription,
          category: DiscoveryCategory.commerce,
          destination: '/tickets',
          icon: AfriIcons.tickets,
          keywords: <String>['ticket', 'entry', 'stadium', 'checkout', 'buy'],
        ),
        DiscoveryResult(
          id: 'my-tickets',
          title: l10n.searchMyTicketsTitle,
          description: l10n.searchMyTicketsDescription,
          category: DiscoveryCategory.commerce,
          destination: '/tickets?tab=mine',
          icon: AfriIcons.qrCode,
          keywords: <String>['ticket', 'qr', 'entry', 'purchase'],
        ),
        DiscoveryResult(
          id: 'shop',
          title: l10n.searchShopTitle,
          description: l10n.searchShopDescription,
          category: DiscoveryCategory.commerce,
          destination: '/shop',
          icon: AfriIcons.shop,
          keywords: <String>['store', 'jersey', 'kit', 'merchandise', 'buy'],
        ),
        DiscoveryResult(
          id: 'cart',
          title: l10n.searchCartTitle,
          description: l10n.searchCartDescription,
          category: DiscoveryCategory.commerce,
          destination: '/shop/cart',
          icon: AfriIcons.cart,
          keywords: <String>['basket', 'checkout', 'order', 'shop'],
        ),
        DiscoveryResult(
          id: 'wallet',
          title: l10n.searchWalletTitle,
          description: l10n.searchWalletDescription,
          category: DiscoveryCategory.services,
          destination: '/fanzone?section=wallet',
          icon: AfriIcons.wallet,
          keywords: <String>['balance', 'fet', 'token', 'transfer', 'redeem'],
        ),
        DiscoveryResult(
          id: 'membership',
          title: l10n.searchMembershipTitle,
          description: l10n.searchMembershipDescription,
          category: DiscoveryCategory.services,
          destination: '/membership',
          icon: AfriIcons.membership,
          keywords: <String>['member', 'card', 'tier', 'benefit'],
        ),
        DiscoveryResult(
          id: 'contributions',
          title: l10n.searchContributionsTitle,
          description: l10n.searchContributionsDescription,
          category: DiscoveryCategory.services,
          destination: '/fanzone?section=supporters',
          icon: AfriIcons.contribute,
          keywords: <String>['support', 'contribute', 'donate', 'project'],
        ),
        DiscoveryResult(
          id: 'notifications',
          title: l10n.searchNotificationsTitle,
          description: l10n.searchNotificationsDescription,
          category: DiscoveryCategory.services,
          destination: '/settings/notifications',
          icon: AfriIcons.notifications,
          keywords: <String>['alert', 'push', 'preference'],
        ),
        DiscoveryResult(
          id: 'privacy',
          title: l10n.searchPrivacyTitle,
          description: l10n.searchPrivacyDescription,
          category: DiscoveryCategory.services,
          destination: '/settings/privacy',
          icon: AfriIcons.privacy,
          keywords: <String>['consent', 'data', 'security', 'permission'],
        ),
        DiscoveryResult(
          id: 'help',
          title: l10n.searchHelpTitle,
          description: l10n.searchHelpDescription,
          category: DiscoveryCategory.services,
          destination: '/settings',
          icon: AfriIcons.help,
          keywords: <String>['help', 'support', 'contact', 'problem'],
        ),
      ];

  @override
  Future<DiscoverySearchResponse> search(DiscoverySearchQuery query) async {
    final normalized = query.text.trim().toLowerCase();
    if (normalized.length < 2) {
      return const DiscoverySearchResponse(results: <DiscoveryResult>[]);
    }

    final terms = normalized
        .split(RegExp(r'\s+'))
        .where((term) => term.isNotEmpty)
        .toList(growable: false);
    final l10n = query.l10n;
    final matches = catalog(l10n)
        .where((result) {
          if (query.category != DiscoveryCategory.all &&
              result.category != query.category) {
            return false;
          }
          final searchable = <String>[
            result.title,
            result.description,
            result.category.label(l10n),
            ...result.keywords,
          ].join(' ').toLowerCase();
          return terms.every(searchable.contains);
        })
        .take(maxResults)
        .toList(growable: false);

    return DiscoverySearchResponse(results: matches);
  }
}
