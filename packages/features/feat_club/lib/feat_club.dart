/// Club information, fixtures, results, standings, news, and projects.
library;

// Compatibility for current public callers; new shared data consumers import club_data.
export 'package:club_data/club_data.dart'
    show
        ClubOverview,
        ClubNewsItem,
        ClubSquadMember,
        ClubFixtureItem,
        ClubStandingItem,
        ClubHistoryItem,
        ClubContentFailureKind,
        ClubContentFailure,
        clubContentGatewayProvider,
        clubContentLoadTimeoutProvider,
        clubOverviewProvider,
        clubNewsProvider,
        clubSquadProvider,
        clubPlayerProvider,
        clubArticleProvider,
        clubMatchesProvider,
        clubStandingsProvider,
        clubHistoryProvider,
        clubPublicLinkProvider,
        validPublicEntityPath,
        validNativeEntityPath,
        nativeCollectionForPublicPath,
        ClubContentGateway,
        ClubEntityGateway,
        SupabaseClubContentGateway,
        loadGikundiroPublicPartners,
        mapGikundiroPublicPartner;

export 'src/club_module.dart';
export 'src/screens/club_collection_screens.dart';
export 'src/screens/club_hub_screen.dart';
