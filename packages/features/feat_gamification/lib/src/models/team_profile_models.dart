import 'package:core_utils/core_utils.dart';

/// Resolved club context for the team profile — determines whether the
/// active app club matches this team, unlocking contribution routing and
/// supporter registry.
class TeamClubContext {
  const TeamClubContext({
    this.clubId,
    this.isActiveClubTeam = false,
    this.paymentRoute,
    this.message,
  });

  final int? clubId;
  final bool isActiveClubTeam;
  final PartnerPaymentRoute? paymentRoute;
  final String? message;
}

/// A single entry in the club member / top-contributor list.
class ClubMemberEntry {
  const ClubMemberEntry({
    required this.userId,
    required this.displayLabel,
    required this.tier,
    required this.points,
    required this.isCurrentUser,
  });

  final String userId;
  final String displayLabel;
  final String tier;
  final int points;
  final bool isCurrentUser;
}
