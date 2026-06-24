import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StorageService {
  static SupabaseClient get _client => Supabase.instance.client;

  static Future<String?> uploadImage({
    required String bucket,
    required String path,
    required XFile image,
  }) async {
    try {
      final bytes = await image.readAsBytes();
      await _client.storage.from(bucket).uploadBinary(
        path,
        bytes,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
      );
      // supabase_flutter v2: getPublicUrl returns a String directly
      return _client.storage.from(bucket).getPublicUrl(path);
    } catch (e) {
      return null;
    }
  }
}
