import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'complaint_detail_screen.dart';

class DashboardScreen extends StatefulWidget {
  final String userId;
  const DashboardScreen({super.key, required this.userId});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String selectedFilter = 'New';
  String searchQuery = '';
  String userName = "";

  List<Map<String, dynamic>> allComplaints = [];
  List<Map<String, dynamic>> filteredComplaints = [];

  @override
  void initState() {
    super.initState();
    fetchUserName();
    fetchAndSetComplaints();
  }

  Future<void> fetchAndSetComplaints() async {
    final complaints = await fetchComplaints();
    setState(() {
      allComplaints = complaints;
      filteredComplaints = complaints;
    });
  }

  // Fetch member name by userId from memberLogin collection
  Future<String> fetchMemberName(String userId) async {
    final ref = FirebaseDatabase.instance.ref('memberLogin');
    final snapshot = await ref.get();
    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      for (var entry in data.entries) {
        final value = entry.value as Map<dynamic, dynamic>;
        if (value['userId'] == userId) {
          return value['name'] ?? "User";
        }
      }
    }
    return "User";
  }

  void fetchUserName() async {
    final name = await fetchMemberName(widget.userId);
    setState(() {
      userName = name;
    });
  }

  void applyFilter(String filter) {
    setState(() {
      selectedFilter = filter;
      // Apply filter to complaints
      if (filter == 'New') {
        filteredComplaints = allComplaints.where((complaint) => complaint['status'] == 'New').toList();
      } else if (filter == 'Old') {
        filteredComplaints = allComplaints.where((complaint) => complaint['status'] == 'Old').toList();
      } else if (filter == 'Most Commented') {
        // Assuming 'comments' field exists and represents the number of comments
        filteredComplaints = allComplaints.where((complaint) => complaint['comments'] != null).toList();
      } else {
        filteredComplaints = allComplaints; // No filter applied
      }
    });
  }

  void updateSearch(String query) {
    setState(() {
      searchQuery = query;
      filteredComplaints = allComplaints.where((complaint) {
        final text = (complaint['text'] ?? '').toString().toLowerCase();
        final area = (complaint['area'] ?? '').toString().toLowerCase();
        return text.contains(query.toLowerCase()) || area.contains(query.toLowerCase());
      }).toList();
    });
  }

  Future<List<String>> fetchWardInfo() async {
    try {
      // Reference to the Realtime Database
      final DatabaseReference wardsRef = FirebaseDatabase.instance.ref('wardInfo');

      // Fetch the data from the database
      final DataSnapshot snapshot = await wardsRef.get();

      if (snapshot.exists) {
        print("Snapshot Data: ${snapshot.value}"); // Log the fetched data

        // Extract ward names from the snapshot
        final List<String> wards = (snapshot.value as Map<dynamic, dynamic>)
            .values
            .map((ward) => (ward as Map<dynamic, dynamic>)['wardName'].toString())
            .toList();
        return wards;
      } else {
        print("No data exists in wardInfo");
        return []; // Return an empty list if no data exists
      }
    } catch (e) {
      print("Error fetching wards: $e"); // Log the error
      throw Exception("Failed to fetch wards");
    }
  }

  Future<List<Map<String, dynamic>>> fetchComplaints() async {
    try {
      final DatabaseReference complaintsRef = FirebaseDatabase.instance.ref('complaints');
      final DataSnapshot snapshot = await complaintsRef.get();

      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        // Complaints ko list me convert karo
        List<Map<String, dynamic>> complaints = data.entries.map((entry) {
          final complaintData = entry.value as Map<dynamic, dynamic>;
          return {
            "id": entry.key,
            "text": complaintData['text'] ?? '',
            "area": complaintData['area'] ?? '',
            "status": complaintData['status'] ?? '',
            "timestamp": complaintData['timestamp'] ?? 0,
          };
        }).toList();

        // Sort by timestamp (descending: newest first)
        complaints.sort((a, b) => (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0));

        // Sirf top 5 complaints return karo
        return complaints.take(5).toList();
      } else {
        print("No complaints found in the database.");
        return [];
      }
    } catch (e) {
      print("Error fetching complaints: $e");
      throw Exception("Failed to fetch complaints");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 80),
                  FadeInUp(
                    duration: const Duration(milliseconds: 1200),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 20),
                      child: Text(
                        "Welcome, ${userName.isEmpty ? 'User' : userName}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(60),
                        topRight: Radius.circular(60),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(30),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FadeInUp(
                            duration: const Duration(milliseconds: 1400),
                            child: const Text(
                              "Ward Selection",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          FutureBuilder<List<String>>(
                            future: fetchWardInfo(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Center(child: CircularProgressIndicator());
                              } else if (snapshot.hasError) {
                                return Text(
                                  "Error: ${snapshot.error}",
                                  style: const TextStyle(color: Colors.red),
                                );
                              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                                return const Text(
                                  "No wards available",
                                  style: TextStyle(color: Colors.grey),
                                );
                              } else {
                                return FadeInUp(
                                  duration: const Duration(milliseconds: 1500),
                                  child: DropdownButtonFormField<String>(
                                    decoration: InputDecoration(
                                      labelText: "Select Ward",
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    items: snapshot.data!
                                        .map((ward) => DropdownMenuItem(
                                              value: ward,
                                              child: Text(ward),
                                            ))
                                        .toList(),
                                    onChanged: (value) {
                                      // Handle ward selection
                                      print("Selected Ward: $value");
                                    },
                                  ),
                                );
                              }
                            },
                          ),
                          const SizedBox(height: 20),
                          FadeInUp(
                            duration: const Duration(milliseconds: 1600),
                            child: const Text(
                              "Ward Complaint",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          FutureBuilder<List<Map<String, dynamic>>>(
                            future: fetchComplaints(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Center(child: CircularProgressIndicator());
                              } else if (snapshot.hasError) {
                                return Center(
                                  child: Text(
                                    "Error: ${snapshot.error}",
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                );
                              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                                return const Center(
                                  child: Text(
                                    "No complaints available",
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                );
                              } else {
                                final complaints = snapshot.data!;
                                return SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: complaints.map((complaint) {
                                      return Padding(
                                        padding: const EdgeInsets.only(right: 10),
                                        child: DashboardCard(
                                          title: " ${complaint['text']}\nArea: ${complaint['area']}\nStatus: ${complaint['status']}",
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => ComplaintDetailScreen(
                                                  area: complaint['area'] ?? '',
                                                  status: complaint['status'] ?? '',
                                                  text: complaint['text'] ?? '',
                                                  id: complaint['id']?.toString() ?? '',
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                );
                              }
                            },
                          ),
                          const SizedBox(height: 10),
                          // Search Box
                          TextField(
                            onChanged: updateSearch,
                            decoration: InputDecoration(
                              hintText: "Search complaints...",
                              prefixIcon: Icon(Icons.search),
                              suffixIcon: IconButton(
                                icon: Icon(Icons.filter_list, color: Colors.brown),
                                onPressed: () {
                                  showModalBottomSheet(
                                    context: context,
                                    builder: (context) {
                                      return Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          ListTile(
                                            leading: Icon(Icons.fiber_new, color: Colors.brown),
                                            title: Text('New'),
                                            onTap: () {
                                              applyFilter('New');
                                              Navigator.pop(context);
                                            },
                                          ),
                                          ListTile(
                                            leading: Icon(Icons.history, color: Colors.brown),
                                            title: Text('Old'),
                                            onTap: () {
                                              applyFilter('Old');
                                              Navigator.pop(context);
                                            },
                                          ),
                                          ListTile(
                                            leading: Icon(Icons.comment, color: Colors.brown),
                                            title: Text('Most Commented'),
                                            onTap: () {
                                              applyFilter('Most Commented');
                                              Navigator.pop(context);
                                            },
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                              ),
                              border: const OutlineInputBorder(
                                borderRadius: BorderRadius.all(Radius.circular(10)),
                              ),
                            ),
                          ),
                         
                          const SizedBox(height: 10),
                          ListView.builder(
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            itemCount: filteredComplaints.length,
                            itemBuilder: (context, index) {
                              final complaint = filteredComplaints[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 6),
                                child: ListTile(
                                  tileColor: Colors.white,
                                  title: Text(complaint['text'] ?? ''),
                                 
                                  trailing: const Icon(Icons.comment, color: Colors.brown),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ComplaintDetailScreen(
                                          area: complaint['area'] ?? '',
                                          status: complaint['status'] ?? '',
                                          text: complaint['text'] ?? '',
                                          id: complaint['id']?.toString() ?? '',
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DashboardCard extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const DashboardCard({
    super.key,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.brown.shade300,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black,
                ),
              ),
            ),
          ),
          // Comment icon at bottom right
          Positioned(
            bottom: 12,
            right: 12,
            child: Icon(
              Icons.comment,
              color: Colors.brown.shade300,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }
}