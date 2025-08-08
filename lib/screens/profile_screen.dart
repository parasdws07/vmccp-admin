import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:vmccp_admin/screens/globalsearchscreen.dart';
import 'username_login_screen.dart';
import 'package:animate_do/animate_do.dart';
import 'dashboardscreen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.userId});
  final String userId;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? memberData;
  bool isLoading = true;
  File? _imageFile;
  bool _isUploading = false;

  late TextEditingController nameController;
  late TextEditingController contactController;
  late TextEditingController roleController;
  late TextEditingController userIdController;
  late TextEditingController wardNameController;
  late TextEditingController wardNoController;
  late TextEditingController emailController;

  @override
  void initState() {
    super.initState();
    fetchMemberData();
  }

  Future<void> fetchMemberData() async {
    setState(() => isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedUserId = prefs.getString("loggedInUserId");

      if (storedUserId == null) {
        setState(() {
          memberData = null;
          isLoading = false;
        });
        return;
      }

      final ref = FirebaseDatabase.instance.ref("memberLogin");
      final snapshot = await ref.get();

      if (snapshot.exists) {
        final allMembers = Map<dynamic, dynamic>.from(snapshot.value as Map);
        for (var entry in allMembers.entries) {
          final member = Map<String, dynamic>.from(entry.value);
          if (member['userId'] == storedUserId) {
            setState(() {
              memberData = member;
              nameController = TextEditingController(text: member['name'] ?? "");
              contactController = TextEditingController(text: member['contact'] ?? "");
              roleController = TextEditingController(text: member['role'] ?? "");
              userIdController = TextEditingController(text: member['userId'] ?? "");
              wardNameController = TextEditingController(text: member['wardName'] ?? "");
              wardNoController = TextEditingController(text: member['wardNo'] ?? "");
              emailController = TextEditingController(text: member['email'] ?? "");
              isLoading = false;
            });
            return;
          }
        }
      }

      setState(() {
        memberData = null;
        isLoading = false;
      });
    } catch (e) {
      print("Error fetching member data: $e");
      setState(() {
        memberData = null;
        isLoading = false;
      });
    }
  }

  Future<void> _showImageSourceDialog() async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Update Profile Picture"),
        content: const Text("Choose image source"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _pickImage(ImageSource.camera);
            },
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.camera_alt),
                SizedBox(width: 8),
                Text("Take Photo"),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _pickImage(ImageSource.gallery);
            },
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.photo_library),
                SizedBox(width: 8),
                Text("Choose from Gallery"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 85, // Reduce image quality to save space
        maxWidth: 800,    // Limit image width
      );

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
        await _uploadImage();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error picking image: ${e.toString()}")),
      );
    }
  }

  Future<void> _uploadImage() async {
    if (_imageFile == null || memberData == null) return;

    setState(() => _isUploading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final storedUserId = prefs.getString("loggedInUserId");

      if (storedUserId == null) return;

      // Read image file and convert to base64
      final bytes = await _imageFile!.readAsBytes();
      final base64Image = base64Encode(bytes);

      final ref = FirebaseDatabase.instance.ref("memberLogin");
      final snapshot = await ref.get();

      if (snapshot.exists) {
        final allMembers = Map<dynamic, dynamic>.from(snapshot.value as Map);

        for (var entry in allMembers.entries) {
          final key = entry.key;
          final member = Map<String, dynamic>.from(entry.value);

          if (member['userId'] == storedUserId) {
            final memberRef = ref.child(key);
            await memberRef.update({
              'profileImage': base64Image,
            });

            // Update local state
            setState(() {
              memberData!['profileImage'] = base64Image;
            });

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Profile picture updated successfully!")),
            );
            break;
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error uploading image: ${e.toString()}")),
      );
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Do you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove("loggedInUserId");
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const UsernameLoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    contactController.dispose();
    roleController.dispose();
    userIdController.dispose();
    wardNameController.dispose();
    wardNoController.dispose();
    emailController.dispose();
    super.dispose();
  }

  Widget buildTextField(TextEditingController controller, String label, {bool readOnly = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        decoration: InputDecoration(
          labelText: label,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
          suffixIcon: readOnly
              ? const Icon(Icons.lock_outline, color: Colors.brown)
              : null,
        ),
      ),
    );
  }

  Widget buildReadOnlyField(String label, String value) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.brown,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.brown.shade300,
        elevation: 0,
        title: const Text(
          "Profile",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 28,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Logout',
            onPressed: logout,
          ),
        ],
      ),
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.brown.shade300,
              Colors.brown.shade200,
              Colors.brown.shade100,
            ],
          ),
        ),
        child: isLoading
            ? const Center(child: CircularProgressIndicator.adaptive())
            : memberData == null
                ? const Center(child: Text("No member data found."))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      Expanded(
                        child: Container(
                          constraints: BoxConstraints(
                            minHeight: MediaQuery.of(context).size.height * 0.80,
                          ),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(60),
                              topRight: Radius.circular(60),
                            ),
                          ),
                          child: Center(
                            child: SingleChildScrollView(
                              child: Padding(
                                padding: const EdgeInsets.all(30),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    GestureDetector(
                                      onTap: _showImageSourceDialog,
                                      child: Stack(
                                        children: [
                                          CircleAvatar(
                                            radius: 45,
                                            backgroundColor: Colors.brown.shade200,
                                            backgroundImage: memberData!['profileImage'] != null
                                                ? MemoryImage(base64Decode(memberData!['profileImage']))
                                                : null,
                                            child: memberData!['profileImage'] == null
                                                ? Text(
                                                    nameController.text.isNotEmpty
                                                        ? nameController.text[0].toUpperCase()
                                                        : '',
                                                    style: const TextStyle(
                                                      fontSize: 32,
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  )
                                                : null,
                                          ),
                                          if (_isUploading)
                                            const Positioned.fill(
                                              child: CircularProgressIndicator(
                                                valueColor: AlwaysStoppedAnimation(Colors.white),
                                              ),
                                            ),
                                          Positioned(
                                            bottom: 0,
                                            right: 0,
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: Colors.brown,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.camera_alt,
                                                size: 20,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      'Tap to change photo',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 30),

                                    FadeInUp(
                                      duration: const Duration(milliseconds: 1000),
                                      child: buildTextField(nameController, "Name"),
                                    ),
                                    const SizedBox(height: 20),
                                    FadeInUp(
                                      duration: const Duration(milliseconds: 1000),
                                      child: buildTextField(contactController, "Contact"),
                                    ),
                                    const SizedBox(height: 20),
                                    FadeInUp(
                                      duration: const Duration(milliseconds: 1000),
                                      child: buildTextField(emailController, "Email"),
                                    ),
                                    const SizedBox(height: 20),
                                    FadeInUp(
                                      duration: const Duration(milliseconds: 1000),
                                      child: buildReadOnlyField("Role", roleController.text),
                                    ),
                                    const SizedBox(height: 20),
                                    FadeInUp(
                                      duration: const Duration(milliseconds: 1000),
                                      child: buildReadOnlyField("User ID", userIdController.text),
                                    ),
                                    const SizedBox(height: 20),

                                    if (roleController.text.toLowerCase() == "member") ...[
                                      FadeInUp(
                                        duration: const Duration(milliseconds: 1000),
                                        child: buildReadOnlyField("Ward Name", wardNameController.text),
                                      ),
                                      const SizedBox(height: 20),
                                      FadeInUp(
                                        duration: const Duration(milliseconds: 1000),
                                        child: buildReadOnlyField("Ward Number", wardNoController.text),
                                      ),
                                      const SizedBox(height: 20),
                                    ],

                                    FadeInUp(
                                      duration: const Duration(milliseconds: 1000),
                                      child: ElevatedButton(
                                        onPressed: () async {
                                          if (memberData == null) return;

                                          final prefs = await SharedPreferences.getInstance();
                                          final storedUserId = prefs.getString("loggedInUserId");

                                          if (storedUserId == null) return;

                                          final ref = FirebaseDatabase.instance.ref("memberLogin");
                                          final snapshot = await ref.get();

                                          if (snapshot.exists) {
                                            final allMembers = Map<dynamic, dynamic>.from(snapshot.value as Map);

                                            for (var entry in allMembers.entries) {
                                              final key = entry.key;
                                              final member = Map<String, dynamic>.from(entry.value);

                                              if (member['userId'] == storedUserId) {
                                                final memberRef = ref.child(key);
                                                await memberRef.update({
                                                  'name': nameController.text.trim(),
                                                  'contact': contactController.text.trim(),
                                                  'email': emailController.text.trim(),
                                                });

                                                await fetchMemberData();

                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text("Profile updated successfully!")),
                                                );
                                                return;
                                              }
                                            }
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.brown[300],
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(50),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 50, vertical: 15),
                                        ),
                                        child: const Text(
                                          "Save Changes",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: Colors.brown,
        unselectedItemColor: Colors.brown.shade200,
        currentIndex: 2,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Search',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        onTap: (index) {
          if (index == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => DashboardScreen(
                  userId: memberData?['userId'] ?? "",
                ),
              ),
            );
          } else if (index == 1) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => GlobalSearchPage(
                  memberData?['userId'] ?? "", userId: '',
                ),
              ),
            );
          }
        },
      ),
    );
  }
}