import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';


class GoogleLogin {
  static Future<GoogleLoginModal?> signInWithGoogle() async {
    FirebaseAuth auth = FirebaseAuth.instance;
    GoogleLoginModal? googleLoginModal;
    final GoogleSignIn googleSignIn = GoogleSignIn();
    
    try {
      print('break point1');
      final GoogleSignInAccount? googleSignInAccount = await googleSignIn.signIn();
      
      if (googleSignInAccount != null) {
        final GoogleSignInAuthentication googleSignInAuthentication = await googleSignInAccount.authentication;
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleSignInAuthentication.accessToken,
          idToken: googleSignInAuthentication.idToken,
        );
        
        try {
          final UserCredential userCredential = await auth.signInWithCredential(credential);
          googleLoginModal = GoogleLoginModal(googleSignInAuthentication: googleSignInAuthentication, user: userCredential.user);
        } on FirebaseAuthException catch (e) {
          print("Firebase Auth Exception: ${e.message}");
        } catch (e) {
          print("Error signing in: ${e.toString()}");
        }
      } else {
        print("Google sign-in account is null");
      }
    } catch (e) {
      print("Error during Google sign-in process: ${e.toString()}");
    }
    return googleLoginModal;
  }
}

class GoogleLoginModal {
  User? user;
  GoogleSignInAuthentication googleSignInAuthentication;
  GoogleLoginModal({required this.googleSignInAuthentication,this.user});
}