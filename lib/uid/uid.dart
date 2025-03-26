import 'package:firebase_auth/firebase_auth.dart';

class userId{
  static String uid = "";

    static initUid() async {
    FirebaseAuth firebaseAuth = FirebaseAuth.instance;
    var currentUser = firebaseAuth.currentUser;
    if (currentUser != null) {
      uid = currentUser.uid;
      print('===========================');
      print('user id was initialised: $uid');
      print('===========================');
    } else {
      print('User is not logged in.');
    }
  }
}