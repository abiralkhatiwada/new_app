import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/in_app_notification_service.dart';

class NotificationPage extends StatelessWidget {
  final String userId;
  final InAppNotificationService _notificationService = InAppNotificationService();

  // Define the consistent color scheme
  final Color primaryColor = const Color(0xFF4E2780); // Deep Purple
  final Color accentColor = const Color(0xFFFFDE59); // Bright Yellow/Gold
  final Color secondaryTextColor = Colors.grey.shade600; // For timestamps

  NotificationPage({super.key, required this.userId});

  // Helper to format Timestamp to a readable string (e.g., 'Dec 31, 2025 at 10:00 PM')
  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    final date = timestamp.toDate();
    return DateFormat('MMM d, yyyy h:mm a').format(date);
  }

  // --- Custom Modern Notification Item Widget ---
  Widget _buildModernNotificationItem({
    required String title,
    required String message,
    required Timestamp? timestamp,
    required bool isRead,
  }) {
    final timeString = _formatTimestamp(timestamp);

    return Container(
      margin: const EdgeInsets.only(bottom: 15.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border(
          left: BorderSide(
            // Use accent color for a left border/status indicator
            color: isRead ? Colors.grey.shade300 : accentColor, 
            width: isRead ? 4 : 6, // Thicker for unread
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          Padding(
            padding: const EdgeInsets.only(top: 2.0, right: 12.0),
            child: Icon(
              Icons.notifications_active_outlined,
              color: isRead ? primaryColor.withOpacity(0.7) : primaryColor,
              size: 24,
            ),
          ),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: isRead ? FontWeight.w600 : FontWeight.w800,
                    fontSize: 16,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 6),
                // Message/Body
                Text(
                  message,
                  style: TextStyle(
                    color: secondaryTextColor,
                    fontSize: 14,
                  ),
                  maxLines: 2, // Limit message preview
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                // Timestamp
                Text(
                  timeString,
                  style: TextStyle(
                    fontSize: 11,
                    color: secondaryTextColor.withOpacity(0.7),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  // ---------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Crucial: Mark all notifications as read immediately when the user enters the page.
    _notificationService.markAllAsRead(userId);

    return Scaffold(
      backgroundColor: Colors.grey[100], // Light background for contrast
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: TextStyle(
            color: accentColor,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        backgroundColor: primaryColor,
        elevation: 4, // Added elevation back for contrast against body
        iconTheme: IconThemeData(color: accentColor), // Back button color
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _notificationService.allNotifications(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: primaryColor));
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error loading notifications: ${snapshot.error}'));
          }

          final notifications = snapshot.data!.docs;
          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off, size: 80, color: secondaryTextColor),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications yet.',
                    style: TextStyle(fontSize: 18, color: secondaryTextColor),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(20.0), // Increased padding
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final data = notifications[index].data() as Map<String, dynamic>;
              // Since we mark them all as read on page entry, we assume 'true' for a clean UI
              final isRead = data['isRead'] ?? true; 

              return _buildModernNotificationItem(
                title: data['title'] ?? 'System Notification',
                message: data['message'] ?? 'Check your status for an important update.',
                timestamp: data['timestamp'] as Timestamp?,
                isRead: isRead,
              );
            },
          );
        },
      ),
    );
  }
}