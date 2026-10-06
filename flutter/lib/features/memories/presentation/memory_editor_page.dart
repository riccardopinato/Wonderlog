import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../app/theme/wonderlog_tokens.dart';
import '../../../l10n/app_localizations.dart';
import '../../premium/domain/premium_creation_guard.dart';
import '../domain/memory_models.dart';
import '../domain/wonderlog_repository.dart';

final class MemoryEditorPage extends StatefulWidget {
  const MemoryEditorPage({
    super.key,
    required this.repository,
    required this.journeyId,
    required this.isPremium,
    this.existing,
  });

  final WonderlogRepository repository;
  final String? journeyId;
  final bool Function() isPremium;
  final MemoryEntry? existing;

  @override
  State<MemoryEditorPage> createState() => _MemoryEditorPageState();
}

final class _MemoryEditorPageState extends State<MemoryEditorPage> {
  late final TextEditingController _title;
  late final TextEditingController _journal;
  late final TextEditingController _location;
  late final TextEditingController _tags;
  late DateTime _date;
  late Mood _mood;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final memory = widget.existing;
    _title = TextEditingController(text: memory?.title ?? '');
    _journal = TextEditingController(text: memory?.journalText ?? '');
    _location = TextEditingController(text: memory?.locationName ?? '');
    _tags = TextEditingController(text: memory?.tags.join(', ') ?? '');
    _date = memory?.date ?? DateTime.now();
    _mood = memory?.mood ?? Mood.happy;
  }

  @override
  void dispose() {
    _title.dispose();
    _journal.dispose();
    _location.dispose();
    _tags.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing == null ? strings.memoryNew : strings.memoryEdit,
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(strings.save),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(WonderlogSpacing.medium),
        children: [
          TextField(
            controller: _title,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(labelText: strings.memoryTitle),
          ),
          const SizedBox(height: WonderlogSpacing.small),
          TextField(
            controller: _journal,
            minLines: 5,
            maxLines: 12,
            decoration: InputDecoration(labelText: strings.memoryJournal),
          ),
          const SizedBox(height: WonderlogSpacing.small),
          TextField(
            controller: _location,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(labelText: strings.memoryLocation),
          ),
          const SizedBox(height: WonderlogSpacing.small),
          TextField(
            controller: _tags,
            decoration: InputDecoration(labelText: strings.memoryTags),
          ),
          const SizedBox(height: WonderlogSpacing.medium),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today_outlined),
            title: Text(strings.memoryDate),
            subtitle: Text(DateFormat.yMMMd(locale).format(_date)),
            onTap: _pickDate,
          ),
          const SizedBox(height: WonderlogSpacing.small),
          DropdownButtonFormField<Mood>(
            initialValue: _mood,
            decoration: InputDecoration(labelText: strings.memoryMood),
            items: Mood.values
                .map(
                  (mood) => DropdownMenuItem(
                    value: mood,
                    child: Text(mood.emoji + ' ' + mood.label),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) {
              if (value != null) setState(() => _mood = value);
            },
          ),
          const SizedBox(height: WonderlogSpacing.large),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
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
  }

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1900),
      lastDate: DateTime(2200),
    );
    if (value != null) setState(() => _date = value);
  }

  Future<void> _save() async {
    final strings = AppLocalizations.of(context);
    final title = _title.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.memoryTitleRequired)),
      );
      return;
    }

    final existing = widget.existing;
    if (existing == null) {
      try {
        await PremiumCreationGuard(
          repository: widget.repository,
          isPremium: widget.isPremium,
        ).ensureMemoryAllowed(journeyId: widget.journeyId);
      } on PremiumCreationLimitException {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.premiumMemoryLimitReached)),
        );
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final now = DateTime.now().toUtc();
      final tags = _tags.text
          .split(',')
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList(growable: false);

      await widget.repository.saveMemory(
        MemoryEntry(
          id: existing?.id ?? const Uuid().v4(),
          journeyId: widget.journeyId,
          title: title,
          journalText: _journal.text.trim(),
          locationName: _location.text.trim(),
          date: _date,
          mood: _mood,
          tags: tags,
          latitude: existing?.latitude,
          longitude: existing?.longitude,
          favorite: existing?.favorite ?? false,
          createdAt: existing?.createdAt ?? now,
          updatedAt: now,
          displayOrder: existing?.displayOrder ?? 0,
          syncStatus: existing?.syncStatus ?? 'LOCAL_ONLY',
          futureCloudId: existing?.futureCloudId,
        ),
      );

      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
