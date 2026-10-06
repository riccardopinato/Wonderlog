import 'package:flutter/foundation.dart';

final class AppConfig {
  const AppConfig({
    required this.supabaseUrl,
    required this.supabasePublishableKey,
    required this.mobileAuthRedirect,
    required this.webAuthRedirect,
    required this.cloudDataEnabled,
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
    cloudDataEnabled: bool.fromEnvironment(
      'WONDERLOG_CLOUD_DATA_ENABLED',
      defaultValue: true,
    ),
  );

  final String supabaseUrl;
  final String supabasePublishableKey;
  final String mobileAuthRedirect;
  final String webAuthRedirect;
  final bool cloudDataEnabled;

  bool get cloudConfigured =>
      supabaseUrl.trim().isNotEmpty &&
      supabasePublishableKey.trim().isNotEmpty;

  bool get cloudDataConfigured => cloudConfigured && cloudDataEnabled;

  String get oauthRedirect {
    if (kIsWeb && webAuthRedirect.trim().isNotEmpty) {
      return webAuthRedirect.trim();
    }
    return mobileAuthRedirect.trim();
  }
}
