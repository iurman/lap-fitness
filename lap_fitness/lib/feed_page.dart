import 'dart:async';
import 'dart:convert';
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
    setState(() {
      _feedData.add(newPost);
    });
    _saveFeedData(); // Save updated data to SharedPreferences

    // Save new post to Firebase Realtime Database
    DatabaseReference newPostRef = _database.push();
    newPostRef.set(newPost).then((value) {
      print('Post added successfully');
    }).catchError((error) {
      print('Failed to add post: $error');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16.0),
            child: TextFormField(
              controller: _postController,
              decoration: InputDecoration(
                labelText: 'Post something...',
              ),
              onFieldSubmitted: (value) async {
                if (value.isNotEmpty) {
                  // Get the current user from Firebase Authentication
                  User? currentUser = FirebaseAuth.instance.currentUser;
                  if (currentUser != null) {
                    String userId = currentUser.uid; // Get the user ID
                    _addPost(value, userId);
                    _postController.clear();
                  } else {
                    print(
                        'Error: User is not logged in.'); // Handle case when user is not logged in
                  }
                }
              },
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _feedData.length,
              itemBuilder: (context, index) {
                final post = _feedData[index];
                return ListTile(
                  title: Text(post['body']),
                  subtitle: Text('User ID: ${post['userId']}'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
