import 'package:flutter/material.dart';
import 'package:qiu_internar/service/notification_service.dart';
import '../internship/internship_page.dart';
import '../widgets/bottom_navigation_bar.dart';
import 'Widgets/HomeAppBar.dart';
import 'Widgets/search_card.dart';
import 'Widgets/tag_list.dart';
import 'package:qiu_internar/application_page.dart';
import 'package:qiu_internar/notification_page.dart';
import 'Widgets/job_list.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  int selectedTagIndex = 0;
  NotificationService notificationService = NotificationService();

  @override
  void initState(){
    super.initState();
    notificationService.requestNotificationPermission();
    notificationService.getDeviceToken();
    notificationService.firebaseInit(context);
    notificationService.setupInteractMessage(context);
  }

  void handleTagSelection(int index) {
    setState(() {
      selectedTagIndex = index;
    });
  }

  // Your existing widgets from MainScreen
  Widget _buildHomeContent() {
    return Stack(
      children: [
        Row(
          children: [
            Expanded(
              flex: 2,
              child: Container(
                color: Colors.white, // Pure white background
              ),
            ),
            Expanded(
              flex: 1,
              child: Container(
                color: Colors.white, // Pure white background
              ),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HomeAppBar(),
            const SearchCard(),
            TagList(onTagSelected: handleTagSelection,),
            Joblist(selectedTagIndex: selectedTagIndex,),
          ],
        ),
      ],
    );
  }

  Widget _getSelectedScreen() {
    switch (_selectedIndex) {
      case 0:
        return _buildHomeContent();
      case 1:
        return InternshipPage();
      case 2:
        return  ApplicationPage();
      case 3:
        return NotificationPage();
      default:
        return _buildHomeContent();
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _getSelectedScreen(),
      bottomNavigationBar: Theme(
        data: ThemeData(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: CustomBottomNavigationBar(
          selectedIndex: _selectedIndex,
          onItemTapped: _onItemTapped,
        ),
      ),
    );
  }
}