import 'package:flutter/material.dart';

import 'package:intl/intl.dart';

import '../services/firebase_service.dart';

import '../models/attendance_model.dart';

class AttendancePage extends StatefulWidget {
  final String employeeId;

  const AttendancePage({super.key, required this.employeeId});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  final FirebaseService _firebaseService = FirebaseService();

  final Color primaryColor = const Color(0xFF4E2780); // Dark Purple

  final Color accentColor = const Color(0xFFFFDE59); // Yellow Accent

  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();

    _selectedDate = DateTime.now();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  // Updated to handle 'Present (Active)'

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Present':
        return Colors.green.shade600; // Completed (Green)

      case 'Present (Active)':
        return Colors.green; // Currently Active (Blue)

      case 'Present (No checkout)':
        return Colors.orange.shade600; // Past Date, Unresolved (Orange)

      case 'Absent':
        return Colors.red.shade600; // Missing (Red)

      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final attendanceStream = _firebaseService.getAttendanceForDateStream(
      widget.employeeId,
      _selectedDate,
    );

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Daily Attendance'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () => _selectDate(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // 📅 Date Selector Header

          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            color: primaryColor,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Selected Date:',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.white70),
                ),
                Text(
                  DateFormat('EEE, MMM dd, yyyy').format(_selectedDate),
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<AttendanceRecord?>(
              stream: attendanceStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                      child: CircularProgressIndicator(color: primaryColor));
                }

                final record = snapshot.data;

                if (record == null) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_busy, size: 60, color: Colors.grey),
                        SizedBox(height: 10),
                        Text(
                          'No attendance record found for this date.',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: _buildAttendanceCard(record),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- UI Card Method ---

  Widget _buildAttendanceCard(AttendanceRecord record) {
    final statusColor = _getStatusColor(record.status);

    final checkInTime = record.checkIn != null
        ? DateFormat('hh:mm:ss a').format(record.checkIn!)
        : 'N/A';

    final checkOutTime = record.checkOut != null
        ? DateFormat('hh:mm:ss a').format(record.checkOut!)
        : 'N/A';

    final duration = record.timeSpentSeconds != null
        ? '${(record.timeSpentSeconds! / 3600).toStringAsFixed(1)} hours'
        : 'N/A';

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Status Header Banner

          Container(
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(15),
                topRight: Radius.circular(15),
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: Text(
              record.status.toUpperCase(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
          ),

          // Details Body

          Padding(
            padding: const EdgeInsets.all(25.0),
            child: Column(
              children: [
                // 🛑 REMOVED: _buildDetailRow(Icons.person, 'Employee ID', record.employeeId),

                // 🛑 REMOVED: _buildDetailRow(Icons.badge, 'Name', record.employeeName),

                // 🛑 REMOVED: const Divider(height: 30),

                // Time Details (Using fixed Icons)

                _buildDetailRow(
                    Icons.login, 'Check In Time', checkInTime, primaryColor),

                const SizedBox(height: 15),

                _buildDetailRow(
                    Icons.logout, 'Check Out Time', checkOutTime, primaryColor),

                if (record.timeSpentSeconds != null) ...[
                  const Divider(height: 30),
                  _buildDetailRow(
                      Icons.schedule, 'Total Duration', duration, primaryColor),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Helper Method ---

  Widget _buildDetailRow(IconData icon, String label, String value,
      [Color? color]) {
    return Row(
      children: [
        Icon(icon, color: color ?? Colors.grey.shade600),
        const SizedBox(width: 15),
        Expanded(
          child: Text(label,
              style: TextStyle(
                  fontWeight: FontWeight.w500, color: Colors.grey.shade700)),
        ),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
        ),
      ],
    );
  }
}
