import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/theme/wonderlog_tokens.dart';
import '../../../l10n/app_localizations.dart';

final class OnboardingGate extends StatefulWidget {
  const OnboardingGate({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<OnboardingGate> createState() => _OnboardingGateState();
}

final class _OnboardingGateState extends State<OnboardingGate> {
  static const _key = 'onboarding.completed';
  bool? _completed;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _completed = prefs.getBool(_key) ?? false);
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
    if (!mounted) return;
    setState(() => _completed = true);
  }

  @override
  Widget build(BuildContext context) {
    final completed = _completed;
    if (completed == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (completed) return widget.child;
    return _OnboardingPage(onStart: _finish);
  }
}

final class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.onStart});

  final Future<void> Function() onStart;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(WonderlogSpacing.large),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colors.primaryContainer,
              colors.tertiaryContainer,
              colors.secondaryContainer,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(),
              Icon(
                Icons.travel_explore,
                size: 76,
                color: colors.onPrimaryContainer,
              ),
              const SizedBox(height: WonderlogSpacing.large),
              Text(
                strings.appTitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: WonderlogSpacing.small),
              Text(
                strings.onboardingHeadline,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: WonderlogSpacing.medium),
              Text(
                strings.onboardingDescription,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onStart,
                  icon: const Icon(Icons.arrow_forward),
                  label: Text(strings.onboardingStart),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
