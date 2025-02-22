import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CustomBottomNavigationBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;

  const CustomBottomNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
  });

  Future<String?> _getStudentId() async {
    final FirebaseAuth _auth = FirebaseAuth.instance;
    final FirebaseFirestore _firestore = FirebaseFirestore.instance;

    final User? currentUser = _auth.currentUser;
    if (currentUser?.email == null) return null;

    final emailDoc = await _firestore
        .collection('email')
        .doc(currentUser?.email)
        .get();

    return emailDoc.data()?['studentId'];
  }

  Widget _buildNotificationIcon(BuildContext context) {
    return StreamBuilder<String?>(
      stream: Stream.fromFuture(_getStudentId()),
      builder: (context, studentIdSnapshot) {
        if (!studentIdSnapshot.hasData) {
          return const Icon(Icons.notifications_outlined, size: 28);
        }

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('allStudents')
              .doc(studentIdSnapshot.data)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Icon(Icons.notifications_outlined, size: 28);
            }

            final data = snapshot.data!.data() as Map<String, dynamic>?;
            if (data == null) return const Icon(Icons.notifications_outlined, size: 28);

            final notifications = data['notifications'] as List<dynamic>? ?? [];
            final unreadCount = notifications.where((notification) =>
            !(notification['read'] ?? false)
            ).length;

            if (unreadCount == 0) {
              return const Icon(Icons.notifications_outlined, size: 28);
            }

            return Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_outlined, size: 28),
                Positioned(
                  right: -8,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      unreadCount > 99 ? '99+' : unreadCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        height: 1,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      backgroundColor: Colors.white,
      items: <BottomNavigationBarItem>[
        const BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined, size: 28),
          activeIcon: Icon(Icons.home, size: 28),
          label: 'Home',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.work_outline, size: 28),
          activeIcon: Icon(Icons.work, size: 28),
          label: 'Internship',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.description_outlined, size: 28),
          activeIcon: Icon(Icons.description, size: 28),
          label: 'My Application',
        ),
        BottomNavigationBarItem(
          icon: _buildNotificationIcon(context),
          activeIcon: const Icon(Icons.notifications, size: 28),
          label: 'Notification',
        ),
      ],
      currentIndex: selectedIndex,
      selectedItemColor: Colors.blue,
      unselectedItemColor: Colors.black54,
      selectedLabelStyle: const TextStyle(
        color: Colors.black,
        fontSize: 14, // Increased from 12
        fontWeight: FontWeight.w500,
      ),
      unselectedLabelStyle: const TextStyle(
        color: Colors.black54,
        fontSize: 14, // Increased from 12
      ),
      onTap: onItemTapped,
      type: BottomNavigationBarType.fixed,
      showSelectedLabels: true,
      showUnselectedLabels: false,
    );
  }
}