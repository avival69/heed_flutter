import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class CloudflareService {
  static const String uploadEndpoint =
      "https://heed-uploader.tuaswinkrishna.workers.dev";

  /// Uploads image via Worker
  /// Returns:
  /// {
  ///   preview: String,
  ///   original: String
  /// }
  Future<Map<String, dynamic>> uploadImage(File file) async {
    final request = http.MultipartRequest(
      "POST",
      Uri.parse(uploadEndpoint),
    );

    request.files.add(
      await http.MultipartFile.fromPath("file", file.path),
    );

    final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception("Upload failed: ${response.body}");
    }

    return jsonDecode(response.body);
  }

  /// Clear all cached images
  static Future<void> clearImageCache() async {
    await DefaultCacheManager().emptyCache();
  }
}
