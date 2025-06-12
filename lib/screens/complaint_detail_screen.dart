import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class ComplaintDetailScreen extends StatefulWidget {
  final String area;
  final String status;
  final String text;
  final String? id;

  const ComplaintDetailScreen({
    super.key,
    required this.area,
    required this.status,
    required this.text,
    this.id,
  });

  @override
  State<ComplaintDetailScreen> createState() => _ComplaintDetailScreenState();
}

class _ComplaintDetailScreenState extends State<ComplaintDetailScreen> {
  List<Map<String, String>> comments = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchComments();
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
      final ref = FirebaseDatabase.instance.ref('complaints/${widget.id}/comments');
      final snapshot = await ref.get();
      if (snapshot.exists) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          comments = data.values
              .map((e) => {
                    'text': (e as Map)['text']?.toString() ?? '',
                    'userName': (e as Map)['userName']?.toString() ?? 'Unknown',
                  })
              .where((e) => e['text']!.isNotEmpty)
              .toList();
          isLoading = false;
        });
      } else {
        setState(() {
          comments = [];
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        comments = [];
        isLoading = false;
      });
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 80),
            Padding(
              padding: const EdgeInsets.only(left: 20),
              child: Image.asset(
                'assets/img/vmccp.png',
                height: 80,
                width: 80,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Container(
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
                      const SizedBox(height: 30),
                      Center(
                        child: Text(
                          "Complaint Details",
                          style: TextStyle(
                            color: Colors.brown[300],
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      _detailRow("Area", widget.area),
                      const SizedBox(height: 20),
                      _detailRow("Status", widget.status),
                      const SizedBox(height: 20),
                      _detailRow("Description", widget.text),
                      if (widget.id != null) ...[
                        const SizedBox(height: 20),
                        _detailRow("Complaint ID", widget.id!),
                      ],
                      const SizedBox(height: 30),
                      const Text(
                        "Comments",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.brown,
                        ),
                      ),
                      const SizedBox(height: 0),
                      Expanded(
                        child: isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : comments.isEmpty
                                ? const Text("No comments yet.")
                                : ListView.builder(
                                    itemCount: comments.length,
                                    itemBuilder: (context, index) {
                                      return Card(
                                        margin: const EdgeInsets.symmetric(vertical: 6),
                                        elevation: 2,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.all(12.0),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                comments[index]['userName']!,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                comments[index]['text']!,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.brown[300],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(50),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            "Back",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
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
              fontWeight: FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }
}