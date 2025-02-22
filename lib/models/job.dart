import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Job {
  final String id;
  final String company;
  final String logoUrl;
  bool isStarred;
  final String title;
  final String location;
  final String time = "Internship";
  final List<String> requirements;
  final int allowance;
  final String description;
  final String email;
  final int hiredPax;
  final String city;
  final String no;
  final String postcode;
  final String road;
  final String state;
  final String phone;
  final String postedBy;
  final String postedDate;
  final String preferredQualification;
  final String status;
  final String location2;
  final DateTime createdAt;
  final List<CompanyEnvironment> companyEnvironments;


  // Enhanced skill levels with more granular proficiency
  static const Map<String, Map<String, double>> SKILL_PROFICIENCY = {
    'beginner': {
      'novice': 0.2,
      'basic': 0.3,
      'developing': 0.4
    },
    'intermediate': {
      'competent': 0.5,
      'proficient': 0.6,
      'skilled': 0.7
    },
    'advanced': {
      'expert': 0.8,
      'master': 0.9,
      'specialist': 1.0
    }
  };

  // Enhanced thresholds for multi-tier matching
  static const double STRICT_MATCH_THRESHOLD = 30.0;
  static const double MEDIUM_MATCH_THRESHOLD = 20.0;
  static const double LOOSE_MATCH_THRESHOLD = 10.0;

  String get daysAgo {
    final difference = DateTime.now().difference(createdAt);
    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return 'Just now';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 30) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '${months}mo ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '${years}y ago';
    }
  }

  Job({
    required this.id,
    required this.company,
    required this.logoUrl,
    this.isStarred = false,
    required this.title,
    required this.location,
    required this.requirements,
    required this.allowance,
    required this.description,
    required this.email,
    required this.hiredPax,
    required this.city,
    required this.no,
    required this.postcode,
    required this.road,
    required this.state,
    required this.phone,
    required this.postedBy,
    required this.postedDate,
    required this.preferredQualification,
    required this.status,
    required this.location2,
    required this.createdAt,
    this.companyEnvironments = const [],
  });

  // Get current user's skills from Firestore
  static Future<List<String>> _getCurrentUserSkills() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user?.email == null) return [];

      final emailDoc = await FirebaseFirestore.instance
          .collection('email')
          .where('email', isEqualTo: user!.email)
          .get();

      if (emailDoc.docs.isEmpty) return [];

      final studentId = emailDoc.docs.first['studentId'];
      final studentDoc = await FirebaseFirestore.instance
          .collection('allStudents')
          .doc(studentId)
          .get();

      if (!studentDoc.exists) return [];

      final skills = List<String>.from(studentDoc.data()?['skills'] ?? []);
      return skills;
    } catch (e) {
      print('Error getting user skills: $e');
      return [];
    }
  }

  static (String level, String proficiency, String skill) _extractSkillProficiency(
      String skillText,
      {bool isRequirement = false}
      ) {
    skillText = skillText.toLowerCase();

    // Check for explicit proficiency levels
    for (var level in SKILL_PROFICIENCY.keys) {
      for (var proficiency in SKILL_PROFICIENCY[level]!.keys) {
        if (skillText.contains(proficiency)) {
          return (
          level,
          proficiency,
          skillText.replaceAll(proficiency, '').replaceAll(level, '').trim()
          );
        }
      }

      if (skillText.contains(level)) {
        var defaultProficiency = SKILL_PROFICIENCY[level]!.keys.elementAt(1);
        return (
        level,
        defaultProficiency,
        skillText.replaceAll(level, '').trim()
        );
      }
    }

    // For requirements without proficiency, use intermediate
    return ('intermediate', 'competent', skillText);
  }

  // Enhanced proficiency score calculation
  static double _calculateProficiencyScore(
      String requiredLevel,
      String requiredProf,
      String userLevel,
      String userProf
      ) {
    double reqWeight = SKILL_PROFICIENCY[requiredLevel]?[requiredProf] ??
        SKILL_PROFICIENCY['intermediate']!['competent']!;

    double userWeight = SKILL_PROFICIENCY[userLevel]?[userProf] ??
        SKILL_PROFICIENCY['intermediate']!['competent']!;

    // If user's proficiency meets or exceeds required level
    if (userWeight >= reqWeight) {
      // Give bonus for significantly exceeding requirements (max 10% bonus)
      double bonus = min((userWeight - reqWeight) / 2, 0.1);
      return 1.0 + bonus;
    }

    // If user's level is lower, calculate partial credit with diminishing returns
    double ratio = userWeight / reqWeight;
    // Apply diminishing returns curve
    return pow(ratio, 1.5).toDouble();
  }

  // Handle requirements with parentheses
  static double _handleParenthesesRequirement(
      String cleanReq,
      String cleanSkill,
      String reqLevel,
      String reqProf,
      String skillLevel,
      String skillProf
      ) {
    try {
      // Extract main term and all parenthetical content
      List<String> allTerms = [];
      String mainTerm = '';

      if (cleanReq.contains('(')) {
        mainTerm = cleanReq.substring(0, cleanReq.indexOf('(')).trim();
        allTerms.add(mainTerm);

        // Extract all parenthetical content
        RegExp parenthesesPattern = RegExp(r'\((.*?)\)');
        var matches = parenthesesPattern.allMatches(cleanReq);

        for (var match in matches) {
          String content = match.group(1) ?? '';
          allTerms.addAll(content.split(',').map((e) => e.trim()));
        }
      } else {
        mainTerm = cleanReq;
        allTerms.add(mainTerm);
      }

      // Handle user skill with parentheses
      List<String> userTerms = [];
      if (cleanSkill.contains('(')) {
        String userMainTerm = cleanSkill.substring(0, cleanSkill.indexOf('(')).trim();
        userTerms.add(userMainTerm);

        RegExp parenthesesPattern = RegExp(r'\((.*?)\)');
        var matches = parenthesesPattern.allMatches(cleanSkill);

        for (var match in matches) {
          String content = match.group(1) ?? '';
          userTerms.addAll(content.split(',').map((e) => e.trim()));
        }
      } else {
        userTerms.add(cleanSkill);
      }

      // Calculate best match score
      double bestScore = 0.0;

      // Check main term matches first
      if (_isSubstringMatch(mainTerm, userTerms.first)) {
        bestScore = max(bestScore,
            0.9 * _calculateProficiencyScore(reqLevel, reqProf, skillLevel, skillProf));
      }

      // Check all term combinations
      for (var reqTerm in allTerms) {
        for (var userTerm in userTerms) {
          if (_isSubstringMatch(reqTerm, userTerm)) {
            double score = 0.85 * _calculateProficiencyScore(
                reqLevel, reqProf, skillLevel, skillProf);
            bestScore = max(bestScore, score);
          }

          // Calculate word overlap score as fallback
          double overlapScore = _calculateWordOverlapScore(reqTerm, userTerm) *
              _calculateProficiencyScore(reqLevel, reqProf, skillLevel, skillProf);
          bestScore = max(bestScore, overlapScore * 0.7); // 70% weight for overlap matches
        }
      }

      return bestScore;
    } catch (e) {
      print('Error in _handleParenthesesRequirement: $e');
      return 0.0;
    }
  }

  // Handle comma-separated requirements
  static double _handleCommaRequirement(
      String cleanReq,
      String cleanSkill,
      String reqLevel,
      String reqProf,
      String skillLevel,
      String skillProf
      ) {
    var reqSkills = cleanReq.split(',').map((s) => s.trim()).toList();
    double bestMatch = 0.0;

    for (var reqSkill in reqSkills) {
      if (reqSkill == cleanSkill) {
        bestMatch = 1.0;
        break;
      } else if (_isSubstringMatch(reqSkill, cleanSkill)) {
        bestMatch = max(bestMatch, 0.8);
      }
    }

    return bestMatch * _calculateProficiencyScore(reqLevel, reqProf, skillLevel, skillProf);
  }

  // Updated substring matching with more intelligent comparison
  static bool _isSubstringMatch(String term1, String term2) {
    // Normalize terms
    term1 = term1.toLowerCase().trim();
    term2 = term2.toLowerCase().trim();

    // Remove common words and punctuation
    final commonWords = ['using', 'with', 'and', 'or', 'in', 'for', 'the', 'a', 'an'];
    final punctuation = [',', '.', '/', '\\', '-'];

    for (var word in commonWords) {
      term1 = term1.replaceAll(RegExp('\\b$word\\b'), ' ');
      term2 = term2.replaceAll(RegExp('\\b$word\\b'), ' ');
    }

    for (var punct in punctuation) {
      term1 = term1.replaceAll(punct, ' ');
      term2 = term2.replaceAll(punct, ' ');
    }

    // Clean up extra spaces
    term1 = term1.replaceAll(RegExp(r'\s+'), ' ').trim();
    term2 = term2.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Exact match check
    if (term1 == term2) return true;

    // Split into words
    List<String> words1 = term1.split(' ').where((w) => w.isNotEmpty).toList();
    List<String> words2 = term2.split(' ').where((w) => w.isNotEmpty).toList();

    // Check if shorter term's words are contained in longer term
    var shorterWords = words1.length <= words2.length ? words1 : words2;
    var longerWords = words1.length > words2.length ? words1 : words2;

    return shorterWords.every((word) =>
        longerWords.any((w) => w.contains(word) || word.contains(w)));
  }

// Updated word overlap calculation
  static double _calculateWordOverlapScore(String term1, String term2) {
    // Normalize and split terms
    List<String> words1 = term1.toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();

    List<String> words2 = term2.toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();

    // Find matching words
    int matchCount = 0;
    for (var word1 in words1) {
      for (var word2 in words2) {
        if (word1.contains(word2) || word2.contains(word1)) {
          matchCount++;
          break;
        }
      }
    }

    // Calculate score based on coverage of both terms
    double score1 = matchCount / words1.length;
    double score2 = matchCount / words2.length;

    // Return average of both scores
    return (score1 + score2) / 2;
  }


  // Updated match score calculation with multi-tier approach
  static double _calculateMatchScore(List<String> studentSkills, List<String> jobRequirements) {
    if (studentSkills.isEmpty || jobRequirements.isEmpty) return 0.0;

    double strictScore = _calculateStrictMatchScore(studentSkills, jobRequirements);
    if (strictScore >= STRICT_MATCH_THRESHOLD) {
      return strictScore;
    }

    double mediumScore = _calculateMediumMatchScore(studentSkills, jobRequirements);
    if (mediumScore >= MEDIUM_MATCH_THRESHOLD) {
      return mediumScore;
    }

    return _calculateLooseMatchScore(studentSkills, jobRequirements);
  }

  // Strict matching calculation
  static double _calculateStrictMatchScore(List<String> studentSkills, List<String> jobRequirements) {
    Map<String, double> bestMatches = {};
    double totalWeight = 0.0;

    for (var requirement in jobRequirements) {
      double bestScore = 0.0;
      for (var skill in studentSkills) {
        double score = _calculateSimilarity(requirement, skill);
        bestScore = max(bestScore, score);
      }

      var (reqLevel, reqProf, _) = _extractSkillProficiency(requirement, isRequirement: true);
      double requirementWeight = SKILL_PROFICIENCY[reqLevel]?[reqProf] ?? 0.5;

      bestMatches[requirement] = bestScore * requirementWeight;
      totalWeight += requirementWeight;
    }

    return (bestMatches.values.reduce((a, b) => a + b) / totalWeight) * 100;
  }

  // Medium matching calculation
  static double _calculateMediumMatchScore(List<String> studentSkills, List<String> jobRequirements) {
    double totalScore = 0.0;
    int matchCount = 0;

    for (var requirement in jobRequirements) {
      for (var skill in studentSkills) {
        if (_findAnyMatch(requirement, skill)) {
          totalScore += 0.7;  // 70% score for medium matches
          matchCount++;
          break;
        }
      }
    }

    if (matchCount == 0) return 0.0;
    return (totalScore / jobRequirements.length) * 100;
  }

  // Loose matching calculation
  static double _calculateLooseMatchScore(List<String> studentSkills, List<String> jobRequirements) {
    String fullRequirements = jobRequirements.join(' ').toLowerCase();
    int matchCount = 0;

    for (var skill in studentSkills) {
      String cleanSkill = skill.toLowerCase();
      if (fullRequirements.contains(cleanSkill)) {
        matchCount++;
      }
    }

    if (matchCount == 0) return 0.0;
    return (matchCount / studentSkills.length) * 60;  // 60% maximum score for loose matches
  }

  // Helper method to find any kind of match
  static bool _findAnyMatch(String requirement, String skill) {
    requirement = requirement.toLowerCase();
    skill = skill.toLowerCase();

    // Check for parentheses
    if (requirement.contains('(') && requirement.contains(')')) {
      String mainTerm = requirement.substring(0, requirement.indexOf('(')).trim();
      String parenthesesContent = requirement
          .substring(requirement.indexOf('(') + 1, requirement.indexOf(')'))
          .trim();
      List<String> items = parenthesesContent.split(',').map((e) => e.trim()).toList();

      if (_isSubstringMatch(mainTerm, skill)) return true;
      return items.any((item) => _isSubstringMatch(item, skill));
    }

    // Check for comma-separated terms
    if (requirement.contains(',')) {
      List<String> terms = requirement.split(',').map((e) => e.trim()).toList();
      return terms.any((term) => _isSubstringMatch(term, skill));
    }

    return _isSubstringMatch(requirement, skill);
  }

  static double _calculateSimilarity(String requirement, String skill) {
    try {
      requirement = requirement.toLowerCase();
      skill = skill.toLowerCase();

      // Extract proficiency levels
      var (reqLevel, reqProf, cleanReq) = _extractSkillProficiency(requirement, isRequirement: true);
      var (skillLevel, skillProf, cleanSkill) = _extractSkillProficiency(skill);

      // Perfect match case
      if (cleanReq == cleanSkill) {
        return _calculateProficiencyScore(reqLevel, reqProf, skillLevel, skillProf);
      }

      // Handle parentheses in either requirement or skill
      if (cleanReq.contains('(') || cleanSkill.contains('(')) {
        return _handleParenthesesRequirement(
            cleanReq, cleanSkill, reqLevel, reqProf, skillLevel, skillProf);
      }

      // Handle comma-separated lists
      if (cleanReq.contains(',') || cleanSkill.contains(',')) {
        return _handleCommaRequirement(
            cleanReq, cleanSkill, reqLevel, reqProf, skillLevel, skillProf);
      }

      // Check for substring matches
      if (_isSubstringMatch(cleanReq, cleanSkill)) {
        return 0.8 * _calculateProficiencyScore(reqLevel, reqProf, skillLevel, skillProf);
      }

      // Calculate word overlap as fallback
      double overlapScore = _calculateWordOverlapScore(cleanReq, cleanSkill);
      return overlapScore * _calculateProficiencyScore(reqLevel, reqProf, skillLevel, skillProf);
    } catch (e) {
      print('Error in _calculateSimilarity: $e');
      return 0.0;
    }
  }


  static Future<List<Job>> getRecommendedJobs() async {
    try {
      final studentSkills = await _getCurrentUserSkills();
      if (studentSkills.isEmpty) return [];

      final availableJobs = await Job.allJobs();

      // Calculate match scores for all jobs
      List<MapEntry<Job, double>> scoredJobs = availableJobs.map((job) {
        double score = _calculateMatchScore(studentSkills, job.requirements);
        return MapEntry(job, score);
      }).toList();

      // Sort by match score
      scoredJobs.sort((a, b) => b.value.compareTo(a.value));

      // Group jobs by match quality
      List<Job> recommendedJobs = [];

      // Add strict matches first
      recommendedJobs.addAll(
          scoredJobs
              .where((entry) => entry.value >= STRICT_MATCH_THRESHOLD)
              .map((entry) => entry.key)
      );

      // Add medium matches if we need more recommendations
      if (recommendedJobs.length < 10) {
        recommendedJobs.addAll(
            scoredJobs
                .where((entry) =>
            entry.value >= MEDIUM_MATCH_THRESHOLD &&
                entry.value < STRICT_MATCH_THRESHOLD &&
                !recommendedJobs.contains(entry.key))
                .map((entry) => entry.key)
        );
      }

      // Add loose matches if we still need more recommendations
      if (recommendedJobs.length < 15) {
        recommendedJobs.addAll(
            scoredJobs
                .where((entry) =>
            entry.value >= LOOSE_MATCH_THRESHOLD &&
                entry.value < MEDIUM_MATCH_THRESHOLD &&
                !recommendedJobs.contains(entry.key))
                .map((entry) => entry.key)
        );
      }

      // Only return jobs that meet minimum recommendation threshold
      return recommendedJobs
          .where((job) => scoredJobs
          .firstWhere((entry) => entry.key == job)
          .value >= LOOSE_MATCH_THRESHOLD)
          .toList();
    } catch (e) {
      print('Error getting recommended jobs: $e');
      return [];
    }
  }

  static Future<Job> fromFirestore(Map<String, dynamic> data, String jobId) async {
    final addressData = data['location'] ?? {};
    final no = addressData['no'] ?? '';
    final road = addressData['road'] ?? '';
    final postcode = addressData['postcode'] ?? '';
    final city = addressData['city'] ?? '';
    final state = addressData['state'] ?? '';


    final location = [
      [no, road, postcode].where((e) => e.isNotEmpty).join(', '),
      [city, state].where((e) => e.isNotEmpty).join(', ')
    ].where((e) => e.isNotEmpty).join('\n');

    final location2 = [
      [no, road, postcode].where((e) => e.isNotEmpty).join(', '),
      [city, state].where((e) => e.isNotEmpty).join(', ')
    ].where((e) => e.isNotEmpty).join(', ');


    final postedDate = data['postedDate'] is Timestamp
        ? (data['postedDate'] as Timestamp).toDate().toString()
        : data['postedDate'] ?? '';

    // Convert Timestamp to DateTime for createdAt
    final DateTime createdAt = data['postedDate'] is Timestamp
        ? (data['postedDate'] as Timestamp).toDate()
        : DateTime.now();

    final employerData = await getEmployerData(data['postedBy'] ?? '');
    final companyName = employerData['company_name'] ?? '';
    final logoUrl = employerData['profilePicture'] ?? '';

    bool isStarred = await checkIfJobIsStarred(jobId);

    String preferredQualification = data['preferredQualification'] ?? '';
    preferredQualification = preferredQualification.toLowerCase() == 'diploma'
        ? 'Diploma'
        : preferredQualification.toLowerCase() == 'degree'
        ? 'Degree'
        : preferredQualification.toLowerCase() == 'diploma_or_degree'
        ? 'Diploma/Degree'
        : preferredQualification;

    // Parse company environments
    List<CompanyEnvironment> environments = [];
    if (data['companyEnvironments'] != null) {
      List<dynamic> envList = data['companyEnvironments'] as List<dynamic>;
      environments = envList.map((env) {
        return CompanyEnvironment(
          placeName: env['placeName'] ?? '',
          arLink: env['arLink'] ?? '',
          momentoLink: env['momentoLink'] ?? '',
        );
      }).toList();
    }

    return Job(
      id: jobId,
      company: companyName,
      logoUrl: logoUrl,
      isStarred: isStarred,
      title: data['title'] ?? '',
      location: location,
      requirements: List<String>.from(data['requirements'] ?? []),
      allowance: int.tryParse(data['allowance']?.toString() ?? '0') ?? 0,
      description: data['description'] ?? '',
      email: data['email'] ?? '',
      hiredPax: data['hiredPax'] ?? 0,
      city: city,
      no: no,
      postcode: postcode,
      road: road,
      state: state,
      phone: data['phone'] ?? '',
      postedBy: data['postedBy'] ?? '',
      postedDate: postedDate,
      preferredQualification: preferredQualification,
      status: data['status'] ?? '',
      location2: location2,
      createdAt: createdAt,
      companyEnvironments: environments,
    );

  }

  static Future<bool> checkIfJobIsStarred(String jobId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user?.email == null) {
        print("User email is null");
        return false;
      }

      final emailSnapshot = await FirebaseFirestore.instance
          .collection('email')
          .where('email', isEqualTo: user!.email)
          .get();

      if (emailSnapshot.docs.isEmpty) {
        print("No user found with this email");
        return false;
      }

      final studentId = emailSnapshot.docs.first['studentId'];
      final studentDoc = await FirebaseFirestore.instance
          .collection('allStudents')
          .doc(studentId)
          .get();

      if (!studentDoc.exists) {
        print("Student document does not exist");
        return false;
      }

      final data = studentDoc.data();
      if (data == null || !data.containsKey('starredJobs') || data['starredJobs'] == null) {
        print("No 'starredJobs' field in student document.");
        return false;
      }

      final List<dynamic> starredJobs = List.from(data['starredJobs'] ?? []);
      print("Starred Jobs: $starredJobs");

      return starredJobs.contains(jobId);
    } catch (e) {
      print("Error checking starred status: $e");
      return false;
    }
  }

  static Future<Map<String, dynamic>> getEmployerData(String employerId) async {
    try {
      final employerSnapshot = await FirebaseFirestore.instance
          .collection('employers')
          .doc(employerId)
          .get();

      if (employerSnapshot.exists) {
        return employerSnapshot.data() ?? {};
      }
      return {};
    } catch (e) {
      print("Error fetching employer data: $e");
      return {};
    }
  }

  static Future<List<Job>> getStarredJobs() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user?.email == null) return [];

      final emailSnapshot = await FirebaseFirestore.instance
          .collection('email')
          .where('email', isEqualTo: user!.email)
          .get();

      if (emailSnapshot.docs.isEmpty) return [];

      final studentId = emailSnapshot.docs.first['studentId'];
      final studentDoc = await FirebaseFirestore.instance
          .collection('allStudents')
          .doc(studentId)
          .get();

      if (!studentDoc.exists) return [];

      final data = studentDoc.data();
      if (data == null || !data.containsKey('starredJobs')) return [];

      final List<dynamic> starredJobIds = data['starredJobs'];
      if (starredJobIds.isEmpty) return [];

      final List<Job> starredJobs = [];
      for (var jobId in starredJobIds) {
        try {
          final jobDoc = await FirebaseFirestore.instance
              .collection('jobs')
              .doc(jobId)
              .get();

          if (jobDoc.exists && jobDoc.data() != null) {
            // Only add the job if it's active
            final jobData = jobDoc.data()!;
            if (jobData['status'] == 'active') {
              final job = await fromFirestore(jobData, jobId);
              starredJobs.add(job);
            }
          }
        } catch (e) {
          print("Error fetching job $jobId: $e");
          continue;
        }
      }
      return starredJobs;
    } catch (e) {
      print("Error fetching starred jobs: $e");
      return [];
    }
  }

  static Future<List<Job>> allJobs() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('jobs')
          .where('status', isEqualTo: 'active')  // Only get jobs with active status
          .get();

      List<Job> jobs = [];

      for (var doc in snapshot.docs) {
        try {
          final job = await fromFirestore(doc.data(), doc.id);
          jobs.add(job);
        } catch (e) {
          print("Error creating job from doc ${doc.id}: $e");
          continue;
        }
      }

      return jobs;
    } catch (e) {
      print("Error fetching jobs: $e");
      return [];
    }
  }

}

class CompanyEnvironment {
  final String placeName;
  final String arLink;
  final String momentoLink;

  CompanyEnvironment({
    required this.placeName,
    required this.arLink,
    required this.momentoLink,
  });
}