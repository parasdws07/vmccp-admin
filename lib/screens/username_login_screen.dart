import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_database/firebase_database.dart';
import 'login_screen.dart';
import 'dashboardscreen.dart';

class UsernameLoginScreen extends StatelessWidget {
  const UsernameLoginScreen({super.key});

  Future<void> saveUserInfo(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("loggedInUserId", userData['userId'] ?? '');
    await prefs.setString("name", userData['name'] ?? '');
    await prefs.setString("role", userData['role'] ?? '');
    await prefs.setString("wardName", userData['wardName'] ?? '');
    await prefs.setString("wardNo", userData['wardNo'] ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final TextEditingController usernameController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();
    final ValueNotifier<bool> obscurePassword = ValueNotifier<bool>(true);

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
            FadeInUp(
              duration: const Duration(milliseconds: 1000),
              child: Padding(
                padding: const EdgeInsets.only(left: 20),
                child: Image.asset(
                  'assets/img/vmccp.png',
                  height: 100,
                  width: 100,
                ),
              ),
            ),
            const SizedBox(height: 20),
            FadeInUp(
              duration: const Duration(milliseconds: 1000),
              child: Padding(
                padding: const EdgeInsets.only(left: 20),
                child: const Text(
                  "Login with Username",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                  ),
                ),
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
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(30),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FadeInUp(
                        duration: const Duration(milliseconds: 1000),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 10,
                                offset: Offset(0, 5),
                              )
                            ],
                          ),
                          child: TextField(
                            controller: usernameController,
                            decoration: const InputDecoration(
                              labelText: "Username",
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 15),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      FadeInUp(
                        duration: const Duration(milliseconds: 1000),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 10,
                                offset: Offset(0, 5),
                              )
                            ],
                          ),
                          child: ValueListenableBuilder<bool>(
                            valueListenable: obscurePassword,
                            builder: (context, value, child) {
                              return TextField(
                                controller: passwordController,
                                obscureText: value,
                                decoration: InputDecoration(
                                  labelText: "Password",
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 15),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      value ? Icons.visibility : Icons.visibility_off,
                                      color: Colors.grey,
                                    ),
                                    onPressed: () {
                                      obscurePassword.value = !value;
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      FadeInUp(
                        duration: const Duration(milliseconds: 1000),
                        child: ElevatedButton(
                          onPressed: () async {
                            final username = usernameController.text.trim();
                            final password = passwordController.text.trim();

                            if (username.isEmpty || password.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Please enter both username and password")),
                              );
                              return;
                            }

                            final isPhone = RegExp(r'^[0-9]{10}$').hasMatch(username);
                            if (isPhone) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Username must not be a phone number")),
                              );
                              return;
                            }

                            final DatabaseReference ref = FirebaseDatabase.instance.ref('memberLogin');
                            final DataSnapshot snapshot = await ref.get();

                            if (snapshot.exists) {
                              final data = snapshot.value as Map<dynamic, dynamic>;
                              Map<String, dynamic>? matchedUser;

                              for (var entry in data.entries) {
                                final user = entry.value as Map<dynamic, dynamic>;
                                if (user['userId'] == username && user['password'] == password) {
                                  matchedUser = Map<String, dynamic>.from(user);
                                  break;
                                }
                              }

                              if (matchedUser != null) {
                                await saveUserInfo(matchedUser);
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => DashboardScreen(userId: username),
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Invalid username or password")),
                                );
                              }
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Unable to fetch user data")),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.brown[300],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(50),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                          ),
                          child: const Text(
                            "Login",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      FadeInUp(
                        duration: const Duration(milliseconds: 1000),
                        child: const Text(
                          "or",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 20,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      FadeInUp(
                        duration: const Duration(milliseconds: 1000),
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const LoginPage(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.brown[300],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(50),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                          ),
                          child: const Text(
                            "Login with Phone Number",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
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
}