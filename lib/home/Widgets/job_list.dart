import 'package:flutter/material.dart';
import 'package:qiu_internar/models/job.dart';
import 'job_detail.dart';
import 'job_item.dart';

class Joblist extends StatefulWidget {
  final int selectedTagIndex;

  const Joblist({
    Key? key,
    required this.selectedTagIndex,
  }) : super(key: key);

  @override
  _JoblistState createState() => _JoblistState();
}

class _JoblistState extends State<Joblist> {
  late Future<List<Job>> jobsFuture;

  @override
  void initState() {
    super.initState();
    jobsFuture = getFilteredJobs();
  }

  @override
  void didUpdateWidget(Joblist oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedTagIndex != widget.selectedTagIndex) {
      setState(() {
        jobsFuture = getFilteredJobs();
      });
    }
  }

  Future<List<Job>> getFilteredJobs() async {
    switch (widget.selectedTagIndex) {
      case 0:
        return Job.allJobs();
      case 1:
        return Job.getRecommendedJobs();
      case 2:
        return Job.getStarredJobs();
      default:
        return Job.allJobs();
    }
  }

  String getEmptyMessage() {
    switch (widget.selectedTagIndex) {
      case 0:
        return 'No Jobs Available';
      case 1:
        return 'No Recommended Jobs';
      case 2:
        return 'No Jobs Starred';
      default:
        return 'No Jobs Available';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 25, horizontal: 25),
      height: 160,
      child: FutureBuilder<List<Job>>(
        future: jobsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Text(
                getEmptyMessage(),
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }

          final jobs = snapshot.data!;
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            itemBuilder: (context, index) => GestureDetector(
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => DraggableScrollableSheet(
                    initialChildSize: 0.6,
                    minChildSize: 0.5,
                    maxChildSize: 1.0, // Allows full screen
                    builder: (context, scrollController) => ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                      child: JobDetail(
                        jobs[index],
                        scrollController: scrollController,
                      ),
                    ),
                  ),
                );
              },
              child: JobItem(
                jobs[index],
                onBookmarkToggle: () {
                  setState(() {
                    jobsFuture = getFilteredJobs();
                  });
                },
              ),
            ),
            separatorBuilder: (_, index) => const SizedBox(width: 15),
            itemCount: jobs.length,
          );
        },
      ),
    );
  }
}
