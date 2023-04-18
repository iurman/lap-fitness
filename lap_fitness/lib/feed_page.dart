import 'dart:async';
import 'dart:convert';
import 'dart:html';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FeedPage extends StatefulWidget {
  @override
  _FeedPageState createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  List<Map<String, dynamic>> _feedData = [];
  TextEditingController _postController = TextEditingController();

  final DatabaseReference _database =
      FirebaseDatabase.instance.reference().child('feedData');

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
      }
    }, onError: (error) {
      print('Error fetching feed data: $error');
    });

    _database.onChildChanged.listen((event) {
      Map<dynamic, dynamic>? data =
          event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        setState(() {
          int index =
              _feedData.indexWhere((post) => post['postId'] == data['postId']);
          if (index >= 0) {
            _feedData[index] = data.cast<String, dynamic>();
          }
        });
      }
    }, onError: (error) {
      print('Error updating feed data: $error');
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

  void _addPost(String body, String userId) {
    Map<String, dynamic> newPost = {
      'userId': userId,
      'postId': DateTime.now().millisecondsSinceEpoch,
      'body': body,
      'liked': false,
      'comments': [],
    };

    // Save new post to Firebase Realtime Database
    DatabaseReference newPostRef = _database.push();
    newPostRef.set(newPost).then((value) {
      print('Post added successfully');
    }).catchError((error) {
      print('Failed to add post: $error');
    });
  }

  void _deletePost(int postId) {
    DatabaseReference postRef = _database.child('$postId');
    String postIdString = postId.toString(); // Convert postId to string
    String currentUserUid = FirebaseAuth.instance.currentUser!.uid;
    postRef.onValue.listen((event) {
      if (event.snapshot.value != null) {
        Map<dynamic, dynamic> post = Map<dynamic, dynamic>.from(
            event.snapshot.value as Map<dynamic, dynamic>);
        if (post['userId'] == currentUserUid) {
          // User can only delete their own posts
          postRef.remove().then((value) {
            setState(() {
              _feedData.removeWhere((post) => post['postId'] == postId);
            });
            _saveFeedData(); // Save updated data to SharedPreferences
            print('Post deleted successfully');
          }).catchError((error) {
            print('Error deleting post: $error');
          });
        } else {
          print('You can only delete your own posts');
        }
      } else {
        print('Post not found');
      }
    }).onError((error) {
      print('Error deleting post: $error');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Feed')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
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
                                        int postId = post['postId'];
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
                      _addPost(body, FirebaseAuth.instance.currentUser!.uid);
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
