import 'dart:async';
import 'package:badges/badges.dart' as badges;
import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vmccp_admin/screens/globalsearchscreen.dart';
import 'package:vmccp_admin/screens/info_screen.dart';
import 'complaint_detail_screen.dart';
import 'profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  final String userId;
  const DashboardScreen({super.key, required this.userId});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final GlobalKey _filterKey = GlobalKey();
  String selectedFilter = 'All';
  String searchQuery = '';
  String userName = "";
  String userId = "";
  String selectedWard = "All Complaints";

  String userWardName = "";
  String userWardNo = "";
  String userRole = ""; // ✅ added this line

  List<Map<String, dynamic>> allComplaints = [];
  List<Map<String, dynamic>> filteredComplaints = [];
  StreamSubscription? _complaintsSubscription;

  final List<String> statusOrder = [ 'in progress', 'completed', 'overdue'];

 @override
void initState() {
  super.initState();
  userId = widget.userId;
  fetchUserName();
  fetchUserWardInfo(userId); // This should set userRole
  _setupComplaintsStream();
  
  // Also get role from shared preferences as fallback
  SharedPreferences.getInstance().then((prefs) {
    if (mounted) {
      setState(() {
        userRole = prefs.getString('role') ?? userRole;
      });
    }
  });
}

  @override
  void dispose() {
    _complaintsSubscription?.cancel();
    super.dispose();
  }

void _setupComplaintsStream() async {
  final prefs = await SharedPreferences.getInstance();
  final loggedInRole = prefs.getString('role') ?? '';
  final loggedInWard = prefs.getString('wardName') ?? '';

  final complaintsRef = FirebaseDatabase.instance.ref('complaints');
  _complaintsSubscription = complaintsRef.onValue.listen((event) {
    final snapshot = event.snapshot;

    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      List<Map<String, dynamic>> complaints = data.entries.map((entry) {
        final complaintData = entry.value as Map<dynamic, dynamic>;
        int commentCount = 0;
        if (complaintData['comments'] != null && complaintData['comments'] is Map) {
          commentCount = (complaintData['comments'] as Map).length;
        }

        // 🟠 Overdue logic
        final status = complaintData['status']?.toString() ?? 'New';
        final timestamp = complaintData['timestamp'];
        if (timestamp != null && status != 'Completed' && status != 'Overdue') {
          final complaintDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
          final now = DateTime.now();
          final daysPassed = now.difference(complaintDate).inDays;

          if (daysPassed > 15) {
            // 🔴 Update status in Firebase
            FirebaseDatabase.instance
                .ref('complaints/${entry.key}')
                .update({'status': 'Overdue'});
          }
        }

        return {
          "id": entry.key,
          "text": complaintData['text'] ?? '',
          "template": complaintData['template'] ?? '',
          "ward": complaintData['ward'] ?? '',
          "status": complaintData['status'] ?? '',
          "timestamp": complaintData['timestamp'] ?? 0,
          "location": complaintData['location'] ?? '',
          "commentCount": commentCount,
          "area": complaintData['area'] ?? '',
          'userImage': complaintData ['image'] ?? '',

        };
      }).where((complaint) {
        if (loggedInRole == 'Admin') {
          return true;
        } else if (loggedInRole == 'Member') {
          return complaint['ward'] == loggedInWard;
        }
        return false;
      }).toList();

      complaints.sort((a, b) {
        int aIndex = statusOrder.indexOf((a['status']?.toString().toLowerCase() ?? ''));
        int bIndex = statusOrder.indexOf((b['status']?.toString().toLowerCase() ?? ''));
        if (aIndex == -1) aIndex = statusOrder.length;
        if (bIndex == -1) bIndex = statusOrder.length;
        if (aIndex != bIndex) {
          return aIndex.compareTo(bIndex);
        }
        return (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0);
      });

      setState(() {
        allComplaints = complaints;
        filteredComplaints = complaints;
        _applyFilters();
      });
    }
  }, onError: (error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Error fetching complaints: $error")),
    );
  });
}


  Future<String> fetchMemberName(String userId) async {
    final ref = FirebaseDatabase.instance.ref('memberLogin');
    final snapshot = await ref.get();
    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      for (var entry in data.entries) {
        final value = entry.value as Map<dynamic, dynamic>;
        if (value['userId'] == userId) {
          return value['name'] ?? userId;
        }
      }
    }
    return userId;
  }

  void fetchUserName() async {
    final name = await fetchMemberName(userId);
    if (mounted) {
      setState(() {
        userName = name;
      });
    }
  }

  Future<void> fetchUserWardInfo(String userId) async {
    final ref = FirebaseDatabase.instance.ref('memberLogin');
    final snapshot = await ref.get();
    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;
      for (var entry in data.entries) {
        final value = entry.value as Map<dynamic, dynamic>;
        if (value['userId'] == userId) {
          setState(() {
            userWardName = value['wardName'] ?? '';
            userWardNo = value['wardNo'] ?? '';
            userRole = value['role'] ?? ''; // ✅ added role fetching
          });
          return;
        }
      }
    }
  }
void _applyFilters() {
  List<Map<String, dynamic>> tempComplaints = List.from(allComplaints);

  // ✅ Ward filter
  if (selectedWard != "All Complaints") {
    tempComplaints = tempComplaints.where((c) {
      return c['ward']?.toString().toLowerCase() == selectedWard.toLowerCase();
    }).toList();
  }

  // ✅ Status filters
  final String status = selectedFilter.toLowerCase();

  if (status == 'initialize') {
    tempComplaints = tempComplaints.where((c) =>
        (c['status']?.toString().toLowerCase() ?? '') == 'initialize').toList();
  } 
  else if (status == 'in progress') {
    tempComplaints = tempComplaints.where((c) {
      final s = c['status']?.toString().toLowerCase() ?? '';
      return s == 'in progress' || s == 'inprogress';
    }).toList();
  } 
  else if (status == 'completed') {
    tempComplaints = tempComplaints.where((c) =>
        (c['status']?.toString().toLowerCase() ?? '') == 'completed').toList();
  } 
  else if (status == 'date and time') {
    tempComplaints.sort((a, b) => (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0));
  } 
  else if (status == 'overdue') {
    final now = DateTime.now();
    tempComplaints = tempComplaints.where((c) {
      final s = (c['status']?.toString().toLowerCase() ?? '');
      if (s == 'completed') return false;

      final int timestamp = c['timestamp'] ?? 0;
      final int lastCommentTime = c['lastCommentTime'] ?? 0;

      final lastActivity = DateTime.fromMillisecondsSinceEpoch(
        lastCommentTime > timestamp ? lastCommentTime : timestamp,
      );

      return now.difference(lastActivity).inDays > 15;
    }).toList();
  } 
  else if (RegExp(r'^\d{1,2}-\d{1,2}-\d{4}$').hasMatch(selectedFilter)) {
    // Custom date filter in format dd-mm-yyyy
    tempComplaints = tempComplaints.where((c) {
      final int timestamp = c['timestamp'] ?? 0;
      final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final filterParts = selectedFilter.split("-");
      final day = int.parse(filterParts[0]);
      final month = int.parse(filterParts[1]);
      final year = int.parse(filterParts[2]);

      return date.day == day && date.month == month && date.year == year;
    }).toList();
  }

  // Search filter
  if (searchQuery.isNotEmpty) {
    tempComplaints = tempComplaints.where((c) =>
        c['text']?.toString().toLowerCase().contains(searchQuery.toLowerCase()) ?? false
    ).toList();
  }

  // Custom status sort unless already sorted by date
  if (status != 'date and time' && status != 'overdue' && !RegExp(r'^\d{1,2}-\d{1,2}-\d{4}$').hasMatch(selectedFilter)) {
    final List<String> statusOrder = ['in progress', 'completed', 'overdue'];
    tempComplaints.sort((a, b) {
      // Get status for comparison
      String aStatus = (a['status']?.toString().toLowerCase() ?? '');
      String bStatus = (b['status']?.toString().toLowerCase() ?? '');
      
      // Normalize "inprogress" to "in progress"
      if (aStatus == 'inprogress') aStatus = 'in progress';
      if (bStatus == 'inprogress') bStatus = 'in progress';
      
      int aIndex = statusOrder.indexOf(aStatus);
      int bIndex = statusOrder.indexOf(bStatus);
      
      // If status not in order list, put it at the end
      if (aIndex == -1) aIndex = statusOrder.length;
      if (bIndex == -1) bIndex = statusOrder.length;
      
      // First sort by status order
      if (aIndex != bIndex) {
        return aIndex.compareTo(bIndex);
      }
      // Then sort by timestamp (newest first)
      return (b['timestamp'] ?? 0).compareTo(a['timestamp'] ?? 0);
    });
  }

  setState(() {
    filteredComplaints = tempComplaints;
  });
}

  String formatDateSmart(int timestamp) {
    final DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp).toLocal();
    final DateTime now = DateTime.now();
    
    final List<String> monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    
    final String day = dateTime.day.toString();
    final String month = monthNames[dateTime.month - 1];
    final String time = "${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}";
    
    if (dateTime.year == now.year) {
      return "$day $month $time";
    } else {
      return "$day $month ${dateTime.year} $time";
    }
  }

String getShortText(String text, int maxChars) {
  if (text.length <= maxChars) return text;
  return '${text.substring(0, maxChars)}...';
}

  void applyFilter(String filter) {
    setState(() {
      selectedFilter = filter;
      _applyFilters();
    });
  }

  void updateSearch(String query) {
    setState(() {
      searchQuery = query;
      _applyFilters();
    });
  }

  void updateWardFilter(String ward) {
    setState(() {
      selectedWard = ward;
      _applyFilters();
    });
  }

  String _getLimitedWords(String text, int wordLimit) {
  List<String> words = text.trim().split(RegExp(r'\s+'));
  if (words.length <= wordLimit) {
    return text;
  }
  return '${words.sublist(0, wordLimit).join(' ')}...';
}


  Stream<List<String>> fetchWardInfo() async* {
    final DatabaseReference wardsRef = FirebaseDatabase.instance.ref('wardInfo');
    await for (final DatabaseEvent event in wardsRef.onValue) {
      final DataSnapshot snapshot = event.snapshot;
      if (snapshot.exists) {
        final List<String> wards = (snapshot.value as Map<dynamic, dynamic>)
            .values
            .map((ward) => (ward as Map<dynamic, dynamic>)['wardName'].toString())
            .toList();
        yield wards;
      } else {
        yield [];
      }
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                FadeInUp(
                  duration: const Duration(milliseconds: 1000),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                " ${userName.isEmpty ? userId : userName}",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
    // Show only role if admin, else show ward info
    if (userRole.toLowerCase() == "admin")
      Row(
        children: [
          Text(
            " $userRole",
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            Icons.star,
            color: Colors.amber,
            size: 18,
          ),
        ],
      )
    else
      Text(
        " $userRole| $userWardName | $userWardNo",
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 16,
        ),
      ),

                            ],
                          ),
                        ),
            IconButton(
              icon: const Icon(
                Icons.info_outline,
                color: Colors.white,
                size: 28,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                builder: (context) => const InfoScreen(),
 // Replace with your info screen widget
                  ),
                );
              },
            ),
                ],
              ),
            ),
          ),
                const SizedBox(height: 20),
               Container(
  constraints: BoxConstraints(
    minHeight: MediaQuery.of(context).size.height * 0.90,
  ),
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
                        if (userRole.toLowerCase() == "admin")
                          FadeInUp(
                            duration: const Duration(milliseconds: 1000),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Text(
                                  "Ward",
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: StreamBuilder<List<String>>(
                                    stream: fetchWardInfo(),
                                    builder: (context, snapshot) {
                                      if (snapshot.connectionState == ConnectionState.waiting) {
                                        return const SizedBox(
                                          height: 48,
                                          child: Center(child: CircularProgressIndicator()),
                                        );
                                      } else if (snapshot.hasError) {
                                        return Text(
                                          "Error: ${snapshot.error}",
                                          style: const TextStyle(color: Colors.brown ),
                                        );
                                      } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                                        return const Text(
                                          "No wards available",
                                          style: TextStyle(color: Colors.grey),
                                        );
                                      } else {
                                        return DropdownButtonFormField<String>(
                                          decoration: InputDecoration(
                                            labelText: "Select Ward",
                                            labelStyle: TextStyle(
                                              color: Colors.brown,
                                              fontSize: 16,
                                            ),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(10),
                                              borderSide: const BorderSide(
                                                color: Colors.brown,
                                                width: 2,
                                              ),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(10),
                                              borderSide: const BorderSide(
                                                color: Colors.brown,
                                                width: 2,
                                              ),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(10),
                                              borderSide: const BorderSide(
                                                color: Colors.brown,
                                                width: 2,
                                              ),
                                            ),
                                          ),
                                          items: ["All Complaints", ...snapshot.data!]
                                              .map((ward) => DropdownMenuItem(
                                                    value: ward,
                                                    child: Text(ward),
                                                  ))
                                              .toList(),
                                          value: selectedWard,
                                          onChanged: (value) => updateWardFilter(value!),
                                        );
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 20),
                        FadeInUp(
                          duration: const Duration(milliseconds: 1000),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                onChanged: updateSearch,
                                decoration: InputDecoration(
                                  hintText: "Search complaints...",
                                  prefixIcon: const Icon(Icons.search),
                                  suffixIcon: IconButton(
                                    key: _filterKey,
                                    icon: Icon(Icons.filter_list, color: Colors.brown),
                                    onPressed: () {
                                      final RenderBox renderBox = _filterKey.currentContext!.findRenderObject() as RenderBox;
                                      final Offset offset = renderBox.localToGlobal(Offset.zero);
                                      final Size size = renderBox.size;

showMenu(
  context: context,
  position: RelativeRect.fromLTRB(
    offset.dx,
    offset.dy + size.height,
    offset.dx + size.width,
    offset.dy,
  ),
  color: Colors.white,
 items: [
  PopupMenuItem(
    value: 'All',
    child: ListTile(
      leading: const Icon(Icons.list_alt, color: Colors.brown),
      title: const Text('All Complaints'),
      trailing: selectedFilter == 'All'
          ? const Icon(Icons.check, color: Colors.green)
          : null,
    ),
  ),
PopupMenuItem(
    value: 'Initialize',
    child: ListTile(
      leading: const Icon(Icons.play_circle_fill, color: Colors.brown),
      title: const Text('Initialize'),
      trailing: selectedFilter == 'Initialize'
          ? const Icon(Icons.check, color: Colors.green)
          : null,
    ),
  ),



  PopupMenuItem(
    value: 'In Progress',
    child: ListTile(
      leading: const Icon(Icons.timelapse, color: Colors.brown),
      title: const Text('In Progress'),
      trailing: selectedFilter == 'In Progress'
          ? const Icon(Icons.check, color: Colors.green)
          : null,
    ),
  ),
  PopupMenuItem(
    value: 'Completed',
    child: ListTile(
      leading: const Icon(Icons.check_circle, color: Colors.brown),
      title: const Text('Completed'),
      trailing: selectedFilter == 'Completed'
          ? const Icon(Icons.check, color: Colors.green)
          : null,
    ),
  ),
  PopupMenuItem(
    value: 'Overdue',
    child: ListTile(
      leading: const Icon(Icons.warning_amber, color: Colors.brown),
      title: const Text('Overdue'),
      trailing: selectedFilter == 'Overdue'
          ? const Icon(Icons.check, color: Colors.green)
          : null,
    ),
  ),
  PopupMenuItem(
    value: 'Date and Time',
    child: ListTile(
      leading: const Icon(Icons.calendar_today, color: Colors.brown),
      title: const Text('Date and Time'),
      trailing: RegExp(r'^\d{1,2}-\d{1,2}-\d{4}$').hasMatch(selectedFilter)
          ? const Icon(Icons.check, color: Colors.green)
          : null,
    ),
  ),
],

).then((value) async {
  if (value != null) {
    if (value == 'Date and Time') {
      final DateTime? selectedDate = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(2020),
        lastDate: DateTime(2100),
      );

      if (selectedDate != null) {
        String formattedDate = "${selectedDate.day}-${selectedDate.month}-${selectedDate.year}";
        
        applyFilter(formattedDate);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Selected Date: $formattedDate'),
            duration: const Duration(milliseconds: 800),
          ),
        );
      }
    } else {
      applyFilter(value);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value == 'All' ? 'Showing all complaints' : 'Showing: $value',
          ),
          duration: const Duration(milliseconds: 800),
        ),
      );
    }
  }
});

                                      },
                                      ),
                                  border: const OutlineInputBorder(
                                    borderRadius: BorderRadius.all(Radius.circular(10)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        filteredComplaints.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Text(
                                    selectedFilter == 'All' && 
                                    selectedWard == 'All Complaints' && 
                                    searchQuery.isEmpty
                                        ? "No complaints available"
                                        : "No matching complaints found",
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                              )
                            : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: filteredComplaints.length,
                              itemBuilder: (context, index) {
                                final complaint = filteredComplaints[index];
                                final List<String> monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

final DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(
                                (complaint['timestamp'] ?? 0));
                                final DateTime now = DateTime.now();

String formattedDate;
if (dateTime.year == now.year) {
  // Only date and month name
  formattedDate = "${dateTime.day.toString().padLeft(2, '0')}-${monthNames[dateTime.month - 1]}";
} else {
  // Date, month name and year
  formattedDate = "${dateTime.day.toString().padLeft(2, '0')}-${monthNames[dateTime.month - 1]}-${dateTime.year}";
}

final String formattedTime = "${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}";

   return GestureDetector(
onTap: () {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => ComplaintDetailScreen(
        status: complaint['status'] ?? '',
        text: complaint['text'] ?? '',
        id: complaint['id']?.toString(),
        timestamp: complaint['timestamp'],
        address: complaint['address'] ?? '',
        template: complaint['template'] ?? '',
        location: complaint['location'] ?? '', 
        ward: complaint['ward'] ?? "",
        userRole: userRole,  // ✅ From dashboard state
        userWard: userWardName,  // ✅ From dashboard state
        userWardNo: userWardNo, userWardName: '',  // ✅ From dashboard state
      ),
    ),
  );
  },
  child: Padding(
    padding: const EdgeInsets.symmetric(
      vertical: 4.0,
      horizontal: 4.0,
    ),
    child: FadeInUp(
      delay: Duration(
        milliseconds: 100 * index,
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.brown.shade50,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.brown.shade50.withOpacity(0.1),
              blurRadius: 1,
              offset: const Offset(0, 3),
            ),
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
                  // ✅ First row: Id + timestamp | status
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
                          formatDateSmart(complaint['timestamp']), // 🛠️ Show creation date
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

                  // ✅ Second row: template + ward | commentCount
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            getShortText(complaint['template'] ?? '', 15),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                            const SizedBox(width: 8),
                            // Show ward name only for admin
                            if (userRole.toLowerCase() == "admin" && (complaint['ward'] ?? '').toString().isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.brown.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  complaint['ward'],
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.brown,
                                    fontWeight: FontWeight.w500,
                                  ),
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
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  ),
),
  bottomNavigationBar: BottomNavigationBar(
  selectedItemColor: Colors.brown,
  unselectedItemColor: Colors.brown.shade200,
  currentIndex: 0,
  items: const [
    BottomNavigationBarItem(
      icon: Icon(Icons.home),
      label: 'Home',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.search), // Global Search icon
      label: 'Search',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.person),
      label: 'Profile',
    ),
  ],
  onTap: (index) {
    if (index == 1) {
      // Navigate to Global Search
      // Navigator.push(
      //   context,
      //   MaterialPageRoute(
      //     builder: (context) => GlobalSearchPage(userId, phoneNumber: ''),
      //   ),
      // );

      Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => GlobalSearchPage(userId, userId: '', ),// Pass userId explicitly
  ),
);


    } else if (index == 2) {
      // Navigate to Profile
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProfileScreen(userId: userId),
        ),
      );
    }
  },
),

    );
  }

  
}