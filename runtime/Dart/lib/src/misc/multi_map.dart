import 'dart:collection';

import 'package:collection/collection.dart';

import 'pair.dart';

class MultiMap<K, V> extends DelegatingMap<K, List<V>> {
  MultiMap() : super(LinkedHashMap());

  void put(K key, V value) {
    List<V> elementsForKey = this[key];
    if (elementsForKey == null) {
      elementsForKey = [];
      this[key] = elementsForKey;
    }
    elementsForKey.add(value);
  }

  List<Pair<K, V>> getPairs() {
    List<Pair<K, V>> pairs = [];
    for (K key in keys) {
      for (V value in this[key]) {
        pairs.add(new Pair<K, V>(key, value));
      }
    }
    return pairs;
  }
}
