//
/* Copyright (c) 2012-2017 The ANTLR Project. All rights reserved.
 * Use of this file is governed by the BSD 3-clause license that
 * can be found in the LICENSE.txt file in the project root.
 */
//

// The following images show the relation of states and
// {@link ATNState//transitions} for various grammar constructs.
//
// <ul>
//
// <li>Solid edges marked with an &//0949; indicate a required
// {@link EpsilonTransition}.</li>
//
// <li>Dashed edges indicate locations where any transition derived from
// {@link Transition} might appear.</li>
//
// <li>Dashed nodes are place holders for either a sequence of linked
// {@link BasicState} states or the inclusion of a block representing a nested
// construct in one of the forms below.</li>
//
// <li>Nodes showing multiple outgoing alternatives with a {@code ...} support
// any number of alternatives (one or more). Nodes without the {@code ...} only
// support the exact number of alternatives shown in the diagram.</li>
//
// </ul>
//
// <h2>Basic Blocks</h2>
//
// <h3>Rule</h3>
//
// <embed src="images/Rule.svg" type="image/svg+xml"/>
//
// <h3>Block of 1 or more alternatives</h3>
//
// <embed src="images/Block.svg" type="image/svg+xml"/>
//
// <h2>Greedy Loops</h2>
//
// <h3>Greedy Closure: {@code (...)*}</h3>
//
// <embed src="images/ClosureGreedy.svg" type="image/svg+xml"/>
//
// <h3>Greedy Positive Closure: {@code (...)+}</h3>
//
// <embed src="images/PositiveClosureGreedy.svg" type="image/svg+xml"/>
//
// <h3>Greedy Optional: {@code (...)?}</h3>
//
// <embed src="images/OptionalGreedy.svg" type="image/svg+xml"/>
//
// <h2>Non-Greedy Loops</h2>
//
// <h3>Non-Greedy Closure: {@code (...)*?}</h3>
//
// <embed src="images/ClosureNonGreedy.svg" type="image/svg+xml"/>
//
// <h3>Non-Greedy Positive Closure: {@code (...)+?}</h3>
//
// <embed src="images/PositiveClosureNonGreedy.svg" type="image/svg+xml"/>
//
// <h3>Non-Greedy Optional: {@code (...)??}</h3>
//
// <embed src="images/OptionalNonGreedy.svg" type="image/svg+xml"/>
//

var INITIAL_NUM_TRANSITIONS = 4;

class ATNState {
  var atn;
  var stateNumber;
  var stateType;
  var ruleIndex;
  var epsilonOnlyTransitions;
  var transitions;
  var nextTokenWithinRule;
  ATNState() {
    // Which ATN are we in?
    this.atn = null;
    this.stateNumber = ATNState.INVALID_STATE_NUMBER;
    this.stateType = null;
    this.ruleIndex = 0; // at runtime, we don't have Rule objects
    this.epsilonOnlyTransitions = false;
    // Track the transitions emanating from this ATN state.
    this.transitions = [];
    // Used to cache lookahead during parsing, not used during construction
    this.nextTokenWithinRule = null;
  }

// constants for serialization
  static const INVALID_TYPE = 0;
  static const BASIC = 1;
  static const RULE_START = 2;
  static const BLOCK_START = 3;
  static const PLUS_BLOCK_START = 4;
  static const STAR_BLOCK_START = 5;
  static const TOKEN_START = 6;
  static const RULE_STOP = 7;
  static const BLOCK_END = 8;
  static const STAR_LOOP_BACK = 9;
  static const STAR_LOOP_ENTRY = 10;
  static const PLUS_LOOP_BACK = 11;
  static const LOOP_END = 12;

  static final serializationNames = [
    "INVALID",
    "BASIC",
    "RULE_START",
    "BLOCK_START",
    "PLUS_BLOCK_START",
    "STAR_BLOCK_START",
    "TOKEN_START",
    "RULE_STOP",
    "BLOCK_END",
    "STAR_LOOP_BACK",
    "STAR_LOOP_ENTRY",
    "PLUS_LOOP_BACK",
    "LOOP_END"
  ];

  static final INVALID_STATE_NUMBER = -1;

  toString() {
    return this.stateNumber;
  }

  equals(other) {
    if (other is ATNState) {
      return this.stateNumber == other.stateNumber;
    } else {
      return false;
    }
  }

  isNonGreedyExitState() {
    return false;
  }

  addTransition(trans, {int index =-1}) {
  
    if (this.transitions.length == 0) {
      this.epsilonOnlyTransitions = trans.isEpsilon;
    } else if (this.epsilonOnlyTransitions != trans.isEpsilon) {
      this.epsilonOnlyTransitions = false;
    }
    if (index == -1) {
      this.transitions.push(trans);
    } else {
      this.transitions.splice(index, 1, trans);
    }
  }
}

class BasicState extends ATNState {
  BasicState() {
    this.stateType = ATNState.BASIC;
  }
}

class DecisionState extends ATNState {
  int decision = -1;
  bool nonGreedy = false;
}

//  The start of a regular {@code (...)} block.
class BlockStartState extends DecisionState {
  var endState = null;
}

class BasicBlockStartState extends BlockStartState {
  BasicBlockStartState() {
    this.stateType = ATNState.BLOCK_START;
  }
}

// Terminal node of a simple {@code (a|b|c)} block.
class BlockEndState extends ATNState {
  var startState = null;
  BlockEndState() {
    this.stateType = ATNState.BLOCK_END;
  }
}

// The last node in the ATN for a rule, unless that rule is the start symbol.
//  In that case, there is one transition to EOF. Later, we might encode
//  references to all calls to this rule to compute FOLLOW sets for
//  error handling.
//
class RuleStopState extends ATNState {
  RuleStopState() {
    this.stateType = ATNState.RULE_STOP;
  }
}

class RuleStartState extends ATNState {
  var stopState = null;
  var isPrecedenceRule = false;
  RuleStartState() {
    this.stateType = ATNState.RULE_START;
  }
}

// Decision state for {@code A+} and {@code (A|B)+}.  It has two transitions:
//  one to the loop back to start of the block and one to exit.
//
class PlusLoopbackState extends DecisionState {
  PlusLoopbackState() {
    this.stateType = ATNState.PLUS_LOOP_BACK;
  }
}

// Start of {@code (A|B|...)+} loop. Technically a decision state, but
//  we don't use for code generation; somebody might need it, so I'm defining
//  it for completeness. In reality, the {@link PlusLoopbackState} node is the
//  real decision-making note for {@code A+}.
//
class PlusBlockStartState extends BlockStartState {
  var loopBackState = null;
  PlusBlockStartState() {
    this.stateType = ATNState.PLUS_BLOCK_START;
  }
}

// The block that begins a closure loop.
class StarBlockStartState extends BlockStartState {
  StarBlockStartState() {
    this.stateType = ATNState.STAR_BLOCK_START;
  }
}

class StarLoopbackState extends ATNState {
  StarLoopbackState() {
    this.stateType = ATNState.STAR_LOOP_BACK;
  }
}

class StarLoopEntryState extends DecisionState {
  var loopBackState = null;
  // Indicates whether this state can benefit from a precedence DFA during SLL decision making.
  var isPrecedenceDecision = null;
  StarLoopEntryState() {
    this.stateType = ATNState.STAR_LOOP_ENTRY;
  }
}

// Mark the end of a * or + loop.
class LoopEndState extends ATNState {
  var loopBackState = null;
  LoopEndState() {
    this.stateType = ATNState.LOOP_END;
  }
}

// The Tokens rule start state linking to each lexer rule start state */
class TokensStartState extends DecisionState {
  TokensStartState() {
    this.stateType = ATNState.TOKEN_START;
  }
}
