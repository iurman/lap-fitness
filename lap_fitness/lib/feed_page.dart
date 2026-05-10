import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'core/theme/app_colors.dart';
import 'data/feed_repository.dart';
import 'data/user_repository.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({Key? key}) : super(key: key);

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  static const String _cacheKey = 'feedData';

  final FeedRepository _feed = FeedRepository();
  final UserRepository _users = UserRepository();
  final TextEditingController _postController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _feedData = [];
  StreamSubscription<DatabaseEvent>? _addedSub;
  StreamSubscription<DatabaseEvent>? _removedSub;

  @override
  void initState() {
    super.initState();
    _loadCachedFeedData();
    _subscribeToFeed();
  }

  @override
  void dispose() {
    _addedSub?.cancel();
    _removedSub?.cancel();
    _postController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadCachedFeedData() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cacheKey);
    if (raw == null) return;
    try {
      final decoded = json.decode(raw) as List<dynamic>;
      if (!mounted) return;
      setState(() {
        _feedData = decoded.cast<Map<String, dynamic>>();
      });
    } catch (_) {/* corrupt cache; ignore */}
  }

  Future<void> _saveCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, json.encode(_feedData));
  }

  void _subscribeToFeed() {
    _addedSub = _feed.onChildAdded.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return;
      final post = data.cast<String, dynamic>();
      final postId = post['postId'] as String?;
      if (postId == null) return;

      final exists = _feedData.any((p) => p['postId'] == postId);
      if (exists) return;

      if (!mounted) return;
      setState(() => _feedData.add(post));
      _saveCache();
      _scrollToBottom();
    }, onError: (Object e) {
      if (kDebugMode) debugPrint('Error fetching feed data: $e');
    });

    _removedSub = _feed.onChildRemoved.listen((event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data == null) return;
      final postId = data['postId'];
      if (!mounted) return;
      setState(() => _feedData.removeWhere((post) => post['postId'] == postId));
      _saveCache();
    }, onError: (Object e) {
      if (kDebugMode) debugPrint('Error removing feed data: $e');
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    });
  }

  Future<void> _addPost(String body, String userId, String postId) async {
    final userEmail = FirebaseAuth.instance.currentUser?.email ?? '';
    bool privateMode = false;
    try {
      final profile = await _users.fetchProfileFor(userId);
      privateMode = profile.privateMode;
    } catch (_) {/* default to public */}

    final ref = _feed.newPostRef();
    final post = <String, dynamic>{
      'key': ref.key,
      'userId': userId,
      'postId': postId,
      'body': body,
      'userEmail': userEmail,
      'displayName': privateMode ? const Uuid().v4() : userEmail,
      'liked': false,
      'comments': <dynamic>[],
    };

    try {
      await _feed.setPost(ref, post);
      _scrollToBottom();
    } catch (e) {
      if (kDebugMode) debugPrint('Failed to add post: $e');
    }
  }

  Future<void> _deletePost(String postId) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return;

    final post = _feedData.firstWhereOrNull((p) => p['postId'] == postId);
    if (post == null || post['userId'] != currentUid) return;

    try {
      await _feed.deletePost(post['key'] as String);
      if (!mounted) return;
      setState(() => _feedData.removeWhere((p) => p['postId'] == postId));
      _saveCache();
    } catch (e) {
      if (kDebugMode) debugPrint('Error deleting post: $e');
    }
  }

  void _confirmDelete(String postId) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('Are you sure you want to delete this post?'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(ctx),
          ),
          TextButton(
            child: const Text('Delete'),
            onPressed: () {
              Navigator.pop(ctx);
              _deletePost(postId);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: _feedData.length,
              itemBuilder: (context, index) {
                final post = _feedData[index];
                final isMine = post['userId'] == currentUid;
                return ListTile(
                  title: Text('${post['body']}'),
                  subtitle: Text('Posted by ${post['displayName']}'),
                  trailing: isMine
                      ? IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () =>
                              _confirmDelete(post['postId'] as String),
                        )
                      : null,
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
                    decoration: const InputDecoration(hintText: 'Enter post'),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                  ),
                  onPressed: () {
                    final body = _postController.text;
                    if (body.isEmpty) return;
                    final uid = FirebaseAuth.instance.currentUser?.uid;
                    if (uid == null) return;
                    _addPost(body, uid, const Uuid().v4());
                    _postController.clear();
                  },
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
