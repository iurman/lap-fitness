import 'package:flutter/foundation.dart';

/// A social feed post, stored at RTDB `/feedData/{key}`.
///
/// `key` is the Firebase-generated push key (used for deletes). `postId` is a
/// client-generated uuid kept for backwards compatibility with existing data.
/// The feed is shared across all users by design; "private mode" only swaps the
/// [displayName] for an anonymous value at post time.
@immutable
class Post {
  const Post({
    required this.key,
    required this.userId,
    required this.postId,
    required this.body,
    required this.userEmail,
    required this.displayName,
    this.liked = false,
    this.comments = const [],
  });

  final String key;
  final String userId;
  final String postId;
  final String body;
  final String userEmail;
  final String displayName;
  final bool liked;
  final List<dynamic> comments;

  factory Post.fromMap(Map<dynamic, dynamic> map) {
    return Post(
      key: (map['key'] ?? '').toString(),
      userId: (map['userId'] ?? '').toString(),
      postId: (map['postId'] ?? '').toString(),
      body: (map['body'] ?? '').toString(),
      userEmail: (map['userEmail'] ?? '').toString(),
      displayName: (map['displayName'] ?? '').toString(),
      liked: map['liked'] == true,
      comments: map['comments'] is List ? map['comments'] as List : const [],
    );
  }

  Map<String, dynamic> toMap() => {
        'key': key,
        'userId': userId,
        'postId': postId,
        'body': body,
        'userEmail': userEmail,
        'displayName': displayName,
        'liked': liked,
        'comments': comments,
      };

  Post copyWith({
    String? key,
    String? userId,
    String? postId,
    String? body,
    String? userEmail,
    String? displayName,
    bool? liked,
    List<dynamic>? comments,
  }) {
    return Post(
      key: key ?? this.key,
      userId: userId ?? this.userId,
      postId: postId ?? this.postId,
      body: body ?? this.body,
      userEmail: userEmail ?? this.userEmail,
      displayName: displayName ?? this.displayName,
      liked: liked ?? this.liked,
      comments: comments ?? this.comments,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Post &&
      other.key == key &&
      other.userId == userId &&
      other.postId == postId &&
      other.body == body &&
      other.userEmail == userEmail &&
      other.displayName == displayName &&
      other.liked == liked;

  @override
  int get hashCode =>
      Object.hash(key, userId, postId, body, userEmail, displayName, liked);
}
