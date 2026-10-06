import 'package:flutter/material.dart';

import '../../../app/theme/wonderlog_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../application/premium_entitlement_service.dart';

final class PremiumPage extends StatelessWidget {
  const PremiumPage({
    super.key,
    required this.service,
  });

  final PremiumEntitlementService service;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);

    return AnimatedBuilder(
      animation: service,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: Text(strings.premiumTitle)),
          body: ListView(
            padding: const EdgeInsets.all(WonderlogSpacing.medium),
            children: [
              Container(
                padding: const EdgeInsets.all(WonderlogSpacing.large),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primaryContainer,
                      Theme.of(context).colorScheme.tertiaryContainer,
                    ],
                  ),
                  borderRadius:
                      BorderRadius.circular(WonderlogRadii.container),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.star_rounded, size: 64),
                    const SizedBox(height: WonderlogSpacing.small),
                    Text(
                      strings.premiumHeadline,
                      textAlign: TextAlign.center,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                    ),
                    const SizedBox(height: WonderlogSpacing.xSmall),
                    Text(
                      strings.premiumDescription,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: WonderlogSpacing.medium),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(WonderlogSpacing.medium),
                  child: Column(
                    children: [
                      _Benefit(
                        icon: Icons.all_inclusive,
                        title: strings.premiumUnlimited,
                      ),
                      _Benefit(
                        icon: Icons.photo_library_outlined,
                        title: strings.albumPhotoCount(100),
                      ),
                      _Benefit(
                        icon: Icons.cloud_done_outlined,
                        title: strings.premiumCloud,
                      ),
                      _Benefit(
                        icon: Icons.picture_as_pdf_outlined,
                        title: strings.premiumPdf,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: WonderlogSpacing.medium),
              if (service.hasPremiumAccess)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.check_circle_outline),
                    title: Text(strings.premiumActive),
                    subtitle: Text(strings.premiumActiveDescription),
                  ),
                )
              else if (!service.configured)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.storefront_outlined),
                    title: Text(strings.premiumStoreUnavailable),
                    subtitle: Text(strings.premiumStoreUnavailableDescription),
                  ),
                )
              else ...[
                for (final product in service.products)
                  Padding(
                    padding: const EdgeInsets.only(
                      bottom: WonderlogSpacing.small,
                    ),
                    child: Card(
                      child: ListTile(
                        title: Text(product.title),
                        subtitle: Text(product.description),
                        trailing: FilledButton(
                          onPressed: service.busy
                              ? null
                              : () => _purchase(
                                    context,
                                    product,
                                  ),
                          child: Text(product.price),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: WonderlogSpacing.small),
                OutlinedButton.icon(
                  onPressed: service.canRestorePurchases && !service.busy
                      ? () => _restore(context)
                      : null,
                  icon: const Icon(Icons.restore),
                  label: Text(strings.premiumRestore),
                ),
              ],
              if (service.busy) ...[
                const SizedBox(height: WonderlogSpacing.medium),
                const Center(child: CircularProgressIndicator()),
              ],
              if ((service.lastError ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: WonderlogSpacing.small),
                Text(
                  strings.premiumGenericError,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _purchase(
    BuildContext context,
    PremiumStoreProduct product,
  ) async {
    final result = await service.purchase(product);
    if (!context.mounted) return;
    final strings = AppLocalizations.of(context);
    final message = switch (result) {
      PremiumPurchaseOutcome.success => strings.premiumPurchaseSuccess,
      PremiumPurchaseOutcome.cancelled => strings.premiumPurchaseCancelled,
      PremiumPurchaseOutcome.unavailable => strings.premiumStoreUnavailable,
      PremiumPurchaseOutcome.unsupported => strings.premiumStoreUnavailable,
      PremiumPurchaseOutcome.failed => strings.premiumGenericError,
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _restore(BuildContext context) async {
    final result = await service.restorePurchases();
    if (!context.mounted) return;
    final strings = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result == PremiumPurchaseOutcome.success
              ? strings.premiumRestoreSuccess
              : strings.premiumGenericError,
        ),
      ),
    );
  }
}

final class _Benefit extends StatelessWidget {
  const _Benefit({
    required this.icon,
    required this.title,
  });

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon),
        title: Text(title),
      );
}
