import 'package:flutter/material.dart';

import '../../../app/theme/wonderlog_tokens.dart';
import '../../../core/app_controller.dart';
import '../../../core/config/app_config.dart';
import '../../../core/identity/identity_models.dart';
import '../../../core/ecosystem/ecosystem_models.dart';
import '../../../core/profile/app_profile.dart';
import '../../../core/runtime/wonderlog_services_scope.dart';
import '../../../l10n/app_localizations.dart';
import '../../cloud/presentation/cloud_backup_page.dart';
import '../../ecosystem/presentation/ecosystem_app_detail_page.dart';
import '../../premium/presentation/premium_page.dart';

final class ProfilePage extends StatelessWidget {
  const ProfilePage({
    super.key,
    required this.controller,
  });

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(strings.profileTitle)),
      body: ListView(
        padding: const EdgeInsets.all(WonderlogSpacing.medium),
        children: [
          _AccountCard(controller: controller),
          const SizedBox(height: WonderlogSpacing.medium),
          Card(
            child: ListTile(
              leading: Icon(
                controller.isPremium
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
              ),
              title: Text(strings.premiumTitle),
              subtitle: Text(
                controller.isPremium
                    ? strings.premiumActive
                    : strings.premiumProfileDescription,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => PremiumPage(
                    service: controller.premiumService,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: WonderlogSpacing.medium),
          Builder(
            builder: (context) {
              final cloudRuntime =
                  WonderlogServicesScope.maybeOf(context)?.cloudRuntime;
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.cloud_outlined),
                  title: Text(strings.cloudBackupTitle),
                  subtitle: Text(
                    cloudRuntime == null
                        ? strings.cloudNotConfigured
                        : strings.cloudBackupProfileDescription,
                  ),
                  trailing: cloudRuntime == null
                      ? null
                      : const Icon(Icons.chevron_right),
                  enabled: cloudRuntime != null,
                  onTap: cloudRuntime == null
                      ? null
                      : () => Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => CloudBackupPage(
                                runtime: cloudRuntime,
                                controller: controller,
                              ),
                            ),
                          ),
                ),
              );
            },
          ),
          const SizedBox(height: WonderlogSpacing.medium),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(WonderlogSpacing.medium),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.appearance,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: WonderlogSpacing.medium),
                  DropdownButtonFormField<ThemePreference>(
                    initialValue: controller.profile.themePreference,
                    decoration: InputDecoration(labelText: strings.theme),
                    items: [
                      DropdownMenuItem(
                        value: ThemePreference.system,
                        child: Text(strings.themeSystem),
                      ),
                      DropdownMenuItem(
                        value: ThemePreference.light,
                        child: Text(strings.themeLight),
                      ),
                      DropdownMenuItem(
                        value: ThemePreference.dark,
                        child: Text(strings.themeDark),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        controller.setTheme(value);
                      }
                    },
                  ),
                  const SizedBox(height: WonderlogSpacing.medium),
                  DropdownButtonFormField<String>(
                    initialValue:
                        controller.profile.languageMode == LanguageMode.device
                            ? 'device'
                            : controller.profile.selectedLocale ?? 'en',
                    decoration: InputDecoration(labelText: strings.language),
                    items: [
                      DropdownMenuItem(
                        value: 'device',
                        child: Text(strings.languageDevice),
                      ),
                      DropdownMenuItem(
                        value: 'en',
                        child: Text(strings.languageEnglish),
                      ),
                      DropdownMenuItem(
                        value: 'it',
                        child: Text(strings.languageItalian),
                      ),
                      DropdownMenuItem(
                        value: 'es',
                        child: Text(strings.languageSpanish),
                      ),
                      DropdownMenuItem(
                        value: 'fr',
                        child: Text(strings.languageFrench),
                      ),
                      DropdownMenuItem(
                        value: 'de',
                        child: Text(strings.languageGerman),
                      ),
                      DropdownMenuItem(
                        value: 'pt',
                        child: Text(strings.languagePortuguese),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      if (value == 'device') {
                        controller.useDeviceLanguage();
                      } else {
                        controller.setLanguage(value);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: WonderlogSpacing.medium),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(WonderlogSpacing.medium),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.ecosystemTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: WonderlogSpacing.xSmall),
                  Text(strings.ecosystemFoundationDescription),
                  const SizedBox(height: WonderlogSpacing.small),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      child: Icon(Icons.hub_outlined),
                    ),
                    title: const Text("Anna's Diary"),
                    subtitle: Text(strings.ecosystemConfiguredApp),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => const EcosystemAppDetailPage(
                          appId: EcosystemAppId.annasDiary,
                        ),
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    enabled: false,
                    leading: const Icon(Icons.notes_outlined),
                    title: const Text('Notes'),
                    subtitle: Text(strings.ecosystemAppsPlanned),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    enabled: false,
                    leading: const Icon(Icons.route_outlined),
                    title: const Text('TrailPath'),
                    subtitle: Text(strings.ecosystemAppsPlanned),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final session = controller.identity;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(WonderlogSpacing.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.account,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: WonderlogSpacing.xSmall),
            switch (session.status) {
              IdentityStatus.localOnly => Text(strings.localOnlyDescription),
              IdentityStatus.signedOut => Text(strings.cloudOptional),
              IdentityStatus.signedIn => Text(
                  session.user?.email ??
                      session.user?.displayName ??
                      strings.accountConnected,
                ),
              IdentityStatus.error => Text(strings.accountError),
            },
            const SizedBox(height: WonderlogSpacing.medium),
            if (session.status == IdentityStatus.localOnly)
              Text(
                AppConfig.current.cloudConfigured
                    ? strings.accountInitializing
                    : strings.cloudNotConfigured,
              )
            else if (session.status == IdentityStatus.signedOut)
              Wrap(
                spacing: WonderlogSpacing.small,
                runSpacing: WonderlogSpacing.small,
                children: [
                  FilledButton.icon(
                    onPressed: () => _runAuth(
                      context,
                      controller.identityService.signInWithGoogle,
                    ),
                    icon: const Icon(Icons.login),
                    label: Text(strings.continueWithGoogle),
                  ),
                  OutlinedButton(
                    onPressed: () => _showEmailAuthDialog(
                      context,
                      controller,
                    ),
                    child: Text(strings.emailLogin),
                  ),
                ],
              )
            else if (session.status == IdentityStatus.signedIn)
              OutlinedButton.icon(
                onPressed: () => _runAuth(
                  context,
                  controller.identityService.signOut,
                ),
                icon: const Icon(Icons.logout),
                label: Text(strings.signOut),
              ),
          ],
        ),
      ),
    );
  }
}

Future<void> _runAuth(
  BuildContext context,
  Future<void> Function() operation,
) async {
  final strings = AppLocalizations.of(context);
  try {
    await operation();
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(strings.accountError)),
    );
  }
}

Future<void> _showEmailAuthDialog(
  BuildContext context,
  AppController controller,
) async {
  final strings = AppLocalizations.of(context);
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  try {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.emailLogin),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(labelText: strings.email),
            ),
            const SizedBox(height: WonderlogSpacing.small),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(labelText: strings.password),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(strings.cancel),
          ),
          TextButton(
            onPressed: () async {
              try {
                await controller.identityService.signUpWithEmail(
                  email: emailController.text,
                  password: passwordController.text,
                );
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              } catch (_) {
                if (!dialogContext.mounted) return;
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(content: Text(strings.accountError)),
                );
              }
            },
            child: Text(strings.signUp),
          ),
          FilledButton(
            onPressed: () async {
              try {
                await controller.identityService.signInWithEmail(
                  email: emailController.text,
                  password: passwordController.text,
                );
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              } catch (_) {
                if (!dialogContext.mounted) return;
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(content: Text(strings.accountError)),
                );
              }
            },
            child: Text(strings.signIn),
          ),
        ],
      ),
    );
  } finally {
    emailController.dispose();
    passwordController.dispose();
  }
}
