import 'dart:collection';

class LruCache<K, V> {
  LruCache({required this.maxEntries}) : assert(maxEntries > 0);

  final int maxEntries;
  final LinkedHashMap<K, V> _store = LinkedHashMap<K, V>();

  V? get(K key) {
    final value = _store.remove(key);
    if (value == null) return null;
    _store[key] = value;
    return value;
  }

  V? peek(K key) => _store[key];

  void set(K key, V value) {
    if (_store.containsKey(key)) {
      _store.remove(key);
    }
    _store[key] = value;
    _trim();
  }

  bool containsKey(K key) => _store.containsKey(key);

  void clear() => _store.clear();

  void _trim() {
    while (_store.length > maxEntries) {
      _store.remove(_store.keys.first);
    }
  }
}
