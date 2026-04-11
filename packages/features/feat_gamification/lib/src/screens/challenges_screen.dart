import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ChallengesScreen extends ConsumerStatefulWidget {
  const ChallengesScreen({super.key});

  @override
  ConsumerState<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends ConsumerState<ChallengesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: 3,
    vsync: this,
  );

  List<_ChallengeData> _daily = const <_ChallengeData>[];
  List<_ChallengeData> _weekly = const <_ChallengeData>[];
  List<_ChallengeData> _seasonal = const <_ChallengeData>[];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadChallenges();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadChallenges() async {
    final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (userId == null) {
      if (!mounted) return;
      setState(() {
        _daily = const <_ChallengeData>[];
        _weekly = const <_ChallengeData>[];
        _seasonal = const <_ChallengeData>[];
        _isLoading = false;
        _error = null;
      });
      return;
    }

    try {
      final client = ref.read(supabaseClientProvider);
      final resolver = ClubScopeResolver(client: client);
      final scope = await resolver.requireResolved();

      final profileFuture = client
          .from('user_private_contacts')
          .select('momo_number')
          .eq('user_id', userId)
          .maybeSingle();
      var membershipFuture = client
          .from('fan_memberships')
          .select('points')
          .eq('user_id', userId)
          .limit(1);
      membershipFuture = resolver.apply(membershipFuture, scope);
      final clubsFuture = client
          .from('fan_club_members')
          .select('club_id')
          .eq('user_id', userId)
          .limit(10);
      var groupsFuture = client
          .from('contribution_groups')
          .select('id')
          .eq('creator_id', userId)
          .limit(10);
      groupsFuture = resolver.apply(groupsFuture, scope);
      var ticketsFuture = client
          .from('tickets')
          .select('id')
          .eq('user_id', userId)
          .limit(10);
      ticketsFuture = resolver.apply(ticketsFuture, scope);

      final results = await Future.wait([
        profileFuture,
        membershipFuture.maybeSingle(),
        clubsFuture,
        groupsFuture,
        ticketsFuture,
      ]);

      final privateContact = results[0] as Map<String, dynamic>?;
      final membership = results[1] as Map<String, dynamic>?;
      final clubs = List<Map<String, dynamic>>.from(results[2] as List);
      final groups = List<Map<String, dynamic>>.from(results[3] as List);
      final tickets = List<Map<String, dynamic>>.from(results[4] as List);

      final xp = (membership?['points'] as num?)?.toInt() ?? 0;
      final hasMomo =
          (privateContact?['momo_number']?.toString().trim().isNotEmpty ??
          false);
      final joinedClubCount = clubs.length;
      final createdGroupCount = groups.length;
      final ticketCount = tickets.length;

      if (!mounted) return;
      setState(() {
        _daily = <_ChallengeData>[
          _ChallengeData(
            title: 'Link your MOMO profile',
            reward: '+150 XP',
            progress: hasMomo ? 1 : 0,
            progressLabel: hasMomo ? 'Completed' : 'Profile setup pending',
          ),
          _ChallengeData(
            title: 'Join your first fan club',
            reward: '+200 XP',
            progress: joinedClubCount > 0 ? 1 : 0,
            progressLabel: joinedClubCount > 0
                ? '$joinedClubCount club joined'
                : 'No fan club joined yet',
          ),
        ];
        _weekly = <_ChallengeData>[
          _ChallengeData(
            title: 'Create a supporter circle',
            reward: '+350 XP',
            progress: createdGroupCount > 0 ? 1 : 0,
            progressLabel: createdGroupCount > 0
                ? '$createdGroupCount circles created'
                : 'No circles created yet',
          ),
          _ChallengeData(
            title: 'Buy your first live ticket',
            reward: '+500 XP',
            progress: ticketCount > 0 ? 1 : 0,
            progressLabel: ticketCount > 0
                ? '$ticketCount tickets issued'
                : 'No ticket issued yet',
          ),
        ];
        _seasonal = <_ChallengeData>[
          _ChallengeData(
            title: 'Reach 5,000 supporter XP',
            reward: '+1,000 XP',
            progress: (xp / 5000).clamp(0.0, 1.0),
            progressLabel: '$xp / 5,000 XP',
          ),
          _ChallengeData(
            title: 'Reach 15,000 supporter XP',
            reward: '+2,500 XP',
            progress: (xp / 15000).clamp(0.0, 1.0),
            progressLabel: '$xp / 15,000 XP',
          ),
        ];
        _isLoading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Challenges are temporarily unavailable.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'CHALLENGES',
          style: TypographyTokens.monolithFont(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.6,
          ),
        ),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'DAILY'),
            Tab(text: 'WEEKLY'),
            Tab(text: 'SEASONAL'),
          ],
        ),
      ),
      body: _isLoading
          ? const Padding(
              padding: EdgeInsets.all(SpacingTokens.spacing6),
              child: AfriSkeletonList(),
            )
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(SpacingTokens.spacing6),
                child: AfriStateView.offline(
                  title: 'Challenges unavailable',
                  message: _error!,
                  actionLabel: 'Retry',
                  onAction: _loadChallenges,
                ),
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildList(_daily),
                _buildList(_weekly),
                _buildList(_seasonal),
              ],
            ),
    );
  }

  Widget _buildList(List<_ChallengeData> items) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(SpacingTokens.spacing6),
          child: GlassCard(
            animate: false,
            child: Text(
              'Challenges appear once your supporter profile is active.',
              style: TypographyTokens.bodyMedium(),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(SpacingTokens.spacing6),
      children: items
          .map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: SpacingTokens.spacing3),
              child: _ChallengeCard(data: item),
            );
          })
          .toList(growable: false),
    );
  }
}

class _ChallengeData {
  const _ChallengeData({
    required this.title,
    required this.reward,
    required this.progress,
    required this.progressLabel,
  });

  final String title;
  final String reward;
  final double progress;
  final String progressLabel;
}

class _ChallengeCard extends StatelessWidget {
  const _ChallengeCard({required this.data});

  final _ChallengeData data;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      animate: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.title.toUpperCase(),
            style: TypographyTokens.monolithFont(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: ColorTokens.onSurface,
            ),
          ),
          const SizedBox(height: SpacingTokens.spacing2),
          Text(data.reward, style: TypographyTokens.bodyLarge()),
          const SizedBox(height: SpacingTokens.spacing3),
          LinearProgressIndicator(
            value: data.progress,
            color: Theme.of(context).colorScheme.primary,
            backgroundColor: ColorTokens.surfaceContainerHighest,
            minHeight: 8,
            borderRadius: BorderRadius.circular(999),
          ),
          const SizedBox(height: SpacingTokens.spacing2),
          Text(data.progressLabel, style: TypographyTokens.bodySmall()),
        ],
      ),
    );
  }
}
