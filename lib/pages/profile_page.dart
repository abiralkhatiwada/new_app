// lib/pages/profile_page.dart



import 'package:flutter/material.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../pages/login_page.dart'; // Ensure this path is correct

// import the actual AttendancePage file here (assuming it's in '../pages/view_attendance.dart')

import 'view_attendance.dart'; // <--- ASSUMING view_attendance.dart is now the correct path



// --- TEMPORARY PLACEHOLDER REMOVED ---

// The actual AttendancePage class definition below is now used.



class ProfilePage extends StatelessWidget {

  final String employeeId; 

  final String employeeName;



  // Brand colors

  final Color primaryColor = const Color(0xFF4E2780); // Deep Purple

  final Color accentColor = const Color(0xFFFFDE59); // Bright Yellow/Gold



  const ProfilePage({

    super.key,

    required this.employeeId,

    required this.employeeName,

  });



  // ---------------- Logout Function ----------------

  Future<void> _logout(BuildContext context) async {

    bool? confirm = await showDialog<bool>(

      context: context,

      builder: (context) => AlertDialog(

        title: const Text('Logout'),

        content: const Text('Are you sure you want to log out?'),

        actions: [

          TextButton(

            onPressed: () => Navigator.pop(context, false),

            child: const Text('Cancel'),

          ),

          TextButton(

            onPressed: () => Navigator.pop(context, true),

            child: const Text('Logout', style: TextStyle(color: Colors.red)),

          ),

        ],

      ),

    );



    if (confirm != true) return;



    final prefs = await SharedPreferences.getInstance();

    await prefs.remove('lastActiveDate');



    if (!context.mounted) return;



    Navigator.pushAndRemoveUntil(

      context,

      MaterialPageRoute(builder: (context) => const LoginPage()),

      (route) => false,

    );

  }



  // ---------------- New Navigation Function (CORRECTED) ----------------

  void _viewAttendance(BuildContext context) {

    Navigator.push(

      context,

      // Pass the employeeId when navigating to the actual AttendancePage

      MaterialPageRoute(builder: (context) => AttendancePage(employeeId: employeeId)),

    );

  }



  @override

  Widget build(BuildContext context) {

    // Get initials for avatar

    String initials = employeeName.isNotEmpty

        ? employeeName.trim().split(' ').map((l) => l[0]).take(2).join()

        : 'E';



    return Container(

      decoration: const BoxDecoration(

        color: Colors.white,

        borderRadius: BorderRadius.only(

          topLeft: Radius.circular(30),

          topRight: Radius.circular(30),

        ),

      ),

      child: Column(

        mainAxisSize: MainAxisSize.min, // *** CRITICAL: Tells the Column to only take up minimum space vertically

        children: [

          // --- Compact Header Section ---

          Container(

            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),

            decoration: BoxDecoration(

              color: primaryColor,

              borderRadius: const BorderRadius.only(

                topLeft: Radius.circular(30),

                topRight: Radius.circular(30),

                bottomLeft: Radius.circular(20),

                bottomRight: Radius.circular(20),

              ),

            ),

            child: Row(

              crossAxisAlignment: CrossAxisAlignment.center,

              children: [

                // Avatar

                Container(

                  padding: const EdgeInsets.all(2),

                  decoration: const BoxDecoration(

                    color: Colors.white,

                    shape: BoxShape.circle,

                  ),

                  child: CircleAvatar(

                    radius: 35,

                    backgroundColor: accentColor,

                    child: Text(

                      initials.toUpperCase(),

                      style: TextStyle(

                        fontSize: 24,

                        fontWeight: FontWeight.bold,

                        color: primaryColor,

                      ),

                    ),

                  ),

                ),

                const SizedBox(width: 20),



                // Name Only (Vertically and Horizontally Centered)

                Expanded(

                  child: Column(

                    crossAxisAlignment: CrossAxisAlignment.center,

                    mainAxisAlignment: MainAxisAlignment.center,

                    children: [

                      Text(

                        employeeName,

                        textAlign: TextAlign.center,

                        style: const TextStyle(

                          fontSize: 30,

                          fontWeight: FontWeight.bold,

                          color: Colors.white,

                        ),

                        overflow: TextOverflow.ellipsis,

                      ),

                    ],

                  ),

                ),



                // --- Profile Items (Right Side) - Stacked Layout ---

                Column(

                  mainAxisAlignment: MainAxisAlignment.center,

                  crossAxisAlignment: CrossAxisAlignment.end,

                  children: [

                    // Department

                    Text(

                      "Department",

                      style: TextStyle(

                        fontSize: 11,

                        color: Colors.white.withOpacity(0.7),

                      ),

                    ),

                    Text(

                      "Infivity Staff",

                      style: const TextStyle(

                        fontSize: 13,

                        fontWeight: FontWeight.bold,

                        color: Colors.white,

                      ),

                    ),

                    const SizedBox(height: 10), // Separator



                    // Status

                    Text(

                      "Status",

                      style: TextStyle(

                        fontSize: 11,

                        color: Colors.white.withOpacity(0.7),

                      ),

                    ),

                    Text(

                      "Active",

                      style: const TextStyle(

                        fontSize: 13,

                        fontWeight: FontWeight.bold,

                        color: Colors.white,

                      ),

                    ),

                  ],

                ),



                // Close "Handle" (Optional visual cue)

                Align(

                  alignment: Alignment.topRight,

                  child: Container(

                    width: 40,

                    height: 5,

                    margin: const EdgeInsets.only(left: 20, top: 10),

                    decoration: BoxDecoration(

                      color: Colors.white.withOpacity(0.3),

                      borderRadius: BorderRadius.circular(10),

                    ),

                  ),

                ),

              ],

            ),

          ),



          // --- Gap Adjustment ---

          const SizedBox(height: 15), // Small fixed gap



          // --- New Button (View Attendance) ---

          Padding(

            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),

            child: SizedBox(

              width: double.infinity,

              height: 50,

              child: ElevatedButton.icon( 

                onPressed: () => _viewAttendance(context), 

                icon: Icon(Icons.calendar_today, color: primaryColor), 

                style: ElevatedButton.styleFrom(

                  backgroundColor: accentColor, 

                  shape: RoundedRectangleBorder(

                    borderRadius: BorderRadius.circular(12),

                  ),

                ),

                label: Text(

                  "View Attendance", 

                  style: TextStyle(

                    color: primaryColor,

                    fontSize: 16,

                    fontWeight: FontWeight.bold,

                  ),

                ),

              ),

            ),

          ),



          // --- Logout Button (Pinned to Bottom of sheet) ---

          Padding(

            padding: const EdgeInsets.fromLTRB(20, 5, 20, 20),

            child: SizedBox(

              width: double.infinity,

              height: 50,

              child: ElevatedButton.icon(

                onPressed: () => _logout(context),

                style: ElevatedButton.styleFrom(

                  backgroundColor: Colors.red[50],

                  elevation: 0,

                  shape: RoundedRectangleBorder(

                    borderRadius: BorderRadius.circular(12),

                    side: BorderSide(color: Colors.red.shade200),

                  ),

                ),

                icon: const Icon(Icons.logout_rounded, color: Colors.red),

                label: const Text(

                  "Log Out",

                  style: TextStyle(

                    color: Colors.red,

                    fontSize: 16,

                    fontWeight: FontWeight.bold,

                  ),

                ),

              ),

            ),

          ),

        ],

      ),

    );

  }

}