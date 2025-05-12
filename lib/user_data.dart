import 'package:firebase_auth/firebase_auth.dart';

class CurrentUser {
  static String currentUserUid = ""; // Initialize as empty or null

  // Initialize user based on Auth state. Call this AFTER Firebase.initializeApp()
  // and ideally in response to auth state changes.
  static void updateUser(User? user) {
    if (user != null) {
      currentUserUid = user.uid;
      print('CurrentUser updated: uid : $currentUserUid');
    } else {
      currentUserUid = ""; // Clear UID if user is null
      print('CurrentUser updated: No user signed in.');
    }
  }
}
