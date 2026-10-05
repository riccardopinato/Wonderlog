import 'package:flutter_test/flutter_test.dart';
import 'package:wonderlog/features/memories/domain/memory_models.dart';

void main() {
  test('memory coordinate exists only when both values are present', () {
    final memory = MemoryEntry(
      id: 'm1',
      journeyId: 'j1',
      title: 'Stop',
      journalText: '',
      locationName: '',
      date: DateTime(2026, 8, 10),
      mood: Mood.calm,
      tags: const [],
      latitude: 46.9,
      longitude: 11.9,
      createdAt: DateTime.utc(2026, 8, 10),
      updatedAt: DateTime.utc(2026, 8, 10),
    );
    expect(memory.coordinate?.latitude, 46.9);
  });

  test('memory can remain unassigned to a Journey', () {
    final memory = MemoryEntry(
      id: 'free-memory',
      journeyId: null,
      title: 'Ricordo libero',
      journalText: 'Ricevuto da Anna',
      locationName: '',
      date: DateTime(2026, 10, 5),
      mood: Mood.calm,
      tags: const ['ecosystem'],
      createdAt: DateTime.utc(2026, 10, 5),
      updatedAt: DateTime.utc(2026, 10, 5),
    );

    expect(memory.journeyId, isNull);
  });

}
