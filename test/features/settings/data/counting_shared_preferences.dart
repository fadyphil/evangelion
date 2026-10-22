import 'package:shared_preferences/shared_preferences.dart';

/// A [SharedPreferences] that **counts the writes** it is asked to make.
///
/// ## WHY IT **IMPLEMENTS** RATHER THAN **EXTENDS**
///
/// `SharedPreferences`'s constructor is **private** — `SharedPreferences._` — so a
/// subclass in this package cannot call it, and `extends` is impossible. `implements`
/// needs no constructor, and the interface is small: seventeen members, all of them
/// public.
///
/// ## AND WHY IT IS NOT A **SECOND** FAKE
///
/// Because it is a **view** over a real store, not a store of its own. Every read
/// and every write goes through to the real `shared_preferences`, so the thing
/// under test is the real package's behaviour and this class only *observes* it.
/// A fake that kept its own map would be a second implementation of the store, and
/// the round-trip claims would then be about the fake.
///
/// ## THE SEAM IS **ALREADY THERE**
///
/// `SettingsLocalDataSource.over(Future<SharedPreferences>)` is the production
/// seam — a named constructor, four lines wide, in the one class that owns the
/// platform channel (see that file's own doc for why it exists). This class is
/// what it was built for: the store it is given can be a real one, a failing one,
/// or a counting one, and the data source cannot tell them apart.
final class CountingPreferences implements SharedPreferences {
  /// Counts the writes of the store [inner].
  CountingPreferences(this._inner);

  /// The real store every read and write goes through.
  final SharedPreferences _inner;

  /// The write calls, in order, as `setInt:eva.shader.hue`.
  ///
  /// **The key is in the string** and not in a separate list, so a test can assert
  /// *which* key was written without a second structure to keep in step with this
  /// one.
  final List<String> writes = <String>[];

  /// How many write calls have been made.
  int get writeCount => writes.length;

  /// The keys written so far, in order, without the method name.
  List<String> get writtenKeys => <String>[
    for (final String write in writes) write.substring(write.indexOf(':') + 1),
  ];

  /// Forgets the recorded writes, so one test can measure several phases.
  void reset() => writes.clear();

  @override
  Set<String> getKeys() => _inner.getKeys();

  @override
  Object? get(String key) => _inner.get(key);

  @override
  bool? getBool(String key) => _inner.getBool(key);

  @override
  int? getInt(String key) => _inner.getInt(key);

  @override
  double? getDouble(String key) => _inner.getDouble(key);

  @override
  String? getString(String key) => _inner.getString(key);

  @override
  bool containsKey(String key) => _inner.containsKey(key);

  @override
  List<String>? getStringList(String key) => _inner.getStringList(key);

  @override
  Future<bool> setBool(String key, bool value) {
    writes.add('setBool:$key');
    return _inner.setBool(key, value);
  }

  @override
  Future<bool> setInt(String key, int value) {
    writes.add('setInt:$key');
    return _inner.setInt(key, value);
  }

  @override
  Future<bool> setDouble(String key, double value) {
    writes.add('setDouble:$key');
    return _inner.setDouble(key, value);
  }

  @override
  Future<bool> setString(String key, String value) {
    writes.add('setString:$key');
    return _inner.setString(key, value);
  }

  @override
  Future<bool> setStringList(String key, List<String> value) {
    writes.add('setStringList:$key');
    return _inner.setStringList(key, value);
  }

  @override
  Future<bool> remove(String key) {
    writes.add('remove:$key');
    return _inner.remove(key);
  }

  @override
  Future<bool> clear() => _inner.clear();

  @override
  Future<void> reload() => _inner.reload();

  /// The package's deprecated no-op.
  ///
  /// **It is answered here and not delegated**, because delegating would *call* a
  /// deprecated member and the analyzer reports that — and the method does nothing
  /// anyway, so the honest answer is the same answer the package gives.
  @override
  Future<bool> commit() async => true;
}
