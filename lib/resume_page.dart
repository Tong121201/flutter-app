import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:open_file/open_file.dart';
import 'package:dio/dio.dart';

class ResumePage extends StatefulWidget {
  final String studentId;
  final String programId;

  const ResumePage({
    Key? key,
    required this.studentId,
    required this.programId
  }) : super(key: key);

  @override
  _ResumePageState createState() => _ResumePageState();
}

class _ResumePageState extends State<ResumePage> {
  String? resumeUrl;
  bool isLoading = true;
  String? resumeFileName;
  String? studentName;
  bool isNewUpload = false;
  double _downloadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    // Set status bar and navigation bar to transparent
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark, // For Android
      statusBarBrightness: Brightness.light, // For iOS
    ));
    fetchResume();
  }

  Future<void> fetchResume() async {
    try {
      DocumentSnapshot studentDoc = await FirebaseFirestore.instance
          .collection('students')
          .doc(widget.programId)
          .collection('students')
          .doc(widget.studentId)
          .get();

      if (studentDoc.exists) {
        Map<String, dynamic>? data = studentDoc.data() as Map<String, dynamic>?;

        setState(() {
          // Explicitly check if 'resume' exists and is not null
          if (data != null && data.containsKey('resume') && data['resume'] != null) {
            studentName = data['studentName'] ?? 'Student';
            resumeUrl = data['resume'] as String?;
            resumeFileName = '${studentName?.replaceAll(' ', '_')}.pdf';
          } else {
            // Reset all resume-related variables if no resume exists
            resumeUrl = null;
            resumeFileName = null;
            studentName = null;
          }

          isLoading = false;
          isNewUpload = false;
        });
      } else {
        setState(() {
          resumeUrl = null;
          resumeFileName = null;
          studentName = null;
          isLoading = false;
          isNewUpload = false;
        });
      }
    } catch (e) {
      _handleError('Failed to fetch resume', e);
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> uploadResume() async {
    // Ensure student name is fetched first
    if (studentName == null) {
      try {
        DocumentSnapshot studentDoc = await FirebaseFirestore.instance
            .collection('students')
            .doc(widget.programId)
            .collection('students')
            .doc(widget.studentId)
            .get();

        if (studentDoc.exists) {
          setState(() {
            studentName = studentDoc.get('studentName') ?? 'Student';
          });
        } else {
          setState(() {
            studentName = 'Student';
          });
        }
      } catch (e) {
        setState(() {
          studentName = 'Student';
        });
        _handleError('Failed to fetch student name', e);
        return;
      }
    }

    FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf']
    );

    if (result != null && result.files.single.path != null) {
      String filePath = result.files.single.path!;

      // Debug print to check studentName
      print('Current studentName before upload: $studentName');

      // Use the fetched or default student name
      String safeStudentName = studentName!.replaceAll(' ', '_');
      String fileName = '$safeStudentName.pdf';

      setState(() {
        isLoading = true;
      });

      try {
        Reference storageRef = FirebaseStorage.instance
            .ref()
            .child('resumes/${widget.studentId}/$fileName');
        UploadTask uploadTask = storageRef.putFile(File(filePath));
        TaskSnapshot snapshot = await uploadTask;

        String downloadUrl = await snapshot.ref.getDownloadURL();

        await FirebaseFirestore.instance
            .collection('students')
            .doc(widget.programId)
            .collection('students')
            .doc(widget.studentId)
            .update({'resume': downloadUrl});

        setState(() {
          resumeUrl = downloadUrl;
          resumeFileName = fileName;
          isLoading = false;
          isNewUpload = true;
        });

        _showSuccessSnackBar('Resume uploaded successfully');
      } catch (e) {
        _handleError('Failed to upload resume', e);
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> removeResume() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Remove Resume'),
          content: const Text('Are you sure you want to remove your resume?'),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Remove'),
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  // Delete from Storage
                  if (resumeUrl != null) {
                    Reference storageRef = FirebaseStorage.instance.refFromURL(resumeUrl!);
                    await storageRef.delete();
                  }

                  // Remove from Firestore
                  await FirebaseFirestore.instance
                      .collection('students')
                      .doc(widget.programId)
                      .collection('students')
                      .doc(widget.studentId)
                      .update({'resume': FieldValue.delete()});

                  setState(() {
                    resumeUrl = null;
                    resumeFileName = null;
                    isNewUpload = false;
                  });

                  _showSuccessSnackBar('Resume removed successfully');
                } catch (e) {
                  _handleError('Failed to remove resume', e);
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _viewResume() async {
    try {
      await _requestPermissions();

      if (resumeUrl != null && resumeUrl!.isNotEmpty) {
        // Use Dio for more reliable and faster download
        Dio dio = Dio();

        // Get the app's temporary directory
        Directory tempDir = await getTemporaryDirectory();
        String tempPath = tempDir.path;
        String localPath = '$tempPath/$resumeFileName';

        try {
          // Download the file with progress tracking
          await dio.download(
            resumeUrl!,
            localPath,
            onReceiveProgress: (received, total) {
              setState(() {
                _downloadProgress = received / total;
              });

              print('Download progress: ${(_downloadProgress * 100).toStringAsFixed(0)}%');
            },
          );

          // Reset download progress
          setState(() {
            _downloadProgress = 0.0;
          });

          // Open the downloaded file
          final result = await OpenFile.open(localPath);

          if (result.type != ResultType.done) {
            _showErrorSnackBar("Failed to open the file: ${result.message}");
          }
        } catch (e) {
          _showErrorSnackBar("Download or open failed: $e");
        }
      } else {
        _showErrorSnackBar("No resume available");
      }
    } catch (e) {
      _showErrorSnackBar("Error viewing resume: $e");
    }
  }

  Future<void> _requestPermissions() async {
    // Check if permission is granted
    PermissionStatus status = await Permission.storage.status;

    // Request storage permission if not granted
    if (!status.isGranted) {
      await Permission.storage.request();
    }

    // For Android 10+, ensure the app has the necessary permission
    if (Platform.isAndroid && await Permission.manageExternalStorage.isPermanentlyDenied) {
      openAppSettings(); // Open settings for the user to manually grant permission
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _handleError(String message, dynamic error) {
    print("$message: $error");
    _showErrorSnackBar(message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Set background color to white
      appBar: AppBar(
        title: const Text('Resume',style: TextStyle(
          fontSize: 22.0,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),),
        centerTitle: true,
        backgroundColor: Colors.white, // Set app bar background to white
        elevation: 0, // Remove app bar shadow
        foregroundColor: Colors.black, // Ensure text and icons are black
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: resumeUrl == null
                    ? _buildNoResumeWidget()
                    : _buildResumeDetailsWidget(),
              ),
            ),
            const SizedBox(height: 20),
            if (_downloadProgress > 0)
              LinearProgressIndicator(value: _downloadProgress),
            const SizedBox(height: 10),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResumeWidget() {
    return Column(
      children: [
        Icon(
          Icons.file_upload_outlined,
          size: 80,
          color: Colors.grey[400],
        ),
        const SizedBox(height: 16),
        Text(
          'No resume uploaded yet',
          style: TextStyle(
            fontSize: 18,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildResumeDetailsWidget() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          alignment: Alignment.topRight,
          children: [
            GestureDetector(
              onTap: _viewResume,
              child: Row(
                children: [
                  Icon(Icons.picture_as_pdf, color: Colors.red, size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          resumeFileName ?? 'Resume',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          isNewUpload
                              ? 'Uploaded successfully'
                              : 'Resume',
                          style: TextStyle(
                              color: isNewUpload ? Colors.green[700] : Colors.blue[700]),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red, size: 24),
                    onPressed: removeResume,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return ElevatedButton.icon(
      onPressed: uploadResume,
      icon: const Icon(Icons.upload_file, color: Colors.black),
      label: const Text(
        'Upload New Resume',
        style: TextStyle(color: Colors.black),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        side: BorderSide(color: Colors.black, width: 1),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }
}