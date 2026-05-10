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
  const FeedPage({super.key});

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
  bool _posting = false;

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
    } catch (_) {/* ignore corrupt cache */}
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
      if (_feedData.any((p) => p['postId'] == postId)) return;
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
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _deletePost(postId);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _onSubmit() async {
    final body = _postController.text.trim();
    if (body.isEmpty) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _posting = true);
    await _addPost(body, uid, const Uuid().v4());
    _postController.clear();
    if (mounted) setState(() => _posting = false);
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: Column(
        children: [
          Expanded(
            child: _feedData.isEmpty
                ? const _EmptyFeed()
                : ListView.builder(
                    controller: _scrollController,
                    padding:
                        const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    itemCount: _feedData.length,
                    itemBuilder: (context, index) {
                      final post = _feedData[index];
                      final isMine = post['userId'] == currentUid;
                      return _FeedItem(
                        body: '${post['body']}',
                        author: '${post['displayName']}',
                        showDelete: isMine,
                        onDelete: () =>
                            _confirmDelete(post['postId'] as String),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _postController,
                      decoration: const InputDecoration(
                        hintText: 'Share something...',
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _onSubmit(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _posting
                        ? const SizedBox(
                            key: ValueKey('busy'),
                            width: 48,
                            height: 48,
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : IconButton.filled(
                            key: const ValueKey('send'),
                            onPressed: _onSubmit,
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.brand,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(48, 48),
                            ),
                            icon: const Icon(Icons.send_rounded),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedItem extends StatelessWidget {
  final String body;
  final String author;
  final bool showDelete;
  final VoidCallback onDelete;

  const _FeedItem({
    required this.body,
    required this.author,
    required this.showDelete,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.brand.withValues(alpha: 0.15),
                child: const Icon(Icons.person, color: AppColors.brand),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      author,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.brand,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(body, style: const TextStyle(fontSize: 15)),
                  ],
                ),
              ),
              if (showDelete)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  color: Colors.grey[600],
                  onPressed: onDelete,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.forum_outlined,
              size: 72, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            'No posts yet',
            style: TextStyle(fontSize: 18, color: Colors.grey[700]),
          ),
          const SizedBox(height: 4),
          Text(
            'Be the first to share something.',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}
