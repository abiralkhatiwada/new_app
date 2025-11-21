// (File: lib/services/firebase_service.dart)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/attendance_model.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Helper to get "yyyy-MM-dd" string (e.g., "2025-11-21")
  String _formatDate(DateTime dt) {
    return DateFormat('yyyy-MM-dd').format(dt);
  }

  // --- 1. Get Attendance Stream (READING) ---
  Stream<AttendanceRecord?> getAttendanceForDateStream(
      String employeeId, DateTime selectedDate) {
    
    // The document ID is just the date string (e.g., "2025-11-21")
    final dateDocId = _formatDate(selectedDate);
    
    // Construct the path: employees -> {employeeId} -> attendance -> {dateDocId}
    return _firestore
        .collection('employees')       
        .doc(employeeId)               
        .collection('attendance')      
        .doc(dateDocId)                
        .snapshots()
        .map((doc) {
          if (doc.exists) {
            try {
              return AttendanceRecord.fromFirestore(doc);
            } catch (e) {
              print("Error parsing data: $e");
              return null; 
            }
          }
          return null;
        });
  }

  // --- 2. Check-in (WRITING to Sub-collection) ---
  Future<void> checkIn(String employeeId) async {
    final now = DateTime.now();
    final dateDocId = _formatDate(now); 

    final docRef = _firestore
        .collection('employees')
        .doc(employeeId)
        .collection('attendance')
        .doc(dateDocId);

    await _firestore.runTransaction((tx) async {
      final snapshot = await tx.get(docRef);
      if (snapshot.exists) {
        throw Exception('Already checked in today');
      }
      
      // 🎯 FIX: Reliably fetch employee name from the parent document 🎯
      String empName = 'Unknown';
      try {
        final empDoc = await _firestore.collection('employees').doc(employeeId).get();
        if(empDoc.exists) {
             empName = empDoc.data()?['name'] ?? 'Unknown';
        }
      } catch (e) {
        print("Error fetching employee name: $e");
      }
      
      // Ensure we write both the ID and the fetched Name
      tx.set(docRef, {
        'id': employeeId,
        'name': empName, 
        'date': dateDocId,
        'checkin_time': Timestamp.fromDate(now),
        'checkout_time': null,
        'time_spent': null,
      });
    });
  }

  // --- 3. Check-out (WRITING to Sub-collection) ---
  Future<void> checkOut(String employeeId) async {
    final now = DateTime.now();
    final dateDocId = _formatDate(now);

    final docRef = _firestore
        .collection('employees')
        .doc(employeeId)
        .collection('attendance')
        .doc(dateDocId);

    await _firestore.runTransaction((tx) async {
      final snapshot = await tx.get(docRef);
      if (!snapshot.exists) {
        throw Exception('No check-in record found for today');
      }
      
      final data = snapshot.data()!;
      if (data['checkout_time'] != null) {
        throw Exception('Already checked out today');
      }

      final checkinTs = data['checkin_time'] as Timestamp;
      final seconds = now.difference(checkinTs.toDate()).inSeconds;

      tx.update(docRef, {
        'checkout_time': Timestamp.fromDate(now),
        'time_spent': seconds,
      });
    });
  }
  
}