import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/data/auth_repository.dart';
import '../features/feed/data/feed_repository.dart';
import '../features/meals/data/meals_repository.dart';
import '../features/notes/data/notes_repository.dart';
import '../features/profile/data/profile_repository.dart';
import '../features/water/data/water_repository.dart';
import 'firebase/database_refs.dart';

/// Low-level Firebase singletons.
final firebaseAuthProvider =
    Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);

final databaseRefsProvider =
    Provider<DatabaseRefs>((ref) => DatabaseRefs(FirebaseDatabase.instance));

/// Repositories.
final authRepositoryProvider = Provider<AuthRepository>(
    (ref) => AuthRepository(ref.watch(firebaseAuthProvider)));

final profileRepositoryProvider = Provider<ProfileRepository>(
    (ref) => ProfileRepository(ref.watch(databaseRefsProvider)));

final feedRepositoryProvider = Provider<FeedRepository>(
    (ref) => FeedRepository(ref.watch(databaseRefsProvider)));

final notesRepositoryProvider = Provider<NotesRepository>(
    (ref) => NotesRepository(ref.watch(databaseRefsProvider)));

final mealsRepositoryProvider = Provider<MealsRepository>(
    (ref) => MealsRepository(ref.watch(databaseRefsProvider)));

final waterRepositoryProvider = Provider<WaterRepository>(
    (ref) => WaterRepository(ref.watch(databaseRefsProvider)));

/// Reactive auth state used to drive routing.
final authStateProvider = StreamProvider<User?>(
    (ref) => ref.watch(authRepositoryProvider).authStateChanges());
