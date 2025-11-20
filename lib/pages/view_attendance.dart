// lib/pages/view_attendance.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/firebase_service.dart';
import '../models/attendance_model.dart'; // Ensure this model exists and is correct

class AttendancePage extends StatefulWidget {
  final String employeeId;
  const AttendancePage({super.key, required this.employeeId});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  final FirebaseService _firebaseService = FirebaseService();
  final Color primaryColor = const Color(0xFF4E2780);
  final Color accentColor = const Color(0xFFFFDE59);
  
  // State variable to track the currently selected date (defaults to today)
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    // Initialize the selected date to today
    _selectedDate = DateTime.now();
  }

  // --- Function to show Date Picker and update state ---
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2023, 1),
      lastDate: DateTime.now(), // Employees cannot check future attendance
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            primaryColor: primaryColor,
            colorScheme: ColorScheme.light(primary: primaryColor, onPrimary: Colors.white, secondary: accentColor),
            buttonTheme: const ButtonThemeData(textTheme: ButtonTextTheme.primary),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  // --- Helper to get status color ---
  Color _getStatusColor(String status) {
    switch (status) {
      case 'Present':
      case 'Present (Active)':
        return Colors.green.shade600;
      case 'Late':
        return Colors.amber.shade700;
      case 'Absent':
        return Colors.red.shade600;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Stream of attendance data for the currently selected single date
    final attendanceStream = _firebaseService.getAttendanceForDateStream(
      widget.employeeId,
      _selectedDate,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Attendance'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list), // The filtering/date selection icon
            onPressed: () => _selectDate(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // --- Display Selected Date ---
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.calendar_today, size: 20, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  'Viewing: ${DateFormat('EEE, MMM dd, yyyy').format(_selectedDate)}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          
          const Divider(height: 1),

          // --- StreamBuilder to Fetch and Display Daily Data ---
          Expanded(
            child: StreamBuilder<AttendanceRecord?>(
              stream: attendanceStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error loading data: ${snapshot.error}'));
                }

                final record = snapshot.data;

                if (record == null) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(30.0),
                      child: Text(
                        'No attendance record found for this date.',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                // Data is present, display the daily card view
                final checkInTime = record.checkIn != null ? DateFormat('HH:mm:ss a').format(record.checkIn!) : 'N/A';
                final checkOutTime = record.checkOut != null ? DateFormat('HH:mm:ss a').format(record.checkOut!) : 'N/A';
                final workDuration = record.timeSpentSeconds != null 
                    ? Duration(seconds: record.timeSpentSeconds!) 
                    : null;
                
                String statusText = record.status;
                if (statusText == 'Absent' && record.checkIn != null) {
                   // Correct status in case it was marked Absent but a check-in exists
                   statusText = 'Present (Active)'; 
                }


                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Status Header
                            Text(
                              'Status: $statusText',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: _getStatusColor(statusText),
                              ),
                            ),
                            const Divider(height: 20, thickness: 1),

                            // Check-in
                            _buildInfoRow(
                              icon: Icons.login,
                              title: 'Check-In Time:',
                              value: checkInTime,
                            ),
                            const SizedBox(height: 10),

                            // Check-out
                            _buildInfoRow(
                              icon: Icons.logout,
                              title: 'Check-Out Time:',
                              value: checkOutTime,
                            ),
                            const SizedBox(height: 10),
                            
                            // Work Duration
                            if (workDuration != null)
                              _buildInfoRow(
                                icon: Icons.timer,
                                title: 'Total Duration:',
                                value: '${workDuration.inHours}h ${workDuration.inMinutes.remainder(60)}m',
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Helper widget for information rows
  Widget _buildInfoRow({required IconData icon, required String title, required String value}) {
    return Row(
      children: [
        Icon(icon, color: primaryColor, size: 20),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(fontSize: 16),
        ),
      ],
    );
  }
}