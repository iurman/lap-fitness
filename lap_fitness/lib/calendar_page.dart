import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CalendarPage extends StatefulWidget {
  @override
  _CalendarPageState createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            margin: EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_left),
                  onPressed: () {
                    setState(() {
                      _selectedDate = DateTime(
                          _selectedDate.year, _selectedDate.month - 1, 1);
                    });
                  },
                ),
                Text(
                  DateFormat.yMMMM().format(_selectedDate),
                  style: TextStyle(fontSize: 20),
                ),
                IconButton(
                  icon: Icon(Icons.arrow_right),
                  onPressed: () {
                    setState(() {
                      _selectedDate = DateTime(
                          _selectedDate.year, _selectedDate.month + 1, 1);
                    });
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7, mainAxisSpacing: 10, crossAxisSpacing: 10),
              itemBuilder: (context, index) {
                if (index < _selectedDate.weekday - 1 ||
                    index >=
                        _selectedDate.weekday +
                            DateTime(_selectedDate.year,
                                    _selectedDate.month + 1, 0)
                                .day -
                            1) {
                  return Container();
                } else {
                  return GestureDetector(
                    onTap: () {
                      // Do something when the user taps a day
                    },
                    child: Container(
                      decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(10)),
                      child: Center(
                        child: Text(
                          '${index - _selectedDate.weekday + 2}',
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                    ),
                  );
                }
              },
              itemCount: 42,
              padding: EdgeInsets.symmetric(horizontal: 10),
            ),
          ),
        ],
      ),
    );
  }
}
