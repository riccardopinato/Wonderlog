import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wonderlog/core/profile/app_profile.dart';
import 'package:wonderlog/core/profile/shared_preferences_profile_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('profile defaults to device language and system theme', () async {
    final repository = SharedPreferencesProfileRepository();

    final profile = await repository.load();

    expect(profile.languageMode, LanguageMode.device);
    expect(profile.selectedLocale, isNull);
    expect(profile.themePreference, ThemePreference.system);
  });

  test('manual language and dark theme survive reload', () async {
    final repository = SharedPreferencesProfileRepository();
    await repository.save(
      const AppProfile(
        themePreference: ThemePreference.dark,
        languageMode: LanguageMode.manual,
        selectedLocale: 'it',
      ),
    );

    final restored = await repository.load();

    expect(restored.themePreference, ThemePreference.dark);
    expect(restored.languageMode, LanguageMode.manual);
    expect(restored.selectedLocale, 'it');
  });
}
