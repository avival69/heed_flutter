import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PendingVerificationPage extends StatelessWidget {
  const PendingVerificationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.mark_email_read, size: 80, color: Colors.orange),
              const SizedBox(height: 20),
              const Text(
                "Verification Pending",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                "Your business account has been created successfully. "
                "Our admin team is reviewing your details. "
                "You will receive an email once your account is verified.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
              const SizedBox(height: 40),
              OutlinedButton(
                onPressed: () {
                  FirebaseAuth.instance.signOut();
                  context.go('/login');
                },
                child: const Text("Back to Login"),
              )
            ],
          ),
        ),
      ),
    );
  }
}