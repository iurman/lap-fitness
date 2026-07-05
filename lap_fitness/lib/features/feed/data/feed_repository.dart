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

  /// Emits each post as it is added to the feed. Malformed nodes (null or
  /// non-map values) are skipped rather than thrown, so one bad record can't
  /// kill the whole subscription.
  Stream<Post> onPostAdded() {
    return _feed.onChildAdded
        .map((event) => event.snapshot.value)
        .where((value) => value is Map)
        .map((value) => Post.fromMap(value as Map));
  }

  /// Emits the Firebase push key of each post as it leaves the feed. The key is
  /// unique per node, so removals map 1:1 (matching on `postId` could delete
  /// several legacy posts that share an empty id).
  Stream<String> onPostRemoved() {
    return _feed.onChildRemoved.map((event) => event.snapshot.key ?? '');
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
