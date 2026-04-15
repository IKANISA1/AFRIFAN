import 'dart:async';

import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

class CreateFanClubScreen extends ConsumerStatefulWidget {
  const CreateFanClubScreen({super.key});

  @override
  ConsumerState<CreateFanClubScreen> createState() =>
      _CreateFanClubScreenState();
}

class _CreateFanClubScreenState extends ConsumerState<CreateFanClubScreen> {
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _isLoadingContext = true;
  bool _isSubmitting = false;
  String? _partnerId;
  int? _clubId;
  List<String> _regionSuggestions = const <String>[];

  @override
  void initState() {
    super.initState();
    unawaited(_loadFormContext());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadFormContext() async {
    try {
      final client = ref.read(supabaseClientProvider);
      final scope = await ClubScopeResolver(client: client).requireResolved();
      final partnerId = await _resolvePartnerId(client, scope);
      final suggestions = await _loadRegionSuggestions(client, scope);

      if (!mounted) return;
      setState(() {
        _clubId = scope.clubId;
        _partnerId = partnerId;
        _regionSuggestions = suggestions;
        _isLoadingContext = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingContext = false);
    }
  }

  Future<List<String>> _loadRegionSuggestions(
    SupabaseClient client,
    ClubScope scope,
  ) async {
    final regions = <String>{};

    if (scope.clubId != null) {
      try {
        final clubRow = await client
            .from('african_football_clubs')
            .select('region')
            .eq('id', scope.clubId!)
            .maybeSingle();
        final primaryRegion = _trimmedOrNull(clubRow?['region']);
        if (primaryRegion != null) {
          regions.add(primaryRegion);
        }
      } catch (_) {
        // Suggestions are best-effort only.
      }
    }

    try {
      var query = client.from('fan_clubs').select('region');
      if (scope.clubId != null) {
        query = query.eq('club_id', scope.clubId!);
      } else if (scope.partnerId.isNotEmpty) {
        query = query.eq('partner_id', scope.partnerId);
      }
      final rows = await query.eq('is_active', true);
      for (final row in rows) {
        final region = _trimmedOrNull(row['region']);
        if (region != null) {
          regions.add(region);
        }
      }
    } catch (_) {
      // Suggestions are best-effort only.
    }

    final sorted = regions.toList(growable: false)
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return sorted;
  }

  Future<String?> _resolvePartnerId(
    SupabaseClient client,
    ClubScope scope,
  ) async {
    final hintedPartnerId = _trimmedOrNull(scope.partnerId);
    if (hintedPartnerId != null && _looksLikeUuid(hintedPartnerId)) {
      return hintedPartnerId;
    }

    const sourceTables = <String>[
      'fan_clubs',
      'membership_packages',
      'matches',
      'initiatives',
      'partner_payment_routes',
    ];

    for (final table in sourceTables) {
      try {
        var query = client.from(table).select('partner_id');
        if (scope.clubId != null) {
          query = query.eq('club_id', scope.clubId!);
        } else if (hintedPartnerId != null) {
          query = query.eq('partner_id', hintedPartnerId);
        } else {
          continue;
        }

        final row = await query.limit(1).maybeSingle();
        final partnerId = _trimmedOrNull(row?['partner_id']);
        if (partnerId != null) {
          return partnerId;
        }
      } catch (_) {
        // Keep probing other scoped tables.
      }
    }

    return null;
  }

  Future<void> _submit() async {
    final name = _trimmedOrNull(_nameController.text);
    final region = _trimmedOrNull(_locationController.text);
    final description = _trimmedOrNull(_descriptionController.text);

    if (name == null || region == null || description == null) {
      _showSnackBar(
        'Enter a name, region, and description before submitting.',
        isError: true,
      );
      return;
    }

    final partnerId = _partnerId;
    final clubId = _clubId;
    final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (partnerId == null || clubId == null) {
      _showSnackBar(
        'This club context is not ready yet. Try again in a moment.',
        isError: true,
      );
      return;
    }
    if (userId == null || userId.isEmpty) {
      context.go('/onboarding');
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref.read(supabaseClientProvider).from('fan_clubs').insert({
        'partner_id': partnerId,
        'club_id': clubId,
        'name': name,
        'region': region,
        'description': description,
        'is_active': false,
      });

      if (!mounted) return;
      unawaited(HapticFeedback.mediumImpact());
      _showSnackBar('Fan club request submitted for admin review.');
      context.pop(true);
    } catch (error) {
      final message = error.toString().toLowerCase().contains('unique')
          ? 'A fan club with this name already exists for the current club.'
          : 'Could not submit this fan club request right now.';
      _showSnackBar(message, isError: true);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? ColorTokens.error : ColorTokens.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = ClubConfigScope.maybeOf(context);
    final appName = config?.appName ?? RuntimeBranding.displayAppName;
    final country = config?.country ?? 'your country';

    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'START A FAN CLUB',
          style: TypographyTokens.monolithFont(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.6,
          ),
        ),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(AfriIcons.back),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(SpacingTokens.spacing6),
        child: Column(
          children: [
            _FieldCard(
              label: 'CLUB NAME',
              child: TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: '$appName Supporters',
                ),
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing3),
            _FieldCard(
              label: 'LOCATION / REGION',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _locationController,
                    decoration: InputDecoration(
                      hintText: 'City or region, $country',
                    ),
                  ),
                  if (_regionSuggestions.isNotEmpty) ...[
                    const SizedBox(height: SpacingTokens.spacing3),
                    Text(
                      'Suggested from existing fan clubs',
                      style: TypographyTokens.bodySmall(),
                    ),
                    const SizedBox(height: SpacingTokens.spacing2),
                    Wrap(
                      spacing: SpacingTokens.spacing2,
                      runSpacing: SpacingTokens.spacing2,
                      children: _regionSuggestions
                          .map(
                            (region) => ActionChip(
                              label: Text(region),
                              onPressed: () =>
                                  _locationController.text = region,
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing3),
            _FieldCard(
              label: 'DESCRIPTION',
              child: TextField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Tell supporters what this fan club is about.',
                ),
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing3),
            GlassCard(
              animate: false,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: ColorTokens.clubAccent,
                  ),
                  const SizedBox(width: SpacingTokens.spacing3),
                  Expanded(
                    child: Text(
                      _isLoadingContext
                          ? 'Loading the active club context.'
                          : _partnerId == null || _clubId == null
                          ? 'The app could not resolve the active club context for this request.'
                          : 'Requests go to admin review before the fan club becomes public.',
                      style: TypographyTokens.bodyMedium(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing6),
            AfriButton(
              label: _isSubmitting
                  ? 'SUBMITTING...'
                  : _isLoadingContext
                  ? 'LOADING CONTEXT...'
                  : 'REQUEST APPROVAL',
              variant: AfriButtonVariant.clay,
              enabled: !_isSubmitting && !_isLoadingContext,
              isLoading: _isSubmitting,
              onTap: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldCard extends StatelessWidget {
  const _FieldCard({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      animate: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TypographyTokens.labelSmall()),
          const SizedBox(height: SpacingTokens.spacing2),
          child,
        ],
      ),
    );
  }
}

String? _trimmedOrNull(Object? value) {
  final trimmed = value?.toString().trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}

bool _looksLikeUuid(String value) {
  return RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  ).hasMatch(value);
}
