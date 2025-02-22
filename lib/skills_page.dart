import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';

class SkillsSelectionPage extends StatefulWidget {
  @override
  _SkillsSelectionPageState createState() => _SkillsSelectionPageState();
}

class _SkillsSelectionPageState extends State<SkillsSelectionPage> {
  bool isLoading = false; // Remove unnecessary loading during navigation
  bool isSaving = false; // Track saving status
  String error = '';
  Map<String, List<String>> fieldSkills = {};
  Set<String> selectedSkills = {};
  Set<String> tempSelectedSkills = {};
  String? selectedField;
  TextEditingController customSkillController = TextEditingController();

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ));
    loadFieldSkills();
    loadExistingSkills();
  }

  Future<void> loadFieldSkills() async {
    try {
      final fieldsSnapshot = await FirebaseFirestore.instance.collection('fields').get();
      Map<String, List<String>> loadedSkills = {};
      for (var doc in fieldsSnapshot.docs) {
        final data = doc.data();
        final fields = data['field'] as List<dynamic>?;
        if (fields != null) {
          for (var field in fields) {
            if (field is Map<String, dynamic>) {
              final fieldName = field['name'] as String?;
              final jobRequirements = field['jobRequirements'] as List<dynamic>?;
              if (fieldName != null && jobRequirements != null) {
                loadedSkills[fieldName] = List<String>.from(jobRequirements);
              }
            }
          }
        }
      }
      setState(() {
        fieldSkills = loadedSkills;
      });
    } catch (e) {
      setState(() {
        error = 'Failed to load skills: $e';
      });
    }
  }

  Future<void> loadExistingSkills() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      final emailDoc = await FirebaseFirestore.instance
          .collection('email')
          .where('email', isEqualTo: user.email)
          .get();
      if (emailDoc.docs.isEmpty) return;
      final studentId = emailDoc.docs.first['studentId'];
      final studentDoc = await FirebaseFirestore.instance
          .collection('allStudents')
          .doc(studentId)
          .get();
      if (studentDoc.exists) {
        final skills = List<String>.from(studentDoc.data()?['skills'] ?? []);
        setState(() {
          selectedSkills = skills.toSet();
        });
      }
    } catch (e) {
      setState(() {
        error = 'Failed to load existing skills: $e';
      });
    }
  }

  Future<void> saveSkills() async {
    setState(() {
      isSaving = true;
      error = '';
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not authenticated');
      final emailDoc = await FirebaseFirestore.instance
          .collection('email')
          .where('email', isEqualTo: user.email)
          .get();
      if (emailDoc.docs.isEmpty) throw Exception('Student not found');
      final studentId = emailDoc.docs.first['studentId'];
      await FirebaseFirestore.instance
          .collection('allStudents')
          .doc(studentId)
          .update({'skills': selectedSkills.toList()});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Skills saved successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        error = 'Failed to save skills: $e';
      });
    } finally {
      setState(() {
        isSaving = false;
      });
    }
  }

  void addCustomSkill() {
    final skill = customSkillController.text.trim();
    if (skill.isNotEmpty && !selectedSkills.contains(skill)) {
      setState(() {
        selectedSkills.add(skill);
        customSkillController.clear();
      });
    }
  }

  void addSelectedSkills() {
    setState(() {
      selectedSkills.addAll(tempSelectedSkills);
      tempSelectedSkills.clear();
      selectedField = null; // Collapse the dropdown
    });
  }

  void removeSkill(String skill) {
    setState(() {
      selectedSkills.remove(skill);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Resume',
          style: TextStyle(
            fontSize: 22.0,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: isSaving
                ? CircularProgressIndicator(color: Colors.white, strokeWidth: 2.0)
                : Icon(Icons.save),
            onPressed: isSaving ? null : saveSkills,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: customSkillController,
                    decoration: InputDecoration(
                      hintText: 'Add custom skill',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.add, color: Colors.blue),
                  onPressed: addCustomSkill,
                ),
              ],
            ),
            SizedBox(height: 16),
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: DropdownButton<String>(
                  value: selectedField,
                  hint: Text('Select your field'),
                  isExpanded: true,
                  underline: SizedBox.shrink(),
                  items: fieldSkills.keys
                      .map((field) => DropdownMenuItem(
                    value: field,
                    child: Text(field),
                  ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedField = value;
                      tempSelectedSkills.clear();
                      if (value != null) {
                        tempSelectedSkills.addAll(
                          fieldSkills[value]!.where(
                                  (skill) => selectedSkills.contains(skill)),
                        );
                      }
                    });
                  },
                ),
              ),
            ),
            SizedBox(height: 16),
            if (selectedField != null)
              Expanded(
                child: ListView.builder(
                  itemCount: fieldSkills[selectedField]!.length,
                  itemBuilder: (context, index) {
                    final skill = fieldSkills[selectedField]![index];
                    return CheckboxListTile(
                      title: Text(skill),
                      value: tempSelectedSkills.contains(skill),
                      onChanged: (isSelected) {
                        setState(() {
                          if (isSelected!) {
                            tempSelectedSkills.add(skill);
                          } else {
                            tempSelectedSkills.remove(skill);
                            selectedSkills.remove(skill); // Reflect changes in the main list
                          }
                        });
                      },
                    );
                  },
                ),
              ),
            SizedBox(height: 16),
            if (selectedField != null)
              ElevatedButton(
                onPressed: addSelectedSkills,
                child: Text('Add Selected Skills'),
              ),
            SizedBox(height: 16),
            Text(
              'Selected Skills',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Expanded(
              child: ListView(
                children: selectedSkills
                    .map((skill) => ListTile(
                  title: Text(skill),
                  trailing: IconButton(
                    icon: Icon(Icons.remove_circle, color: Colors.red),
                    onPressed: () => removeSkill(skill),
                  ),
                ))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

