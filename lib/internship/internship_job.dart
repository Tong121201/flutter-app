import 'package:flutter/material.dart';
import '../../home/Widgets/job_detail.dart';
import '../../home/Widgets/job_item.dart';
import '../../models/job.dart';

class InternshipJob extends StatefulWidget {
  const InternshipJob({Key? key}) : super(key: key);

  @override
  _InternshipJobsListState createState() => _InternshipJobsListState();
}

class _InternshipJobsListState extends State<InternshipJob> {
  late Future<List<Job>> jobsFuture;

  @override
  void initState() {
    super.initState();
    jobsFuture = Job.allJobs();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 25, horizontal: 25),
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
            return const Center(
              child: Text(
                'No Jobs Available',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            );
          }

          final jobs = snapshot.data!;
          return ListView.separated(
            scrollDirection: Axis.vertical,
            itemBuilder: (context, index) => GestureDetector(
              onTap: () {
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
                      child: JobDetail(
                        jobs[index],
                        scrollController: scrollController,
                      ),
                    ),
                  ),
                );
              },
              child: Container(
                height: MediaQuery.of(context).size.height * 0.2,
                margin: const EdgeInsets.only(bottom: 15),
                child: JobItem(jobs[index],
                showTime: true,),
              ),
            ),
            separatorBuilder: (_, index) => const SizedBox(height: 15),
            itemCount: jobs.length,
          );
        },
      ),
    );
  }
}