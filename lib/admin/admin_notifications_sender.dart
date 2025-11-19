// admin_notifications_sender.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminNotificationSender {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Send in-app notification to all employees
  Future<void> sendToAllEmployees({
    required String title,
    required String message,
  }) async {
    final employees = await _db.collection('employees').get();

    WriteBatch batch = _db.batch();
    final now = DateTime.now();

    for (var emp in employees.docs) {
      final notifRef = _db
          .collection('employees')
          .doc(emp.id)
          .collection('notifications')
          .doc();

      batch.set(notifRef, {
        'title': title,
        'message': message,
        'isRead': false,
        'timestamp': now,
      });
    }

    await batch.commit();
  }
}

// ---------------- Admin UI ----------------
class SendNotificationPage extends StatefulWidget {
  const SendNotificationPage({super.key});

  @override
  State<SendNotificationPage> createState() => _SendNotificationPageState();
}

class _SendNotificationPageState extends State<SendNotificationPage> {
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isSending = false;

  final _sender = AdminNotificationSender();

  void _sendNotification() async {
    final title = _titleController.text.trim();
    final message = _messageController.text.trim();

    if (title.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both title and message')),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      await _sender.sendToAllEmployees(title: title, message: message);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification sent successfully!')),
      );
      _titleController.clear();
      _messageController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send notification: $e')),
      );
    } finally {
      setState(() => _isSending = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Notification Sender'),
        backgroundColor: const Color(0xFF4E2780),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                labelText: 'Message',
                border: OutlineInputBorder(),
              ),
              maxLines: 5,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isSending ? null : _sendNotification,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4E2780),
                minimumSize: const Size(double.infinity, 50),
              ),
              child: _isSending
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'Send Notification',
                      style: TextStyle(fontSize: 18),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
