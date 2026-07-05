import 'dart:convert';

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../core/providers.dart';
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
  List<Post> _feedData = [];
  final TextEditingController _postController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  AuthRepository get _authRepo => ref.read(authRepositoryProvider);
  FeedRepository get _feedRepo => ref.read(feedRepositoryProvider);
  ProfileRepository get _profileRepo => ref.read(profileRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _loadFeedData(); // Load saved data from SharedPreferences
    _fetchFeedData();
  }

  @override
  void dispose() {
    _postController.dispose();
    super.dispose();
  }

  void _loadFeedData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? feedDataJson = prefs.getString('feedData');
    if (feedDataJson != null) {
      List<dynamic> feedData = json.decode(feedDataJson);
      setState(() {
        _feedData = feedData
            .map((e) => Post.fromMap(e as Map<dynamic, dynamic>))
            .toList();
      });
    }
  }

  void _fetchFeedData() {
    _feedRepo.onPostAdded().listen((post) {
      setState(() {
        _feedData.add(post);
      });
      // Scroll to the most recent post after loading all the posts
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      });
    });

    _feedRepo.onPostRemoved().listen((postId) {
      setState(() {
        _feedData.removeWhere((post) => post.postId == postId);
      });
    });
  }

  void _saveFeedData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'feedData', json.encode(_feedData.map((p) => p.toMap()).toList()));
  }

  void _addPost(String body) async {
    final userId = _authRepo.currentUid!;
    final userEmail = _authRepo.currentEmail;
    final profile = await _profileRepo.getProfile(userId);
    final displayName =
        profile.privateMode ? const Uuid().v4() : userEmail;

    await _feedRepo.addPost(
      userId: userId,
      body: body,
      userEmail: userEmail,
      displayName: displayName,
    );
  }

  void _deletePost(Post post) {
    final currentUserUid = _authRepo.currentUid;
    if (post.userId == currentUserUid) {
      _feedRepo.deletePost(post).then((value) {
        setState(() {
          _feedData.removeWhere((p) => p.postId == post.postId);
        });
        _saveFeedData();
      });
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
