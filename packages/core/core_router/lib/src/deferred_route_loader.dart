import 'package:core_theme/core_theme.dart';
import 'package:flutter/material.dart';

class AfriDeferredRouteLoader extends StatefulWidget {
  const AfriDeferredRouteLoader({
    super.key,
    required this.loadLibrary,
    required this.builder,
    this.loadingBuilder,
    this.errorBuilder,
  });

  final Future<void> Function() loadLibrary;
  final WidgetBuilder builder;
  final WidgetBuilder? loadingBuilder;
  final Widget Function(BuildContext context, Object? error)? errorBuilder;

  @override
  State<AfriDeferredRouteLoader> createState() =>
      _AfriDeferredRouteLoaderState();
}

class _AfriDeferredRouteLoaderState extends State<AfriDeferredRouteLoader> {
  late final Future<void> _loadFuture = widget.loadLibrary();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return widget.loadingBuilder?.call(context) ??
              const _AfriDeferredRouteLoadingScreen();
        }

        if (snapshot.hasError) {
          return widget.errorBuilder?.call(context, snapshot.error) ??
              _AfriDeferredRouteErrorScreen(error: snapshot.error);
        }

        return AnimatedSwitcher(
          duration: AfriMotion.resolve(context, AfriMotion.quick),
          switchInCurve: AfriMotion.enterCurve,
          child: Builder(
            key: const ValueKey('loaded'),
            builder: widget.builder,
          ),
        );
      },
    );
  }
}

class _AfriDeferredRouteLoadingScreen extends StatelessWidget {
  const _AfriDeferredRouteLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return AfriScreenScaffold(
      backgroundColor: ColorTokens.background,
      showAppBar: false,
      scrollable: false,
      constrainContent: true,
      child: const Padding(
        padding: EdgeInsets.fromLTRB(
          SpacingTokens.screenPadding,
          SpacingTokens.spacing6,
          SpacingTokens.screenPadding,
          SpacingTokens.spacing10,
        ),
        child: AfriSkeletonList(itemCount: 4),
      ),
    );
  }
}

class _AfriDeferredRouteErrorScreen extends StatelessWidget {
  const _AfriDeferredRouteErrorScreen({required this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    return AfriScreenScaffold(
      backgroundColor: ColorTokens.background,
      showAppBar: false,
      scrollable: false,
      constrainContent: true,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(SpacingTokens.screenPadding),
          child: AfriStateView.error(
            title: 'Screen failed to load',
            message: error?.toString() ?? 'Please try again.',
            compact: true,
          ),
        ),
      ),
    );
  }
}
