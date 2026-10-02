import 'package:flutter/foundation.dart';

final class AppConfig {
  const AppConfig({
    required this.supabaseUrl,
    required this.supabasePublishableKey,
    required this.mobileAuthRedirect,
    required this.webAuthRedirect,
  });

  static const current = AppConfig(
    supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
    supabasePublishableKey: String.fromEnvironment(
      'SUPABASE_PUBLISHABLE_KEY',
    ),
    mobileAuthRedirect: String.fromEnvironment(
      'WONDERLOG_AUTH_REDIRECT',
      defaultValue: 'com.riccardopinato.wonderlog://login-callback/',
    ),
    webAuthRedirect: String.fromEnvironment('WONDERLOG_WEB_AUTH_REDIRECT'),
  );

  final String supabaseUrl;
  final String supabasePublishableKey;
  final String mobileAuthRedirect;
  final String webAuthRedirect;

  bool get cloudConfigured =>
      supabaseUrl.trim().isNotEmpty &&
      supabasePublishableKey.trim().isNotEmpty;

  String get oauthRedirect {
    if (kIsWeb && webAuthRedirect.trim().isNotEmpty) {
      return webAuthRedirect.trim();
    }
    return mobileAuthRedirect.trim();
  }
}
