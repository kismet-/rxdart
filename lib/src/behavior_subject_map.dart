import 'package:rxdart/rxdart.dart';

typedef V InitialValueProvider<K, V>(K key);

/// Maintains a map of behavior [Subject]s of type [V], with keys of type [K].
class BehaviorSubjectMap<K, V> {
  final _subjects = <K, Subject<V>>{};
  final InitialValueProvider<K, V> _initialValueProvider;

  BehaviorSubjectMap({V? initial})
      : this.withInitialValueProvider((_) => initial!);

  BehaviorSubjectMap.withInitialValueProvider(this._initialValueProvider);

  /// For each key in [newValues], adds the corresponding value to the key's
  /// stream.
  void publishUpdates(Map<K, V> newValues) {
    for (var id in newValues.keys) {
      update(id, newValues[id]!);
    }
  }

  /// Adds [value] to the [Subject] for [key].
  void update(K key, V value) {
    _data(key).sendNext(value);
  }

  /// Replaces the contents of the map with these values. Removes values from
  /// the map that are not present in newValues.
  void reset(Map<K, V> newValues) {
    List<MapEntry<K, Subject<V>>> entriesToBeRemoved = _subjects.entries
        .where((mapEntry) => !newValues.containsKey(mapEntry.key))
        .toList();
    entriesToBeRemoved.forEach((mapEntry) {
      mapEntry.value.sendCompleted();
      _subjects.remove(mapEntry.key);
    });

    publishUpdates(newValues);
  }

  /// 'Clears' the map by updating each key to its initial value.
  ///
  /// If the initial value is null, be careful about calling this and make sure
  /// you know the consequences.
  void clearAll() {
    for (var key in _subjects.keys) {
      update(key, _initialValueProvider(key));
    }
  }

  bool containsKey(K key) => _subjects.containsKey(key);

  /// Returns an [Observable] that publishes updates to the data for [key].
  Observable<V> data(K key) => _data(key);

  Subject<V> _data(K key) => _subjects.putIfAbsent(
        key,
        () => createBehaviorSubject(initial: _initialValueProvider(key)),
      );
}
