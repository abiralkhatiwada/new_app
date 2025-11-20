// lib/services/firebase_service.dart



import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:intl/intl.dart';

import '../models/attendance_model.dart'; // Ensure this path is correct



class FirebaseService {

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;



  String _formatDate(DateTime dt) {

    return DateFormat('yyyy-MM-dd').format(dt);

  }



  // Attendance doc id: "{employeeId}_{yyyy-MM-dd}"

  String _attendanceDocId(String employeeId, DateTime date) {

    return '${employeeId}_${_formatDate(date)}';

  }



  // 1) Admin: add employee (id + name) — call once per employee

  Future<void> addEmployee(String id, String name) async {

    final docRef = _firestore.collection('employees').doc(id);

    await docRef.set({

      'id': id,

      'name': name,

    }, SetOptions(merge: true));

  }



  // 2) Get today's attendance (returns Map or null)

  Future<Map<String, dynamic>?> getTodayStatus(String employeeId) async {

    final now = DateTime.now();

    final docId = _attendanceDocId(employeeId, now);

    final doc = await _firestore.collection('attendance').doc(docId).get();

    if (doc.exists) return doc.data() as Map<String, dynamic>;

    return null;

  }



  // 3) Check-in: create today's attendance doc only if it doesn't exist

  Future<void> checkIn(String employeeId) async {

    final now = DateTime.now();

    final today = _formatDate(now);

    final docId = _attendanceDocId(employeeId, now);

    final docRef = _firestore.collection('attendance').doc(docId);



    // Get employee name for storing (optional)

    final empSnap = await _firestore.collection('employees').doc(employeeId).get();

    final empName = empSnap.exists ? (empSnap.data()!['name'] ?? '') : '';



    // Transaction ensures atomic check

    await _firestore.runTransaction((tx) async {

      final snapshot = await tx.get(docRef);

      if (snapshot.exists) {

        // Already checked in today — do nothing or throw

        throw Exception('Already checked in today');

      } else {

        tx.set(docRef, {

          'id': employeeId,

          'name': empName,

          'date': today,

          'checkin': Timestamp.fromDate(now), // client timestamp

          'checkout': null,

          'time_spent': null, // seconds

        });

      }

    });

  }



  // 4) Check-out: update checkout and compute time_spent (seconds)

  Future<void> checkOut(String employeeId) async {

    final now = DateTime.now();

    final docId = _attendanceDocId(employeeId, now);

    final docRef = _firestore.collection('attendance').doc(docId);



    await _firestore.runTransaction((tx) async {

      final snapshot = await tx.get(docRef);

      if (!snapshot.exists) {

        throw Exception('No check-in record found for today');

      }

      final data = snapshot.data()!;

      if (data['checkout'] != null) {

        throw Exception('Already checked out today');

      }



      // read checkin

      final checkinTs = data['checkin'] as Timestamp;

      final checkinDt = checkinTs.toDate();

      final seconds = now.difference(checkinDt).inSeconds;



      tx.update(docRef, {

        'checkout': Timestamp.fromDate(now),

        'time_spent': seconds,

      });

    });

  }



  // Helper: fetch attendance history for an employee (optional)

  Stream<QuerySnapshot> attendanceStreamForEmployee(String employeeId) {

    return _firestore

      .collection('attendance')

      .where('id', isEqualTo: employeeId)

      .orderBy('date', descending: true)

      .snapshots();

  }

  

  // 5) Get Attendance Stream for a specific SINGLE DATE <--- MISSING METHOD ADDED HERE

  Stream<AttendanceRecord?> getAttendanceForDateStream(

      String employeeId, DateTime selectedDate) {

    

    final docId = _attendanceDocId(employeeId, selectedDate);



    return _firestore

        .collection('attendance')

        .doc(docId)

        .snapshots() // Listen to changes on a single document

        .map((doc) {

      if (doc.exists) {

        // Use the existing factory constructor to create the model

        return AttendanceRecord.fromFirestore(doc);

      }

      return null; // Return null if the document does not exist for the date

    });

  }

}