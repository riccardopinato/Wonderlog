import 'package:flutter/foundation.dart';

import '../domain/capture_models.dart';
import '../domain/capture_repository.dart';

sealed class CaptureUiState {
  const CaptureUiState();
}

final class CaptureIdle extends CaptureUiState {
  const CaptureIdle();
}

final class CaptureReady extends CaptureUiState {
  const CaptureReady(this.draft);
  final CaptureDraft draft;
}

final class CaptureSaving extends CaptureUiState {
  const CaptureSaving(this.draft);
  final CaptureDraft draft;
}

final class CaptureSuccess extends CaptureUiState {
  const CaptureSuccess(this.result);
  final CaptureSaveResult result;
}

final class CaptureError extends CaptureUiState {
  const CaptureError(this.message);
  final String message;
}

final class CaptureController extends ChangeNotifier {
  CaptureController(this.repository);

  final CaptureRepository repository;

  CaptureUiState _state = const CaptureIdle();
  List<CaptureJourneyOption> _journeys = const [];
  List<CaptureMemoryOption> _memories = const [];

  CaptureUiState get state => _state;
  List<CaptureJourneyOption> get journeys => _journeys;
  List<CaptureMemoryOption> get memories => _memories;

  Future<void> setIncomingItems(List<CaptureIncomingItem> items) async {
    if (items.isEmpty) return;
    _state = CaptureReady(CaptureDraft(items: items));
    notifyListeners();
    _journeys = await repository.getJourneys();
    notifyListeners();
  }

  void appendIncomingItems(List<CaptureIncomingItem> items) {
    if (items.isEmpty) return;
    final current = _state;
    if (current is! CaptureReady) return;
    final merged = <CaptureIncomingItem>[...current.draft.items, ...items]
        .take(100)
        .toList(growable: false);
    _state = CaptureReady(
      CaptureDraft(
        items: merged,
        journeyId: current.draft.journeyId,
        memoryId: current.draft.memoryId,
        createNewMemory: current.draft.createNewMemory,
        memoryTitle: current.draft.memoryTitle,
        memoryText: current.draft.memoryText,
        location: current.draft.location,
      ),
    );
    notifyListeners();
  }

  void removeIncomingItem(String id) {
    final current = _state;
    if (current is! CaptureReady) return;
    _state = CaptureReady(
      CaptureDraft(
        items: current.draft.items
            .where((item) => item.id != id)
            .toList(growable: false),
        journeyId: current.draft.journeyId,
        memoryId: current.draft.memoryId,
        createNewMemory: current.draft.createNewMemory,
        memoryTitle: current.draft.memoryTitle,
        memoryText: current.draft.memoryText,
        location: current.draft.location,
      ),
    );
    notifyListeners();
  }

  Future<void> selectJourney(String? journeyId) async {
    _updateDraft(
      (draft) => CaptureDraft(
        items: draft.items,
        journeyId: journeyId,
        memoryId: null,
        createNewMemory: draft.createNewMemory,
        memoryTitle: draft.memoryTitle,
        memoryText: draft.memoryText,
        location: draft.location,
      ),
    );
    _memories =
        journeyId == null ? const [] : await repository.getMemories(journeyId);
    notifyListeners();
  }

  void selectMemory(String? memoryId) => _updateDraft(
        (draft) => CaptureDraft(
          items: draft.items,
          journeyId: draft.journeyId,
          memoryId: memoryId,
          createNewMemory: false,
          memoryTitle: draft.memoryTitle,
          memoryText: draft.memoryText,
          location: draft.location,
        ),
      );

  void setCreateNewMemory(bool enabled) => _updateDraft(
        (draft) => CaptureDraft(
          items: draft.items,
          journeyId: draft.journeyId,
          memoryId: enabled ? null : draft.memoryId,
          createNewMemory: enabled,
          memoryTitle: draft.memoryTitle,
          memoryText: draft.memoryText,
          location: draft.location,
        ),
      );

  void setMemoryTitle(String value) => _updateDraft(
        (draft) => CaptureDraft(
          items: draft.items,
          journeyId: draft.journeyId,
          memoryId: draft.memoryId,
          createNewMemory: draft.createNewMemory,
          memoryTitle: _take(value, 120),
          memoryText: draft.memoryText,
          location: draft.location,
        ),
      );

  void setMemoryText(String value) => _updateDraft(
        (draft) => CaptureDraft(
          items: draft.items,
          journeyId: draft.journeyId,
          memoryId: draft.memoryId,
          createNewMemory: draft.createNewMemory,
          memoryTitle: draft.memoryTitle,
          memoryText: _take(value, 50000),
          location: draft.location,
        ),
      );

  Future<void> save() async {
    final current = _state;
    if (current is! CaptureReady) return;
    _state = CaptureSaving(current.draft);
    notifyListeners();

    try {
      final result = await repository.save(current.draft);
      _state = CaptureSuccess(result);
    } catch (error) {
      _state = CaptureError(error.toString());
    }
    notifyListeners();
  }

  void reset() {
    _state = const CaptureIdle();
    _journeys = const [];
    _memories = const [];
    notifyListeners();
  }

  void _updateDraft(CaptureDraft Function(CaptureDraft) transform) {
    final current = _state;
    if (current is! CaptureReady) return;
    _state = CaptureReady(transform(current.draft));
    notifyListeners();
  }

  String _take(String value, int max) =>
      value.length <= max ? value : value.substring(0, max);
}
