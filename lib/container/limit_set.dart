class LimitSet<T> {
  int _limit;
  final Set<T> _set = <T>{};
  final List<T> _seq = [];

  LimitSet({int limit = 1024}) : _limit = limit;

  set limit(value) => _limit = value;
  get limit => _limit;

  bool contains(T t) {
    return _set.contains(t);
  }

  bool add(T t) {
    if (_set.contains(t)) return false;

    _set.add(t);
    _seq.add(t);

    if (_set.length > _limit && _seq.isNotEmpty) {
      final val = _seq.first!;
      _set.remove(val);
      _seq.removeAt(0);
    }

    return true;
  }

  remove(T t) {
    return _set.remove(t);
  }
}
