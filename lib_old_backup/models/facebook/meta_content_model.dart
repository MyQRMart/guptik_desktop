enum SocialPlatform { facebook, instagram }
enum ContentType { post, reel, story, mention }

class MetaContent {
  final String id;
  final SocialPlatform platform;
  final ContentType type;
  final String imageUrl;
  final String? videoUrl; // ADDED THIS
  final String caption;
  final int likes;
  final int comments;

  MetaContent({
    required this.id, required this.platform, required this.type,
    required this.imageUrl, this.videoUrl, required this.caption,
    required this.likes, required this.comments,
  });
}