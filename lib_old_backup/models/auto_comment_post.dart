class AutoCommentPost {
  final int id;
  final String? postId;
  final Map<String, dynamic>? autoReply;
  final bool allComments;

  AutoCommentPost({
    required this.id,
    this.postId,
    this.autoReply,
    required this.allComments,
  });

  factory AutoCommentPost.fromJson(Map<String, dynamic> json) {
    return AutoCommentPost(
      id: json['id'],
      postId: json['post_id'],
      autoReply: json['auto_reply'],
      allComments: json['all_comments'] ?? false,
    );
  }
}