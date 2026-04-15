import 'package:flutter/material.dart';

/// Semantic icon aliases — single source of truth for icon choices.
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
  static const IconData wallet = Icons.account_balance_wallet_outlined;
  static const IconData membership = Icons.card_membership_outlined;
  static const IconData contribute = Icons.volunteer_activism_outlined;
  static const IconData tickets = Icons.confirmation_number_outlined;
  static const IconData live = Icons.live_tv_rounded;
  static const IconData shop = Icons.storefront_outlined;

  // ── Actions ──
  static const IconData predict = Icons.sports_soccer_rounded;
  static const IconData transfer = Icons.send_rounded;
  static const IconData redeem = Icons.redeem_rounded;
  static const IconData share = Icons.share_rounded;
  static const IconData friend = Icons.person_search_rounded;
  static const IconData notifications = Icons.notifications_none_rounded;
  static const IconData search = Icons.search_rounded;
  static const IconData filter = Icons.tune_rounded;
  static const IconData back = Icons.arrow_back_rounded;
  static const IconData close = Icons.close_rounded;
  static const IconData more = Icons.more_horiz_rounded;
  static const IconData refresh = Icons.refresh_rounded;
  static const IconData edit = Icons.edit_outlined;
  static const IconData logout = Icons.logout_rounded;
  static const IconData help = Icons.chat_outlined;
  static const IconData privacy = Icons.lock_outline;
  static const IconData profile = Icons.person_outline_rounded;
  static const IconData admin = Icons.admin_panel_settings_outlined;

  // ── Status ──
  static const IconData statusLive = Icons.fiber_manual_record_rounded;
  static const IconData statusSuccess = Icons.check_circle_outline_rounded;
  static const IconData statusError = Icons.error_outline_rounded;
  static const IconData statusWarning = Icons.warning_amber_rounded;
  static const IconData statusInfo = Icons.info_outline_rounded;
  static const IconData statusPending = Icons.schedule_rounded;
  static const IconData statusEmpty = Icons.inbox_rounded;

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

  // ── Transaction ──
  static const IconData earn = Icons.stars_rounded;
  static const IconData receiveFet = Icons.call_received_rounded;
  static const IconData sendFet = Icons.call_made_rounded;
  static const IconData adjustment = Icons.tune_rounded;
  static const IconData openingBalance = Icons.account_balance_wallet_rounded;

  // ── Navigation chrome ──
  static const IconData chevronRight = Icons.chevron_right_rounded;
  static const IconData chevronDown = Icons.expand_more_rounded;
  static const IconData expandMore = Icons.expand_more_rounded;
  static const IconData expandLess = Icons.expand_less_rounded;

  // ── Misc ──
  static const IconData checkCircle = Icons.check_circle_rounded;
  static const IconData scan = Icons.qr_code_rounded;
  static const IconData chat = Icons.chat_bubble_outline_rounded;
  static const IconData delete = Icons.delete_outline_rounded;
  static const IconData pin = Icons.push_pin_outlined;
  static const IconData copy = Icons.copy_rounded;
  static const IconData timer = Icons.timer_outlined;
  static const IconData users = Icons.people_outline_rounded;

  // ── Date & location ──
  static const IconData calendar = Icons.calendar_today_rounded;
  static const IconData location = Icons.location_on_outlined;
}
