import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class InAppNotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// 🔹 Stream for in-app display
  Stream<QuerySnapshot> allNotifications(String userId) {
    return _firestore
        .collection('employees')
        .doc(userId)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  /// 🔹 Mark all as read
  Future<void> markAllAsRead(String userId) async {
    final unread = await _firestore
        .collection('employees')
        .doc(userId)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .get();

    for (var doc in unread.docs) {
      await doc.reference.update({'isRead': true});
    }
  }

  /// 🔹 Send notification to a single employee
  Future<void> sendToUser(String userId, String title, String message) async {
    // 1️⃣ Save in Firestore
    await _firestore
        .collection('employees')
        .doc(userId)
        .collection('notifications')
        .add({
      'title': title,
      'message': message,
      'isRead': false,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // 2️⃣ Send FCM push
    final tokenDoc =
        await _firestore.collection('employees').doc(userId).get();

    if (tokenDoc.exists && tokenDoc.data()?['fcmToken'] != null) {
      final token = tokenDoc.data()?['fcmToken'];
      await sendPushNotification(token, title, message);
    }
  }

  /// 🔹 Send notification to all employees
  Future<void> sendToAll(String title, String message) async {
    final employees = await _firestore.collection('employees').get();

    for (var emp in employees.docs) {
      await sendToUser(emp.id, title, message);
    }
  }

  /// 🔹 Send FCM notification
  Future<void> sendPushNotification(String token, String title, String message) async {
    // FCM HTTP v1 API (requires server key)
    // For simplicity, you can use Firebase Cloud Functions
    // Here, we only outline the structure (actual sending requires server-side)
    print('Push notification to $token: $title - $message');
  }

  /// 🔹 Save FCM token for the user
  Future<void> saveToken(String userId) async {
    String? token = await _messaging.getToken();
    if (token != null) {
      await _firestore.collection('employees').doc(userId).update({
        'fcmToken': token,
      });
    }
  }
}
