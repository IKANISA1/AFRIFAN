/// Semantic geometry and visual-strength tokens for shared app chrome.
///
/// These values keep top-command and floating bottom-navigation primitives
/// synchronized without leaking one-off literals back into widget source.
class AfriChromeTokens {
  AfriChromeTokens._();

  static const int maxTopCommandActions = 2;

  static const double commandControlSize = 58;
  static const double commandBrandSize = 40;
  static const double commandSearchLabelMinWidth = 142;
  static const double commandSearchIconSize = 27;
  static const double commandActionIconSize = 25;
  static const double notificationDotSize = 11;
  static const double notificationDotInset = 2;
  static const double actionNotificationDotInset = 4;

  static const double navigationCompactHeight = 66;
  static const double navigationRegularHeight = 78;
  static const double navigationBottomMargin = 12;
  static const double navigationContentClearance = 12;
  static const double navigationHorizontalMargin = 18;
  static const double navigationBlurSigma = 24;
  static const double navigationLargeTextThreshold = 1.45;
  static const double navigationPressScale = 0.96;
  static const double navigationItemMinWidth = 64;
  static const double navigationItemHorizontalMargin = 3;
  static const double navigationItemVerticalMargin = 2;
  static const double navigationItemHorizontalPadding = 8;
  static const double navigationItemVerticalPadding = 6;
  static const double navigationLargeTextIconSize = 24;
  static const double navigationIconSize = 22;
  static const double navigationLabelGap = 2;

  static const double commandGradientStartOpacity = 0.96;
  static const double chromeGradientEndOpacity = 0.98;
  static const double navigationGradientHighlightOpacity = 0.08;
  static const double navigationGradientMidOpacity = 0.52;
  static const double navigationActiveFillOpacity = 0.18;
  static const double navigationInactiveContentOpacity = 0.68;
}
