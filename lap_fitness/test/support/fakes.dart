import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:lap_fitness/features/auth/data/auth_repository.dart';
import 'package:lap_fitness/features/feed/data/feed_repository.dart';
import 'package:lap_fitness/features/feed/domain/post.dart';
import 'package:lap_fitness/features/meals/data/meals_repository.dart';
import 'package:lap_fitness/features/meals/domain/meal.dart';
import 'package:lap_fitness/features/notes/data/notes_repository.dart';
import 'package:lap_fitness/features/notes/domain/note.dart';
import 'package:lap_fitness/features/profile/data/profile_repository.dart';
import 'package:lap_fitness/features/profile/domain/user_profile.dart';
import 'package:lap_fitness/features/water/data/water_repository.dart';

/// Minimal fakes for widget tests. Each implements its repository interface and
/// throws on any unexpected member so accidental use is loud.

/// A minimal Firebase [User] whose only meaningful field is [uid].
class FakeUser implements User {
  FakeUser(this.uid);

  @override
  final String uid;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class FakeAuthRepository implements AuthRepository {
  /// Pass `uid: null` to simulate a signed-out user.
  FakeAuthRepository({this.uid = 'test-uid'});

  final String? uid;

  @override
  String? get currentUid => uid;

  @override
  String get currentEmail => 'tester@example.com';

  @override
  Stream<User?> authStateChanges() =>
      Stream.value(uid == null ? null : FakeUser(uid!));

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class FakeProfileRepository implements ProfileRepository {
  FakeProfileRepository([this.profile = const UserProfile()]);

  final UserProfile profile;

  @override
  Stream<UserProfile> watchProfile(String uid) => Stream.value(profile);

  @override
  Future<UserProfile> getProfile(String uid) async => profile;

  @override
  Future<void> saveProfile(String uid, UserProfile p) async {}

  @override
  Future<void> setPrivateMode(String uid, bool value) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class FakeMealsRepository implements MealsRepository {
  FakeMealsRepository(this.meals);

  final List<Meal> meals;

  @override
  Stream<List<Meal>> watchMeals(String uid) => Stream.value(meals);

  @override
  Future<void> addMeal(String uid, Meal meal) async => meals.add(meal);

  @override
  Future<void> deleteMeal(String uid, String key) async =>
      meals.removeWhere((m) => m.key == key);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class FakeNotesRepository implements NotesRepository {
  FakeNotesRepository(this.notes);

  final List<Note> notes;

  @override
  Stream<List<Note>> watchNotes(String uid, {DateTime? day}) =>
      Stream.value(notes);

  @override
  Future<void> addNote({required String uid, DateTime? day}) async {}

  @override
  Future<void> updateName(String uid, String key, String name) async {}

  @override
  Future<void> updateContent(String uid, String key, String content) async {}

  @override
  Future<void> deleteNote(String uid, String key) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class FakeFeedRepository implements FeedRepository {
  FakeFeedRepository(this.posts);

  final List<Post> posts;

  @override
  Stream<Post> onPostAdded() => Stream.fromIterable(posts);

  @override
  Stream<String> onPostRemoved() => const Stream.empty();

  @override
  Future<void> addPost({
    required String userId,
    required String body,
    required String userEmail,
    required String displayName,
  }) async {}

  @override
  Future<void> deletePost(Post post) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class FakeWaterRepository implements WaterRepository {
  FakeWaterRepository([int initial = 3]) : _value = initial;

  int _value;
  final _controller = StreamController<int>.broadcast();

  @override
  Stream<int> watchIntake(String uid) async* {
    yield _value;
    yield* _controller.stream;
  }

  @override
  Future<void> adjust(String uid, int delta) async {
    _value = (_value + delta) < 0 ? 0 : _value + delta;
    _controller.add(_value);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}
