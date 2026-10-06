import 'package:flutter/foundation.dart';

final class AppConfig {
  const AppConfig({
    required this.supabaseUrl,
    required this.supabasePublishableKey,
    required this.mobileAuthRedirect,
    required this.webAuthRedirect,
    required this.cloudDataEnabled,
    required this.mapStyleUrl,
    required this.offlineMapStyleUrl,
    required this.routingBaseUrl,
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
    mapStyleUrl: String.fromEnvironment(
      'WONDERLOG_MAP_STYLE_URL',
      defaultValue: 'https://tiles.openfreemap.org/styles/liberty',
    ),
    offlineMapStyleUrl: String.fromEnvironment(
      'WONDERLOG_OFFLINE_MAP_STYLE_URL',
    ),
    routingBaseUrl: String.fromEnvironment(
      'WONDERLOG_ROUTING_URL',
    ),
  );

  final String supabaseUrl;
  final String supabasePublishableKey;
  final String mobileAuthRedirect;
  final String webAuthRedirect;
  final bool cloudDataEnabled;
  final String mapStyleUrl;
  final String offlineMapStyleUrl;
  final String routingBaseUrl;

  bool get offlineMapsConfigured => offlineMapStyleUrl.trim().isNotEmpty;
  bool get roadRoutingConfigured => routingBaseUrl.trim().isNotEmpty;

  String get effectiveMapStyleUrl => offlineMapsConfigured
      ? offlineMapStyleUrl.trim()
      : mapStyleUrl.trim();

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
