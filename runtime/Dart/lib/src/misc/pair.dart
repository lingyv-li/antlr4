class Pair<A, B> {
  final A a;
  final B b;

  const Pair(this.a, this.b);

  @override
  bool operator ==(other) {
    return other is Pair<A, B> && a == other.a && b == other.b;
  }

  String toString() {
    return "($a, $b)";
  }

  @override
  int get hashCode {
    return a.hashCode ^ b.hashCode;
  }
}
