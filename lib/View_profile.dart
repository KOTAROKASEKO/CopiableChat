import 'dart:io'; // For File
import 'package:chatapp/user_data.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart'; // For date formatting

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _dobController = TextEditingController(); // Still used for DatePicker display in edit mode

  String? _profileImageUrl;
  File? _pickedImageFile;
  DateTime? _selectedDate; // This will hold the DOB

  bool _isLoading = false;
  bool _isEditing = false;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
 // EXAMPLE USER ID

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // --- Helper function to calculate age ---
  int? _calculateAge(DateTime? birthDate) {
    if (birthDate == null) {
      return null;
    }
    DateTime currentDate = DateTime.now();
    int age = currentDate.year - birthDate.year;
    if (currentDate.month < birthDate.month ||
        (currentDate.month == birthDate.month && currentDate.day < birthDate.day)) {
      age--;
    }
    return age < 0 ? 0 : age; // Ensure age isn't negative if DOB is in future (though validated)
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(CurrentUser.currentUserUid).get();
      if (userDoc.exists) {
        Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
        _nameController.text = data['name'] ?? '';
        if (data['dob'] != null && data['dob'] is Timestamp) {
           _selectedDate = (data['dob'] as Timestamp).toDate();
          _dobController.text = DateFormat('yyyy-MM-dd').format(_selectedDate!); // Keep for edit form
        } else if (data['dob'] is String) {
            try {
                _selectedDate = DateFormat('yyyy-MM-dd').parse(data['dob']);
                _dobController.text = data['dob']; // Keep for edit form
            } catch (e) {
                print("Error parsing DOB string from Firestore: $e");
            }
        }
        _profileImageUrl = data['profileImageUrl'];
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load user data: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _pickedImageFile = File(image.path);
        _profileImageUrl = null;
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(), // Users cannot select a future date for DOB
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
              onPrimary: Colors.white,
              onSurface: Colors.deepPurple.shade700,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).primaryColor,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dobController.text = DateFormat('yyyy-MM-dd').format(_selectedDate!); // Update controller for edit form
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      // String? uploadedImageUrl = _profileImageUrl;
      // if (_pickedImageFile != null) {
      //   // --- Placeholder for image upload to S3/Supabase ---
      //   // uploadedImageUrl = "URL_FROM_S3_OR_SUPABASE";
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     const SnackBar(content: Text('Image upload logic not implemented.')),
      //   );
      // }

      Map<String, dynamic> userData = {
        'name': _nameController.text.trim(),
        'dob': _selectedDate != null ? Timestamp.fromDate(_selectedDate!) : null, // Store DOB
        // 'profileImageUrl': uploadedImageUrl,
      };
       if (_profileImageUrl != null && _pickedImageFile == null) {
          userData['profileImageUrl'] = _profileImageUrl;
      }


      try {
        await _firestore.collection('users').doc(CurrentUser.currentUserUid).set(
              userData,
              SetOptions(merge: true),
            );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile saved successfully!')),
          );
          setState(() => _isEditing = false);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to save profile: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  Widget _buildProfileView() {
    int? age = _calculateAge(_selectedDate); // Calculate age here

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Stack(
            children: [
              CircleAvatar(
                radius: 60,
                backgroundColor: Colors.deepPurple.shade100,
                backgroundImage: _pickedImageFile != null
                    ? FileImage(_pickedImageFile!)
                    : (_profileImageUrl != null && _profileImageUrl!.isNotEmpty
                        ? NetworkImage(_profileImageUrl!)
                        : const AssetImage('assets/placeholder_profile.png'))
                            as ImageProvider,
                child: _pickedImageFile == null && (_profileImageUrl == null || _profileImageUrl!.isEmpty)
                    ? Icon(Icons.person, size: 60, color: Colors.deepPurple.shade300)
                    : null,
              ),
              if (_isEditing)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                      onPressed: _pickImage,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            _nameController.text.isNotEmpty ? _nameController.text : 'User Name',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.deepPurple.shade700),
          ),
          const SizedBox(height: 8),
          // --- Display Age ---
          Text(
            age != null ? 'Age: $age years old' : 'Age not set',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            icon: const Icon(Icons.edit),
            label: const Text('Edit Profile'),
            onPressed: () {
              setState(() {
                _isEditing = true;
              });
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileEditForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Stack(
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.deepPurple.shade100,
                  backgroundImage: _pickedImageFile != null
                      ? FileImage(_pickedImageFile!)
                      : (_profileImageUrl != null && _profileImageUrl!.isNotEmpty
                          ? NetworkImage(_profileImageUrl!)
                          : const AssetImage('assets/placeholder_profile.png'))
                              as ImageProvider,
                   child: _pickedImageFile == null && (_profileImageUrl == null || _profileImageUrl!.isEmpty)
                      ? Icon(Icons.person, size: 60, color: Colors.deepPurple.shade300)
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                     decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                      onPressed: _pickImage,
                      tooltip: 'Change profile picture',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your name';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            // --- DOB Picker, text shows selected DOB ---
            TextFormField(
              controller: _dobController, // Shows the selected DOB in yyyy-MM-dd format
              decoration: InputDecoration(
                labelText: 'Date of Birth',
                prefixIcon: const Icon(Icons.calendar_today_outlined),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(Icons.edit_calendar_outlined, color: Theme.of(context).primaryColor),
                  onPressed: () => _selectDate(context),
                )
              ),
              readOnly: true,
              onTap: () => _selectDate(context),
              validator: (value) {
                if (_selectedDate == null) { // Validate based on _selectedDate
                  return 'Please select your date of birth';
                }
                return null;
              },
            ),
            const SizedBox(height: 40),
            _isLoading
                ? CircularProgressIndicator(color: Theme.of(context).primaryColor)
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isEditing = false;
                            _loadUserData(); // Reset changes
                          });
                        },
                        child: Text('Cancel', style: TextStyle(color: Colors.grey.shade700)),
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.save_alt_outlined),
                        label: const Text('Save Profile'),
                        onPressed: _saveProfile,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Profile' : 'My Profile'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: Center(
        child: _isLoading && !_isEditing
            ? CircularProgressIndicator(color: Theme.of(context).primaryColor)
            : _isEditing
                ? _buildProfileEditForm()
                : _buildProfileView(),
      ),
    );
  }
}