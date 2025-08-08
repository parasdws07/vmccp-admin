import 'package:badges/badges.dart' as badges;
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
// ignore: depend_on_referenced_packages
import 'package:intl/intl.dart';
import 'package:animate_do/animate_do.dart';
import 'package:vmccp_admin/screens/dashboardscreen.dart';
import 'complaint_detail_screen.dart';
import 'profile_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

// class GlobalSearchPage extends StatefulWidget {
//   final String phoneNumber;
//   const GlobalSearchPage(String userId, {super.key, required this.phoneNumber});
  
//   get isOwnWard => null;

//   @override
//   State<GlobalSearchPage> createState() => _GlobalSearchPageState();
// }

class GlobalSearchPage extends StatefulWidget {
  final String userId; // Changed from phoneNumber to userId for clarity
  const GlobalSearchPage(param0, {super.key, required this.userId});

  @override
  State<GlobalSearchPage> createState() => _GlobalSearchPageState();
}


class _GlobalSearchPageState extends State<GlobalSearchPage> {
  final GlobalKey _filterKey = GlobalKey();
  String _topComplaintsSearchQuery = "";
  String selectedFilter = 'All';
  DateTime? selectedDate;
  String? selectedWard;
  List<Map<String, dynamic>> userWardComplaints = [];
  late Future<List<Map<String, dynamic>>> _complaintsFuture;
  List<String> wardNames = [];
  String userRole = '';
  String userWard = '';
 String userWardName = '';
 String userWardNo = '';
  


  // @override
  // void initState() {
  //   super.initState();
  //   _complaintsFuture = fetchAllComplaints();
  //   loadWardNames();
  //   loadUserData();
  // }

  @override
void initState() {
  super.initState();
  loadUserData();
  loadWardNames();
  _refreshComplaints(); // Initial fetch
}

void _refreshComplaints() {
  setState(() {
    _complaintsFuture = fetchAllComplaints();
  });
}

// void loadUserData() async {
//   final prefs = await SharedPreferences.getInstance();
//   setState(() {
//     userRole = prefs.getString('role') ?? '';
//     userWard = prefs.getString('ward') ?? '';
//     print('Loaded User Data - Role: $userRole, Ward: $userWard'); // Debug log
//   });
// }

Future<void> loadUserData() async {
  final prefs = await SharedPreferences.getInstance();
  final userId = prefs.getString('loggedInUserId') ?? widget.userId; // Fallback to phoneNumber if userId is not in prefs
  final ref = FirebaseDatabase.instance.ref('memberLogin');
  final snapshot = await ref.get();

  if (snapshot.exists) {
    final data = snapshot.value as Map<dynamic, dynamic>;
    for (var entry in data.entries) {
      final value = entry.value as Map<dynamic, dynamic>;
      if (value['userId'] == userId) {
        setState(() {
          userRole = value['role'] ?? '';
          userWardName = value['wardName'] ?? '';
          userWardNo = value['wardNo'] ?? '';
          userWard = userWardName; // Set userWard to match wardName for consistency
          print('Loaded User Data - Role: $userRole, Ward: $userWard, WardNo: $userWardNo'); // Debug log
        });
        return;
      }
    }
  }
  // Fallback to SharedPreferences if Firebase lookup fails
  setState(() {
    userRole = prefs.getString('role') ?? '';
    userWardName = prefs.getString('wardName') ?? '';
    userWardNo = prefs.getString('wardNo') ?? '';
    userWard = userWardName;
    print('Fallback to SharedPreferences - Role: $userRole, Ward: $userWard'); // Debug log
  });
}

  // Future<List<Map<String, dynamic>>> fetchAllComplaints() async {
  //   final complaintsRef = FirebaseDatabase.instance.ref('complaints');
  //   final snapshot = await complaintsRef.get();

  //   List<Map<String, dynamic>> allComplaints = [];

  //   if (snapshot.exists) {
  //     final data = snapshot.value as Map<dynamic, dynamic>;

  //     for (var entry in data.entries) {
  //       final complaintId = entry.key;
  //       final complaintData = entry.value as Map<dynamic, dynamic>;

  //       final commentsRef = FirebaseDatabase.instance.ref(
  //         'complaints/$complaintId/comments',
  //       );
  //       final commentsSnapshot = await commentsRef.get();
  //       final commentCount =
  //           commentsSnapshot.exists
  //               ? (commentsSnapshot.value as Map<dynamic, dynamic>).length
  //               : 0;

  //       allComplaints.add({
  //         "id": complaintId,
  //         "uid": complaintData['uid'],
  //         "ward": complaintData['ward'] ?? '',
  //         "text": complaintData['text'] ?? '',
  //         "area": complaintData['area'] ?? '',
  //         "address": complaintData['address'] ?? '',
  //         "location": complaintData['location'] ?? '',
  //         "images":
  //             complaintData['images'] != null
  //                 ? List<String>.from(complaintData['images'] as List<dynamic>)
  //                 : <String>[],
  //         "template": complaintData['template'] ?? '',
  //         "status": complaintData['status'] ?? '',
  //         "timestamp": complaintData['timestamp'] ?? 0,
  //         "lastUpdated": complaintData['lastUpdated'] ?? 0,
  //         "commentCount": commentCount,
  //         "keywords":
  //             complaintData['keywords'] != null
  //                 ? List<String>.from(
  //                   complaintData['keywords'] as List<dynamic>,
  //                 )
  //                 : <String>[],
  //       });
  //     }
  //   }

  //   userWardComplaints = allComplaints;
  //   return allComplaints;
  // }
  Future<List<Map<String, dynamic>>> fetchAllComplaints() async {
  final complaintsRef = FirebaseDatabase.instance.ref('complaints');
  final snapshot = await complaintsRef.get();

  List<Map<String, dynamic>> allComplaints = [];

  if (snapshot.exists) {
    final data = snapshot.value as Map<dynamic, dynamic>;

    for (var entry in data.entries) {
      final complaintId = entry.key;
      final complaintData = entry.value as Map<dynamic, dynamic>;

      final commentsRef = FirebaseDatabase.instance.ref('complaints/$complaintId/comments');
      final commentsSnapshot = await commentsRef.get();
      final commentCount = commentsSnapshot.exists
          ? (commentsSnapshot.value as Map<dynamic, dynamic>).length
          : 0;

      // Only include complaints that match the user's ward if they are a Member
      if (userRole.toLowerCase() == 'member' && complaintData['ward'] != userWardName) {
        continue; // Skip complaints not in the member's ward
      }

      allComplaints.add({
        "id": complaintId,
        "uid": complaintData['uid'],
        "ward": complaintData['ward'] ?? '',
        "text": complaintData['text'] ?? '',
        "area": complaintData['area'] ?? '',
        "address": complaintData['address'] ?? '',
        "location": complaintData['location'] ?? '',
        "images": complaintData['images'] != null
            ? List<String>.from(complaintData['images'] as List<dynamic>)
            : <String>[],
        "template": complaintData['template'] ?? '',
        "status": complaintData['status'] ?? '',
        "timestamp": complaintData['timestamp'] ?? 0,
        "lastUpdated": complaintData['lastUpdated'] ?? 0,
        "commentCount": commentCount,
        "keywords": complaintData['keywords'] != null
            ? List<String>.from(complaintData['keywords'] as List<dynamic>)
            : <String>[],
      });
    }
  }

  userWardComplaints = allComplaints;
  return allComplaints;
}

  Future<void> pickDateAndFilter() async {
    final timestamps =
        userWardComplaints.map((c) => c['timestamp'] as int).toList();

    if (timestamps.isEmpty) return;

    timestamps.sort();
    final earliest = DateTime.fromMillisecondsSinceEpoch(timestamps.first);
    final latest = DateTime.fromMillisecondsSinceEpoch(timestamps.last);

    final firstDate =
        earliest.isAtSameMomentAs(latest)
            ? earliest.subtract(Duration(days: 1))
            : earliest;

    final selected = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? latest,
      firstDate: firstDate,
      lastDate: latest,
      helpText: 'Select complaint date',
    );

    if (selected != null) {
      setState(() {
        selectedDate = selected;
        selectedFilter = 'Select Date';
      });
    }
  }

  String formatDate(dynamic timestamp) {
    if (timestamp == null) return '';
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp).toLocal();
    return DateFormat('dd-MM-yyyy • hh:mm a').format(date);
  }

  Future<List<String>> fetchWardNames() async {
    final wardInfoRef = FirebaseDatabase.instance.ref('wardInfo');
    final snapshot = await wardInfoRef.get();

    if (!snapshot.exists) {
      throw Exception("No ward info found");
    }

    final data = snapshot.value as Map<dynamic, dynamic>;
    final List<String> wardNames = [];

    for (var entry in data.entries) {
      final wardData = entry.value as Map<dynamic, dynamic>;
      final wardName = wardData['wardName']?.toString();
      if (wardName != null && wardName.isNotEmpty) {
        wardNames.add(wardName);
      }
    }

    return wardNames;
  }

  List<Map<String, dynamic>> filterAndSearchComplaints(
    List<Map<String, dynamic>> allComplaints,
    String selectedFilter,
    String searchQuery,
    List<String> wardNames,
    DateTime? selectedDate,
  ) {
    List<Map<String, dynamic>> filteredComplaints;

    if (selectedFilter == 'All') {
      filteredComplaints = allComplaints;
    } else if (selectedFilter == 'Select Date' && selectedDate != null) {
      final selectedDateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
      filteredComplaints =
          allComplaints.where((c) {
            final complaintDate = DateTime.fromMillisecondsSinceEpoch(
              c['timestamp'],
            );
            return DateFormat('yyyy-MM-dd').format(complaintDate) ==
                selectedDateStr;
          }).toList();
    } else if (wardNames.contains(selectedFilter)) {
      filteredComplaints =
          allComplaints.where((c) => c['ward'] == selectedFilter).toList();
    } else {
      filteredComplaints = allComplaints;
    }

    final search = searchQuery.toLowerCase();
    if (search.isNotEmpty) {
      filteredComplaints =
          filteredComplaints.where((c) {
            final id = (c['id'] ?? '').toString().toLowerCase();
            final template = (c['template'] ?? '').toString().toLowerCase();
            final keywords = (c['keywords'] as List<String>? ?? [])
                .map((k) => k.toLowerCase())
                .join(' ');

            return id.contains(search) ||
                template.contains(search) ||
                keywords.contains(search);
          }).toList();
    }

    return filteredComplaints;
  }

  void loadWardNames() async {
    try {
      final names = await fetchWardNames();
      setState(() {
        wardNames = names;
      });
    } catch (e) {
      print("Failed to load ward names: $e");
    }
  }

  String getShortTemplateSearch(dynamic template, {int maxChars = 25}) {
    final text = template?.toString() ?? '';
    return text.length <= maxChars ? text : '${text.substring(0, maxChars)}...';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                colors: [
                 Colors.brown.shade300,
                 Colors.brown.shade200,
                 Colors.brown.shade100,
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const SizedBox(height: 60),
                Padding(
                  padding: const EdgeInsets.only(left: 20),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        "Global Search",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(30),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(60),
                        topRight: Radius.circular(60),
                      ),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          const SizedBox(height: 20),
                          TextField(
                            onChanged: (value) {
                              setState(() {
                                _topComplaintsSearchQuery = value.toLowerCase();
                              });
                            },
                            decoration: InputDecoration(
                              hintText: "Search by complaint id, title or keywords...",
                              border: const OutlineInputBorder(),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.brown),
                              ),
                              enabledBorder: const OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.grey),
                              ),
                              hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: userRole == 'Admin' ? _buildFilterButton() : null,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _buildComplaintsList(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: Colors.brown,
        unselectedItemColor: Colors.brown.shade200,
        currentIndex: 1,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Search'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
        onTap: (index) async {
          final prefs = await SharedPreferences.getInstance();
          final userId = prefs.getString("loggedInUserId") ?? "";
          
          if (index == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => DashboardScreen(userId: userId)),
            );
          } else if (index == 2) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => ProfileScreen(userId: userId)),
            );
          }
        },
      ),
    );
  }

  Widget _buildFilterButton() {
    return IconButton(
      key: _filterKey,
      icon: const Icon(Icons.filter_list),
      onPressed: () {
        final renderBox = _filterKey.currentContext!.findRenderObject() as RenderBox;
        final offset = renderBox.localToGlobal(Offset.zero);
        final size = renderBox.size;

        showMenu<String>(
          context: context,
          position: RelativeRect.fromLTRB(
            offset.dx,
            offset.dy + size.height,
            offset.dx + size.width,
            offset.dy,
          ),
          items: [
            PopupMenuItem(
              enabled: false,
              padding: EdgeInsets.zero,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 250),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PopupMenuItem(
                        value: 'All',
                        child: Row(
                          children: [
                            const Text('All'),
                            const Spacer(),
                            if (selectedFilter == 'All')
                              const Icon(Icons.check, color: Colors.brown, size: 18),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'Select Date',
                        child: Row(
                          children: [
                            const Text('Select Date'),
                            const Spacer(),
                            if (selectedFilter == 'Select Date')
                              const Icon(Icons.check, color: Colors.brown, size: 18),
                          ],
                        ),
                      ),
                      ...wardNames.map((ward) => PopupMenuItem(
                        value: ward,
                        child: Row(
                          children: [
                            Text(ward),
                            const Spacer(),
                            if (selectedFilter == ward)
                              const Icon(Icons.check, color: Colors.brown, size: 18),
                          ],
                        ),
                      )),
                    ],
                  ),
                ),
              ),
            ),
          ],
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.brown, width: 1),
          ),
        ).then((value) {
          if (value != null) {
            if (value == 'Select Date') {
              WidgetsBinding.instance.addPostFrameCallback((_) => pickDateAndFilter());
            } else {
              setState(() => selectedFilter = value);
            }
          }
        });
      },
    );
  }

  Widget _buildComplaintsList() {
    return SizedBox(
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _complaintsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.brown));
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No complaints found.'));
          }

          final topComplaints = filterAndSearchComplaints(
            userWardComplaints,
            selectedFilter,
            _topComplaintsSearchQuery,
            wardNames,
            selectedDate,
          );

          return MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: topComplaints.length,
              itemBuilder: (context, index) {
                final complaint = topComplaints[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
        //                 builder: (context) => ComplaintDetailScreen(
      
        // status: complaint['status'] ?? '',
        // text: complaint['text'] ?? '',
        // id: complaint['id']?.toString(),
        // timestamp: complaint['timestamp'],
        // address: complaint['address'] ?? '',
        // template: complaint['template'] ?? '',
        // location: complaint['location'] ?? '', 
        // ward: complaint['ward'] ?? "",
        // userRole: userRole,  // ✅ From dashboard state
        // userWard: userWardName,  // ✅ From dashboard state
        // userWardNo: userWardNo, userWardName: '',  // ✅ From dashboard state
        //                 ),

        builder: (context) => ComplaintDetailScreen(
          status: complaint['status'] ?? '',
          text: complaint['text'] ?? '',
          id: complaint['id']?.toString(),
          timestamp: complaint['timestamp'],
          address: complaint['address'] ?? '',
          template: complaint['template'] ?? '',
          location: complaint['location'] ?? '',
          ward: complaint['ward'] ?? '',
          userRole: userRole,
          userWard: userWardName, // Use the state variable
          userWardNo: userWardNo,
          userWardName: userWardName, // Pass the correct userWardName
        ),


                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 4.0),
                    child: FadeInUp(
                      delay: Duration(milliseconds: 100 * index),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.brown.shade50,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withOpacity(0.1),
                              blurRadius: 1,
                              offset: const Offset(0, 3),
                            )
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            'ID: ${complaint['id']}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            formatDate(complaint['timestamp']),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        '${complaint['status']}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            getShortTemplateSearch(complaint['template']),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '${complaint['ward'] ?? ''}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                 
                                   Row(
                        children: [
                          badges.Badge(
                            showBadge: (complaint['commentCount'] ?? 0) > 0,
                            badgeContent: Text(
                              '${complaint['commentCount'] ?? 0}',
                              style: const TextStyle(color: Colors.white, fontSize: 10),
                            ),
                            badgeStyle: badges.BadgeStyle(
                              badgeColor: Colors.brown,
                              padding: const EdgeInsets.all(6),
                            ),
                            position: badges.BadgePosition.topEnd(top: -8, end: -8),
                            child: const Icon(
                              Icons.comment,
                              size: 18,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}