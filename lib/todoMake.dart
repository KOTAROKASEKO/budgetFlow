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
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.white,
        child: Icon(Icons.add, color: Colors.black),
        onPressed: () {
          showModalBottomSheet(
            enableDrag: true,
            isScrollControlled: true,
            context: context,
            builder: (context) {
              return showTaskCard();
            },
          );

        },
      ),
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
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                formatButtonVisible: false,
                titleCentered: true,
                leftChevronIcon: Icon(Icons.chevron_left, color: Colors.white),
                rightChevronIcon: Icon(Icons.chevron_right, color: Colors.white),
              ),
              focusedDay: DateTime.now(),
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              onDaySelected: (selectedDay, focusedDay) {
                showModalBottomSheet(context: context, builder: (context){
                  return showTaskCard();
                });
              },
            )

          ],
        ),
      ),
    );
  }

  Widget showTaskCard(){
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.7,
      expand: false,
      builder: (context, scrollController) {
        return StatefulBuilder(
    builder: (context, StateSetter setState) {
      return Container(
        width: MediaQuery.of(context).size.width,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
        child: SingleChildScrollView(
          controller: scrollController,
          padding: EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(height: 20),
              Container(
                width: 100,
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.grey,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Expense Detail',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color.fromARGB(255, 73, 73, 73),
                  fontSize: 17,
                ),
              ),

              //budget field
              
              
              GestureDetector(
                onTap: () async {
                  
                },
                child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey,
                          blurRadius: 10,
                        ),
                      ],
                      color: theme.shiokuriBlue,
                      borderRadius: BorderRadius.circular(40),
                    ),
                    child: Center(
                      child: Text(
                        'Save',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    )),
              ),
              SizedBox(height: 20),
            ],
          ),
        ),
      );
    },
        );
      },
    );
  }
}

