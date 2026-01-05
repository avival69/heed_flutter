import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';

import '../services/db.dart';
import '../services/cloudflare.dart';

class CaptionPage extends StatefulWidget {
  final List<File> images;
  final bool isBusiness;

  const CaptionPage({
    super.key,
    required this.images,
    required this.isBusiness,
  });

  @override
  State<CaptionPage> createState() => _CaptionPageState();
}

class _CaptionPageState extends State<CaptionPage> {
  final PageController _pageController =
      PageController(viewportFraction: 0.85);

  int selectedIndex = 0;

  final _title = TextEditingController();
  final _caption = TextEditingController();
  final _price = TextEditingController();
  final _tagController = TextEditingController();

  final List<String> tags = [];

  bool allowComments = true;
  bool allowChat = true;
  bool showLikes = true;
  bool loading = false;

  late List<File> images;

  @override
  void initState() {
    super.initState();
    images = List.from(widget.images);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _title.dispose();
    _caption.dispose();
    _price.dispose();
    _tagController.dispose();
    super.dispose();
  }

  // ---------------- IMAGE ACTIONS (RESTORED) ----------------

  void removeImage(int index) {
    setState(() {
      images.removeAt(index);
      if (selectedIndex >= images.length) {
        selectedIndex = images.isEmpty ? 0 : images.length - 1;
      }
    });
  }

  Future<void> addMoreImages() async {
    final picker = ImagePicker();
    final more = await picker.pickMultiImage(
      imageQuality: 85,
      limit: 4 - images.length,
    );

    if (more.isNotEmpty) {
      setState(() {
        images.addAll(more.map((e) => File(e.path)));
      });
    }
  }

  // ---------------- IMAGE DIMENSIONS ----------------

  Future<Map<String, int>> _getImageSize(File file) async {
    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();

    return {
      "width": frame.image.width,
      "height": frame.image.height,
    };
  }

  // ---------------- POST ----------------

  Future<void> post() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || images.isEmpty) return;

    setState(() => loading = true);

    try {
      final List<Map<String, dynamic>> uploadedImages = [];

      // Cover image dimensions
      final coverSize = await _getImageSize(images.first);

      for (final img in images) {
        final size = await _getImageSize(img);
        final meta = await CloudflareService().uploadImage(img);

        uploadedImages.add({
          "id": meta["id"],
          "preview": meta["preview"],
          "original": meta["original"],
          "width": size["width"],
          "height": size["height"],
        });
      }

      await DatabaseService().createPost(
        uid: user.uid,
        images: uploadedImages,
        width: coverSize["width"]!,
        height: coverSize["height"]!,
        title: _title.text.trim(),
        caption: _caption.text.trim(),
        price: _price.text.trim().isEmpty ? null : _price.text.trim(),
        tags: tags,
        allowComments: allowComments,
        allowChat: allowChat,
        showLikes: showLikes,
      );

      if (mounted) context.go('/home');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        context.go('/home');
        return false;
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: const Text("New Post"),
          leading: BackButton(onPressed: () => context.go('/home')),
          actions: [
            TextButton(
              onPressed: loading ? null : post,
              child: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text("Post"),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _imageCarousel(),
              _dots(),
              _section("Title", "Add a title (optional)", _title),
              _section("Description", "Write a caption…", _caption, max: 4),
              _section(
                "Price",
                "Optional",
                _price,
                keyboard: TextInputType.number,
              ),
              _tags(),
              const Divider(height: 32),
              _engagement(),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- IMAGE CAROUSEL ----------------

  Widget _imageCarousel() {
    return Container(
      color: const Color(0xFFF5F5F5),
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: SizedBox(
        height: 280,
        child: PageView.builder(
          controller: _pageController,
          itemCount: images.length + (images.length < 4 ? 1 : 0),
          onPageChanged: (i) => setState(() => selectedIndex = i),
          itemBuilder: (_, i) {
            if (i == images.length) return _addCard();

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.file(
                      images[i],
                      fit: BoxFit.contain,
                      width: double.infinity,
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: GestureDetector(
                      onTap: () => removeImage(i),
                      child: const CircleAvatar(
                        radius: 14,
                        backgroundColor: Colors.black54,
                        child: Icon(Icons.close,
                            size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _dots() {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          images.length,
          (i) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: selectedIndex == i ? 6 : 5,
            height: selectedIndex == i ? 6 : 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  selectedIndex == i ? Colors.black : Colors.grey.shade400,
            ),
          ),
        ),
      ),
    );
  }

  Widget _addCard() {
    return GestureDetector(
      onTap: addMoreImages,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade300),
          color: const Color(0xFFF1F5F9),
        ),
        child: const Center(
          child: Icon(Icons.add, size: 40, color: Colors.grey),
        ),
      ),
    );
  }
  // ---------------- FORM ----------------

  Widget _section(
    String title,
    String hint,
    TextEditingController c, {
    int max = 1,
    TextInputType keyboard = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          TextField(
            controller: c,
            maxLines: max,
            keyboardType: keyboard,
            decoration: InputDecoration(
              hintText: hint,
              filled: true,
              fillColor: const Color(0xFFEDEDED),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tags() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("Tags",
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: tags
              .map((t) => Chip(
                    label: Text(t),
                    onDeleted: () => setState(() => tags.remove(t)),
                  ))
              .toList(),
        ),
        TextField(
          controller: _tagController,
          decoration:
              const InputDecoration(hintText: "Add a tag & press enter"),
          onSubmitted: (v) {
            if (v.isNotEmpty) {
              setState(() {
                tags.add(v.trim());
                _tagController.clear();
              });
            }
          },
        ),
      ]),
    );
  }

  Widget _engagement() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text("Engagement settings",
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        SwitchListTile(
          value: allowComments,
          onChanged: (v) => setState(() => allowComments = v),
          title: const Text("Allow comments"),
        ),
        SwitchListTile(
          value: allowChat,
          onChanged: (v) => setState(() => allowChat = v),
          title: const Text("Allow chat"),
        ),
        SwitchListTile(
          value: showLikes,
          onChanged: (v) => setState(() => showLikes = v),
          title: const Text("Show likes"),
        ),
      ]),
    );
  }

  Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
      ),
      child:
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 12)),
    );
  }

  void _preview(File image) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        child: InteractiveViewer(
          child: Image.file(image),
        ),
      ),
    );
  }
}
