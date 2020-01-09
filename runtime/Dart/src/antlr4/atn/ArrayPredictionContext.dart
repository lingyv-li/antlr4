import 'package:collection/collection.dart';

import '../PredictionContext.dart';

class ArrayPredictionContext extends PredictionContext {
  /** Parent can be null only if full ctx mode and we make an array
   *  from {@link #EMPTY} and non-empty. We merge {@link #EMPTY} by using null parent and
   *  returnState == {@link #EMPTY_RETURN_STATE}.
   */
  List<PredictionContext> parents;

  /** Sorted for merge, no duplicates; if present,
   *  {@link #EMPTY_RETURN_STATE} is always last.
   */
  List<int> returnStates;

  ArrayPredictionContext.of(SingletonPredictionContext a)
      : this([a.parent], [a.returnState]);

  ArrayPredictionContext(
      List<PredictionContext> parents, List<int> returnStates)
      : super(PredictionContext.calculateHashCode(parents, returnStates)) {
    assert(parents != null && parents.length > 0);
    assert(returnStates != null && returnStates.length > 0);
//		System.err.println("CREATE ARRAY: "+Arrays.toString(parents)+", "+Arrays.toString(returnStates));
    this.parents = parents;
    this.returnStates = returnStates;
  }

  bool isEmpty() {
    // since EMPTY_RETURN_STATE can only appear in the last position, we
    // don't need to verify that size==1
    return returnStates[0] == PredictionContext.EMPTY_RETURN_STATE;
  }

  int size() {
    return returnStates.length;
  }

  PredictionContext getParent(int index) {
    return parents[index];
  }

  int getReturnState(int index) {
    return returnStates[index];
  }

//	 int findReturnState(int returnState) {
//		return Arrays.binarySearch(returnStates, returnState);
//	}

  bool equals(Object o) {
    if (this == o) {
      return true;
    } else if (o is ArrayPredictionContext) {
      if (this.hashCode() != o.hashCode()) {
        return false; // can't be same if hash is different
      }

      ArrayPredictionContext a = o;
      return ListEquality().equals(returnStates, a.returnStates) &&
          ListEquality().equals(parents, a.parents);
    }
    return false;
  }

  String toString() {
    if (isEmpty()) return "[]";
    StringBuffer buf = new StringBuffer();
    buf.write("[");
    for (int i = 0; i < returnStates.length; i++) {
      if (i > 0) buf.write(", ");
      if (returnStates[i] == PredictionContext.EMPTY_RETURN_STATE) {
        buf.write(r"$");
        continue;
      }
      buf.write(returnStates[i]);
      if (parents[i] != null) {
        buf.write(' ');
        buf.write(parents[i].toString());
      } else {
        buf.write("null");
      }
    }
    buf.write("]");
    return buf.toString();
  }
}
