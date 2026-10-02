import 'identity_models.dart';

abstract interface class IdentityService {
  IdentitySession get current;
  Stream<IdentitySession> watch();

  Future<void> initialize();
  Future<void> signInWithGoogle();
  Future<void> signInWithEmail({
    required String email,
    required String password,
  });
  Future<void> signUpWithEmail({
    required String email,
    required String password,
  });
  Future<void> signOut();
  Future<void> dispose();
}
