// ignore_for_file: prefer_const_literals_to_create_immutables
import 'package:flutter_test/flutter_test.dart';
import 'package:lap_fitness/features/feed/domain/post.dart';

void main() {
  group('Post', () {
    test('fromMap reads fields with defaults', () {
      final post = Post.fromMap({
        'key': 'k1',
        'userId': 'u1',
        'postId': 'p1',
        'body': 'hello',
        'userEmail': 'a@b.com',
        'displayName': 'a@b.com',
        'liked': true,
        'comments': ['nice'],
      });

      expect(post.key, 'k1');
      expect(post.userId, 'u1');
      expect(post.postId, 'p1');
      expect(post.body, 'hello');
      expect(post.userEmail, 'a@b.com');
      expect(post.displayName, 'a@b.com');
      expect(post.liked, isTrue);
      expect(post.comments, ['nice']);
    });

    test('fromMap defaults missing fields', () {
      final post = Post.fromMap({'body': 'hi'});
      expect(post.body, 'hi');
      expect(post.key, '');
      expect(post.liked, isFalse);
      expect(post.comments, isEmpty);
    });

    test('toMap round-trips', () {
      const post = Post(
        key: 'k',
        userId: 'u',
        postId: 'p',
        body: 'b',
        userEmail: 'e',
        displayName: 'd',
      );
      final restored = Post.fromMap(post.toMap());
      expect(restored, post);
    });

    test('equality ignores comments list identity', () {
      const a = Post(
          key: 'k',
          userId: 'u',
          postId: 'p',
          body: 'b',
          userEmail: 'e',
          displayName: 'd');
      const b = Post(
          key: 'k',
          userId: 'u',
          postId: 'p',
          body: 'b',
          userEmail: 'e',
          displayName: 'd');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });
}
