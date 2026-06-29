class OfficialMembershipTier {
  const OfficialMembershipTier({
    required this.slug,
    required this.name,
    required this.priceRwf,
    required this.billingPeriod,
    required this.track,
    required this.summary,
    required this.benefits,
    required this.sortOrder,
    this.featured = false,
    this.seatingAccess,
    this.matchAccess,
  });

  final String slug;
  final String name;
  final int priceRwf;
  final String billingPeriod;
  final String track;
  final String summary;
  final List<String> benefits;
  final int sortOrder;
  final bool featured;
  final String? seatingAccess;
  final String? matchAccess;

  Map<String, dynamic> toPackageMap() {
    return <String, dynamic>{
      'id': 'official-$slug',
      'tier': slug,
      'category_slug': slug,
      'title': name,
      'subtitle': track,
      'description': summary,
      'benefits': benefits,
      'annual_price': priceRwf,
      'price': priceRwf,
      'billing_period': billingPeriod,
      'sort_order': sortOrder,
      'featured': featured,
      'seating_access': seatingAccess,
      'match_access': matchAccess,
      'source_label':
          'User-provided official Rayon Sports membership category list, 2026-06-27',
      'verification_status': 'approved',
    };
  }
}

const officialMembershipTiers = <OfficialMembershipTier>[
  OfficialMembershipTier(
    slug: 'gold',
    name: 'Gold',
    priceRwf: 1000000,
    billingPeriod: 'annual',
    track: 'Season Ticket - Premium and Honorary Membership',
    summary:
        'VVIP reserved seat, parking, and complimentary half-time hospitality.',
    seatingAccess: 'VVIP Section',
    matchAccess: 'Permanent reserved seat and parking',
    featured: true,
    sortOrder: 1,
    benefits: <String>[
      'VVIP permanent reserved seat and parking',
      'Club Advisory Committee seat',
      'General Assembly invitation',
      'Complimentary half-time hospitality and refreshments',
      'Free access to all training sessions',
      'Official Rayon Sports jersey',
      'Exclusive VVIP event invitations',
      'Premium team photos and videos',
      'Discounts with official sponsors and partners',
    ],
  ),
  OfficialMembershipTier(
    slug: 'silver',
    name: 'Silver',
    priceRwf: 400000,
    billingPeriod: 'annual',
    track: 'Season Ticket - Premium and Honorary Membership',
    summary: 'Home-match hospitality and VIP club event invitations.',
    seatingAccess: 'VIP Section',
    matchAccess: 'All home and organized matches',
    sortOrder: 2,
    benefits: <String>[
      'VIP section for all home and organized matches',
      'Hospitality and refreshments at home matches',
      'Official Rayon Sports jersey',
      'VIP invitations to club events',
      'Discounts with club partners',
      'Access to official club video content',
    ],
  ),
  OfficialMembershipTier(
    slug: 'bronze',
    name: 'Bronze',
    priceRwf: 100000,
    billingPeriod: 'annual',
    track: 'Season Ticket - Premium and Honorary Membership',
    summary: 'Covered stand membership with official jersey and club updates.',
    seatingAccess: 'Covered Stands (Igice Gitwikiriye)',
    matchAccess: 'Covered-stand home match access',
    sortOrder: 3,
    benefits: <String>[
      'Covered stands access',
      'Official Rayon Sports jersey',
      'Regular official club updates',
      'Insider news through digital channels',
    ],
  ),
  OfficialMembershipTier(
    slug: 'imena',
    name: 'Imena',
    priceRwf: 10000,
    billingPeriod: 'annual',
    track: 'Standard Fan Membership Card',
    summary: 'Dedicated special entrance gate on match days.',
    matchAccess: 'Standard fan-card match access',
    sortOrder: 4,
    benefits: <String>[
      '10% off home match tickets',
      'Dedicated special entrance gate on match days',
      '50% off training sessions at Nzove grounds',
      'Free entry to open training sessions while traveling away',
      'Direct access to official club news updates',
    ],
  ),
  OfficialMembershipTier(
    slug: 'inyamibwa',
    name: 'Inyamibwa',
    priceRwf: 5000,
    billingPeriod: 'annual',
    track: 'Standard Fan Membership Card',
    summary: 'Standard fan-card member access with official club news updates.',
    matchAccess: 'Standard fan-card match access',
    sortOrder: 5,
    benefits: <String>[
      '5% off home match tickets',
      '20% off training sessions at Nzove grounds',
      'Free entry to open training sessions while traveling away',
      'Direct access to official club news updates',
    ],
  ),
  OfficialMembershipTier(
    slug: 'ingenzi-imanzi',
    name: 'Ingenzi / Imanzi',
    priceRwf: 2000,
    billingPeriod: 'annual',
    track: 'Standard Fan Membership Card',
    summary: 'Dedicated fan entrance gate.',
    matchAccess: 'Standard ticketing rates',
    sortOrder: 6,
    benefits: <String>[
      'Standard ticketing rates',
      'Dedicated fan entrance gate',
      '20% off training sessions at Nzove grounds',
      'Free entry to open training sessions when the team plays away',
    ],
  ),
];

Map<String, dynamic>? officialMembershipPackage(String rawSlug) {
  final normalized = normalizeMembershipSlug(rawSlug);
  for (final tier in officialMembershipTiers) {
    if (tier.slug == normalized) {
      return tier.toPackageMap();
    }
  }
  return null;
}

List<Map<String, dynamic>> officialMembershipPackages() {
  return officialMembershipTiers
      .map((tier) => tier.toPackageMap())
      .toList(growable: false);
}

String normalizeMembershipSlug(String? rawValue) {
  final value = (rawValue ?? '').trim().toLowerCase();
  return switch (value) {
    'ingenzi' || 'imanzi' || 'ingenzi / imanzi' => 'ingenzi-imanzi',
    'standard_fan_card' => 'imena',
    'season_ticket' => 'gold',
    _ =>
      value
          .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
          .replaceAll(RegExp(r'^-|-$'), ''),
  };
}

String officialMembershipLabel(String? rawValue) {
  final normalized = normalizeMembershipSlug(rawValue);
  for (final tier in officialMembershipTiers) {
    if (tier.slug == normalized) {
      return tier.name;
    }
  }
  if (normalized.isEmpty) {
    return 'Imena';
  }
  return normalized
      .split('-')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

List<String> parseMembershipBenefits(dynamic raw) {
  if (raw is! List) {
    return const <String>[];
  }

  return raw
      .map((entry) {
        if (entry is String) {
          return entry.trim();
        }
        if (entry is Map) {
          final map = Map<String, dynamic>.from(entry);
          return (map['label'] ?? map['title'] ?? map['value'] ?? '')
              .toString()
              .trim();
        }
        return '';
      })
      .where((entry) => entry.isNotEmpty)
      .toList(growable: false);
}

Map<String, dynamic> normalizeMembershipTierRow(Map<String, dynamic> row) {
  final slug = normalizeMembershipSlug(
    row['category_slug']?.toString() ??
        row['tier']?.toString() ??
        row['name']?.toString(),
  );
  final fallback = officialMembershipPackage(slug);
  final benefits = parseMembershipBenefits(
    row['benefits'] ?? row['privileges'],
  );
  final price =
      (row['price_rwf'] as num?)?.toInt() ??
      (row['annual_price'] as num?)?.toInt() ??
      (row['price'] as num?)?.toInt() ??
      (row['monthly_price_rwf'] as num?)?.toInt() ??
      (fallback?['annual_price'] as num?)?.toInt() ??
      0;

  return <String, dynamic>{
    ...?fallback,
    'id': row['id']?.toString() ?? fallback?['id'] ?? 'official-$slug',
    'tier': slug,
    'category_slug': slug,
    'title':
        row['title']?.toString() ??
        row['name']?.toString() ??
        fallback?['title'] ??
        officialMembershipLabel(slug),
    'subtitle':
        row['subtitle']?.toString() ??
        row['membership_track']?.toString() ??
        row['package_type']?.toString() ??
        fallback?['subtitle'],
    'description':
        row['description']?.toString() ??
        row['entry_perks']?.toString() ??
        row['notes']?.toString() ??
        fallback?['description'],
    'benefits': benefits.isEmpty
        ? (fallback?['benefits'] ?? benefits)
        : benefits,
    'annual_price': price,
    'price': price,
    'billing_period':
        row['billing_period']?.toString() ?? fallback?['billing_period'],
    'sort_order':
        (row['sort_order'] as num?)?.toInt() ??
        (fallback?['sort_order'] as num?)?.toInt() ??
        100,
    'featured': row['featured'] as bool? ?? fallback?['featured'] ?? false,
    'seating_access':
        row['seating_access']?.toString() ?? fallback?['seating_access'],
    'match_access':
        row['match_access']?.toString() ?? fallback?['match_access'],
    'source_label':
        row['source_label']?.toString() ?? fallback?['source_label'],
    'verification_status':
        row['verification_status']?.toString() ??
        fallback?['verification_status'],
  };
}
