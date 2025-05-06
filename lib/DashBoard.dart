import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:liquid_pull_to_refresh/liquid_pull_to_refresh.dart';
import 'package:moneymanager/model/expenseModel.dart';
import 'package:moneymanager/showUpdate.dart';
import 'package:moneymanager/themeColor.dart';
import 'package:moneymanager/uid/uid.dart';
import 'package:uuid/uuid.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  _DashboardState createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  final ShowUpdate UpdateChecker = ShowUpdate();
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
    final DraggableScrollableController draggableController =
      DraggableScrollableController();
    double sheetSize = 0.7;

  String EditedId = '';
  String editingDate = '';
  String amount = '';
  String description = '';
  bool isOnline = true;

  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    _performUpdateCheck();
    

    print("user id is " + userId.uid);
    DateTime now = DateTime.now();
    year = now.year;
    month = now.month;
    formattedDate = "${year}-${month.toString().padLeft(2, '0')}";

    fetchData(formattedDate);
  }

    void _performUpdateCheck() {
    // Pass the current context to ShowUpdate if needed for dialogs shown from within ShowUpdate
    // For this example, the dialog is shown from the callback.
    UpdateChecker.checkUpdate(context, (currentVersion, newVersion) {
      // This callback is triggered if an update is available
      if (mounted) { // Check if the widget is still in the tree
        showDialog(
          context: context,
          barrierDismissible: false, // User must tap button!
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: const Text("Update Available"),
              content: Text(
                  "A new version ($newVersion) is available. You are currently using version $currentVersion."),
              actions: <Widget>[
                TextButton(
                  child: const Text("Later"),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                ),
                TextButton(
                  child: const Text("Update Now"),
                  onPressed: () {
                    Navigator.of(dialogContext).pop(); // Dismiss the dialog first
                    UpdateChecker.launchAppStore(); // Call the method to launch URL
                  },
                ),
              ],
            );
          },
        );
      }
    });
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
      backgroundColor: Colors.white,
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
          sheetSize = 0.7;
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
              return enterExpense(
                context,
                setState,
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
                                          color: const Color.fromARGB(
                                              255, 35, 35, 35),
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
                                            color: const Color.fromARGB(
                                                255, 46, 46, 46)),
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
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Center(
                                                child: Text("Save",
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.white,
                                                      fontSize: 17,
                                                    )),
                                              )))
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
                            child: LiquidPullToRefresh(
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
                                                    expenseModels[index - 1]
                                                        .date) {
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
                                        : Center(
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
                                          ))))))
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
    int whichIndex = expenseInstances().icons.indexWhere((element) =>
        element.itemName.toLowerCase() ==
        expenseModels[index].category!.toLowerCase());
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
                                    sheetSize = 0.7;
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
                                        return enterExpense(
                                          context,
                                          setState,
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

  

  Widget enterExpense(
  BuildContext context,
  StateSetter setStateParent, // setState from the widget that calls showModalBottomSheet
) {
  print('enter expense was called');

  // Variables local to this invocation of enterExpense, managed by StatefulBuilder's setState
  String errTxt = ""; // Used for DraggableScrollableSheet's 'expand' property



  // Pre-fill controllers when the sheet is first built.
  // These lines run once per call to enterExpense.
  _budgetController.text = amount;
  _descriptionController.text = description;
  

  return StatefulBuilder(builder: (context, StateSetter setState) {
    // 'setState' here is local to this StatefulBuilder.
    // It will rebuild the DraggableScrollableSheet and its contents.
    return DraggableScrollableSheet(
      initialChildSize: sheetSize,
      controller: draggableController,
      minChildSize: 0.4,
      maxChildSize: 1.0, // Explicitly defining max size
      expand: false, // If true, sheet tries to expand to maxChildSize
      builder: (sheetContext, scrollController) { // Renamed context to sheetContext
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(sheetContext).canvasColor, // Background for the sheet
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
            boxShadow: [ // Optional: Add a subtle shadow
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                spreadRadius: 0,
              ),
            ]
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            padding: EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SizedBox(height: 12), // Space for drag handle
                Container( // Drag handle
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
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
                SizedBox(height: 15),

                // Budget field
                TextField(
                  onTap: () {
                    print("scrolling up ");
                    setState(() {
                      sheetSize = 1.0;
                    });
                  },
                  onChanged: (value) {
                    amount = value; // Update parent-level variable (ensure parent handles state)
                  },
                  onSubmitted: (value) {
                    print('onsubmit called for budget: $value');
                    // Potentially move focus or trigger validation
                  },
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  controller: _budgetController,
                  decoration: InputDecoration(
                    icon: Icon(Icons.monetization_on, color: Colors.black54),
                    hintText: "Enter amount",
                    border: UnderlineInputBorder(),
                  ),
                ),

                SizedBox(height: 10),

                // Description field
                TextField(
                  onTap: () {
                    setState(() {
                      sheetSize = 1.0;
                    });
                    // If you also want to set the 'expand' property directly:
                    // setState(() {
                    //   isExapanded = true;
                    // });
                  },
                  onChanged: (value) {
                    print('description value is $value');
                    description = value; // Update parent-level variable
                  },
                  onSubmitted: (value) {
                    print('onsubmit called for description: $value');
                  },
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    icon: Icon(Icons.edit, color: Colors.black54),
                    hintText: "Description (optional)",
                    border: UnderlineInputBorder(),
                  ),
                ),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        'Category : ${category}', // Display current category
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color.fromARGB(255, 90, 90, 90),
                            fontSize: 18), // Adjusted size
                      ),
                    )
                  ],
                ),
                Container(
                    height: 200, // Fixed height for GridView container
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 240, 240, 240), // Lighter background
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: GridView.builder( // Removed PrimaryScrollController wrapper
                        controller: scrollController, // Use the sheet's scrollController
                        padding: EdgeInsets.all(15),
                        itemCount: expenseInstances().icons.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: 15.0, // Adjusted spacing
                          mainAxisSpacing: 15.0,   // Adjusted spacing
                        ),
                        itemBuilder: (BuildContext context, int index) {
                          final item = expenseInstances().icons[index];
                          bool isSelected = category == item.itemName;
                          return GestureDetector(
                            onTap: () {
                              setState(() { // This updates the UI within the StatefulBuilder
                                category = item.itemName;
                              });
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected ? theme.shiokuriBlue.withOpacity(0.3) : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: isSelected ? Border.all(color: theme.shiokuriBlue, width: 2) : null,
                              ),
                              child: Tooltip(
                                message: item.itemName,
                                child: Column( // To show icon and optionally text
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    item.itemIcon,
                                    // Text(item.itemName, style: TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis) // Optional: show name
                                  ],
                                ),
                              )
                            ),
                          );
                        },
                      ),
                    )),
                SizedBox(height: 15),
                if (errTxt.isNotEmpty) // Only show error text if it's not empty
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      errTxt,
                      style: TextStyle(color: Colors.red, fontSize: 14),
                    ),
                  ),
                GestureDetector(
                  onTap: () async {
                    // Basic validation
                    if (amount.trim().isEmpty || double.tryParse(amount.trim()) == null) {
                      setState(() {
                        errTxt = "Please enter a valid amount.";
                      });
                      return;
                    }
                    if (category.isEmpty) {
                       setState(() {
                        errTxt = "Please select a category.";
                      });
                      return;
                    }
                    setState(() { // Clear error on successful validation start
                      errTxt = "";
                    });

                    double? enteredExpense = double.tryParse(amount.trim());

                    if (enteredExpense != null) { // Should always be true due to above check
                      try {
                        Uuid uuid = Uuid();
                        String id = uuid.v4(); // Generate new ID
                        DateTime now = DateTime.now();
                        int? parsedDate = int.tryParse(editingDate); // Day of the month

                        // Construct the date for the expense
                        // Assuming formattedDate is "YYYY-MM" and parsedDate is "DD"
                        // More robust date handling might be needed
                        // For simplicity, using now.day if editingDate is invalid

                        await FirebaseFirestore.instance
                            .collection("expenses")
                            .doc(userId.uid) // User's specific expenses
                            .collection(formattedDate) // Collection per month (e.g., "2024-05")
                            .doc(EditedId.isEmpty ? id : EditedId) // Use new ID or existing ID
                            .set({
                          "category": category,
                          "amount": enteredExpense,
                          "description": description.trim(),
                          "date": parsedDate ?? now.day, // Storing day of the month
                          "timestamp": FieldValue.serverTimestamp(), // For ordering
                          "monthYear": formattedDate, // Store YYYY-MM for easier querying
                          "expenseId": EditedId.isEmpty ? id : EditedId, // Store the ID itself
                        });

                        if (sheetContext.mounted) { // Use sheetContext
                          // Reset parent-level variables (ensure parent handles this state change)
                          amount = '0.0';
                          description = '';
                          EditedId = '';
                          _budgetController.clear();
                          _descriptionController.clear();
                          editingDate = '';
                          // category = "Food"; // Optionally reset category

                          Navigator.pop(sheetContext); // Use sheetContext
                          sheetSize = 0.7;
                          refresh(); // Call parent's refresh
                        }
                      } catch (e) {
                        sheetSize = 0.7;
                        print("Error saving data: $e");
                        
                      }
                    }
                    // No 'else' needed here for enteredExpense == null because of earlier validation
                  },
                  child: Container(
                    width: double.infinity, // Make button wider
                    padding: EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      color: theme.shiokuriBlue,
                      borderRadius: BorderRadius.circular(30), // More rounded
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        EditedId.isEmpty ? 'Save Expense' : 'Update Expense',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 16),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: MediaQuery.of(sheetContext).padding.bottom + 20), // Ensure content is above navigation bar
              ],
            ),
          ),
        );
      },
    );
  });
}

  Future<void> sheetScroller() async{
    await Future.delayed(Duration(milliseconds: 100));
    draggableController.animateTo(
      1.0, // Target max size
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }
}
