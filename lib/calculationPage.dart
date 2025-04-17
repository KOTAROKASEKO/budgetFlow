import 'package:flutter/material.dart';

class calculationPage extends StatefulWidget {
  const calculationPage({super.key});

  @override
  _calculationPageState createState() => _calculationPageState();
}

class _calculationPageState extends State<calculationPage> {

  @override
  void initState() {
    // TODO: implement initState
    super.initState();


  }

  int income = 0;
  int saving = 0;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Calculation Page'),
        centerTitle: true,
      ),
      body: Center(
        child: Text('This is the calculation page.'),
      ),
    );
  }
}