import 'package:firebase_database/firebase_database.dart';
import 'package:uuid/uuid.dart';

import '../../../core/firebase/database_refs.dart';
import '../domain/post.dart';

/// Owns reads/writes for the shared social feed at `/feedData`.
class FeedRepository {
  FeedRepository(this._refs);

  final DatabaseRefs _refs;
  static const _uuid = Uuid();

  DatabaseReference get _feed => _refs.feed();

  /// Emits each post as it is added to the feed.
  Stream<Post> onPostAdded() {
    return _feed.onChildAdded.map((event) {
      final data = event.snapshot.value as Map;
      return Post.fromMap(data);
    });
  }

  /// Emits the removed post (by `postId`) whenever a post leaves the feed.
  Stream<String> onPostRemoved() {
    return _feed.onChildRemoved.map((event) {
      final data = event.snapshot.value as Map?;
      return (data?['postId'] ?? '').toString();
    });
  }

  /// Adds a post authored by [userId]. [displayName] is anonymized upstream
  /// when the author has private mode enabled.
  Future<void> addPost({
    required String userId,
    required String body,
    required String userEmail,
    required String displayName,
  }) async {
    final newPostRef = _feed.push();
    final post = Post(
      key: newPostRef.key ?? '',
      userId: userId,
      postId: _uuid.v4(),
      body: body,
      userEmail: userEmail,
      displayName: displayName,
    );
    await newPostRef.set(post.toMap());
  }

  Future<void> deletePost(Post post) => _feed.child(post.key).remove();
}
