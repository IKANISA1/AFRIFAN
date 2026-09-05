import 'dart:convert';
import 'dart:io';

const componentStateCatalog = <String>[
  'default',
  'hover',
  'focused',
  'pressed',
  'selected',
  'disabled',
  'loading',
  'success',
  'warning',
  'error',
  'empty',
  'offline',
  'permission_denied',
  'skeleton',
];

enum ComponentImplementationStatus { implemented, partial, missing }

class ComponentSeed {
  const ComponentSeed(
    this.category,
    this.name,
    this.status, {
    this.sourcePaths = const <String>[],
    this.testPaths = const <String>[],
    this.notes = '',
  });

  final String category;
  final String name;
  String get componentKey => '$category|$name';
  final ComponentImplementationStatus status;
  final List<String> sourcePaths;
  final List<String> testPaths;
  final String notes;
}

/// States owned by a component rather than by a composing screen or service.
///
/// A button does not become an offline component merely because a screen can
/// place it inside an offline state, and a receipt does not own hover/pressed
/// behavior unless the component itself exposes that interaction. This keeps
/// evidence requirements meaningful while still covering the complete global
/// state catalog through the components that actually own each state.
Set<String> applicableStatesFor(ComponentSeed seed) {
  const defaultOnly = <String>{'default'};
  const interactive = <String>{
    'default',
    'hover',
    'focused',
    'pressed',
    'disabled',
  };
  const selectable = <String>{
    'default',
    'hover',
    'focused',
    'pressed',
    'selected',
    'disabled',
  };
  const editable = <String>{
    'default',
    'hover',
    'focused',
    'disabled',
    'error',
    'empty',
  };
  const asyncMedia = <String>{
    'default',
    'loading',
    'error',
    'empty',
    'offline',
    'permission_denied',
    'skeleton',
  };

  return switch (seed.componentKey) {
    'app_shell|bottom_nav' || 'app_shell|large_screen_side_rail' => selectable,

    'navigation|list_item' ||
    'navigation|large_screen_breadcrumb' ||
    'navigation|back_button' => interactive,

    'buttons|primary' ||
    'buttons|secondary' ||
    'buttons|tertiary' ||
    'buttons|destructive' ||
    'buttons|icon_only' ||
    'buttons|split' => {...interactive, 'loading'},

    'buttons|loading' => {'loading'},
    'buttons|disabled' => {'disabled'},

    'inputs|text' ||
    'inputs|number' ||
    'inputs|money' ||
    'inputs|phone' ||
    'inputs|email' ||
    'inputs|password' ||
    'inputs|search' ||
    'inputs|multiline' ||
    'inputs|otp' => editable,

    'inputs|date' || 'inputs|time' => {...editable, 'pressed'},

    'inputs|file_media_picker' => {
      ...interactive,
      'selected',
      'loading',
      'success',
      'warning',
      'error',
      'empty',
      'offline',
      'permission_denied',
    },

    'selection|checkbox' ||
    'selection|radio' ||
    'selection|switch' ||
    'selection|segmented_control' ||
    'selection|chips' ||
    'selection|tabs' ||
    'selection|menus' => selectable,

    'feedback|banner' => {
      'default',
      'loading',
      'success',
      'warning',
      'error',
      'offline',
    },
    'feedback|snackbar' ||
    'feedback|toast' => {'default', 'success', 'warning', 'error'},
    'feedback|inline_validation' => {'default', 'success', 'warning', 'error'},
    'feedback|progress_indicator' => {'loading'},
    'feedback|skeleton' => {'skeleton'},
    'feedback|empty_state' => {'empty'},
    'feedback|error_state' => {'error', 'offline'},

    'data_display|list_row' ||
    'data_display|card' ||
    'data_display|activity_item' => interactive,
    'data_display|timeline' => {'default', 'empty'},

    'navigation|deep_link_recovery' => {'default', 'error', 'offline'},
    'navigation|route_transition' => defaultOnly,

    'overlays|dialog' ||
    'overlays|bottom_sheet' ||
    'overlays|action_sheet' ||
    'overlays|popover' => defaultOnly,
    'overlays|command_menu' => {...selectable, 'loading', 'empty', 'error'},

    'media|image' || 'media|video_thumbnail' => asyncMedia,
    'media|document_preview' => {
      ...asyncMedia,
      'hover',
      'focused',
      'pressed',
      'disabled',
    },
    'media|qr_barcode_surface' => {'default', 'disabled', 'error', 'empty'},

    'security_privacy|masked_value' ||
    'security_privacy|reveal_control' => selectable,
    'security_privacy|session_timeout' => {
      'default',
      'warning',
      'error',
      'offline',
    },
    'security_privacy|permission_prompt' => {
      'default',
      'disabled',
      'warning',
      'error',
      'permission_denied',
    },
    'security_privacy|consent_review' => {
      ...selectable,
      'success',
      'warning',
      'error',
      'empty',
    },

    _ => defaultOnly,
  };
}

const componentSeeds = <ComponentSeed>[
  ComponentSeed(
    'app_shell',
    'top_bar',
    ComponentImplementationStatus.implemented,
    sourcePaths: [
      'packages/core/core_theme/lib/src/widgets/afri_top_command_bar.dart',
    ],
    testPaths: ['packages/core/core_theme/test/ui_source_guardrails_test.dart'],
  ),
  ComponentSeed(
    'app_shell',
    'bottom_nav',
    ComponentImplementationStatus.implemented,
    sourcePaths: [
      'packages/core/core_theme/lib/src/widgets/africlub_bottom_nav.dart',
    ],
    testPaths: ['packages/core/core_theme/test/africlub_bottom_nav_test.dart'],
  ),
  ComponentSeed(
    'app_shell',
    'large_screen_side_rail',
    ComponentImplementationStatus.implemented,
    sourcePaths: [
      'packages/core/core_theme/lib/src/widgets/afri_navigation_primitives.dart',
      'apps/rayon_sports/web/src/components/admin/admin-shell.tsx',
    ],
    testPaths: [
      'packages/core/core_theme/test/universal_component_primitives_test.dart',
    ],
  ),
  ComponentSeed(
    'app_shell',
    'safe_area_wrapper',
    ComponentImplementationStatus.implemented,
    sourcePaths: [
      'packages/core/core_theme/lib/src/widgets/afri_screen_scaffold.dart',
    ],
    testPaths: ['packages/core/core_theme/test/afri_screen_scaffold_test.dart'],
  ),
  ComponentSeed(
    'app_shell',
    'keyboard_aware_scaffold',
    ComponentImplementationStatus.implemented,
    sourcePaths: [
      'packages/core/core_theme/lib/src/widgets/afri_screen_scaffold.dart',
    ],
    testPaths: ['packages/core/core_theme/test/afri_screen_scaffold_test.dart'],
  ),

  ComponentSeed(
    'buttons',
    'primary',
    ComponentImplementationStatus.implemented,
    sourcePaths: ['packages/core/core_theme/lib/src/widgets/afri_button.dart'],
    testPaths: ['packages/core/core_theme/test/afri_button_test.dart'],
  ),
  ComponentSeed(
    'buttons',
    'secondary',
    ComponentImplementationStatus.implemented,
    sourcePaths: ['packages/core/core_theme/lib/src/widgets/afri_button.dart'],
    testPaths: ['packages/core/core_theme/test/afri_button_test.dart'],
  ),
  ComponentSeed(
    'buttons',
    'tertiary',
    ComponentImplementationStatus.implemented,
    sourcePaths: ['packages/core/core_theme/lib/src/widgets/afri_button.dart'],
    testPaths: ['packages/core/core_theme/test/afri_button_test.dart'],
  ),
  ComponentSeed(
    'buttons',
    'destructive',
    ComponentImplementationStatus.implemented,
    sourcePaths: ['packages/core/core_theme/lib/src/widgets/afri_button.dart'],
    testPaths: ['packages/core/core_theme/test/afri_button_test.dart'],
  ),
  ComponentSeed(
    'buttons',
    'icon_only',
    ComponentImplementationStatus.implemented,
    sourcePaths: [
      'packages/core/core_theme/lib/src/widgets/afri_icon_button.dart',
    ],
    testPaths: ['packages/core/core_theme/test/touch_target_test.dart'],
  ),
  ComponentSeed(
    'buttons',
    'split',
    ComponentImplementationStatus.implemented,
    sourcePaths: [
      'packages/core/core_theme/lib/src/widgets/afri_split_button.dart',
    ],
    testPaths: ['packages/core/core_theme/test/afri_split_button_test.dart'],
  ),
  ComponentSeed(
    'buttons',
    'loading',
    ComponentImplementationStatus.implemented,
    sourcePaths: ['packages/core/core_theme/lib/src/widgets/afri_button.dart'],
    testPaths: ['packages/core/core_theme/test/afri_button_test.dart'],
  ),
  ComponentSeed(
    'buttons',
    'disabled',
    ComponentImplementationStatus.implemented,
    sourcePaths: ['packages/core/core_theme/lib/src/widgets/afri_button.dart'],
    testPaths: ['packages/core/core_theme/test/afri_button_test.dart'],
  ),

  ComponentSeed(
    'inputs',
    'text',
    ComponentImplementationStatus.implemented,
    sourcePaths: [
      'packages/core/core_theme/lib/src/widgets/afri_input_field.dart',
    ],
    testPaths: [
      'packages/core/core_theme/test/accessibility_primitives_test.dart',
    ],
  ),
  ComponentSeed(
    'inputs',
    'number',
    ComponentImplementationStatus.implemented,
    sourcePaths: [
      'packages/core/core_theme/lib/src/widgets/afri_form_fields.dart',
    ],
    testPaths: [
      'packages/core/core_theme/test/universal_component_primitives_test.dart',
    ],
  ),
  ComponentSeed(
    'inputs',
    'money',
    ComponentImplementationStatus.implemented,
    sourcePaths: [
      'packages/core/core_theme/lib/src/widgets/afri_form_fields.dart',
    ],
    testPaths: [
      'packages/core/core_theme/test/universal_component_primitives_test.dart',
    ],
  ),
  ComponentSeed(
    'inputs',
    'phone',
    ComponentImplementationStatus.implemented,
    sourcePaths: [
      'packages/core/core_theme/lib/src/widgets/afri_form_fields.dart',
    ],
    testPaths: [
      'packages/core/core_theme/test/universal_component_primitives_test.dart',
    ],
  ),
  ComponentSeed(
    'inputs',
    'email',
    ComponentImplementationStatus.implemented,
    sourcePaths: [
      'packages/core/core_theme/lib/src/widgets/afri_form_fields.dart',
    ],
    testPaths: [
      'packages/core/core_theme/test/universal_component_primitives_test.dart',
    ],
  ),
  ComponentSeed(
    'inputs',
    'password',
    ComponentImplementationStatus.implemented,
    sourcePaths: [
      'packages/core/core_theme/lib/src/widgets/afri_form_fields.dart',
    ],
    testPaths: [
      'packages/core/core_theme/test/universal_component_primitives_test.dart',
    ],
  ),
  ComponentSeed(
    'inputs',
    'date',
    ComponentImplementationStatus.implemented,
    sourcePaths: [
      'packages/core/core_theme/lib/src/widgets/afri_form_fields.dart',
    ],
    testPaths: [
      'packages/core/core_theme/test/universal_component_primitives_test.dart',
    ],
  ),
  ComponentSeed(
    'inputs',
    'time',
    ComponentImplementationStatus.implemented,
    sourcePaths: [
      'packages/core/core_theme/lib/src/widgets/afri_form_fields.dart',
    ],
    testPaths: [
      'packages/core/core_theme/test/universal_component_primitives_test.dart',
    ],
  ),
  ComponentSeed(
    'inputs',
    'search',
    ComponentImplementationStatus.implemented,
    sourcePaths: [
      'packages/core/core_theme/lib/src/widgets/afri_form_fields.dart',
      'packages/features/feat_home/lib/src/screens/discovery_search_screen.dart',
    ],
    testPaths: [
      'packages/core/core_theme/test/universal_component_primitives_test.dart',
      'packages/features/feat_home/test/discovery_search_test.dart',
    ],
  ),
  ComponentSeed(
    'inputs',
    'multiline',
    ComponentImplementationStatus.implemented,
    sourcePaths: [
      'packages/core/core_theme/lib/src/widgets/afri_input_field.dart',
    ],
    testPaths: [
      'packages/core/core_theme/test/accessibility_primitives_test.dart',
    ],
  ),
  ComponentSeed(
    'inputs',
    'otp',
    ComponentImplementationStatus.implemented,
    sourcePaths: [
      'packages/core/core_theme/lib/src/widgets/afri_form_fields.dart',
    ],
    testPaths: [
      'packages/core/core_theme/test/universal_component_primitives_test.dart',
    ],
  ),
  ComponentSeed(
    'inputs',
    'file_media_picker',
    ComponentImplementationStatus.implemented,
    sourcePaths: [
      'packages/core/core_theme/lib/src/widgets/afri_form_fields.dart',
    ],
    testPaths: [
      'packages/core/core_theme/test/universal_component_primitives_test.dart',
    ],
  ),

  ComponentSeed(
    'selection',
    'checkbox',
    ComponentImplementationStatus.implemented,
    sourcePaths: [
      'packages/core/core_theme/lib/src/widgets/afri_selection_controls.dart',
    ],
    testPaths: [
      'packages/core/core_theme/test/universal_component_primitives_test.dart',
    ],
  ),
  ComponentSeed(
    'selection',
    'radio',
    ComponentImplementationStatus.implemented,
    sourcePaths: [
      'packages/core/core_theme/lib/src/widgets/afri_selection_controls.dart',
    ],
    testPaths: [
      'packages/core/core_theme/test/universal_component_primitives_test.dart',
    ],
  ),
  ComponentSeed(
    'selection',
    'switch',
    ComponentImplementationStatus.implemented,
    sourcePaths: ['packages/core/core_theme/lib/src/widgets/afri_switch.dart'],
    testPaths: ['packages/core/core_theme/test/ui_source_guardrails_test.dart'],
  ),
  ComponentSeed(
    'selection',
    'segmented_control',
    ComponentImplementationStatus.implemented,
    sourcePaths: [
      'packages/core/core_theme/lib/src/widgets/afri_segmented_control.dart',
    ],
    testPaths: [
      'packages/core/core_theme/test/accessibility_primitives_test.dart',
    ],
  ),
  ComponentSeed(
    'selection',
    'chips',
    ComponentImplementationStatus.implemented,
    sourcePaths: ['packages/core/core_theme/lib/src/widgets/afri_chip.dart'],
    testPaths: ['packages/core/core_theme/test/touch_target_test.dart'],
  ),
  ComponentSeed(
    'selection',
    'tabs',
    ComponentImplementationStatus.implemented,
    sourcePaths: ['packages/core/core_theme/lib/src/widgets/afri_tab_bar.dart'],
    testPaths: ['packages/core/core_theme/test/ui_source_guardrails_test.dart'],
  ),
  ComponentSeed(
    'selection',
    'menus',
    ComponentImplementationStatus.implemented,
    sourcePaths: [
      'packages/core/core_theme/lib/src/widgets/afri_popup_menu_button.dart',
    ],
    testPaths: ['packages/core/core_theme/test/touch_target_test.dart'],
  ),

  ComponentSeed(
    'feedback',
    'banner',
    ComponentImplementationStatus.implemented,
    sourcePaths: [
      'packages/core/core_theme/lib/src/widgets/afri_state_banner.dart',
    ],
    testPaths: ['packages/core/core_theme/test/afri_state_banner_test.dart'],
  ),
  ComponentSeed(
    'feedback',
    'snackbar',
    ComponentImplementationStatus.implemented,
    sourcePaths: [
      'packages/core/core_theme/lib/src/widgets/afri_snackbar.dart',
    ],
    testPaths: [
      'packages/core/core_theme/test/universal_component_primitives_test.dart',
    ],
  ),
  ComponentSeed(
    'feedback',
    'toast',
    ComponentImplementationStatus.implemented,
    sourcePaths: ['packages/core/core_theme/lib/src/widgets/afri_toast.dart'],
    testPaths: ['packages/core/core_theme/test/ui_source_guardrails_test.dart'],
  ),
  ComponentSeed(
    'feedback',
    'inline_validation',
    ComponentImplementationStatus.implemented,
    sourcePaths: [
      'packages/core/core_theme/lib/src/widgets/afri_input_field.dart',
    ],
    testPaths: [
      'packages/core/core_theme/test/accessibility_primitives_test.dart',
    ],
  ),
  ComponentSeed(
    'feedback',
    'progress_indicator',
    ComponentImplementationStatus.implemented,
    sourcePaths: [
      'packages/core/core_theme/lib/src/widgets/afri_loading_indicator.dart',
    ],
    testPaths: ['packages/core/core_theme/test/ui_source_guardrails_test.dart'],
  ),
  ComponentSeed(
    'feedback',
    'skeleton',
    ComponentImplementationStatus.implemented,
    sourcePaths: [
      'packages/core/core_theme/lib/src/widgets/afri_skeleton.dart',
    ],
    testPaths: [
      'packages/core/core_theme/test/afri_async_state_view_test.dart',
    ],
  ),
  ComponentSeed(
    'feedback',
    'empty_state',
    ComponentImplementationStatus.implemented,
    sourcePaths: [
      'packages/core/core_theme/lib/src/widgets/afri_empty_view.dart',
    ],
    testPaths: [
      'packages/core/core_theme/test/afri_async_state_view_test.dart',
    ],
  ),
  ComponentSeed(
    'feedback',
    'error_state',
    ComponentImplementationStatus.implemented,
    sourcePaths: [
      'packages/core/core_theme/lib/src/widgets/afri_error_view.dart',
    ],
    testPaths: [
      'packages/core/core_theme/test/afri_async_state_view_test.dart',
    ],
  ),

  ComponentSeed(
    'data_display',
    'list_row',
    ComponentImplementationStatus.implemented,
    sourcePaths: [
      'packages/core/core_theme/lib/src/widgets/afri_list_row.dart',
    ],
    testPaths: ['packages/core/core_theme/test/ui_source_guardrails_test.dart'],
  ),
  ComponentSeed(
    'data_display',
    'card',
    ComponentImplementationStatus.implemented,
    sourcePaths: [
      'packages/core/core_theme/lib/src/widgets/afri_surface_card.dart',
    ],
    testPaths: ['packages/core/core_theme/test/ui_source_guardrails_test.dart'],
  ),
  ComponentSeed(
    'data_display',
    'table_row',
    ComponentImplementationStatus.implemented,
    sourcePaths: [
      'packages/core/core_theme/lib/src/widgets/afri_data_display.dart',
      'apps/rayon_sports/web/src/components/admin/admin-data-grid.tsx',
    ],
    testPaths: [
      'packages/core/core_theme/test/universal_component_primitives_test.dart',
    ],
  ),
  ComponentSeed(
    'data_display',
    'metric',
    ComponentImplementationStatus.implemented,
    sourcePaths: [
      'packages/core/core_theme/lib/src/widgets/afri_metric_tile.dart',
    ],
    testPaths: ['packages/core/core_theme/test/ui_source_guardrails_test.dart'],
  ),
  ComponentSeed(
    'data_display',
    'avatar',
    ComponentImplementationStatus.implemented,
    sourcePaths: [
      'packages/core/core_theme/lib/src/widgets/afri_data_display.dart',
    ],
    testPaths: [
      'packages/core/core_theme/test/universal_component_primitives_test.dart',
    ],
  ),
  ComponentSeed(
    'data_display',
    'badge',
    ComponentImplementationStatus.implemented,
    sourcePaths: [
      'packages/core/core_theme/lib/src/widgets/afri_data_display.dart',
    ],
    testPaths: [
      'packages/core/core_theme/test/universal_component_primitives_test.dart',
    ],
  ),
  ComponentSeed(
    'data_display',
    'timeline',
    ComponentImplementationStatus.implemented,
    sourcePaths: [
      'packages/core/core_theme/lib/src/widgets/afri_data_display.dart',
    ],
    testPaths: [
      'packages/core/core_theme/test/universal_component_primitives_test.dart',
    ],
  ),
  ComponentSeed(
    'data_display',
    'receipt',
    ComponentImplementationStatus.implemented,
    sourcePaths: [
      'packages/core/core_theme/lib/src/widgets/afri_data_display.dart',
    ],
    testPaths: [
      'packages/core/core_theme/test/universal_component_primitives_test.dart',
    ],
  ),
  ComponentSeed(
    'data_display',
    'activity_item',
    ComponentImplementationStatus.implemented,
    sourcePaths: [
      'packages/core/core_theme/lib/src/widgets/afri_data_display.dart',
    ],
    testPaths: [
      'packages/core/core_theme/test/universal_component_primitives_test.dart',
    ],
  ),

  ComponentSeed(
    'navigation',
    'list_item',
    ComponentImplementationStatus.implemented,
    sourcePaths: [
      'packages/core/core_theme/lib/src/widgets/afri_list_row.dart',
    ],
    testPaths: ['packages/core/core_theme/test/ui_source_guardrails_test.dart'],
  ),
  ComponentSeed(
    'navigation',
    'large_screen_breadcrumb',
    ComponentImplementationStatus.implemented,
    sourcePaths: [
      'packages/core/core_theme/lib/src/widgets/afri_navigation_primitives.dart',
    ],
    testPaths: [
      'packages/core/core_theme/test/universal_component_primitives_test.dart',
    ],
  ),
  ComponentSeed(
    'navigation',
    'back_button',
    ComponentImplementationStatus.implemented,
    sourcePaths: [
      'packages/core/core_theme/lib/src/widgets/afri_navigation_primitives.dart',
      'packages/core/core_theme/lib/src/widgets/afri_app_bar.dart',
    ],
    testPaths: [
      'packages/core/core_theme/test/universal_component_primitives_test.dart',
    ],
  ),
  ComponentSeed(
    'navigation',
    'deep_link_recovery',
    ComponentImplementationStatus.implemented,
    sourcePaths: [
      'packages/core/core_theme/lib/src/widgets/afri_deep_link_recovery.dart',
      'packages/core/core_router/lib/src/app_router.dart',
      'packages/core/core_app/lib/src/app.dart',
    ],
    testPaths: [
      'packages/core/core_theme/test/component_state_contract_test.dart',
      'packages/core/core_app/test/app_deep_link_test.dart',
    ],
  ),
  ComponentSeed(
    'navigation',
    'route_transition',
    ComponentImplementationStatus.implemented,
    sourcePaths: [
      'packages/core/core_router/lib/src/route_transitions.dart',
      'packages/core/core_theme/lib/src/club_theme.dart',
    ],
    testPaths: [
      'packages/core/core_router/test/route_transitions_test.dart',
      'packages/core/core_router/test/route_transitions_golden_test.dart',
      'packages/core/core_theme/test/accessibility_primitives_test.dart',
    ],
  ),

  ComponentSeed(
    'overlays',
    'dialog',
    ComponentImplementationStatus.implemented,
    sourcePaths: ['packages/core/core_theme/lib/src/widgets/afri_dialog.dart'],
    testPaths: ['packages/core/core_theme/test/ui_source_guardrails_test.dart'],
  ),
  ComponentSeed(
    'overlays',
    'bottom_sheet',
    ComponentImplementationStatus.implemented,
    sourcePaths: [
      'packages/core/core_theme/lib/src/widgets/afri_bottom_sheet.dart',
    ],
    testPaths: ['packages/core/core_theme/test/ui_source_guardrails_test.dart'],
  ),
  ComponentSeed(
    'overlays',
    'popover',
    ComponentImplementationStatus.implemented,
    sourcePaths: [
      'packages/core/core_theme/lib/src/widgets/afri_overlay_primitives.dart',
    ],
    testPaths: [
      'packages/core/core_theme/test/universal_component_primitives_test.dart',
    ],
  ),
  ComponentSeed(
    'overlays',
    'action_sheet',
    ComponentImplementationStatus.implemented,
    sourcePaths: [
      'packages/core/core_theme/lib/src/widgets/afri_action_sheet.dart',
    ],
    testPaths: ['packages/core/core_theme/test/ui_source_guardrails_test.dart'],
  ),
  ComponentSeed(
    'overlays',
    'command_menu',
    ComponentImplementationStatus.implemented,
    sourcePaths: [
      'packages/core/core_theme/lib/src/widgets/afri_overlay_primitives.dart',
    ],
    testPaths: [
      'packages/core/core_theme/test/universal_component_primitives_test.dart',
    ],
  ),

  ComponentSeed(
    'media',
    'image',
    ComponentImplementationStatus.implemented,
    sourcePaths: [
      'packages/core/core_theme/lib/src/widgets/afri_governed_image.dart',
    ],
    testPaths: ['packages/core/core_theme/test/afri_governed_image_test.dart'],
  ),
  ComponentSeed(
    'media',
    'video_thumbnail',
    ComponentImplementationStatus.implemented,
    sourcePaths: [
      'packages/core/core_theme/lib/src/widgets/afri_media_surfaces.dart',
    ],
    testPaths: [
      'packages/core/core_theme/test/universal_component_primitives_test.dart',
    ],
  ),
  ComponentSeed(
    'media',
    'document_preview',
    ComponentImplementationStatus.implemented,
    sourcePaths: [
      'packages/core/core_theme/lib/src/widgets/afri_media_surfaces.dart',
    ],
    testPaths: [
      'packages/core/core_theme/test/universal_component_primitives_test.dart',
    ],
  ),
  ComponentSeed(
    'media',
    'avatar',
    ComponentImplementationStatus.implemented,
    sourcePaths: [
      'packages/core/core_theme/lib/src/widgets/afri_data_display.dart',
      'packages/core/core_theme/lib/src/widgets/afri_media_surfaces.dart',
    ],
    testPaths: [
      'packages/core/core_theme/test/universal_component_primitives_test.dart',
    ],
  ),
  ComponentSeed(
    'media',
    'icon',
    ComponentImplementationStatus.implemented,
    sourcePaths: ['packages/core/core_theme/lib/src/tokens/icon_tokens.dart'],
    testPaths: ['packages/core/core_theme/test/ui_source_guardrails_test.dart'],
  ),
  ComponentSeed(
    'media',
    'qr_barcode_surface',
    ComponentImplementationStatus.implemented,
    sourcePaths: [
      'packages/core/core_theme/lib/src/widgets/afri_media_surfaces.dart',
      'packages/core/core_theme/lib/src/widgets/afri_scanner_shell.dart',
    ],
    testPaths: [
      'packages/core/core_theme/test/universal_component_primitives_test.dart',
    ],
  ),

  ComponentSeed(
    'security_privacy',
    'masked_value',
    ComponentImplementationStatus.implemented,
    sourcePaths: [
      'packages/core/core_theme/lib/src/widgets/afri_masked_value.dart',
    ],
    testPaths: ['packages/core/core_theme/test/afri_masked_value_test.dart'],
  ),
  ComponentSeed(
    'security_privacy',
    'reveal_control',
    ComponentImplementationStatus.implemented,
    sourcePaths: [
      'packages/core/core_theme/lib/src/widgets/afri_masked_value.dart',
    ],
    testPaths: ['packages/core/core_theme/test/afri_masked_value_test.dart'],
    notes:
        'Shared control is privacy-safe; route authorization/audit policy remains caller-owned.',
  ),
  ComponentSeed(
    'security_privacy',
    'session_timeout',
    ComponentImplementationStatus.implemented,
    sourcePaths: [
      'packages/core/core_theme/lib/src/widgets/afri_security_prompts.dart',
      'packages/core/core_auth/lib/src/user_session.dart',
    ],
    testPaths: [
      'packages/core/core_theme/test/universal_component_primitives_test.dart',
    ],
  ),
  ComponentSeed(
    'security_privacy',
    'permission_prompt',
    ComponentImplementationStatus.implemented,
    sourcePaths: [
      'packages/core/core_theme/lib/src/widgets/afri_security_prompts.dart',
    ],
    testPaths: [
      'packages/core/core_theme/test/universal_component_primitives_test.dart',
    ],
  ),
  ComponentSeed(
    'security_privacy',
    'consent_review',
    ComponentImplementationStatus.implemented,
    sourcePaths: [
      'packages/core/core_theme/lib/src/widgets/afri_security_prompts.dart',
    ],
    testPaths: [
      'packages/core/core_theme/test/universal_component_primitives_test.dart',
    ],
  ),

  ComponentSeed(
    'semantic_icons',
    'stable_role_catalog',
    ComponentImplementationStatus.implemented,
    sourcePaths: ['packages/core/core_theme/lib/src/tokens/icon_tokens.dart'],
    testPaths: ['packages/core/core_theme/test/ui_source_guardrails_test.dart'],
  ),
];

void main(List<String> arguments) {
  final workspace = Directory.current.absolute;
  final outputDirectory = Directory(
    arguments.isEmpty
        ? '${workspace.path}/output/component_inventory'
        : arguments.first,
  );
  final payload = generateComponentInventory(
    workspace: workspace,
    outputDirectory: outputDirectory,
  );
  stdout.writeln(payload['json_path']);
}

Map<String, Object?> generateComponentInventory({
  required Directory workspace,
  required Directory outputDirectory,
  File? evidenceFile,
}) {
  outputDirectory.createSync(recursive: true);
  final generatedAt = DateTime.now().toUtc().toIso8601String();
  final resolvedEvidenceFile =
      evidenceFile ??
      File('${workspace.path}/docs/governance/component-state-evidence.json');
  final evidenceByCell = _loadComponentStateEvidence(
    workspace: workspace,
    evidenceFile: resolvedEvidenceFile,
  );
  final components = <Map<String, Object?>>[];
  final statusCounts = <String, int>{
    for (final status in ComponentImplementationStatus.values) status.name: 0,
  };
  var stateCellsOpen = 0;
  var stateCellsNotImplemented = 0;
  var stateCellsNotApplicable = 0;
  var stateCellsTestEvidenced = 0;
  var stateCellsVisualEvidenced = 0;
  var stateCellsEvidenced = 0;

  for (final seed in componentSeeds) {
    statusCounts[seed.status.name] = statusCounts[seed.status.name]! + 1;
    final states = <String, Object?>{};
    final applicableStates = applicableStatesFor(seed);
    for (final state in componentStateCatalog) {
      final isMissing = seed.status == ComponentImplementationStatus.missing;
      final isApplicable = applicableStates.contains(state);
      final cellKey = '${seed.componentKey}|$state';
      final evidence = evidenceByCell[cellKey];
      if (!isApplicable && evidence != null) {
        throw FormatException(
          'Evidence is linked to non-applicable component-state cell '
          '"$cellKey".',
        );
      }
      final testEvidence = evidence?.testEvidence ?? const <String>[];
      final screenshotEvidence =
          evidence?.screenshotEvidence ?? const <String>[];
      final hasTestEvidence = testEvidence.isNotEmpty;
      final hasScreenshotEvidence = screenshotEvidence.isNotEmpty;
      final isEvidenced =
          isApplicable &&
          !isMissing &&
          hasTestEvidence &&
          hasScreenshotEvidence;
      if (!isApplicable) {
        stateCellsNotApplicable += 1;
      } else if (isMissing) {
        stateCellsNotImplemented += 1;
      } else if (isEvidenced) {
        stateCellsEvidenced += 1;
      } else {
        stateCellsOpen += 1;
      }
      if (isApplicable && hasTestEvidence) stateCellsTestEvidenced += 1;
      if (isApplicable && hasScreenshotEvidence) {
        stateCellsVisualEvidenced += 1;
      }
      states[state] = <String, Object?>{
        'evidence_status': !isApplicable
            ? 'not_applicable'
            : isMissing
            ? 'not_implemented'
            : isEvidenced
            ? 'evidenced'
            : 'open',
        'test_evidence': testEvidence,
        'screenshot_evidence': screenshotEvidence,
        'exception_id': null,
        'disposition_note': isEvidenced
            ? evidence!.dispositionNote
            : isApplicable
            ? _openDispositionNote(
                hasTestEvidence: hasTestEvidence,
                hasScreenshotEvidence: hasScreenshotEvidence,
              )
            : 'Not owned by this component contract; compose through a '
                  'dedicated state primitive or route.',
      };
    }
    components.add(<String, Object?>{
      'component_key': seed.componentKey,
      'category': seed.category,
      'name': seed.name,
      'implementation_status': seed.status.name,
      'source_paths': seed.sourcePaths,
      'candidate_test_paths': seed.testPaths,
      'notes': seed.notes,
      'states': states,
    });
  }

  final jsonPath = '${outputDirectory.path}/universal-component-inventory.json';
  final markdownPath =
      '${outputDirectory.path}/universal-component-inventory.md';
  final payload = <String, Object?>{
    'schema_version': '1.2',
    'generated_at': generatedAt,
    'workspace': workspace.path,
    'design_authority': '${workspace.path}/DESIGN.md',
    'component_count': components.length,
    'state_count': componentStateCatalog.length,
    'state_cell_count': components.length * componentStateCatalog.length,
    'status_counts': statusCounts,
    'open_state_cell_count': stateCellsOpen,
    'not_implemented_state_cell_count': stateCellsNotImplemented,
    'not_applicable_state_cell_count': stateCellsNotApplicable,
    'test_evidenced_state_cell_count': stateCellsTestEvidenced,
    'visual_evidenced_state_cell_count': stateCellsVisualEvidenced,
    'evidenced_state_cell_count': stateCellsEvidenced,
    'closure_complete':
        stateCellsOpen == 0 &&
        stateCellsNotImplemented == 0 &&
        stateCellsEvidenced > 0,
    'evidence_source': resolvedEvidenceFile.path,
    'components': components,
  };
  File(jsonPath).writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(payload)}\n',
  );

  final markdown = StringBuffer()
    ..writeln('# AFRICLUB Universal Component Inventory')
    ..writeln()
    ..writeln('- Generated: `$generatedAt`')
    ..writeln('- Components/variants: `${components.length}`')
    ..writeln('- Implemented: `${statusCounts['implemented']}`')
    ..writeln('- Partial: `${statusCounts['partial']}`')
    ..writeln('- Missing: `${statusCounts['missing']}`')
    ..writeln('- States per component: `${componentStateCatalog.length}`')
    ..writeln('- Applicable state cells requiring evidence: `$stateCellsOpen`')
    ..writeln('- Not applicable state cells: `$stateCellsNotApplicable`')
    ..writeln('- Test-evidenced applicable cells: `$stateCellsTestEvidenced`')
    ..writeln(
      '- Visual-evidenced applicable cells: `$stateCellsVisualEvidenced`',
    )
    ..writeln('- Fully evidenced state cells: `$stateCellsEvidenced`')
    ..writeln(
      '- Closure complete: '
      '`${stateCellsOpen == 0 && stateCellsNotImplemented == 0 && stateCellsEvidenced > 0}`',
    )
    ..writeln()
    ..writeln(
      'State applicability is component-owned and explicit. Candidate tests '
      'identify useful existing coverage but are not promoted to state '
      'evidence until each applicable state is reviewed and linked.',
    )
    ..writeln()
    ..writeln(
      '| Category | Component/variant | Status | Source count | Candidate tests | Notes |',
    )
    ..writeln('| --- | --- | --- | ---: | ---: | --- |');
  for (final component in components) {
    markdown.writeln(
      '| ${component['category']} | `${component['name']}` | '
      '${component['implementation_status']} | '
      '${(component['source_paths']! as List<Object?>).length} | '
      '${(component['candidate_test_paths']! as List<Object?>).length} | '
      '${component['notes']} |',
    );
  }
  File(markdownPath).writeAsStringSync(markdown.toString());

  return <String, Object?>{
    ...payload,
    'json_path': jsonPath,
    'markdown_path': markdownPath,
  };
}

String _openDispositionNote({
  required bool hasTestEvidence,
  required bool hasScreenshotEvidence,
}) {
  if (hasTestEvidence && !hasScreenshotEvidence) {
    return 'Current executable test evidence is linked; controlled visual '
        'proof is still required.';
  }
  if (!hasTestEvidence && hasScreenshotEvidence) {
    return 'Controlled visual proof is linked; current executable test '
        'evidence is still required.';
  }
  return 'Component-owned state; linked current test and visual evidence '
      'required.';
}

class _ComponentStateEvidence {
  const _ComponentStateEvidence({
    required this.testEvidence,
    required this.screenshotEvidence,
    required this.dispositionNote,
  });

  final List<String> testEvidence;
  final List<String> screenshotEvidence;
  final String dispositionNote;
}

Map<String, _ComponentStateEvidence> _loadComponentStateEvidence({
  required Directory workspace,
  required File evidenceFile,
}) {
  if (!evidenceFile.existsSync()) return const {};

  final decoded = jsonDecode(evidenceFile.readAsStringSync());
  if (decoded is! Map<String, Object?>) {
    throw FormatException(
      'Component-state evidence root must be a JSON object: '
      '${evidenceFile.path}',
    );
  }
  if (decoded['schema_version'] != '1.0') {
    throw FormatException(
      'Unsupported component-state evidence schema in ${evidenceFile.path}.',
    );
  }
  final rawCells = decoded['cells'];
  if (rawCells is! Map<String, Object?>) {
    throw const FormatException(
      'Component-state evidence must contain an object named "cells".',
    );
  }

  final knownCells = <String>{
    for (final seed in componentSeeds)
      for (final state in componentStateCatalog) '${seed.componentKey}|$state',
  };
  final result = <String, _ComponentStateEvidence>{};
  void addEvidenceCell(String cellKey, Object? rawCell, {String? groupId}) {
    if (!knownCells.contains(cellKey)) {
      throw FormatException(
        'Unknown component-state evidence cell "$cellKey".',
      );
    }
    if (result.containsKey(cellKey)) {
      throw FormatException(
        'Duplicate component-state evidence cell "$cellKey"'
        '${groupId == null ? '' : ' in group "$groupId"'}.',
      );
    }
    if (rawCell is! Map<String, Object?>) {
      throw FormatException('Evidence cell "$cellKey" must be a JSON object.');
    }
    final cell = rawCell;
    final testEvidence = _readEvidencePaths(
      workspace: workspace,
      cellKey: cellKey,
      field: 'test_evidence',
      value: cell['test_evidence'],
    );
    final screenshotEvidence = _readEvidencePaths(
      workspace: workspace,
      cellKey: cellKey,
      field: 'screenshot_evidence',
      value: cell['screenshot_evidence'],
    );
    final dispositionNote = cell['disposition_note'];
    if (dispositionNote is! String || dispositionNote.trim().isEmpty) {
      throw FormatException(
        'Evidence cell "$cellKey" requires a non-empty '
        'disposition_note.',
      );
    }
    result[cellKey] = _ComponentStateEvidence(
      testEvidence: testEvidence,
      screenshotEvidence: screenshotEvidence,
      dispositionNote: dispositionNote.trim(),
    );
  }

  for (final entry in rawCells.entries) {
    addEvidenceCell(entry.key, entry.value);
  }

  final rawGroups = decoded['groups'];
  if (rawGroups != null) {
    if (rawGroups is! List<Object?>) {
      throw const FormatException(
        'Component-state evidence "groups" must be a list.',
      );
    }
    for (final rawGroup in rawGroups) {
      if (rawGroup is! Map<String, Object?>) {
        throw const FormatException(
          'Each component-state evidence group must be a JSON object.',
        );
      }
      final groupId = rawGroup['id'];
      final groupCells = rawGroup['cells'];
      if (groupId is! String || groupId.trim().isEmpty) {
        throw const FormatException(
          'Each component-state evidence group requires a non-empty id.',
        );
      }
      if (groupCells is! List<Object?> || groupCells.isEmpty) {
        throw FormatException(
          'Evidence group "$groupId" requires a non-empty cells list.',
        );
      }
      final sharedEvidence = <String, Object?>{
        'test_evidence': rawGroup['test_evidence'],
        'screenshot_evidence': rawGroup['screenshot_evidence'],
        'disposition_note': rawGroup['disposition_note'],
      };
      for (final rawCellKey in groupCells) {
        if (rawCellKey is! String || rawCellKey.trim().isEmpty) {
          throw FormatException(
            'Evidence group "$groupId" contains an invalid cell key.',
          );
        }
        addEvidenceCell(
          rawCellKey.trim(),
          sharedEvidence,
          groupId: groupId.trim(),
        );
      }
    }
  }
  return result;
}

List<String> _readEvidencePaths({
  required Directory workspace,
  required String cellKey,
  required String field,
  required Object? value,
}) {
  if (value == null) return const [];
  if (value is! List<Object?>) {
    throw FormatException(
      'Evidence cell "$cellKey" field "$field" must be a list.',
    );
  }
  final paths = <String>[];
  for (final rawPath in value) {
    if (rawPath is! String || rawPath.trim().isEmpty) {
      throw FormatException(
        'Evidence cell "$cellKey" field "$field" contains an invalid path.',
      );
    }
    final path = rawPath.trim();
    if (path.startsWith('/') || path.contains('..')) {
      throw FormatException(
        'Evidence path must be workspace-relative and traversal-free: $path',
      );
    }
    if (!File('${workspace.path}/$path').existsSync()) {
      throw FormatException(
        'Evidence path does not exist for "$cellKey": $path',
      );
    }
    paths.add(path);
  }
  return List.unmodifiable(paths.toSet());
}
