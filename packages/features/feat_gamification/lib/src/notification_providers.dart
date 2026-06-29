import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Client-side notification state — mirrors the fanafrika `useAppStore` notification
/// slice (notifications, addNotification, markAsRead, unreadCount).
///
/// This is a UI-layer store for in-app notification toasts and badges; it does NOT
/// replace the server-side `prediction_notifications` table.

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    this.read = false,
    required this.timestamp,
    this.route,
  });

  final String id;

  /// One of: challenge_received, challenge_settled, settlement, earn, system
  final String type;
  final String title;
  final String message;
  final bool read;
  final DateTime timestamp;

  /// Optional deep link route when the user taps a notification.
  final String? route;

  AppNotification copyWith({bool? read}) {
    return AppNotification(
      id: id,
      type: type,
      title: title,
      message: message,
      read: read ?? this.read,
      timestamp: timestamp,
      route: route,
    );
  }
}

class NotificationState {
  const NotificationState({this.notifications = const <AppNotification>[]});

  final List<AppNotification> notifications;

  int get unreadCount => notifications.where((n) => !n.read).length;

  NotificationState copyWith({List<AppNotification>? notifications}) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
    );
  }
}

class NotificationNotifier extends StateNotifier<NotificationState> {
  NotificationNotifier() : super(const NotificationState());

  int _counter = 0;

  /// Add a new notification. Returns the generated ID.
  String addNotification({
    required String type,
    required String title,
    required String message,
    String? route,
  }) {
    _counter++;
    final id = 'notif-$_counter-${DateTime.now().millisecondsSinceEpoch}';
    final notification = AppNotification(
      id: id,
      type: type,
      title: title,
      message: message,
      timestamp: DateTime.now(),
      route: route,
    );

    state = state.copyWith(
      notifications: [notification, ...state.notifications],
    );

    return id;
  }

  /// Mark a single notification as read.
  void markAsRead(String id) {
    state = state.copyWith(
      notifications: state.notifications
          .map((n) {
            return n.id == id ? n.copyWith(read: true) : n;
          })
          .toList(growable: false),
    );
  }

  /// Mark all notifications as read.
  void markAllAsRead() {
    state = state.copyWith(
      notifications: state.notifications
          .map((n) => n.copyWith(read: true))
          .toList(growable: false),
    );
  }

  /// Clear all notifications.
  void clearAll() {
    state = const NotificationState();
  }
}

final notificationProvider =
    StateNotifierProvider<NotificationNotifier, NotificationState>(
      (_) => NotificationNotifier(),
    );

/// Convenience: unread count provider for badge displays.
final unreadNotificationCountProvider = Provider<int>(
  (ref) => ref.watch(notificationProvider).unreadCount,
);
