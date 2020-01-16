/* Copyright (c) 2012-2017 The ANTLR Project. All rights reserved.
 * Use of this file is governed by the BSD 3-clause license that
 * can be found in the LICENSE.txt file in the project root.
 */

import 'dart:math';

import 'package:collection/collection.dart';

import 'lexer.dart';
import 'token.dart';
import 'util/murmur_hash.dart';
import 'vocabulary.dart';

/** An immutable inclusive interval a..b */
class Interval {
  static final int INTERVAL_POOL_MAX_VALUE = 1000;

  static final Interval INVALID = new Interval(-1, -2);

  static List<Interval> cache = List<Interval>(INTERVAL_POOL_MAX_VALUE + 1);

  int a;
  int b;

  static int creates = 0;
  static int misses = 0;
  static int hits = 0;
  static int outOfRange = 0;

  Interval(this.a, this.b);

  /** Interval objects are used readonly so share all with the
   *  same single value a==b up to some max size.  Use an array as a perfect hash.
   *  Return shared object for 0..INTERVAL_POOL_MAX_VALUE or a new
   *  Interval object with a..a in it.  On Java.g4, 218623 IntervalSets
   *  have a..a (set with 1 element).
   */
  static Interval of(int a, int b) {
    // cache just a..a
    if (a != b || a < 0 || a > INTERVAL_POOL_MAX_VALUE) {
      return new Interval(a, b);
    }
    if (cache[a] == null) {
      cache[a] = new Interval(a, a);
    }
    return cache[a];
  }

  /** return number of elements between a and b inclusively. x..x is length 1.
   *  if b &lt; a, then length is 0.  9..10 has length 2.
   */
  int get length {
    if (b < a) return 0;
    return b - a + 1;
  }

  bool operator ==(Object o) {
    if (o == null || !(o is Interval)) {
      return false;
    }
    Interval other = o;
    return this.a == other.a && this.b == other.b;
  }

  int get hashCode {
    int hash = 23;
    hash = hash * 31 + a;
    hash = hash * 31 + b;
    return hash;
  }

  /** Does this start completely before other? Disjoint */
  bool startsBeforeDisjoint(Interval other) {
    return this.a < other.a && this.b < other.a;
  }

  /** Does this start at or before other? Nondisjoint */
  bool startsBeforeNonDisjoint(Interval other) {
    return this.a <= other.a && this.b >= other.a;
  }

  /** Does this.a start after other.b? May or may not be disjoint */
  bool startsAfter(Interval other) {
    return this.a > other.a;
  }

  /** Does this start completely after other? Disjoint */
  bool startsAfterDisjoint(Interval other) {
    return this.a > other.b;
  }

  /** Does this start after other? NonDisjoint */
  bool startsAfterNonDisjoint(Interval other) {
    return this.a > other.a && this.a <= other.b; // this.b>=other.b implied
  }

  /** Are both ranges disjoint? I.e., no overlap? */
  bool disjoint(Interval other) {
    return startsBeforeDisjoint(other) || startsAfterDisjoint(other);
  }

  /** Are two intervals adjacent such as 0..41 and 42..42? */
  bool adjacent(Interval other) {
    return this.a == other.b + 1 || this.b == other.a - 1;
  }

  bool properlyContains(Interval other) {
    return other.a >= this.a && other.b <= this.b;
  }

  /** Return the interval computed from combining this and other */
  Interval union(Interval other) {
    return Interval.of(min(a, other.a), max(b, other.b));
  }

  /** Return the interval in common between this and o */
  Interval intersection(Interval other) {
    return Interval.of(max(a, other.a), min(b, other.b));
  }

  /** Return the interval with elements from this not in other;
   *  other must not be totally enclosed (properly contained)
   *  within this, which would result in two disjoint intervals
   *  instead of the single one returned by this method.
   */
  Interval differenceNotProperlyContained(Interval other) {
    Interval diff = null;
    // other.a to left of this.a (or same)
    if (other.startsBeforeNonDisjoint(this)) {
      diff = Interval.of(max(this.a, other.b + 1), this.b);
    }

    // other.a to right of this.a
    else if (other.startsAfterNonDisjoint(this)) {
      diff = Interval.of(this.a, other.a - 1);
    }
    return diff;
  }

  String toString() {
    return "$a..$b";
  }
}

/**
 * This class implements the {@link IntervalSet} backed by a sorted array of
 * non-overlapping intervals. It is particularly efficient for representing
 * large collections of numbers, where the majority of elements appear as part
 * of a sequential range of numbers that are all part of the set. For example,
 * the set { 1, 2, 3, 4, 7, 8 } may be represented as { [1, 4], [7, 8] }.
 *
 * <p>
 * This class is able to represent sets containing any combination of values in
 * the range {@link int#MIN_VALUE} to {@link int#MAX_VALUE}
 * (inclusive).</p>
 */
class IntervalSet {
  static final IntervalSet COMPLETE_CHAR_SET =
      IntervalSet.ofRange(Lexer.MIN_CHAR_VALUE, Lexer.MAX_CHAR_VALUE)
        ..setReadonly(true);

  static final IntervalSet EMPTY_SET = new IntervalSet([])..setReadonly(true);

  /** The list of sorted, disjoint intervals. */
  List<Interval> intervals = [];

  bool readonly = false;

  IntervalSet([List<Interval> intervals]) {
    this.intervals = intervals ?? [];
  }

  IntervalSet.ofSet(IntervalSet set) {
    addAll(set);
  }

// TODO
// IntervalSet(int... els) {
//if ( els==null ) {
//intervals = new ArrayList<Interval>(2); // most sets are 1 or 2 elements
//}
//else {
//intervals = new ArrayList<Interval>(els.length);
//for (int e : els) add(e);
//}
//}

  /** Create a set with a single element, el. */

  IntervalSet.ofOne(int a) {
    addOne(a);
  }

  /** Create a set with all ints within range [a..b] (inclusive) */
  static IntervalSet ofRange(int a, int b) {
    IntervalSet s = new IntervalSet();
    s.addRange(a, b);
    return s;
  }

  void clear() {
    if (readonly) throw new StateError("can't alter readonly IntervalSet");
    intervals.clear();
  }

  /** Add a single element to the set.  An isolated element is stored
   *  as a range el..el.
   */

  void addOne(int el) {
    if (readonly) throw new StateError("can't alter readonly IntervalSet");
    addRange(el, el);
  }

  /** Add interval; i.e., add all integers from a to b to set.
   *  If b&lt;a, do nothing.
   *  Keep list in sorted order (by left range value).
   *  If overlap, combine ranges.  For example,
   *  If this is {1..5, 10..20}, adding 6..7 yields
   *  {1..5, 6..7, 10..20}.  Adding 4..8 yields {1..8, 10..20}.
   */
  void addRange(int a, int b) {
    add(Interval.of(a, b));
  }

  // copy on write so we can cache a..a intervals and sets of that
  void add(Interval addition) {
    if (readonly) throw new StateError("can't alter readonly IntervalSet");
    //System.out.println("add "+addition+" to "+intervals.toString());
    if (addition.b < addition.a) {
      return;
    }
    for (int i = 0; i < intervals.length; i++) {
      Interval r = intervals[i];
      if (addition == r) {
        return;
      }
      if (addition.adjacent(r) || !addition.disjoint(r)) {
        // next to each other, make a single larger interval
        Interval bigger = addition.union(r);
        intervals[i] = bigger;

        // make sure we didn't just create an interval that
        // should be merged with next interval in list
        for (i++; i < intervals.length; i++) {
          Interval next = intervals[i];
          if (!bigger.adjacent(next) && bigger.disjoint(next)) {
            break;
          }

          // if we bump up against or overlap next, merge
          intervals.removeAt(i); // remove this one
          intervals[i - 1] =
              bigger.union(next); // set previous to 3 merged ones
        }
        return;
      }
      if (addition.startsBeforeDisjoint(r)) {
        // insert before r
        intervals.insert(i, addition);
        return;
      }
      // if disjoint and after r, a future iteration will handle it

    }
    // ok, must be after last interval (and disjoint from last interval)
    // just add it
    intervals.add(addition);
  }

  /** combine all sets in the array returned the or'd value */
  static IntervalSet or(List<IntervalSet> sets) {
    IntervalSet r = new IntervalSet();
    for (IntervalSet s in sets) r.addAll(s);
    return r;
  }

  IntervalSet operator |(IntervalSet a) {
    IntervalSet o = new IntervalSet();
    o.addAll(this);
    o.addAll(a);
    return o;
  }

  IntervalSet addAll(IntervalSet set) {
    if (set == null) {
      return this;
    }

    if (set is IntervalSet) {
      IntervalSet other = set;
      // walk set and add each interval
      int n = other.intervals.length;
      for (int i = 0; i < n; i++) {
        Interval I = other.intervals[i];
        this.addRange(I.a, I.b);
      }
    } else {
      for (int value in set.toList()) {
        addOne(value);
      }
    }

    return this;
  }

  IntervalSet complementRange(int minElement, int maxElement) {
    return this.complement(IntervalSet.ofRange(minElement, maxElement));
  }

  /** {@inheritDoc} */
  IntervalSet complement(IntervalSet vocabulary) {
    if (vocabulary == null || vocabulary.isNil) {
      return null; // nothing in common with null set
    }
    IntervalSet vocabularyIS;
    if (vocabulary is IntervalSet) {
      vocabularyIS = vocabulary;
    } else {
      vocabularyIS = new IntervalSet();
      vocabularyIS.addAll(vocabulary);
    }

    return vocabularyIS - this;
  }

  IntervalSet operator -(IntervalSet a) {
    if (a == null || a.isNil) {
      return new IntervalSet.ofSet(this);
    }

    if (a is IntervalSet) {
      return subtract(this, a);
    }

    IntervalSet other = new IntervalSet();
    other.addAll(a);
    return subtract(this, other);
  }

  /**
   * Compute the set difference between two interval sets. The specific
   * operation is {@code left - right}. If either of the input sets is
   * {@code null}, it is treated as though it was an empty set.
   */
  static IntervalSet subtract(IntervalSet left, IntervalSet right) {
    if (left == null || left.isNil) {
      return new IntervalSet();
    }

    IntervalSet result = new IntervalSet.ofSet(left);
    if (right == null || right.isNil) {
      // right set has no elements; just return the copy of the current set
      return result;
    }

    int resultI = 0;
    int rightI = 0;
    while (
        resultI < result.intervals.length && rightI < right.intervals.length) {
      Interval resultInterval = result.intervals[resultI];
      Interval rightInterval = right.intervals[rightI];

// operation: (resultInterval - rightInterval) and update indexes

      if (rightInterval.b < resultInterval.a) {
        rightI++;
        continue;
      }

      if (rightInterval.a > resultInterval.b) {
        resultI++;
        continue;
      }

      Interval beforeCurrent = null;
      Interval afterCurrent = null;
      if (rightInterval.a > resultInterval.a) {
        beforeCurrent = new Interval(resultInterval.a, rightInterval.a - 1);
      }

      if (rightInterval.b < resultInterval.b) {
        afterCurrent = new Interval(rightInterval.b + 1, resultInterval.b);
      }

      if (beforeCurrent != null) {
        if (afterCurrent != null) {
// split the current interval into two
          result.intervals[resultI] = beforeCurrent;
          result.intervals.insert(resultI + 1, afterCurrent);
          resultI++;
          rightI++;
          continue;
        } else {
// replace the current interval
          result.intervals[resultI] = beforeCurrent;
          resultI++;
          continue;
        }
      } else {
        if (afterCurrent != null) {
// replace the current interval
          result.intervals[resultI] = afterCurrent;
          rightI++;
          continue;
        } else {
// remove the current interval (thus no need to increment resultI)
          result.intervals.remove(resultI);
          continue;
        }
      }
    }

// If rightI reached right.intervals.length, no more intervals to subtract from result.
// If resultI reached result.intervals.length, we would be subtracting from an empty set.
// Either way, we are done.
    return result;
  }

  /** {@inheritDoc} */
  IntervalSet operator +(IntervalSet other) {
    if (other == null) {
      //|| !(other is IntervalSet) ) {
      return null; // nothing in common with null set
    }

    List<Interval> myIntervals = this.intervals;
    List<Interval> theirIntervals = (other).intervals;
    IntervalSet intersection = null;
    int mySize = myIntervals.length;
    int theirSize = theirIntervals.length;
    int i = 0;
    int j = 0;
// iterate down both interval lists looking for nondisjoint intervals
    while (i < mySize && j < theirSize) {
      Interval mine = myIntervals[i];
      Interval theirs = theirIntervals[j];
//System.out.println("mine="+mine+" and theirs="+theirs);
      if (mine.startsBeforeDisjoint(theirs)) {
// move this iterator looking for interval that might overlap
        i++;
      } else if (theirs.startsBeforeDisjoint(mine)) {
// move other iterator looking for interval that might overlap
        j++;
      } else if (mine.properlyContains(theirs)) {
// overlap, add intersection, get next theirs
        if (intersection == null) {
          intersection = new IntervalSet();
        }
        intersection.add(mine.intersection(theirs));
        j++;
      } else if (theirs.properlyContains(mine)) {
// overlap, add intersection, get next mine
        if (intersection == null) {
          intersection = new IntervalSet();
        }
        intersection.add(mine.intersection(theirs));
        i++;
      } else if (!mine.disjoint(theirs)) {
// overlap, add intersection
        if (intersection == null) {
          intersection = new IntervalSet();
        }
        intersection.add(mine.intersection(theirs));
// Move the iterator of lower range [a..b], but not
// the upper range as it may contain elements that will collide
// with the next iterator. So, if mine=[0..115] and
// theirs=[115..200], then intersection is 115 and move mine
// but not theirs as theirs may collide with the next range
// in thisIter.
// move both iterators to next ranges
        if (mine.startsAfterNonDisjoint(theirs)) {
          j++;
        } else if (theirs.startsAfterNonDisjoint(mine)) {
          i++;
        }
      }
    }
    if (intersection == null) {
      return new IntervalSet();
    }
    return intersection;
  }

  /** {@inheritDoc} */

  bool contains(int el) {
    int n = intervals.length;
    int l = 0;
    int r = n - 1;
// Binary search for the element in the (sorted,
// disjoint) array of intervals.
    while (l <= r) {
      int m = ((l + r) / 2).floor();
      Interval I = intervals[m];
      int a = I.a;
      int b = I.b;
      if (b < el) {
        l = m + 1;
      } else if (a > el) {
        r = m - 1;
      } else {
        // el >= a && el <= b
        return true;
      }
    }
    return false;
  }

  /** {@inheritDoc} */

  bool get isNil {
    return intervals == null || intervals.isEmpty;
  }

  /**
   * Returns the maximum value contained in the set if not isNil().
   *
   * @return the maximum value contained in the set.
   * @throws RuntimeException if set is empty
   */
  int get maxElement {
    if (isNil) {
      throw new StateError("set is empty");
    }
    return intervals.last.b;
  }

  /**
   * Returns the minimum value contained in the set if not isNil().
   *
   * @return the minimum value contained in the set.
   * @throws RuntimeException if set is empty
   */
  int get minElement {
    if (isNil) {
      throw new StateError("set is empty");
    }

    return intervals.first.a;
  }

  int get hashCode {
    int hash = MurmurHash.initialize();
    for (Interval I in intervals) {
      hash = MurmurHash.update(hash, I.a);
      hash = MurmurHash.update(hash, I.b);
    }

    hash = MurmurHash.finish(hash, intervals.length * 2);
    return hash;
  }

  /** Are two IntervalSets equal?  Because all intervals are sorted
   *  and disjoint, equals is a simple linear walk over both lists
   *  to make sure they are the same.  Interval.equals() is used
   *  by the List.equals() method to check the ranges.
   */

  bool operator ==(Object obj) {
    if (obj == null || !(obj is IntervalSet)) {
      return false;
    }
    IntervalSet other = obj;
    return ListEquality().equals(this.intervals, other.intervals);
  }

  String toString({bool elemAreChar = false, Vocabulary vocabulary}) {
    StringBuffer buf = new StringBuffer();
    if (this.intervals == null || this.intervals.isEmpty) {
      return "{}";
    }
    if (this.length > 1) {
      buf.write("{");
    }

    for (var I in this.intervals) {
      int a = I.a;
      int b = I.b;
      if (a == b) {
        if (vocabulary != null) {
          buf.write(elementName(vocabulary, a));
        } else {
          if (a == Token.EOF) {
            buf.write("<EOF>");
          } else if (elemAreChar) {
            buf.write("'");
            buf.writeCharCode(a);
            buf.write("'");
          } else {
            buf.write(a);
          }
        }
      } else {
        if (vocabulary != null) {
          for (int i = a; i <= b; i++) {
            if (i > a) buf.write(", ");
            buf.write(elementName(vocabulary, i));
          }
        }
        if (elemAreChar) {
          buf.write("'");
          buf.writeCharCode(a);
          buf.write("'..'");
          buf.writeCharCode(b);
          buf.write("'");
        } else {
          buf.write(a);
          buf.write("..");
          buf.write(b);
        }
      }
      buf.write(", "); // TODO Not write for the last element
    }
    if (this.length > 1) {
      buf.write("}");
    }
    return buf.toString();
  }

  String elementName(Vocabulary vocabulary, int a) {
    if (a == Token.EOF) {
      return "<EOF>";
    } else if (a == Token.EPSILON) {
      return "<EPSILON>";
    } else {
      return vocabulary.getDisplayName(a);
    }
  }

  int get length {
    int n = 0;
    int numIntervals = intervals.length;
    if (numIntervals == 1) {
      Interval firstInterval = this.intervals[0];
      return firstInterval.b - firstInterval.a + 1;
    }
    for (int i = 0; i < numIntervals; i++) {
      Interval I = intervals[i];
      n += (I.b - I.a + 1);
    }
    return n;
  }

  List<int> toIntegerList() {
    List<int> values = new List<int>(length);
    int n = intervals.length;
    for (int i = 0; i < n; i++) {
      Interval I = intervals[i];
      int a = I.a;
      int b = I.b;
      for (int v = a; v <= b; v++) {
        values.add(v);
      }
    }
    return values;
  }

  List<int> toList() {
    List<int> values = [];
    int n = intervals.length;
    for (int i = 0; i < n; i++) {
      Interval I = intervals[i];
      int a = I.a;
      int b = I.b;
      for (int v = a; v <= b; v++) {
        values.add(v);
      }
    }
    return values;
  }

  Set<int> toSet() {
    Set<int> s = new Set();
    for (Interval I in intervals) {
      int a = I.a;
      int b = I.b;
      for (int v = a; v <= b; v++) {
        s.add(v);
      }
    }
    return s;
  }

  /** Get the ith element of ordered set.  Used only by RandomPhrase so
   *  don't bother to implement if you're not doing that for a new
   *  ANTLR code gen target.
   */
  int get(int i) {
    int n = intervals.length;
    int index = 0;
    for (int j = 0; j < n; j++) {
      Interval I = intervals[j];
      int a = I.a;
      int b = I.b;
      for (int v = a; v <= b; v++) {
        if (index == i) {
          return v;
        }
        index++;
      }
    }
    return -1;
  }

  void remove(int el) {
    if (readonly) throw new StateError("can't alter readonly IntervalSet");
    int n = intervals.length;
    for (int i = 0; i < n; i++) {
      Interval I = intervals[i];
      int a = I.a;
      int b = I.b;
      if (el < a) {
        break; // list is sorted and el is before this interval; not here
      }
// if whole interval x..x, rm
      if (el == a && el == b) {
        intervals.remove(i);
        break;
      }
// if on left edge x..b, adjust left
      if (el == a) {
        I.a++;
        break;
      }
// if on right edge a..x, adjust right
      if (el == b) {
        I.b--;
        break;
      }
// if in middle a..x..b, split interval
      if (el > a && el < b) {
        // found in this interval
        int oldb = I.b;
        I.b = el - 1; // [a..x-1]
        addRange(el + 1, oldb); // add [x+1..b]
      }
    }
  }

  bool isReadonly() {
    return readonly;
  }

  void setReadonly(bool readonly) {
    if (this.readonly && !readonly)
      throw new StateError("can't alter readonly IntervalSet");
    this.readonly = readonly;
  }
}
