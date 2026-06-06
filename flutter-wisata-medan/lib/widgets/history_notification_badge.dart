import 'package:flutter/material.dart';
import '../services/submission_review_notification_service.dart';

class HistoryNotificationBadge extends StatelessWidget {
  final Widget child;
  final double top;
  final double right;
  final String? statusFilter;

  const HistoryNotificationBadge({
    super.key,
    required this.child,
    this.top = 0,
    this.right = 0,
    this.statusFilter,
  });

  @override
  Widget build(BuildContext context) {
    SubmissionReviewNotificationService.instance.ensureTrackingCurrentUser();
    final listenable = statusFilter == null
        ? SubmissionReviewNotificationService.instance.hasUnreadNotifier
        : SubmissionReviewNotificationService.instance.unreadStatusNotifier;

    return ValueListenableBuilder(
      valueListenable: listenable,
      builder: (context, value, _) {
        final hasUnread = statusFilter == null
            ? (value as bool? ?? false)
            : ((value as Map<String, bool>?)?[statusFilter] ?? false);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            child,
            if (hasUnread)
              Positioned(
                top: top,
                right: right,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
