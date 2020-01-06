/* Copyright (c) 2012-2017 The ANTLR Project. All rights reserved.
 * Use of this file is governed by the BSD 3-clause license that
 * can be found in the LICENSE.txt file in the project root.
 */

// A DFA walker that knows how to dump them to serialized strings.#/

class DFASerializer {
  var dfa;
  List<String> literalNames;
  List<String> symbolicNames;
  DFASerializer(dfa, literalNames, symbolicNames) {
    this.dfa = dfa;
    this.literalNames = literalNames ?? [];
    this.symbolicNames = symbolicNames ?? [];
  }

  toString() {
    if (this.dfa.s0 == null) {
      return null;
    }
    var buf = "";
    var states = this.dfa.sortedStates();
    for (var i = 0; i < states.length; i++) {
      var s = states[i];
      if (s.edges != null) {
        var n = s.edges.length;
        for (var j = 0; j < n; j++) {
          var t = s.edges[j] ?? null;
          if (t != null && t.stateNumber != 0x7FFFFFFF) {
            buf += this.getStateString(s);
            buf += "-";
            buf += this.getEdgeLabel(j);
            buf += "->";
            buf += this.getStateString(t);
            buf += '\n';
          }
        }
      }
    }
    return buf.length == 0 ? null : buf;
  }

  String getEdgeLabel(i) {
    if (i == 0) {
      return "EOF";
    } else if (this.literalNames != null || this.symbolicNames != null) {
      return this.literalNames[i - 1] ?? this.symbolicNames[i - 1];
    } else {
      return String.fromCharCode(i - 1);
    }
  }

  getStateString(s) {
    var baseStateStr = (s.isAcceptState ? ":" : "") +
        "s" +
        s.stateNumber +
        (s.requiresFullContext ? "^" : "");
    if (s.isAcceptState) {
      if (s.predicates != null) {
        return baseStateStr + "=>" + s.predicates.toString();
      } else {
        return baseStateStr + "=>" + s.prediction.toString();
      }
    } else {
      return baseStateStr;
    }
  }
}

class LexerDFASerializer extends DFASerializer {
  LexerDFASerializer(dfa) : super(dfa, null, null);
  getEdgeLabel(i) {
    return "'" + String.fromCharCode(i) + "'";
  }
}
