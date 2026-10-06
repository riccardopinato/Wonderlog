import 'package:flutter/material.dart';

import '../../../app/theme/wonderlog_tokens.dart';
import '../../../core/app_controller.dart';
import '../../../core/identity/identity_models.dart';
import '../../../l10n/app_localizations.dart';
import '../../premium/presentation/premium_page.dart';
import '../application/cloud_runtime_controller.dart';

final class CloudBackupPage extends StatelessWidget {
  const CloudBackupPage({
    super.key,
    required this.runtime,
    required this.controller,
  });

  final CloudRuntimeController runtime;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(strings.cloudBackupTitle)),
      body: AnimatedBuilder(
        animation: runtime,
        builder: (context, _) {
          final signedIn =
              controller.identity.status == IdentityStatus.signedIn;
          final premium = controller.isPremium;
          final lastBackup = runtime.lastSuccessfulBackupAt;

          return ListView(
            padding: const EdgeInsets.all(WonderlogSpacing.medium),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(WonderlogSpacing.medium),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.cloudBackupStatus,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: WonderlogSpacing.small),
                      _StatusLine(
                        icon: signedIn
                            ? Icons.cloud_done_outlined
                            : Icons.cloud_off_outlined,
                        text: signedIn
                            ? strings.cloudAccountReady
                            : strings.cloudSignInRequired,
                      ),
                      _StatusLine(
                        icon: premium
                            ? Icons.workspace_premium_outlined
                            : Icons.lock_outline,
                        text: premium
                            ? strings.cloudPremiumReady
                            : strings.cloudPremiumRequired,
                      ),
                      _StatusLine(
                        icon: Icons.pending_actions_outlined,
                        text: strings.cloudPendingOperations(
                          runtime.pendingCount,
                        ),
                      ),
                      _StatusLine(
                        icon: Icons.schedule_outlined,
                        text: lastBackup == null
                            ? strings.cloudNeverBackedUp
                            : strings.cloudLastBackup(
                                lastBackup.toLocal().toString(),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: WonderlogSpacing.medium),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Icons.photo_library_outlined),
                      title: Text(strings.cloudIncludePhotos),
                      subtitle: Text(strings.cloudIncludePhotosDescription),
                      value: runtime.settings.includePhotos,
                      onChanged: runtime.busy
                          ? null
                          : runtime.setIncludePhotos,
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      secondary: const Icon(Icons.autorenew_outlined),
                      title: Text(strings.cloudAutomaticBackup),
                      subtitle: Text(strings.cloudAutomaticBackupDeferred),
                      value: false,
                      onChanged: null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: WonderlogSpacing.medium),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(WonderlogSpacing.medium),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton.icon(
                        onPressed: runtime.busy
                            ? null
                            : () => _syncNow(context),
                        icon: runtime.syncing
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.cloud_upload_outlined),
                        label: Text(strings.cloudSyncNow),
                      ),
                      const SizedBox(height: WonderlogSpacing.small),
                      OutlinedButton.icon(
                        onPressed: runtime.busy
                            ? null
                            : () => _confirmRestore(context),
                        icon: runtime.restoring
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.restore_outlined),
                        label: Text(strings.cloudRestoreNow),
                      ),
                      if (runtime.restoring &&
                          runtime.restoreProgress != null) ...[
                        const SizedBox(height: WonderlogSpacing.small),
                        LinearProgressIndicator(
                          value: runtime.restoreProgress!.total > 0
                              ? runtime.restoreProgress!.fraction
                              : null,
                        ),
                      ],
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
                        strings.cloudBackupScopeTitle,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: WonderlogSpacing.xSmall),
                      Text(strings.cloudBackupScopeDescription),
                    ],
                  ),
                ),
              ),
              if (runtime.lastSyncSummary != null) ...[
                const SizedBox(height: WonderlogSpacing.medium),
                _SummaryCard(
                  title: strings.cloudLastSyncSummary,
                  body: strings.cloudSyncSummary(
                    runtime.lastSyncSummary!.uploaded,
                    runtime.lastSyncSummary!.deleted,
                    runtime.lastSyncSummary!.failures,
                  ),
                ),
              ],
              if (runtime.lastRestoreSummary != null) ...[
                const SizedBox(height: WonderlogSpacing.medium),
                _SummaryCard(
                  title: strings.cloudLastRestoreSummary,
                  body: strings.cloudRestoreSummary(
                    runtime.lastRestoreSummary!.journeysInserted +
                        runtime.lastRestoreSummary!.journeysUpdated,
                    runtime.lastRestoreSummary!.memoriesInserted +
                        runtime.lastRestoreSummary!.memoriesUpdated,
                    runtime.lastRestoreSummary!.photosInserted +
                        runtime.lastRestoreSummary!.photosUpdated,
                    runtime.lastRestoreSummary!.conflicts,
                    runtime.lastRestoreSummary!.failures,
                  ),
                ),
              ],
              if (runtime.lastError != null) ...[
                const SizedBox(height: WonderlogSpacing.medium),
                Card(
                  child: Padding(
                    padding:
                        const EdgeInsets.all(WonderlogSpacing.medium),
                    child: Text(
                      runtime.lastError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _syncNow(BuildContext context) async {
    try {
      final summary = await runtime.syncNow();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context).cloudSyncSummary(
              summary.uploaded,
              summary.deleted,
              summary.failures,
            ),
          ),
        ),
      );
    } on CloudRuntimeException catch (error) {
      if (!context.mounted) return;
      await _handleBlocked(context, error);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).cloudOperationFailed)),
      );
    }
  }

  Future<void> _confirmRestore(BuildContext context) async {
    final strings = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(strings.cloudRestoreConfirmTitle),
            content: Text(strings.cloudRestoreConfirmDescription),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(strings.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(strings.cloudRestoreNow),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !context.mounted) return;

    try {
      final summary = await runtime.restoreNow();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            strings.cloudRestoreSummary(
              summary.journeysInserted + summary.journeysUpdated,
              summary.memoriesInserted + summary.memoriesUpdated,
              summary.photosInserted + summary.photosUpdated,
              summary.conflicts,
              summary.failures,
            ),
          ),
        ),
      );
    } on CloudRuntimeException catch (error) {
      if (!context.mounted) return;
      await _handleBlocked(context, error);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.cloudOperationFailed)),
      );
    }
  }

  Future<void> _handleBlocked(
    BuildContext context,
    CloudRuntimeException error,
  ) async {
    final strings = AppLocalizations.of(context);
    if (error.reason == CloudRuntimeBlockReason.premiumRequired) {
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => PremiumPage(service: controller.premiumService),
        ),
      );
      return;
    }

    final message = switch (error.reason) {
      CloudRuntimeBlockReason.signedOut => strings.cloudSignInRequired,
      CloudRuntimeBlockReason.premiumRequired =>
        strings.cloudPremiumRequired,
      CloudRuntimeBlockReason.busy => strings.cloudOperationBusy,
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

final class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(
          vertical: WonderlogSpacing.xSmall,
        ),
        child: Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: WonderlogSpacing.small),
            Expanded(child: Text(text)),
          ],
        ),
      );
}

final class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(WonderlogSpacing.medium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: WonderlogSpacing.xSmall),
              Text(body),
            ],
          ),
        ),
      );
}
