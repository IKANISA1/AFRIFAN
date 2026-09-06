// Synthetic H/A shields for isolated tests; no production images or downloads.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/painting.dart';

Future<void> installPredictFixtureImages() async {
  debugNetworkImageHttpClientProvider = () => _Client({
    'home': base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAGAAAABgCAYAAADimHc4AAACY0lEQVR4nO2dPUoEQRBGW9FIECOPIQYewMwrmFWkGIhgamwoCEaCkZknEMwELyDiKQRhEYwElQ78YRF1Zrrnq5p5L9tghqZef1W7ze5sSgAAAAAAMDZmml5wcnbxVmcpw2Fva/PfdZ2tuxT4CwSImety8fntRrmVBMdWr1pdRwLEIEAMAsQgQAwCxCBADALEIEAMAsQgQAwCxCBADALEIEAMAsQgQAwCxCBADALEIEAMAiJ/K6IWy0uz6fJw8fP1/ulzurl/aXSP9ZX5dLS98Pl64+ApPT69Jm+QADEIEIMAMQgQgwAxCBCDADEIEIMAMQgQ4/IoYprjna8jhaFBAsQgQEyIFrRf4DTUKyRADALEIEAMAqIJ+P4chLY/Th4a9q0OTZ4TkSEBYloJIAVldn+GBIhpLYAUpM67P0MCxHQSMOYUWIHd7/Ys6GHymtZ2J53ucX330vkefdC5BY0xBVZo92eYAWKKCBhTCqzg7s+QADHFBIwhBVZ492dIgJiiAoacAquw+6t/DvhYdOTni1rljVS8Bf20O6KmwX5Yd8ndnyl6s78e9B0pCTZV/NKF72UITy86ShKsp+JXT8Bvj7z3mAbroeVI3oZGmAsmKH5vCfA+F6zHliP/IOZtLpiw+JIEeJkLJmo5bo4ilHPBnBRfmgDVXDBxy3EpoI+W5GnXuzwN3avYkrwWP+NiETVbkreW4zYBNd6qei9+xt2CSswFzy0nRAK6zIVIxc+4XVibuRCh5YRKQJO5ELH4mRCLbPpvrlGKHyoB/y1upOJnQi32tzREK/xgOOEPpgEAAABSPN4BdIvHBljPrM8AAAAASUVORK5CYII=',
    ),
    'away': base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAGAAAABgCAYAAADimHc4AAAEg0lEQVR4nO2dv0sjURDHx6iggo2ChaiF2gmioAgWNnqFIorxJ1wnXCXY2Pln2F79VNBE42+52IgIiigoQbFIowgKooUi/j7eQt5tPM9L1t3MTJwPhOzbZMNjvu87895usgEQBEEQBEEQBOGrkZHsAWM/J1+96Ur6MPxjIOG4+rztivA/RABksj5z8Hf/N/d6whwV/OXoOHEAMiIAMiIAMiIAMiIAMiIAMiIAMiIAMiIAMiIAMiIAMiIAMiIAMiIAMiIAMiIAMiIAMiIAMiIAMiIAMiIAMiwFmJ+fh8rKSvMYHBwErrAUIBAIxLU3Njbg9PQUOMJOgLOzM9jc3Izb9/LyApOTk8ARdgIEg0Er4Jqmpiazf2pqCp6enoAbrAR4fX2NSz9DQ0NQVFRkbV9eXsLq6ipwg5UA29vbcHJyYm3n5+dDTU0NtLa2mtfHx8eBG6wEmJ6eNtvNzc2QmZkJnZ2dZt/W1hZEo1HgBBsBbm9vYWVlxbTb2tqs5+rqaqioqDD7JyYmgBNsBFhcXIS7uztru7CwMK4A9/T0mO2ZmRm4v78HLvg4ph+/3w9ZWX++Wd/d3Q3Z2dnW9vX1NSwtLQEXWAgQjUZhd3fXtHt7e+NeLygogJaWFpbFmIUAAdvUs76+HsrLy/96z8DAgNne29uDo6Mj4AB5AZ6fn628HqOvr+/d9zU2NkJpaSm7YkxegPX1dbi4uDBzf/u8305GRgb09/ebdigUMkWbMj5O6aejowNycnL++V5djPXaQHNzcwNzc3OQ1j/S85qrqytYW1szbaWU9UgUXYztrqAIaQeEQiF4fHx0fHwkEoH9/X2gjI/TeX8nUC/GZFNQJBKBw8PDuNPNtbW1CR07MjJiuUezsLAAo6OjVgFPCwfY74Pg9MfJya58S0pKEg5+bKUcQ8+EZmdnwUvscUjmPhFkU9DDw4N13TeG/YxnIug1QXFxMYs05EgAr10QDoetczr26Wcy6DVBV1eXaR8fH8POzg5QG/1kHTBtSz9VVVVxp5sTRa8JtBDUXeBYAK9ccH5+bn3LwWn6iVFWVgZ1dXWmvby8HOcqCqOfpAOCtovuPp8P2tvbHX+WdoG9rtidRYVPCeCFCwK2uX9DQ4O56O4EfdUsNzfXtPVXV/SFfSqjn+Q6IBwOu/ZZeXl5cHBwAJT5dApK1bqAEm6NfpI14KvhigBfyQXKxdGvEQcg45oAX8EFyuXRrxEHIOOqAOnsAuXB6Pd8HRDrNOf7iyqPB5LrKei90cHVDeqdfrs5+jWuftj/bvTNyQnqTfDdDnxKivDbTnNxgkpR8D13wEe3vKfoBpWClIMyDeVQFxRC8FPmAOp1QaUw5aAvxKjVBYUYfBQHUKkLCinlkDkVgVkXFJHgozoAqy4o5JRDUoBUpCRKo57k2dBhD1MS1eBrSHTCy5RELeWQdYAXU1XqwdeQ65AbdYFyymHhgM/UBU7B15DtmJO6wCHlsHJAMnWBY/A1LDqZ7L+5cgk+KwckGlxOwdew6uxHbuAW+LRhTP5gWhAEQRAEAfjxG1wTwpIpZ7tJAAAAAElFTkSuQmCC',
    ),
  });
}

class _Client implements HttpClient {
  _Client(this.images);
  final Map<String, List<int>> images;
  @override
  Future<HttpClientRequest> getUrl(Uri url) async =>
      _Request(images[url.path.contains('away') ? 'away' : 'home']!);
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
