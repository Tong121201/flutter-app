import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum ApplicationStatus {
  pending,
  shortlisted,
  approved,
  accepted,
  declined,
  rejected,
  withdrawn
}

class Module {
  // Basic application details - Always present
  final String applicationId;
  final String jobId;
  final DateTime appliedAt;
  final String company;
  final ApplicationStatus status;
  final DateTime? updateAt;

  // Student details - Always present
  final String studentEmail;
  final String studentId;
  final String studentName;
  final String studentPhone;

  // Document URLs - Always present
  final String resumeUrl;
  final String placementLetterUrl;

  // Read status - Optional, present after employer reviews
  final DateTime? resumeRead;
  final DateTime? placementLetterRead;

  // Interview details - Optional, present if shortlisted
  final InterviewDetails? interviewDetails;

  // Offer details - Optional, present if approved
  final OfferDetails? offerDetails;

  // Rejection details - Optional, present if rejected
  final RejectionDetails? rejectionDetails;

  // New timestamp fields for status changes
  final DateTime? acceptedAt;
  final DateTime? declinedAt;
  final DateTime? withdrawnAt;

  Module({
    required this.applicationId,
    required this.jobId,
    required this.appliedAt,
    required this.company,
    required this.status,
    required this.studentEmail,
    required this.studentId,
    required this.studentName,
    required this.studentPhone,
    required this.resumeUrl,
    required this.placementLetterUrl,
    this.updateAt,
    this.resumeRead,
    this.placementLetterRead,
    this.interviewDetails,
    this.offerDetails,
    this.rejectionDetails,
    this.acceptedAt,
    this.declinedAt,
    this.withdrawnAt,
  });

  // Factory constructor to create Module from Firestore document
  factory Module.fromFirestore(Map<String, dynamic> data) {
    DateTime parseDate(dynamic date) {
      if (date == null) return DateTime.now();
      if (date is Timestamp) {
        // Convert Timestamp to local DateTime
        return date.toDate().toLocal();
      }
      if (date is String) {
        // Parse string to DateTime and convert to local
        return DateTime.parse(date).toLocal();
      }
      return DateTime.now();
    }

    // Updated helper function for optional dates
    DateTime? parseOptionalDate(dynamic date) {
      if (date == null) return null;
      if (date is Timestamp) {
        return date.toDate().toLocal();
      }
      if (date is String) {
        return DateTime.parse(date).toLocal();
      }
      return null;
    }

    // Convert string status to enum
    ApplicationStatus getStatus(String? statusStr) {
      switch (statusStr?.toLowerCase()) {
        case 'shortlisted':
          return ApplicationStatus.shortlisted;
        case 'approved':
          return ApplicationStatus.approved;
        case 'rejected':
          return ApplicationStatus.rejected;
        case 'accepted':
          return ApplicationStatus.accepted;
        case 'declined':
          return ApplicationStatus.declined;
        case 'withdrawn':
          return ApplicationStatus.withdrawn;
        default:
          return ApplicationStatus.pending;
      }
    }

    return Module(
      applicationId: data['applicationId'] ?? '',
      jobId: data['jobId'] ?? '',
      appliedAt: parseDate(data['appliedAt']),
      company: data['company'] ?? '',
      status: getStatus(data['status']),
      studentEmail: data['studentEmail'] ?? '',
      studentId: data['studentId'] ?? '',
      studentName: data['studentName'] ?? '',
      studentPhone: data['studentPhone'] ?? '',
      resumeUrl: data['resumeUrl'] ?? '',
      updateAt: parseOptionalDate(data['updatedAt']),
      placementLetterUrl: data['placementLetterUrl'] ?? '',
      resumeRead: parseOptionalDate(data['resumeRead']),
      placementLetterRead: parseOptionalDate(data['placementLetterRead']),
      interviewDetails: data['interviewDetails'] != null
          ? InterviewDetails.fromFirestore(data['interviewDetails'])
          : null,
      offerDetails: data['offerDetails'] != null
          ? OfferDetails.fromFirestore(data['offerDetails'])
          : null,
      rejectionDetails: data['rejectionDetails'] != null
          ? RejectionDetails.fromFirestore(data['rejectionDetails'])
          : null,
      acceptedAt: parseOptionalDate(data['acceptedAt']),
      declinedAt: parseOptionalDate(data['declinedAt']),
      withdrawnAt: parseOptionalDate(data['withdrawnAt']),
    );
  }

  // Helper methods to check status
  bool get isShortlisted => status == ApplicationStatus.shortlisted;
  bool get isApproved => status == ApplicationStatus.approved;
  bool get isRejected => status == ApplicationStatus.rejected;
  bool get isPending => status == ApplicationStatus.pending;
  bool get isAccepted => status == ApplicationStatus.accepted;
  bool get isDeclined => status == ApplicationStatus.declined;
  bool get isWithdrawn => status == ApplicationStatus.withdrawn;

  // Helper method to check if documents have been read
  bool get hasBeenReviewed => resumeRead != null && placementLetterRead != null;
  bool get isResumeRead => resumeRead != null;
  bool get isPlacementLetterRead => placementLetterRead != null;
  DateTime? get resumeReadAt => resumeRead;
  DateTime? get placementLetterReadAt => placementLetterRead;
}

class InterviewDetails {
  final String location;
  final String notes;
  final String date;      // Interview date
  final String time;      // Interview time
  final DateTime scheduledAt;  // When employer scheduled the interview
  final String type;

  InterviewDetails({
    required this.location,
    required this.notes,
    required this.date,
    required this.time,
    required this.scheduledAt,
    required this.type,
  });

  factory InterviewDetails.fromFirestore(Map<String, dynamic> data) {
    DateTime parseDate(dynamic date) {
      if (date == null) return DateTime.now();

      // Handle Timestamp objects
      if (date is Timestamp) return date.toDate();

      // Handle String representations
      if (date is String) {
        // Try parsing as complete ISO date
        try {
          return DateTime.parse(date);
        } catch (e) {
          // If it's just a time (HH:mm), combine with today's date
          if (RegExp(r'^\d{1,2}:\d{2}$').hasMatch(date)) {
            final List<String> timeParts = date.split(':');
            final now = DateTime.now();
            return DateTime(
              now.year,
              now.month,
              now.day,
              int.parse(timeParts[0]),
              int.parse(timeParts[1]),
            );
          }

          // If parsing fails, return current time
          return DateTime.now();
        }
      }

      return DateTime.now();
    }

    return InterviewDetails(
      location: data['location'] ?? '',
      notes: data['notes'] ?? '',
      date: data['date'] ?? '',
      time: data['time'] ?? '',
      scheduledAt: data['scheduledAt'] is Timestamp
          ? (data['scheduledAt'] as Timestamp).toDate()
          : parseDate(data['scheduledAt']),
      type: data['type'] ?? '',
    );
  }
}

class OfferDetails {
  final DateTime offerDate;
  final DateTime offeredAt;
  final String notes;
  final String offerLetterPath;

  OfferDetails({
    required this.offerDate,
    required this.notes,
    required this.offerLetterPath,
    required this.offeredAt,
  });

  factory OfferDetails.fromFirestore(Map<String, dynamic> data) {
    DateTime parseDate(dynamic date) {
      if (date == null) return DateTime.now();
      if (date is Timestamp) return date.toDate();
      if (date is String) return DateTime.parse(date);
      return DateTime.now();
    }

    return OfferDetails(
      offerDate: parseDate(data['offerDate']),
      notes: data['notes'] ?? '',
      offerLetterPath: data['offerLetterUrl'] ?? '',
      offeredAt: parseDate(data['offeredAt']), // Fixed here
    );
  }
}


class RejectionDetails {
  final String feedback;
  final String improvementSuggestions;
  final String reason;
  final DateTime rejectedAt;

  RejectionDetails({
    required this.feedback,
    required this.improvementSuggestions,
    required this.reason,
    required this.rejectedAt,
  });

  factory RejectionDetails.fromFirestore(Map<String, dynamic> data) {
    DateTime parseDate(dynamic date) {
      if (date == null) return DateTime.now();
      if (date is Timestamp) return date.toDate();
      if (date is String) return DateTime.parse(date);
      return DateTime.now();
    }

    return RejectionDetails(
      feedback: data['feedback'] ?? '',
      improvementSuggestions: data['improvementSuggestions'] ?? '',
      reason: data['reason'] ?? '',
      rejectedAt: parseDate(data['rejectedAt']),
    );
  }
}