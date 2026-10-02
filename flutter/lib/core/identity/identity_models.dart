enum IdentityStatus {
  localOnly,
  signedOut,
  signedIn,
  error,
}

final class IdentityUser {
  const IdentityUser({
    required this.id,
    this.email,
    this.displayName,
    this.avatarUrl,
  });

  final String id;
  final String? email;
  final String? displayName;
  final String? avatarUrl;
}

final class IdentitySession {
  const IdentitySession({
    required this.status,
    this.user,
    this.message,
  });

  const IdentitySession.localOnly()
      : status = IdentityStatus.localOnly,
        user = null,
        message = null;

  const IdentitySession.signedOut()
      : status = IdentityStatus.signedOut,
        user = null,
        message = null;

  final IdentityStatus status;
  final IdentityUser? user;
  final String? message;
}
