import 'dart:async';

import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../admin_providers.dart';
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
  const CmsContentManagerScreen({super.key});

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
  List<Map<String, dynamic>> _articles = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _quickActions = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _partners = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _partnerServices = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _predictionCompetitions =
      const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _competitionCatalog =
      const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _contentBlocks = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _platformFeatures = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _auditLogs = const <Map<String, dynamic>>[];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_loadContent());
  }

  Future<void> _loadContent() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repo = ref.read(adminRepositoryProvider);
      final results = await Future.wait<dynamic>([
        repo.getNewsArticles(),
        repo.getQuickActions(),
        repo.getPartners(),
        repo.getPartnerServices(),
        repo.getPredictionSupportedCompetitions(),
        repo.getFootballCompetitions(),
        repo.getPlatformContentBlocks(),
        repo.getPlatformFeatures(),
        repo.getPlatformFeatureAuditLogs(),
      ]);

      if (!mounted) return;
      setState(() {
        _articles = List<Map<String, dynamic>>.from(results[0] as List);
        _quickActions = List<Map<String, dynamic>>.from(results[1] as List);
        _partners = List<Map<String, dynamic>>.from(results[2] as List);
        _partnerServices = List<Map<String, dynamic>>.from(results[3] as List);
        _predictionCompetitions = List<Map<String, dynamic>>.from(
          results[4] as List,
        );
        _competitionCatalog = List<Map<String, dynamic>>.from(
          results[5] as List,
        );
        _contentBlocks = List<Map<String, dynamic>>.from(results[6] as List);
        _platformFeatures = List<Map<String, dynamic>>.from(results[7] as List);
        _auditLogs = List<Map<String, dynamic>>.from(results[8] as List);
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _togglePublish(String articleId, bool currentlyPublished) async {
    try {
      final repo = ref.read(adminRepositoryProvider);
      await repo.updateNewsArticle(articleId, {
        'is_published': !currentlyPublished,
        if (!currentlyPublished)
          'published_at': DateTime.now().toUtc().toIso8601String(),
      });
      await _loadContent();
    } catch (error) {
      _showSnack('Failed to update article: $error');
    }
  }

  Future<void> _toggleQuickAction(Map<String, dynamic> action) async {
    try {
      await ref.read(adminRepositoryProvider).updateQuickAction(
        action['id'].toString(),
        {'is_active': action['is_active'] != true},
      );
      await _loadContent();
    } catch (error) {
      _showSnack('Failed to update quick action: $error');
    }
  }

  Future<void> _togglePartner(Map<String, dynamic> partner) async {
    try {
      await ref.read(adminRepositoryProvider).updatePartner(
        partner['id'].toString(),
        {'is_active': partner['is_active'] != true},
      );
      await _loadContent();
    } catch (error) {
      _showSnack('Failed to update partner: $error');
    }
  }

  Future<void> _togglePartnerService(Map<String, dynamic> service) async {
    try {
      await ref.read(adminRepositoryProvider).updatePartnerService(
        service['id'].toString(),
        {'is_active': service['is_active'] != true},
      );
      await _loadContent();
    } catch (error) {
      _showSnack('Failed to update partner service: $error');
    }
  }

  Future<void> _togglePredictionCompetition(Map<String, dynamic> item) async {
    try {
      await ref
          .read(adminRepositoryProvider)
          .updatePredictionSupportedCompetition(item['support_id'].toString(), {
            'is_active': item['is_supported'] != true,
          });
      await _loadContent();
    } catch (error) {
      _showSnack('Failed to update prediction competition: $error');
    }
  }

  Future<void> _toggleContentBlock(Map<String, dynamic> block) async {
    try {
      await ref.read(adminRepositoryProvider).updatePlatformContentBlock(
        block['id'].toString(),
        {'is_active': block['is_active'] != true},
      );
      await _loadContent();
    } catch (error) {
      _showSnack('Failed to update content block: $error');
    }
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
                    try {
                      final repo = ref.read(adminRepositoryProvider);
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
                      await _loadContent();
                    } catch (error) {
                      _showSnack('Failed to save content block: $error');
                    }
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
                try {
                  await ref
                      .read(adminRepositoryProvider)
                      .createNewsArticle(
                        title: titleController.text.trim(),
                        body: bodyController.text.trim(),
                      );
                  await _loadContent();
                } catch (error) {
                  _showSnack('Failed to create article: $error');
                }
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
                    try {
                      final repo = ref.read(adminRepositoryProvider);
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
                      await _loadContent();
                    } catch (error) {
                      _showSnack('Failed to save quick action: $error');
                    }
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
                    try {
                      final repo = ref.read(adminRepositoryProvider);
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
                      await _loadContent();
                    } catch (error) {
                      _showSnack('Failed to save partner: $error');
                    }
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
                    try {
                      final repo = ref.read(adminRepositoryProvider);
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
                      await _loadContent();
                    } catch (error) {
                      _showSnack('Failed to save partner service: $error');
                    }
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
        .map((item) => item['id']?.toString())
        .whereType<String>()
        .toSet();
    final availableCompetitions = _competitionCatalog
        .where((item) {
          final id = item['id']?.toString() ?? '';
          if (existing != null && id == existing['id']?.toString()) {
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
        existing?['id']?.toString() ??
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
                    try {
                      final repo = ref.read(adminRepositoryProvider);
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
                      await _loadContent();
                    } catch (error) {
                      _showSnack('Failed to save competition: $error');
                    }
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

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
      body: _isLoading
          ? const Padding(
              padding: EdgeInsets.all(SpacingTokens.spacing6),
              child: AfriSkeletonList(),
            )
          : _error != null
          ? buildErrorState()
          : AfriRefreshIndicator(
              onRefresh: _loadContent,
              child: ListView(
                padding: const EdgeInsets.all(SpacingTokens.spacing6),
                children: [
                  Text(
                    'Manage home shortcuts, partner catalogs, and supported prediction competitions.',
                    style: TypographyTokens.bodyMedium(),
                  ),
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
