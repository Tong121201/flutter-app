import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/job.dart';

class JobContainer extends StatefulWidget {
  final Job job;
  final bool showTime;
  final VoidCallback? onBookmarkToggle;
  final VoidCallback? onDetailsTap;  // Add this

  JobContainer(
      this.job, {
        this.showTime = false,
        this.onBookmarkToggle,
        this.onDetailsTap,  // Add this
      });

  @override
  _EnhancedJobItemState createState() => _EnhancedJobItemState();
}

class _EnhancedJobItemState extends State<JobContainer> {
  bool _isLoading = false;

  Future<void> _toggleBookmark() async {
    // Existing bookmark logic from JobItem
    if (_isLoading) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user?.email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to bookmark jobs'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final emailSnapshot = await FirebaseFirestore.instance
          .collection('email')
          .where('email', isEqualTo: user?.email)
          .get();

      if (emailSnapshot.docs.isEmpty) throw Exception('Student not found');

      final studentId = emailSnapshot.docs.first['studentId'];
      final studentRef = FirebaseFirestore.instance.collection('allStudents').doc(studentId);
      final studentDoc = await studentRef.get();

      bool newStarredState = !widget.job.isStarred;

      if (!studentDoc.exists) {
        if (newStarredState) {
          await studentRef.set({'starredJobs': [widget.job.id]});
        }
      } else {
        final studentData = studentDoc.data();
        if (studentData != null) {
          List<dynamic> starredJobs = studentData['starredJobs'] ?? [];

          if (!newStarredState) {
            starredJobs.remove(widget.job.id);
          } else {
            starredJobs.add(widget.job.id);
          }

          await studentRef.update({'starredJobs': starredJobs});
        }
      }

      setState(() => widget.job.isStarred = newStarredState);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newStarredState ? 'Job bookmarked' : 'Bookmark removed'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update bookmark'),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Colors.grey.shade50,
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildCompanyLogo(),
                const SizedBox(width: 12),
                Expanded(child: _buildCompanyInfo()),
                _buildBookmarkButton(),
              ],
            ),
            const SizedBox(height: 16),
            _buildJobDetails(),
            const SizedBox(height: 16),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildCompanyLogo() {
    return Hero(
      tag: 'company_logo_${widget.job.id}',
      child: Container(
        height: 50,
        width: 50,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 1,
              blurRadius: 4,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: widget.job.logoUrl.isNotEmpty
              ? Image.network(
            widget.job.logoUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Icon(Icons.business),
          )
              : const Icon(Icons.business),
        ),
      ),
    );
  }

  Widget _buildCompanyInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.job.company,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          '${widget.job.city}, ${widget.job.state}',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildBookmarkButton() {
    return IconButton(
      icon: _isLoading
          ? const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      )
          : Icon(
        widget.job.isStarred ? Icons.bookmark : Icons.bookmark_border,
        color: widget.job.isStarred ? Theme.of(context).primaryColor : Colors.grey,
      ),
      onPressed: _toggleBookmark,
    );
  }

  Widget _buildJobDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.job.title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildDetailChip(Icons.attach_money, 'RM ${widget.job.allowance}'),
            const SizedBox(width: 8),
            if (widget.showTime)
              _buildDetailChip(Icons.access_time, widget.job.time),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Theme.of(context).primaryColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: Theme.of(context).primaryColor,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '${widget.job.hiredPax} positions',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
        GestureDetector(
          onTap: widget.onDetailsTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'View Details',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }
}