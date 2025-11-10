import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/in_app_notification_service.dart';

class NotificationPage extends StatelessWidget {
  final String userId;
  final InAppNotificationService _notificationService = InAppNotificationService();

  NotificationPage({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications'), backgroundColor: Colors.blue),
      body: StreamBuilder<QuerySnapshot>(
        stream: _notificationService.allNotifications(userId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final notifications = snapshot.data!.docs;
          if (notifications.isEmpty) return const Center(child: Text('No notifications yet.'));

          _notificationService.markAllAsRead(userId); // Mark all as read

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final data = notifications[index].data() as Map<String, dynamic>;
              return ListTile(
                leading: const Icon(Icons.notifications),
                title: Text(data['title'] ?? ''),
                subtitle: Text(data['message'] ?? ''),
                trailing: Text(
                  (data['timestamp'] != null)
                      ? (data['timestamp'] as Timestamp).toDate().toString().split('.')[0]
                      : '',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
