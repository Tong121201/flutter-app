import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qiu_internar/internship/job_container.dart';
import 'package:qiu_internar/search/search.dart';
import '../home/Widgets/job_detail.dart';
import '../models/job.dart';

class InternshipPage extends StatefulWidget {
  @override
  _InternshipPageState createState() => _InternshipPageState();
}

class _InternshipPageState extends State<InternshipPage> {
  late Future<List<Job>> recommendedJobsFuture;
  late Future<List<Job>> allJobsFuture;
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToTop = false;

  @override
  void initState() {
    super.initState();
    recommendedJobsFuture = Job.getRecommendedJobs();
    allJobsFuture = Job.allJobs();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.offset >= 400) {
      setState(() => _showScrollToTop = true);
    } else {
      setState(() => _showScrollToTop = false);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
        ),
        child: SafeArea(
          child: Stack(
            children: [
              FutureBuilder<List<Job>>(
                future: recommendedJobsFuture,
                builder: (context, recommendedSnapshot) {
                  if (recommendedSnapshot.connectionState == ConnectionState.waiting) {
                    return CustomScrollView(
                      controller: _scrollController,
                      slivers: [
                        _buildAppBar(),
                        const SliverFillRemaining(
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      ],
                    );
                  }

                  final hasRecommendedJobs = recommendedSnapshot.hasData &&
                      recommendedSnapshot.data!.isNotEmpty;

                  return CustomScrollView(
                    controller: _scrollController,
                    slivers: [
                      _buildAppBar(),
                      if (hasRecommendedJobs) _buildRecommendedJobs(recommendedSnapshot.data!),
                      _buildJobsList(hasRecommendedJobs ? recommendedSnapshot.data! : []),
                    ],
                  );
                },
              ),
              if (_showScrollToTop) _buildScrollToTopButton(),
              _buildSearchButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      floating: true,
      backgroundColor: Colors.white,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 4,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Find Your Dream',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Internship',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecommendedJobs(List<Job> recommendedJobs) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
              (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  'Recommended for You',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).primaryColor,
                    width: 2, // Retain the blue outline from Code 1
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Stack(
                  children: [
                    JobContainer(
                      recommendedJobs[index - 1],
                      showTime: true,
                      onDetailsTap: () => _showJobDetails(
                        context,
                        recommendedJobs[index - 1],
                      ),
                    ),
                    // Updated Recommended Badge with border radius
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(10), // Match the top-right design
                            bottomLeft: Radius.circular(16), // Add symmetry
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              spreadRadius: 1,
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: const Text(
                          'Recommended',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
              },
          childCount: recommendedJobs.length + 1,
        ),
      ),
    );
  }


  Widget _buildJobsList(List<Job> recommendedJobs) {
    return SliverPadding(
      padding: const EdgeInsets.all(20),
      sliver: FutureBuilder<List<Job>>(
        future: allJobsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SliverToBoxAdapter(
              child: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasError) {
            return SliverFillRemaining(
              child: Center(child: Text('Error: ${snapshot.error}')),
            );
          }

          final allJobs = snapshot.data ?? [];
          if (allJobs.isEmpty) {
            return const SliverFillRemaining(
              child: Center(
                child: Text(
                  'No Jobs Available',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            );
          }

          final otherJobs = allJobs.where((job) =>
          !recommendedJobs.any((recJob) => recJob.id == job.id)
          ).toList();

          return SliverList(
            delegate: SliverChildBuilderDelegate(
                  (context, index) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: JobContainer(
                  otherJobs[index],
                  showTime: true,
                  onDetailsTap: () => _showJobDetails(
                    context,
                    otherJobs[index],
                  ),
                ),
              ),
              childCount: otherJobs.length,
            ),
          );
        },
      ),
    );
  }

  void _showJobDetails(BuildContext context, Job job) {
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
            top: Radius.circular(20), // Changed from 20 to 8 to match your design
          ),
          child: JobDetail(
            job,
            scrollController: scrollController,
          ),
        ),
      ),
    );
  }

  Widget _buildScrollToTopButton() {
    return Positioned(
      right: 20,
      bottom: 90,
      child: FloatingActionButton(
        mini: true,
        backgroundColor: Colors.white,
        child: const Icon(Icons.arrow_upward, color: Colors.black),
        onPressed: () {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        },
      ),
    );
  }

  Widget _buildSearchButton() {
    return Positioned(
      right: 20,
      bottom: 20,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 4,
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SearchPage()),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Icon(Icons.search, color: Colors.grey[800]),
            ),
          ),
        ),
      ),
    );
  }
}