import 'package:flutter/material.dart';

import '../tokens/color_tokens.dart';
import '../tokens/component_size_tokens.dart';
import '../tokens/icon_tokens.dart';
import '../tokens/spacing_tokens.dart';
import '../tokens/typography_tokens.dart';
import 'afri_dialog.dart';
import 'afri_icon_button.dart';
import 'afri_input_field.dart';
import 'afri_list_row.dart';
import 'afri_press_feedback.dart';
import 'afri_state_view.dart';

/// Generic anchored content with keyboard dismissal and an explicit trigger.
class AfriPopover extends StatelessWidget {
  const AfriPopover({
    required this.tooltip,
    required this.contentBuilder,
    this.icon = AfriIcons.more,
    super.key,
  });

  final String tooltip;
  final WidgetBuilder contentBuilder;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      consumeOutsideTap: true,
      menuChildren: [
        ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AfriComponentSizes.anchoredOverlayMaxWidth,
          ),
          child: Padding(
            padding: const EdgeInsets.all(SpacingTokens.spacing4),
            child: Builder(builder: contentBuilder),
          ),
        ),
      ],
      builder: (context, controller, child) => AfriIconButton(
        icon: icon,
        tooltip: tooltip,
        onTap: controller.isOpen ? controller.close : controller.open,
      ),
    );
  }
}

class AfriCommandItem<T> {
  const AfriCommandItem({
    required this.value,
    required this.label,
    required this.icon,
    this.description,
    this.enabled = true,
  });

  final T value;
  final String label;
  final IconData icon;
  final String? description;
  final bool enabled;
}

enum AfriCommandMenuState { ready, loading, error }

class AfriCommandMenu {
  AfriCommandMenu._();

  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    required List<AfriCommandItem<T>> items,
    String searchLabel = 'Search commands',
    AfriCommandMenuState state = AfriCommandMenuState.ready,
    T? selectedValue,
    String errorMessage = 'Commands could not be loaded.',
    VoidCallback? onRetry,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: true,
      builder: (context) => _AfriCommandMenuDialog<T>(
        title: title,
        items: items,
        searchLabel: searchLabel,
        state: state,
        selectedValue: selectedValue,
        errorMessage: errorMessage,
        onRetry: onRetry,
      ),
    );
  }
}

class _AfriCommandMenuDialog<T> extends StatelessWidget {
  const _AfriCommandMenuDialog({
    required this.title,
    required this.items,
    required this.searchLabel,
    required this.state,
    required this.selectedValue,
    required this.errorMessage,
    required this.onRetry,
  });

  final String title;
  final List<AfriCommandItem<T>> items;
  final String searchLabel;
  final AfriCommandMenuState state;
  final T? selectedValue;
  final String errorMessage;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return AfriAlertDialog(
      title: Text(title),
      content: AfriCommandMenuPanel<T>(
        items: items,
        searchLabel: searchLabel,
        state: state,
        selectedValue: selectedValue,
        errorMessage: errorMessage,
        onRetry: onRetry,
        autofocus: true,
        onSelected: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

/// Embeddable command-menu body used by the modal route and visual catalogs.
class AfriCommandMenuPanel<T> extends StatefulWidget {
  const AfriCommandMenuPanel({
    required this.items,
    this.searchLabel = 'Search commands',
    this.state = AfriCommandMenuState.ready,
    this.selectedValue,
    this.errorMessage = 'Commands could not be loaded.',
    this.onRetry,
    this.onSelected,
    this.autofocus = false,
    super.key,
  });

  final List<AfriCommandItem<T>> items;
  final String searchLabel;
  final AfriCommandMenuState state;
  final T? selectedValue;
  final String errorMessage;
  final VoidCallback? onRetry;
  final ValueChanged<T>? onSelected;
  final bool autofocus;

  @override
  State<AfriCommandMenuPanel<T>> createState() =>
      _AfriCommandMenuPanelState<T>();
}

class _AfriCommandMenuPanelState<T> extends State<AfriCommandMenuPanel<T>> {
  late final TextEditingController _queryController;
  late final FocusNode _queryFocus;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController();
    _queryFocus = FocusNode();
  }

  @override
  void dispose() {
    _queryController.dispose();
    _queryFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final normalizedQuery = _query.trim().toLowerCase();
    final visible = widget.items.where((item) {
      if (normalizedQuery.isEmpty) return true;
      return item.label.toLowerCase().contains(normalizedQuery) ||
          (item.description?.toLowerCase().contains(normalizedQuery) ?? false);
    }).toList();

    return SizedBox(
      width: AfriComponentSizes.overlayDefaultWidth,
      height: AfriComponentSizes.overlayDefaultHeight,
      child: Column(
        children: [
          AfriInputField(
            controller: _queryController,
            focusNode: _queryFocus,
            autofocus: widget.autofocus,
            label: widget.searchLabel,
            prefixIcon: AfriIcons.search,
            enabled: widget.state == AfriCommandMenuState.ready,
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: SpacingTokens.spacing3),
          Expanded(
            child: switch (widget.state) {
              AfriCommandMenuState.loading => AfriStateView.loading(
                title: 'Loading commands',
                message: 'Available actions are being prepared.',
                compact: true,
              ),
              AfriCommandMenuState.error => AfriStateView.error(
                title: 'Commands unavailable',
                message: widget.errorMessage,
                actionLabel: widget.onRetry == null ? null : 'Retry',
                onAction: widget.onRetry,
                compact: true,
              ),
              AfriCommandMenuState.ready =>
                visible.isEmpty
                    ? Center(
                        child: Text(
                          'No matching commands',
                          style: TypographyTokens.bodyMedium(
                            ColorTokens.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: visible.length,
                        itemBuilder: (context, index) {
                          final item = visible[index];
                          return AfriPressFeedback(
                            enabled: item.enabled && widget.onSelected != null,
                            selected: item.value == widget.selectedValue,
                            semanticsLabel: item.label,
                            onTap: item.enabled && widget.onSelected != null
                                ? () => widget.onSelected!(item.value)
                                : null,
                            child: AfriListTile(
                              leading: Icon(item.icon),
                              title: Text(item.label),
                              subtitle: item.description == null
                                  ? null
                                  : Text(item.description!),
                              enabled: item.enabled,
                              selected: item.value == widget.selectedValue,
                            ),
                          );
                        },
                      ),
            },
          ),
        ],
      ),
    );
  }
}
