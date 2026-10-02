import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../app/theme/wonderlog_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../application/capture_controller.dart';
import '../domain/capture_models.dart';
import '../domain/capture_validator.dart';

final class CapturePage extends StatefulWidget {
  const CapturePage({
    super.key,
    required this.controller,
    this.initialText,
  });

  final CaptureController controller;
  final String? initialText;

  @override
  State<CapturePage> createState() => _CapturePageState();
}

final class _CapturePageState extends State<CapturePage> {
  @override
  void initState() {
    super.initState();
    final text = widget.initialText?.trim();
    widget.controller.setIncomingItems([
      if (text != null && text.isNotEmpty)
        CaptureIncomingItem(
          id: const Uuid().v4(),
          type: CaptureContentType.text,
          text: text,
        )
      else
        CaptureIncomingItem(
          id: const Uuid().v4(),
          type: CaptureContentType.text,
          text: '',
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final state = widget.controller.state;
        if (state is CaptureIdle) {
          return Scaffold(
            appBar: AppBar(title: Text(strings.captureTitle)),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (state is CaptureSuccess) {
          return Scaffold(
            appBar: AppBar(title: Text(strings.captureTitle)),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(WonderlogSpacing.large),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_outline, size: 56),
                    const SizedBox(height: WonderlogSpacing.medium),
                    Text(strings.captureSaved),
                    const SizedBox(height: WonderlogSpacing.medium),
                    FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(strings.done),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        if (state is CaptureError) {
          return Scaffold(
            appBar: AppBar(title: Text(strings.captureTitle)),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(WonderlogSpacing.large),
                child: Text(strings.captureError),
              ),
            ),
          );
        }

        final draft = switch (state) {
          CaptureReady(:final draft) => draft,
          CaptureSaving(:final draft) => draft,
          _ => throw StateError('Unexpected capture state'),
        };
        final saving = state is CaptureSaving;
        final validation = CaptureValidator.validate(draft);

        return Scaffold(
          appBar: AppBar(title: Text(strings.captureTitle)),
          body: ListView(
            padding: const EdgeInsets.all(WonderlogSpacing.medium),
            children: [
              DropdownButtonFormField<String>(
                initialValue: draft.journeyId,
                decoration:
                    InputDecoration(labelText: strings.captureJourney),
                items: widget.controller.journeys
                    .map(
                      (journey) => DropdownMenuItem(
                        value: journey.id,
                        child: Text(journey.title),
                      ),
                    )
                    .toList(growable: false),
                onChanged: saving
                    ? null
                    : (value) => widget.controller.selectJourney(value),
              ),
              const SizedBox(height: WonderlogSpacing.medium),
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment<bool>(
                    value: false,
                    icon: const Icon(Icons.auto_stories_outlined),
                    label: Text(strings.captureExistingMemory),
                  ),
                  ButtonSegment<bool>(
                    value: true,
                    icon: const Icon(Icons.note_add_outlined),
                    label: Text(strings.captureCreateMemory),
                  ),
                ],
                selected: {draft.createNewMemory},
                onSelectionChanged: saving
                    ? null
                    : (values) => widget.controller
                        .setCreateNewMemory(values.single),
              ),
              const SizedBox(height: WonderlogSpacing.small),
              if (!draft.createNewMemory)
                DropdownButtonFormField<String>(
                  initialValue: draft.memoryId,
                  decoration:
                      InputDecoration(labelText: strings.captureMemory),
                  items: widget.controller.memories
                      .map(
                        (memory) => DropdownMenuItem(
                          value: memory.id,
                          child: Text(memory.title),
                        ),
                      )
                      .toList(growable: false),
                  onChanged:
                      saving ? null : widget.controller.selectMemory,
                ),
              if (draft.createNewMemory) ...[
                TextFormField(
                  initialValue: draft.memoryTitle,
                  decoration:
                      InputDecoration(labelText: strings.memoryTitle),
                  onChanged: widget.controller.setMemoryTitle,
                ),
                const SizedBox(height: WonderlogSpacing.small),
              ],
              TextFormField(
                initialValue: draft.memoryText,
                minLines: 5,
                maxLines: 12,
                decoration:
                    InputDecoration(labelText: strings.captureText),
                onChanged: widget.controller.setMemoryText,
              ),
              const SizedBox(height: WonderlogSpacing.medium),
              if (!validation.valid && validation.message != null)
                Text(
                  validation.message!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              const SizedBox(height: WonderlogSpacing.small),
              FilledButton.icon(
                onPressed:
                    validation.valid && !saving ? widget.controller.save : null,
                icon: saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(strings.save),
              ),
            ],
          ),
        );
      },
    );
  }
}
