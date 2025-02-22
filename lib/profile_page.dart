import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path/path.dart' as path;
import 'package:qiu_internar/placement_letter_page.dart';
import 'package:qiu_internar/resume_page.dart';
import 'package:qiu_internar/skills_page.dart';
import 'edit_profile_page.dart';
import 'loginpage.dart';

class ProfilePage extends StatefulWidget {

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String _profilePicUrl = '';
  bool _isProfileUpdated = false; // Track if the profile was updated
  String _studentId = ''; // Add this line to store the studentId
  String _programId = '';
  // Get the current logged-in user
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _fetchProfilePicture();
  }

  Future<void> _fetchProfilePicture() async {
    if (_currentUser == null) return;

    try {
      // Fetch the current user email
      String userEmail = _currentUser!.email!;

      // Query the 'email' collection to find the document with this email
      QuerySnapshot emailQuerySnapshot = await FirebaseFirestore.instance
          .collection('email') // Assuming the collection name is 'email'
          .where('email', isEqualTo: userEmail)
          .get();

      if (emailQuerySnapshot.docs.isEmpty) {
        print('Email not found in email collection');
        // Fallback to Google profile pic or empty string
        setState(() {
          _profilePicUrl = _currentUser?.photoURL ?? '';
        });
        return;
      }

      // Extract the studentId from the first document in the query result
      DocumentSnapshot emailDoc = emailQuerySnapshot.docs.first;
      String studentId = emailDoc.get('studentId'); // Ensure this field exists

      // Store the studentId as a class-level variable
      setState(() {
        _studentId = studentId;
      });

      if (studentId.isEmpty) {
        print('Student ID is missing in the email document');
        // Fallback to Google profile pic or empty string
        setState(() {
          _profilePicUrl = _currentUser?.photoURL ?? '';
        });
        return;
      }

      // Fetch the student document using the studentId
      final studentDoc = await FirebaseFirestore.instance
          .collection('allStudents')
          .doc(studentId) // Use the studentId to fetch the student's document
          .get();

      String programId = studentDoc.get('currentProgram');
      // Store the studentId as a class-level variable
      setState(() {
        _programId = programId;
      });

      if (studentDoc.exists && studentDoc.data()?['profilePic'] != null) {
        // If a custom profile pic exists in Firestore, use it
        setState(() {
          _profilePicUrl = studentDoc.data()?['profilePic'];
        });
      } else {
        // If no custom profile pic, use Google profile pic
        setState(() {
          _profilePicUrl = _currentUser?.photoURL ?? '';
        });
      }
    } catch (e) {
      print('Error fetching profile picture: $e');
      // Fallback to Google profile pic or empty string
      setState(() {
        _profilePicUrl = _currentUser?.photoURL ?? '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Check if the profile was updated, if so, pass true to the previous screen
        if (_isProfileUpdated) {
          Navigator.of(context).pop(true); // Pass 'true' if profile updated
        }
        return true; // Allow navigation to go back
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: const Text(
            'Profile',
            style: TextStyle(
              fontSize: 22.0,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          centerTitle: true,  // This ensures the title is centered
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
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
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () => _handleEditProfilePic(context),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                            padding: const EdgeInsets.all(8.0),
                            child: const Icon(
                              Icons.edit,
                              color: Colors.white,
                              size: 16.0,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16.0),
                Center(
                  child: Text(
                    _currentUser?.displayName ?? 'Name',
                    style: const TextStyle(
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Center(
                  child: Text(
                    _currentUser?.email ?? 'email@example.com',
                    style: const TextStyle(
                      fontSize: 16.0,
                      color: Colors.grey,
                    ),
                  ),
                ),
                const SizedBox(height: 24.0),
                _buildOptionSection(),
                const Spacer(),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: SizedBox(
                    height: 48,
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _handleLogout,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 15.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      child: const Text(
                        'Log Out',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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

  Widget _buildOptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildOption(
          'Edit Profile',
          icon: Icons.edit,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => EditProfilePage()),
            );
          },
        ),
        _buildOption(
          'Resume',
          icon: Icons.description,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ResumePage(studentId: _studentId,
                  programId: _programId,),
              ),
            );
          },
        ),
        _buildOption(
          'Placement Letter',
          icon: Icons.description_outlined,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PlacementLetterPage(studentId: _studentId,
                  programId: _programId,),
              ),
            );
          },
        ),
        _buildOption(
          'Skills',
          icon: Icons.star,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => SkillsSelectionPage()),
            );
          },
        ),
      ],
    );
  }


  Widget _buildOption(String title, {required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.blue, size: 24.0), // Add the icon
                const SizedBox(width: 12.0), // Add spacing between icon and text
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Icon(Icons.chevron_right, color: Colors.grey), // Arrow icon
          ],
        ),
      ),
    );
  }


  void _handleLogout() async {
    try {
      // Sign out from Firebase
      await FirebaseAuth.instance.signOut();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Logout successful!'),
          duration: Duration(seconds: 2),
        ),
      );
      // Navigate to login screen and remove all previous routes
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => LoginPage()),
            (Route<dynamic> route) => false,
      );
    } catch (e) {
      // Handle any logout errors
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error logging out: ${e.toString()}')),
      );
    }
  }

  void _handleEditProfilePic(BuildContext context) {
    // Use the current user's UID
    final String studentId = _currentUser?.uid ?? '';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: Container(
            width: 300,
            constraints: const BoxConstraints(
              maxWidth: 250,
              maxHeight: 250,
            ),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Edit Profile Photo',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 10),
                const Center(
                  child: Text(
                    'Upload from',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.normal,
                      color: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _pickImageFromGallery(context);
                    },
                    icon: const Icon(Icons.photo_library, color: Colors.white),
                    label: const Text('Gallery', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Center(
                  child: Text('-- OR --'),
                ),
                const SizedBox(height: 10),
                Center(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _pickImageFromCamera(context);
                    },
                    icon: const Icon(Icons.camera_alt, color: Colors.white),
                    label: const Text('Camera', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _pickImageFromGallery(BuildContext context) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile != null) {
        await _uploadProfilePicture(context, File(pickedFile.path));
      }
    } catch (e) {
      _showErrorDialog(context, 'Error selecting image from gallery: $e');
    }
  }

  Future<void> _pickImageFromCamera(BuildContext context) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(source: ImageSource.camera);

      if (pickedFile != null) {
        await _uploadProfilePicture(context, File(pickedFile.path));
      }
    } catch (e) {
      _showErrorDialog(context, 'Error capturing image from camera: $e');
    }
  }

  Future<void> _uploadProfilePicture(BuildContext context, File imageFile) async {
    try {
      // Ensure current user exists
      if (_currentUser == null) {
        _showErrorDialog(context, 'No user logged in');
        await FirebaseAuth.instance.signOut();
        return;
      }

      // Show "Uploading..." indicator
      showDialog(
        context: context,
        barrierDismissible: false, // Prevent dismissing while uploading
        builder: (BuildContext context) {
          return const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 30),
                Text("Uploading..."),
              ],
            ),
          );
        },
      );

      // Fetch the current user email
      String userEmail = _currentUser!.email!;

      // Query the 'email' collection to find the document with this email
      QuerySnapshot emailQuerySnapshot = await FirebaseFirestore.instance
          .collection('email') // Assuming the new collection is named 'email'
          .where('email', isEqualTo: userEmail)
          .get();

      if (emailQuerySnapshot.docs.isEmpty) {
        Navigator.of(context).pop(); // Close the "Uploading..." dialog
        _showErrorDialog(context, 'Email not found in email collection');
        return;
      }

      // Extract the studentId from the first document in the query result
      DocumentSnapshot emailDoc = emailQuerySnapshot.docs.first;
      String studentId = emailDoc.get('studentId'); // Ensure this field exists
      if (studentId.isEmpty) {
        Navigator.of(context).pop(); // Close the "Uploading..." dialog
        _showErrorDialog(context, 'Student ID is missing in the email document');
        return;
      }

      print("Student ID fetched: $studentId");

      // Fetch the student data from the 'allStudents' collection
      DocumentSnapshot studentDoc = await FirebaseFirestore.instance
          .collection('allStudents')
          .doc(studentId)
          .get();

      if (!studentDoc.exists) {
        Navigator.of(context).pop(); // Close the "Uploading..." dialog
        _showErrorDialog(context, 'Student data not found for studentId: $studentId');
        return;
      }

      // Retrieve the programID (currentProgram) from the student document
      String programID = studentDoc.get('currentProgram') ?? '';
      if (programID.isEmpty) {
        Navigator.of(context).pop(); // Close the "Uploading..." dialog
        _showErrorDialog(context, 'Program ID not found for studentId: $studentId');
        return;
      }

      // Define the storage path and upload the profile picture
      String fileName = path.basename(imageFile.path); // Retain original filename
      String storagePath = 'students/profile-pictures/$studentId/$fileName';

      // Upload the file to Firebase Storage
      Reference storageReference = FirebaseStorage.instance.ref().child(storagePath);
      UploadTask uploadTask = storageReference.putFile(imageFile);
      TaskSnapshot taskSnapshot = await uploadTask;

      // Get the download URL
      String downloadURL = await taskSnapshot.ref.getDownloadURL();

      // Update Firestore documents with the new profile picture URL
      // Update program-specific student collection
      DocumentReference studentRef = FirebaseFirestore.instance
          .collection('students')
          .doc(programID)
          .collection('students')
          .doc(studentId);

      await studentRef.update({'profilePic': downloadURL});

      // Update allStudents collection
      await FirebaseFirestore.instance
          .collection('allStudents')
          .doc(studentId)
          .update({'profilePic': downloadURL});

      // Refresh the profile picture in the UI
      _fetchProfilePicture();

      // Close the "Uploading..." dialog
      Navigator.of(context).pop();
      Navigator.of(context).pop(); // Close the "Upload Options" dialog

      _showSuccessSnackBar('Profile picture uploaded successfully!');

      // Update the profile status only if the upload is successful
      setState(() {
        _isProfileUpdated = true; // Mark the profile as updated
      });
    } catch (e) {
      Navigator.of(context).pop(); // Close the "Uploading..." dialog
      _showErrorDialog(context, 'Error uploading profile picture: $e');
    }
  }

  void _showErrorDialog(BuildContext context, String message) {
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
}