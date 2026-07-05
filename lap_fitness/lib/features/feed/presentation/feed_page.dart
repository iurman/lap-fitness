import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/data/auth_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../data/feed_repository.dart';
import '../domain/post.dart';

class FeedPage extends ConsumerStatefulWidget {
  const FeedPage({super.key});

  @override
  ConsumerState<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends ConsumerState<FeedPage> {
  final List<Post> _feedData = [];
  final TextEditingController _postController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<Post>? _addedSub;
  StreamSubscription<String>? _removedSub;

  AuthRepository get _authRepo => ref.read(authRepositoryProvider);
  FeedRepository get _feedRepo => ref.read(feedRepositoryProvider);
  ProfileRepository get _profileRepo => ref.read(profileRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _fetchFeedData();
  }

  @override
  void dispose() {
    _addedSub?.cancel();
    _removedSub?.cancel();
    _postController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _fetchFeedData() {
    // Posts stream in from the Realtime Database (childAdded replays existing
    // posts on subscribe, then pushes new ones), so it is the single source of
    // truth — no local cache to avoid double-loading.
    _addedSub = _feedRepo.onPostAdded().listen((post) {
      if (!mounted) return;
      setState(() {
        _feedData.add(post);
      });
      // Scroll to the most recent post.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      });
    }, onError: (Object error, StackTrace stackTrace) {
      appLogger.warning('Error fetching feed data', error, stackTrace);
    });

    _removedSub = _feedRepo.onPostRemoved().listen((removedKey) {
      if (!mounted || removedKey.isEmpty) return;
      setState(() {
        _feedData.removeWhere((post) => post.key == removedKey);
      });
    }, onError: (Object error, StackTrace stackTrace) {
      appLogger.warning('Error removing feed data', error, stackTrace);
    });
  }

  void _addPost(String body) async {
    final userId = _authRepo.currentUid!;
    final userEmail = _authRepo.currentEmail;
    final profile = await _profileRepo.getProfile(userId);
    final displayName = profile.privateMode ? const Uuid().v4() : userEmail;

    await _feedRepo.addPost(
      userId: userId,
      body: body,
      userEmail: userEmail,
      displayName: displayName,
    );
  }

  void _deletePost(Post post) {
    // Only the author may delete; the onPostRemoved stream drops it from the
    // list once the backend confirms the removal.
    if (post.userId == _authRepo.currentUid) {
      _feedRepo.deletePost(post);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = _authRepo.currentUid;
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller:
                  _scrollController, // Assign the scroll controller here
              itemCount: _feedData.length,
              itemBuilder: (context, index) {
                final Post post = _feedData[index];
                final bool isCurrentUserPost = post.userId == currentUid;
                return ListTile(
                  title: Text(post.body),
                  subtitle: Text('Posted by ${post.displayName}'),
                  trailing: isCurrentUserPost
                      ? IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: const Text('Delete Post'),
                                  content: const Text(
                                      'Are you sure you want to delete this post?'),
                                  actions: [
                                    TextButton(
                                      child: const Text('Cancel'),
                                      onPressed: () {
                                        Navigator.pop(context);
                                      },
                                    ),
                                    TextButton(
                                      child: const Text('Delete'),
                                      onPressed: () {
                                        Navigator.pop(context);
                                        _deletePost(post);
                                      },
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        )
                      : null, // Set IconButton to null for posts not by current user
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _postController,
                    decoration: const InputDecoration(
                      hintText: 'Enter post',
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    String body = _postController.text;
                    if (body.isNotEmpty) {
                      _addPost(body);
                      _postController.clear();
                    }
                  },
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.all<Color>(
                      AppColors.brand,
                    ),
                  ),
                  child: const Text('Post'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
