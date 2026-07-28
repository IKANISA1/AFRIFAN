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

  static const List<DiscoveryResult> catalog = <DiscoveryResult>[
    DiscoveryResult(
      id: 'supporter-directory',
      title: 'Find supporters',
      description: 'Search public supporter aliases and manage friends.',
      category: DiscoveryCategory.supporters,
      destination: '/membership/fans',
      icon: AfriIcons.friend,
      keywords: <String>['fan', 'fans', 'friend', 'community', 'supporter'],
    ),
    DiscoveryResult(
      id: 'fan-zone',
      title: 'Fan Zone',
      description: 'Predictions, community, rewards, and matchday activity.',
      category: DiscoveryCategory.supporters,
      destination: '/fanzone',
      icon: AfriIcons.fanzone,
      keywords: <String>['fans', 'community', 'prediction', 'reward'],
    ),
    DiscoveryResult(
      id: 'fan-registry',
      title: 'Fan registry',
      description: 'Browse the club supporter registry.',
      category: DiscoveryCategory.supporters,
      destination: '/membership/fans',
      icon: AfriIcons.members,
      keywords: <String>['fan', 'supporter', 'member', 'registry'],
    ),
    DiscoveryResult(
      id: 'fixtures',
      title: 'Fixtures',
      description: 'Upcoming and recent Rayon Sports matches.',
      category: DiscoveryCategory.fixtures,
      destination: '/fanzone?section=league',
      icon: AfriIcons.fixture,
      keywords: <String>['match', 'matches', 'game', 'schedule', 'result'],
    ),
    DiscoveryResult(
      id: 'live-match',
      title: 'Live match',
      description: 'Open the current match centre when live coverage exists.',
      category: DiscoveryCategory.fixtures,
      destination: '/fanzone/match/live',
      icon: AfriIcons.live,
      keywords: <String>['score', 'live', 'match', 'commentary'],
    ),
    DiscoveryResult(
      id: 'standings',
      title: 'League standings',
      description: 'View the current table and competition position.',
      category: DiscoveryCategory.fixtures,
      destination: '/fanzone?section=league',
      icon: AfriIcons.league,
      keywords: <String>['table', 'league', 'rank', 'competition'],
    ),
    DiscoveryResult(
      id: 'tickets',
      title: 'Match tickets',
      description: 'Find available tickets and continue to checkout.',
      category: DiscoveryCategory.commerce,
      destination: '/tickets',
      icon: AfriIcons.tickets,
      keywords: <String>['ticket', 'entry', 'stadium', 'checkout', 'buy'],
    ),
    DiscoveryResult(
      id: 'my-tickets',
      title: 'My tickets',
      description: 'Open purchased tickets and match entry details.',
      category: DiscoveryCategory.commerce,
      destination: '/tickets?tab=mine',
      icon: AfriIcons.qrCode,
      keywords: <String>['ticket', 'qr', 'entry', 'purchase'],
    ),
    DiscoveryResult(
      id: 'shop',
      title: 'Club shop',
      description: 'Browse official club products.',
      category: DiscoveryCategory.commerce,
      destination: '/shop',
      icon: AfriIcons.shop,
      keywords: <String>['store', 'jersey', 'kit', 'merchandise', 'buy'],
    ),
    DiscoveryResult(
      id: 'cart',
      title: 'Shopping cart',
      description: 'Review products before checkout.',
      category: DiscoveryCategory.commerce,
      destination: '/shop/cart',
      icon: AfriIcons.cart,
      keywords: <String>['basket', 'checkout', 'order', 'shop'],
    ),
    DiscoveryResult(
      id: 'wallet',
      title: 'FET wallet',
      description: 'View token balance, history, transfer, and redemption.',
      category: DiscoveryCategory.services,
      destination: '/fanzone?section=wallet',
      icon: AfriIcons.wallet,
      keywords: <String>['balance', 'fet', 'token', 'transfer', 'redeem'],
    ),
    DiscoveryResult(
      id: 'membership',
      title: 'Membership',
      description: 'View membership status and club benefits.',
      category: DiscoveryCategory.services,
      destination: '/membership',
      icon: AfriIcons.membership,
      keywords: <String>['member', 'card', 'tier', 'benefit'],
    ),
    DiscoveryResult(
      id: 'contributions',
      title: 'Support the club',
      description: 'Open contributions and supporter projects.',
      category: DiscoveryCategory.services,
      destination: '/fanzone?section=supporters',
      icon: AfriIcons.contribute,
      keywords: <String>['support', 'contribute', 'donate', 'project'],
    ),
    DiscoveryResult(
      id: 'notifications',
      title: 'Notifications',
      description: 'Review and update notification preferences.',
      category: DiscoveryCategory.services,
      destination: '/settings/notifications',
      icon: AfriIcons.notifications,
      keywords: <String>['alert', 'push', 'preference'],
    ),
    DiscoveryResult(
      id: 'privacy',
      title: 'Privacy settings',
      description: 'Review consent and privacy controls.',
      category: DiscoveryCategory.services,
      destination: '/settings/privacy',
      icon: AfriIcons.privacy,
      keywords: <String>['consent', 'data', 'security', 'permission'],
    ),
    DiscoveryResult(
      id: 'help',
      title: 'Help and support',
      description: 'Open support options from Settings.',
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
    final matches = catalog
        .where((result) {
          if (query.category != DiscoveryCategory.all &&
              result.category != query.category) {
            return false;
          }
          final searchable = <String>[
            result.title,
            result.description,
            result.category.label,
            ...result.keywords,
          ].join(' ').toLowerCase();
          return terms.every(searchable.contains);
        })
        .take(maxResults)
        .toList(growable: false);

    return DiscoverySearchResponse(results: matches);
  }
}
