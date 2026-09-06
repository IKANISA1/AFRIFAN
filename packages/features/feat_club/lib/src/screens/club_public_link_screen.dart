import 'package:core_l10n/core_l10n.dart';
import 'package:core_network/core_network.dart';
import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/club_content_providers.dart';
import 'club_content_state_widgets.dart';

final clubPublicWebsiteProvider = Provider<Uri?>((ref) {
  final uri = Uri.tryParse(const String.fromEnvironment('APP_WEBSITE_URL'));
  return uri?.scheme == 'https' && uri!.host.isNotEmpty && uri.userInfo.isEmpty
      ? uri
      : null;
});

final clubPublicLinkProvider = FutureProvider.autoDispose
    .family<String?, String>((ref, path) async {
      if (!validPublicEntityPath(path)) return null;
      final client = ref.watch(supabaseClientProvider);
      final scope = await ClubScopeResolver(client: client).requireResolved();
      final result = await client
          .rpc(
            'resolve_club_public_link_v1',
            params: {'p_club_id': scope.requiredClubId, 'p_source_path': path},
          )
          .timeout(const Duration(seconds: 12));
      final target = result is String ? result : null;
      return target != null && validNativeEntityPath(target) ? target : null;
    });

bool validPublicEntityPath(String path) =>
    !path.contains('%') &&
    !path.contains('..') &&
    RegExp(
      r'^/(squad/(player|staff)|news|shop/product|fanclubs|tickets/match|partners)/[a-zA-Z0-9_-]+$',
    ).hasMatch(path);

bool validNativeEntityPath(String path) => RegExp(
  r'^/(club/(team|news|fixtures|partners)|shop/product|fan-clubs|tickets/detail)/[a-zA-Z0-9_-]+$',
).hasMatch(path);

class ClubPublicLinkScreen extends ConsumerWidget {
  const ClubPublicLinkScreen({super.key, required this.sourcePath});
  final String sourcePath;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.afriL10n;
    final state = ref.watch(clubPublicLinkProvider(sourcePath));
    final destination = state.valueOrNull;
    if (destination != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go(destination);
      });
    }
    final website = ref.watch(clubPublicWebsiteProvider);
    final canOpen = website != null && validPublicEntityPath(sourcePath);
    return AfriScreenScaffold(
      title: state.isLoading || destination != null
          ? l.clubLinkLoading
          : canOpen
          ? l.clubLinkUnavailable
          : l.clubInformationUnavailable,
      actions: [
        AfriIconButton(
          key: const ValueKey<String>('club-refresh-action'),
          icon: AfriIcons.refresh,
          tooltip: l.clubRefresh,
          onTap: () => ref.invalidate(clubPublicLinkProvider(sourcePath)),
        ),
      ],
      child: ValueListenableBuilder<bool>(
        valueListenable: ConnectivityService.onlineNotifier,
        builder: (context, isOnline, _) {
          if (!isOnline) {
            return ClubContentFailureView(
              failure: const ClubContentFailure(ClubContentFailureKind.offline),
              onRetry: () => ref.invalidate(clubPublicLinkProvider(sourcePath)),
            );
          }
          if ((state.isLoading && !state.hasValue) || destination != null) {
            return const AfriSkeletonList();
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (state.isRefreshing) ...[
                const ClubContentStatusBanner(refreshing: true, failure: null),
                const SizedBox(height: SpacingTokens.sectionGap),
              ],
              if (state.hasError) ...[
                ClubContentFailureView(
                  failure: ClubContentFailure.fromError(
                    state.error!,
                    isOnline: true,
                  ),
                  compact: true,
                ),
                const SizedBox(height: SpacingTokens.sectionGap),
              ],
              Text(
                canOpen
                    ? l.clubLinkUnavailableBody
                    : l.clubLinkedRecordLoadMessage,
                style: TypographyTokens.bodyLarge(),
              ),
              const SizedBox(height: SpacingTokens.sectionGap),
              if (canOpen)
                AfriButton(
                  label: l.clubOpenWebsite,
                  onTap: () async {
                    final opened = await launchUrl(
                      website.replace(
                        path: sourcePath,
                        query: '',
                        fragment: '',
                      ),
                      mode: LaunchMode.externalApplication,
                    );
                    if (!opened && context.mounted) {
                      AfriToast.error(context, l.genericError);
                    }
                  },
                ),
              const SizedBox(height: SpacingTokens.spacing3),
              AfriButton(
                label: l.clubLinkRetry,
                variant: AfriButtonVariant.secondary,
                onTap: () => ref.invalidate(clubPublicLinkProvider(sourcePath)),
              ),
            ],
          );
        },
      ),
    );
  }
}
