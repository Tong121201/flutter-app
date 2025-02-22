import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';

import 'application_timeline.dart';
import 'models/module.dart';

class ApplicationPage extends StatefulWidget {
  const ApplicationPage({Key? key}) : super(key: key);

  @override
  State<ApplicationPage> createState() => _ApplicationPageState();
}

class _ApplicationPageState extends State<ApplicationPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  List<Map<String, dynamic>> applications = [];
  bool isLoading = true;


  @override
  void initState() {
    super.initState();
    fetchApplications();
  }

  Future<String> _getImageUrl(String path) async {
    if (path.isEmpty) return '';

    try {
      // If the path is already a URL, return it directly
      if (path.startsWith('http')) {
        return path;
      }
      // Otherwise, get the download URL from Firebase Storage
      return await _storage.ref(path).getDownloadURL();
    } catch (e) {
      print('Error getting image URL: $e');
      return '';
    }
  }

  String formatDateTime(String? dateString) {
    if (dateString == null) return 'Not available';
    try {
      final DateTime date = DateTime.parse(dateString);
      // Remove the manual UTC+8 conversion since the DateTime.parse()
      // will automatically handle the timezone
      return DateFormat('MMM d, y · h:mm a').format(date.toLocal());
    } catch (e) {
      return 'Not available';
    }
  }

  Future<void> fetchApplications() async {
    try {
      setState(() => isLoading = true);

      User? currentUser = _auth.currentUser;
      if (currentUser?.email == null) {
        throw Exception('No authenticated user found');
      }

      final emailSnapshot = await _firestore
          .collection('email')
          .where('email', isEqualTo: currentUser!.email)
          .get();

      if (emailSnapshot.docs.isEmpty) {
        setState(() {
          applications = []; // Set empty applications list
          isLoading = false;
        });
        return; // Return early if no student found
      }

      final studentId = emailSnapshot.docs.first['studentId'];

      final studentDoc = await _firestore
          .collection('allStudents')
          .doc(studentId)
          .get();

      if (!studentDoc.exists) {
        setState(() {
          applications = []; // Set empty applications list
          isLoading = false;
        });
        return; // Return early if student document not found
      }

      final currentProgram = studentDoc.get('currentProgram');

      final programDoc = await _firestore
          .collection('students')
          .doc(currentProgram)
          .collection('students')
          .doc(studentId)
          .get();

      if (!programDoc.exists || !programDoc.data()!.containsKey('applications')) {
        setState(() {
          applications = []; // Set empty applications list
          isLoading = false;
        });
        return; // Return early if no applications field exists
      }

      Map<String, dynamic> applicationsMap =
      Map<String, dynamic>.from(programDoc.get('applications') ?? {});

      List<Map<String, dynamic>> apps = [];
      for (var entry in applicationsMap.entries) {
        String applicationId = entry.key;
        String jobId = entry.value['jobId'];

        try {
          DocumentSnapshot applicationDoc = await _firestore
              .collection('applications')
              .doc(jobId)
              .collection('applicants')
              .doc(applicationId)
              .get();

          DocumentSnapshot jobDoc = await _firestore
              .collection('jobs')
              .doc(jobId)
              .get();

          if (applicationDoc.exists && jobDoc.exists) {
            Map<String, dynamic> applicationData =
            applicationDoc.data() as Map<String, dynamic>;
            Map<String, dynamic> jobData = jobDoc.data() as Map<String, dynamic>;

            String employerId = jobData['postedBy'] ?? '';
            if (employerId.isNotEmpty) {
              DocumentSnapshot employerDoc = await _firestore
                  .collection('employers')
                  .doc(employerId)
                  .get();

              if (employerDoc.exists) {
                Map<String, dynamic> employerData =
                employerDoc.data() as Map<String, dynamic>;
                String profilePicturePath = employerData['profilePicture'] ?? '';
                applicationData['companyLogo'] = await _getImageUrl(profilePicturePath);
                applicationData['company'] = employerData['company_name'] ?? 'Unknown Company';
              }
            }

            applicationData['title'] = jobData['title'] ?? 'Job Title Not Found';

            if (applicationData['appliedAt'] is Timestamp) {
              applicationData['appliedAt'] =
                  (applicationData['appliedAt'] as Timestamp)
                      .toDate()
                      .toIso8601String();
            }
            if (applicationData['updatedAt'] is Timestamp) {
              applicationData['updatedAt'] =
                  (applicationData['updatedAt'] as Timestamp)
                      .toDate()
                      .toIso8601String();
            }

            apps.add(applicationData);
          }
        } catch (e) {
          print('Error fetching application $applicationId: $e');
        }
      }

      // Sort applications based on status priority
      apps.sort((a, b) {
        // Helper function to get priority value
        int getPriorityValue(String? status) {
          switch (status?.toLowerCase()) {
            case 'accepted':
              return 0; // Highest priority
            case 'approved':
              return 1; // Second highest priority
            case 'shortlisted':
              return 2;
            case 'pending':
              return 3;
            case 'rejected':
              return 4;
            case 'declined':
              return 5;
            case 'withdrawn':
              return 6;
            default:
              return 7; // Lowest priority for unknown status
          }
        }

        // Get status values
        int priorityA = getPriorityValue(a['status']);
        int priorityB = getPriorityValue(b['status']);

        // Sort by priority (lower number = higher priority)
        return priorityA.compareTo(priorityB);
      });

      setState(() {
        applications = apps;
        isLoading = false;
      });
    } catch (e) {
      print('Error in fetchApplications: $e');
      setState(() {
        applications = []; // Set empty applications list on error
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading applications: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return const Color(0xFF4CAF50); // Green (Success)
      case 'pending':
        return const Color(0xFFFFC107); // Amber (Waiting for action)
      case 'shortlisted':
        return const Color(0xFF03A9F4); // Light Blue (Positive but tentative)
      case 'accepted':
        return const Color(0xFF8BC34A); // Light Green (Final success)
      case 'rejected':
        return const Color(0xFFF44336); // Red (Negative outcome)
      case 'declined':
        return const Color(0xFFE91E63); // Pink (Distinct from rejected but still negative)
      case 'withdrawn':
        return const Color(0xFF9E9E9E); // Grey (Neutral or inactive)
      default:
        return const Color(0xFFBDBDBD); // Light Grey (Unknown or undefined status)
    }
  }

  Color _getStatusBackgroundColor(String status) {
    return _getStatusColor(status).withOpacity(0.1);
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Icons.check_circle_outline;
      case 'pending':
        return Icons.hourglass_empty;
      case 'shortlisted':
        return Icons.star_outline;
      case 'rejected':
        return Icons.cancel_outlined;
      default:
        return Icons.info_outline;
    }
  }

  Widget _buildStatusBadge(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getStatusColor(status).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _getStatusColor(status),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getStatusIcon(status),
            size: 16,
            color: _getStatusColor(status),
          ),
          const SizedBox(width: 6),
          Text(
            status,
            style: TextStyle(
              color: _getStatusColor(status),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyLogo(String? logoUrl) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.grey.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: logoUrl != null && logoUrl.isNotEmpty
            ? Image.network(
          logoUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Icon(
            Icons.business,
            size: 24,
            color: Colors.grey[400],
          ),
        )
            : Icon(
          Icons.business,
          size: 24,
          color: Colors.grey[400],
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
            Icons.inbox_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No applications yet',
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

  Widget _buildApplicationHeader(Map<String, dynamic> application) {
    final status = application['status'] ?? 'Unknown';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _getStatusBackgroundColor(status),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildStatusBadge(status),
          Text(
            'ID: ${application['applicationId']}',
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: Colors.grey[400],
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[800],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  void _showApplicationDetail(Map<String, dynamic> application) {
    // Convert the application map to a Module object
    final module = Module.fromFirestore(application);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.5,
        maxChildSize: 1.0,
        builder: (context, scrollController) => ClipRRect(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(20),
          ),
          child: Material(
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Header Section with Job Details
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Company Logo and Title
                      Row(
                        children: [
                          _buildCompanyLogo(application['companyLogo']),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  application['title'] ?? 'Job Title',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  application['company'] ?? 'Company Name',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Divider with Job ID and Status
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 16),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(color: Colors.grey[200]!),
                            bottom: BorderSide(color: Colors.grey[200]!),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Job ID: ${application['applicationId']}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                            _buildStatusBadge(application['status'] ?? 'pending'),
                          ],
                        ),
                      ),

                      // Application Progress Title
                      const Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: Text(
                          'Application Progress',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Timeline Section
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ApplicationTimeline(module: module),
                  ),
                ),
              ],
            ),
          ),
        ),
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
        surfaceTintColor: Colors.white, // Add this to prevent any tint color
        scrolledUnderElevation: 0, //
        title: const Text(
          'My Applications',
          style: TextStyle(
            color: Colors.black,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : applications.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
        onRefresh: fetchApplications,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: applications.length,
          itemBuilder: (context, index) {
            final application = applications[index];
            return GestureDetector(
              onTap: () => _showApplicationDetail(application),
              child: Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.grey.withOpacity(0.2),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildApplicationHeader(application),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _buildCompanyLogo(application['companyLogo']),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      application['company'] ?? 'Company Name',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      application['title'] ?? 'Job Title',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildInfoRow(
                            'Applied Date',
                            formatDateTime(application['appliedAt']),
                            Icons.calendar_today_outlined,
                          ),
                          const SizedBox(height: 8),
                          _buildInfoRow(
                            'Last Update',
                            formatDateTime(application['updatedAt']?.toString() ?? application['appliedAt']),  // If updatedAt is null, use appliedAt
                            Icons.update_outlined,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}