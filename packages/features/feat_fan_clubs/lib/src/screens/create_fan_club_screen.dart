import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CreateFanClubScreen extends StatefulWidget {
  const CreateFanClubScreen({super.key});

  @override
  State<CreateFanClubScreen> createState() => _CreateFanClubScreenState();
}

class _CreateFanClubScreenState extends State<CreateFanClubScreen> {
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  final Set<String> _regions = <String>{'Kigali'};
  bool _isPrivate = false;

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          icon: const Icon(Icons.arrow_back_rounded),
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
                decoration: const InputDecoration(hintText: 'Blue Army Kigali'),
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing3),
            _FieldCard(
              label: 'LOCATION / REGION',
              child: TextField(
                controller: _locationController,
                decoration: const InputDecoration(hintText: 'Kigali, Rwanda'),
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing3),
            _FieldCard(
              label: 'DESCRIPTION',
              child: TextField(
                controller: _descriptionController,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Tell supporters what this fan club is about.',
                ),
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing3),
            GlassCard(
              animate: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PHOTO', style: TypographyTokens.labelSmall()),
                  const SizedBox(height: SpacingTokens.spacing3),
                  OutlinedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Photo upload coming soon.'),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 72),
                    ),
                    child: const Text('UPLOAD CLUB PHOTO'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing3),
            GlassCard(
              animate: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('VISIBILITY', style: TypographyTokens.labelSmall()),
                  const SizedBox(height: SpacingTokens.spacing3),
                  SwitchListTile(
                    value: _isPrivate,
                    activeThumbColor: Theme.of(context).colorScheme.primary,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      _isPrivate ? 'PRIVATE CLUB' : 'PUBLIC CLUB',
                      style: TypographyTokens.bodyLarge(),
                    ),
                    subtitle: Text(
                      _isPrivate
                          ? 'Only approved members can discover this club.'
                          : 'Anyone can find and request to join this club.',
                      style: TypographyTokens.bodySmall(),
                    ),
                    onChanged: (value) => setState(() => _isPrivate = value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing3),
            GlassCard(
              animate: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('REGIONS SERVED', style: TypographyTokens.labelSmall()),
                  const SizedBox(height: SpacingTokens.spacing3),
                  Wrap(
                    spacing: SpacingTokens.spacing2,
                    runSpacing: SpacingTokens.spacing2,
                    children:
                        [
                              'Kigali',
                              'Northern',
                              'Southern',
                              'Western',
                              'Eastern',
                              'International',
                            ]
                            .map((region) {
                              return FilterChip(
                                selected: _regions.contains(region),
                                label: Text(region),
                                onSelected: (value) {
                                  setState(() {
                                    if (value) {
                                      _regions.add(region);
                                    } else {
                                      _regions.remove(region);
                                    }
                                  });
                                },
                              );
                            })
                            .toList(growable: false),
                  ),
                ],
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
                      'Reviewed by admin before going official.',
                      style: TypographyTokens.bodyMedium(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: SpacingTokens.spacing6),
            ClaymorphicButton(
              label: 'REQUEST APPROVAL',
              width: double.infinity,
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Fan club request submitted.'),
                    backgroundColor: ColorTokens.success,
                  ),
                );
                context.pop();
              },
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
