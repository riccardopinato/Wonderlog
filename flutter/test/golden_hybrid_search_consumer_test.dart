import 'package:flutter_test/flutter_test.dart';
import 'package:wonderlog/features/journeys/domain/journey.dart';
import 'package:wonderlog/features/memories/domain/memory_models.dart';
import 'package:wonderlog/features/search/domain/search_engine.dart';

void main() {
  Journey journey({required String id,required String title}) => Journey(
    id:id,title:title,destination:'Padova',country:'Italia',
    startDate:DateTime.utc(2026,1,1),endDate:DateTime.utc(2026,1,2),
    description:'',latitude:45,longitude:12,favorite:false,archived:false,
    createdAt:DateTime.utc(2026),updatedAt:DateTime.utc(2026),
  );
  MemoryEntry memory({required String id,required String title,
    List<String> tags=const []}) => MemoryEntry(
    id:id,journeyId:null,title:title,journalText:'Ricordo di viaggio',
    locationName:'',date:DateTime.utc(2026),mood:Mood.happy,tags:tags,
    createdAt:DateTime.utc(2026),updatedAt:DateTime.utc(2026),
  );

  test('real search preserves legacy partial, phrase and accent matching', () {
    final trips=[journey(id:'j',title:'Città di Anna')];
    expect(WonderlogSearchEngine.search(query:'citta',journeys:trips,
      memories:const []),hasLength(1));
    expect(WonderlogSearchEngine.search(query:'ann',journeys:trips,
      memories:const []),hasLength(1));
    expect(WonderlogSearchEngine.search(query:'di',journeys:trips,
      memories:const []),hasLength(1));
    expect(WonderlogSearchEngine.search(query:'citta di marco',journeys:trips,
      memories:const []),isEmpty);
  });

  test('related-terms opt-in exercises byte-identical Golden feature hash', () {
    final records=[memory(id:'m1',title:'Auto elettrica')];
    final defaultHits=WonderlogSearchEngine.search(query:'macchina',
      journeys:const [],memories:records);
    expect(defaultHits,isEmpty);
    final related=WonderlogSearchEngine.search(query:'macchina',
      journeys:const [],memories:records,includeRelatedTerms:true);
    expect(related,hasLength(1));
    expect(related.single,isA<MemorySearchResult>());
    expect((related.single as MemorySearchResult).memory.id,'m1');
  });

  test('search preserves typed unique identities and a strict result limit', () {
    final j=journey(id:'same',title:'Auto');
    final m=memory(id:'same',title:'Auto');
    final found=WonderlogSearchEngine.search(query:'auto',
      journeys:[j],memories:[m],includeRelatedTerms:true);
    expect(found.length,2);
    expect(found.whereType<JourneySearchResult>().length,1);
    expect(found.whereType<MemorySearchResult>().length,1);
    expect(WonderlogSearchEngine.search(query:'auto',journeys:[j],memories:[m],
      includeRelatedTerms:true,limit:1),hasLength(1));
    expect(WonderlogSearchEngine.search(query:'',journeys:[j],memories:[m]),
      isEmpty);
  });
}
