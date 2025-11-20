// lib/models/attendance_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceRecord {
  final String id;
  final String employeeId;
  final String employeeName;
  final DateTime date;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final int? timeSpentSeconds;
  final String status; // Derived status ('Present', 'Absent', 'Late', etc.)

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

  // Factory constructor to create an AttendanceRecord from a Firestore DocumentSnapshot
  factory AttendanceRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;

    final checkInTs = data?['checkin'] as Timestamp?;
    final checkOutTs = data?['checkout'] as Timestamp?;
    final dateStr = data?['date'] as String?;

    // Determine the status (simplified logic for demonstration)
    String status;
    if (checkInTs == null) {
      // NOTE: In a real app, you'd check if the date is today/past and if it was a workday/holiday.
      status = 'Absent';
    } else if (checkOutTs == null) {
      status = 'Present (Active)';
    } else {
      // Basic check for lateness (e.g., check-in after 9:00 AM)
      final checkInTime = checkInTs.toDate();
      if (checkInTime.hour > 9) {
        status = 'Late';
      } else {
        status = 'Present';
      }
    }

    return AttendanceRecord(
      id: doc.id,
      employeeId: data?['id'] ?? '',
      employeeName: data?['name'] ?? 'N/A',
      date: dateStr != null ? DateTime.parse(dateStr) : DateTime(2000), // Parse yyyy-MM-dd string
      checkIn: checkInTs?.toDate(),
      checkOut: checkOutTs?.toDate(),
      timeSpentSeconds: data?['time_spent'] as int?,
      status: status,
    );
  }
}