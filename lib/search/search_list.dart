import 'package:flutter/material.dart';
import '../home/Widgets/job_detail.dart';
import '../home/Widgets/job_item.dart';
import '../models/job.dart';

class SearchList extends StatefulWidget {
  final List<Job> searchResults;
  final bool hasSearched;

  const SearchList({
    Key? key,
    required this.searchResults,
    required this.hasSearched,
  }) : super(key: key);

  @override
  _SearchListState createState() => _SearchListState();
}

class _SearchListState extends State<SearchList> {
  @override
  Widget build(BuildContext context) {
    if (!widget.hasSearched) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 25, horizontal: 25),
      child: widget.searchResults.isEmpty
          ? Center(
        child: Text(
          'No Result Found',
          style: TextStyle(
            fontSize: 18,
            color: Colors.grey,
          ),
        ),
      )
          : ListView.separated(
        scrollDirection: Axis.vertical,
        itemBuilder: (context, index) => GestureDetector(
          onTap: () => _showJobDetail(context, index),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.2,
            margin: const EdgeInsets.only(bottom: 15),
            child: JobItem(
              widget.searchResults[index],
              showTime: true,
            ),
          ),
        ),
        separatorBuilder: (_, index) => const SizedBox(height: 15),
        itemCount: widget.searchResults.length,
      ),
    );
  }

  void _showJobDetail(BuildContext context, int index) {
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
            widget.searchResults[index],
            scrollController: scrollController,
          ),
        ),
      ),
    );
  }
}