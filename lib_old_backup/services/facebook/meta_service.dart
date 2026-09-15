import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import '../../models/facebook/meta_chat_model.dart';
import '../../models/facebook/meta_content_model.dart';
import '../supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MetaService {
  static const String _graphApiVersion = "v19.0";
  final SupabaseService _supabaseService = SupabaseService();
  Map<String, dynamic>? _cachedCredentials;

  Future<Map<String, dynamic>> _getCredentials() async {
    final userId = _supabaseService.currentUserId;
    if (userId == null) throw Exception("User not logged in");
    if (_cachedCredentials != null) return _cachedCredentials!;

    final response = await _supabaseService.client
        .from('user_api_settings')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
        
    if (response == null) throw Exception("Configure settings first.");
    _cachedCredentials = response;
    return response;
  }

  // ============== GET CONTENT ==============
  Future<List<MetaContent>> getContent(SocialPlatform platform, ContentType filter) async {
    final creds = await _getCredentials();
    final String? accessToken = creds['facebook_page_access_token'] ?? creds['facebook_user_access_token'];
    if (accessToken == null) return [];

    String url = '';
    if (platform == SocialPlatform.instagram) {
      final String? igId = creds['instagram_account_id'];
      if (igId == null) return [];
      url = filter == ContentType.story 
          ? 'https://graph.facebook.com/$_graphApiVersion/$igId/stories?fields=id,caption,media_type,media_url,thumbnail_url,like_count,comments_count&access_token=$accessToken'
          : filter == ContentType.mention
              ? 'https://graph.facebook.com/$_graphApiVersion/$igId/tags?fields=id,caption,media_type,media_url,thumbnail_url,like_count,comments_count&access_token=$accessToken'
              : 'https://graph.facebook.com/$_graphApiVersion/$igId/media?fields=id,caption,media_type,media_product_type,media_url,thumbnail_url,like_count,comments_count&access_token=$accessToken';
    } else {
      final String? pageId = creds['facebook_account_id'];
      if (pageId == null || filter == ContentType.story) return [];
      url = 'https://graph.facebook.com/$_graphApiVersion/$pageId/feed?fields=id,message,full_picture,source,likes.summary(true),comments.summary(true),created_time&access_token=$accessToken';
    }

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) return [];
      final data = json.decode(response.body);
      if (!data.containsKey('data')) return [];

      List<MetaContent> results = [];
      for (var item in data['data']) {
        ContentType itemType = ContentType.post;
        if (platform == SocialPlatform.instagram) {
          if (filter == ContentType.story) {
            itemType = ContentType.story;
          } else if (filter == ContentType.mention) itemType = ContentType.mention;
          else if (item['media_product_type'] == 'REELS') itemType = ContentType.reel;
          
          String img = item['thumbnail_url'] ?? item['media_url'] ?? '';
          String? vid = item['media_type'] == 'VIDEO' ? item['media_url'] : null;

          if (filter == itemType) {
            results.add(MetaContent(
              id: item['id'], platform: platform, type: itemType, imageUrl: img, videoUrl: vid,
              caption: item['caption'] ?? '', likes: item['like_count'] ?? 0, comments: item['comments_count'] ?? 0,
            ));
          }
        } else {
          results.add(MetaContent(
            id: item['id'], platform: platform, type: ContentType.post,
            imageUrl: item['full_picture'] ?? '', videoUrl: item['source'], caption: item['message'] ?? '',
            likes: item['likes']?['summary']?['total_count'] ?? 0, comments: item['comments']?['summary']?['total_count'] ?? 0,
          ));
        }
      }
      return results;
    } catch (e) { return []; }
  }

  // ============== CREATE POST ==============
  Future<bool> uploadPost(SocialPlatform platform, File mediaFile, String caption, bool isVideo) async {
    final creds = await _getCredentials();
    final String? accessToken = creds['facebook_page_access_token'] ?? creds['facebook_user_access_token'];
    if (accessToken == null) return false;

    if (platform == SocialPlatform.facebook) {
      final String? pageId = creds['facebook_account_id'];
      if (pageId == null) return false;
      
      var uri = Uri.parse('https://graph.facebook.com/$_graphApiVersion/$pageId/${isVideo ? 'videos' : 'photos'}');
      var request = http.MultipartRequest('POST', uri);
      request.fields['access_token'] = accessToken;
      request.fields[isVideo ? 'description' : 'message'] = caption;
      request.files.add(await http.MultipartFile.fromPath('source', mediaFile.path));

      var response = await request.send();
      return response.statusCode == 200;
    } else {
      final String? igId = creds['instagram_account_id'];
      if (igId == null) return false;

      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(mediaFile.path)}';
      final bytes = await mediaFile.readAsBytes();
      await _supabaseService.client.storage.from('post_images').uploadBinary(fileName, bytes, fileOptions: const FileOptions(upsert: true));
      final publicUrl = _supabaseService.client.storage.from('post_images').getPublicUrl(fileName);

      final containerUrl = Uri.parse('https://graph.facebook.com/$_graphApiVersion/$igId/media');
      final containerRes = await http.post(containerUrl, body: {
        isVideo ? 'video_url' : 'image_url': publicUrl,
        'caption': caption,
        'media_type': isVideo ? 'REELS' : 'IMAGE',
        'access_token': accessToken,
      });

      if (containerRes.statusCode != 200) return false;
      final creationId = json.decode(containerRes.body)['id'];

      final publishUrl = Uri.parse('https://graph.facebook.com/$_graphApiVersion/$igId/media_publish');
      final publishRes = await http.post(publishUrl, body: {'creation_id': creationId, 'access_token': accessToken});
      return publishRes.statusCode == 200;
    }
  }

  // ============== GET INBOX ==============
  Future<List<MetaChat>> getUnifiedInbox() async {
    final creds = await _getCredentials();
    final String? fbPageId = creds['facebook_account_id'];
    final String? igId = creds['instagram_account_id'];
    final String? accessToken = creds['facebook_page_access_token'] ?? creds['facebook_user_access_token'];
    if (accessToken == null) return [];

    List<MetaChat> allChats = [];

    Future<void> fetchChats(String? accountId, SocialPlatform platform, String urlSuffix) async {
      if (accountId == null) return;
      try {
        final res = await http.get(Uri.parse('https://graph.facebook.com/$_graphApiVersion/$accountId/conversations?fields=id,updated_time,messages.limit(1){message,from,created_time},unread_count&access_token=$accessToken$urlSuffix'));
        if (res.statusCode == 200) {
          final data = json.decode(res.body);
          if (data['data'] != null) {
            for (var conv in data['data']) {
              final lastMsg = conv['messages']?['data']?[0];
              allChats.add(MetaChat(
                id: conv['id'], platform: platform, avatarUrl: '',
                senderName: lastMsg?['from']?['username'] ?? lastMsg?['from']?['name'] ?? 'User',
                lastMessage: lastMsg?['message'] ?? 'Attachment',
                time: _formatTime(lastMsg?['created_time']),
                rawTimestamp: lastMsg?['created_time'],
                isUnread: (conv['unread_count'] ?? 0) > 0,
              ));
            }
          }
        }
      } catch (_) {}
    }

    await fetchChats(fbPageId, SocialPlatform.facebook, '');
    await fetchChats(igId, SocialPlatform.instagram, '&platform=instagram');

    allChats.sort((a, b) => (b.rawTimestamp ?? '').compareTo(a.rawTimestamp ?? ''));
    return allChats;
  }

  // ============== MESSAGING ==============
  Future<List<Map<String, dynamic>>> getChatMessages(String conversationId) async {
    final creds = await _getCredentials();
    final accessToken = creds['facebook_page_access_token'] ?? creds['facebook_user_access_token'];
    if (accessToken == null) return [];

    try {
      final res = await http.get(Uri.parse('https://graph.facebook.com/$_graphApiVersion/$conversationId/messages?fields=message,from,created_time&limit=30&access_token=$accessToken'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body)['data'] as List;
        return data.map((m) => {'message': m['message'] ?? '', 'is_from_me': false, 'created_time': m['created_time']}).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<bool> sendMessage(String conversationId, String message) async {
    final creds = await _getCredentials();
    final accessToken = creds['facebook_page_access_token'] ?? creds['facebook_user_access_token'];
    if (accessToken == null) return false;

    try {
      final res = await http.post(
        Uri.parse('https://graph.facebook.com/$_graphApiVersion/$conversationId/messages'),
        body: {'recipient': json.encode({'id': conversationId}), 'message': message, 'access_token': accessToken},
      );
      return res.statusCode == 200;
    } catch (_) { return false; }
  }

  String _formatTime(String? isoTime) {
    if (isoTime == null) return '';
    try {
      final d = DateTime.parse(isoTime).toLocal();
      return "${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}";
    } catch (_) { return ''; }
  }
}