import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'caption_page.dart';

class CreatePage extends StatefulWidget {
  const CreatePage({super.key});

  @override
  State<CreatePage> createState() => _CreatePageState();
}

class _CreatePageState extends State<CreatePage> {
  final ImagePicker _picker = ImagePicker();
  List<File> _selected = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pickImages();
    });
  }

  Future<void> _pickImages() async {
    final images = await _picker.pickMultiImage(
      imageQuality: 85,
      limit: 4,
    );

    if (images.isEmpty) return;

    final files = images.map((e) => File(e.path)).toList();

    if (files.length > 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You can select up to 4 images")),
      );
      return;
    }

    // 🔥 GO DIRECTLY TO CAPTION PAGE
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CaptionPage(
            images: files,
            isBusiness: false, // replace with role check later
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Empty scaffold — user never stays here
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
