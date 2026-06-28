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
      _CmsSection.news => 'News',
      _CmsSection.quickActions => 'Quick Actions',
      _CmsSection.partners => 'Partners',
      _CmsSection.services => 'Services',
      _CmsSection.competitions => 'Predictions',
      _CmsSection.placements => 'Placements',
      _CmsSection.auditLogs => 'Audit Logs',
    };
  }

  // ─── Error State ───────────────────────────────────────────────────────

  Widget buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SpacingTokens.spacing8),
        child: GlassCard(
          animate: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(AfriIcons.statusError, size: 48),
              const SizedBox(height: SpacingTokens.spacing4),
              Text(
                'Failed to load content manager',
                style: TypographyTokens.titleLarge(),
              ),
              const SizedBox(height: SpacingTokens.spacing3),
              Text(
                _error ?? 'Unknown error',
                style: TypographyTokens.bodyMedium(),
              ),
              const SizedBox(height: SpacingTokens.spacing5),
              AfriButton(label: 'RETRY', onTap: _loadContent),
            ],
          ),
        ),
      ),
    );
  }

  // ─── News Section ──────────────────────────────────────────────────────

  Widget buildNewsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'News Articles',
          actionLabel: 'ADD ARTICLE',
          onAction: _showCreateArticleDialog,
        ),
        const SizedBox(height: SpacingTokens.spacing3),
        if (_articles.isNotEmpty)
          ..._articles.map(
            (article) => Padding(
              padding: const EdgeInsets.only(bottom: SpacingTokens.spacing3),
              child: _ArticleCard(
                article: article,
                onTogglePublish: () => _togglePublish(
                  article['id'].toString(),
                  article['is_published'] == true,
                ),
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
          title: 'Home Quick Actions',
          actionLabel: 'ADD ACTION',
          onAction: _showQuickActionDialog,
        ),
        const SizedBox(height: SpacingTokens.spacing3),
        if (_quickActions.isNotEmpty)
          ..._quickActions.map(
            (action) => Padding(
              padding: const EdgeInsets.only(bottom: SpacingTokens.spacing3),
              child: _EntityCard(
                title: action['title']?.toString() ?? 'Quick action',
                subtitle:
                    '${action['route']?.toString() ?? '/'} • ${_countryLabel(action['country'])}',
                tags: <String>[
                  (action['icon_key']?.toString() ?? 'icon').toUpperCase(),
                  action['is_active'] == true ? 'ACTIVE' : 'INACTIVE',
                ],
                onEdit: () => _showQuickActionDialog(action),
                onToggle: () => _toggleQuickAction(action),
                toggleLabel: action['is_active'] == true
                    ? 'DEACTIVATE'
                    : 'ACTIVATE',
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
          title: 'Partners',
          actionLabel: 'ADD PARTNER',
          onAction: _showPartnerDialog,
        ),
        const SizedBox(height: SpacingTokens.spacing3),
        if (_partners.isNotEmpty)
          ..._partners.map(
            (partner) => Padding(
              padding: const EdgeInsets.only(bottom: SpacingTokens.spacing3),
              child: _EntityCard(
                title: partner['name']?.toString() ?? 'Partner',
                subtitle:
                    '${partner['category']?.toString() ?? 'organization'} • ${partner['country']?.toString() ?? 'RW'}',
                body: partner['subtitle']?.toString(),
                tags: <String>[
                  partner['gamification_enabled'] == true
                      ? 'GAMIFICATION'
                      : 'DIRECT',
                  partner['is_active'] == true ? 'ACTIVE' : 'INACTIVE',
                ],
                onEdit: () => _showPartnerDialog(partner),
                onToggle: () => _togglePartner(partner),
                toggleLabel: partner['is_active'] == true
                    ? 'DEACTIVATE'
                    : 'ACTIVATE',
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
          title: 'Partner Services',
          actionLabel: 'ADD SERVICE',
          onAction: _showPartnerServiceDialog,
        ),
        const SizedBox(height: SpacingTokens.spacing3),
        if (_partnerServices.isNotEmpty)
          ..._partnerServices.map(
            (service) => Padding(
              padding: const EdgeInsets.only(bottom: SpacingTokens.spacing3),
              child: _EntityCard(
                title: service['title']?.toString() ?? 'Service',
                subtitle:
                    '${(service['partner'] as Map?)?['name'] ?? 'Partner'} • ${service['category']?.toString() ?? 'general'}',
                body:
                    '${service['cta_label']?.toString() ?? 'CTA pending'} → ${service['cta_action']?.toString() ?? 'n/a'}',
                tags: <String>[
                  _countryLabel(service['country']),
                  service['gamification_enabled'] == true
                      ? 'GAMIFICATION'
                      : 'STANDARD',
                  service['is_active'] == true ? 'ACTIVE' : 'INACTIVE',
                ],
                onEdit: () => _showPartnerServiceDialog(service),
                onToggle: () => _togglePartnerService(service),
                toggleLabel: service['is_active'] == true
                    ? 'DEACTIVATE'
                    : 'ACTIVATE',
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
          title: 'Prediction Competitions',
          actionLabel: 'ADD COMPETITION',
          onAction: _showPredictionCompetitionDialog,
        ),
        const SizedBox(height: SpacingTokens.spacing3),
        if (_predictionCompetitions.isNotEmpty)
          ..._predictionCompetitions.map(
            (competition) => Padding(
              padding: const EdgeInsets.only(bottom: SpacingTokens.spacing3),
              child: _EntityCard(
                title: competition['name']?.toString() ?? 'Competition',
                subtitle:
                    '${competition['competition_kind']?.toString() ?? 'competition'} • fixtures ${(competition['fixture_count'] as num?)?.toInt() ?? 0}',
                body: competition['format_notes']?.toString(),
                tags: <String>[
                  competition['highlight_label']?.toString().toUpperCase() ??
                      'CATALOG',
                  competition['is_supported'] == true
                      ? 'SUPPORTED'
                      : 'INACTIVE',
                ],
                onEdit: () => _showPredictionCompetitionDialog(competition),
                onToggle: () => _togglePredictionCompetition(competition),
                toggleLabel: competition['is_supported'] == true
                    ? 'DEACTIVATE'
                    : 'ACTIVATE',
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
          title: 'Platform Content Blocks',
          actionLabel: 'ADD BLOCK',
          onAction: _showContentBlockDialog,
        ),
        const SizedBox(height: SpacingTokens.spacing3),
        if (_contentBlocks.isNotEmpty)
          ..._contentBlocks.map(
            (block) => Padding(
              padding: const EdgeInsets.only(bottom: SpacingTokens.spacing3),
              child: _EntityCard(
                title: block['block_key']?.toString() ?? 'Content block',
                subtitle:
                    '${block['placement_key']?.toString() ?? 'unknown'} • ${block['target_channel']?.toString() ?? 'both'}',
                body:
                    '${block['title']?.toString() ?? ''}\n${(block['content'] as Map?)?['component'] ?? ''}',
                tags: <String>[
                  (block['block_type']?.toString() ?? 'banner').toUpperCase(),
                  block['is_active'] == true ? 'ACTIVE' : 'INACTIVE',
                ],
                onEdit: () => _showContentBlockDialog(block),
                onToggle: () => _toggleContentBlock(block),
                toggleLabel: block['is_active'] == true
                    ? 'DEACTIVATE'
                    : 'ACTIVATE',
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
          'FEATURE MANAGEMENT AUDIT LOGS',
          style: TypographyTokens.titleMedium().copyWith(letterSpacing: 1.1),
        ),
        const SizedBox(height: SpacingTokens.spacing3),
        if (_auditLogs.isNotEmpty)
          ..._auditLogs.map((log) {
            final feature = log['feature'] as Map<String, dynamic>?;
            final featureName =
                feature?['display_name'] ??
                feature?['feature_key'] ??
                'Unknown Feature';
            final timestamp = DateTime.tryParse(
              log['created_at']?.toString() ?? '',
            );
            final dateStr = timestamp != null
                ? DateFormat('dd MMM, HH:mm').format(timestamp)
                : 'Unknown date';

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
                            log['action']?.toString().toUpperCase() ?? 'ACTION',
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
                      'Feature: $featureName',
                      style: TypographyTokens.titleMedium(),
                    ),
                    const SizedBox(height: SpacingTokens.spacing1),
                    Text(
                      'Changed by: ${log['changed_by'] ?? 'System'}',
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
