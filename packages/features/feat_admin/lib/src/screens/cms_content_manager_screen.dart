import 'dart:async';

import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../repositories/admin_repository.dart';

enum _CmsSection { news, quickActions, partners, services, competitions }

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

  _CmsSection _section = _CmsSection.news;
  List<Map<String, dynamic>> _articles = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _quickActions = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _partners = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _partnerServices = const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _predictionCompetitions =
      const <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _competitionCatalog =
      const <Map<String, dynamic>>[];
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

  void _showCreateArticleDialog() {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();

    unawaited(
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: ColorTokens.surfaceContainer,
          title: Text('NEW ARTICLE', style: TypographyTokens.titleLarge()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(hintText: 'Article title'),
              ),
              const SizedBox(height: SpacingTokens.spacing3),
              TextField(
                controller: bodyController,
                maxLines: 3,
                decoration: const InputDecoration(hintText: 'Article body'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => dialogContext.pop(),
              child: const Text('CANCEL'),
            ),
            TextButton(
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
            return AlertDialog(
              backgroundColor: ColorTokens.surfaceContainer,
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
                    DropdownButtonFormField<String>(
                      initialValue: selectedCountry,
                      decoration: const InputDecoration(labelText: 'Country'),
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
                    SwitchListTile.adaptive(
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
                TextButton(
                  onPressed: () => dialogContext.pop(),
                  child: const Text('CANCEL'),
                ),
                TextButton(
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
      text: existing?['emoji']?.toString() ?? '🤝',
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
            return AlertDialog(
              backgroundColor: ColorTokens.surfaceContainer,
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
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      decoration: const InputDecoration(labelText: 'Category'),
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
                    DropdownButtonFormField<String>(
                      initialValue: country,
                      decoration: const InputDecoration(labelText: 'Country'),
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
                    SwitchListTile.adaptive(
                      value: isActive,
                      onChanged: (value) =>
                          setDialogState(() => isActive = value),
                      title: const Text('Active'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    SwitchListTile.adaptive(
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
                TextButton(
                  onPressed: () => dialogContext.pop(),
                  child: const Text('CANCEL'),
                ),
                TextButton(
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
                      'emoji': _trimToNull(emojiController.text) ?? '🤝',
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
                          emoji: payload['emoji']?.toString() ?? '🤝',
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
            return AlertDialog(
              backgroundColor: ColorTokens.surfaceContainer,
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
                    DropdownButtonFormField<String>(
                      initialValue: selectedPartnerId,
                      decoration: const InputDecoration(labelText: 'Partner'),
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
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      decoration: const InputDecoration(labelText: 'Category'),
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
                    DropdownButtonFormField<String>(
                      initialValue: country,
                      decoration: const InputDecoration(labelText: 'Country'),
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
                    SwitchListTile.adaptive(
                      value: isActive,
                      onChanged: (value) =>
                          setDialogState(() => isActive = value),
                      title: const Text('Active'),
                      contentPadding: EdgeInsets.zero,
                    ),
                    SwitchListTile.adaptive(
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
                TextButton(
                  onPressed: () => dialogContext.pop(),
                  child: const Text('CANCEL'),
                ),
                TextButton(
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
            return AlertDialog(
              backgroundColor: ColorTokens.surfaceContainer,
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
                    DropdownButtonFormField<String>(
                      initialValue: selectedCompetitionId.isEmpty
                          ? null
                          : selectedCompetitionId,
                      decoration: const InputDecoration(
                        labelText: 'Competition',
                      ),
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
                    SwitchListTile.adaptive(
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
                TextButton(
                  onPressed: () => dialogContext.pop(),
                  child: const Text('CANCEL'),
                ),
                TextButton(
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('CONTENT MANAGER', style: TypographyTokens.titleLarge()),
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(AfriIcons.back),
        ),
      ),
      body: _isLoading
          ? const Padding(
              padding: EdgeInsets.all(SpacingTokens.spacing6),
              child: AfriSkeletonList(),
            )
          : _error != null
          ? _buildErrorState()
          : RefreshIndicator(
              onRefresh: _loadContent,
              child: ListView(
                padding: const EdgeInsets.all(SpacingTokens.spacing6),
                children: [
                  Text(
                    'Manage home shortcuts, partner catalogs, and supported prediction competitions.',
                    style: TypographyTokens.bodyMedium(),
                  ),
                  const SizedBox(height: SpacingTokens.spacing4),
                  _buildSectionSelector(),
                  const SizedBox(height: SpacingTokens.spacing5),
                  _buildSectionContent(),
                ],
              ),
            ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SpacingTokens.spacing8),
        child: GlassCard(
          animate: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48),
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

  Widget _buildSectionSelector() {
    return Wrap(
      spacing: SpacingTokens.spacing2,
      runSpacing: SpacingTokens.spacing2,
      children: _CmsSection.values.map((section) {
        final selected = section == _section;
        return ChoiceChip(
          label: Text(_sectionLabel(section)),
          selected: selected,
          onSelected: (_) => setState(() => _section = section),
        );
      }).toList(),
    );
  }

  Widget _buildSectionContent() {
    return switch (_section) {
      _CmsSection.news => _buildNewsSection(),
      _CmsSection.quickActions => _buildQuickActionsSection(),
      _CmsSection.partners => _buildPartnersSection(),
      _CmsSection.services => _buildPartnerServicesSection(),
      _CmsSection.competitions => _buildPredictionCompetitionsSection(),
    };
  }

  Widget _buildNewsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'News Articles',
          actionLabel: 'ADD ARTICLE',
          onAction: _showCreateArticleDialog,
        ),
        const SizedBox(height: SpacingTokens.spacing3),
        if (_articles.isEmpty)
          const _EmptySectionState(
            title: 'No articles yet',
            message: 'Create the first article for the live intel feed.',
          )
        else
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

  Widget _buildQuickActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Home Quick Actions',
          actionLabel: 'ADD ACTION',
          onAction: _showQuickActionDialog,
        ),
        const SizedBox(height: SpacingTokens.spacing3),
        if (_quickActions.isEmpty)
          const _EmptySectionState(
            title: 'No quick actions configured',
            message: 'Add shortcuts for the supporter home screen.',
          )
        else
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

  Widget _buildPartnersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Partners',
          actionLabel: 'ADD PARTNER',
          onAction: _showPartnerDialog,
        ),
        const SizedBox(height: SpacingTokens.spacing3),
        if (_partners.isEmpty)
          const _EmptySectionState(
            title: 'No partners configured',
            message: 'Seed or create admin-managed partner rows here.',
          )
        else
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

  Widget _buildPartnerServicesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Partner Services',
          actionLabel: 'ADD SERVICE',
          onAction: _showPartnerServiceDialog,
        ),
        const SizedBox(height: SpacingTokens.spacing3),
        if (_partnerServices.isEmpty)
          const _EmptySectionState(
            title: 'No partner services configured',
            message: 'Attach service journeys to the active partner catalog.',
          )
        else
          ..._partnerServices.map(
            (service) => Padding(
              padding: const EdgeInsets.only(bottom: SpacingTokens.spacing3),
              child: _EntityCard(
                title: service['title']?.toString() ?? 'Service',
                subtitle:
                    '${(service['partner'] as Map?)?['name'] ?? 'Partner'} • ${service['category']?.toString() ?? 'general'}',
                body:
                    '${service['cta_label']?.toString() ?? 'No CTA'} → ${service['cta_action']?.toString() ?? 'n/a'}',
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

  Widget _buildPredictionCompetitionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Prediction Competitions',
          actionLabel: 'ADD COMPETITION',
          onAction: _showPredictionCompetitionDialog,
        ),
        const SizedBox(height: SpacingTokens.spacing3),
        if (_predictionCompetitions.isEmpty)
          const _EmptySectionState(
            title: 'No prediction competitions configured',
            message:
                'Curate the competitions and fixtures exposed to predictions.',
          )
        else
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

  String _sectionLabel(_CmsSection section) {
    return switch (section) {
      _CmsSection.news => 'News',
      _CmsSection.quickActions => 'Quick Actions',
      _CmsSection.partners => 'Partners',
      _CmsSection.services => 'Services',
      _CmsSection.competitions => 'Predictions',
    };
  }
}

class _DialogTextField extends StatelessWidget {
  const _DialogTextField({
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(hintText: hint),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title.toUpperCase(),
            style: TypographyTokens.titleMedium().copyWith(letterSpacing: 1.1),
          ),
        ),
        TextButton.icon(
          onPressed: onAction,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: Text(actionLabel),
        ),
      ],
    );
  }
}

class _EmptySectionState extends StatelessWidget {
  const _EmptySectionState({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      animate: false,
      child: AfriEmptyView(
        compact: true,
        title: title,
        message: message,
        icon: AfriIcons.statusEmpty,
      ),
    );
  }
}

class _EntityCard extends StatelessWidget {
  const _EntityCard({
    required this.title,
    required this.subtitle,
    required this.tags,
    required this.onEdit,
    required this.onToggle,
    required this.toggleLabel,
    this.body,
  });

  final String title;
  final String subtitle;
  final String? body;
  final List<String> tags;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final String toggleLabel;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      animate: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: TypographyTokens.titleLarge().copyWith(
                    color: ColorTokens.onSurface,
                  ),
                ),
              ),
              Wrap(
                spacing: SpacingTokens.spacing2,
                children: tags
                    .map(
                      (tag) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: SpacingTokens.spacing3,
                          vertical: SpacingTokens.spacing1,
                        ),
                        decoration: BoxDecoration(
                          color: ColorTokens.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(tag, style: TypographyTokens.labelSmall()),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
          const SizedBox(height: SpacingTokens.spacing2),
          Text(subtitle, style: TypographyTokens.bodyMedium()),
          if (body != null && body!.trim().isNotEmpty) ...[
            const SizedBox(height: SpacingTokens.spacing2),
            Text(body!, style: TypographyTokens.bodyMedium()),
          ],
          const SizedBox(height: SpacingTokens.spacing3),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('EDIT'),
              ),
              TextButton.icon(
                onPressed: onToggle,
                icon: const Icon(Icons.toggle_on_outlined, size: 18),
                label: Text(toggleLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ArticleCard extends StatelessWidget {
  const _ArticleCard({required this.article, required this.onTogglePublish});

  final Map<String, dynamic> article;
  final VoidCallback onTogglePublish;

  @override
  Widget build(BuildContext context) {
    final title = article['title']?.toString() ?? 'Untitled';
    final category = article['category']?.toString() ?? 'News';
    final isPublished = article['is_published'] == true;
    final isFeatured = article['is_featured'] == true;
    final publishedAt = DateTime.tryParse(
      article['published_at']?.toString() ?? '',
    );

    final statusLabel = isPublished ? 'LIVE' : 'DRAFT';
    final dateLabel = publishedAt != null
        ? DateFormat('dd MMM HH:mm').format(publishedAt)
        : 'Not published';

    return GlassCard(
      animate: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: TypographyTokens.titleLarge().copyWith(
                    color: ColorTokens.onSurface,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: SpacingTokens.spacing3,
                  vertical: SpacingTokens.spacing1,
                ),
                decoration: BoxDecoration(
                  color: isPublished
                      ? ColorTokens.clubAccent.withValues(alpha: 0.15)
                      : ColorTokens.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(statusLabel, style: TypographyTokens.labelSmall()),
              ),
            ],
          ),
          const SizedBox(height: SpacingTokens.spacing2),
          Text(
            '${category.toUpperCase()}  •  $dateLabel${isFeatured ? '  •  FEATURED' : ''}',
            style: TypographyTokens.bodyMedium(),
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: onTogglePublish,
                icon: Icon(
                  isPublished
                      ? Icons.unpublished_rounded
                      : Icons.publish_rounded,
                  size: 18,
                ),
                label: Text(isPublished ? 'UNPUBLISH' : 'PUBLISH'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
