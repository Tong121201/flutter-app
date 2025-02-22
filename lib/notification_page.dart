import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class NotificationPage extends StatefulWidget {
  const NotificationPage({Key? key}) : super(key: key);

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool isSelectionMode = false;
  Set<String> selectedNotifications = {};
  String? currentStudentId;

  String _formatDateTime(DateTime dateTime) {
    final localDateTime = dateTime.toLocal();
    return DateFormat('MMM dd, yyyy, hh:mm a').format(localDateTime);
  }

  Future<String?> _getStudentId() async {
    if (currentStudentId != null) return currentStudentId;

    final User? currentUser = _auth.currentUser;
    if (currentUser?.email == null) return null;

    final emailDoc = await _firestore
        .collection('email')
        .doc(currentUser?.email)
        .get();

    currentStudentId = emailDoc.data()?['studentId'];
    return currentStudentId;
  }

  Future<void> _markAsRead(String studentId, String notificationId,
      List<dynamic> notifications) async {
    final notificationIndex = notifications.indexWhere((notification) =>
    notification['applicationId'] + notification['createdAt'] ==
        notificationId);

    if (notificationIndex != -1) {
      notifications[notificationIndex]['read'] = true;
      await _firestore
          .collection('allStudents')
          .doc(studentId)
          .update({'notifications': notifications});
    }
  }

  void _toggleSelectionMode() {
    setState(() {
      isSelectionMode = !isSelectionMode;
      if (!isSelectionMode) {
        selectedNotifications.clear();
      }
    });
  }

  void _toggleNotificationSelection(String notificationId) {
    setState(() {
      if (selectedNotifications.contains(notificationId)) {
        selectedNotifications.remove(notificationId);
      } else {
        selectedNotifications.add(notificationId);
      }

      if (selectedNotifications.isEmpty && isSelectionMode) {
        isSelectionMode = false;
      }
    });
  }

  Future<void> _deleteSelectedNotifications(String studentId,
      List<dynamic> notifications) async {
    try {
      notifications.removeWhere((notification) =>
          selectedNotifications.contains(
              notification['applicationId'] + notification['createdAt']));

      await _firestore
          .collection('allStudents')
          .doc(studentId)
          .update({'notifications': notifications});

      setState(() {
        isSelectionMode = false;
        selectedNotifications.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notifications deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete notifications'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getFormattedStatus(Map<String, dynamic> notification) {
    final title = notification['title']?.toLowerCase() ?? '';
    final status = notification['status']?.toLowerCase() ?? '';

    if (title.contains('document reviewed')) {
      return 'Document Reviewed';
    } else
    if (title.contains('shortlisted') || status.contains('shortlisted')) {
      return 'Shortlisted';
    } else if (title.contains('rejected') || status.contains('rejected')) {
      return 'Rejected';
    } else if (title.contains('approved') || status.contains('approved') ||
        title.contains('updated offer information') ||
        status.contains('updated offer information')) {
      return 'Approved';
    }
    return status;
  }

  void _showNotificationDetails(BuildContext context,
      Map<String, dynamic> notification, String studentId,
      List<dynamic> notifications) async {
    final notificationId = notification['applicationId'] +
        notification['createdAt'];
    await _markAsRead(studentId, notificationId, notifications);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) =>
          Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification['title'],
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    notification['body'],
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.justify,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Company: ${notification['companyName']}',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Position: ${notification['jobTitle']}',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Status: ${_getFormattedStatus(notification)}',
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        'Close',
                        style: TextStyle(color: Colors.blue),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No notifications yet',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        scrolledUnderElevation: 0,
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: Colors.black,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (isSelectionMode)
            IconButton(
              icon: const Icon(
                Icons.delete_outline,
                color: Colors.red,
              ),
              onPressed: selectedNotifications.isEmpty
                  ? null
                  : () async {
                final studentId = await _getStudentId();
                if (studentId != null) {
                  final snapshot = await _firestore
                      .collection('allStudents')
                      .doc(studentId)
                      .get();
                  final data = snapshot.data() as Map<String, dynamic>;
                  final notifications =
                  data['notifications'] as List<dynamic>;
                  await _deleteSelectedNotifications(
                      studentId, notifications);
                }
              },
            ),
        ],
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      body: FutureBuilder<String?>(
        future: _getStudentId(),
        builder: (context, studentIdSnapshot) {
          if (studentIdSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!studentIdSnapshot.hasData || studentIdSnapshot.data == null) {
            return _buildEmptyState();
          }

          return StreamBuilder<DocumentSnapshot>(
            stream: _firestore
                .collection('allStudents')
                .doc(studentIdSnapshot.data)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || !snapshot.data!.exists) {
                return _buildEmptyState();
              }

              final data = snapshot.data!.data() as Map<String, dynamic>;
              final notifications =
              (data['notifications'] as List<dynamic>? ?? [])
                ..sort((a, b) =>
                    DateTime.parse(b['createdAt'])
                        .compareTo(DateTime.parse(a['createdAt'])));

              if (notifications.isEmpty) {
                return _buildEmptyState();
              }

              return ListView.builder(
                itemCount: notifications.length,
                padding: const EdgeInsets.all(16),
                itemBuilder: (context, index) {
                  final notification = notifications[index];
                  final notificationId =
                      notification['applicationId'] + notification['createdAt'];
                  final DateTime createdAt =
                  DateTime.parse(notification['createdAt']);
                  final bool isRead = notification['read'] ?? false;

                  return GestureDetector(
                    onLongPress: () {
                      if (!isSelectionMode) {
                        _toggleSelectionMode();
                        _toggleNotificationSelection(notificationId);
                      }
                    },
                    child: Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 12),
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: Colors.grey.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: InkWell(
                        onTap: () {
                          if (isSelectionMode) {
                            _toggleNotificationSelection(notificationId);
                          } else {
                            _showNotificationDetails(
                              context,
                              notification,
                              studentIdSnapshot.data!,
                              notifications,
                            );
                          }
                        },
                        child: Stack(
                          children: [
                            Container(
                              padding: EdgeInsets.only(
                                left: isSelectionMode ? 64 : 16,
                                right: 16,
                                top: 16,
                                bottom: 16,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment
                                        .start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              notification['title'] ??
                                                  'Notification',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: isRead
                                                    ? FontWeight.normal
                                                    : FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              notification['body'] ?? '',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey[600],
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              textAlign: TextAlign.justify,
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (!isRead)
                                        Container(
                                          width: 8,
                                          height: 8,
                                          margin: const EdgeInsets.only(
                                              top: 4, left: 8),
                                          decoration: const BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.blue,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.bottomRight,
                                    child: Text(
                                      _formatDateTime(createdAt),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelectionMode)
                              Positioned(
                                left: 16,
                                top: 0,
                                bottom: 0,
                                child: Center(
                                  child: Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: selectedNotifications
                                          .contains(notificationId)
                                          ? Colors.blue
                                          : Colors.grey[200],
                                      border: Border.all(
                                        color: selectedNotifications
                                            .contains(notificationId)
                                            ? Colors.blue
                                            : Colors.grey[400]!,
                                        width: 2,
                                      ),
                                    ),
                                    child: selectedNotifications
                                        .contains(notificationId)
                                        ? const Icon(
                                      Icons.check,
                                      size: 16,
                                      color: Colors.white,
                                    )
                                        : null,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}