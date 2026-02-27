import 'meta_content_model.dart';

class MetaChat {
  final String id;
  final String senderName;
  final String lastMessage;
  final String time;
  final String? rawTimestamp;
  final String avatarUrl;
  final SocialPlatform platform;
  final bool isUnread;

  MetaChat({
    required this.id, required this.senderName, required this.lastMessage,
    required this.time, this.rawTimestamp, required this.avatarUrl,
    required this.platform, this.isUnread = false,
  });
}