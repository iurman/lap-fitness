// ignore_for_file: depend_on_referenced_packages, use_key_in_widget_constructors, library_private_types_in_public_api, prefer_final_fields, deprecated_member_use, prefer_const_constructors, avoid_print

import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart'; // Import the uuid library
import 'package:collection/collection.dart';

class FeedPage extends StatefulWidget {
  @override
  _FeedPageState createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  List<Map<String, dynamic>> _feedData = [];
  TextEditingController _postController = TextEditingController();

  final DatabaseReference _database =
      FirebaseDatabase.instance.reference().child('feedData');

  ScrollController _scrollController = ScrollController();

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
        _feedData = feedData.cast<Map<String, dynamic>>();
      });
    }
  }

  void _fetchFeedData() {
    _database.onChildAdded.listen((event) {
      Map<dynamic, dynamic>? data =
          event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        setState(() {
          _feedData.add(data.cast<String, dynamic>());
        });
        // Scroll to the most recent post after loading all the posts
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        });
      }
    }, onError: (error) {
      print('Error fetching feed data: $error');
    });

    _database.onChildRemoved.listen((event) {
      Map<dynamic, dynamic>? data =
          event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        setState(() {
          _feedData.removeWhere((post) => post['postId'] == data['postId']);
        });
      }
    }, onError: (error) {
      print('Error removing feed data: $error');
    });
  }

  void _saveFeedData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('feedData', json.encode(_feedData));
  }

  void _addPost(String body, String userId, String postId) {
    DatabaseReference newPostRef = _database.push();
    Map<String, dynamic> newPost = {
      'key': newPostRef.key, // Store the Firebase-generated key
      'userId': userId,
      'postId': postId,
      'body': body,
      'liked': false,
      'comments': [],
    };

    newPostRef.set(newPost).then((value) {
      print('Post added successfully');
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }).catchError((error) {
      print('Failed to add post: $error');
    });
  }

  void _deletePost(String postId) {
    String currentUserUid = FirebaseAuth.instance.currentUser!.uid;

    // Find the post with the matching postId in the _feedData list
    Map<String, dynamic>? postToDelete =
        _feedData.firstWhereOrNull((post) => post['postId'] == postId);

    if (postToDelete != null && postToDelete['userId'] == currentUserUid) {
      DatabaseReference postToRemove = _database.child(postToDelete['key']);
      postToRemove.remove().then((value) {
        setState(() {
          _feedData.removeWhere((post) => post['postId'] == postId);
        });
        _saveFeedData();
        print('Post deleted successfully');
      }).catchError((error) {
        print('Error deleting post: $error');
      });
    } else {
      print('You can only delete your own posts');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller:
                  _scrollController, // Assign the scroll controller here
              itemCount: _feedData.length,
              itemBuilder: (context, index) {
                Map<String, dynamic> post = _feedData[index];
                bool isCurrentUserPost = post['userId'] ==
                    FirebaseAuth.instance.currentUser!
                        .uid; // Check if post is made by current user
                return ListTile(
                  title: Text(post['body']),
                  subtitle: Text('Posted by user ${post['userId']}'),
                  trailing: isCurrentUserPost
                      ? IconButton(
                          icon: Icon(Icons.delete),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: Text('Delete Post'),
                                  content: Text(
                                      'Are you sure you want to delete this post?'),
                                  actions: [
                                    TextButton(
                                      child: Text('Cancel'),
                                      onPressed: () {
                                        Navigator.pop(context);
                                      },
                                    ),
                                    TextButton(
                                      child: Text('Delete'),
                                      onPressed: () {
                                        Navigator.pop(context);
                                        String postId = post['postId'];
                                        _deletePost(
                                            postId); // Call _deletePost method with postId as argument
                                      },
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        )
                      : null, // Set IconButton to null for posts that are not made by current user
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _postController,
                    decoration: InputDecoration(
                      hintText: 'Enter post',
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    String body = _postController.text;
                    if (body.isNotEmpty) {
                      String userId = FirebaseAuth.instance.currentUser!.uid;
                      String postId = Uuid()
                          .v4(); // Generate a unique ID using uuid library
                      _addPost(body, userId, postId);
                      _postController.clear();
                    }
                  },
                  child: Text('Post'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
