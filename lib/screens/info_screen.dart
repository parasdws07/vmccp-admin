import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InfoScreen extends StatefulWidget {
  const InfoScreen({super.key});

  @override
  State<InfoScreen> createState() => _InfoScreenState();
}

class _InfoScreenState extends State<InfoScreen> {
  String userWard = "";
  String userRole = "";
  Map<String, String> wardContentMap = {};
  List<String> wardOrder = [];
  List<Map<String, String>> membersList = [];
  bool isLoading = true;
  String _htmlContent = "";

  @override
  void initState() {
    super.initState();
    _fetchIntroContent();
    _fetchUserAndWardInfo();
  }

  Future<void> _fetchIntroContent() async {
    try {
      final dbRef = FirebaseDatabase.instance.ref();
      final snapshot = await dbRef.child('KnowYourMC/introContent').get();

      if (snapshot.exists) {
        setState(() {
          _htmlContent = snapshot.value.toString();
        });
      } else {
        setState(() {
          _htmlContent = "<p>No information available at the moment.</p>";
        });
      }
    } catch (e) {
      setState(() {
        _htmlContent = "<p>Failed to load content.</p>";
      });
    }
  }

  Future<void> _fetchUserAndWardInfo() async {
    final dbRef = FirebaseDatabase.instance.ref();
    final prefs = await SharedPreferences.getInstance();

    try {
      userWard = prefs.getString('wardName') ?? "";
      userRole = prefs.getString('role')?.toLowerCase() ?? "";

      // Get ward content
      final wardSnap = await dbRef.child('wardInfo').get();
      for (final ward in wardSnap.children) {
        final name = ward.child("wardName").value.toString();
        final content = ward.child("knowYourWard").value.toString();
        wardContentMap[name] = content;
        wardOrder.add(name);
      }

      // Get all members
      final membersSnap = await dbRef.child('memberLogin').get();
      if (membersSnap.exists) {
        final data = membersSnap.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          final member = value as Map<dynamic, dynamic>;
          final role = member['role']?.toString();
          final isArchived = member['isArchived'] == true;

          if ((role == 'Admin' || role == 'Member') && !isArchived) {
            membersList.add({
              'name': member['name']?.toString() ?? '',
              'email': member['email']?.toString() ?? '',
              'contact': member['contact']?.toString() ?? '',
              'wardName': member['wardName']?.toString() ?? '',
              'role': role ?? '',
            });
          }
        });
      }

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      print("Error fetching data: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredWards = userRole == "admin"
        ? wardOrder
        : wardOrder.where((wardName) => wardName == userWard).toList();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF5D4037), Color(0xFFD7CCC8)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      "Information",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Expanded(
                  child: isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Intro Content
                              Html(
                                data: _htmlContent,
                                style: {
                                  "body": Style(
                                    color: Colors.white,
                                    fontSize: FontSize(14.0),
                                    textAlign: TextAlign.center,
                                  ),
                                  "h1": Style(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  "strong": Style(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontSize: FontSize(20.0),
                                  ),
                                  "h2": Style(
                                    color: Colors.white70,
                                    fontSize: FontSize(14.0),
                                    fontWeight: FontWeight.w300,
                                  ),
                                },
                              ),
                              const SizedBox(height: 24),
                              const Text(
                                "Ward Details",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Wards List
                              ...filteredWards.map((wardName) {
                                final content = wardContentMap[wardName] ?? "";
                                bool isExpanded = wardName == userWard;

                                // Ward specific members
                                final wardMembers = membersList.where((m) => m['wardName'] == wardName).toList();

                                return StatefulBuilder(
                                  builder: (context, setInnerState) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 6),
                                      child: Theme(
                                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                        child: Card(
                                          elevation: 4,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          color: Colors.white.withOpacity(0.1),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(16),
                                            child: ExpansionTile(
                                              initiallyExpanded: isExpanded,
                                              onExpansionChanged: (val) => setInnerState(() => isExpanded = val),
                                              trailing: AnimatedRotation(
                                                duration: const Duration(milliseconds: 300),
                                                turns: isExpanded ? 0.5 : 0.0,
                                                child: const Icon(Icons.expand_more, color: Color(0xFF3A3A3A)),
                                              ),
                                              title: Text(
                                                wardName,
                                                style: const TextStyle(color: Color(0xFF3A3A3A), fontSize: 14),
                                              ),
                                              backgroundColor: const Color(0xFFFFD1A3),
                                              collapsedBackgroundColor: const Color(0xFFFFE8CC),
                                              children: [
                                                Padding(
                                                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                                                  child: Html(
                                                    data: content,
                                                    style: {
                                                      "body": Style(
                                                        color: Color(0xFF5C5C5C),
                                                        fontSize: FontSize(14.0),
                                                        textAlign: TextAlign.justify,
                                                      ),
                                                    },
                                                  ),
                                                ),
                                                const SizedBox(height: 8),

                                                // Members list
                                             ...wardMembers.map((member) => Align(
  alignment: Alignment.centerLeft, // 👈 Ensures content is aligned left
  child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, // 👈 Align texts to left inside column
      children: [
        Text("Member: ${member['name']}", style: const TextStyle(fontSize: 13, color: Colors.black87)),
        Text("Email: ${member['email']}", style: const TextStyle(fontSize: 13, color: Colors.black87)),
        Text("Contact: ${member['contact']}", style: const TextStyle(fontSize: 13, color: Colors.black87)),
        const SizedBox(height: 8),
      ],
    ),
  ),
)),
const SizedBox(height: 12),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                );
                              }),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}