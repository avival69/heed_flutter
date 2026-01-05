import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

class GalleryBottomSheet extends StatefulWidget {
  final List<AssetEntity> initiallySelected;

  const GalleryBottomSheet({super.key, required this.initiallySelected});

  @override
  State<GalleryBottomSheet> createState() => _GalleryBottomSheetState();
}

class _GalleryBottomSheetState extends State<GalleryBottomSheet> {
  List<AssetEntity> allPhotos = [];
  late List<AssetEntity> selected;

  @override
  void initState() {
    super.initState();
    selected = List.from(widget.initiallySelected);
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.isAuth) return;

    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.image,
    );

    final photos = await albums.first.getAssetListPaged(
      page: 0,
      size: 100,
    );

    setState(() => allPhotos = photos);
  }

  void _toggle(AssetEntity asset) {
    setState(() {
      if (selected.contains(asset)) {
        selected.remove(asset);
      } else if (selected.length < 4) {
        selected.add(asset);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, color: Colors.grey),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: allPhotos.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 2,
                crossAxisSpacing: 2,
              ),
              itemBuilder: (_, i) {
                final asset = allPhotos[i];
                final index = selected.indexOf(asset);

                return GestureDetector(
                  onTap: () => _toggle(asset),
                  child: Stack(
                    children: [
                      AssetEntityImage(asset, fit: BoxFit.cover),
                      if (index != -1)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: CircleAvatar(
                            radius: 10,
                            backgroundColor: Colors.black,
                            child: Text(
                              "${index + 1}",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: ElevatedButton(
                onPressed: selected.isEmpty
                    ? null
                    : () => Navigator.pop(context, selected),
                child: const Text("Done"),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
