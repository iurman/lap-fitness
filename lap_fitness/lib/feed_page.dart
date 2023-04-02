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
      'postImage': 'assets/images/post.png',
      'likes': 10,
      'comments': 5,
    },
    // Add more sample data here
  ];

  TextEditingController _postTextController = TextEditingController();

  @override
  void dispose() {
    _postTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                        onPressed: () {},
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
            );
          }
        },
      ),
    );
  }
}
