// Actual registered club assets served locally for isolated widget fixtures.
import 'dart:async';
import 'dart:io';
import 'package:flutter/painting.dart';

Future<void> installPredictFixtureImages() async {
  var root = Directory.current;
  while (!Directory(
    '${root.path}/packages/core/core_theme/assets/crests',
  ).existsSync()) {
    if (root.parent.path == root.path) {
      throw StateError('Repository assets unavailable');
    }
    root = root.parent;
  }
  debugNetworkImageHttpClientProvider = () => _Client({
    'home': File(
      '${root.path}/packages/core/core_theme/assets/crests/rayon-sports.png',
    ).readAsBytesSync(),
    'away': File(
      '${root.path}/packages/core/core_theme/assets/crests/apr-fc.png',
    ).readAsBytesSync(),
    'project': File(
      '${root.path}/apps/rayon_sports/assets/onboarding/rayon_matchday_team.webp',
    ).readAsBytesSync(),
  });
}

class _Client implements HttpClient {
  _Client(this.images);
  final Map<String, List<int>> images;
  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _Request(
    images[url.path.contains('project')
        ? 'project'
        : url.path.contains('away')
        ? 'away'
        : 'home']!,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Request implements HttpClientRequest {
  _Request(this.bytes);
  final List<int> bytes;
  @override
  HttpHeaders get headers => _Headers();
  @override
  Future<HttpClientResponse> close() async => _Response(bytes);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Headers implements HttpHeaders {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _Response extends Stream<List<int>> implements HttpClientResponse {
  _Response(this.bytes);
  final List<int> bytes;
  @override
  int get statusCode => 200;
  @override
  int get contentLength => bytes.length;
  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream.value(bytes).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
