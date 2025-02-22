import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:app_settings/app_settings.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:qiu_internar/home/mainscreen.dart';
import 'get_service_key.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class NotificationService {
  final FirebaseMessaging messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  NotificationService() {
    _initializeNotifications(); // 🔥 Ensure initialization runs
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings androidInitSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    final InitializationSettings initSettings = InitializationSettings(
      android: androidInitSettings,
    );

    await _flutterLocalNotificationsPlugin.initialize(initSettings);
    print('✅ Notifications initialized successfully.');
  }



  // Request notification permission
  Future<bool> requestNotificationPermission() async {
    try {
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        announcement: true,
        badge: true,
        carPlay: true,
        criticalAlert: true,
        provisional: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('User granted permission');
        return true;
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        print('User granted provisional permission');
        return true;
      } else {
        Get.snackbar(
          'Notification permission denied',
          "Please allow notifications to receive updates.",
          snackPosition: SnackPosition.BOTTOM,
        );

        await Future.delayed(const Duration(seconds: 2));
        await AppSettings.openAppSettings(type: AppSettingsType.notification);
        return false;
      }
    } catch (e) {
      print('Error requesting notification permission: $e');
      return false;
    }
  }

  // Get device token
  Future<String?> getDeviceToken() async {
    try {
      // Get current user
      final User? currentUser = _auth.currentUser;
      if (currentUser == null) return null;

      final String userEmail = currentUser.email ?? '';
      if (userEmail.isEmpty) return null;

      // Get the token
      final String? token = await messaging.getToken();
      if (token == null) return null;

      // Get student ID from email collection
      final emailDoc = await _firestore
          .collection('email')
          .doc(userEmail)
          .get();

      if (!emailDoc.exists) return null;

      // Get student ID
      final String studentId = emailDoc.data()?['studentId'] ?? '';
      if (studentId.isEmpty) return null;

      // Store token in allStudents collection
      await _firestore
          .collection('allStudents')
          .doc(studentId)
          .update({'deviceToken': token});

      if (kDebugMode) {
        print("Device token stored => $token");
      }
      return token;
    } catch (e) {
      if (kDebugMode) {
        print('Error in getDeviceToken: $e');
      }
      return null;
    }
  }

  // New method to refresh device token
  Future<void> refreshDeviceToken() async {
    try {
      // Delete existing token
      await messaging.deleteToken();

      // Get and store new token
      final String? newToken = await getDeviceToken();

      if (kDebugMode) {
        if (newToken != null) {
          print('Device token refreshed successfully');
        } else {
          print('Failed to refresh device token');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error refreshing device token: $e');
      }
    }
  }

  //init
  void initLocalNotification(
      BuildContext context, RemoteMessage message) async{
    var androidInitSetting =
      const AndroidInitializationSettings("@mipmap/ic_launcher");
    var initialaizationSetting = InitializationSettings(
      android: androidInitSetting,
    );

    await _flutterLocalNotificationsPlugin.initialize(
        initialaizationSetting,
        onDidReceiveNotificationResponse: (payload) {
          handleMessage(context, message);
        },
    );
  }

  //firebase init
 void firebaseInit(BuildContext context){
   FirebaseMessaging.onMessage.listen(
         (message) {
       RemoteNotification? notification = message.notification;
       if (notification != null && Platform.isAndroid) {
         showNotification(message);
       }
     },
   );
 }

 //Function to show notificaiton
  Future<void> showNotification(RemoteMessage message) async {
    AndroidNotificationChannel channel = AndroidNotificationChannel(
        message.notification!.android!.channelId.toString(),
        message.notification!.android!.channelId.toString(),
      importance: Importance.high,
      showBadge:true,
      playSound: true,
    );

    //android setting
    AndroidNotificationDetails androidNotificationDetails = AndroidNotificationDetails(
        channel.id.toString(),
      channel.name.toString(),
      channelDescription: "Channel Description",
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      sound: channel.sound,
    );

    NotificationDetails notificationDetails = NotificationDetails(
      android: androidNotificationDetails,
    );

    //show notification
    Future.delayed(Duration.zero,
        (){
      _flutterLocalNotificationsPlugin.show(
          0,
          message.notification!.title.toString(),
          message.notification!.body.toString(),
          notificationDetails);
        },
    );
  }

 //background and terminated
  Future<void> setupInteractMessage(BuildContext context) async{

    //background
    FirebaseMessaging.onMessageOpenedApp.listen(
            (message){
              handleMessage(context, message);
            },
    );
    //terminated state
    FirebaseMessaging.instance.getInitialMessage().then(
            (RemoteMessage? message){
              if(message != null && message.data.isNotEmpty){
                handleMessage(context, message);
              }
            },
    );
  }

  //handle message
  Future<void> handleMessage(BuildContext context, RemoteMessage message) async {

    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MainScreen(),
      ),
    );
  }

  // New method to initialize all notification related services
  Future<void> initializeNotificationServices(BuildContext context) async {
    // Request permission
    final bool hasPermission = await requestNotificationPermission();

    if (hasPermission) {
      // Get and store token
      await getDeviceToken();

      // Refresh token
      await refreshDeviceToken();

      // Setup message handling
      await setupInteractMessage(context);
    }
  }

  Future<bool> sendOfferNotification({
    required String employerToken,
    required String studentName,
    required String jobTitle,
    required String companyName,
    required String employerId,
    required String type, // 'declined', 'accepted', or 'withdrawn'
  }) async {
    try {
      if (kDebugMode) {
        print('Attempting to send offer notification to employer');
        print('Employer FCM token: $employerToken');
        print('Student name: $studentName');
        print('Job title: $jobTitle');
        print('Notification type: $type');
      }

      if (employerToken.isEmpty) {
        print('❌ Empty employer token provided');
        return false;
      }

      GetServerKey getServerKey = GetServerKey();
      String accessToken = await getServerKey.getServerKeyToken();

      final String fcmUrl = 'https://fcm.googleapis.com/v1/projects/myproject-9638b/messages:send';

      // Determine notification content based on type
      String title = 'Application Status Update';
      String body;

      switch (type) {
        case 'declined':
          title = 'Offer Decision Update';
          body = '$studentName has declined your offer for $jobTitle position at $companyName';
          break;
        case 'accepted':
          title = 'Offer Decision Update';
          body = '$studentName has accepted your offer for $jobTitle position at $companyName';
          break;
        case 'withdrawn':
          title = 'Application Withdrawn';
          body = '$studentName has withdrawn the application for $jobTitle position at $companyName';
          break;
        default:
          body = '$studentName has updated the application status for $jobTitle position at $companyName';
      }

      final Map<String, dynamic> notification = {
        'message': {
          'token': employerToken,
          'notification': {
            'title': title,
            'body': body
          },
          'data': {
            'type': 'offer_$type',
            'studentName': studentName,
            'jobTitle': jobTitle,
            'companyName': companyName,
            'click_action': 'FLUTTER_NOTIFICATION_CLICK',
            'timestamp': DateTime.now().toIso8601String(),
          }
        }
      };

      if (kDebugMode) {
        print('Notification payload: ${jsonEncode(notification)}');
      }

      final response = await http.post(
        Uri.parse(fcmUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(notification),
      );

      if (response.statusCode == 200) {
        if (kDebugMode) {
          print('✅ Notification sent successfully');
          print('Response: ${response.body}');
        }

        // Store notification in Firestore for tracking
        await _firestore
            .collection('sentNotifications')
            .doc(employerId)
            .collection('notifications')
            .add({
          'studentName': studentName,
          'jobTitle': jobTitle,
          'companyName': companyName,
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'sent',
          'type': 'offer_$type',
          'response': response.body,
          'read': false,
          'deleted': false,
        });

        return true;
      } else {
        if (kDebugMode) {
          print('❌ Failed to send notification');
          print('Status code: ${response.statusCode}');
          print('Response body: ${response.body}');
        }

        // Store failed notification attempt
        await _firestore
            .collection('sentNotifications')
            .doc(employerId)
            .collection('notifications')
            .add({
          'studentName': studentName,
          'jobTitle': jobTitle,
          'companyName': companyName,
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'failed',
          'type': 'offer_$type',
          'error': '${response.statusCode}: ${response.body}',
        });

        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error sending notification: $e');
      }

      // Store error in Firestore
      await _firestore
          .collection('sentNotifications')
          .doc(employerId)
          .collection('notifications')
          .add({
        'studentName': studentName,
        'jobTitle': jobTitle,
        'companyName': companyName,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'error',
        'type': 'offer_$type',
        'error': e.toString(),
      });

      return false;
    }
  }

  Future<bool> sendEmployerNotification({
    required String employerToken,
    required String studentName,
    required String jobTitle,
    required String companyName,
    required String employerId,
  }) async {
    try {
      if (kDebugMode) {
        print('Attempting to send notification to employer');
        print('Employer token: $employerToken');
        print('Student name: $studentName');
        print('Job title: $jobTitle');
      }

      GetServerKey getServerKey = GetServerKey();
      String accessToken = await getServerKey.getServerKeyToken();

      final String fcmUrl = 'https://fcm.googleapis.com/v1/projects/myproject-9638b/messages:send';

      final Map<String, dynamic> notification = {
        'message': {
          'token': employerToken,
          'notification': {
            'title': 'New Job Application',
            'body': '$studentName has applied to $jobTitle at $companyName'
          },
          'data': {
            'type': 'job_application',
            'studentName': studentName,
            'jobTitle': jobTitle,
            'companyName': companyName,
            'click_action': 'FLUTTER_NOTIFICATION_CLICK',
            'timestamp': DateTime.now().toIso8601String(),
          }
        }
      };

      if (kDebugMode) {
        print('Notification payload: ${jsonEncode(notification)}');
      }

      final response = await http.post(
        Uri.parse(fcmUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode(notification),
      );

      if (response.statusCode == 200) {
        if (kDebugMode) {
          print('✅ Notification sent successfully');
          print('Response: ${response.body}');
        }

        // Store notification in Firestore for tracking
        await _firestore
            .collection('sentNotifications')
            .doc(employerId)
            .collection('notifications')
            .add({
          'studentName': studentName,
          'jobTitle': jobTitle,
          'companyName': companyName,
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'sent',
          'response': response.body,
          'read': false,
          'deleted': false,
        });

        return true;
      } else {
        if (kDebugMode) {
          print('❌ Failed to send notification');
          print('Status code: ${response.statusCode}');
          print('Response body: ${response.body}');
        }

        // Store failed notification attempt
        await _firestore
            .collection('sentNotifications')
            .doc(employerId)
            .collection('notifications')
            .add({
          'studentName': studentName,
          'jobTitle': jobTitle,
          'companyName': companyName,
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'failed',
          'error': '${response.statusCode}: ${response.body}',
        });

        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error sending notification: $e');
      }

      // Store error in Firestore
      await _firestore
          .collection('sentNotifications')
          .doc(employerId)
          .collection('notifications')
          .add({
        'studentName': studentName,
        'jobTitle': jobTitle,
        'companyName': companyName,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'error',
        'error': e.toString(),
      });

      return false;
    }
  }
}
