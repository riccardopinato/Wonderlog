abstract interface class EcosystemLocalTransportPort {
  Future<bool> tryOpen(Uri targetUri);

  Future<void> copyPortableFallback(String portablePayload);
}
