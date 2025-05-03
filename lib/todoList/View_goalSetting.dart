import 'package:flutter/material.dart';

class goalSetting extends StatefulWidget {
  const goalSetting({super.key});

  @override
  _goalSettingState createState() => _goalSettingState();
}

class _goalSettingState extends State<goalSetting> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Goal Setting'),
      ),
      body: Center(
        child: Column(
          children:[
            Text(
              "What is your goal?",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextField(
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Enter your goal',
              ),
            ),
            SizedBox(height: 20),
            Text(
              "What is your deadline?",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            Text("Current progress"),
          ]
        )
      )
    );
  }
}