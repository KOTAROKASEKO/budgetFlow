import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:moneymanager/themeColor.dart';
import 'package:moneymanager/uid/uid.dart';
import 'package:table_calendar/table_calendar.dart';

class todoPage extends StatefulWidget {
  const todoPage({Key? key}) : super(key: key);

  @override
  _todoPageState createState() => _todoPageState();
}

class _todoPageState extends State<todoPage> {
  String userGoal = "";
  initState() {
      getGoal();
      super.initState();
      // Initialize any data or state here if needed
    }
  Future<void> getGoal() async {
      FirebaseFirestore firestore = FirebaseFirestore.instance;
      firestore.collection("goals").doc(userId.uid).get().then((value) {
        setState(() {
          userGoal = value.data()?["goal"] ?? "No goal set";
        });
      }).catchError((error) {
        print("Error fetching goal: $error");
      });
    }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Todo List', style: TextStyle(
          fontFamily: "thick",
          color: Colors.white
          ),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          children: [
            //goal card
            Container(
              width: screenSize.width,
              decoration: BoxDecoration(
                color: theme.shiokuriBlue,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child:Padding(
                padding: EdgeInsets.all(10),
                child:Text(
                  maxLines: 2,
                  "Your Goal: Be an astronaut in 5 years!!", 
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20, 
                    fontFamily: "thick",
                    ),
                  ),
                ),
              ),
            SizedBox(height: 20),
            Padding(padding:EdgeInsets.all(10),
              child:Column(
                children: [
                  Row(
                    children:[
                     Padding (
                      padding: EdgeInsets.only(left: 10),
                      child:Text(
                        maxLines: 2,
                        "Today's task :",
                        textAlign: TextAlign.start,
                        style: TextStyle(
                          color: const Color.fromARGB(255, 223, 223, 223),
                          fontSize: 20,
                          fontFamily: "thick",
                        ),
                      ),)
                    ]
                  ),
                  Padding(
                    padding: EdgeInsets.only(left: 10, top: 10),
                    child:Text("Find an application form for the astronaut program",
                    textAlign: TextAlign.start,
                    style: TextStyle(
                      color: const Color.fromARGB(255, 223, 223, 223),
                      fontSize: 17,
                      fontFamily: "thick",
                    ),
                  ),)
              ])
            ),
            TableCalendar(
              calendarStyle: CalendarStyle(
                defaultTextStyle: TextStyle(color: Colors.white),
                weekendTextStyle: TextStyle(color: Colors.white),
                todayTextStyle: TextStyle(color: Colors.black),
                selectedTextStyle: TextStyle(color: Colors.white),

                selectedDecoration: BoxDecoration(
                  color: theme.shiokuriBlue,
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: const Color.fromARGB(255, 54, 54, 54),
                  shape: BoxShape.circle,
                ),
              ),
              headerStyle: HeaderStyle(
                titleTextStyle: TextStyle(
                  color: Colors.white, // ← ヘッダー「May 2025」を白に
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                formatButtonVisible: false,
              ),
              focusedDay: DateTime.now(),
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              onDaySelected: (selectedDay, focusedDay) {
                // 処理を書くところ
              },
            )
],
        ),
      ),
    );
  }
}
