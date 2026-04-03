import 'package:core_auth/core_auth.dart';
import 'package:core_theme/core_theme.dart';
import 'package:core_utils/core_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final TextEditingController _momoController = TextEditingController();
  bool _isLoading = false;

  String get _momoValue => _momoController.text.trim();

  @override
  void initState() {
    super.initState();
    _momoController.addListener(_onMomoChanged);
  }

  @override
  void dispose() {
    _momoController
      ..removeListener(_onMomoChanged)
      ..dispose();
    super.dispose();
  }

  void _onMomoChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _linkMomoAndContinue() async {
    if (_momoValue.isEmpty) {
      return;
    }

    setState(() => _isLoading = true);

    var authState = ref.read(authStateProvider);
    final authNotifier = ref.read(authStateProvider.notifier);

    if (authState is! AuthAuthenticated) {
      await authNotifier.signInAnonymously();
      authState = ref.read(authStateProvider);
    }

    if (authState is! AuthAuthenticated) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      final message = switch (authState) {
        AuthError() => authState.message,
        _ => 'Could not prepare your anonymous profile.',
      };
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    final country = AfriCountryCatalog.resolve(
      country: authState.profile.country,
      phone: authState.profile.momoNumber ?? authState.profile.phone,
    );

    late final String normalizedMomo;
    try {
      normalizedMomo = country.buildE164Phone(_momoValue);
    } on FormatException catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      return;
    }

    final profile = authState.profile.copyWith(
      phone: normalizedMomo,
      momoNumber: normalizedMomo,
      momoProvider: country.providerId,
      country: country.isoCode,
    );

    final error = await authNotifier.updateProfile(profile);
    if (!mounted) return;

    final updatedState = ref.read(authStateProvider);
    setState(() => _isLoading = false);

    if (error == null && updatedState is AuthAuthenticated) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/home');
      }
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? 'Could not save your MOMO details.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(currentUserProvider);
    final alias = profile?.publicUserId == null
        ? '000 000'
        : AliasGenerator.format(profile!.publicUserId!).replaceAll('-', ' ');

    return Scaffold(
      backgroundColor: ColorTokens.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: ColorTokens.onSurface),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/onboarding');
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(SpacingTokens.spacing8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'LINK MOBILE MONEY',
                style: TypographyTokens.headlineLarge(),
              ),
              const SizedBox(height: SpacingTokens.spacing4),
              Text(
                'Link your MoMo number to create your profile.',
                style: TypographyTokens.bodyLarge().copyWith(
                  color: ColorTokens.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: SpacingTokens.spacing8),
              Container(
                padding: const EdgeInsets.all(SpacingTokens.spacing6),
                decoration: BoxDecoration(
                  color: ColorTokens.surface,
                  borderRadius: ShapeTokens.cardRadius,
                  border: Border.all(color: ColorTokens.ghostBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'YOUR PUBLIC IDENTITY',
                      style: TypographyTokens.labelMedium(),
                    ),
                    const SizedBox(height: SpacingTokens.spacing3),
                    Text(
                      alias,
                      style: TypographyTokens.numericAlias(
                        fontSize: 36,
                        color: ColorTokens.clubAccent,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: SpacingTokens.spacing10),
              TextField(
                controller: _momoController,
                keyboardType: TextInputType.phone,
                style: TypographyTokens.headlineMedium(),
                decoration: InputDecoration(
                  hintText: 'e.g. 078...',
                  hintStyle: TypographyTokens.headlineMedium().copyWith(
                    color: ColorTokens.outlineVariant,
                  ),
                  filled: true,
                  fillColor: ColorTokens.surface,
                  border: OutlineInputBorder(
                    borderRadius: ShapeTokens.inputRadius,
                    borderSide: BorderSide(color: ColorTokens.ghostBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: ShapeTokens.inputRadius,
                    borderSide: BorderSide(color: ColorTokens.ghostBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: ShapeTokens.inputRadius,
                    borderSide: BorderSide(color: ColorTokens.clubPrimary),
                  ),
                  prefixIcon: Icon(
                    Icons.phone_android,
                    color: ColorTokens.clubPrimary,
                  ),
                ),
              ),
              const SizedBox(height: SpacingTokens.spacing10),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: ColorTokens.clubPrimary,
                  padding: const EdgeInsets.symmetric(
                    vertical: SpacingTokens.spacing6,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: ShapeTokens.buttonRadius,
                  ),
                ),
                onPressed: _isLoading || _momoValue.isEmpty
                    ? null
                    : _linkMomoAndContinue,
                child: _isLoading
                    ? SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: ColorTokens.onSurface,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'CONFIRM & ENTER',
                        style: TypographyTokens.labelLarge().copyWith(
                          color: ColorTokens.onSurface,
                        ),
                      ),
              ),
              const SizedBox(height: SpacingTokens.spacing6),
            ],
          ),
        ),
      ),
    );
  }
}
