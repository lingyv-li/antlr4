//
/* Copyright (c) 2012-2017 The ANTLR Project. All rights reserved.
 * Use of this file is governed by the BSD 3-clause license that
 * can be found in the LICENSE.txt file in the project root.
 */
//

// A tree structure used to record the semantic context in which
//  an ATN configuration is valid.  It's either a single predicate,
//  a conjunction {@code p1&&p2}, or a sum of products {@code p1||p2}.
//
//  <p>I have scoped the {@link AND}, {@link OR}, and {@link Predicate} subclasses of
//  {@link SemanticContext} within the scope of this outer class.</p>
//

abstract class SemanticContext {
  @override
  int get hashCode => updateHashCode();

  int updateHashCode();

  // For context independent predicates, we evaluate them without a local
  // context (i.e., null context). That way, we can evaluate them without
  // having to create proper rule-specific context during prediction (as
  // opposed to the parser, which creates them naturally). In a practical
  // sense, this avoids a cast exception from RuleContext to myruleContext.
  //
  // <p>For context dependent predicates, we must pass in a local context so that
  // references such as $arg evaluate properly as _localctx.arg. We only
  // capture context dependent predicates in the context in which we begin
  // prediction, so we passed in the outer context here in case of context
  // dependent predicate evaluation.</p>
  //
  evaluate(parser, outerContext);

//
// Evaluate the precedence predicates for the context and reduce the result.
//
// @param parser The parser instance.
// @param outerContext The current parser context object.
// @return The simplified semantic context after precedence predicates are
// evaluated, which will be one of the following values.
// <ul>
// <li>{@link //NONE}: if the predicate simplifies to {@code true} after
// precedence predicates are evaluated.</li>
// <li>{@code null}: if the predicate simplifies to {@code false} after
// precedence predicates are evaluated.</li>
// <li>{@code this}: if the semantic context is not changed as a result of
// precedence predicate evaluation.</li>
// <li>A non-{@code null} {@link SemanticContext}: the new simplified
// semantic context after precedence predicates are evaluated.</li>
// </ul>
//
  evalPrecedence(parser, outerContext) {
    return this;
  }

  static andContext(a, b) {
    if (a == null || a == SemanticContext.NONE) {
      return b;
    }
    if (b == null || b == SemanticContext.NONE) {
      return a;
    }
    var result = new AND(a, b);
    if (result.opnds.length == 1) {
      return result.opnds[0];
    } else {
      return result;
    }
  }

  static orContext(a, b) {
    if (a == null) {
      return b;
    }
    if (b == null) {
      return a;
    }
    if (a == SemanticContext.NONE || b == SemanticContext.NONE) {
      return SemanticContext.NONE;
    }
    var result = new OR(a, b);
    if (result.opnds.length == 1) {
      return result.opnds[0];
    } else {
      return result;
    }
  }

  /// The default {@link SemanticContext}, which is semantically equivalent to
  /// a predicate of the form {@code {true}?}.
  ///
  static final NONE = new Predicate(0, 0, false);
}

class Predicate extends SemanticContext {
  int ruleIndex;
  int predIndex;
  bool isCtxDependent;
  Predicate(ruleIndex, predIndex, isCtxDependent) {
    this.ruleIndex = ruleIndex == null ? -1 : ruleIndex;
    this.predIndex = predIndex == null ? -1 : predIndex;
    this.isCtxDependent =
        isCtxDependent == null ? false : isCtxDependent; // e.g., $i ref in pred
  }

  evaluate(parser, outerContext) {
    var localctx = this.isCtxDependent ? outerContext : null;
    return parser.sempred(localctx, this.ruleIndex, this.predIndex);
  }

  updateHashCode(hash) {
    hash.update(this.ruleIndex, this.predIndex, this.isCtxDependent);
  }

  equals(other) {
    if (this == other) {
      return true;
    } else if (!(other is Predicate)) {
      return false;
    } else {
      return this.ruleIndex == other.ruleIndex &&
          this.predIndex == other.predIndex &&
          this.isCtxDependent == other.isCtxDependent;
    }
  }

  toString() {
    return "{$ruleIndex:$predIndex}?";
  }
}

class PrecedencePredicate {
  int precedence;
  PrecedencePredicate(precedence) {
    this.precedence = precedence == null ? 0 : precedence;
  }

  evaluate(parser, outerContext) {
    return parser.precpred(outerContext, this.precedence);
  }

  evalPrecedence(parser, outerContext) {
    if (parser.precpred(outerContext, this.precedence)) {
      return SemanticContext.NONE;
    } else {
      return null;
    }
  }

  compareTo(other) {
    return this.precedence - other.precedence;
  }

  updateHashCode(hash) {
    hash.update(31);
  }

  equals(other) {
    if (this == other) {
      return true;
    } else if (!(other is PrecedencePredicate)) {
      return false;
    } else {
      return this.precedence == other.precedence;
    }
  }

  toString() {
    return "{$precedence>=prec}?";
  }

  static filterPrecedencePredicates(s) {
    var result = [];
    s.values().map((context) {
      if (context is PrecedencePredicate) {
        result.add(context);
      }
    });
    return result;
  }
}

// A semantic context which is true whenever none of the contained contexts
// is false.
//
class AND extends SemanticContext {
  var opnds;
  AND(a, b) {
    var operands = new Set();
    if (a is AND) {
      a.opnds.map((o) {
        operands.add(o);
      });
    } else {
      operands.add(a);
    }
    if (b is AND) {
      b.opnds.map((o) {
        operands.add(o);
      });
    } else {
      operands.add(b);
    }
    var precedencePredicates =
        PrecedencePredicate.filterPrecedencePredicates(operands);
    if (precedencePredicates.length > 0) {
      // interested in the transition with the lowest precedence
      var reduced = null;
      precedencePredicates.map((p) {
        if (reduced == null || p.precedence < reduced.precedence) {
          reduced = p;
        }
      });
      operands.add(reduced);
    }
    this.opnds = operands.values();
  }

  updateHashCode(hash) {
    hash.update(this.opnds, "AND");
  }

//
// {@inheritDoc}
//
// <p>
// The evaluation of predicates by this context is short-circuiting, but
// unordered.</p>
//
  evaluate(parser, outerContext) {
    for (var i = 0; i < this.opnds.length; i++) {
      if (!this.opnds[i].evaluate(parser, outerContext)) {
        return false;
      }
    }
    return true;
  }

  evalPrecedence(parser, outerContext) {
    var differs = false;
    var operands = [];
    for (var i = 0; i < this.opnds.length; i++) {
      var context = this.opnds[i];
      var evaluated = context.evalPrecedence(parser, outerContext);
      differs |= (evaluated != context);
      if (evaluated == null) {
        // The AND context is false if any element is false
        return null;
      } else if (evaluated != SemanticContext.NONE) {
        // Reduce the result by skipping true elements
        operands.add(evaluated);
      }
    }
    if (!differs) {
      return this;
    }
    if (operands.length == 0) {
      // all elements were true, so the AND context is true
      return SemanticContext.NONE;
    }
    var result = null;
    operands.map((o) {
      result = result == null ? o : SemanticContext.andContext(result, o);
    });
    return result;
  }

  toString() {
    var s = "";
    this.opnds.map((o) {
      s += "&& " + o.toString();
    });
    return s.length > 3 ? s.substring(3) : s;
  }
}

//
// A semantic context which is true whenever at least one of the contained
// contexts is true.
//
class OR extends SemanticContext {
  var opnds;
  OR(a, b) {
    var operands = new Set();
    if (a is OR) {
      a.opnds.map((o) {
        operands.add(o);
      });
    } else {
      operands.add(a);
    }
    if (b is OR) {
      b.opnds.map((o) {
        operands.add(o);
      });
    } else {
      operands.add(b);
    }

    var precedencePredicates =
        PrecedencePredicate.filterPrecedencePredicates(operands);
    if (precedencePredicates.length > 0) {
      // interested in the transition with the highest precedence
      var s = precedencePredicates.sort((a, b) {
        return a.compareTo(b);
      });
      var reduced = s[s.length - 1];
      operands.add(reduced);
    }
    this.opnds = operands.values();
  }

  // TODO what this means
  bool constructor(other) {
    if (this == other) {
      return true;
    } else if (!(other is OR)) {
      return false;
    } else {
      return this.opnds == other.opnds;
    }
  }

  updateHashCode(hash) {
    hash.update(this.opnds, "OR");
  }

  /// <p>
  /// The evaluation of predicates by this context is short-circuiting, but
  /// unordered.</p>
  ///
  evaluate(parser, outerContext) {
    for (var i = 0; i < this.opnds.length; i++) {
      if (this.opnds[i].evaluate(parser, outerContext)) {
        return true;
      }
    }
    return false;
  }

  evalPrecedence(parser, outerContext) {
    var differs = false;
    var operands = [];
    for (var i = 0; i < this.opnds.length; i++) {
      var context = this.opnds[i];
      var evaluated = context.evalPrecedence(parser, outerContext);
      differs |= (evaluated != context);
      if (evaluated == SemanticContext.NONE) {
        // The OR context is true if any element is true
        return SemanticContext.NONE;
      } else if (evaluated != null) {
        // Reduce the result by skipping false elements
        operands.add(evaluated);
      }
    }
    if (!differs) {
      return this;
    }
    if (operands.length == 0) {
      // all elements were false, so the OR context is false
      return null;
    }
    var result = null;
    operands.map((o) {
      return result == null ? o : SemanticContext.orContext(result, o);
    });
    return result;
  }

  toString() {
    var s = "";
    this.opnds.map((o) {
      s += "|| " + o.toString();
    });
    return s.length > 3 ? s.substring(3) : s;
  }
}
