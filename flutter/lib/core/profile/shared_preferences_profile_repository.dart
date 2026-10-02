import 'package:shared_preferences/shared_preferences.dart';

import 'app_profile.dart';
import 'profile_repository.dart';

final class SharedPreferencesProfileRepository implements ProfileRepository {
  static const _themeKey = 'profile.theme';
  static const _languageModeKey = 'profile.language_mode';
  static const _localeKey = 'profile.locale';

  @override
  Future<AppProfile> load() async {
    final prefs = await SharedPreferences.getInstance();
    final theme = ThemePreference.values.firstWhere(
      (value) => value.name == prefs.getString(_themeKey),
      orElse: () => ThemePreference.system,
    );
    final languageMode = LanguageMode.values.firstWhere(
      (value) => value.name == prefs.getString(_languageModeKey),
      orElse: () => LanguageMode.device,
    );
    final selectedLocale = prefs.getString(_localeKey);

    return AppProfile(
      themePreference: theme,
      languageMode: languageMode,
      selectedLocale: languageMode == LanguageMode.manual
          ? selectedLocale
          : null,
    );
  }

  @override
  Future<void> save(AppProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, profile.themePreference.name);
    await prefs.setString(_languageModeKey, profile.languageMode.name);
    if (profile.selectedLocale == null) {
      await prefs.remove(_localeKey);
    } else {
      await prefs.setString(_localeKey, profile.selectedLocale!);
    }
  }
}
