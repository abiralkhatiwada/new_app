import 'package:flutter/material.dart';
import 'admin_notifications_sender.dart';

class SendNotificationPage extends StatefulWidget {
  const SendNotificationPage({super.key});

  @override
  State<SendNotificationPage> createState() => _SendNotificationPageState();
}

class _SendNotificationPageState extends State<SendNotificationPage> {
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  final AdminNotificationSender _sender = AdminNotificationSender();

  bool _isSending = false;

  Future<void> _send() async {
    final title = _titleController.text.trim();
    final message = _messageController.text.trim();

    if (title.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Title and Message are required")),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      await _sender.sendToAllEmployees(
        title: title,
        message: message,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Notification sent successfully!")),
      );

      _titleController.clear();
      _messageController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }

    setState(() => _isSending = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Send Notification"),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: "Notification Title",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _messageController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: "Notification Message",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 25),

            _isSending
                ? const CircularProgressIndicator()
                : ElevatedButton.icon(
                    onPressed: _send,
                    icon: const Icon(Icons.send),
                    label: const Text("Send to All Employees"),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
