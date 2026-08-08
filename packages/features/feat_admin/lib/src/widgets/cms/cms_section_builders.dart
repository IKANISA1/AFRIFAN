// M-2: Extracted section builder methods from CmsContentManagerScreen.
// Each method builds one CMS section tab (News, Quick Actions, Partners, etc.)
part of '../../screens/cms_content_manager_screen.dart';

// ─── Section Selector ──────────────────────────────────────────────────

extension _SectionBuilders on _CmsContentManagerScreenState {
  Widget buildSectionSelector() {
    return Wrap(
      spacing: SpacingTokens.spacing2,
      runSpacing: SpacingTokens.spacing2,
      children: _CmsSection.values.map((section) {
        final selected = section == _section;
        return AfriChoiceChip(
          label: Text(sectionLabel(section)),
          selected: selected,
          // ignore: invalid_use_of_protected_member
          onSelected: (_) => setState(() => _section = section),
        );
      }).toList(),
    );
  }

  Widget buildSectionContent() {
    return switch (_section) {
      _CmsSection.news => buildNewsSection(),
      _CmsSection.quickActions => buildQuickActionsSection(),
      _CmsSection.partners => buildPartnersSection(),
      _CmsSection.services => buildPartnerServicesSection(),
      _CmsSection.competitions => buildPredictionCompetitionsSection(),
      _CmsSection.placements => buildPlacementsSection(),
      _CmsSection.auditLogs => buildAuditLogsSection(),
    };
  }

  String sectionLabel(_CmsSection section) {
    return switch (section) {
      _CmsSection.news => context.afriL10n.adminCmsSectionNews,
      _CmsSection.quickActions => context.afriL10n.adminCmsSectionQuickActions,
      _CmsSection.partners => context.afriL10n.adminCmsSectionPartners,
      _CmsSection.services => context.afriL10n.adminCmsSectionServices,
      _CmsSection.competitions => context.afriL10n.adminCmsSectionPredictions,
      _CmsSection.placements => context.afriL10n.adminCmsSectionPlacements,
      _CmsSection.auditLogs => context.afriL10n.adminCmsSectionAuditLogs,
    };
  }

  // ─── News Section ──────────────────────────────────────────────────────

  Widget buildNewsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: context.afriL10n.adminCmsNewsArticles,
          actionLabel: context.afriL10n.adminCmsAddArticle,
          onAction: _actionsEnabled ? _showCreateArticleDialog : null,
          actionFocusNode: widget.primaryActionFocusNode,
        ),
        const SizedBox(height: SpacingTokens.spacing3),
        if (_articles.isNotEmpty)
          ..._articles.map(
            (article) => Padding(
              padding: const EdgeInsets.only(bottom: SpacingTokens.spacing3),
              child: _ArticleCard(
                article: article,
                onTogglePublish: _actionsEnabled
                    ? () => _togglePublish(
                        article['id'].toString(),
                        article['is_published'] == true,
                      )
                    : null,
              ),
            ),
          ),
      ],
    );
  }

  // ─── Quick Actions Section ─────────────────────────────────────────────

  Widget buildQuickActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: context.afriL10n.adminCmsHomeQuickActions,
          actionLabel: context.afriL10n.adminCmsAddAction,
          onAction: _actionsEnabled ? _showQuickActionDialog : null,
        ),
        const SizedBox(height: SpacingTokens.spacing3),
        if (_quickActions.isNotEmpty)
          ..._quickActions.map(
            (action) => Padding(
              padding: const EdgeInsets.only(bottom: SpacingTokens.spacing3),
              child: _EntityCard(
                title:
                    action['title']?.toString() ??
                    context.afriL10n.adminCmsQuickActionFallback,
                subtitle: context.afriL10n.adminCmsPair(
                  action['route']?.toString() ?? '/',
                  _countryLabel(action['country']),
                ),
                tags: <String>[
                  (action['icon_key']?.toString() ?? 'icon').toUpperCase(),
                  action['is_active'] == true
                      ? context.afriL10n.adminCmsActiveUpper
                      : context.afriL10n.adminCmsInactiveUpper,
                ],
                onEdit: _actionsEnabled
                    ? () => _showQuickActionDialog(action)
                    : null,
                onToggle: _actionsEnabled
                    ? () => _toggleQuickAction(action)
                    : null,
                toggleLabel: action['is_active'] == true
                    ? context.afriL10n.adminCmsDeactivate
                    : context.afriL10n.adminCmsActivate,
              ),
            ),
          ),
      ],
    );
  }

  // ─── Partners Section ──────────────────────────────────────────────────

  Widget buildPartnersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: context.afriL10n.adminCmsPartners,
          actionLabel: context.afriL10n.adminCmsAddPartnerAction,
          onAction: _actionsEnabled ? _showPartnerDialog : null,
        ),
        const SizedBox(height: SpacingTokens.spacing3),
        if (_partners.isNotEmpty)
          ..._partners.map(
            (partner) => Padding(
              padding: const EdgeInsets.only(bottom: SpacingTokens.spacing3),
              child: _EntityCard(
                title:
                    partner['name']?.toString() ??
                    context.afriL10n.adminCmsPartner,
                subtitle: context.afriL10n.adminCmsPair(
                  _cmsCategoryLabel(
                    context,
                    partner['category']?.toString() ?? 'organization',
                  ),
                  partner['country']?.toString() ?? 'RW',
                ),
                body: partner['subtitle']?.toString(),
                tags: <String>[
                  partner['gamification_enabled'] == true
                      ? context.afriL10n.adminCmsGamificationUpper
                      : context.afriL10n.adminCmsDirectUpper,
                  partner['is_active'] == true
                      ? context.afriL10n.adminCmsActiveUpper
                      : context.afriL10n.adminCmsInactiveUpper,
                ],
                onEdit: _actionsEnabled
                    ? () => _showPartnerDialog(partner)
                    : null,
                onToggle: _actionsEnabled
                    ? () => _togglePartner(partner)
                    : null,
                toggleLabel: partner['is_active'] == true
                    ? context.afriL10n.adminCmsDeactivate
                    : context.afriL10n.adminCmsActivate,
              ),
            ),
          ),
      ],
    );
  }

  // ─── Partner Services Section ──────────────────────────────────────────

  Widget buildPartnerServicesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: context.afriL10n.adminCmsPartnerServices,
          actionLabel: context.afriL10n.adminCmsAddService,
          onAction: _actionsEnabled ? _showPartnerServiceDialog : null,
        ),
        const SizedBox(height: SpacingTokens.spacing3),
        if (_partnerServices.isNotEmpty)
          ..._partnerServices.map(
            (service) => Padding(
              padding: const EdgeInsets.only(bottom: SpacingTokens.spacing3),
              child: _EntityCard(
                title:
                    service['title']?.toString() ??
                    context.afriL10n.adminCmsServiceFallback,
                subtitle: context.afriL10n.adminCmsPair(
                  (service['partner'] as Map?)?['name']?.toString() ??
                      context.afriL10n.adminCmsPartner,
                  _cmsCategoryLabel(
                    context,
                    service['category']?.toString() ?? 'general',
                  ),
                ),
                body:
                    '${service['cta_label']?.toString() ?? context.afriL10n.adminCmsCtaPending} → ${service['cta_action']?.toString() ?? context.afriL10n.adminCmsNotAvailable}',
                tags: <String>[
                  _countryLabel(service['country']),
                  service['gamification_enabled'] == true
                      ? context.afriL10n.adminCmsGamificationUpper
                      : context.afriL10n.adminCmsStandardUpper,
                  service['is_active'] == true
                      ? context.afriL10n.adminCmsActiveUpper
                      : context.afriL10n.adminCmsInactiveUpper,
                ],
                onEdit: _actionsEnabled
                    ? () => _showPartnerServiceDialog(service)
                    : null,
                onToggle: _actionsEnabled
                    ? () => _togglePartnerService(service)
                    : null,
                toggleLabel: service['is_active'] == true
                    ? context.afriL10n.adminCmsDeactivate
                    : context.afriL10n.adminCmsActivate,
              ),
            ),
          ),
      ],
    );
  }

  // ─── Prediction Competitions Section ───────────────────────────────────

  Widget buildPredictionCompetitionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: context.afriL10n.adminCmsPredictionCompetitions,
          actionLabel: context.afriL10n.adminCmsAddCompetition,
          onAction: _actionsEnabled ? _showPredictionCompetitionDialog : null,
        ),
        const SizedBox(height: SpacingTokens.spacing3),
        if (_predictionCompetitions.isNotEmpty)
          ..._predictionCompetitions.map(
            (competition) => Padding(
              padding: const EdgeInsets.only(bottom: SpacingTokens.spacing3),
              child: _EntityCard(
                title:
                    competition['name']?.toString() ??
                    context.afriL10n.adminCmsCompetitionFallback,
                subtitle: context.afriL10n.adminCmsCompetitionSummary(
                  competition['competition_kind']?.toString() ??
                      context.afriL10n.adminCmsCompetitionFallback,
                  (competition['fixture_count'] as num?)?.toInt() ?? 0,
                ),
                body: competition['format_notes']?.toString(),
                tags: <String>[
                  competition['highlight_label']?.toString().toUpperCase() ??
                      context.afriL10n.adminCmsCatalog,
                  competition['is_supported'] == true
                      ? context.afriL10n.adminCmsSupported
                      : context.afriL10n.adminCmsInactiveUpper,
                ],
                onEdit: _actionsEnabled
                    ? () => _showPredictionCompetitionDialog(competition)
                    : null,
                onToggle: _actionsEnabled
                    ? () => _togglePredictionCompetition(competition)
                    : null,
                toggleLabel: competition['is_supported'] == true
                    ? context.afriL10n.adminCmsDeactivate
                    : context.afriL10n.adminCmsActivate,
              ),
            ),
          ),
      ],
    );
  }

  // ─── Placements Section ────────────────────────────────────────────────

  Widget buildPlacementsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: context.afriL10n.adminCmsContentBlocks,
          actionLabel: context.afriL10n.adminCmsAddBlock,
          onAction: _actionsEnabled ? _showContentBlockDialog : null,
        ),
        const SizedBox(height: SpacingTokens.spacing3),
        if (_contentBlocks.isNotEmpty)
          ..._contentBlocks.map(
            (block) => Padding(
              padding: const EdgeInsets.only(bottom: SpacingTokens.spacing3),
              child: _EntityCard(
                title:
                    block['block_key']?.toString() ??
                    context.afriL10n.adminCmsContentBlockFallback,
                subtitle: context.afriL10n.adminCmsPair(
                  block['placement_key']?.toString() ??
                      context.afriL10n.adminCmsUnknown,
                  _cmsChannelLabel(
                    context,
                    block['target_channel']?.toString() ?? 'both',
                  ),
                ),
                body:
                    '${block['title']?.toString() ?? ''}\n${(block['content'] as Map?)?['component'] ?? ''}',
                tags: <String>[
                  (block['block_type']?.toString() ?? 'banner').toUpperCase(),
                  block['is_active'] == true
                      ? context.afriL10n.adminCmsActiveUpper
                      : context.afriL10n.adminCmsInactiveUpper,
                ],
                onEdit: _actionsEnabled
                    ? () => _showContentBlockDialog(block)
                    : null,
                onToggle: _actionsEnabled
                    ? () => _toggleContentBlock(block)
                    : null,
                toggleLabel: block['is_active'] == true
                    ? context.afriL10n.adminCmsDeactivate
                    : context.afriL10n.adminCmsActivate,
              ),
            ),
          ),
      ],
    );
  }

  // ─── Audit Logs Section ────────────────────────────────────────────────

  Widget buildAuditLogsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.afriL10n.adminCmsAuditLogs,
          style: TypographyTokens.titleMedium().copyWith(letterSpacing: 1.1),
        ),
        const SizedBox(height: SpacingTokens.spacing3),
        if (_auditLogs.isNotEmpty)
          ..._auditLogs.map((log) {
            final feature = log['feature'] as Map<String, dynamic>?;
            final featureName =
                feature?['display_name'] ??
                feature?['feature_key'] ??
                context.afriL10n.adminCmsUnknownFeature;
            final timestamp = DateTime.tryParse(
              log['created_at']?.toString() ?? '',
            );
            final localTimestamp = timestamp?.toLocal();
            final materialL10n = MaterialLocalizations.of(context);
            final dateStr = localTimestamp == null
                ? context.afriL10n.adminCmsUnknownDate
                : context.afriL10n.adminCmsPair(
                    materialL10n.formatShortDate(localTimestamp),
                    materialL10n.formatTimeOfDay(
                      TimeOfDay.fromDateTime(localTimestamp),
                      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(
                        context,
                      ),
                    ),
                  );

            return Padding(
              padding: const EdgeInsets.only(bottom: SpacingTokens.spacing3),
              child: GlassCard(
                animate: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            log['action']?.toString().toUpperCase() ??
                                context.afriL10n.adminCmsActionFallback,
                            style: TypographyTokens.labelLarge().copyWith(
                              color: ColorTokens.clubAccent,
                            ),
                          ),
                        ),
                        Text(dateStr, style: TypographyTokens.labelSmall()),
                      ],
                    ),
                    const SizedBox(height: SpacingTokens.spacing2),
                    Text(
                      context.afriL10n.adminCmsFeatureName(
                        featureName.toString(),
                      ),
                      style: TypographyTokens.titleMedium(),
                    ),
                    const SizedBox(height: SpacingTokens.spacing1),
                    Text(
                      context.afriL10n.adminCmsActorWithheld,
                      style: TypographyTokens.bodySmall(),
                    ),
                    if (log['notes'] != null) ...[
                      const SizedBox(height: SpacingTokens.spacing2),
                      Text(
                        log['notes'].toString(),
                        style: TypographyTokens.bodyMedium(),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}
