import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class ComplaintDetailScreen extends StatefulWidget {
  final String status;
  final String text;
  final String? id;
  final int? timestamp;
  final String address;
  final String template;
  final String location;
  final String ward;
  final String userRole;  // ✅ From dashboard
  final String userWard;  // ✅ From dashboard (userWardName)
  final String userWardNo; 

const ComplaintDetailScreen({
  super.key,
      
    required this.status,
    required this.text,
    required this.id,
    required this.timestamp,
    required this.address,
    required this.template,
    required this.location,
    required this.ward,
    required this.userRole,
    required this.userWard,
    required this.userWardNo, required String userWardName,

});


  @override
  State<ComplaintDetailScreen> createState() => _ComplaintDetailScreenState();
}

class _ComplaintDetailScreenState extends State<ComplaintDetailScreen> {
  List<Map<String, dynamic>> comments = [];
  bool isLoading = true;
  final TextEditingController _commentController = TextEditingController();
  bool _isSending = false;
  String currentStatus = 'Initialize'; 
  String currentAddress = '';
  List<String>? base64Images;
  bool isFullScreen = false;
String? selectedImageBase64;

  
  int? lastUpdated;
  String userRole = '';
  String wardName = '';

 bool isOwnWard = false;


 bool get isAdmin => widget.userRole.toLowerCase() == 'admin';
bool get isMember => widget.userRole.toLowerCase() == 'member';
bool get isComplaintInMemberWard => 
    widget.ward.toLowerCase() == widget.userWard.toLowerCase();
bool get canChangeStatus => isMember && isComplaintInMemberWard;

void _debugPrintPermissions() {
  print('=== DEBUG: User Permissions ===');
  print('User Role: ${widget.userRole}');
  print('User Ward: ${widget.userWard}');
  print('Complaint Ward: ${widget.ward}');
  print('isAdmin: $isAdmin');
  print('isMember: $isMember');
  print('isComplaintInMemberWard: $isComplaintInMemberWard');
  print('canChangeStatus: $canChangeStatus');
  print('==============================');
}


bool get canComment {
  final isAdmin = (widget.userRole ?? '').toLowerCase() == 'admin';
  final isMember = (widget.userRole ?? '').toLowerCase() == 'member';
  final isComplaintInMemberWard = isMember && 
      (widget.ward ?? '').toLowerCase() == (widget.userWard ?? '').toLowerCase() && 
      (widget.ward ?? '').isNotEmpty && 
      (widget.userWard ?? '').isNotEmpty;

  // Debug logs for verification
  print('User Role: ${widget.userRole}');
  print('User Ward: ${widget.userWard}');
  print('Complaint Ward: ${widget.ward}');
  print('isAdmin: $isAdmin');
  print('isMember: $isMember');
  print('isComplaintInMemberWard: $isComplaintInMemberWard');
  print('canComment: ${isAdmin || isComplaintInMemberWard}');

  return isAdmin || isComplaintInMemberWard;
}
bool get canDeleteComment {
  final isAdmin = (widget.userRole ?? '').toLowerCase() == 'admin';
  final isMember = (widget.userRole ?? '').toLowerCase() == 'member';
  final isComplaintInMemberWard = isMember && 
      (widget.ward ?? '').toLowerCase() == (widget.userWard ?? '').toLowerCase() && 
      (widget.ward ?? '').isNotEmpty && 
      (widget.userWard ?? '').isNotEmpty;

  return isAdmin || isComplaintInMemberWard;
}

@override
void initState() {
  super.initState();
  currentStatus = widget.status;
  currentAddress = widget.address;
  fetchComments();
  fetchComplaintData();
  
 isOwnWard = widget.ward.toLowerCase() == widget.userWard.toLowerCase();
}



String getDisplayRole(dynamic role) {
  final roleStr = (role ?? '').toString().trim().toLowerCase();
  if (roleStr.isEmpty || roleStr == 'null' || roleStr == 'citizen') return 'User';
  if (roleStr == 'admin') return 'Admin';
  return 'member';
}



Future<void> fetchComments() async {
  if (widget.id == null) {
    setState(() {
      comments = [];
      isLoading = false;
    });
    return;
  }

  try {
    print("🔍 Fetching comments for complaint ID: ${widget.id}");

    final ref = FirebaseDatabase.instance.ref('complaints/${widget.id}/comments');
    final snapshot = await ref.get();
    if (snapshot.exists) {
      final data = snapshot.value as Map<dynamic, dynamic>;

      final List<Map<String, dynamic>> loadedComments = [];

      for (var entry in data.entries) {
        final commentMap = Map<String, dynamic>.from(entry.value);
        print("🗨️ Raw Comment: $commentMap");

        String role = 'citizen'; // default

        if (commentMap.containsKey('role')) {
          role = commentMap['role']?.toString() ?? 'citizen';
          print("➡️ Role found in comment: $role");
        } else if (commentMap.containsKey('uid')) {
          print("🔎 Role not in comment, fetching from uid: ${commentMap['uid']}");
          final userSnapshot = await FirebaseDatabase.instance
              .ref('memberLogin/${commentMap['uid']}')
              .get();

          if (userSnapshot.exists) {
            final userData = Map<String, dynamic>.from(userSnapshot.value as Map);
            role = userData['role']?.toString() ?? 'citizen';
            print("✅ Role fetched from memberLogin: $role");
          } else {
            print("❌ No user found for uid ${commentMap['uid']}, defaulting to citizen");
          }
        } else {
          print("⚠️ No role or uid found, defaulting to citizen");
        }

        loadedComments.add({
          'key': entry.key,
          'text': commentMap['text']?.toString() ?? '',
          'userName': commentMap['userName']?.toString() ?? 'Unknown',
          'timestamp': commentMap['timestamp'] ?? 0,
          'role': role,
        });
      }

      setState(() {
        comments = loadedComments.where((e) => e['text']!.isNotEmpty).toList();
        isLoading = false;
      });

      print("✅ Final Loaded Comments:");
      for (var comment in comments) {
        print(comment);
      }

    } else {
      print("🚫 No comments found for this complaint.");
      setState(() {
        comments = [];
        isLoading = false;
      });
    }
  } catch (e) {
    print("❗ Error while fetching comments: $e");
    setState(() {
      comments = [];
      isLoading = false;
    });
  }
}


Future<void> _openMapWithLatLng() async {
                                                          final text =
                                                            widget.location;
                                                        final regex = RegExp(
                                                          r'Lat:\s*([\d\.\-]+),\s*Lon:\s*([\d\.\-]+)',
                                                        );
                                                        final match = regex
                                                            .firstMatch(text);
                                                        if (match != null) {
                                                          final lat = match
                                                              .group(1);
                                                          final lng = match
                                                              .group(2);
                                                          final url =
                                                              'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
                                                          launchUrl(
                                                            Uri.parse(url),
                                                            mode:
                                                                LaunchMode
                                                                    .externalApplication,
                                                          );
                                                        } else {
                                                          ScaffoldMessenger.of(
                                                            context,
                                                          ).showSnackBar(
                                                            const SnackBar(
                                                              content: Text(
                                                                "Invalid location format",
                                                              ),
                                                            ),
                                                          );
                                                        }

  }


Future<void> _sendComment() async {
  if (!canComment) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("You can't comment on this complaint.")),
    );
    return;
  }

  if (_commentController.text.trim().isEmpty || widget.id == null) return;

  setState(() => _isSending = true);

  final prefs = await SharedPreferences.getInstance();
  final userName = prefs.getString('name') ?? 'Unknown';
  final role = prefs.getString('role') ?? 'citizen';

  final commentRef = FirebaseDatabase.instance
      .ref('complaints/${widget.id}/comments')
      .push();

  await commentRef.set({
    'text': _commentController.text.trim(),
    'userName': userName,
    'role': role,
    'timestamp': DateTime.now().millisecondsSinceEpoch,
  });

  _commentController.clear();
  setState(() => _isSending = false);
  fetchComments();
}


  Future<void> _updateStatus(String newStatus) async {
    if (widget.id == null) return;
    final ref = FirebaseDatabase.instance.ref('complaints/${widget.id}');
    await ref.update({'status': newStatus, 'lastUpdated': DateTime.now().millisecondsSinceEpoch});
    setState(() {
      currentStatus = newStatus;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Status updated to "$newStatus"')),
    );
  }

  Future<void> _showStatusChangeDialog(String newStatus) async {
    bool showTextField = false;
    String dialogComment = '';
    final TextEditingController dialogController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text("Add Comment Required"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Please add a comment before changing the status.'),
                const SizedBox(height: 10),
                if (showTextField)
                  TextField(
                    controller: dialogController,
                    decoration: const InputDecoration(
                      hintText: "Write your comment...",
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => dialogComment = value,
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(foregroundColor: Colors.brown),
                child: const Text("Cancel"),
              ),
              if (!showTextField)
                ElevatedButton(
                  onPressed: () {
                    setState(() => showTextField = true);
                  },
                  style: ElevatedButton.styleFrom(foregroundColor: Colors.brown),
                  child: const Text("Add Comment"),
                ),
              if (showTextField)
                ElevatedButton(
                  
                  onPressed: () async {
                    if (dialogComment.trim().isNotEmpty) {
                      Navigator.pop(context);
                      _commentController.text = dialogComment;
                      await _sendComment();
                      await _updateStatus(newStatus);
                    }
                  },
                  child: const Text("Submit"),
                ),
            ],
          );
        },
      ),
    );
  }

Future<void> fetchComplaintData() async {
  if (widget.id == null) return;

  final ref = FirebaseDatabase.instance.ref('complaints/${widget.id}');
  final snapshot = await ref.get();

  if (!snapshot.exists) {
    print("No data found for complaint ID: ${widget.id}");
    return;
  }

  final data = snapshot.value as Map;

  // ✅ Debug print
  print("Fetched complaint data: $data");

  // ✅ Handle 'images' field that can be either List or String
  List<String>? base64ImgList;
  final imagesData = data['images'];

  if (imagesData != null) {
    if (imagesData is List) {
      base64ImgList = imagesData.cast<String>();
    } else if (imagesData is String) {
      base64ImgList = [imagesData]; // single image case
    }
  }

  final lastUpdatedMillis = data['lastUpdated'] ?? widget.timestamp;
  final status = data['status'] ?? 'New';

  final DateTime lastUpdatedDate = DateTime.fromMillisecondsSinceEpoch(lastUpdatedMillis ?? 0);
  final now = DateTime.now();
  final differenceInDays = now.difference(lastUpdatedDate).inDays;

  if (status != 'Completed' && differenceInDays >= 15) {
    await ref.update({
      'status': 'Overdue',
      'lastUpdated': DateTime.now().millisecondsSinceEpoch,
    });

    setState(() {
      currentStatus = 'Overdue';
      lastUpdated = DateTime.now().millisecondsSinceEpoch;
      base64Images = base64ImgList;
      currentAddress = data['address'] ?? widget.address;
    });
  } else {
    setState(() {
      base64Images = base64ImgList;
      currentAddress = data['address'] ?? widget.address;
      currentStatus = status;
      lastUpdated = lastUpdatedMillis;
    });
  }

  print("✅ Final base64Images length: ${base64Images?.length ?? 0}");
}

void _showFullScreenImage(String imageBase64) {
  final imageBytes = base64Decode(imageBase64);
  
  showDialog(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          InteractiveViewer(
            panEnabled: true,
            minScale: 0.5,
            maxScale: 4.0,
            child: Image.memory(
              imageBytes,
              fit: BoxFit.contain,
            ),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    ),
  );
}


void _showStatusOptions() {
  showModalBottomSheet(
    context: context,
    builder: (context) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.timelapse, color: Colors.brown),
            title: const Text('In progress'),
            trailing: currentStatus == 'In progress'
                ? const Icon(Icons.check, color: Colors.green)
                : null,
            onTap: () {
              Navigator.pop(context);
              _showStatusChangeDialog('In progress'); // स्टेटस अपडेट करें
            },
          ),
          ListTile(
            leading: const Icon(Icons.check_circle, color: Colors.green),
            title: const Text('Completed'),
            trailing: currentStatus == 'Completed'
                ? const Icon(Icons.check, color: Colors.green)
                : null,
            onTap: () {
              Navigator.pop(context);
              _showStatusChangeDialog('Completed'); // स्टेटस अपडेट करें
            },
          ),
        ],
      );
    },
  );
}
Future<void> deleteComment(String commentKey) async {
  if (widget.id == null) return;
  
  // Check permissions
  final isAdmin = (widget.userRole ?? '').toLowerCase() == 'admin';
  final complaintWard = (widget.ward ?? '').toLowerCase();
  final userWard = (widget.userWard ?? '').toLowerCase();
  
  // User can delete if:
  // 1. They're admin, OR
  // 2. They're in the same ward as the complaint and wards are not empty
  final canDelete = isAdmin || 
      (complaintWard == userWard && 
       complaintWard.isNotEmpty && 
       userWard.isNotEmpty);
  
  if (!canDelete) {
    print('User does not have permission to delete comments');
    return;
  }
  
  // User has permission - proceed with deletion
  final ref = FirebaseDatabase.instance.ref('complaints/${widget.id}/comments/$commentKey');
  await ref.remove();
  // You might want to call fetchComments() or similar here to refresh the UI
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

  @override
  Widget build(BuildContext context) {
     _debugPrintPermissions();
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
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 5),
              if (widget.id != null) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 40, 30, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "ID:${widget.id!}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
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
                     // Replace your status widget with this:
InkWell(
  onTap: canChangeStatus ? _showStatusOptions : null, // Disable if not allowed
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        "Status: ",
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 18,
          color: Colors.brown,
        ),
      ),
      const SizedBox(width: 30),
      Row(
        children: [
          Icon(
            currentStatus == 'Completed' 
              ? Icons.check_circle 
              : Icons.timelapse,
            color: currentStatus == 'Completed' 
              ? Colors.green 
              : Colors.orange,
            size: 22,
          ),
          const SizedBox(width: 4),
          Text(
            currentStatus,
            style: TextStyle(
              fontSize: 17,
              color: canChangeStatus ? Colors.black87 : Colors.grey,
            ),
          ),
          if (canChangeStatus) // Only show dropdown arrow if allowed
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, color: Colors.brown),
        ],
      ),
    ],
  ),
),
                      

                    // Title Label
Padding(
  padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Title: ',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.brown,
        ),
      ),
       const SizedBox(width: 50), 
      Expanded(
        child: Text(
          widget.template,
          style: const TextStyle(
            fontSize: 16, // You can keep it 24 if you want bigger text
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
          overflow: TextOverflow.visible,
          softWrap: true,
        ),
      ),
    ],
  ),
),



// Description Label
Padding(
  padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Details: ',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.brown,
        ),
      ),
       const SizedBox(width: 30), 
      Expanded(
        child: Text(
          widget.text,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.black87,
          ),
          softWrap: true,
        ),
      ),
    ],
  ),
),


                      
const SizedBox(height: 15),
                      
                     

                      // Created on
                     // Address
Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    const Text(
      "Address: ",
      style: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 18,
        color: Colors.brown,
      ),
    ),
    const SizedBox(width: 17),
    Expanded(
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            fontSize: 17,
            color: Colors.black87,
          ),
          children: [
            TextSpan(text: currentAddress),
            WidgetSpan(
              child: GestureDetector(
                onTap: _openMapWithLatLng,
                child: const Padding(
                  padding: EdgeInsets.only(left: 8.0),
                  child: Icon(Icons.location_on, color: Colors.red, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  ],
),

const SizedBox(height: 10), 

// Created On
if (widget.timestamp != null)...[
  _detailRow("Created on", formatDateSmart(widget.timestamp!)),

],
                      // Last Updated
                      if (lastUpdated != null) ...[
      const SizedBox(height: 10),
      _detailRow("Last Updated", formatDateSmart(lastUpdated!)),
    ],
 
 
 
 const SizedBox(height: 15),
base64Images != null && base64Images!.isNotEmpty
    ? Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 0.0, bottom: 16.0),
            child: Text(
              "Uploaded Images",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.brown,
              ),
            ),
          ),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: base64Images!.length,
              itemBuilder: (context, index) {
                final imageBytes = base64Decode(base64Images![index]);
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: GestureDetector(
                    onTap: () => _showFullScreenImage(base64Images![index]),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.5),
                            spreadRadius: 2,
                            blurRadius: 5,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.memory(
                          imageBytes,
                          fit: BoxFit.cover,
                          width: MediaQuery.of(context).size.width / 2 - 24,
                          height: 100,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      )
    : const Text("No images available."),
                      // Comments Section
                      const SizedBox(height: 20),
                      const Text(
  "Comments",
  style: TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: Colors.brown,
  ),
),
const SizedBox(height: 10),

if (isLoading)
  const Center(child: CircularProgressIndicator())
else if (comments.isEmpty)
  const Text("No comments yet.")
else
  ...comments.map((comment) {
    final timestamp = comment['timestamp'] as int;
    final formattedTime = formatDateSmart(timestamp);

    return Dismissible(
      key: Key(comment['key']),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        // First check permissions before allowing dismiss
        final isAdmin = (widget.userRole ?? '').toLowerCase() == 'admin';
        final complaintWard = (widget.ward ?? '').toLowerCase();
        final userWard = (widget.userWard ?? '').toLowerCase();
        final canDelete = isAdmin || 
            (complaintWard == userWard && 
             complaintWard.isNotEmpty && 
             userWard.isNotEmpty);

        if (!canDelete) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("You can only delete comments from your ward"),
              duration: Duration(seconds: 2),
            ),
          );
          return false; // Prevent dismissal
        }
        return true; // Allow dismissal
      },
      onDismissed: (direction) async {
        await deleteComment(comment['key']);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Comment deleted'),
            duration: Duration(seconds: 1),
          ),
        );
      },
                            child: Card(
                              color: Colors.transparent,
                              elevation: 0,
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      margin: const EdgeInsets.only(right: 8),
                                      child: (comment['role']?.toString().toLowerCase() == 'admin')
                                          ? buildAdminBadge(comment['userName'] ?? 'A')
                                          : buildUserBadge(comment['userName'] ?? 'U'),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
RichText(
  text: TextSpan(
    children: [
      TextSpan(
        text: "${comment['userName']} ",
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
      TextSpan(
        text: getDisplayRole(comment['role']),
        style: const TextStyle(
          fontSize: 12,
          color: Colors.grey,
        ),
      ),
    ],
  ),
),


const SizedBox(height: 4),
Text(
  comment['text']!,
  style: const TextStyle(
    fontSize: 16,
    color: Colors.black87,
  ),
),
const SizedBox(height: 4),
Text(
  formattedTime,
  style: const TextStyle(
    fontSize: 12,
    color: Colors.grey,
  ),
),

                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      const SizedBox(height: 10),
                      
                      // Comment Input
       Row(
  children: [
    Expanded(
      child: TextField(
        controller: _commentController,
        enabled: canComment, // Use updated canComment getter
        decoration: InputDecoration(
          hintText: canComment ? "Write a comment..." : "Comments disabled for this ward",
          border: const OutlineInputBorder(),
          hintStyle: TextStyle(
            color: canComment ? Colors.grey : Colors.grey.withOpacity(0.5),
          ),
        ),
        onTap: () {
          if (!canComment) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('You can only comment on complaints from your ward.')),
            );
          }
        },
      ),
    ),
    const SizedBox(width: 8),
    IconButton(
      icon: Icon(
        Icons.send,
        color: canComment ? Colors.brown : Colors.grey.withOpacity(0.5),
      ),
      onPressed: canComment ? _sendComment : null, // Disable button if !canComment
    ),
  ],
)
                      
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "$label: ",
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.brown,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  Widget buildAdminBadge(String name) {
    final display = (name.isNotEmpty) ? name[0].toUpperCase() : "?";
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: 25,
          backgroundColor: Colors.red,
          child: Text(
            display,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        Positioned(
          top: -4,
          right: -4,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.star,
              size: 16,
              color: Colors.amber,
            ),
          ),
        ),
      ],
    );
  }

  Widget buildUserBadge(String name) {
    final display = (name.isNotEmpty) ? name[0].toUpperCase() : "?";
    return CircleAvatar(
      radius: 22,
      backgroundColor: Colors.blue,
      child: Text(
        display,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
    );
  }
} 