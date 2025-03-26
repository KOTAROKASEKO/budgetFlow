import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:moneymanager/DashBoard.dart';
import 'package:moneymanager/firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:moneymanager/google_login.dart';
import 'package:moneymanager/uid/uid.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Ensure bindings are initialized

  await Firebase.initializeApp(
    options:
        DefaultFirebaseOptions.currentPlatform, // Uses auto-generated options
  );

  bool isLoggedIn = await getLoginStatus();

  runApp(MyApp(isLoggedIn: isLoggedIn));
}

Future<bool> getLoginStatus() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool isLoggedIn = prefs.getBool("isLoggedIn") ?? false;
  if (isLoggedIn) {
    userId.initUid();
  }
  return isLoggedIn;
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;

  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: isLoggedIn ? Dashboard() : AuthPage(),
    );
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  get sharedPreferences => null;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  CarouselController controller = CarouselController();

  @override
  void initState() {
    super.initState(); // Call the overridden method
    controller.addListener(() {
      if (controller.position.pixels <= 0) {
        // If at the start of the carousel
        setState(() {
          isSignIn = true;
        });
      } else if (controller.position.pixels >=
          controller.position.maxScrollExtent) {
        // If at the end of the carousel
        setState(() {
          isSignIn = false;
        });
      }
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> _signInWithEmail() async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      print("Signed in: ${_auth.currentUser?.email}");
      toggleLoginStatus();
    } catch (e) {
      print("Sign-In Error: $e");
    }
  }

  Future<void> _signUpWithEmail() async {
    try {
      await _auth.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      print("User registered: ${_auth.currentUser?.email}");
      toggleLoginStatus();
    } catch (e) {
      print("Sign-Up Error: $e");
    }
  }

  
  Future<void> toggleLoginStatus() async {
    SharedPreferences sharedPreferences = await SharedPreferences.getInstance();
    sharedPreferences.setBool("isLoggedIn", true);
    userId.initUid();
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (context) => Dashboard()));
  }

  bool isSignIn = true;

  void toggle(bool signInSelected) {
    setState(() {
      isSignIn = signInSelected;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              SizedBox(
                height: 100,
              ),
              toggleButton(),
              SizedBox(
                height: 20,
              ),
              Container(
                  decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 215, 215, 215),
                      borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: EdgeInsets.all(5),
                    child: TextField(
                      controller: emailController,
                      decoration: InputDecoration(
                        labelText: "  Email",
                        border: InputBorder.none, // Removes the border line
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                  )),
              SizedBox(
                height: 20,
              ),
              Container(
                  decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 215, 215, 215),
                      borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: EdgeInsets.all(5),
                    child: TextField(
                      obscureText: true,
                      controller: passwordController,
                      decoration: InputDecoration(
                        labelText: "  Password",
                        border: InputBorder.none, // Removes the border line
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                  )),
              SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  isSignIn ? _signInWithEmail() : _signUpWithEmail();
                },
                child: Container(
                  width: 200,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 152, 209, 255),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Center(
                    child: Text(
                      'Enter→',
                      style: TextStyle(
                          color: const Color.fromARGB(255, 255, 255, 255),
                          fontSize: 20,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 16),
              signInWithGoogleUI(),
            ],
          ),
        ),
      ),
    );
  }
   

   signInWithGoogleUI() {
    return InkWell(
      onTap: (){
        GoogleLogin.signInWithGoogle().then((data){
          if(data != null){
            toggleLoginStatus();
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 30.0,vertical: 8.0),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
              color: Colors.black.withOpacity(0.2)
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 30,
              width: 30,
              child: Image.network(
                "https://cdn.iconscout.com/icon/free/png-256/free-google-1772223-1507807.png",
                height: 40,
                width: 40,
              ),
            ),
            const SizedBox(
              width: 10.0,
            ),
            const  Text("Sign In With Google", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600, height: 0),)
          ],
        ),
      ),
    );
  }

  Widget toggleButton() {
    return Column(children: [
      Container(
          height: 200,
          width: 200,
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 236, 236, 236),
            borderRadius: BorderRadius.circular(100),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints.tightFor(width: 250, height: 60),
            child: NotificationListener<ScrollNotification>(
                onNotification: (scrollNotification) {
                  if (scrollNotification is ScrollEndNotification) {
                    if (controller.position.pixels <= 0) {
                      setState(() {
                        isSignIn = true;
                      });
                    } else if (controller.position.pixels >=
                        controller.position.maxScrollExtent) {
                      setState(() {
                        isSignIn = false;
                      });
                    }
                  }
                  return true;
                },
                child: CarouselView(
                  controller: controller,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  itemExtent: 200,
                  shrinkExtent: 100,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue, Colors.purple], // グラデーションの色
                          begin: Alignment.topLeft, // グラデーションの開始位置
                          end: Alignment.bottomRight, // グラデーションの終了位置
                        ),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Center(
                        child: Text(
                          "Sign In",
                          maxLines: 1,
                          style: TextStyle(
                            color: const Color.fromARGB(255, 255, 255, 255),
                            fontWeight: FontWeight.w300,
                            fontFamily: 'fancy',
                            fontSize: 20,
                          ),
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color.fromARGB(255, 117, 242, 251),
                            const Color.fromARGB(255, 215, 120, 131)
                          ], // グラデーションの色
                          begin: Alignment.topLeft, // グラデーションの開始位置
                          end: Alignment.bottomRight, // グラデーションの終了位置
                        ),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Center(
                        child: Text(
                          "Sign Up",
                          maxLines: 1,
                          style: TextStyle(
                            color: const Color.fromARGB(255, 255, 255, 255),
                            fontWeight: FontWeight.w300,
                            fontFamily: 'fancy',
                            fontSize: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                )),
          )),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              color: isSignIn ? Colors.black : Colors.grey,
            ),
            width: 10,
            height: 10,
          ),
          SizedBox(
            width: 10,
          ),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              color: isSignIn ? Colors.grey : Colors.black,
            ),
            width: 10,
            height: 10,
          ),
        ],
      )
    ]);
  }
}
