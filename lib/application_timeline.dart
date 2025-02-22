import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:qiu_internar/service/notification_service.dart';
import 'models/module.dart';


class ApplicationTimeline extends StatelessWidget {
  final Module module;

  const ApplicationTimeline({Key? key, required this.module})
      : super(key: key);

  String getCurrentUserEmail() {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null) {
      return user.email!;
    } else {
      throw Exception("No logged-in user found or user email is null.");
    }
  }

  String formatDateTime(String? dateString) {
    if (dateString == null) return 'Not available';
    try {
      final DateTime date = DateTime.parse(dateString);
      // Remove the UTC+8 conversion since DateTime.parse already handles timezone
      return DateFormat('MMM d, y · h:mm a').format(date);
    } catch (e) {
      return 'Not available';
    }
  }

  String _formatDate(DateTime date) {
    // Remove the UTC+8 conversion
    return DateFormat('MMM d, y').format(date);
  }

  String _formatDateTime(DateTime date) {
    // Remove the UTC+8 conversion
    return DateFormat('MMM d, y · h:mm a').format(date);
  }

  IconData _getStageIcon(String stage, bool isCompleted, bool isRejected) {
    if (isRejected) return Icons.cancel_outlined;

    switch (stage.toLowerCase()) {
      case 'applied':
        return Icons.send_outlined;
      case 'document review':
        return isCompleted ? Icons.rate_review : Icons.pending_outlined;
      case 'shortlisted':
        return isCompleted ? Icons.person_search : Icons.people_outline;
      case 'approved':
        return Icons.verified_outlined;
      case 'withdrawn':
        return Icons.history;
      default:
        return Icons.circle_outlined;
    }
  }

  Widget _buildAppliedInfo() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Application Details',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          _InfoRow(
            icon: Icons.calendar_today_outlined,
            text: 'Applied on ${_formatDateTime(module.appliedAt)}',
          ),
          const SizedBox(height: 8),
          const _InfoRow(
            icon: Icons.description_outlined,
            text: 'Resume submitted',
          ),
          const SizedBox(height: 8),
          const _InfoRow(
            icon: Icons.description_outlined,
            text: 'Placement letter submitted',
          ),
        ],
      ),
    );
  }


  Widget _buildReviewInfo() {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Document Review Status',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                module.isResumeRead ? Icons.check_circle : Icons.pending,
                size: 16,
                color: module.isResumeRead ? Colors.green : Colors.grey,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  module.isResumeRead ? 'Resume reviewed' : 'Resume pending review',
                  style: TextStyle(
                    color: module.isResumeRead ? Colors.green[700] : Colors.grey[700],
                  ),
                ),
              ),
            ],
          ),
          if (module.isResumeRead && module.resumeReadAt != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 24),
              child: Text(
                'Reviewed on ${_formatDateTime(module.resumeReadAt!)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                module.isPlacementLetterRead ? Icons.check_circle : Icons.pending,
                size: 16,
                color: module.isPlacementLetterRead ? Colors.green : Colors.grey,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  module.isPlacementLetterRead ? 'Placement Letter reviewed' : 'Placement Letter pending review',
                  style: TextStyle(
                    color: module.isPlacementLetterRead ? Colors.green[700] : Colors.grey[700],
                  ),
                ),
              ),
            ],
          ),
          if (module.isPlacementLetterRead && module.placementLetterReadAt != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 24),
              child: Text(
                'Reviewed on ${_formatDateTime(module.placementLetterReadAt!)}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAcceptedInfo(DateTime updatedAt) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.green.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Offer Acceptance Details',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                size: 16,
                color: Colors.green[600],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Accepted on ${_formatDateTime(module.acceptedAt ?? DateTime.now())}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeclinedInfo(DateTime updatedAt) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.red.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Offer Decline Details',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.cancel_outlined,
                size: 16,
                color: Colors.red[600],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Declined on ${_formatDateTime(module.declinedAt ?? DateTime.now())
                  }',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWithdrawnInfo(DateTime updatedAt) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.grey.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Application Withdrawal Details',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.history,
                size: 16,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Withdrawn on ${_formatDateTime(module.withdrawnAt ?? DateTime.now())}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _getRelevantStages(BuildContext context, String userEmail)       {
    final List<Widget> stages = [];

    // Always show Applied stage first
    stages.add(_TimelineItem(
      title: 'Applied',
      subtitle: 'Application submitted\nUpdated by ${_formatDateTime(module.appliedAt)}',
      isCompleted: true,
      isRejected: false,
      date: '',
      isFirst: true,
      showLine: module.hasBeenReviewed || module.interviewDetails != null || module.isApproved || module.isRejected  || module.status == ApplicationStatus.withdrawn || module.status == ApplicationStatus.accepted,
      icon: _getStageIcon('applied', true, false),
      additionalInfo: _buildAppliedInfo(),
    ));

    // Handle direct rejection after application
    if (module.isRejected && !module.hasBeenReviewed && module.interviewDetails == null) {
      stages.add(_TimelineItem(
        title: 'Rejected',
        subtitle: 'Application rejected\nUpdated by ${_formatDateTime(module.rejectionDetails!.rejectedAt)}',
        isCompleted: false,
        isRejected: true,
        date: '',
        showLine: false,
        icon: _getStageIcon('rejected', false, true),
        additionalInfo: _buildRejectionInfo(module.rejectionDetails!),
      ));
      return stages;
    }

    // Show Document Review if documents are being reviewed or have been reviewed
    if (module.isResumeRead || module.isPlacementLetterRead) {
      stages.add(_TimelineItem(
        title: 'Document Review',
        subtitle: module.hasBeenReviewed ? 'All documents reviewed' : 'Documents being reviewed',
        isCompleted: module.hasBeenReviewed,
        isRejected: false,
        date: module.hasBeenReviewed ? 'Review completed' : 'Review in progress',
        showLine: module.interviewDetails != null || module.isApproved || module.isRejected || module.status == ApplicationStatus.approved || module.status == ApplicationStatus.accepted || module.status == ApplicationStatus.declined || module.status == ApplicationStatus.withdrawn,
        icon: _getStageIcon('document review', module.hasBeenReviewed, false),
        additionalInfo: _buildReviewInfo(),
      ));
    }

    // Show Shortlisted if interview details exist
    if (module.interviewDetails != null) {
      stages.add(_TimelineItem(
        title: 'Shortlisted',
        subtitle: '${module.interviewDetails!.type} Interview\nUpdated by ${_formatDateTime(module.interviewDetails!.scheduledAt)}',
        isCompleted: true,
        isRejected: false,
        date: '',
        showLine: module.isApproved || module.isRejected || module.status == ApplicationStatus.approved || module.status == ApplicationStatus.accepted || module.status == ApplicationStatus.declined || module.status == ApplicationStatus.withdrawn,
        icon: _getStageIcon('shortlisted', true, false),
        additionalInfo: _buildInterviewInfo(module.interviewDetails!, context),
      ));
    }

    // Handle rejection after document review or interview
    if (module.isRejected) {
      stages.add(_TimelineItem(
        title: 'Rejected',
        subtitle: 'Application rejected\nUpdated by ${_formatDateTime(module.rejectionDetails!.rejectedAt)}',
        isCompleted: false,
        isRejected: true,
        date: '',
        showLine: false,
        icon: _getStageIcon('rejected', false, true),
        additionalInfo: _buildRejectionInfo(module.rejectionDetails!),
      ));
      return stages;
    }

    // Handle rejection after interview
    if (module.isRejected && module.interviewDetails != null) {
      stages.add(_TimelineItem(
        title: 'Rejected',
        subtitle: 'Application rejected\nUpdated by ${_formatDateTime(module.rejectionDetails!.rejectedAt)}',
        isCompleted: false,
        isRejected: true,
        date: '',
        showLine: false,
        icon: _getStageIcon('rejected', false, true),
        additionalInfo: _buildRejectionInfo(module.rejectionDetails!),
      ));
      return stages;
    }

    // Show Approved stage
    if (module.isApproved || module.status == ApplicationStatus.accepted || module.status == ApplicationStatus.declined) {
      stages.add(_TimelineItem(
        title: 'Approved',
        subtitle: 'Offer received\nUpdated by ${_formatDateTime(module.offerDetails!.offeredAt)}',
        isCompleted: true,
        isRejected: false,
        date: '',
        showLine: module.status == ApplicationStatus.accepted || module.status == ApplicationStatus.declined,
        icon: _getStageIcon('approved', true, false),
        additionalInfo: _buildOfferInfo(module.offerDetails!, context),
      ));
    }

    // Show Accepted/Declined stage if applicable
    if (module.status == ApplicationStatus.accepted) {
      stages.add(_TimelineItem(
        title: 'Accepted',
        subtitle: 'Offer accepted\nUpdated by ${_formatDateTime(module.acceptedAt ?? DateTime.now())}',
        isCompleted: true,
        isRejected: false,
        date: '',
        showLine: false,
        icon: Icons.check_circle_outline,
        additionalInfo: _buildAcceptedInfo(module.acceptedAt ?? DateTime.now()),
      ));
    } else if (module.status == ApplicationStatus.declined) {
      stages.add(_TimelineItem(
        title: 'Declined',
        subtitle: 'Offer declined\nUpdated by ${_formatDateTime(module.declinedAt ?? DateTime.now())}',
        isCompleted: false,
        isRejected: true,
        date: '',
        showLine: false,
        icon: Icons.cancel_outlined,
        additionalInfo: _buildDeclinedInfo(module.declinedAt ?? DateTime.now()),
      ));
    }

    if (module.status == ApplicationStatus.withdrawn) {
      stages.add(_TimelineItem(
        title: 'Withdrawn',
        subtitle: 'Application withdrawn\nUpdated by ${_formatDateTime(module.withdrawnAt ?? DateTime.now())}',
        isCompleted: false,
        isRejected: false,  // Use false since it's a neutral state
        date: '',
        showLine: false,
        icon: _getStageIcon('withdrawn', false, false),
        additionalInfo: _buildWithdrawnInfo(module.withdrawnAt ?? DateTime.now()),
      ));
    }
    return stages;
  }

  void handleOfferAcceptance(String userEmail, Module selectedApplication, BuildContext context) async {
    final firestore = FirebaseFirestore.instance;
    final DateTime now = DateTime.now();
    final notificationService = NotificationService();

    try {
      // Step 1: Get studentId from email collection
      final emailSnapshot = await firestore
          .collection('email')
          .where('email', isEqualTo: userEmail)
          .get();

      if (emailSnapshot.docs.isEmpty) {
        throw Exception('User email not found');
      }
      final studentId = emailSnapshot.docs.first['studentId'];

      // Step 2: Get currentProgram from allStudents collection
      final studentDoc = await firestore.collection('allStudents').doc(studentId).get();
      if (!studentDoc.exists) {
        throw Exception('Student document not found');
      }
      final currentProgram = studentDoc.data()?['currentProgram'];
      final studentName = studentDoc.data()?['name'] ?? 'Student';

      // Step 3: Get all student's applications
      final studentApplicationsDoc = await firestore
          .collection('students')
          .doc(currentProgram)
          .collection('students')
          .doc(studentId)
          .get();

      if (!studentApplicationsDoc.exists) {
        throw Exception('Student applications not found');
      }

      Map<String, dynamic> studentApplications = {};
      if (studentApplicationsDoc.data()!.containsKey('applications')) {
        studentApplications = Map<String, dynamic>.from(studentApplicationsDoc.data()?['applications'] ?? {});
      }

      // Step 4: Start batch write
      final batch = firestore.batch();

      // Update student document
      final studentProgramRef = firestore
          .collection('students')
          .doc(currentProgram)
          .collection('students')
          .doc(studentId);

      batch.update(studentProgramRef, {
        'internshipStatus': 'Hired',
        'internshipCompany': selectedApplication.company
      });

      // Update job document and notify employer of acceptance
      final jobRef = firestore.collection('jobs').doc(selectedApplication.jobId);
      final jobDoc = await jobRef.get();

      if (!jobDoc.exists) {
        throw Exception('Job document not found');
      }

      final currentHiredPax = jobDoc.data()?['hiredPax'] ?? 0;
      final newHiredPax = currentHiredPax - 1;
      final jobTitle = jobDoc.data()?['title'] ?? 'position';
      final employerId = jobDoc.data()?['postedBy'];

      // Update job attributes
      if (newHiredPax <= 0) {
        batch.update(jobRef, {
          'hiredPax': 0,
          'status': 'hide'
        });
      } else {
        batch.update(jobRef, {
          'hiredPax': newHiredPax
        });
      }

      // Update employer's hired number and send acceptance notification
      if (employerId != null) {
        final employerRef = firestore.collection('employers').doc(employerId);
        final employerDoc = await employerRef.get();

        if (employerDoc.exists) {
          final currentHiredNumber = employerDoc.data()?['hiredNumber'] ?? 0;
          final employerToken = employerDoc.data()?['fcmToken'];

          batch.update(employerRef, {
            'hiredNumber': currentHiredNumber + 1
          });

          // Send acceptance notification
          if (employerToken != null) {
            await notificationService.sendOfferNotification(
                employerToken: employerToken,
                studentName: studentName,
                jobTitle: jobTitle,
                companyName: selectedApplication.company,
                employerId: employerId,
                type: 'accepted'
            );
          }
        }
      }

      // Process each application
      for (var entry in studentApplications.entries) {
        final applicationData = entry.value as Map<String, dynamic>;
        final applicationId = entry.key;
        final jobId = applicationData['jobId'];

        final mainAppRef = firestore
            .collection('applications')
            .doc(jobId)
            .collection('applicants')
            .doc(applicationId);

        final appSnapshot = await mainAppRef.get();
        if (!appSnapshot.exists) continue;

        final currentStatus = appSnapshot.data()?['status']?.toString().toLowerCase();

        // Skip if already declined
        if (currentStatus == 'declined') continue;

        if (applicationId == selectedApplication.applicationId) {
          // Update accepted application
          batch.update(mainAppRef, {
            'status': 'Accepted',
            'updatedAt': now,
            'acceptedAt': now,
          });
        } else {
          // Handle other applications
          final otherJobDoc = await firestore.collection('jobs').doc(jobId).get();
          if (!otherJobDoc.exists) continue;

          final otherEmployerId = otherJobDoc.data()?['postedBy'];
          if (otherEmployerId == null) continue;

          final otherEmployerDoc = await firestore.collection('employers').doc(otherEmployerId).get();
          if (!otherEmployerDoc.exists) continue;

          final otherEmployerToken = otherEmployerDoc.data()?['fcmToken'];
          final otherJobTitle = otherJobDoc.data()?['title'] ?? 'position';

          switch (currentStatus) {
            case 'approved':
            // Auto-decline other approved offers
              batch.update(mainAppRef, {
                'status': 'Declined',
                'updatedAt': now,
                'declinedAt': now,
              });

              // Notify employer of declined offer
              if (otherEmployerToken != null) {
                await notificationService.sendOfferNotification(
                    employerToken: otherEmployerToken,
                    studentName: studentName,
                    jobTitle: otherJobTitle,
                    companyName: otherEmployerDoc.data()?['company_name'] ?? '',
                    employerId: otherEmployerId,
                    type: 'declined'
                );
              }
              break;

            case 'pending':
            case 'shortlisted':
            // Auto-withdraw other applications
              batch.update(mainAppRef, {
                'status': 'Withdrawn',
                'updatedAt': now,
                'withdrawnAt': now,
              });

              // Notify employer of withdrawal
              if (otherEmployerToken != null) {
                await notificationService.sendOfferNotification(
                    employerToken: otherEmployerToken,
                    studentName: studentName,
                    jobTitle: otherJobTitle,
                    companyName: otherEmployerDoc.data()?['company_name'] ?? '',
                    employerId: otherEmployerId,
                    type: 'withdrawn'
                );
              }
              break;
          }
        }
      }

      await batch.commit();

      Fluttertoast.showToast(
        msg: "Offer accepted successfully. Other applications have been updated.",
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );

      // Navigate back after successful acceptance
      if (context.mounted) {
        Navigator.pop(context); // Return to previous page
      }

    } catch (e) {
      print('Error handling offer acceptance: $e');
      print('Stack trace: ${StackTrace.current}');
      Fluttertoast.showToast(
        msg: "Error accepting offer: $e",
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  void handleOfferDecline(String userEmail, Module declinedApplication, BuildContext context) async {
    final firestore = FirebaseFirestore.instance;
    final DateTime now = DateTime.now();
    final notificationService = NotificationService();

    try {
      // Get student details from email collection
      final emailSnapshot = await firestore
          .collection('email')
          .where('email', isEqualTo: userEmail)
          .get();

      if (emailSnapshot.docs.isEmpty) {
        throw Exception('User email not found');
      }
      final studentId = emailSnapshot.docs.first['studentId'];

      // Get student name
      final studentDoc = await firestore.collection('allStudents').doc(studentId).get();
      if (!studentDoc.exists) {
        throw Exception('Student document not found');
      }
      final studentName = studentDoc.data()?['name'] ?? 'Student';

      // Get job details
      final jobDoc = await firestore.collection('jobs').doc(declinedApplication.jobId).get();
      if (!jobDoc.exists) {
        throw Exception('Job document not found');
      }

      final employerId = jobDoc.data()?['postedBy'];
      final jobTitle = jobDoc.data()?['title'] ?? 'position';

      if (employerId == null) {
        throw Exception('Invalid employer ID');
      }

      // Get employer details
      final employerDoc = await firestore.collection('employers').doc(employerId).get();
      if (!employerDoc.exists) {
        throw Exception('Employer document not found');
      }

      final employerToken = employerDoc.data()?['fcmToken'];

      // Update application status
      await firestore
          .collection('applications')
          .doc(declinedApplication.jobId)
          .collection('applicants')
          .doc(declinedApplication.applicationId)
          .update({
        'status': 'Declined',
        'updatedAt': now,
        'declinedAt': now,
      });

      // Send decline notification to employer
      if (employerToken != null && employerToken.isNotEmpty) {
        await notificationService.sendOfferNotification(
            employerToken: employerToken,
            studentName: studentName,
            jobTitle: jobTitle,
            companyName: declinedApplication.company,
            employerId: employerId,
            type: 'declined'
        );
      }

      Fluttertoast.showToast(
        msg: "Offer declined successfully",
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );

      // Navigate back after successful decline
      if (context.mounted) {
        Navigator.pop(context);
      }

    } catch (e) {
      print('Error handling offer decline: $e');
      print('Stack trace: ${StackTrace.current}');
      Fluttertoast.showToast(
        msg: "Error declining offer: $e",
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }


  Widget _buildInterviewInfo(InterviewDetails details, BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Interview Details',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Interview Date & Time:',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.event, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text(
                '${details.date} • ${details.time}',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            details.type.toLowerCase() == 'online' ? 'Meeting Link:' : 'Location:',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: details.location));
              Fluttertoast.showToast(
                msg: "Copied to clipboard",
                toastLength: Toast.LENGTH_SHORT,
                gravity: ToastGravity.BOTTOM,
                backgroundColor: Colors.white,
                textColor: Colors.black,
                fontSize: 16.0,
              );
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    details.type.toLowerCase() == 'online'
                        ? Icons.link
                        : Icons.location_on,
                    size: 20,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      details.location,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  Icon(
                    Icons.copy,
                    size: 16,
                    color: Colors.grey[400],
                  ),
                ],
              ),
            ),
          ),
          if (details.notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Notes:',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              details.notes,
              textAlign: TextAlign.justify,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _viewOfferLetter(String offerLetterUrl, String fileName) async {
    try {
      // Ensure offerLetterUrl is valid
      if (offerLetterUrl.isEmpty) {
        Fluttertoast.showToast(
          msg: "Offer letter URL is empty",
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
        return;
      }

      // Request storage permissions
      await _requestPermissions();

      print('Downloading offer letter from URL: $offerLetterUrl');
      Dio dio = Dio();

      // Get the app's temporary directory
      Directory tempDir = await getTemporaryDirectory();
      String tempPath = tempDir.path;
      String localPath = '$tempPath/$fileName';

      print('Saving offer letter to: $localPath');

      // Download the file with progress tracking
      await dio.download(offerLetterUrl, localPath, onReceiveProgress: (received, total) {
        if (total != -1) {
          print('Download progress: ${(received / total * 100).toStringAsFixed(0)}%');
        }
      });

      print('Download completed.');

      // Check if the file exists and open it
      final file = File(localPath);
      if (await file.exists()) {
        final result = await OpenFile.open(localPath);
        if (result.type != ResultType.done) {
          Fluttertoast.showToast(
            msg: "Failed to open the offer letter: ${result.message}",
            backgroundColor: Colors.white,
            textColor: Colors.black,
          );
          print('Failed to open offer letter: ${result.message}');
        } else {
          Fluttertoast.showToast(
            msg: "Offer letter opened successfully",
            backgroundColor: Colors.white,
            textColor: Colors.black,
          );
        }
      } else {
        Fluttertoast.showToast(
          msg: "File not found after download",
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
        print("File not found: $localPath");
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Error viewing offer letter: $e",
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      print('Error viewing offer letter: $e');
    }
  }


  Future<void> _requestPermissions() async {
    // Check and request storage permissions
    if (!await Permission.storage.isGranted) {
      await Permission.storage.request();
    }

    // Ensure manage storage permissions for Android 10+
    if (Platform.isAndroid && await Permission.manageExternalStorage.isPermanentlyDenied) {
      openAppSettings();
    }
  }

  Widget _buildOfferInfo(OfferDetails details, BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('students')
          .doc(module.studentId)
          .get(),
      builder: (context, snapshot) {
        bool isHired = snapshot.hasData &&
            snapshot.data?.data() != null &&
            (snapshot.data?.data() as Map<String, dynamic>)['internshipStatus'] == 'Hired';
        bool showButtons = !isHired && module.status == ApplicationStatus.approved;

        return Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Offer Details',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Start Date:',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.calendar_today_outlined, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    _formatDate(details.offerDate),
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              if (details.offerLetterPath.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Offer Letter:',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () => _viewOfferLetter(details.offerLetterPath, "offer_letter.pdf"),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.download, size: 20, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Download Offer Letter',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.blue,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                        Icon(Icons.arrow_downward, size: 16, color: Colors.grey[400]),
                      ],
                    ),
                  ),
                )
              ],
              if (details.notes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Notes:',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  details.notes,
                  textAlign: TextAlign.justify,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
              ],
              if (showButtons) ...[
                const SizedBox(height: 10),
                const Divider(),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          String userEmail = getCurrentUserEmail();
                          handleOfferAcceptance(userEmail, module, context);
                        },
                        icon: const Icon(
                          Icons.check_circle_outline,
                          size: 20,
                          color: Colors.white,
                        ),
                        label: const Text(
                          'Accept Offer',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          String userEmail = getCurrentUserEmail();
                          handleOfferDecline(userEmail, module, context);
                        },
                        icon: Icon(
                          Icons.cancel_outlined,
                          size: 20,
                          color: Colors.white,
                        ),
                        label: Text(
                          'Decline Offer',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else if (isHired) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'You have already accepted an offer',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // Add this method to the ApplicationTimeline class
  Widget _buildRejectionInfo(RejectionDetails details) {
    return Container(
      width: double.infinity,  // Added to ensure full width
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.red.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Application Rejected',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Rejection Reason:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                details.reason,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
              if (details.feedback.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Feedback:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  details.feedback,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
              ],
              if (details.improvementSuggestions.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Improvement Suggestions:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  details.improvementSuggestions,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }





  @override
  Widget build(BuildContext context) {
    String userEmail = getCurrentUserEmail();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        ListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: _getRelevantStages(context, userEmail),
        ),
      ],
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isCompleted;
  final bool isRejected;
  final String date;
  final bool showLine;
  final bool isFirst;
  final IconData icon;
  final Widget? additionalInfo;

  const _TimelineItem({
    required this.title,
    required this.subtitle,
    required this.isCompleted,
    required this.isRejected,
    required this.date,
    required this.showLine,
    required this.icon,
    this.isFirst = false,
    this.additionalInfo,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        children: [
          // Timeline indicator column
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isRejected
                        ? Colors.red.withOpacity(0.1)
                        : isCompleted
                        ? Colors.green.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isRejected
                          ? Colors.red
                          : isCompleted
                          ? Colors.green
                          : Colors.grey,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: isRejected
                        ? Colors.red
                        : isCompleted
                        ? Colors.green
                        : Colors.grey,
                    size: 16,
                  ),
                ),
                if (showLine)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: isCompleted ? Colors.green : Colors.grey.withOpacity(0.3),
                    ),
                  ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(left: 12, bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // In the _TimelineItem class, update the content Container:
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isRejected
                          ? Colors.red.withOpacity(0.1)
                          : isCompleted
                          ? Colors.green.withOpacity(0.1)
                          : Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isRejected
                            ? Colors.red.withOpacity(0.3)
                            : isCompleted
                            ? Colors.green.withOpacity(0.3)
                            : Colors.grey.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isRejected
                                ? Colors.red
                                : isCompleted
                                ? Colors.green[700]
                                : Colors.grey[800],
                          ),
                        ),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: subtitle.split('\n').map((text) {
                              if (text.contains('Interview')) {
                                return Row(
                                  children: [
                                    Icon(
                                      Icons.video_camera_front_outlined,
                                      size: 14,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      text,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                );
                              } else if (text.contains('Updated by')) {
                                return Row(
                                  children: [
                                    Icon(
                                      Icons.update,
                                      size: 14,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      text,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                );
                              }
                              return Text(
                                text,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                        if (date.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 14,
                                color: Colors.grey[500],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                date,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (additionalInfo != null) additionalInfo!,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RejectionDetails extends StatelessWidget {
  final RejectionDetails details;

  const _RejectionDetails({required this.details});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 52, bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Application Rejected',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Rejection Reason:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                details.reason,
                textAlign: TextAlign.justify,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
              if (details.feedback.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Feedback:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  details.feedback,
                  textAlign: TextAlign.justify,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
              ],
              if (details.improvementSuggestions.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Improvement Suggestions:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  details.improvementSuggestions,
                  textAlign: TextAlign.justify,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
        ),
      ],
    );
  }
}