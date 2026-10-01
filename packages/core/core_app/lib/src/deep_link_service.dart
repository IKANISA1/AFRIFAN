import 'dart:async';

import 'package:app_links/app_links.dart';

/// Fail-closed policy for destinations that may be handed to the in-app
/// router.
///
/// A route target must be a local absolute path. Schemes, authorities,
/// residual traversal segments, encoded separators, backslashes, and control
/// characters are rejected before route matching. Use [parse] when the raw
/// destination string is available so URI dot-segment normalization cannot
/// erase evidence of a traversal attempt before validation.
abstract final class InternalRouteUriPolicy {
  static final RegExp _controlCharacters = RegExp(r'[\u0000-\u001F\u007F]');
  static final RegExp _rawTraversalSegment = RegExp(
    r'(?:^|/)(?:\.|%2e)(?:\.|%2e)?(?:/|$)',
    caseSensitive: false,
  );
  static final RegExp _encodedSeparator = RegExp(
    r'%(?:2f|5c)',
    caseSensitive: false,
  );

  static Uri? parse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty ||
        _rawTraversalSegment.hasMatch(trimmed) ||
        _encodedSeparator.hasMatch(trimmed) ||
        trimmed.contains(r'\') ||
        _controlCharacters.hasMatch(trimmed)) {
      return null;
    }

    return validate(Uri.tryParse(trimmed));
  }

  static Uri? validate(Uri? candidate) {
    if (candidate == null) {
      return null;
    }
    final path = candidate.path;
    if (candidate.isAbsolute ||
        candidate.hasAuthority ||
        path.isEmpty ||
        !path.startsWith('/') ||
        path.contains('//') ||
        path.contains(r'\') ||
        _controlCharacters.hasMatch(path)) {
      return null;
    }

    try {
      // URI construction accepts percent-encoded bytes that are not valid
      // UTF8. Validate every component before downstream code decodes it.
      candidate.queryParametersAll;
      Uri.decodeComponent(candidate.fragment);
      for (final segment in candidate.pathSegments) {
        if (segment == '.' ||
            segment == '..' ||
            segment.contains('/') ||
            segment.contains(r'\') ||
            _controlCharacters.hasMatch(segment)) {
          return null;
        }
      }
    } on FormatException {
      return null;
    }

    return candidate;
  }
}

/// Normalizes inbound app/universal links into in-app router destinations.
class DeepLinkParser {
  DeepLinkParser({
    Uri? websiteUri,
    String? customScheme,
    Iterable<String> additionalCustomSchemes = const <String>[],
  }) : websiteUri = websiteUri == null
           ? null
           : _normalizeWebsiteUri(websiteUri),
       customSchemes = <String>{
         if (customScheme?.trim().isNotEmpty ?? false)
           customScheme!.trim().toLowerCase(),
         ...additionalCustomSchemes
             .map((scheme) => scheme.trim().toLowerCase())
             .where((scheme) => scheme.isNotEmpty),
       };

  factory DeepLinkParser.fromEnvironment() {
    final website = Uri.tryParse(
      const String.fromEnvironment('APP_WEBSITE_URL', defaultValue: '').trim(),
    );
    final additionalSchemes = const String.fromEnvironment(
      'APP_DEEP_LINK_SCHEME_ALIASES',
      defaultValue: '',
    ).split(',');
    return DeepLinkParser(
      websiteUri: website,
      customScheme: const String.fromEnvironment(
        'APP_DEEP_LINK_SCHEME',
        defaultValue: '',
      ),
      additionalCustomSchemes: additionalSchemes,
    );
  }

  final Uri? websiteUri;
  final Set<String> customSchemes;

  bool get isEnabled =>
      (websiteUri?.host.trim().isNotEmpty ?? false) || customSchemes.isNotEmpty;

  Uri? toInternalUri(Uri incoming) {
    try {
      return _toInternalUri(incoming);
    } on FormatException {
      // A custom-scheme path is decoded before the internal URI is built.
      return null;
    }
  }

  Uri? _toInternalUri(Uri incoming) {
    if (!isEnabled) {
      return null;
    }

    final normalizedIncomingScheme = incoming.scheme.trim().toLowerCase();
    if (_matchesWebsiteLink(incoming, normalizedIncomingScheme)) {
      final safe = InternalRouteUriPolicy.validate(
        _buildInternalUri(
          path: _normalizePath(incoming.path),
          query: incoming.hasQuery ? incoming.query : null,
          fragment: incoming.hasFragment ? incoming.fragment : null,
        ),
      );
      return safe == null ? null : _websiteDestination(safe);
    }

    if (customSchemes.contains(normalizedIncomingScheme)) {
      final path = _customSchemePath(incoming);
      if (path == null) {
        return null;
      }
      return InternalRouteUriPolicy.validate(
        _buildInternalUri(
          path: path,
          query: incoming.hasQuery ? incoming.query : null,
          fragment: incoming.hasFragment ? incoming.fragment : null,
        ),
      );
    }

    return null;
  }

  /// Website slugs belong to a different publication schema. Entity routes use
  /// a club-scoped resolver instead of treating a slug or reservation as an app ID.
  Uri _websiteDestination(Uri source) {
    const destinations = {
      '/': '/home',
      '/squad': '/club/team',
      '/news': '/club/news',
      '/fixtures': '/club/fixtures',
      '/results': '/club/results',
      '/standings': '/club/standings',
      '/partners': '/club/partners',
      '/fanclubs': '/fan-clubs',
      '/fanclubs/find': '/fan-clubs',
      '/fanclubs/diaspora': '/fan-clubs',
      '/join-gikundiro': '/membership',
      '/squad/men': '/club/team',
      '/squad/women': '/club/team',
      '/squad/academy': '/club/team',
      '/squad/technical-team': '/club/team',
    };
    const squadGroups = {
      '/squad/men': 'first_team',
      '/squad/women': 'women',
      '/squad/academy': 'academy',
      '/squad/technical-team': 'staff',
    };
    final group = squadGroups[source.path];
    if (group != null) {
      return Uri(
        path: '/club/team',
        queryParameters: {...source.queryParameters, 'group': group},
      );
    }
    final destination = destinations[source.path];
    if (destination != null) return source.replace(path: destination);
    if (RegExp(
      r'^/(squad/(player|staff)|news|shop/product|fanclubs|tickets/match|partners)/[^/]+$',
    ).hasMatch(source.path)) {
      return Uri(
        path: '/club/open-web',
        queryParameters: {'path': source.path},
      );
    }
    return source;
  }

  bool _matchesWebsiteLink(Uri incoming, String normalizedIncomingScheme) {
    final configuredHost = websiteUri?.host.trim().toLowerCase();
    if (configuredHost == null || configuredHost.isEmpty) {
      return false;
    }
    if (normalizedIncomingScheme != 'https' &&
        normalizedIncomingScheme != 'http') {
      return false;
    }
    return incoming.host.trim().toLowerCase() == configuredHost;
  }

  String? _customSchemePath(Uri incoming) {
    final segments = <String>[
      if (incoming.host.trim().isNotEmpty) incoming.host.trim(),
      ...incoming.pathSegments.where((segment) => segment.trim().isNotEmpty),
    ];
    if (segments.isEmpty) {
      return '/';
    }
    return '/${segments.join('/')}';
  }

  static Uri? _normalizeWebsiteUri(Uri raw) {
    final host = raw.host.trim();
    if (host.isEmpty) {
      return null;
    }
    return raw;
  }

  static Uri _buildInternalUri({
    required String path,
    String? query,
    String? fragment,
  }) {
    return Uri(
      path: path,
      query: query?.trim().isEmpty ?? true ? null : query,
      fragment: fragment?.trim().isEmpty ?? true ? null : fragment,
    );
  }

  static String _normalizePath(String rawPath) {
    final trimmed = rawPath.trim();
    if (trimmed.isEmpty || trimmed == '/') {
      return '/';
    }
    return trimmed.startsWith('/') ? trimmed : '/$trimmed';
  }
}

abstract class DeepLinkService {
  const DeepLinkService();

  Future<Uri?> getInitialUri();

  Stream<Uri> get uriStream;
}

class PlatformDeepLinkService extends DeepLinkService {
  PlatformDeepLinkService({AppLinks? appLinks})
    : _appLinks = appLinks ?? AppLinks();

  final AppLinks _appLinks;

  @override
  Future<Uri?> getInitialUri() async {
    try {
      return await _appLinks.getInitialLink();
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<Uri> get uriStream => _appLinks.uriLinkStream;
}

class FakeDeepLinkService extends DeepLinkService {
  FakeDeepLinkService({Uri? initialUri, Stream<Uri>? stream})
    : _initialUri = initialUri,
      _stream = stream ?? const Stream<Uri>.empty();

  final Uri? _initialUri;
  final Stream<Uri> _stream;

  @override
  Future<Uri?> getInitialUri() async => _initialUri;

  @override
  Stream<Uri> get uriStream => _stream;
}
