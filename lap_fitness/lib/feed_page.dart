// ignore_for_file: prefer_const_constructors, use_key_in_widget_constructors, library_private_types_in_public_api, prefer_final_fields, sort_child_properties_last
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class FeedPage extends StatefulWidget {
  @override
  _FeedPageState createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  List<Map<String, dynamic>> _feedData = [
    {
      'name': 'Billy Bob',
      'image': 'assets/images/profile.png',
      'time': '2 hours ago',
      'text':
          'Bro watch this amazing lift I am doing. My form is immaculate, no one can top me, this is peak human physique.',
      'postImage':
          'assets/images/post.png', //need to add controller for image adding
      'likes': 10,
      'comments': 5,
      'comments': [
        {'name': 'John Doe', 'text': 'Awesome workout!'},
        // Add more sample comments here
      ],
    },
    // Add more sample data here
  ];

  TextEditingController _postTextController = TextEditingController();

  @override
  void dispose() {
    _postTextController.dispose();
    super.dispose();
  }

  void _addComment(int index, String text) {
    setState(() {
      _feedData[index]['comments'].add({'name': 'Me', 'text': text});
    });
  }

  void _toggleLike(int index) {
    setState(() {
      _feedData[index]['likes'] = !_feedData[index]['liked']
          ? _feedData[index]['likes'] + 1
          : _feedData[index]['likes'] - 1;
      _feedData[index]['liked'] = !_feedData[index]['liked'];
    });
  }

  Future<void> _saveFeedData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('feedData', jsonEncode(_feedData));
  }

  Future<void> _loadFeedData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String feedDataString = prefs.getString('feedData');

    if (feedDataString != null) {
      setState(() {
        _feedData = List<Map<String, dynamic>>.from(jsonDecode(feedDataString));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('LAP: Lift and Progress'),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.filter_list),
            onSelected: (String value) {
              // Handle the selected option here
            },
            itemBuilder: (BuildContext context) {
              return [
                PopupMenuItem<String>(
                  value: 'sort_time',
                  child: Text('Sort by Time'),
                ),
                PopupMenuItem<String>(
                  value: 'sort_likes',
                  child: Text('Sort by Likes'),
                ),
                // Add more options here
              ];
            },
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: _feedData.length + 1,
        itemBuilder: (BuildContext context, int index) {
          if (index == 0) {
            // The first item in the list is the new post card
            return Card(
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _postTextController,
                      decoration: InputDecoration(
                        hintText: 'What\'s on your mind?',
                      ),
                      maxLines: 5,
                    ),
                    SizedBox(height: 8.0),
                    ElevatedButton(
                      onPressed: () {
                        // Add the new post to the feed data
                        setState(() {
                          _feedData.insert(0, {
                            'name': 'Me',
                            'image': 'assets/images/profile_me.png',
                            'time': 'Just now',
                            'text': _postTextController.text,
                            'postImage': null,
                            'likes': 0,
                            'comments': 0,
                          });
                          _postTextController.clear();
                        });
                      },
                      style: ButtonStyle(
                        backgroundColor: MaterialStateProperty.all<Color>(
                          Color.fromARGB(255, 138, 104, 35),
                        ),
                      ),
                      child: Text('Post'),
                    ),
                  ],
                ),
              ),
            );
          } else {
            // The rest of the items are the existing posts
            final data = _feedData[index - 1];
            return Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundImage: AssetImage(data['image']),
                        ),
                        SizedBox(width: 8.0),
                        Text(
                          data['name'],
                          style: TextStyle(
                              fontSize: 18.0, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(width: 8.0),
                        Text(
                          data['time'],
                          style: TextStyle(fontSize: 12.0, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      data['text'],
                      style: TextStyle(fontSize: 16.0),
                    ),
                  ),
                  if (data['postImage'] != null)
                    Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Image.asset(data['postImage']),
                    ),
                  ButtonBar(
                    children: [
                      TextButton.icon(
                        onPressed: () {},
                        icon: Icon(Icons.favorite_border,
                            color: Color.fromARGB(255, 138, 104, 35)),
                        label: Text('Like',
                            style: TextStyle(
                                color: Color.fromARGB(255, 138, 104, 35))),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          _addComment(
                              index - 1, _commentControllers[index - 1].text);
                          _commentControllers[index - 1].clear();
                        },
                        icon: Icon(Icons.comment,
                            color: Color.fromARGB(255, 138, 104, 35)),
                        label: Text('Comment',
                            style: TextStyle(
                                color: Color.fromARGB(255, 138, 104, 35))),
                      ),
                    ],
                  ),
                  Divider(height: 1.0),
                  Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundImage:
                              AssetImage('assets/images/profile.png'),
                        ),
                        SizedBox(width: 8.0),
                        Expanded(
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'Add a comment',
                            ),
                          ),
                        ),
                        SizedBox(width: 8.0),
                        TextButton(
                          onPressed: () {},
                          child: Text('Post',
                              style: TextStyle(color: Colors.white)),
                          style: ButtonStyle(
                            backgroundColor: MaterialStateProperty.all<Color>(
                              Color.fromARGB(255, 138, 104, 35),
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                ],
              ),
              Column(
  children: _feedData[index - 1]['comments']
      .map<Widget>((comment) => ListTile(
            title: Text(comment['name']),
            subtitle: Text(comment['text']),
          ))
      .toList(),
),
            );
          }
        },
      ),
    );
  }
}
