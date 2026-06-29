class OfficialTicketCategory {
  const OfficialTicketCategory({
    required this.name,
    required this.priceRwf,
    required this.stadiumPlacement,
    required this.sortOrder,
  });

  final String name;
  final int priceRwf;
  final String stadiumPlacement;
  final int sortOrder;
}

const officialTicketCategories = <OfficialTicketCategory>[
  OfficialTicketCategory(
    name: 'General',
    priceRwf: 3000,
    stadiumPlacement: 'Open stands / Bleachers area',
    sortOrder: 10,
  ),
  OfficialTicketCategory(
    name: 'Regular',
    priceRwf: 5000,
    stadiumPlacement: 'Standard covered seating sections',
    sortOrder: 20,
  ),
  OfficialTicketCategory(
    name: 'Regular+',
    priceRwf: 10000,
    stadiumPlacement: 'Main grandstand padded seats',
    sortOrder: 30,
  ),
  OfficialTicketCategory(
    name: 'Classic Seat',
    priceRwf: 15000,
    stadiumPlacement: 'Mid-tier seating with extra legroom',
    sortOrder: 40,
  ),
  OfficialTicketCategory(
    name: 'VIP',
    priceRwf: 30000,
    stadiumPlacement: 'Premium lounge seating',
    sortOrder: 50,
  ),
  OfficialTicketCategory(
    name: 'VVIP',
    priceRwf: 50000,
    stadiumPlacement: 'Center hospitality / Presidential section',
    sortOrder: 60,
  ),
  OfficialTicketCategory(
    name: 'Business Suite',
    priceRwf: 70000,
    stadiumPlacement: 'Premium private indoor/outdoor tier',
    sortOrder: 70,
  ),
  OfficialTicketCategory(
    name: 'Executive',
    priceRwf: 100000,
    stadiumPlacement: 'Front-row luxury padded seating',
    sortOrder: 80,
  ),
  OfficialTicketCategory(
    name: 'Executive+',
    priceRwf: 150000,
    stadiumPlacement: 'Elite seating alongside club dignitaries',
    sortOrder: 90,
  ),
  OfficialTicketCategory(
    name: 'SkyBox',
    priceRwf: 2000000,
    stadiumPlacement: 'Private suite rental for corporate groups',
    sortOrder: 100,
  ),
];
