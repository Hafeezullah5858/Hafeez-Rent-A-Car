import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth auth;
  AuthService([FirebaseAuth? value]) : auth = value ?? FirebaseAuth.instance;
  Stream<User?> get changes => auth.authStateChanges();
  Future<UserCredential> signIn(String email, String password) => auth.signInWithEmailAndPassword(email: email.trim(), password: password);
  Future<UserCredential> signUp(String email, String password) => auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
  Future<void> signOut() => auth.signOut();
  Future<void> sendPasswordReset(String email) => auth.sendPasswordResetEmail(email: email.trim());
}
