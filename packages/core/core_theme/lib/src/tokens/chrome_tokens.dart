/// Semantic geometry and visual-strength tokens for shared app chrome.
///
/// These values keep top-command and floating bottom-navigation primitives
/// synchronized without leaking one-off literals back into widget source.
class AfriChromeTokens {
  AfriChromeTokens._();

  static const int maxTopCommandActions = 2;

  // September 2026 native Dark · Glow: measured visual bounds. Interactive
  // wrappers retain the platform minimum target independently of the artwork.
  static const double commandControlSize = 44;
  static const double commandBrandSize = commandControlSize;
  static const double commandSearchLabelMinWidth = 112;
  static const double commandSearchIconSize = 20;
  static const double commandActionIconSize = 22;
  static const double notificationDotSize = 11;
  static const double notificationDotInset = 2;
  static const double actionNotificationDotInset = 4;

  static const double navigationCompactHeight = 64;
  static const double navigationRegularHeight = 64;
  static const double navigationBottomMargin = 0;
  static const double navigationContentClearance = 12;
  static const double navigationHorizontalMargin = 16;
  static const double navigationBlurSigma = 24;
  static const double navigationLargeTextThreshold = 1.45;
  static const double navigationPressScale = 0.96;
  static const double navigationItemMinWidth = 64;
  static const double navigationItemHorizontalMargin = 0;
  static const double navigationItemVerticalMargin = 0;
  static const double navigationItemHorizontalPadding = 4;
  static const double navigationItemVerticalPadding = 4;
  static const double navigationLargeTextIconSize = 24;
  static const double navigationIconSize = 22;
  static const double navigationLabelGap = 2;

  static const double commandFillOpacity = 0.94;
  static const double commandGradientStartOpacity = 0.96;
  static const double chromeGradientEndOpacity = 0.98;
  static const double navigationActiveFillOpacity = 0.18;
  static const double navigationInactiveContentOpacity = 0.68;
}
