import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wonderlog/core/database/wonderlog_database.dart';
import 'package:wonderlog/features/location/data/open_street_map_repository.dart';

void main() {
  test('blank place search remains local and returns empty', () async {
    final database = WonderlogDatabase(NativeDatabase.memory());
    final repository = OpenStreetMapRepository(database);
    expect(await repository.searchPlaces('   '), isEmpty);
    await database.close();
  });

  test('Nominatim search uses app locale in request and cache key', () async {
    final database = WonderlogDatabase(NativeDatabase.memory());
    var italianCalls = 0;
    final italianClient = MockClient((request) async {
      italianCalls++;
      expect(request.url.queryParameters['accept-language'], 'it-IT');
      expect(request.headers['Accept-Language'], 'it-IT');
      expect(
        request.headers['User-Agent'],
        contains('com.riccardopinato.wonderlog'),
      );
      return http.Response(
        jsonEncode([
          {
            'lat': '45.0703',
            'lon': '7.6869',
            'display_name': 'Torino, Piemonte, Italia',
            'address': {
              'city': 'Torino',
              'state': 'Piemonte',
              'country': 'Italia',
            },
          }
        ]),
        200,
      );
    });
    final italian = OpenStreetMapRepository(
      database,
      client: italianClient,
      localeTag: () => 'it-IT',
    );

    final first = await italian.searchPlaces('Torino');
    expect(first.single.country, 'Italia');
    expect(italianCalls, 1);

    final noNetworkClient = MockClient((_) async {
      fail('same-locale cache should avoid a second network request');
    });
    final cached = OpenStreetMapRepository(
      database,
      client: noNetworkClient,
      localeTag: () => 'it-IT',
    );
    final cachedResult = await cached.searchPlaces('Torino');
    expect(cachedResult.single.source, 'CACHED');

    var englishCalls = 0;
    final english = OpenStreetMapRepository(
      database,
      localeTag: () => 'en-US',
      client: MockClient((request) async {
        englishCalls++;
        expect(request.url.queryParameters['accept-language'], 'en-US');
        return http.Response(
          jsonEncode([
            {
              'lat': '45.0703',
              'lon': '7.6869',
              'display_name': 'Turin, Piedmont, Italy',
              'address': {
                'city': 'Turin',
                'state': 'Piedmont',
                'country': 'Italy',
              },
            }
          ]),
          200,
        );
      }),
    );
    final secondLocale = await english.searchPlaces('Torino');
    expect(secondLocale.single.country, 'Italy');
    expect(englishCalls, 1);

    await database.close();
  });

  test('reverse geocode cache is locale-scoped', () async {
    final database = WonderlogDatabase(NativeDatabase.memory());
    final it = OpenStreetMapRepository(
      database,
      localeTag: () => 'it',
      client: MockClient((request) async => http.Response(
            jsonEncode({
              'display_name': 'Roma, Lazio, Italia',
              'address': {
                'city': 'Roma',
                'state': 'Lazio',
                'country': 'Italia',
              },
            }),
            200,
          )),
    );
    final en = OpenStreetMapRepository(
      database,
      localeTag: () => 'en',
      client: MockClient((request) async => http.Response(
            jsonEncode({
              'display_name': 'Rome, Lazio, Italy',
              'address': {
                'city': 'Rome',
                'state': 'Lazio',
                'country': 'Italy',
              },
            }),
            200,
          )),
    );

    expect((await it.reverseGeocode(41.9028, 12.4964))?.country, 'Italia');
    expect((await en.reverseGeocode(41.9028, 12.4964))?.country, 'Italy');

    await database.close();
  });
}
