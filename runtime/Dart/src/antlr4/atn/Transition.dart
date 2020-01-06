/* Copyright (c) 2012-2017 The ANTLR Project. All rights reserved.
 * Use of this file is governed by the BSD 3-clause license that
 * can be found in the LICENSE.txt file in the project root.
 */
//

//  An ATN transition between any two ATN states.  Subclasses define
//  atom, set, epsilon, action, predicate, rule transitions.
//
//  <p>This is a one way link.  It emanates from a state (usually via a list of
//  transitions) and has a target state.</p>
//
//  <p>Since we never have to change the ATN transitions once we construct it,
//  we can fix these transitions as specific classes. The DFA transitions
//  on the other hand need to update the labels as it adds transitions to
//  the states. We'll use the term Edge for the DFA to distinguish them from
//  ATN transitions.</p>
import '../Token.dart';
import '../IntervalSet.dart';
import './SemanticContext.dart';

class Transition {
  var target;
  bool isEpsilon;
  var label;
  Transition(target) {
    // The target of this transition.
    if (target == null || target == null) {
      throw "target cannot be null.";
    }
    this.target = target;
    // Are we epsilon, action, sempred?
    this.isEpsilon = false;
    this.label = null;
  }
  // constants for serialization
  static const EPSILON = 1;
  static const RANGE = 2;
  static const RULE = 3;
  static const PREDICATE = 4; // e.g., {isType(input.LT(1))}?
  static const ATOM = 5;
  static const ACTION = 6;
  static const SET = 7; // ~(A|B) or ~atom, wildcard, which convert to next 2
  static const NOT_SET = 8;
  static const WILDCARD = 9;
  static const PRECEDENCE = 10;

  static const serializationNames = [
    "INVALID",
    "EPSILON",
    "RANGE",
    "RULE",
    "PREDICATE",
    "ATOM",
    "ACTION",
    "SET",
    "NOT_SET",
    "WILDCARD",
    "PRECEDENCE"
  ];

  static const serializationTypes = {
    EpsilonTransition: Transition.EPSILON,
    RangeTransition: Transition.RANGE,
    RuleTransition: Transition.RULE,
    PredicateTransition: Transition.PREDICATE,
    AtomTransition: Transition.ATOM,
    ActionTransition: Transition.ACTION,
    SetTransition: Transition.SET,
    NotSetTransition: Transition.NOT_SET,
    WildcardTransition: Transition.WILDCARD,
    PrecedencePredicateTransition: Transition.PRECEDENCE
  };
}

// TODO: make all transitions sets? no, should remove set edges
class AtomTransition extends Transition {
  var label_;
  var serializationType;

  AtomTransition(target, label) : super(target) {
    this.label_ =
        label; // The token type or character value; or, signifies special label.
    this.label = this.makeLabel();
    this.serializationType = Transition.ATOM;
  }

  makeLabel() {
    var s = new IntervalSet();
    s.addOne(this.label_);
    return s;
  }

  matches(symbol, minVocabSymbol, maxVocabSymbol) {
    return this.label_ == symbol;
  }

  toString() {
    return this.label_;
  }
}

class RuleTransition extends Transition {
  var ruleIndex;
  var precedence;
  var followState;
  var serializationType;
  RuleTransition(ruleStart, ruleIndex, precedence, followState)
      : super(ruleStart) {
    this.ruleIndex = ruleIndex; // ptr to the rule definition object for this rule ref
    this.precedence = precedence;
    this.followState = followState; // what node to begin computations following ref to rule
    this.serializationType = Transition.RULE;
    this.isEpsilon = true;
  }

  matches(symbol, minVocabSymbol, maxVocabSymbol) => false;
  
}

class EpsilonTransition extends Transition {
  var serializationType;
  var outermostPrecedenceReturn;
  EpsilonTransition(target, {outermostPrecedenceReturn}) : super(target) {
    this.serializationType = Transition.EPSILON;
    this.isEpsilon = true;
    this.outermostPrecedenceReturn = outermostPrecedenceReturn;
  }

  matches(symbol, minVocabSymbol, maxVocabSymbol) => false;
  

  toString() => "epsilon";
}

class RangeTransition extends Transition {
  var serializationType;
  var start;
  var stop;
  RangeTransition(target, start, stop) : super(target) {
    this.serializationType = Transition.RANGE;
    this.start = start;
    this.stop = stop;
    this.label = this.makeLabel();
  }

  makeLabel() {
    var s = new IntervalSet();
    s.addRange(this.start, this.stop);
    return s;
  }

  matches(symbol, minVocabSymbol, maxVocabSymbol) {
    return symbol >= this.start && symbol <= this.stop;
  }

  toString() {
    return "'" +
        String.fromCharCode(this.start) +
        "'..'" +
        String.fromCharCode(this.stop) +
        "'";
  }
}

class AbstractPredicateTransition extends Transition {
  AbstractPredicateTransition(target) : super(target);
}

class PredicateTransition extends Transition {
  var serializationType;
  var ruleIndex;
  var predIndex;
  var isCtxDependent;
  PredicateTransition(target, ruleIndex, predIndex, isCtxDependent)
      : super(target) {
    this.serializationType = Transition.PREDICATE;
    this.ruleIndex = ruleIndex;
    this.predIndex = predIndex;
    this.isCtxDependent = isCtxDependent; // e.g., $i ref in pred
    this.isEpsilon = true;
  }

  matches(symbol, minVocabSymbol, maxVocabSymbol) {
    return false;
  }

  getPredicate() {
    return new Predicate(this.ruleIndex, this.predIndex, this.isCtxDependent);
  }

  toString() {
    return "pred_" + this.ruleIndex + ":" + this.predIndex;
  }
}

class ActionTransition extends Transition {
  int serializationType;
  int ruleIndex;
  int actionIndex;
  bool isCtxDependent;
  ActionTransition(target, ruleIndex, actionIndex, isCtxDependent)
      : super(target) {
    this.serializationType = Transition.ACTION;
    this.ruleIndex = ruleIndex;
    this.actionIndex = actionIndex == null ? -1 : actionIndex;
    this.isCtxDependent =
        isCtxDependent == null ? false : isCtxDependent; // e.g., $i ref in pred
    this.isEpsilon = true;
  }

  matches(symbol, minVocabSymbol, maxVocabSymbol) {
    return false;
  }

  toString() {
    return "action_$ruleIndex:$actionIndex";
  }
}

// A transition containing a set of values.
class SetTransition extends Transition {
  int serializationType;
  SetTransition(target, st) : super(target) {
    this.serializationType = Transition.SET;
    if (st != null) {
      this.label = st;
    } else {
      this.label = new IntervalSet();
      this.label.addOne(Token.INVALID_TYPE);
    }
  }

  matches(symbol, minVocabSymbol, maxVocabSymbol) {
    return this.label.contains(symbol);
  }

  toString() {
    return this.label.toString();
  }
}

class NotSetTransition extends SetTransition {
  NotSetTransition(target, st) : super(target, st) {
    this.serializationType = Transition.NOT_SET;
  }

  matches(symbol, minVocabSymbol, maxVocabSymbol) {
    return symbol >= minVocabSymbol &&
        symbol <= maxVocabSymbol &&
        super.matches(symbol, minVocabSymbol, maxVocabSymbol);
  }

  toString() {
    return '~' + super.toString();
  }
}

class WildcardTransition extends Transition {
  int serializationType;
  WildcardTransition(target) : super(target) {
    this.serializationType = Transition.WILDCARD;
  }

  matches(symbol, minVocabSymbol, maxVocabSymbol) {
    return symbol >= minVocabSymbol && symbol <= maxVocabSymbol;
  }

  toString() {
    return ".";
  }
}

class PrecedencePredicateTransition extends AbstractPredicateTransition {
  int serializationType;
  int precedence;
  PrecedencePredicateTransition(target, precedence) : super(target) {
    this.serializationType = Transition.PRECEDENCE;
    this.precedence = precedence;
    this.isEpsilon = true;
  }

  matches(symbol, minVocabSymbol, maxVocabSymbol) {
    return false;
  }

  getPredicate() {
    return new PrecedencePredicate(this.precedence);
  }

  toString() {
    return "$precedence >= _p";
  }
}
