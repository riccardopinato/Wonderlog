import 'dart:async';

import 'package:flutter/material.dart';

import 'identity/identity_models.dart';
import 'identity/identity_service.dart';
import 'profile/app_profile.dart';
import 'profile/profile_repository.dart';

final class AppController extends ChangeNotifier {
  AppController({
    required ProfileRepository profileRepository,
    required IdentityService identityService,
  })  : _profileRepository = profileRepository,
        identityService = identityService;

  final ProfileRepository _profileRepository;
  final IdentityService identityService;

  AppProfile _profile = const AppProfile.defaults();
  IdentitySession _identity = const IdentitySession.localOnly();
  StreamSubscription<IdentitySession>? _identitySubscription;

  AppProfile get profile => _profile;
  IdentitySession get identity => _identity;

  ThemeMode get themeMode => switch (_profile.themePreference) {
        ThemePreference.light => ThemeMode.light,
        ThemePreference.dark => ThemeMode.dark,
        ThemePreference.system => ThemeMode.system,
      };

  Locale? get locale {
    if (_profile.languageMode == LanguageMode.device) return null;
    final code = _profile.selectedLocale;
    if (code == null || code.isEmpty) return null;
    return Locale(code);
  }

  Future<void> initialize() async {
    _profile = await _profileRepository.load();
    await identityService.initialize();
    _identity = identityService.current;
    _identitySubscription = identityService.watch().listen((value) {
      _identity = value;
      notifyListeners();
    });
  }

  Future<void> setTheme(ThemePreference value) async {
    _profile = _profile.copyWith(themePreference: value);
    await _profileRepository.save(_profile);
    notifyListeners();
  }

  Future<void> useDeviceLanguage() async {
    _profile = _profile.copyWith(
      languageMode: LanguageMode.device,
      clearSelectedLocale: true,
    );
    await _profileRepository.save(_profile);
    notifyListeners();
  }

  Future<void> setLanguage(String code) async {
    _profile = _profile.copyWith(
      languageMode: LanguageMode.manual,
      selectedLocale: code,
    );
    await _profileRepository.save(_profile);
    notifyListeners();
  }

  @override
  void dispose() {
    _identitySubscription?.cancel();
    identityService.dispose();
    super.dispose();
  }
}
