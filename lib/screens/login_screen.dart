import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'otp.dart'; // Ensure you have an `OtpPage` widget defined in your project
import 'username_login_screen.dart';
import 'dashboardscreen.dart'; // Import your DashboardScreen

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final TextEditingController phoneController = TextEditingController();

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const SizedBox(height: 80),
            Padding(
              padding: const EdgeInsets.only(left: 20),
              child: FadeInUp(
                duration: const Duration(milliseconds: 1000),
                child: Image.asset(
                  'assets/img/vmccp.png', // Ensure this image exists in your assets folder
                  height: 100,
                  width: 100,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FadeInUp(
                    duration: const Duration(milliseconds: 1300),
                    child: const Text(
                      "Your Mobile No",
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ),
                ],
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
                    children: <Widget>[
                      const SizedBox(height: 60),
                      FadeInUp(
                        duration: const Duration(milliseconds: 1400),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26, // Changed shadow color to black with some transparency
                                blurRadius: 20,
                                offset: Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            child: TextField(
                              controller: phoneController,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                hintText: "Phone number",
                                hintStyle: TextStyle(color: Colors.grey),
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      FadeInUp(
                        duration: const Duration(milliseconds: 1600),
                        child: MaterialButton(
                          onPressed: () async {
                            final rawPhone = phoneController.text.trim();
                            final phoneNumber = '+91$rawPhone'; // Add country code

                            if (rawPhone.isEmpty || rawPhone.length != 10) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Please enter a valid 10-digit phone number")),
                              );
                              return;
                            }

                            try {
                              await FirebaseAuth.instance.verifyPhoneNumber(
                                phoneNumber: phoneNumber,
                                verificationCompleted: (PhoneAuthCredential credential) {
                                  // Optional auto-retrieval
                                },
                                verificationFailed: (FirebaseAuthException e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(e.message ?? "Verification failed")),
                                  );
                                },
                                codeSent: (String verificationId, int? resendToken) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => OtpPage(
                                        phoneNumber: phoneNumber,
                                        verificationId: verificationId, // Pass the verificationId here
                                      ),
                                    ),
                                  );
                                },
                                codeAutoRetrievalTimeout: (String verificationId) {},
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Error: ${e.toString()}")),
                              );
                            }
                          },
                          height: 50,
                          color: Colors.brown[300],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: const Center(
                            child: Text(
                              "Get OTP",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      FadeInUp(
                        duration: const Duration(milliseconds: 1800),
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
                        duration: const Duration(milliseconds: 2000),
                        child: MaterialButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const UsernameLoginScreen(),
                              ),
                            );
                          },
                          height: 50,
                          color: Colors.brown[300],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: const Center(
                            child: Text(
                              "Login with Username",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 50),
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
