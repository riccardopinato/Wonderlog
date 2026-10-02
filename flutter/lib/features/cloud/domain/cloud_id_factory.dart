import 'dart:convert';

import '../../map_memories/domain/map_cluster_engine.dart';

abstract final class CloudIdFactory {
  static String journey(String ownerId, String localId) =>
      _stable(ownerId + '|journey|' + localId);

  static String memory(String ownerId, String localId) =>
      _stable(ownerId + '|memory|' + localId);

  static String photo(String ownerId, String localId) =>
      _stable(ownerId + '|photo|' + localId);

  static String _stable(String value) =>
      javaNameUuidFromBytes(utf8.encode(value));
}
