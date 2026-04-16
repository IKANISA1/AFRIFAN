import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';

Future<String?> showGroupPrivacySettingsSheet(
  BuildContext context, {
  required String currentValue,
}) {
  return showAfriBottomSheet<String>(
    context: context,
    builder: (context) {
      return _GroupPrivacySettingsSheet(currentValue: currentValue);
    },
  );
}

class _GroupPrivacySettingsSheet extends StatefulWidget {
  const _GroupPrivacySettingsSheet({required this.currentValue});

  final String currentValue;

  @override
  State<_GroupPrivacySettingsSheet> createState() =>
      _GroupPrivacySettingsSheetState();
}

class _GroupPrivacySettingsSheetState
    extends State<_GroupPrivacySettingsSheet> {
  late String _value;

  @override
  void initState() {
    super.initState();
    _value = widget.currentValue.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    const options = <_PrivacyOptionData>[
      _PrivacyOptionData(
        value: 'PUBLIC',
        title: 'PUBLIC',
        description: 'Anyone can see the Group and request to join.',
        icon: AfriIcons.public,
      ),
      _PrivacyOptionData(
        value: 'FRIENDS OF MEMBERS',
        title: 'FRIENDS OF MEMBERS',
        description:
            'Only supporters connected to members can join via invite.',
        icon: AfriIcons.clubZone,
      ),
      _PrivacyOptionData(
        value: 'PRIVATE',
        title: 'PRIVATE',
        description: 'Invite code and approval are both required.',
        icon: AfriIcons.lock,
      ),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: ColorTokens.onSurfaceVariant.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        const SizedBox(height: SpacingTokens.spacing4),
        Text(
          'Group PRIVACY',
          style: TypographyTokens.monolithFont(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: ColorTokens.onSurface,
          ),
        ),
        const SizedBox(height: SpacingTokens.spacing2),
        Text(
          'Choose who can discover this Group and request to join.',
          style: TypographyTokens.bodyMedium(),
        ),
        const SizedBox(height: SpacingTokens.spacing4),
        ...options.map(
          (option) => Padding(
            padding: const EdgeInsets.only(bottom: SpacingTokens.spacing3),
            child: _PrivacyOptionCard(
              data: option,
              selected: _value == option.value,
              onTap: () => setState(() => _value = option.value),
            ),
          ),
        ),
        const SizedBox(height: SpacingTokens.spacing1),
        const GlassCard(
          animate: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PrivacyCompareRow(
                visibility: 'VISIBILITY',
                join: 'JOIN',
                approval: 'APPROVAL',
                heading: true,
              ),
              SizedBox(height: SpacingTokens.spacing2),
              _PrivacyCompareRow(
                visibility: 'Public',
                join: 'Request',
                approval: 'Optional',
              ),
              SizedBox(height: SpacingTokens.spacing1),
              _PrivacyCompareRow(
                visibility: 'Friends',
                join: 'Invite',
                approval: 'Member-led',
              ),
              SizedBox(height: SpacingTokens.spacing1),
              _PrivacyCompareRow(
                visibility: 'Private',
                join: 'Code',
                approval: 'Required',
              ),
            ],
          ),
        ),
        const SizedBox(height: SpacingTokens.spacing4),
        AfriButton(
          label: 'Save',
          fullWidth: true,
          onTap: () => Navigator.of(context).pop(_value),
        ),
      ],
    );
  }
}

class _PrivacyOptionCard extends StatelessWidget {
  const _PrivacyOptionCard({
    required this.data,
    required this.selected,
    required this.onTap,
  });

  final _PrivacyOptionData data;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(SpacingTokens.spacing4),
        decoration: BoxDecoration(
          color: ColorTokens.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: BorderTokens.all(
            color: selected ? ColorTokens.clubPrimary : ColorTokens.ghostBorder,
            width: selected ? 1.4 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: ColorTokens.clubPrimary.withValues(alpha: 0.2),
                    blurRadius: 24,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: selected
                    ? ColorTokens.clubPrimary.withValues(alpha: 0.14)
                    : ColorTokens.glassFill,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: Icon(
                data.icon,
                color: selected
                    ? ColorTokens.clubPrimary
                    : ColorTokens.clubAccent,
              ),
            ),
            const SizedBox(width: SpacingTokens.spacing4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.title,
                    style: TypographyTokens.monolithFont(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: ColorTokens.onSurface,
                    ),
                  ),
                  const SizedBox(height: SpacingTokens.spacing1),
                  Text(data.description, style: TypographyTokens.bodyMedium()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivacyCompareRow extends StatelessWidget {
  const _PrivacyCompareRow({
    required this.visibility,
    required this.join,
    required this.approval,
    this.heading = false,
  });

  final String visibility;
  final String join;
  final String approval;
  final bool heading;

  @override
  Widget build(BuildContext context) {
    final style = heading
        ? TypographyTokens.labelSmall().copyWith(
            color: ColorTokens.onSurfaceVariant,
          )
        : TypographyTokens.bodySmall();
    return Row(
      children: [
        Expanded(flex: 4, child: Text(visibility, style: style)),
        Expanded(flex: 3, child: Text(join, style: style)),
        Expanded(flex: 3, child: Text(approval, style: style)),
      ],
    );
  }
}

class _PrivacyOptionData {
  const _PrivacyOptionData({
    required this.value,
    required this.title,
    required this.description,
    required this.icon,
  });

  final String value;
  final String title;
  final String description;
  final IconData icon;
}
