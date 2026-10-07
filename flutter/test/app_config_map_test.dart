import 'package:flutter_test/flutter_test.dart';
import 'package:wonderlog/core/config/app_config.dart';

void main() {
  test('authorized offline style becomes the effective rendered style', () {
    const config = AppConfig(
      supabaseUrl: '',
      supabasePublishableKey: '',
      mobileAuthRedirect: '',
      webAuthRedirect: '',
      cloudDataEnabled: false,
      mapStyleUrl: 'https://online.example/style.json',
      offlineMapStyleUrl: 'https://offline.example/style.json',
      routingBaseUrl: '',
    );

    expect(config.offlineMapsConfigured, isTrue);
    expect(
      config.effectiveMapStyleUrl,
      'https://offline.example/style.json',
    );
  });

  test('online style is fallback when offline provider is absent', () {
    const config = AppConfig(
      supabaseUrl: '',
      supabasePublishableKey: '',
      mobileAuthRedirect: '',
      webAuthRedirect: '',
      cloudDataEnabled: false,
      mapStyleUrl: 'https://online.example/style.json',
      offlineMapStyleUrl: '',
      routingBaseUrl: '',
    );

    expect(config.offlineMapsConfigured, isFalse);
    expect(config.effectiveMapStyleUrl, 'https://online.example/style.json');
  });
}
