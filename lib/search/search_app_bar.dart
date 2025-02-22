import 'package:flutter/material.dart';

class SearchAppBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        FocusScope.of(context).unfocus(); // Dismiss keyboard
        await Future.delayed(Duration(milliseconds: 100)); // Wait for the keyboard to dismiss
        return true; // Allow navigation
      },
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top,
          left: 8,
          right: 25,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            BackButton(
              color: Colors.black, // Set the color of the icon
              onPressed: () async {
                FocusScope.of(context).unfocus(); // Dismiss keyboard
                await Future.delayed(Duration(milliseconds: 100)); // Wait for the keyboard to dismiss
                Navigator.of(context).pop(); // Navigate back
              },
            ),
          ],
        ),
      ),
    );
  }
}
