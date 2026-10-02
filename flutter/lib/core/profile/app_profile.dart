enum ThemePreference { system, light, dark }

enum LanguageMode { device, manual }

final class AppProfile {
  const AppProfile({
    required this.themePreference,
    required this.languageMode,
    this.selectedLocale,
  });

  const AppProfile.defaults()
      : themePreference = ThemePreference.system,
        languageMode = LanguageMode.device,
        selectedLocale = null;

  final ThemePreference themePreference;
  final LanguageMode languageMode;
  final String? selectedLocale;

  AppProfile copyWith({
    ThemePreference? themePreference,
    LanguageMode? languageMode,
    String? selectedLocale,
    bool clearSelectedLocale = false,
  }) {
    return AppProfile(
      themePreference: themePreference ?? this.themePreference,
      languageMode: languageMode ?? this.languageMode,
      selectedLocale:
          clearSelectedLocale ? null : selectedLocale ?? this.selectedLocale,
    );
  }
}
