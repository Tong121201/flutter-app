import 'package:flutter/material.dart';
import 'package:qiu_internar/models/job.dart';
import 'package:qiu_internar/search/search_app_bar.dart';
import 'package:qiu_internar/search/search_input.dart';
import 'package:qiu_internar/search/search_list.dart';

import 'filter.dart';

class SearchPage extends StatefulWidget {
  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  List<Job> allJobs = [];
  List<Job> searchResults = [];
  bool isLoading = false;
  bool hasSearched = false;
  TextEditingController searchController = TextEditingController();
  SortOption currentSort = SortOption.titleAsc;

  Future<void> loadJobs(String query) async {
    setState(() => hasSearched = true);

    if (query.isEmpty) {
      setState(() {
        searchResults = [];
        isLoading = false;
      });
      return;
    }

    setState(() => isLoading = true);

    try {
      if (allJobs.isEmpty) {
        allJobs = await Job.allJobs();
      }

      final lowercaseQuery = query.toLowerCase();
      final results = allJobs.where((job) {
        final titleMatch = job.title.toLowerCase().contains(lowercaseQuery);
        final companyMatch = job.company.toLowerCase().contains(lowercaseQuery);
        final locationMatch = job.location.toLowerCase().contains(lowercaseQuery);
        final requirementsMatch = job.requirements.any(
              (requirement) => requirement.toLowerCase().contains(lowercaseQuery),
        );

        return titleMatch || companyMatch || locationMatch || requirementsMatch;
      }).toList();

      _sortResults(currentSort, results);

      setState(() {
        searchResults = results;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading jobs: $e');
      setState(() => isLoading = false);
    }
  }

  // Modified _sortResults to accept a list parameter
  void _sortResults(SortOption option, [List<Job>? jobsToSort]) {
    final jobs = jobsToSort ?? searchResults; // Use provided list or current searchResults

    setState(() {
      currentSort = option;
      switch (option) {
        case SortOption.titleAsc:
          jobs.sort((a, b) => a.title.compareTo(b.title));
          break;
        case SortOption.titleDesc:
          jobs.sort((a, b) => b.title.compareTo(a.title));
          break;
        case SortOption.companyAsc:
          jobs.sort((a, b) => a.company.compareTo(b.company));
          break;
        case SortOption.companyDesc:
          jobs.sort((a, b) => b.company.compareTo(a.company));
          break;
        case SortOption.dateAsc:
          jobs.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          break;
        case SortOption.dateDesc:
          jobs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          break;
      }

      if (jobsToSort == null) {
        searchResults = List.from(jobs); // Update searchResults if we're sorting the existing list
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () async {
      setState(() {
        hasSearched = false;
        searchResults = [];
        searchController.clear();
      });
      return true;
    },
    child: Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Container(color: Colors.white),
              ),
              Expanded(
                flex: 1,
                child: Container(color: Colors.white),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SearchAppBar(),
              SearchInput(
                controller: searchController,
                onChanged: loadJobs,
                onSortSelected: _sortResults,
                currentSort: currentSort,
              ),
              if (isLoading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                Expanded(
                  child: SearchList(
                    searchResults: searchResults,
                    hasSearched: hasSearched,
                  ),
                ),
            ],
          ),
        ],
      ),
    ),
    );
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }
}