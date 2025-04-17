import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:liquid_pull_to_refresh/liquid_pull_to_refresh.dart';
import 'package:moneymanager/model/expenseModel.dart';
import 'package:moneymanager/themeColor.dart';
import 'package:moneymanager/uid/uid.dart';
import 'package:uuid/uuid.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  _DashboardState createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  String category = "Food";
  int? budget = 0;
  List<double> dayBalances = [];
  List<expenseModel> expenseModels = [];
  int? avg = 0;
  String formattedDate = '';
  int month = 0;
  int year = 0;
  bool isLoading = true;
  bool doesExist = true;

//=====editing members
  TextEditingController _budgetController = TextEditingController();
  TextEditingController _descriptionController = TextEditingController();

  String EditedId = '';
  String editingDate = '';
  String amount = '';
  String description = '';
  bool isOnline = true;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    DateTime now = DateTime.now();
    year = now.year;
    month = now.month;
    formattedDate = "${year}-${month.toString().padLeft(2, '0')}";

    fetchData(formattedDate);
  }

  void checkConnection() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      print("No internet connection");
      setState(() {
        isOnline = false;
      });
    } else {
      print("Connected to internet");
      isOnline = true;
    }
  }

  void fetchData(String formattedDate) async {
    try {
      checkConnection();

      this.formattedDate = formattedDate;

      setState(() {
        isLoading = true;
      });

      DocumentSnapshot ref = await FirebaseFirestore.instance
          .collection("budget")
          .doc(userId.uid)
          .get();
      if (ref.exists) {
        budget = ref["budget"];
      } else {
        budget = 0; // Set a default value if the document doesn't exist
      }

      QuerySnapshot expensesSnapshot = await FirebaseFirestore.instance
          .collection("expenses")
          .doc(userId.uid)
          .collection(formattedDate)
          .get();

      expenseModels.clear(); // Clear the list before adding new data
      for (var doc in expensesSnapshot.docs) {
        Map<String, dynamic>? data =
            doc.data() as Map<String, dynamic>?; // Ensure type safety

        if (data != null && data.containsKey("amount")) {
          double amount = double.parse('${data["amount"]}');
          int date = data["date"];

          expenseModels.add(expenseModel(
              amount: double.parse('$amount'),
              date: date,
              id: doc.id,
              description: data["description"] ?? '',
              category: data["category"] ?? ''));
        }
      }
      expenseModels
          .sort((a, b) => b.date.compareTo(a.date)); // Sort the list by date

      print("Expenses list: $expenseModels"); // Debugging output
      setState(() {
        isLoading = false;
        doesExist = expenseModels.isNotEmpty;
        getCurrentFinance();
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        doesExist = expenseModels.isNotEmpty;
      });
      print("Error fetching data: $e");
    }
  }

  Future<void> refresh() async {
    fetchData(formattedDate);
  }

  int sum = 0;
  int numDays = 0;

  int pace = 0;

  int getCurrentFinance() {
    int subtraction = 0;

    if (expenseModels.length != 0) {
      subtraction = expenseModels[0].date -
          expenseModels[expenseModels.length - 1].date +
          1;
    }

    double total = 0;

    for (int j = 0; j < expenseModels.length; j++) {
      total += expenseModels[j].amount;
    }

    total = (subtraction * budget!) - total;

    // Round up to the nearest integer
    pace = total.ceil();
    return pace;
  }

  int getAverage() {
    int days = 1;

    if (expenseModels.isNotEmpty) {
      print('latest day${expenseModels[expenseModels.length - 1].date}');
      days = expenseModels[0].date -
          expenseModels[expenseModels.length - 1].date +
          1;
      print('how many days exist: $days');
    }

    double total = 0;
    for (int j = 0; j < expenseModels.length; j++) {
      total += expenseModels[j].amount;
    }
    try {
      avg = total ~/ days;
    } catch (e) {
      print('error in getAverage $e');
    }
    return avg ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.shiokuriBlue,
        shape: ShapeBorder.lerp(
            RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                    //bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20))),
            RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                    //bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20))),
            1),
        centerTitle: true,
        title: Text(
          "Finance Planner",
          style: TextStyle(fontFamily: 'fancy', fontSize: 20),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: theme.shiokuriBlue,
        onPressed: () async {
          //=============================create new record (not edit)=========================
          amount = '';
          description = '';
          EditedId = '';
          editingDate = '';

          showModalBottomSheet(
            enableDrag: true,
            isScrollControlled: true,
            context: context,
            builder: (context) {
              return DraggableScrollableSheet(
                initialChildSize: 0.7,
                minChildSize: 0.4,
                maxChildSize: 0.7,
                expand: false,
                builder: (context, scrollController) {
                  return StatefulBuilder(
                    builder: (context, StateSetter setState) {
                      return enterExpense(
                        context,
                        setState,
                        scrollController,
                      );
                    },
                  );
                },
              );
            },
          );
        },
        //======================================================================
        child: Icon(
          Icons.add,
          size: 20,
        ),
      ),
      body: isOnline
          ? Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  height: 10,
                ),
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      GestureDetector(
                        onTap: () {
                          showDialog(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                    content: Container(
                                  width: 200,
                                  height: 160,
                                  child: Column(
                                    children: [
                                      Text(
                                          "Budget/day:",
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: const Color.fromARGB(255, 35, 35, 35),
                                              fontSize: 20,
                                          ),
                                          ),
                                      SizedBox(
                                        height: 20,
                                      ),
                                      TextField(
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 20,
                                          color: const Color.fromARGB(255, 46, 46, 46)
                                        ),
                                        textAlign: TextAlign.center,
                                        controller: TextEditingController()
                                          ..text = budget.toString(),
                                        onChanged: (value) {
                                          budget = int.parse(value);
                                        },
                                      ),
                                      SizedBox(
                                        height: 20,
                                      ),
                                      GestureDetector(
                                          onTap: () async {
                                            await FirebaseFirestore.instance
                                                .collection("budget")
                                                .doc(userId.uid)
                                                .set({"budget": budget});
                                            refresh();
                                            Navigator.pop(context);
                                          },
                                          child: Container(
                                            height: 40,
                                            width: 100,
                                            decoration: BoxDecoration(
                                              color: theme.shiokuriBlue,
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child:Center(
                                              child: Text(
                                                "Save",
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                  fontSize: 17,)
                                                ),
                                            )
                                          )
                                          )
                                    ],
                                  ),
                                ));
                              });
                        },
                        child: Container(
                          height: 100,
                          width: 200,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                  color:
                                      const Color.fromARGB(255, 131, 131, 131),
                                  offset: Offset(0, 10),
                                  blurRadius: 10)
                            ],
                          ),
                          child: Center(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                Text(
                                  "Daily Budget",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      fontFamily: 'fancy'),
                                ),
                                Text(
                                  "RM ${budget ?? 0}",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16),
                                )
                              ])),
                        ),
                      ),
                      Column(children: [
                        Text('average/day'),
                        Text(
                          'RM ${getAverage()}',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 20),
                        ),
                        Text(
                          pace >= 0
                              ? 'You are saving :'
                              : 'You have exceeded :',
                          style: TextStyle(
                              fontFamily: 'fancy',
                              fontWeight: FontWeight.bold,
                              color: const Color.fromARGB(255, 54, 54, 54)),
                        ),
                        Text(
                          "RM ${pace}",
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                              color: pace <= 0 ? Colors.red : Colors.green),
                        ),
                      ]),
                    ]),
                SizedBox(
                  height: 20,
                ),
                Expanded(
                    child: Container(
                        decoration: BoxDecoration(
                          borderRadius:
                              BorderRadius.only(topRight: Radius.circular(60)),
                          gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                theme.shiokuriBlue,
                                const Color.fromARGB(255, 235, 235, 235)
                              ]),
                        ),
                        child: ClipRRect(
                            borderRadius: BorderRadius.only(
                                topRight: Radius.circular(60)),
                          child:LiquidPullToRefresh(
                            backgroundColor: theme.shiokuriBlue,
                            color: Colors.white,
                            springAnimationDurationInMilliseconds: 400,
                            onRefresh: () {
                              return refresh();
                            },
                            child: isLoading
                                ? Center(
                                    child: Column(children: [
                                    SizedBox(
                                      height: 20,
                                    ),
                                    monthModifier(),
                                    CircularProgressIndicator()
                                  ]))
                                : doesExist
                                    ? ListView.builder(
                                        itemCount: expenseModels.length,
                                        itemBuilder: (context, index) {
                                          print(expenseModels[index].date);
                                          if (index > 0) {
                                            if (expenseModels[index].date !=
                                                expenseModels[index - 1].date) {
                                              print(
                                                  "${expenseModels[index].date} and the previous one is ,${expenseModels[index - 1].date}");
                                              return Column(children: [
                                                Text(
                                                  "Day ${expenseModels[index].date}",
                                                  style: TextStyle(
                                                      fontSize: 16,
                                                      fontFamily: 'fancy',
                                                      fontWeight:
                                                          FontWeight.bold),
                                                ),
                                                expenseTile(index),
                                              ]);
                                            } else {
                                              print(
                                                  "${expenseModels[index].date} and the previous one is ,${expenseModels[index - 1].date}");
                                              return expenseTile(index);
                                            }
                                          } else {
                                            return Column(children: [
                                              SizedBox(
                                                height: 20,
                                              ),
                                              monthModifier(),
                                              SizedBox(
                                                height: 20,
                                              ),
                                              Text(
                                                "Day ${expenseModels[index].date}",
                                                style: TextStyle(
                                                    fontSize: 16,
                                                    fontFamily: 'fancy',
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                              expenseTile(index),
                                            ]);
                                          }
                                        },
                                      )
                                    : 
                                    Center(
                                        child: LiquidPullToRefresh(
                                        onRefresh: () {
                                          return refresh();
                                        },
                                        child: ListView(children: [
                                          SizedBox(
                                            height: 20,
                                          ),
                                          monthModifier(),
                                          SizedBox(
                                            height: 30,
                                          ),
                                          Text(
                                            'Record doesnt exist',
                                            style: TextStyle(
                                                fontFamily: 'fancy',
                                                fontWeight: FontWeight.bold,
                                                color: const Color.fromARGB(
                                                    255, 39, 39, 39)),
                                            textAlign: TextAlign.center,
                                          ),
                                          SizedBox(
                                            height: 20,
                                          ),
                                        ]),
                                      )
                                    )
                                  )
                                ))
                              )
              ],
            )
          : Center(
              child: LiquidPullToRefresh(
              onRefresh: () {
                return refresh();
              },
              child: ListView(
                children: [
                  Icon(Icons.wifi_off),
                  Text(
                    'You are offline',
                    style: TextStyle(fontFamily: 'fancy', fontSize: 20),
                  ),
                  Text(
                    'Please check your internet connection',
                    style: TextStyle(fontFamily: 'fancy', fontSize: 20),
                  ),
                  SizedBox(
                    height: 20,
                  ),
                  ElevatedButton(
                      onPressed: () {
                        fetchData(formattedDate);
                      },
                      child: Text('Retry'))
                ],
              ),
            )),
    );
  }

  Widget monthModifier() {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      //to last month
      GestureDetector(
          onTap: () {
            month--;
            if (month == 0) {
              month = 12;
              year--;
            }
            String customDate = "${year}-${month.toString().padLeft(2, '0')}";
            fetchData(customDate);
          },
          child: Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20), color: Colors.blue),
            child: Center(
                child: Icon(
              Icons.arrow_left_sharp,
              color: Colors.white,
            )),
          )),

      SizedBox(
        width: 20,
      ),
      Text(
        '${year}-${month}',
        style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'fancy'),
      ),
      //to next month
      SizedBox(
        width: 20,
      ),
      GestureDetector(
          onTap: () {
            month++;
            if (month == 13) {
              month = 1;
              year++;
            }
            String customDate = "${year}-${month.toString().padLeft(2, '0')}";
            fetchData(customDate);
          },
          child: Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20), color: Colors.blue),
            child: Center(
                child: Icon(
              Icons.arrow_right,
              color: Colors.white,
            )),
          )),
    ]);
  }

  Widget expenseTile(int index) {

    int whichIndex = expenseInstances().icons.indexWhere(
        (element) => element.itemName.toLowerCase() == expenseModels[index].category!.toLowerCase());
    return ListTile(
      leading: expenseInstances().icons[whichIndex].itemIcon,
      title: Text(
        "RM ${expenseModels[index].amount}",
        style: TextStyle(
            fontWeight: FontWeight.bold,
            color: const Color.fromARGB(255, 50, 50, 50)),
      ),
      subtitle: Text("${expenseModels[index].description}",
          maxLines: 1,
          style: TextStyle(
              fontWeight: FontWeight.bold,
              color: const Color.fromARGB(255, 81, 81, 81))),
      onTap: () {
        showModalBottomSheet(
            context: context,
            builder: (context) {
              return DraggableScrollableSheet(
                expand: false,
                initialChildSize: 0.6,
                minChildSize: 0.1,
                maxChildSize: 0.7,
                builder: (context, scrollController) {
                  return Container(
                      height: 200,
                      child: SingleChildScrollView(
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                            Padding(
                              padding: EdgeInsets.all(10),
                              child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 100,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(3),
                                        color: const Color.fromARGB(
                                            255, 104, 104, 104),
                                      ),
                                    )
                                  ]),
                            ),
                            ListTile(
                              title: Text(
                                "Amount: RM${expenseModels[index].amount}",
                                style: TextStyle(
                                    fontSize: 30, fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                "Description: ${expenseModels[index].description}",
                                style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        const Color.fromARGB(255, 86, 86, 86)),
                              ),
                            ),
                            SizedBox(
                              height: 20,
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                GestureDetector(
                                  child: Container(
                                      height: 40,
                                      width: 40,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(20),
                                        color: Colors.red,
                                      ),
                                      child: Icon(
                                        Icons.delete,
                                        color: Colors.white,
                                      )),
                                  onTap: () async {
                                    await FirebaseFirestore.instance
                                        .collection("expenses")
                                        .doc(userId.uid)
                                        .collection(formattedDate)
                                        .doc(expenseModels[index].id)
                                        .delete();
                                    refresh();
                                    Navigator.pop(context);
                                  },
                                ),
                                GestureDetector(
                                  child: Container(
                                      height: 40,
                                      width: 40,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(20),
                                        color: Colors.green,
                                      ),
                                      child: Icon(Icons.edit,
                                          color: Colors.white)),
                                  onTap: () {
                                    //================================edit the record ===============================
                                    Navigator.pop(context);
                                    //=====
                                    EditedId = expenseModels[index].id;
                                    amount =
                                        expenseModels[index].amount.toString();
                                    description =
                                        expenseModels[index].description ?? '';
                                    editingDate =
                                        expenseModels[index].date.toString();

                                    print('edited id is $EditedId');
                                    print('amount is $amount');
                                    print('description is $description');

                                    showModalBottomSheet(
                                      enableDrag: true,
                                      isScrollControlled: true,
                                      context: context,
                                      builder: (context) {
                                        return DraggableScrollableSheet(
                                          initialChildSize: 0.7,
                                          minChildSize: 0.4,
                                          maxChildSize: 0.7,
                                          expand: false,
                                          builder: (context, scrollController) {
                                            return StatefulBuilder(
                                              builder: (context,
                                                  StateSetter setState) {
                                                return enterExpense(
                                                  context,
                                                  setState,
                                                  scrollController,
                                                );
                                              },
                                            );
                                          },
                                        );
                                      },
                                    );
                                  },
                                )
                              ],
                            ),
                          ])));
                },
              );
            });
      },
    );
  }

  


//edit, enter expense

  Widget enterExpense(
    BuildContext context,
    StateSetter setState,
    ScrollController scrollController,
  ) {
    print('enter expense was called');
    String errTxt = "";

    //keep the value even if setstate is called by using value defined outside of the method
    _budgetController.text = amount;
    _descriptionController.text = description;

    return Container(
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
            TextField(
              onChanged: (value) {
                amount = value;
              },
              onSubmitted: (vlaue) {
                print('onsubmit called $vlaue');
                _budgetController.text = amount;
                _descriptionController.text = description;
              },
              keyboardType: TextInputType.number,
              controller: _budgetController,
              decoration: InputDecoration(
                icon: Icon(Icons.monetization_on, color: Colors.black),
                hintText: "Enter amount",
              ),
            ),

            //description field

            TextField(
              onChanged: (value) {
                print('value is $value');
                description = value;
              },
              onSubmitted: (vlaue) {
                print('onsubmit called $vlaue');
              },
              controller: _descriptionController,
              decoration: InputDecoration(
                icon: Icon(Icons.edit),
                hintText: "Description (optional)",
              ),
            ),
            //////
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    'Category : ${category}',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color.fromARGB(255, 90, 90, 90),
                        fontSize: 20),
                  ),
                )
              ],
            ),
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 231, 231, 231), // 背景色
                borderRadius: BorderRadius.circular(20), // 角を丸くする
                boxShadow: [
                  BoxShadow(
                    color: const Color.fromARGB(255, 255, 255, 255),
                    spreadRadius: 2,
                    blurRadius: 5,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20), // ClipRRect で角丸を適用
                child: PrimaryScrollController(
                  controller: scrollController,
                  child: GridView.builder(
                  padding: EdgeInsets.all(10), // アイコンが枠にくっつかないように余白を追加
                  itemCount: expenseInstances().icons.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4, // 3列
                    crossAxisSpacing: 20.0,
                    mainAxisSpacing: 20.0,
                  ),
                  itemBuilder: (BuildContext context, int index) {
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          category = expenseInstances().icons[index].itemName;
                        });
                      },
                      child: expenseInstances().icons[index].itemIcon,
                    );
                  },
                ),
              ),)
            ),
            SizedBox(height: 10),
            Text(
              errTxt,
              style: TextStyle(color: Colors.red),
            ),
            GestureDetector(
              onTap: () async {
                print('amount is ${amount}');
                double? enteredExpense = double.tryParse(amount);
                print('budget is $enteredExpense');

                if (enteredExpense != null) {
                  try {
                    Uuid uuid = Uuid();
                    String id = uuid.v4();
                    DateTime now = DateTime.now();
                    int? parsedDate = int.tryParse(editingDate);

                    await FirebaseFirestore.instance
                        .collection("expenses")
                        .doc(userId.uid)
                        .collection(formattedDate)
                        .doc(EditedId == '' ? id : EditedId)
                        .set({
                      "category": category,
                      "amount": enteredExpense,
                      "description": description,
                      "date": parsedDate ?? now.day,
                    });

                    if (context.mounted) {
                      amount = '';
                      description = '';
                      EditedId = '';
                      _budgetController.text = '';
                      _descriptionController.text = '';
                      editingDate = '';

                      Navigator.pop(context);
                      refresh();
                    }
                  } catch (e) {
                    print("Error saving data: $e");
                  }
                } else {
                  setState(() {
                    errTxt = "Please enter a valid number";
                  });
                }
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
  }
}
