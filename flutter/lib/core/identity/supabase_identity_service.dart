import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import 'identity_models.dart';
import 'identity_service.dart';

final class SupabaseIdentityService implements IdentityService {
  SupabaseIdentityService(this._config);

  final AppConfig _config;
  final StreamController<IdentitySession> _state =
      StreamController<IdentitySession>.broadcast();

  StreamSubscription<AuthState>? _authSubscription;
  IdentitySession _current = const IdentitySession.localOnly();
  bool _initialized = false;

  @override
  IdentitySession get current => _current;

  @override
  Stream<IdentitySession> watch() => _state.stream;

  SupabaseClient get _client => Supabase.instance.client;

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    if (!_config.cloudConfigured) {
      _emit(const IdentitySession.localOnly());
      return;
    }

    try {
      await Supabase.initialize(
        url: _config.supabaseUrl.trim(),
        anonKey: _config.supabasePublishableKey.trim(),
      );

      _authSubscription = _client.auth.onAuthStateChange.listen((_) {
        _emitFromClient();
      });

      _emitFromClient();
    } catch (error) {
      _emit(
        IdentitySession(
          status: IdentityStatus.error,
          message: error.toString(),
        ),
      );
    }
  }

  @override
  Future<void> signInWithGoogle() async {
    _requireCloud();
    final started = await _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: _config.oauthRedirect,
      scopes: 'openid email profile',
      authScreenLaunchMode:
          kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
    );
    if (!started) {
      throw const AuthException('Google sign-in could not be started.');
    }
  }

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    _requireCloud();
    await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    _emitFromClient();
  }

  @override
  Future<void> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    _requireCloud();
    if (password.length < 8) {
      throw const AuthException('Password must contain at least 8 characters.');
    }
    await _client.auth.signUp(
      email: email.trim(),
      password: password,
      emailRedirectTo: _config.oauthRedirect,
    );
    _emitFromClient();
  }

  @override
  Future<void> signOut() async {
    if (!_config.cloudConfigured) return;
    await _client.auth.signOut();
    _emit(const IdentitySession.signedOut());
  }

  void _requireCloud() {
    if (!_config.cloudConfigured) {
      throw StateError(
        'Supabase is not configured. Local Wonderlog remains available.',
      );
    }
  }

  void _emitFromClient() {
    final session = _client.auth.currentSession;
    final user = session?.user;
    if (user == null) {
      _emit(const IdentitySession.signedOut());
      return;
    }

    final metadata = user.userMetadata;
    _emit(
      IdentitySession(
        status: IdentityStatus.signedIn,
        user: IdentityUser(
          id: user.id,
          email: user.email,
          displayName:
              metadata?['full_name']?.toString() ??
              metadata?['name']?.toString(),
          avatarUrl:
              metadata?['avatar_url']?.toString() ??
              metadata?['picture']?.toString(),
        ),
      ),
    );
  }

  void _emit(IdentitySession value) {
    _current = value;
    if (!_state.isClosed) {
      _state.add(value);
    }
  }

  @override
  Future<void> dispose() async {
    await _authSubscription?.cancel();
    await _state.close();
  }
}
