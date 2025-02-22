import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../profile_page.dart';



class HomeAppBar extends StatefulWidget {
  @override
  _HomeAppBarState createState() => _HomeAppBarState();
}

class _HomeAppBarState extends State<HomeAppBar> {
  String _userName = '';
  String _userProfilePic = '';
  late ScrollController _scrollController;

  static const double fontSize = 27.0;
  static const double maxWidth = 270.0; // Maximum width for name display

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser != null) {
      try {
        // Check if the user's email exists in the "email" collection
        final emailQuerySnapshot = await FirebaseFirestore.instance
            .collection('email')
            .where('email', isEqualTo: currentUser.email)
            .get();

        if (emailQuerySnapshot.docs.isEmpty) {
          throw Exception("User email not found in the 'email' collection");
        }

        // Extract the studentId from the email collection
        final emailDoc = emailQuerySnapshot.docs.first;
        final studentId = emailDoc.data()['studentId'] ?? ''; // Ensure this field exists

        if (studentId.isEmpty) {
          throw Exception("Student ID is missing in the 'email' document");
        }

        // Fetch the user document from "allStudents" collection using studentId
        final userDoc = await FirebaseFirestore.instance
            .collection('allStudents')
            .doc(studentId)
            .get();

        final userData = userDoc.data();

        setState(() {
          // Set the username
          _userName = userData != null && userData['name'] != null
              ? userData['name'] as String // Custom username
              : (currentUser.displayName ?? 'User'); // Fallback to display name or default

          // Set the profile picture
          _userProfilePic = userData != null && userData['profilePic'] != null
              ? userData['profilePic'] as String // Custom profile picture
              : (currentUser.photoURL ?? ''); // Fallback to Google profile picture
        });

        // Start scrolling if needed
        _startScrolling();
      } catch (e) {
        print("Error fetching user info: $e");
        setState(() {
          _userName = currentUser.displayName ?? 'User';
          _userProfilePic = currentUser.photoURL ?? '';
        });
      }
    }
  }

  void _startScrolling() {
    final textWidth = _calculateTextWidth(_userName, fontSize);

    if (textWidth > maxWidth) {
      // Start the scroll animation
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(seconds: 5),
            curve: Curves.linear,
          ).then((_) {
            // Scroll back to the start
            _scrollController.animateTo(
              0,
              duration: const Duration(seconds: 5),
              curve: Curves.linear,
            ).whenComplete(_startScrolling); // Loop the animation
          });
        }
      });
    }
  }

  double _calculateTextWidth(String text, double fontSize) {
    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: fontSize),
      ),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout(minWidth: 0, maxWidth: double.infinity);

    return textPainter.size.width;
  }

  @override
  Widget build(BuildContext context) {
    final textWidth = _calculateTextWidth(_userName, fontSize);

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 15,
        left: 25,
        right: 25,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Welcome ,',
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 36,
                width: maxWidth,
                child: textWidth > maxWidth
                    ? SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  controller: _scrollController,
                  physics: const NeverScrollableScrollPhysics(),
                  child: Text(
                    _userName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: fontSize,
                    ),
                  ),
                )
                    : Text(
                  _userName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: fontSize,
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 10.0,top: 5.0),
                child: GestureDetector(
                  onTap: () async {
                    final profileUpdated = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProfilePage(),
                      ),
                    );

                    if (profileUpdated == true) {
                      // Reload the user information to update the profile picture
                      _loadUserInfo();
                    }
                  },
                  child: SizedBox(
                    width: 45,
                    height: 45,
                    child: ClipOval(
                      child: _userProfilePic.isNotEmpty
                          ? Image.network(
                        _userProfilePic,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(Icons.account_circle, size: 40);
                        },
                      )
                          : const Icon(Icons.account_circle, size: 40),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
