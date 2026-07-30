import 'dart:async';

import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../admin_cms_controller.dart';
import '../repositories/admin_repository.dart';
part '../widgets/cms/cms_widgets.dart';
part '../widgets/cms/cms_section_builders.dart';

enum _CmsSection {
  news,
  quickActions,
  partners,
  services,
  competitions,
  placements,
  auditLogs,
}

class CmsContentManagerScreen extends ConsumerStatefulWidget {
  const CmsContentManagerScreen({this.primaryActionFocusNode, super.key});

  final FocusNode? primaryActionFocusNode;

  @override
  ConsumerState<CmsContentManagerScreen> createState() =>
      _CmsContentManagerScreenState();
}

class _CmsContentManagerScreenState
    extends ConsumerState<CmsContentManagerScreen> {
  static const List<String> _countryOptions = <String>[
    'GLOBAL',
    'RW',
    'CD',
    'ZM',
  ];
  static const List<String> _partnerCategories = <String>[
    'organization',
    'bank',
    'football',
  ];
  static const List<String> _serviceCategories = <String>[
    'general',
    'bank',
    'community',
    'insurance',
    'mobility',
  ];
  static const List<String> _targetChannels = <String>['mobile', 'web', 'both'];
  static const List<String> _placementKeys = <String>[
    'home_hero',
    'home_top',
    'home_mid',
    'home_bottom',
    'home_footer',
  ];

  _CmsSection _section = _CmsSection.news;
  AdminCmsSnapshot _snapshot = const AdminCmsSnapshot.empty();
  bool _cmsLoading = true;

  Future<void> _loadContent() async {
    await ref.read(adminCmsProvider.notifier).refresh();
  }

  List<Map<String, dynamic>> get _articles => _snapshot.articles;
  List<Map<String, dynamic>> get _quickActions => _snapshot.quickActions;
  List<Map<String, dynamic>> get _partners => _snapshot.partners;
  List<Map<String, dynamic>> get _partnerServices => _snapshot.partnerServices;
  List<Map<String, dynamic>> get _predictionCompetitions =>
      _snapshot.predictionCompetitions;
  List<Map<String, dynamic>> get _competitionCatalog =>
      _snapshot.competitionCatalog;
  List<Map<String, dynamic>> get _contentBlocks => _snapshot.contentBlocks;
  List<Map<String, dynamic>> get _platformFeatures =>
      _snapshot.platformFeatures;
  List<Map<String, dynamic>> get _auditLogs => _snapshot.auditLogs;
  bool get _actionsEnabled => _snapshot.actionsEnabled && !_cmsLoading;

  Future<void> _togglePublish(String articleId, bool currentlyPublished) async {
    await _runCmsMutation(
      (repo) => repo.updateNewsArticle(articleId, {
        'is_published': !currentlyPublished,
        if (!currentlyPublished)
          'published_at': DateTime.now().toUtc().toIso8601String(),
      }),
    );
  }

  Future<void> _toggleQuickAction(Map<String, dynamic> action) async {
    await _runCmsMutation(
      (repo) => repo.updateQuickAction(action['id'].toString(), {
        'is_active': action['is_active'] != true,
      }),
    );
  }

  Future<void> _togglePartner(Map<String, dynamic> partner) async {
    await _runCmsMutation(
      (repo) => repo.updatePartner(partner['id'].toString(), {
        'is_active': partner['is_active'] != true,
      }),
    );
  }

  Future<void> _togglePartnerService(Map<String, dynamic> service) async {
    await _runCmsMutation(
      (repo) => repo.updatePartnerService(service['id'].toString(), {
        'is_active': service['is_active'] != true,
      }),
    );
  }

  Future<void> _togglePredictionCompetition(Map<String, dynamic> item) async {
    await _runCmsMutation(
      (repo) => repo.updatePredictionSupportedCompetition(
        item['support_id'].toString(),
        <String, dynamic>{'is_active': item['is_supported'] != true},
      ),
    );
  }

  Future<void> _toggleContentBlock(Map<String, dynamic> block) async {
    await _runCmsMutation(
      (repo) => repo.updatePlatformContentBlock(block['id'].toString(), {
        'is_active': block['is_active'] != true,
      }),
    );
  }

  void _showContentBlockDialog([Map<String, dynamic>? existing]) {
    final blockKeyController = TextEditingController(
      text: existing?['block_key']?.toString() ?? '',
    );
    final blockTypeController = TextEditingController(
      text: existing?['block_type']?.toString() ?? 'banner',
    );
    final titleController = TextEditingController(
      text: existing?['title']?.toString() ?? '',
    );
    final subtitleController = TextEditingController(
      text: existing?['subtitle']?.toString() ?? '',
    );
    final contentComponentController = TextEditingController(
      text: (existing?['content'] as Map?)?['component']?.toString() ?? '',
    );
    final sortOrderController = TextEditingController(
      text: '${(existing?['sort_order'] as num?)?.toInt() ?? 0}',
    );

    var targetChannel = existing?['target_channel']?.toString() ?? 'both';
    var placementKey = existing?['placement_key']?.toString() ?? 'home_hero';
    var selectedFeatureId = existing?['feature_id']?.toString();
    var isActive = existing?['is_active'] != false;

    unawaited(
      showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) {
            return AfriAlertDialog(
              title: Text(
                existing == null ? 'ADD CONTENT BLOCK' : 'EDIT CONTENT BLOCK',
                style: TypographyTokens.titleLarge(),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _DialogTextField(
                      controller: blockKeyController,
                      hint: 'Block key (e.g. home_hero_1)',
                    ),
                    const SizedBox(height: SpacingTokens.spacing3),
                    _DialogTextField(
                      controller: blockTypeController,
                      hint: 'Block type (e.g. banner)',
                    ),
                    const SizedBox(height: SpacingTokens.spacing3),
                    AfriDropdownField<String>(
                      initialValue: targetChannel,
                      label: 'Target Channel',
                      items: _targetChannels
                          .map(
                            (item) => DropdownMenuItem<String>(
                              value: item,
                              child: Text(item),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() => targetChannel = value);
                      },
                    ),
                    const SizedBox(height: SpacingTokens.spacing3),
                    AfriDropdownField<String>(
                      initialValue: _placementKeys.contains(placementKey)
                          ? placementKey
                          : null,
                      label: 'Placement Key',
                      items: _placementKeys
                          .map(
                            (item) => DropdownMenuItem<String>(
                              value: item,
                              child: Text(item),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() => placementKey = value);
                      },
                    ),
                    const SizedBox(height: SpacingTokens.spacing3),
                    _DialogTextField(
                      controller: titleController,
                      hint: 'Title',
                    ),
                    const SizedBox(height: SpacingTokens.spacing3),
                    _DialogTextField(
                      controller: subtitleController,
                      hint: 'Subtitle',
                    ),
                    const SizedBox(height: SpacingTokens.spacing3),
                    _DialogTextField(
                      controller: contentComponentController,
                      hint: 'Content Component Name',
                    ),
                    const SizedBox(height: SpacingTokens.spacing3),
                    AfriDropdownField<String>(
                      initialValue: selectedFeatureId,
                      label: 'Feature',
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('None'),
                        ),
                        ..._platformFeatures.map(
                          (feature) => DropdownMenuItem<String>(
                            value: feature['id']?.toString(),
                            child: Text(
                              feature['display_name']?.toString() ??
                                  feature['feature_key']?.toString() ??
                                  'Feature',
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        setDialogState(() => selectedFeatureId = value);
                      },
                    ),
                    const SizedBox(height: SpacingTokens.spacing3),
                    _DialogTextField(
                      controller: sortOrderController,
                      hint: 'Sort order',
                      keyboardType: TextInputType.number,
                    ),
                    AfriSwitchListTile(
                      value: isActive,
                      onChanged: (value) =>
                          setDialogState(() => isActive = value),
                      title: const Text('Active'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              actions: [
                AfriTextButton(
                  onPressed: () => dialogContext.pop(),
                  child: const Text('CANCEL'),
                ),
                AfriTextButton(
                  onPressed: () async {
                    final blockKey = blockKeyController.text.trim();
                    if (blockKey.isEmpty) return;

                    final payload = <String, dynamic>{
                      'block_key': blockKey,
                      'block_type': blockTypeController.text.trim(),
                      'target_channel': targetChannel,
                      'placement_key': placementKey,
                      'title': _trimToNull(titleController.text),
                      'subtitle': _trimToNull(subtitleController.text),
                      'content': {
                        'component': _trimToNull(
                          contentComponentController.text,
                        ),
                      },
                      'feature_id': selectedFeatureId,
                      'sort_order':
                          int.tryParse(sortOrderController.text.trim()) ?? 0,
                      'is_active': isActive,
                    };

                    dialogContext.pop();
                    await _runCmsMutation((repo) async {
                      if (existing == null) {
                        await repo.createPlatformContentBlock(
                          blockKey: payload['block_key'] as String,
                          blockType: payload['block_type'] as String,
                          targetChannel: payload['target_channel'] as String,
                          placementKey: payload['placement_key'] as String,
                          title: payload['title'] as String?,
                          subtitle: payload['subtitle'] as String?,
                          content:
                              payload['content'] as Map<String, dynamic>? ??
                              const {},
                          featureId: payload['feature_id'] as String?,
                          sortOrder: payload['sort_order'] as int?,
                          isActive: isActive,
                        );
                      } else {
                        await repo.updatePlatformContentBlock(
                          existing['id'].toString(),
                          payload,
                        );
                      }
                    });
                  },
                  child: Text(existing == null ? 'CREATE' : 'SAVE'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showCreateArticleDialog() {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();

    unawaited(
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AfriAlertDialog(
          title: Text('NEW ARTICLE', style: TypographyTokens.titleLarge()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AfriInputField(
                controller: titleController,
                hint: 'Article title',
              ),
              const SizedBox(height: SpacingTokens.spacing3),
              AfriInputField(
                controller: bodyController,
                maxLines: 3,
                hint: 'Article body',
              ),
            ],
          ),
          actions: [
            AfriTextButton(
              onPressed: () => dialogContext.pop(),
              child: const Text('CANCEL'),
            ),
            AfriTextButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty) return;
                dialogContext.pop();
                await _runCmsMutation(
                  (repo) async => repo.createNewsArticle(
                    title: titleController.text.trim(),
                    body: bodyController.text.trim(),
                  ),
                );
              },
              child: const Text('CREATE'),
            ),
          ],
        ),
      ),
    );
  }

  void _showQuickActionDialog([Map<String, dynamic>? existing]) {
    final actionKeyController = TextEditingController(
      text: existing?['action_key']?.toString() ?? '',
    );
    final titleController = TextEditingController(
      text: existing?['title']?.toString() ?? '',
    );
    final subtitleController = TextEditingController(
      text: existing?['subtitle']?.toString() ?? '',
    );
    final routeController = TextEditingController(
      text: existing?['route']?.toString() ?? '',
    );
    final iconKeyController = TextEditingController(
      text: existing?['icon_key']?.toString() ?? '',
    );
    final emojiController = TextEditingController(
      text: existing?['emoji']?.toString() ?? '',
    );
    final sortOrderController = TextEditingController(
      text: '${(existing?['sort_order'] as num?)?.toInt() ?? 0}',
    );
    var selectedCountry = _countryLabel(existing?['country']);
    var isActive = existing?['is_active'] != false;

    unawaited(
      showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) {
            return AfriAlertDialog(
              title: Text(
                existing == null ? 'ADD QUICK ACTION' : 'EDIT QUICK ACTION',
                style: TypographyTokens.titleLarge(),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _DialogTextField(
                      controller: actionKeyController,
                      hint: 'Action key',
                    ),
                    const SizedBox(height: SpacingTokens.spacing3),
                    _DialogTextField(
                      controller: titleController,
                      hint: 'Title',
                    ),
                    const SizedBox(height: SpacingTokens.spacing3),
                    _DialogTextField(
                      controller: subtitleController,
                      hint: 'Subtitle',
                    ),
                    const SizedBox(height: SpacingTokens.spacing3),
                    _DialogTextField(
                      controller: routeController,
                      hint: 'Route',
                    ),
                    const SizedBox(height: SpacingTokens.spacing3),
                    _DialogTextField(
                      controller: iconKeyController,
                      hint: 'Icon key',
                    ),
                    const SizedBox(height: SpacingTokens.spacing3),
                    _DialogTextField(
                      controller: emojiController,
                      hint: 'Emoji',
                    ),
                    const SizedBox(height: SpacingTokens.spacing3),
                    _DialogTextField(
                      controller: sortOrderController,
                      hint: 'Sort order',
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: SpacingTokens.spacing3),
                    AfriDropdownField<String>(
                      initialValue: selectedCountry,
                      label: 'Country',
                      items: _countryOptions
                          .map(
                            (country) => DropdownMenuItem<String>(
                              value: country,
                              child: Text(country),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() => selectedCountry = value);
                      },
                    ),
                    AfriSwitchListTile(
                      value: isActive,
                      onChanged: (value) =>
                          setDialogState(() => isActive = value),
                      title: const Text('Active'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              actions: [
                AfriTextButton(
                  onPressed: () => dialogContext.pop(),
                  child: const Text('CANCEL'),
                ),
                AfriTextButton(
                  onPressed: () async {
                    final actionKey = actionKeyController.text.trim();
                    final title = titleController.text.trim();
                    final route = routeController.text.trim();
                    final iconKey = iconKeyController.text.trim();
                    if (actionKey.isEmpty ||
                        title.isEmpty ||
                        route.isEmpty ||
                        iconKey.isEmpty) {
                      return;
                    }

                    final payload = <String, dynamic>{
                      'action_key': actionKey,
                      'title': title,
                      'subtitle': _trimToNull(subtitleController.text),
                      'route': route,
                      'icon_key': iconKey,
                      'emoji': _trimToNull(emojiController.text),
                      'country': _countryValue(selectedCountry),
                      'sort_order':
                          int.tryParse(sortOrderController.text.trim()) ?? 0,
                      'is_active': isActive,
                    };

                    dialogContext.pop();
                    await _runCmsMutation((repo) async {
                      if (existing == null) {
                        await repo.createQuickAction(
                          actionKey: actionKey,
                          title: title,
                          route: route,
                          iconKey: iconKey,
                          subtitle: payload['subtitle']?.toString(),
                          emoji: payload['emoji']?.toString(),
                          countryCode: payload['country']?.toString(),
                          sortOrder: payload['sort_order'] as int,
                          isActive: isActive,
                        );
                      } else {
                        await repo.updateQuickAction(
                          existing['id'].toString(),
                          payload,
                        );
                      }
                    });
                  },
                  child: Text(existing == null ? 'CREATE' : 'SAVE'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showPartnerDialog([Map<String, dynamic>? existing]) {
    final nameController = TextEditingController(
      text: existing?['name']?.toString() ?? '',
    );
    final slugController = TextEditingController(
      text: existing?['slug']?.toString() ?? '',
    );
    final subtitleController = TextEditingController(
      text: existing?['subtitle']?.toString() ?? '',
    );
    final descriptionController = TextEditingController(
      text: existing?['description']?.toString() ?? '',
    );
    final emojiController = TextEditingController(
      text: existing?['emoji']?.toString() ?? '',
    );
    final sortOrderController = TextEditingController(
      text: '${(existing?['sort_order'] as num?)?.toInt() ?? 0}',
    );
    var category = existing?['category']?.toString() ?? 'organization';
    var country = existing?['country']?.toString() ?? 'RW';
    var isActive = existing?['is_active'] != false;
    var gamificationEnabled = existing?['gamification_enabled'] == true;

    unawaited(
      showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) {
            return AfriAlertDialog(
              title: Text(
                existing == null ? 'ADD PARTNER' : 'EDIT PARTNER',
                style: TypographyTokens.titleLarge(),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _DialogTextField(controller: nameController, hint: 'Name'),
                    const SizedBox(height: SpacingTokens.spacing3),
                    _DialogTextField(controller: slugController, hint: 'Slug'),
                    const SizedBox(height: SpacingTokens.spacing3),
                    AfriDropdownField<String>(
                      initialValue: category,
                      label: 'Category',
                      items: _partnerCategories
                          .map(
                            (item) => DropdownMenuItem<String>(
                              value: item,
                              child: Text(item),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() => category = value);
                      },
                    ),
                    const SizedBox(height: SpacingTokens.spacing3),
                    AfriDropdownField<String>(
                      initialValue: country,
                      label: 'Country',
                      items: _countryOptions
                          .where((item) => item != 'GLOBAL')
                          .map(
                            (item) => DropdownMenuItem<String>(
                              value: item,
                              child: Text(item),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() => country = value);
                      },
                    ),
                    const SizedBox(height: SpacingTokens.spacing3),
                    _DialogTextField(
                      controller: subtitleController,
                      hint: 'Subtitle',
                    ),
                    const SizedBox(height: SpacingTokens.spacing3),
                    _DialogTextField(
                      controller: descriptionController,
                      hint: 'Description',
                      maxLines: 3,
                    ),
                    const SizedBox(height: SpacingTokens.spacing3),
                    _DialogTextField(
                      controller: emojiController,
                      hint: 'Emoji',
                    ),
                    const SizedBox(height: SpacingTokens.spacing3),
                    _DialogTextField(
                      controller: sortOrderController,
                      hint: 'Sort order',
                      keyboardType: TextInputType.number,
                    ),
                    AfriSwitchListTile(
                      value: isActive,
                      onChanged: (value) =>
                          setDialogState(() => isActive = value),
                      title: const Text('Active'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    AfriSwitchListTile(
                      value: gamificationEnabled,
                      onChanged: (value) =>
                          setDialogState(() => gamificationEnabled = value),
                      title: const Text('Linked to gamification'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              actions: [
                AfriTextButton(
                  onPressed: () => dialogContext.pop(),
                  child: const Text('CANCEL'),
                ),
                AfriTextButton(
                  onPressed: () async {
                    final name = nameController.text.trim();
                    final slug = slugController.text.trim();
                    if (name.isEmpty || slug.isEmpty) return;

                    final payload = <String, dynamic>{
                      'name': name,
                      'slug': slug,
                      'category': category,
                      'country': country,
                      'subtitle': _trimToNull(subtitleController.text),
                      'description': _trimToNull(descriptionController.text),
                      'emoji': _trimToNull(emojiController.text),
                      'sort_order':
                          int.tryParse(sortOrderController.text.trim()) ?? 0,
                      'is_active': isActive,
                      'gamification_enabled': gamificationEnabled,
                    };

                    dialogContext.pop();
                    await _runCmsMutation((repo) async {
                      if (existing == null) {
                        await repo.createPartner(
                          name: name,
                          slug: slug,
                          category: category,
                          countryCode: country,
                          emoji: payload['emoji']?.toString(),
                          subtitle: payload['subtitle']?.toString(),
                          description: payload['description']?.toString(),
                          isActive: isActive,
                          gamificationEnabled: gamificationEnabled,
                          sortOrder: payload['sort_order'] as int,
                        );
                      } else {
                        await repo.updatePartner(
                          existing['id'].toString(),
                          payload,
                        );
                      }
                    });
                  },
                  child: Text(existing == null ? 'CREATE' : 'SAVE'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showPartnerServiceDialog([Map<String, dynamic>? existing]) {
    if (_partners.isEmpty) {
      _showSnack('Create a partner first.');
      return;
    }

    final partnerMap = existing?['partner'] as Map<String, dynamic>?;
    var selectedPartnerId =
        partnerMap?['id']?.toString() ?? _partners.first['id'].toString();
    final serviceSlugController = TextEditingController(
      text: existing?['service_slug']?.toString() ?? '',
    );
    final titleController = TextEditingController(
      text: existing?['title']?.toString() ?? '',
    );
    final subtitleController = TextEditingController(
      text: existing?['subtitle']?.toString() ?? '',
    );
    final emojiController = TextEditingController(
      text: existing?['emoji']?.toString() ?? '',
    );
    final ctaLabelController = TextEditingController(
      text: existing?['cta_label']?.toString() ?? '',
    );
    final ctaActionController = TextEditingController(
      text: existing?['cta_action']?.toString() ?? '',
    );
    final sortOrderController = TextEditingController(
      text: '${(existing?['sort_order'] as num?)?.toInt() ?? 0}',
    );
    var category = existing?['category']?.toString() ?? 'general';
    var country = _countryLabel(existing?['country']);
    var isActive = existing?['is_active'] != false;
    var gamificationEnabled = existing?['gamification_enabled'] == true;

    unawaited(
      showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) {
            return AfriAlertDialog(
              title: Text(
                existing == null
                    ? 'ADD PARTNER SERVICE'
                    : 'EDIT PARTNER SERVICE',
                style: TypographyTokens.titleLarge(),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AfriDropdownField<String>(
                      initialValue: selectedPartnerId,
                      label: 'Partner',
                      items: _partners
                          .map(
                            (partner) => DropdownMenuItem<String>(
                              value: partner['id']?.toString() ?? '',
                              child: Text(
                                partner['name']?.toString() ?? 'Partner',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null || value.isEmpty) return;
                        setDialogState(() => selectedPartnerId = value);
                      },
                    ),
                    const SizedBox(height: SpacingTokens.spacing3),
                    _DialogTextField(
                      controller: serviceSlugController,
                      hint: 'Service slug',
                    ),
                    const SizedBox(height: SpacingTokens.spacing3),
                    _DialogTextField(
                      controller: titleController,
                      hint: 'Title',
                    ),
                    const SizedBox(height: SpacingTokens.spacing3),
                    _DialogTextField(
                      controller: subtitleController,
                      hint: 'Subtitle',
                    ),
                    const SizedBox(height: SpacingTokens.spacing3),
                    AfriDropdownField<String>(
                      initialValue: category,
                      label: 'Category',
                      items: _serviceCategories
                          .map(
                            (item) => DropdownMenuItem<String>(
                              value: item,
                              child: Text(item),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() => category = value);
                      },
                    ),
                    const SizedBox(height: SpacingTokens.spacing3),
                    AfriDropdownField<String>(
                      initialValue: country,
                      label: 'Country',
                      items: _countryOptions
                          .map(
                            (item) => DropdownMenuItem<String>(
                              value: item,
                              child: Text(item),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() => country = value);
                      },
                    ),
                    const SizedBox(height: SpacingTokens.spacing3),
                    _DialogTextField(
                      controller: emojiController,
                      hint: 'Emoji',
                    ),
                    const SizedBox(height: SpacingTokens.spacing3),
                    _DialogTextField(
                      controller: ctaLabelController,
                      hint: 'CTA label',
                    ),
                    const SizedBox(height: SpacingTokens.spacing3),
                    _DialogTextField(
                      controller: ctaActionController,
                      hint: 'CTA action',
                    ),
                    const SizedBox(height: SpacingTokens.spacing3),
                    _DialogTextField(
                      controller: sortOrderController,
                      hint: 'Sort order',
                      keyboardType: TextInputType.number,
                    ),
                    AfriSwitchListTile(
                      value: isActive,
                      onChanged: (value) =>
                          setDialogState(() => isActive = value),
                      title: const Text('Active'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    AfriSwitchListTile(
                      value: gamificationEnabled,
                      onChanged: (value) =>
                          setDialogState(() => gamificationEnabled = value),
                      title: const Text('Linked to gamification'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              actions: [
                AfriTextButton(
                  onPressed: () => dialogContext.pop(),
                  child: const Text('CANCEL'),
                ),
                AfriTextButton(
                  onPressed: () async {
                    final serviceSlug = serviceSlugController.text.trim();
                    final title = titleController.text.trim();
                    if (serviceSlug.isEmpty || title.isEmpty) return;

                    final payload = <String, dynamic>{
                      'partner_id': selectedPartnerId,
                      'service_slug': serviceSlug,
                      'title': title,
                      'subtitle': _trimToNull(subtitleController.text),
                      'emoji': _trimToNull(emojiController.text),
                      'category': category,
                      'cta_label': _trimToNull(ctaLabelController.text),
                      'cta_action': _trimToNull(ctaActionController.text),
                      'country': _countryValue(country),
                      'sort_order':
                          int.tryParse(sortOrderController.text.trim()) ?? 0,
                      'is_active': isActive,
                      'gamification_enabled': gamificationEnabled,
                    };

                    dialogContext.pop();
                    await _runCmsMutation((repo) async {
                      if (existing == null) {
                        await repo.createPartnerService(
                          partnerId: selectedPartnerId,
                          title: title,
                          serviceSlug: serviceSlug,
                          category: category,
                          subtitle: payload['subtitle']?.toString(),
                          emoji: payload['emoji']?.toString(),
                          ctaLabel: payload['cta_label']?.toString(),
                          ctaAction: payload['cta_action']?.toString(),
                          countryCode: payload['country']?.toString(),
                          sortOrder: payload['sort_order'] as int,
                          isActive: isActive,
                          gamificationEnabled: gamificationEnabled,
                        );
                      } else {
                        await repo.updatePartnerService(
                          existing['id'].toString(),
                          payload,
                        );
                      }
                    });
                  },
                  child: Text(existing == null ? 'CREATE' : 'SAVE'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showPredictionCompetitionDialog([Map<String, dynamic>? existing]) {
    final supportedCompetitionIds = _predictionCompetitions
        .map((item) => item['competition_id']?.toString())
        .whereType<String>()
        .toSet();
    final availableCompetitions = _competitionCatalog
        .where((item) {
          final id = item['id']?.toString() ?? '';
          if (existing != null &&
              id == existing['competition_id']?.toString()) {
            return true;
          }
          return !supportedCompetitionIds.contains(id);
        })
        .toList(growable: false);

    if (existing == null && availableCompetitions.isEmpty) {
      _showSnack(
        'All active competitions are already in the prediction catalog.',
      );
      return;
    }

    var selectedCompetitionId =
        existing?['competition_id']?.toString() ??
        availableCompetitions.first['id']?.toString() ??
        '';
    final highlightLabelController = TextEditingController(
      text: existing?['highlight_label']?.toString() ?? '',
    );
    final sortOrderController = TextEditingController(
      text: '${(existing?['support_sort_order'] as num?)?.toInt() ?? 0}',
    );
    var isActive = existing?['is_supported'] != false;

    unawaited(
      showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) {
            return AfriAlertDialog(
              title: Text(
                existing == null
                    ? 'ADD PREDICTION COMPETITION'
                    : 'EDIT PREDICTION COMPETITION',
                style: TypographyTokens.titleLarge(),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AfriDropdownField<String>(
                      initialValue: selectedCompetitionId.isEmpty
                          ? null
                          : selectedCompetitionId,
                      label: 'Competition',
                      items: availableCompetitions
                          .map(
                            (competition) => DropdownMenuItem<String>(
                              value: competition['id']?.toString() ?? '',
                              child: Text(
                                competition['name']?.toString() ??
                                    'Competition',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: existing != null
                          ? null
                          : (value) {
                              if (value == null || value.isEmpty) return;
                              setDialogState(
                                () => selectedCompetitionId = value,
                              );
                            },
                    ),
                    const SizedBox(height: SpacingTokens.spacing3),
                    _DialogTextField(
                      controller: highlightLabelController,
                      hint: 'Highlight label',
                    ),
                    const SizedBox(height: SpacingTokens.spacing3),
                    _DialogTextField(
                      controller: sortOrderController,
                      hint: 'Sort order',
                      keyboardType: TextInputType.number,
                    ),
                    AfriSwitchListTile(
                      value: isActive,
                      onChanged: (value) =>
                          setDialogState(() => isActive = value),
                      title: const Text('Active'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              actions: [
                AfriTextButton(
                  onPressed: () => dialogContext.pop(),
                  child: const Text('CANCEL'),
                ),
                AfriTextButton(
                  onPressed: () async {
                    if (selectedCompetitionId.isEmpty) return;
                    final payload = <String, dynamic>{
                      'highlight_label': _trimToNull(
                        highlightLabelController.text,
                      ),
                      'sort_order':
                          int.tryParse(sortOrderController.text.trim()) ?? 0,
                      'is_active': isActive,
                    };

                    dialogContext.pop();
                    await _runCmsMutation((repo) async {
                      if (existing == null) {
                        await repo.createPredictionSupportedCompetition(
                          competitionId: selectedCompetitionId,
                          highlightLabel: payload['highlight_label']
                              ?.toString(),
                          sortOrder: payload['sort_order'] as int,
                          isActive: isActive,
                        );
                      } else {
                        await repo.updatePredictionSupportedCompetition(
                          existing['support_id'].toString(),
                          payload,
                        );
                      }
                    });
                  },
                  child: Text(existing == null ? 'CREATE' : 'SAVE'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<bool> _runCmsMutation(
    Future<void> Function(AdminRepository repository) mutation,
  ) async {
    final success = await ref
        .read(adminCmsProvider.notifier)
        .runMutation(mutation);
    if (!mounted || success) return success;
    final failure = ref.read(adminCmsProvider).valueOrNull?.failure;
    final message = switch (failure?.kind) {
      AdminCmsFailureKind.offline =>
        'CMS changes need a connection. Nothing was retried.',
      AdminCmsFailureKind.permissionDenied =>
        'CMS access is no longer available for this account.',
      AdminCmsFailureKind.conflict =>
        'CMS content changed. Refresh before trying another action.',
      AdminCmsFailureKind.securityTimeout =>
        'The result is not confirmed. Refresh before trying another action.',
      _ => 'The CMS change could not be completed. Review and try again.',
    };
    _showSnack(message, isError: true);
    return false;
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    if (isError) {
      AfriToast.error(context, message);
    } else {
      AfriToast.info(context, message);
    }
  }

  String _countryLabel(dynamic value) {
    final normalized = value?.toString().trim().toUpperCase();
    if (normalized == null || normalized.isEmpty) {
      return 'GLOBAL';
    }
    return normalized;
  }

  String? _countryValue(String label) {
    final normalized = label.trim().toUpperCase();
    return normalized == 'GLOBAL' ? null : normalized;
  }

  String? _trimToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Widget _unavailable(AdminCmsFailure failure) {
    final view = switch (failure.kind) {
      AdminCmsFailureKind.offline => AfriStateView.offline(
        key: const ValueKey<String>('admin-cms-state-offline'),
        title: 'Content manager offline',
        message: 'Reconnect before loading private publishing controls.',
        actionLabel: 'Try again',
        onAction: () => unawaited(_loadContent()),
      ),
      AdminCmsFailureKind.permissionDenied => AfriStateView.error(
        key: const ValueKey<String>('admin-cms-state-permission-denied'),
        title: 'Content access unavailable',
        message: 'This account cannot view or change club publishing data.',
        actionLabel: 'Back to admin',
        onAction: () => context.pop(),
      ),
      AdminCmsFailureKind.conflict => AfriStateView.error(
        key: const ValueKey<String>('admin-cms-state-conflict'),
        title: 'Content changed',
        message: 'Refresh the workspace before making another change.',
        actionLabel: 'Refresh',
        onAction: () => unawaited(_loadContent()),
      ),
      AdminCmsFailureKind.securityTimeout => AfriStateView.error(
        key: const ValueKey<String>('admin-cms-state-security-timeout'),
        title: 'Security check timed out',
        message:
            'No private content was shown. Check your connection and retry.',
        actionLabel: 'Retry',
        onAction: () => unawaited(_loadContent()),
      ),
      AdminCmsFailureKind.unknown => AfriStateView.error(
        key: const ValueKey<String>('admin-cms-state-error'),
        title: 'Content manager unavailable',
        message: 'Private publishing data remains hidden. Try again.',
        actionLabel: 'Try again',
        onAction: () => unawaited(_loadContent()),
      ),
    };
    return Padding(
      padding: const EdgeInsets.all(SpacingTokens.spacing6),
      child: view,
    );
  }

  Widget? _statusBanner(AsyncValue<AdminCmsSnapshot> cms) {
    if (_snapshot.isMutating) {
      return const AfriStateBanner(
        key: ValueKey<String>('admin-cms-state-syncing'),
        icon: AfriIcons.refresh,
        title: 'Saving content',
        subtitle:
            'Publishing controls are paused until the result is confirmed.',
        tone: AfriStateBannerTone.info,
      );
    }
    if (cms.isLoading && cms.valueOrNull != null) {
      return const AfriStateBanner(
        key: ValueKey<String>('admin-cms-state-syncing'),
        icon: AfriIcons.refresh,
        title: 'Refreshing content',
        subtitle:
            'Showing the last confirmed workspace while status is checked.',
        tone: AfriStateBannerTone.info,
      );
    }
    final failure = _snapshot.failure;
    if (_snapshot.phase != AdminCmsPhase.degraded || failure == null) {
      return null;
    }
    return AfriStateBanner(
      key: ValueKey<String>('admin-cms-state-${failure.kind.name}'),
      icon: failure.kind == AdminCmsFailureKind.offline
          ? AfriIcons.offline
          : AfriIcons.statusWarning,
      title: failure.kind == AdminCmsFailureKind.conflict
          ? 'Content changed'
          : failure.kind == AdminCmsFailureKind.securityTimeout
          ? 'Security check timed out'
          : failure.kind == AdminCmsFailureKind.offline
          ? 'Content manager offline'
          : 'Current refresh unavailable',
      subtitle: _snapshot.mutationOutcomeUnconfirmed
          ? 'The last change is not confirmed. Refresh before taking another action.'
          : 'Showing the last confirmed workspace. Actions are paused until refresh succeeds.',
      tone: AfriStateBannerTone.warning,
    );
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(adminCmsEnabledProvider);
    final cms = ref.watch(adminCmsProvider);
    _cmsLoading = cms.isLoading;
    if (cms.valueOrNull case final current?) {
      _snapshot = current;
    }
    final permissionDenied =
        _snapshot.failure?.kind == AdminCmsFailureKind.permissionDenied;

    return AfriScreenScaffold(
      backgroundColor: ColorTokens.background,
      appBar: AfriAppBar(
        backgroundColor: ColorTokens.transparent,
        title: Text('CONTENT MANAGER', style: TypographyTokens.titleLarge()),
        leading: AfriIconButton(
          icon: AfriIcons.back,
          onTap: () => context.pop(),
          tooltip: 'Back',
        ),
      ),
      scrollable: false,
      constrainContent: true,
      child: !enabled
          ? Padding(
              padding: const EdgeInsets.all(SpacingTokens.spacing6),
              child: AfriStateView.empty(
                key: const ValueKey<String>('admin-cms-state-disabled'),
                title: 'Content manager unavailable',
                message:
                    'Publishing controls are disabled for this controlled build.',
                icon: AfriIcons.lock,
                actionLabel: 'Back to admin',
                onAction: () => context.pop(),
              ),
            )
          : permissionDenied
          ? _unavailable(
              const AdminCmsFailure(AdminCmsFailureKind.permissionDenied),
            )
          : cms.isLoading && cms.valueOrNull == null
          ? Padding(
              padding: const EdgeInsets.all(SpacingTokens.spacing6),
              child: AfriStateView.loading(
                key: const ValueKey<String>('admin-cms-state-loading'),
                title: 'Loading content manager',
                message: 'Checking current publishing work.',
              ),
            )
          : cms.hasError && cms.valueOrNull == null
          ? _unavailable(AdminCmsFailure.fromError(cms.error!))
          : AfriRefreshIndicator(
              onRefresh: _loadContent,
              child: ListView(
                padding: const EdgeInsets.all(SpacingTokens.spacing6),
                children: [
                  if (_statusBanner(cms) case final banner?) ...[
                    banner,
                    const SizedBox(height: SpacingTokens.spacing4),
                  ],
                  Text(
                    'Manage home shortcuts, partner catalogs, and supported prediction competitions.',
                    style: TypographyTokens.bodyMedium(),
                  ),
                  if (_snapshot.isEmpty) ...[
                    const SizedBox(height: SpacingTokens.spacing4),
                    AfriStateView.empty(
                      key: const ValueKey<String>('admin-cms-state-empty'),
                      title: 'No managed content',
                      message:
                          'Choose a section to create the first controlled item.',
                      compact: true,
                    ),
                  ],
                  const SizedBox(height: SpacingTokens.spacing4),
                  buildSectionSelector(),
                  const SizedBox(height: SpacingTokens.spacing5),
                  buildSectionContent(),
                ],
              ),
            ),
    );
  }
}
