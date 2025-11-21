import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // Import DateFormat for date comparison

class AttendanceRecord {
  final String id;
  final String employeeId;
  final String employeeName;
  final DateTime date;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final int? timeSpentSeconds;
  final String status;

  AttendanceRecord({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.date,
    this.checkIn,
    this.checkOut,
    this.timeSpentSeconds,
    required this.status,
  });

  factory AttendanceRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    // --- Timestamps and Time Spent ---
    final checkInTs = data['checkin_time'] as Timestamp?;
    final checkOutTs = data['checkout_time'] as Timestamp?;
    final int? timeSpent = (data['time_spent'] as num?)?.toInt();

    // --- Parse date safely ---
    DateTime parsedDate;
    try {
      final dateStr = data['date'] as String?;
      parsedDate = dateStr != null ? DateTime.parse(dateStr) : DateTime.now();
    } catch (e) {
      parsedDate = DateTime.now();
    }

    // --- Convert timestamps ---
    final checkInDate = checkInTs?.toDate();
    final checkOutDate = checkOutTs?.toDate();
    
    // --- Determine if the record is for Today ---
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final recordDateStr = DateFormat('yyyy-MM-dd').format(parsedDate);
    final isToday = today == recordDateStr;

    // 🎯 REVISED STATUS LOGIC 🎯
    String status = 'Absent';
    if (checkInDate != null) {
      if (checkOutDate == null) {
        // SCENARIO 1: Checked In, NO Checkout
        if (isToday) {
          // If viewing today's active session: Show 'Present (Active)'
          status = 'Present (Active)';
        } else {
          // If viewing a past date where checkout was missed: Show 'Present (No checkout)'
          status = 'Present (No checkout)';
        }
      } else {
        // SCENARIO 2: Checked In AND Checked Out: Show 'Present'
        status = 'Present';
      }
    }

    // Note: 'id' inside the document might be null, but doc.id is the date string
    return AttendanceRecord(
      id: doc.id,
      employeeId: data['id'] ?? '', 
      employeeName: data['name'] ?? 'Unknown',
      date: parsedDate,
      checkIn: checkInDate,
      checkOut: checkOutDate,
      timeSpentSeconds: timeSpent,
      status: status,
    );
  }
}