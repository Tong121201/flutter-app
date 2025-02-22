import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:qiu_internar/service/get_service_key.dart';
import 'package:qiu_internar/service/notification_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/job.dart';
import 'package:url_launcher/url_launcher_string.dart';


class JobDetail extends StatefulWidget{
  final Job job;
  final bool showTime;
  final String? currentUserId;
  final VoidCallback? onBookmarkToggle;
  final ScrollController? scrollController;

  JobDetail(
      this.job, {
        this.showTime = false,
        this.currentUserId,
        this.onBookmarkToggle,
        this.scrollController,
      });

  @override
  _JobDetailState createState() => _JobDetailState();
}

class _JobDetailState extends State<JobDetail> {
  bool _isLoading = false;
  int _selectedTab = 0;
  Map<String, dynamic>? _employerData;
  bool _isLoadingEmployer = true;

  @override
  void initState() {
    super.initState();
    _fetchEmployerData();
  }

  Future<void> _fetchEmployerData() async {
    try {
      final employerDoc = await FirebaseFirestore.instance
          .collection('employers')
          .doc(widget.job.postedBy)
          .get();

      if (employerDoc.exists) {
        setState(() {
          _employerData = employerDoc.data();
          _isLoadingEmployer = false;
        });
      }
    } catch (e) {
      print("Error fetching employer data: $e");
      setState(() => _isLoadingEmployer = false);
    }
  }

  Future<void> _toggleStarred() async {
    if (_isLoading) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user?.email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to bookmark jobs'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Get student ID from email collection
      final emailSnapshot = await FirebaseFirestore.instance
          .collection('email')
          .where('email', isEqualTo: user?.email)
          .get();

      if (emailSnapshot.docs.isEmpty) {
        throw Exception('Student not found');
      }

      final studentId = emailSnapshot.docs.first['studentId'];
      final studentRef = FirebaseFirestore.instance.collection('allStudents')
          .doc(studentId);

      // Get current student document
      final studentDoc = await studentRef.get();

      // Update local state first for immediate UI feedback
      bool newStarredState = !widget.job.isStarred;

      if (!studentDoc.exists) {
        // If student document doesn't exist, create it with starredJobs array
        if (newStarredState) { // Only create if starring
          await studentRef.set({
            'starredJobs': [widget.job.id]
          });
        }
      } else {
        final studentData = studentDoc.data();
        if (studentData != null) {
          List<dynamic> starredJobs = studentData['starredJobs'] ?? [];

          if (!newStarredState) {
            // Remove job from starred list
            starredJobs.remove(widget.job.id);
          } else {
            // Add job to starred list
            starredJobs.add(widget.job.id);
          }

          await studentRef.update({
            'starredJobs': starredJobs
          });

          print("Updated starredJobs: $starredJobs");
        }
      }

      // Verify the update was successful
      final verifyDoc = await studentRef.get();
      final verifyData = verifyDoc.data();
      final List<dynamic> starredJobs = verifyData?['starredJobs'] ?? [];

      if ((newStarredState && starredJobs.contains(widget.job.id)) ||
          (!newStarredState && !starredJobs.contains(widget.job.id))) {
        setState(() {
          widget.job.isStarred = newStarredState;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newStarredState
                ? 'Job added to bookmarks'
                : 'Job removed from bookmarks'),
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        throw Exception('Failed to update bookmark status in Firestore');
      }
    } catch (e) {
      print("Error toggling starred status: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update bookmark. Please try again.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> applyForJob(String jobId, BuildContext context) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    NotificationService notificationService = NotificationService();

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to apply for jobs.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return WillPopScope(
            onWillPop: () async => false,
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        },
      );

      // First get studentId from email collection
      final emailSnapshot = await FirebaseFirestore.instance
          .collection('email')
          .where('email', isEqualTo: currentUser.email)
          .get();

      if (emailSnapshot.docs.isEmpty) {
        throw Exception('Student ID not found for the logged-in user.');
      }

      final studentId = emailSnapshot.docs.first['studentId'];

      // Then get the student's current program from allStudents collection
      final allStudentsSnapshot = await FirebaseFirestore.instance
          .collection('allStudents')
          .doc(studentId)
          .get();

      if (!allStudentsSnapshot.exists) {
        throw Exception('Student profile not found.');
      }

      final currentProgram = allStudentsSnapshot.data()!['currentProgram'];

      if (currentProgram == null) {
        throw Exception('Student program not found.');
      }

      // Get the detailed student information from the program-specific collection
      final studentSnapshot = await FirebaseFirestore.instance
          .collection('students')
          .doc(currentProgram)
          .collection('students')
          .doc(studentId)
          .get();

      if (!studentSnapshot.exists) {
        throw Exception('Student details not found.');
      }

      final studentData = studentSnapshot.data()!;

      // NEW: Check internship status
      final internshipStatus = studentData['internshipStatus'];
      if (internshipStatus == null) {
        throw Exception('Internship status not found. Please contact administrator.');
      }

      if (internshipStatus == 'Hired') {
        throw Exception('You have already been hired for an internship and cannot apply for additional positions.');
      }

      if (internshipStatus != 'Pending') {
        throw Exception('You are not eligible to apply for internships at this time. Current status: $internshipStatus');
      }

      // Check for required documents with specific error messages
      List<String> missingDocuments = [];
      if (studentData['resume'] == null) missingDocuments.add('resume');
      if (studentData['placementLetter'] == null) missingDocuments.add('placement letter');

      if (missingDocuments.isNotEmpty) {
        throw Exception(
            'Please upload your ${missingDocuments.join(' and ')} before applying.'
        );
      }

      // Check if student has already applied for this job
      final existingApplications = await FirebaseFirestore.instance
          .collection('applications')
          .doc(jobId)
          .collection('applicants')
          .where('studentId', isEqualTo: studentId)
          .get();

      if (existingApplications.docs.isNotEmpty) {
        navigator.pop();
        navigator.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You have already applied for this job.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
        return;
      }

      // Get job details and employer ID
      final jobDoc = await FirebaseFirestore.instance
          .collection('jobs')
          .doc(jobId)
          .get();

      if (!jobDoc.exists) {
        throw Exception('Job not found.');
      }

      final employerId = jobDoc.data()?['postedBy'];

      // Get company name from employers collection
      final employerDoc = await FirebaseFirestore.instance
          .collection('employers')
          .doc(employerId)
          .get();

      if (!employerDoc.exists) {
        throw Exception('Employer not found.');
      }

      final companyName = employerDoc.data()?['company_name'] ?? 'Unknown Company';
      final employerFcmToken = employerDoc.data()?['fcmToken'];
      final token = await notificationService.getDeviceToken() ?? '';

      // Generate a new application ID
      final applicationId = FirebaseFirestore.instance
          .collection('applications')
          .doc(jobId)
          .collection('applicants')
          .doc()
          .id;

      // Create application data
      final applicationData = {
        'applicationId': applicationId,
        'jobId': jobId,
        'studentId': studentId,
        'employerId': employerId,
        'status': 'Pending',
        'appliedAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
        'studentName': studentData['studentName'] ?? '',
        'studentEmail': currentUser.email,
        'studentPhone': studentData['contact'] ?? '',
        'resumeUrl': studentData['resume'],
        'placementLetterUrl': studentData['placementLetter'],
        'company': companyName,
        'userDeviceToken' : token,
      };

      // Use a transaction to ensure all operations succeed or fail together
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final studentRef = FirebaseFirestore.instance
            .collection('students')
            .doc(currentProgram)
            .collection('students')
            .doc(studentId);

        final applicationRef = FirebaseFirestore.instance
            .collection('applications')
            .doc(jobId)
            .collection('applicants')
            .doc(applicationId);

        final studentDoc = await transaction.get(studentRef);
        Map<String, dynamic> currentApplications = {};

        if (studentDoc.exists && studentDoc.data()?['applications'] != null) {
          final existingData = studentDoc.data()?['applications'];
          if (existingData is Map) {
            currentApplications = Map<String, dynamic>.from(existingData);
          }
        }

        // Update the structure to store applicationId > applicationId, jobId
        currentApplications[applicationId] = {
          'applicationId': applicationId,
          'jobId': jobId,
        };

        transaction.set(applicationRef, applicationData);
        transaction.update(jobDoc.reference, {
          'applicationIds': FieldValue.arrayUnion([applicationId])
        });
        transaction.update(studentRef, {
          'applications': currentApplications,
        });

      });

      // Send notification to employer
      final notificationSent = await notificationService.sendEmployerNotification(
        employerToken: employerDoc.data()?['fcmToken'],
        studentName: studentData['studentName'] ?? 'A student',
        jobTitle: jobDoc.data()?['title'] ?? 'the position',
        companyName: companyName,
        employerId: jobDoc.data()?['postedBy'] ?? '',
      );

      if (kDebugMode) {
        print('Notification sent status: $notificationSent');
      }

      // Close loading dialog
      navigator.pop();

      // Close bottom sheet
      navigator.pop();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your job application has been submitted successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );

    } catch (e) {
      // Close loading dialog if it's showing
      if (navigator.canPop()) {
        navigator.pop();
      }

      // Close bottom sheet
      navigator.pop();

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().contains('Exception:')
                ? e.toString().split('Exception: ')[1]
                : 'Error applying for job. Please try again.',
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      print('Error during job application: $e');
    }
  }


  @override
  Widget build(BuildContext context) {
    return Material(
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Fixed header section
            Padding(
              padding: const EdgeInsets.fromLTRB(25, 0, 25, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Company header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              height: 40,
                              width: 40,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                color: Colors.grey.withOpacity(0.1),
                              ),
                              clipBehavior: Clip.hardEdge,
                              child: widget.job.logoUrl.isNotEmpty
                                  ? Image.network(
                                widget.job.logoUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(Icons.image_not_supported);
                                },
                              )
                                  : const Icon(Icons.image),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                widget.job.company,
                                style: const TextStyle(fontSize: 16),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: _isLoading
                                ? SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Theme
                                      .of(context)
                                      .primaryColor,
                                ),
                              ),
                            )
                                : Icon(
                              widget.job.isStarred
                                  ? Icons.bookmark
                                  : Icons.bookmark_outline_outlined,
                              color: widget.job.isStarred
                                  ? Theme
                                  .of(context)
                                  .primaryColor
                                  : Colors.black,
                            ),
                            onPressed: _toggleStarred,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          widget.job.title,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        widget.job.daysAgo,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Job details grid
                  _buildJobDetailsGrid(),
                  const SizedBox(height: 20),

                  // Line above the tabs
                  const Divider(height: 1, color: Colors.grey),
                  const SizedBox(height: 15),

                  // Tabs
                  _buildTabs(),
                  const SizedBox(height: 15),
                ],
              ),
            ),

            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                controller: widget.scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(25, 20, 25, 25),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _selectedTab == 0
                        ? _buildJobDescription()
                        : _buildOfficeDetails(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJobDetailsGrid() {
    return Column(
      children: [
        Row(
          children: [
            _buildDetailTile(
              Icons.money,
              'RM ${widget.job.allowance}',
            ),
            const SizedBox(width: 12),
            _buildDetailTile(
              Icons.people_alt,
              widget.job.hiredPax.toString(),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _buildDetailTile(
              Icons.access_time_outlined,
              widget.job.time,
            ),
            const SizedBox(width: 12),
            _buildDetailTile(
              Icons.school,
              widget.job.preferredQualification,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailTile(IconData icon, String text) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[800],
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Row(
      children: [
        _buildTabButton(
          'The Job',
          0,
          BorderRadius.only(
            topLeft: Radius.circular(10),
            bottomLeft: Radius.circular(10),
          ),
        ),
        _buildTabButton(
          'Office',
          1,
          BorderRadius.only(
            topRight: Radius.circular(10),
            bottomRight: Radius.circular(10),
          ),
        ),
      ],
    );
  }

  Widget _buildTabButton(String text, int index, BorderRadius borderRadius) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: _selectedTab == index ? Colors.white : Colors.transparent,
            border: Border.all(
              color: _selectedTab == index
                  ? Colors.transparent
                  : Colors.grey[300]!,
            ),
            boxShadow: _selectedTab == index
                ? [
              BoxShadow(
                color: Colors.grey.withOpacity(0.15),
                spreadRadius: 1,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ]
                : [],
            borderRadius: borderRadius,
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: _selectedTab == index
                  ? Theme
                  .of(context)
                  .primaryColor
                  : Colors.grey,
              fontWeight: _selectedTab == index
                  ? FontWeight.w500
                  : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildJobDescription() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Description Section
        Container(
          padding: const EdgeInsets.all(16),
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.description_outlined,
                      color: Theme
                          .of(context)
                          .primaryColor, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Job Description',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                widget.job.description ?? 'No description available.',
                style: TextStyle(
                  color: Colors.grey[700],
                  height: 1.5,
                ),
                textAlign: TextAlign.justify,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _buildJobRequirement(),

        // Add company environments section if available
        if (widget.job.companyEnvironments.isNotEmpty) ...[
          const SizedBox(height: 20),
          _buildCompanyEnvironments(),
        ],

        const SizedBox(height: 20),
        _buildJobContactInfo(),

        const SizedBox(height: 20),
        _buildApplyButton(context),
      ],
    );
  }

  Widget _buildJobRequirement() {
    return Container(
      padding: const EdgeInsets.all(16),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.assignment_outlined,
                  color: Theme
                      .of(context)
                      .primaryColor, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Job Requirements',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (widget.job.requirements != null &&
              (widget.job.requirements as List).isNotEmpty)
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: (widget.job.requirements as List).length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 6, right: 8),
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Theme
                              .of(context)
                              .primaryColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          widget.job.requirements[index],
                          style: TextStyle(
                            color: Colors.grey[700],
                            height: 1.5,
                          ),
                          textAlign: TextAlign.justify,
                        ),
                      ),
                    ],
                  ),
                );
              },
            )
          else
            Text(
              'No requirements specified.',
              style: TextStyle(color: Colors.grey[700], height: 1.5),
              textAlign: TextAlign.justify,
            ),
        ],
      ),
    );
  }

  GoogleMapController? _mapController;
  bool _isMapReady = false;

  Set<Marker> _createMarker(LatLng point) {
    return {
      Marker(
        markerId: MarkerId("job-location"),
        position: point,
        infoWindow: InfoWindow(
          title: 'Job Location',
        ),
      ),
    };
  }

  Widget _buildJobContactInfo() {
    final jobAddress = widget.job.location2;
    final jobEmail = widget.job.email;
    final jobContact = widget.job.phone;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline,
                  color: Theme
                      .of(context)
                      .primaryColor, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Ask for More Information',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Email Section
          Row(
            children: [
              Icon(Icons.email_outlined, size: 20, color: Colors.grey[700]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  jobEmail ?? 'No email provided.',
                  style: TextStyle(
                    color: Colors.grey[700],
                    height: 1.5,
                  ),
                  textAlign: TextAlign.justify,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Phone Section
          Row(
            children: [
              Icon(Icons.phone_outlined, size: 20, color: Colors.grey[700]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  jobContact ?? 'No contact number provided.',
                  style: TextStyle(
                    color: Colors.grey[700],
                    height: 1.5,
                  ),
                  textAlign: TextAlign.justify,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Address Section
          Row(
            children: [
              Icon(Icons.location_on_outlined,
                  size: 20, color: Colors.grey[700]),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  jobAddress ?? 'No address provided.',
                  style: TextStyle(
                    color: Colors.grey[700],
                    height: 1.5,
                  ),
                  textAlign: TextAlign.justify,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Google Map Section with Proper Lifecycle Management
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
            ),
            child: FutureBuilder<LatLng>(
              future: _getLatLngFromAddress(jobAddress),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError || !snapshot.hasData) {
                  print("Map API Error: ${snapshot.error}");
                  return Center(
                    child: Text(
                      'Failed to load map.\nCheck API key or address.',
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                return ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: snapshot.data!,
                      zoom: 14,
                    ),
                    onMapCreated: (controller) {
                      _mapController = controller;
                      _mapController!.animateCamera(
                        CameraUpdate.newLatLng(snapshot.data!),
                      );
                    },
                    markers: _createMarker(snapshot.data!),
                    gestureRecognizers: Set()
                      ..add(Factory<OneSequenceGestureRecognizer>(
                            () => EagerGestureRecognizer(),
                      )),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyEnvironments() {
    return Container(
      padding: const EdgeInsets.all(16),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.business_center_outlined,
                  color: Theme.of(context).primaryColor, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Company Environments',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.job.companyEnvironments.length,
            itemBuilder: (context, index) {
              final environment = widget.job.companyEnvironments[index];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    environment.placeName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildEnvironmentButtons(environment),
                  const SizedBox(height: 16),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEnvironmentButtons(CompanyEnvironment environment) {
    final hasArLink = environment.arLink.isNotEmpty;
    final hasMomentoLink = environment.momentoLink.isNotEmpty;

    // Single button case
    if (hasArLink && !hasMomentoLink) {
      return _buildButton(
        'AR Link',
        environment.arLink,
        double.infinity,
      );
    } else if (!hasArLink && hasMomentoLink) {
      return _buildButton(
        'Momento 360',
        environment.momentoLink,
        double.infinity,
      );
    }

    // Two buttons case
    return Row(
      children: [
        if (hasArLink)
          Expanded(
            child: _buildButton(
              'AR Link',
              environment.arLink,
              null,
            ),
          ),
        if (hasArLink && hasMomentoLink)
          const SizedBox(width: 8),
        if (hasMomentoLink)
          Expanded(
            child: _buildButton(
              'Momento 360',
              environment.momentoLink,
              null,
            ),
          ),
      ],
    );
  }

  Widget _buildButton(String label, String url, double? width) {
    return SizedBox(
      width: width,
      child: OutlinedButton(
        onPressed: () => _launchUrl(url),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Theme.of(context).primaryColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Theme.of(context).primaryColor,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Future<void> _launchUrl(String urlString) async {
    try {
      final Uri url = Uri.parse(urlString);
      if (!await launchUrlString(
        urlString,
        mode: LaunchMode.externalApplication,
      )) {
        throw 'Could not launch $urlString';
      }
    } catch (e) {
      print('Error launching URL: $e');
      // You might want to show a snackbar or other error message to the user
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open the link. Please try again later.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

// Dispose the map controller to prevent memory leaks
  @override
  void dispose() {
    if (_isMapReady && _mapController != null) {
      _mapController?.dispose();
      _mapController = null;
      _isMapReady = false;
    }
    super.dispose();
  }

  Future<LatLng> _getLatLngFromAddress(String? address) async {
    try {
      if (address == null) return LatLng(3.1390, 101.6869);
      List<Location> locations = await locationFromAddress(address);
      return LatLng(locations.first.latitude, locations.first.longitude);
    } catch (e) {
      print("Address resolution failed: $e");
      return LatLng(3.1390, 101.6869); // Default fallback
    }
  }

  Widget _buildApplyButton(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 25),
      height: 45,
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: Theme.of(context).primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        onPressed: () async {
          print('Apply Now button clicked'); // Debug statement
          try {
            await applyForJob(widget.job.id, context);
          } catch (e) {
            print('Error during job application: $e');
          }
        },
        child: const Text(
          'Apply Now',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildOfficeDetails() {
    if (_isLoadingEmployer) {
      return Center(child: CircularProgressIndicator());
    }

    if (_employerData == null) {
      return Center(
        child: Text(
          'Company information not available',
          style: TextStyle(color: Colors.grey[700]),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Company Info Section
        Container(
          padding: const EdgeInsets.all(16),
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.business_outlined,
                      color: Theme
                          .of(context)
                          .primaryColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Company Information',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _employerData?['company_name'] ?? 'Company Name',
                style: TextStyle(
                  color: Colors.grey[700],
                  height: 1.5,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (_employerData?['company_description'] != null) ...[
                const SizedBox(height: 8),
                Text(
                  _employerData?['company_description'],
                  style: TextStyle(
                    color: Colors.grey[700],
                    height: 1.5,
                  ),
                  textAlign: TextAlign.justify,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Contact Info Section
        Container(
          padding: const EdgeInsets.all(16),
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.contact_mail_outlined,
                      color: Theme
                          .of(context)
                          .primaryColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Contact Information',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildContactItem(
                Icons.email_outlined,
                'Email',
                _employerData?['company_email'] ?? 'Not specified',
              ),
              const SizedBox(height: 8),
              _buildContactItem(
                Icons.phone_outlined,
                'Phone',
                _employerData?['company_tel'] ?? 'Not specified',
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Address Section with Map
        if (_employerData?['address'] != null)
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.location_on_outlined,
                        color: Theme.of(context).primaryColor, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Our Address',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                      height: 1.5,
                    ),
                    children: [
                      TextSpan(
                        text: '${_employerData?['address']['no'] ?? ''} ',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      TextSpan(text: '${_employerData?['address']['road'] ?? ''}, '),
                      TextSpan(text: '${_employerData?['address']['city'] ?? ''}, '),
                      TextSpan(text: '${_employerData?['address']['postcode'] ?? ''}, '),
                      TextSpan(text: _employerData?['address']['state'] ?? ''),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: FutureBuilder<LatLng>(
                    future: _getLatLngFromAddress(
                      '${_employerData?['address']['no']} '
                          '${_employerData?['address']['road']} '
                          '${_employerData?['address']['postcode']} '
                          '${_employerData?['address']['city']} '
                          '${_employerData?['address']['state']}',
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError || !snapshot.hasData) {
                        return Center(
                          child: Text(
                            'Failed to load map.\nCheck API key or address.',
                            textAlign: TextAlign.center,
                          ),
                        );
                      }

                      return ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: snapshot.data!,
                            zoom: 14,
                          ),
                          onMapCreated: (controller) {
                            _mapController = controller;
                            _mapController!.animateCamera(
                              CameraUpdate.newLatLng(snapshot.data!),
                            );
                          },
                          markers: _createMarker(snapshot.data!),
                          gestureRecognizers: Set()
                            ..add(Factory<OneSequenceGestureRecognizer>(
                                  () => EagerGestureRecognizer(),
                            )),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildContactItem(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[700]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[900],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}