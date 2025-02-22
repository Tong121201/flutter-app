import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../models/job.dart';


class JobItem extends StatefulWidget {
  final Job job;
  final bool showTime;
  final String? currentUserId;
  final VoidCallback? onBookmarkToggle;

  JobItem(
      this.job, {
        this.showTime = false,
        this.currentUserId,
        this.onBookmarkToggle,
      });
  @override
  _JobItemState createState() => _JobItemState();
}

class _JobItemState extends State<JobItem> {
  bool _isLoading = false;

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
      final studentRef = FirebaseFirestore.instance.collection('allStudents').doc(studentId);

      // Get current student document
      final studentDoc = await studentRef.get();

      // Update local state first for immediate UI feedback
      bool newStarredState = !widget.job.isStarred;

      if (!studentDoc.exists) {
        // If student document doesn't exist, create it with starredJobs array
        if (newStarredState) {  // Only create if starring
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


  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      child: Container(
        width: 290,
        height: MediaQuery.of(context).size.height * 0.3,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Colors.white.withOpacity(0.95),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                          errorBuilder: (_, __, ___) => const Icon(Icons.business),
                        )
                            : const Icon(Icons.business),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.job.company,
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              widget.job.daysAgo,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: _isLoading
                      ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).primaryColor,
                      ),
                    ),
                  )
                      : Icon(
                    widget.job.isStarred ? Icons.bookmark : Icons.bookmark_outline_outlined,
                    color: widget.job.isStarred ? Theme.of(context).primaryColor : Colors.black,
                  ),
                  onPressed: _toggleStarred,
                ),
              ],
            ),
            const SizedBox(height: 15),
            Flexible(
              child: Text(
                widget.job.title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.location_on_outlined, color: Colors.grey, size: 16),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          '${widget.job.city}, ${widget.job.state}',
                          style: const TextStyle(color: Colors.grey),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.showTime) ...[
                  const SizedBox(width: 10),
                  Row(
                    children: [
                      Icon(Icons.access_time_outlined, color: Colors.grey, size: 16),
                      const SizedBox(width: 5),
                      Text(
                        widget.job.time,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
