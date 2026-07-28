import 'package:flutter/material.dart';

/// Semantic icon runtime implementation governed by root DESIGN.md.
///
/// Every feature screen references these instead of choosing ad-hoc
/// Material icons. This guarantees visual consistency and makes icon
/// swaps a single-file change.
class AfriIcons {
  AfriIcons._();

  // ── Size presets ──
  static const double sizeNav = 20.0;
  static const double sizeInline = 18.0;
  static const double sizeChip = 14.0;

  // ── Navigation ──
  static const IconData home = Icons.home_rounded;
  static const IconData fanzone = Icons.sports_soccer_rounded;
  static const IconData settings = Icons.settings_outlined;
  static const IconData appearance = Icons.contrast_rounded;
  static const IconData wallet = Icons.account_balance_wallet_outlined;
  static const IconData membership = Icons.card_membership_outlined;
  static const IconData contribute = Icons.volunteer_activism_outlined;
  static const IconData tickets = Icons.confirmation_number_outlined;
  static const IconData live = Icons.live_tv_rounded;
  static const IconData shop = Icons.storefront_outlined;
  static const IconData cart = Icons.shopping_cart_outlined;
  static const IconData groups = Icons.groups_outlined;
  static const IconData members = Icons.badge_outlined;
  static const IconData stadium = Icons.stadium_rounded;
  static const IconData face = Icons.face_rounded;

  // ── Actions ──
  static const IconData predict = Icons.sports_soccer_rounded;
  static const IconData transfer = Icons.send_rounded;
  static const IconData redeem = Icons.redeem_rounded;
  static const IconData share = Icons.share_rounded;
  static const IconData friend = Icons.person_search_rounded;
  static const IconData notifications = Icons.notifications_none_rounded;
  static const IconData notificationsActive =
      Icons.notifications_active_rounded;
  static const IconData search = Icons.search_rounded;
  static const IconData filter = Icons.tune_rounded;
  static const IconData back = Icons.arrow_back_rounded;
  static const IconData close = Icons.close_rounded;
  static const IconData more = Icons.more_horiz_rounded;
  static const IconData refresh = Icons.refresh_rounded;
  static const IconData link = Icons.link_rounded;
  static const IconData edit = Icons.edit_outlined;
  static const IconData logout = Icons.logout_rounded;
  static const IconData help = Icons.chat_outlined;
  static const IconData privacy = Icons.lock_outline;
  static const IconData lock = Icons.lock_rounded;
  static const IconData maintenance = Icons.engineering_rounded;
  static const IconData profile = Icons.person_outline_rounded;
  static const IconData admin = Icons.admin_panel_settings_outlined;
  static const IconData visibility = Icons.visibility_rounded;
  static const IconData visibilityOff = Icons.visibility_off_rounded;
  static const IconData mediaUnavailable = Icons.image_not_supported_rounded;
  static const IconData check = Icons.check_rounded;
  static const IconData verified = Icons.verified_rounded;

  // ── Status ──
  static const IconData statusLive = Icons.fiber_manual_record_rounded;
  static const IconData statusSuccess = Icons.check_circle_outline_rounded;
  static const IconData statusError = Icons.error_outline_rounded;
  static const IconData statusWarning = Icons.warning_amber_rounded;
  static const IconData statusInfo = Icons.info_outline_rounded;
  static const IconData statusPending = Icons.schedule_rounded;
  static const IconData statusEmpty = Icons.inbox_rounded;
  static const IconData statusBlocked = Icons.block_rounded;
  static const IconData statusLoading = Icons.hourglass_top_rounded;
  static const IconData statusWait = Icons.hourglass_bottom_rounded;
  static const IconData warning = Icons.warning_rounded;
  static const IconData offline = Icons.wifi_off_rounded;

  // ── Content ──
  static const IconData fixture = Icons.calendar_month_rounded;
  static const IconData leaderboard = Icons.leaderboard_outlined;
  static const IconData badge = Icons.military_tech_rounded;
  static const IconData challenge = Icons.flag_rounded;
  static const IconData streak = Icons.local_fire_department_rounded;
  static const IconData rank = Icons.emoji_events_rounded;
  static const IconData history = Icons.history_rounded;
  static const IconData myPicks = Icons.receipt_long_outlined;
  static const IconData terms = Icons.description_outlined;
  static const IconData league = Icons.table_chart_rounded;
  static const IconData clubZone = Icons.groups_rounded;
  static const IconData versus = Icons.compare_arrows_rounded;
  static const IconData rewards = Icons.redeem_rounded;
  static const IconData offers = Icons.local_offer_outlined;
  static const IconData premium = Icons.workspace_premium_rounded;
  static const IconData bolt = Icons.bolt_rounded;
  static const IconData star = Icons.star_rounded;
  static const IconData fetToken = Icons.toll_rounded;
  static const IconData gift = Icons.celebration_rounded;
  static const IconData pdf = Icons.picture_as_pdf_rounded;
  static const IconData excel = Icons.table_chart_rounded;
  static const IconData diamond = Icons.diamond_rounded;
  static const IconData campaign = Icons.campaign_rounded;
  static const IconData today = Icons.today_rounded;

  // ── Transaction ──
  static const IconData earn = Icons.stars_rounded;
  static const IconData receiveFet = Icons.call_received_rounded;
  static const IconData sendFet = Icons.call_made_rounded;
  static const IconData adjustment = Icons.tune_rounded;
  static const IconData openingBalance = Icons.account_balance_wallet_rounded;
  static const IconData out = Icons.north_east_rounded;
  static const IconData incoming = Icons.south_west_rounded;

  // ── Navigation chrome ──
  static const IconData chevronRight = Icons.chevron_right_rounded;
  static const IconData chevronLeft = Icons.chevron_left_rounded;
  static const IconData chevronDown = Icons.expand_more_rounded;
  static const IconData expandMore = Icons.expand_more_rounded;
  static const IconData expandLess = Icons.expand_less_rounded;
  static const IconData up = Icons.keyboard_arrow_up_rounded;
  static const IconData down = Icons.keyboard_arrow_down_rounded;
  static const IconData add = Icons.add_rounded;
  static const IconData remove = Icons.remove_rounded;
  static const IconData join = Icons.group_add_rounded;
  static const IconData shareIos = Icons.ios_share_rounded;
  static const IconData smile = Icons.sentiment_satisfied_alt_rounded;
  static const IconData dialpad = Icons.dialpad_rounded;
  static const IconData smartphone = Icons.smartphone_rounded;
  static const IconData public = Icons.public_rounded;
  static const IconData article = Icons.article_outlined;
  static const IconData score = Icons.sports_score_rounded;
  static const IconData sms = Icons.sms_rounded;
  static const IconData people = Icons.people_alt_rounded;
  static const IconData business = Icons.business_rounded;
  static const IconData category = Icons.category_rounded;
  static const IconData cloud = Icons.cloud_upload_rounded;
  static const IconData magic = Icons.auto_fix_high_rounded;
  static const IconData scoreboard = Icons.scoreboard_rounded;
  static const IconData forward = Icons.arrow_forward_rounded;

  // ── Misc ──
  static const IconData checkGroup = Icons.check_circle_rounded;
  static const IconData scan = Icons.qr_code_rounded;
  static const IconData qrCode = Icons.qr_code_2_rounded;
  static const IconData qrScan = Icons.qr_code_scanner_rounded;
  static const IconData faceScan = Icons.face_retouching_natural_rounded;
  static const IconData seat = Icons.event_seat_rounded;
  static const IconData shield = Icons.shield_rounded;
  static const IconData nfc = Icons.nfc_rounded;
  static const IconData addCard = Icons.add_card_rounded;
  static const IconData chat = Icons.chat_bubble_outline_rounded;
  static const IconData delete = Icons.delete_outline_rounded;
  static const IconData pin = Icons.push_pin_outlined;
  static const IconData copy = Icons.copy_rounded;
  static const IconData publish = Icons.publish_rounded;
  static const IconData unpublished = Icons.unpublished_rounded;
  static const IconData toggleOn = Icons.toggle_on_outlined;
  static const IconData timer = Icons.timer_outlined;
  static const IconData users = Icons.people_outline_rounded;
  static const IconData grid = Icons.grid_view_rounded;
  static const IconData chart = Icons.bar_chart_rounded;
  static const IconData language = Icons.language_rounded;
  static const IconData phone = Icons.phone_android_rounded;

  // ── Date & location ──
  static const IconData calendar = Icons.calendar_today_rounded;
  static const IconData location = Icons.location_on_outlined;
}
