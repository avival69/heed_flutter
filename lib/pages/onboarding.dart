import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../services/db.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../services/db.dart';
import '../services/cloudflare.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  // --- SIGNUP CONTROLLERS ---
  final signupEmailController = TextEditingController();
  final signupPasswordController = TextEditingController();
  bool _signupLoading = false;
  String _signupError = '';

  final PageController _pageController = PageController();
  int _currentStep = 0;
  String _accountType = "general";
  bool _isLoading = false;

  // --- IMAGE PICKER ---
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  // --- CONTROLLERS (General) ---
  final name = TextEditingController();
  final age = TextEditingController();
  final location = TextEditingController();
  final username = TextEditingController();
  final bio = TextEditingController();
  String gender = "Male";
  final interests = ["Fashion", "Tech", "Art", "Travel", "Food", "Decor", "Photography", "Design"];
  final selectedInterests = <String>[];

  // --- CONTROLLERS (Business) ---
  final companyName = TextEditingController();
  final phone = TextEditingController();
  final gst = TextEditingController();
  final address = TextEditingController();
  final website = TextEditingController();
  final publicEmail = TextEditingController();
  String category = "Clothing";
  final categories = ["Clothing", "Decor", "Art", "Electronics", "Services"];

  // --- LOGIC ---
  void next() {
    if (_accountType == 'general' && _currentStep == 3 && mounted && ModalRoute.of(context)?.isCurrent == true) {
      final uname = username.text.trim();
      if (uname.length < 4) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Username must be at least 4 characters.")),
        );
        return;
      }
      FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: uname.toLowerCase())
          .get()
          .then((snap) {
        if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
        ScaffoldMessenger.of(context).clearSnackBars();
        if (snap.docs.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Username already taken.")),
          );
        } else {
          _pageController.nextPage(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
          );
          setState(() => _currentStep++);
        }
      });
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
    setState(() => _currentStep++);
  }

  Future<void> _signup() async {
    setState(() {
      _signupLoading = true;
      _signupError = '';
    });
    final email = signupEmailController.text.trim();
    final password = signupPasswordController.text.trim();
    print('Attempting signup with email: \x1B[32m$email\x1B[0m');
    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _signupError = 'Email and password cannot be empty.';
        _signupLoading = false;
      });
      return;
    }
    if (password.length < 6) {
      setState(() {
        _signupError = 'Password must be at least 6 characters.';
        _signupLoading = false;
      });
      return;
    }
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: password);
      setState(() {
        _signupLoading = false;
      });
      await Future.delayed(const Duration(milliseconds: 300));
      next();
    } on FirebaseAuthException catch (e) {
      print('FirebaseAuthException: \x1B[31m${e.code}: ${e.message}\x1B[0m');
      setState(() {
        if (e.code == 'email-already-in-use') {
          _signupError = 'Email already in use.';
        } else if (e.code == 'invalid-email') {
          _signupError = 'Invalid email address.';
        } else if (e.code == 'weak-password') {
          _signupError = 'Password is too weak.';
        } else {
          _signupError = 'Error: ${e.message}';
        }
        _signupLoading = false;
      });
    } catch (e) {
      print('Signup error: \x1B[31m$e\x1B[0m');
      setState(() {
        _signupError = 'Error: ${e.toString()}';
        _signupLoading = false;
      });
    }
  }

  Future<void> finish() async {
    final email = signupEmailController.text.trim();
    final password = signupPasswordController.text.trim();

    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please upload a Profile Picture")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email != email) {
        try {
          final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: password);
          user = cred.user;
        } on FirebaseAuthException catch (e) {
          if (e.code == 'email-already-in-use') {
            final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
            user = cred.user;
          } else {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Auth error: ${e.message}")));
            return;
          }
        }
      }
      final uid = user?.uid ?? 'dummy-uid';

      final imageData = await CloudflareService().uploadImage(_selectedImage!);
      String? r2Link = imageData['original'];
      r2Link ??= "https://cdn-icons-png.flaticon.com/512/149/149071.png";

      if (_accountType == 'general') {
        await DatabaseService().createGeneralUser(
          uid: uid,
          email: email,
          name: name.text.trim(),
          age: int.tryParse(age.text) ?? 18,
          gender: gender,
          location: location.text.trim(),
          username: username.text.trim(),
          bio: bio.text.trim(),
          profileImageUrl: r2Link,
          interests: selectedInterests,
        );
      } else {
        await DatabaseService().createBusinessUser(
          uid: uid,
          email: email,
          companyName: companyName.text.trim(),
          phone: phone.text.trim(),
          gst: gst.text.trim(),
          address: address.text.trim(),
          website: website.text.trim(),
          category: category,
          publicEmail: publicEmail.text.trim(),
          profileImageUrl: r2Link,
        );
      }

      if (mounted) context.go('/');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _selectedImage = File(image.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_currentStep > 0) {
          _pageController.previousPage(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
          );
          setState(() => _currentStep--);
          return false;
        } else {
          if (mounted) {
            context.go('/login?from=onboarding');
          }
          return false;
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: SafeArea(
          child: Column(
            children: [
              _header(),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _stepSignup(), // 0
                    _stepAccountType(), // 1
                    // GENERAL FLOW
                    if (_accountType == 'general') ...[
                      _stepProfilePicAndBasic(), // 2
                      _stepGeneralSocial(), // 3
                      _stepGeneralInterests(), // 4
                    ],
                    // BUSINESS FLOW
                    if (_accountType == 'business') ...[
                      _stepBusinessProfile(), // 2 (Pic + Basic)
                      _stepBusinessDetails(), // 3 (Web, Email, Category)
                      _stepBusinessLegal(), // 4 (GST, Address)
                    ]
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGETS ---
  // --- SIGNUP STEP ---
  Widget _stepSignup() {
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Create Account", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text("Start your journey with Heed", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 40),
          TextField(
            controller: signupEmailController,
            decoration: InputDecoration(
              labelText: "Email",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: signupPasswordController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: "Password",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 24),
          if (_signupError.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_signupError, style: const TextStyle(color: Colors.red)),
            ),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _signupLoading ? null : _signup,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _signupLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Sign Up & Continue", style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    int totalSteps = _accountType == 'general' ? 4 : 4;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Setup Profile", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (_currentStep + 1) / totalSteps,
            backgroundColor: Colors.grey[200],
            color: Colors.black,
            borderRadius: BorderRadius.circular(10),
          ),
        ],
      ),
    );
  }

  // --- 0. ACCOUNT TYPE ---
  Widget _stepAccountType() {
    return _card(
      Column(
        children: [
          const Text("Who are you?", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _typeOption("General User", "Browse & Share ideas.", Icons.person, "general"),
          const SizedBox(height: 16),
          _typeOption("Business Account", "Sell & Grow Brand.", Icons.store, "business"),
          const Spacer(),
          _primaryButton("Next", next),
        ],
      ),
    );
  }

  // --- 1. GENERAL: PIC & BASIC ---
  Widget _stepProfilePicAndBasic() {
    return _card(
      SingleChildScrollView(
        child: Column(
          children: [
            _imagePickerWidget("Upload Profile Photo"),
            const SizedBox(height: 20),
            _field(name, "Full Name"),
            Row(
              children: [
                Expanded(child: _field(age, "Age", keyboard: TextInputType.number)),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: gender,
                        isExpanded: true,
                        items: ["Male", "Female", "Other"].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                        onChanged: (v) => setState(() => gender = v!),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            _field(location, "Location"),
            _primaryButton("Next", next),
          ],
        ),
      ),
    );
  }

  // --- 2. GENERAL: SOCIAL ---
  Widget _stepGeneralSocial() {
    return _card(
      Column(
        children: [
          const Text("Create Identity", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _field(username, "Username (@user)"),
          _field(bio, "Bio (Short description)"),
          const Spacer(),
          _primaryButton("Next", next),
        ],
      ),
    );
  }

  // --- 3. GENERAL: INTERESTS ---
  Widget _stepGeneralInterests() {
    return _card(
      Column(
        children: [
          const Text("Interests", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: interests.map((e) {
              final active = selectedInterests.contains(e);
              return ChoiceChip(
                label: Text(e),
                selected: active,
                selectedColor: Colors.black,
                labelStyle: TextStyle(color: active ? Colors.white : Colors.black),
                onSelected: (_) => setState(() => active ? selectedInterests.remove(e) : selectedInterests.add(e)),
              );
            }).toList(),
          ),
          const Spacer(),
          _primaryButton("Finish", finish, isLoading: _isLoading),
        ],
      ),
    );
  }

  // --- BUSINESS: 1. LOGO & NAME ---
  Widget _stepBusinessProfile() {
    return _card(
      SingleChildScrollView(
        child: Column(
          children: [
            _imagePickerWidget("Upload Brand Logo"),
            const SizedBox(height: 20),
            _field(companyName, "Company Name"),
            _field(phone, "Contact Phone", keyboard: TextInputType.phone),
            _primaryButton("Next", next),
          ],
        ),
      ),
    );
  }

  // --- BUSINESS: 2. DETAILS ---
  Widget _stepBusinessDetails() {
    return _card(
      Column(
        children: [
          const Text("Business Details", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _field(website, "Website (https://...)"),
          _field(publicEmail, "Public Contact Email"),
          Container(
             padding: const EdgeInsets.symmetric(horizontal: 12),
             margin: const EdgeInsets.only(bottom: 16),
             decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)),
             child: DropdownButtonHideUnderline(
               child: DropdownButton<String>(
                 value: category,
                 isExpanded: true,
                 items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                 onChanged: (v) => setState(() => category = v!),
               ),
            ),
          ),
          const Spacer(),
          _primaryButton("Next", next),
        ],
      ),
    );
  }

  // --- BUSINESS: 3. LEGAL ---
  Widget _stepBusinessLegal() {
    return _card(
      Column(
        children: [
          const Text("Verification", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _field(gst, "GST Number"),
          _field(address, "Registered Address", maxLines: 3),
          const Spacer(),
          _primaryButton("Submit Application", finish, isLoading: _isLoading),
        ],
      ),
    );
  }

  // --- REUSED COMPONENTS ---

  Widget _imagePickerWidget(String label) {
    return GestureDetector(
      onTap: _pickImage,
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: Colors.grey[200],
            backgroundImage: _selectedImage != null ? FileImage(_selectedImage!) : null,
            child: _selectedImage == null ? const Icon(Icons.add_a_photo, size: 30, color: Colors.grey) : null,
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _typeOption(String title, String subtitle, IconData icon, String value) {
    bool isSelected = _accountType == value;
    return GestureDetector(
      onTap: () => setState(() => _accountType = value),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? Colors.black : Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(icon, size: 30, color: isSelected ? Colors.white : Colors.black),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.black)),
              Text(subtitle, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white70 : Colors.grey)),
            ])),
            if (isSelected) const Icon(Icons.check_circle, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _card(Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, 10))]),
        child: child,
      ),
    );
  }

  Widget _field(TextEditingController c, String label, {TextInputType keyboard = TextInputType.text, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(controller: c, keyboardType: keyboard, maxLines: maxLines, decoration: InputDecoration(labelText: label, filled: true, fillColor: const Color(0xFFF1F5F9), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
    );
  }

  Widget _primaryButton(String text, VoidCallback onTap, {bool isLoading = false}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : onTap,
        style: ElevatedButton.styleFrom(backgroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        child: isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
      setState(() {
        _signupLoading = true;
        _signupError = '';
      });
      final email = signupEmailController.text.trim();
      final password = signupPasswordController.text.trim();
      print('Attempting signup with email: \x1B[32m$email\x1B[0m');
      if (email.isEmpty || password.isEmpty) {
        setState(() {
          _signupError = 'Email and password cannot be empty.';
          _signupLoading = false;
        });
        return;
      }
      if (password.length < 6) {
        setState(() {
          _signupError = 'Password must be at least 6 characters.';
          _signupLoading = false;
        });
        return;
      }
      try {
        // Actually create the Firebase Auth user
        await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: password);
        // If successful, go to next onboarding step
        setState(() {
          _signupLoading = false;
        });
        await Future.delayed(const Duration(milliseconds: 300));
        next();
      } on FirebaseAuthException catch (e) {
        print('FirebaseAuthException: \x1B[31m${e.code}: ${e.message}\x1B[0m');
        setState(() {
          if (e.code == 'email-already-in-use') {
            _signupError = 'Email already in use.';
          } else if (e.code == 'invalid-email') {
            _signupError = 'Invalid email address.';
          } else if (e.code == 'weak-password') {
            _signupError = 'Password is too weak.';
          } else {
            _signupError = 'Error: ${e.message}';
          }
          _signupLoading = false;
        });
      } catch (e) {
        print('Signup error: \x1B[31m$e\x1B[0m');
        setState(() {
          _signupError = 'Error: ${e.toString()}';
          _signupLoading = false;
        });
      }
          );
        } else {
          _pageController.nextPage(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
          );
          setState(() => _currentStep++);
        }
      });
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
    setState(() => _currentStep++);
  }

  Future<void> finish() async {
    final email = signupEmailController.text.trim();
    final password = signupPasswordController.text.trim();

    // VALIDATION: Image is mandatory
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please upload a Profile Picture")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Ensure user is signed in (create account if needed)
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email != email) {
        try {
          // Try to create the user
          final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: password);
          user = cred.user;
        } on FirebaseAuthException catch (e) {
          if (e.code == 'email-already-in-use') {
            // If already exists, sign in
            final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
            user = cred.user;
          } else {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Auth error: ${e.message}")));
            return;
          }
        }
      }
      final uid = user?.uid ?? 'dummy-uid';

      // 2. Upload Image to Cloudflare R2
      final imageData = await CloudflareService().uploadImage(_selectedImage!);
      String? r2Link = imageData['original'];
      r2Link ??= "https://cdn-icons-png.flaticon.com/512/149/149071.png";

      // 3. Save Data to Firestore
      if (_accountType == 'general') {
        await DatabaseService().createGeneralUser(
          uid: uid,
          email: email,
          name: name.text.trim(),
          age: int.tryParse(age.text) ?? 18,
          gender: gender,
          location: location.text.trim(),
          username: username.text.trim(),
          bio: bio.text.trim(),
          profileImageUrl: r2Link,
          interests: selectedInterests,
        );
      } else {
        await DatabaseService().createBusinessUser(
          uid: uid,
          email: email,
          companyName: companyName.text.trim(),
          phone: phone.text.trim(),
          gst: gst.text.trim(),
          address: address.text.trim(),
          website: website.text.trim(),
          category: category,
          publicEmail: publicEmail.text.trim(),
          profileImageUrl: r2Link,
        );
      }

      // 4. Redirect to home after finishing onboarding
      if (mounted) context.go('/');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_currentStep > 0) {
          _pageController.previousPage(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
          );
          setState(() => _currentStep--);
          return false;
        } else {
          if (mounted) {
            context.go('/login?from=onboarding');
          }
          return false;
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: SafeArea(
          child: Column(
            children: [
              _header(),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _stepSignup(), // 0
                    _stepAccountType(), // 1
                    // GENERAL FLOW
                    if (_accountType == 'general') ...[
                      _stepProfilePicAndBasic(), // 2
                      _stepGeneralSocial(), // 3
                      _stepGeneralInterests(), // 4
                    ],
                    // BUSINESS FLOW
                    if (_accountType == 'business') ...[
                      _stepBusinessProfile(), // 2 (Pic + Basic)
                      _stepBusinessDetails(), // 3 (Web, Email, Category)
                      _stepBusinessLegal(), // 4 (GST, Address)
                    ]
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGETS ---
  // --- SIGNUP STEP ---
  Widget _stepSignup() {
    return _card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Create Account", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text("Start your journey with Heed", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 40),
          TextField(
            controller: signupEmailController,
            decoration: InputDecoration(
              labelText: "Email",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: signupPasswordController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: "Password",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 24),
          if (_signupError.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_signupError, style: const TextStyle(color: Colors.red)),
            ),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _signupLoading ? null : _signup,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _signupLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Sign Up & Continue", style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    int totalSteps = _accountType == 'general' ? 4 : 4;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Setup Profile", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (_currentStep + 1) / totalSteps,
            backgroundColor: Colors.grey[200],
            color: Colors.black,
            borderRadius: BorderRadius.circular(10),
          ),
        ],
      ),
    );
  }

  // --- 0. ACCOUNT TYPE ---
  Widget _stepAccountType() {
    return _card(
      Column(
        children: [
          const Text("Who are you?", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _typeOption("General User", "Browse & Share ideas.", Icons.person, "general"),
          const SizedBox(height: 16),
          _typeOption("Business Account", "Sell & Grow Brand.", Icons.store, "business"),
          const Spacer(),
          _primaryButton("Next", next),
        ],
      ),
    );
  }

  // --- 1. GENERAL: PIC & BASIC ---
  Widget _stepProfilePicAndBasic() {
    return _card(
      SingleChildScrollView(
        child: Column(
          children: [
            _imagePickerWidget("Upload Profile Photo"),
            const SizedBox(height: 20),
            _field(name, "Full Name"),
            Row(
              children: [
                Expanded(child: _field(age, "Age", keyboard: TextInputType.number)),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: gender,
                        isExpanded: true,
                        items: ["Male", "Female", "Other"].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                        onChanged: (v) => setState(() => gender = v!),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            _field(location, "Location"),
            _primaryButton("Next", next),
          ],
        ),
      ),
    );
  }

  // --- 2. GENERAL: SOCIAL ---
  Widget _stepGeneralSocial() {
    return _card(
      Column(
        children: [
          const Text("Create Identity", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _field(username, "Username (@user)"),
          _field(bio, "Bio (Short description)"),
          const Spacer(),
          _primaryButton("Next", next),
        ],
      ),
    );
  }

  // --- 3. GENERAL: INTERESTS ---
  Widget _stepGeneralInterests() {
    return _card(
      Column(
        children: [
          const Text("Interests", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: interests.map((e) {
              final active = selectedInterests.contains(e);
              return ChoiceChip(
                label: Text(e),
                selected: active,
                selectedColor: Colors.black,
                labelStyle: TextStyle(color: active ? Colors.white : Colors.black),
                onSelected: (_) => setState(() => active ? selectedInterests.remove(e) : selectedInterests.add(e)),
              );
            }).toList(),
          ),
          const Spacer(),
          _primaryButton("Finish", finish, isLoading: _isLoading),
        ],
      ),
    );
  }

  // --- BUSINESS: 1. LOGO & NAME ---
  Widget _stepBusinessProfile() {
    return _card(
      SingleChildScrollView(
        child: Column(
          children: [
            _imagePickerWidget("Upload Brand Logo"),
            const SizedBox(height: 20),
            _field(companyName, "Company Name"),
            _field(phone, "Contact Phone", keyboard: TextInputType.phone),
            _primaryButton("Next", next),
          ],
        ),
      ),
    );
  }

  // --- BUSINESS: 2. DETAILS ---
  Widget _stepBusinessDetails() {
    return _card(
      Column(
        children: [
          const Text("Business Details", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _field(website, "Website (https://...)"),
          _field(publicEmail, "Public Contact Email"),
          Container(
             padding: const EdgeInsets.symmetric(horizontal: 12),
             margin: const EdgeInsets.only(bottom: 16),
             decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)),
             child: DropdownButtonHideUnderline(
               child: DropdownButton<String>(
                 value: category,
                 isExpanded: true,
                 items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                 onChanged: (v) => setState(() => category = v!),
               ),
             ),
          ),
          const Spacer(),
          _primaryButton("Next", next),
        ],
      ),
    );
  }

  // --- BUSINESS: 3. LEGAL ---
  Widget _stepBusinessLegal() {
    return _card(
      Column(
        children: [
          const Text("Verification", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _field(gst, "GST Number"),
          _field(address, "Registered Address", maxLines: 3),
          const Spacer(),
          _primaryButton("Submit Application", finish, isLoading: _isLoading),
        ],
      ),
    );
  }

  // --- REUSED COMPONENTS ---

  Widget _imagePickerWidget(String label) {
    return GestureDetector(
      onTap: _pickImage,
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: Colors.grey[200],
            backgroundImage: _selectedImage != null ? FileImage(_selectedImage!) : null,
            child: _selectedImage == null ? const Icon(Icons.add_a_photo, size: 30, color: Colors.grey) : null,
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _typeOption(String title, String subtitle, IconData icon, String value) {
    bool isSelected = _accountType == value;
    return GestureDetector(
      onTap: () => setState(() => _accountType = value),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? Colors.black : Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(icon, size: 30, color: isSelected ? Colors.white : Colors.black),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.black)),
              Text(subtitle, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white70 : Colors.grey)),
            ])),
            if (isSelected) const Icon(Icons.check_circle, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _card(Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, 10))]),
        child: child,
      ),
    );
  }

  Widget _field(TextEditingController c, String label, {TextInputType keyboard = TextInputType.text, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(controller: c, keyboardType: keyboard, maxLines: maxLines, decoration: InputDecoration(labelText: label, filled: true, fillColor: const Color(0xFFF1F5F9), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
    );
  }

  Widget _primaryButton(String text, VoidCallback onTap, {bool isLoading = false}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : onTap,
        style: ElevatedButton.styleFrom(backgroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        child: isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}