import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditProfilePage extends StatefulWidget {
  @override
  _EditProfilePageState createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  // Controllers for editable fields
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _noController = TextEditingController();
  final TextEditingController _roadController = TextEditingController();
  final TextEditingController _postcodeController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();

  String? _selectedState; // Nullable String for dropdown selection
  String _profilePicUrl = '';
  String _studentName = '';
  String _studentId = '';
  String _email = '';
  String _gender = '';
  String _nationality = '';
  String _program = '';
  String _programId = '';
  String _internshipCompany = '';
  String _internshipStatus = '';

  final User? _currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _fetchStudentData();
  }

  Future<void> _fetchStudentData() async {
    try {
      if (_currentUser == null) {
        _showErrorDialog('No user logged in');
        return;
      }

      // Fetch email document
      String userEmail = _currentUser!.email!;
      QuerySnapshot emailQuerySnapshot = await FirebaseFirestore.instance
          .collection('email')
          .where('email', isEqualTo: userEmail)
          .get();

      if (emailQuerySnapshot.docs.isEmpty) {
        _showErrorDialog('Email not found in email collection');
        return;
      }

      // Get student ID from email collection
      DocumentSnapshot emailDoc = emailQuerySnapshot.docs.first;
      String studentId = emailDoc.get('studentId');

      if (studentId.isEmpty) {
        _showErrorDialog('Student ID is missing');
        return;
      }

      // Fetch student data from allStudents collection
      DocumentSnapshot studentDoc = await FirebaseFirestore.instance
          .collection('allStudents')
          .doc(studentId)
          .get();

      if (!studentDoc.exists) {
        _showErrorDialog('Student data not found');
        return;
      }

      // Extract student data
      Map<String, dynamic>? studentData = studentDoc.data() as Map<
          String,
          dynamic>?;

      if (studentData == null) {
        _showErrorDialog('Unable to retrieve student data');
        return;
      }

      // Get program ID
      String programId = studentData['currentProgram'] ?? '';

      // Fetch program-specific student data
      DocumentSnapshot programStudentDoc = await FirebaseFirestore.instance
          .collection('students')
          .doc(programId)
          .collection('students')
          .doc(studentId)
          .get();

      Map<String, dynamic>? programStudentData = programStudentDoc
          .data() as Map<String, dynamic>?;

      setState(() {
        _studentId = studentId;
        _studentName = studentData['name'] ?? '';
        _email = userEmail;
        _profilePicUrl = studentData['profilePic'] ?? (_currentUser?.photoURL ?? '');
        _programId = programId;

        // Safely access internshipCompany with null-aware operator
        _internshipCompany = programStudentData?['internshipCompany'] ?? '';

        // Optional: If the value is empty, display a default message like 'Not yet assigned'
        if (_internshipCompany.isEmpty) {
          _internshipCompany = '-';
        }

        // Populate fields from program-specific student data if available
        if (programStudentData != null) {
          _gender = programStudentData['gender'] ?? '';
          _nationality = programStudentData['nationality'] ?? '';
          _program = programStudentData['program'] ?? '';
          _contactController.text = programStudentData['contact'] ?? '';
          _noController.text = programStudentData['address']['no'] ?? '';
          _roadController.text = programStudentData['address']['road'] ?? '';
          _postcodeController.text =
              programStudentData['address']['postcode'] ?? '';
          _cityController.text = programStudentData['address']['city'] ?? '';
          _selectedState = programStudentData['address']['state'];
          _internshipStatus = programStudentData['internshipStatus'] ?? '';
        }
      });

    } catch (e) {
      print('Error fetching student data: $e');
      _showErrorDialog('An error occurred while fetching student data');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Error'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Transparent status bar
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Edit Profile',
          style: TextStyle(
              color: Colors.black, fontWeight: FontWeight.bold, fontSize: 22),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
    body: NestedScrollView(
    headerSliverBuilder: (context, innerBoxIsScrolled) {
      return [

      ];
    },
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Picture Section (similar to previous implementation)
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60.0,
                      backgroundColor: Colors.grey[300],
                      child: _profilePicUrl.isNotEmpty
                          ? ClipOval(
                        child: Image.network(
                          _profilePicUrl,
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.person,
                              size: 60,
                              color: Colors.grey[600],
                            );
                          },
                        ),
                      )
                          : Icon(
                        Icons.person,
                        size: 60,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // General Information Section
              const Text(
                'General Information',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87),
              ),
              const SizedBox(height: 10),

              // Use the fetched student data
              _buildReadOnlyField('Name', _studentName),
              _buildReadOnlyField('Student ID', _studentId),
              _buildReadOnlyField('Email', _email),
              _buildEditableField(
                  'Contact Number', _contactController, 'Enter contact number'),
              _buildReadOnlyField('Gender', _gender),


              // Address Section
              const SizedBox(height: 10),
              Text('Address', style: _sectionLabelStyle),
              _buildEditableField('No', _noController, 'House/Building No'),
              _buildEditableField('Road', _roadController, 'Enter road name'),
              _buildEditableField(
                  'Postcode', _postcodeController, 'Enter postcode'),
              _buildEditableField('City', _cityController, 'Enter city'),

              // State Dropdown
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: DropdownButtonFormField<String>(
                  value: _selectedState,
                  decoration: InputDecoration(
                    labelText: 'State',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  hint: const Text('Select your state'),
                  items: [
                    'Johor', 'Kedah', 'Kelantan', 'Kuala Lumpur', 'Melaka',
                    'Negeri Sembilan', 'Pahang', 'Penang', 'Perak', 'Perlis',
                    'Sabah', 'Sarawak', 'Selangor', 'Terengganu',
                  ]
                      .map((state) =>
                      DropdownMenuItem(
                        value: state,
                        child: Text(state),
                      ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedState = value;
                    });
                  },
                ),
              ),

              const SizedBox(height: 10),
              _buildReadOnlyField('Nationality', _nationality),
              _buildReadOnlyField('Program', _program),
              _buildReadOnlyField('Internship Company', _internshipCompany),
              _buildReadOnlyField('Internship Status', _internshipStatus),


              const SizedBox(height: 32),
              // Save Button
              Center(
                child: ElevatedButton(
                  onPressed: _saveChanges,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    padding: const EdgeInsets.symmetric(
                        vertical: 15, horizontal: 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Save Changes',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }


  void _saveChanges() async {
    try {
      // Validate required fields
      if (_studentId.isEmpty || _programId.isEmpty) {
        _showErrorDialog(
            'Unable to save changes. Student information is missing.');
        return;
      }

      // Prepare the update data
      Map<String, dynamic> updateData = {
        'contact': _contactController.text.trim(),
        'address': {
          'no': _noController.text.trim(),
          'road': _roadController.text.trim(),
          'postcode': _postcodeController.text.trim(),
          'city': _cityController.text.trim(),
          'state': _selectedState,
        }
      };

      // Update in program-specific students collection
      await FirebaseFirestore.instance
          .collection('students')
          .doc(_programId)
          .collection('students')
          .doc(_studentId)
          .update(updateData);

      // Unfocus any active text fields to remove cursor
      FocusScope.of(context).unfocus();

      // Fetch and refresh student data
      await _fetchStudentData();

      _showSuccessSnackBar('Profile updated successfully!');

    } catch (e) {
      print('Error saving changes: $e');
      _showErrorDialog('An error occurred while saving changes');
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

  final _sectionLabelStyle = const TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.black54,
  );

  // Non-editable Field Widget with improved visibility
  Widget _buildReadOnlyField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: TextField(
        controller: TextEditingController(text: value),
        // Ensure value is passed correctly
        enabled: false,
        style: TextStyle(color: Colors.black87),
        // Improve visibility of text
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
              color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 16),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
            borderSide: BorderSide(color: Colors.grey.shade400),
          ),
          filled: true,
          fillColor: Colors.grey[200],
        ),
      ),
    );
  }

// Editable Field Widget with better text color visibility
  Widget _buildEditableField(String label, TextEditingController controller,
      String hint) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: TextField(
        controller: controller,
        style: TextStyle(color: Colors.black87),
        // Ensure the text is more visible
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: TextStyle(
              color: Colors.black87, fontWeight: FontWeight.w600),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
            borderSide: BorderSide(color: Colors.grey.shade400),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }
}