/// Public discovery is usable before authentication, including offline recovery.
/// Account data, cart/checkout, admission and all write actions remain protected.
abstract final class PublicReadRoutes {
  static bool allows(Uri uri) {
    if (uri.hasScheme ||
        uri.hasAuthority ||
        uri.path.contains('%') ||
        uri.path.contains('..')) {
      return false;
    }
    if (uri.path == '/tickets' && uri.queryParameters['tab'] == 'mine') {
      return false;
    }
    return const {
          '/home',
          '/club',
          '/club/open-web',
          '/shop',
          '/fan-clubs',
          '/tickets',
        }.contains(uri.path) ||
        RegExp(
          r'^/club/(team|news|fixtures|results|standings|history|projects|partners)(/[^/]+)?$',
        ).hasMatch(uri.path) ||
        RegExp(
          r'^/(shop/product|fan-clubs|tickets/detail)/[^/]+$',
        ).hasMatch(uri.path);
  }
}
