/* Copyright (c) 2012-2017 The ANTLR Project. All rights reserved.
 * Use of this file is governed by the BSD 3-clause license that
 * can be found in the LICENSE.txt file in the project root.
 */

// This is the earliest supported serialized UUID.
// stick to serialized version for now, we don't need a UUID instance
import '../IntervalSet.dart';
import '../Token.dart';
import 'ATN.dart';
import 'ATNDeserializationOptions.dart';
import 'ATNState.dart';
import 'ATNType.dart';
import 'LexerAction.dart';
import 'Transition.dart';

var BASE_SERIALIZED_UUID = "AADB8D7E-AEEF-4415-AD2B-8204D6CF042E";

//
// This UUID indicates the serialized ATN contains two sets of
// IntervalSets, where the second set's values are encoded as
// 32-bit integers to support the full Unicode SMP range up to U+10FFFF.
//
var ADDED_UNICODE_SMP = "59627784-3BE5-417A-B9EB-8131A7286089";

// This list contains all of the currently supported UUIDs, ordered by when
// the feature first appeared in this branch.
var SUPPORTED_UUIDS = [BASE_SERIALIZED_UUID, ADDED_UNICODE_SMP];

var SERIALIZED_VERSION = 3;

// This is the current serialized UUID.
var SERIALIZED_UUID = ADDED_UNICODE_SMP;

initArray(length, value) {
  var tmp = [];
  tmp[length - 1] = value;
  return tmp.map((i) {
    return value;
  });
}

class ATNDeserializer {
  var deserializationOptions;
  var stateFactories = null;
  var actionFactories = null;
  var data;
  var pos;
  var uuid;
  ATNDeserializer({options = null}) {
    this.deserializationOptions =
        options ?? ATNDeserializationOptions.defaultOptions;
  }

// Determines if a particular serialized representation of an ATN supports
// a particular feature, identified by the {@link UUID} used for serializing
// the ATN at the time the feature was first introduced.
//
// @param feature The {@link UUID} marking the first time the feature was
// supported in the serialized ATN.
// @param actualUuid The {@link UUID} of the actual serialized ATN which is
// currently being deserialized.
// @return {@code true} if the {@code actualUuid} value represents a
// serialized ATN at or after the feature identified by {@code feature} was
// introduced; otherwise, {@code false}.

  isFeatureSupported(feature, actualUuid) {
    var idx1 = SUPPORTED_UUIDS.indexOf(feature);
    if (idx1 < 0) {
      return false;
    }
    var idx2 = SUPPORTED_UUIDS.indexOf(actualUuid);
    return idx2 >= idx1;
  }

  deserialize(data) {
    this.reset(data);
    this.checkVersion();
    this.checkUUID();
    var atn = this.readATN();
    this.readStates(atn);
    this.readRules(atn);
    this.readModes(atn);
    var sets = [];
    // First, deserialize sets with 16-bit arguments <= U+FFFF.
    this.readSets(atn, sets, () {
      this.readInt();
    });
    // Next, if the ATN was serialized with the Unicode SMP feature,
    // deserialize sets with 32-bit arguments <= U+10FFFF.
    if (this.isFeatureSupported(ADDED_UNICODE_SMP, this.uuid)) {
      this.readSets(atn, sets, () {
        this.readInt32();
      });
    }
    this.readEdges(atn, sets);
    this.readDecisions(atn);
    this.readLexerActions(atn);
    this.markPrecedenceDecisions(atn);
    this.verifyATN(atn);
    if (this.deserializationOptions.generateRuleBypassTransitions &&
        atn.grammarType == ATNType.PARSER) {
      this.generateRuleBypassTransitions(atn);
      // re-verify after modification
      this.verifyATN(atn);
    }
    return atn;
  }

  reset(data) {
    var adjust = (c) {
      var v = c.charCodeAt(0);
      return v > 1 ? v - 2 : v + 65534;
    };
    var temp = data.split("").map(adjust);
    // don't adjust the first value since that's the version number
    temp[0] = data.charCodeAt(0);
    this.data = temp;
    this.pos = 0;
  }

  checkVersion() {
    var version = this.readInt();
    if (version != SERIALIZED_VERSION) {
      throw ("Could not deserialize ATN with version " +
          version +
          " (expected $SERIALIZED_VERSION).");
    }
  }

  checkUUID() {
    var uuid = this.readUUID();
    if (SUPPORTED_UUIDS.indexOf(uuid) < 0) {
      throw ("Could not deserialize ATN with UUID: $uuid (expected $SERIALIZED_UUID or a legacy UUID).");
    }
    this.uuid = uuid;
  }

  readATN() {
    var grammarType = this.readInt();
    var maxTokenType = this.readInt();
    return new ATN(grammarType, maxTokenType);
  }

  readStates(atn) {
    var j, pair, stateNumber;
    var loopBackStateNumbers = [];
    var endStateNumbers = [];
    var nstates = this.readInt();
    for (var i = 0; i < nstates; i++) {
      var stype = this.readInt();
      // ignore bad type of states
      if (stype == ATNState.INVALID_TYPE) {
        atn.addState(null);
        continue;
      }
      var ruleIndex = this.readInt();
      if (ruleIndex == 0xFFFF) {
        ruleIndex = -1;
      }
      var s = this.stateFactory(stype, ruleIndex);
      if (stype == ATNState.LOOP_END) {
        // special case
        var loopBackStateNumber = this.readInt();
        loopBackStateNumbers.add([s, loopBackStateNumber]);
      } else if (s is BlockStartState) {
        var endStateNumber = this.readInt();
        endStateNumbers.add([s, endStateNumber]);
      }
      atn.addState(s);
    }
    // delay the assignment of loop back and end states until we know all the
    // state instances have been initialized
    for (j = 0; j < loopBackStateNumbers.length; j++) {
      pair = loopBackStateNumbers[j];
      pair[0].loopBackState = atn.states[pair[1]];
    }

    for (j = 0; j < endStateNumbers.length; j++) {
      pair = endStateNumbers[j];
      pair[0].endState = atn.states[pair[1]];
    }

    var numNonGreedyStates = this.readInt();
    for (j = 0; j < numNonGreedyStates; j++) {
      stateNumber = this.readInt();
      atn.states[stateNumber].nonGreedy = true;
    }

    var numPrecedenceStates = this.readInt();
    for (j = 0; j < numPrecedenceStates; j++) {
      stateNumber = this.readInt();
      atn.states[stateNumber].isPrecedenceRule = true;
    }
  }

  readRules(atn) {
    var i;
    var nrules = this.readInt();
    if (atn.grammarType == ATNType.LEXER) {
      atn.ruleToTokenType = initArray(nrules, 0);
    }
    atn.ruleToStartState = initArray(nrules, 0);
    for (i = 0; i < nrules; i++) {
      var s = this.readInt();
      var startState = atn.states[s];
      atn.ruleToStartState[i] = startState;
      if (atn.grammarType == ATNType.LEXER) {
        var tokenType = this.readInt();
        if (tokenType == 0xFFFF) {
          tokenType = Token.EOF;
        }
        atn.ruleToTokenType[i] = tokenType;
      }
    }
    atn.ruleToStopState = initArray(nrules, 0);
    for (i = 0; i < atn.states.length; i++) {
      var state = atn.states[i];
      if (!(state is RuleStopState)) {
        continue;
      }
      atn.ruleToStopState[state.ruleIndex] = state;
      atn.ruleToStartState[state.ruleIndex].stopState = state;
    }
  }

  readModes(atn) {
    var nmodes = this.readInt();
    for (var i = 0; i < nmodes; i++) {
      var s = this.readInt();
      atn.modeToStartState.push(atn.states[s]);
    }
  }

  readSets(atn, sets, readUnicode) {
    var m = this.readInt();
    for (var i = 0; i < m; i++) {
      var iset = new IntervalSet();
      sets.push(iset);
      var n = this.readInt();
      var containsEof = this.readInt();
      if (containsEof != 0) {
        iset.addOne(-1);
      }
      for (var j = 0; j < n; j++) {
        var i1 = readUnicode();
        var i2 = readUnicode();
        iset.addRange(i1, i2);
      }
    }
  }

  readEdges(atn, sets) {
    var i, j, state, trans, target;
    var nedges = this.readInt();
    for (i = 0; i < nedges; i++) {
      var src = this.readInt();
      var trg = this.readInt();
      var ttype = this.readInt();
      var arg1 = this.readInt();
      var arg2 = this.readInt();
      var arg3 = this.readInt();
      trans = this.edgeFactory(atn, ttype, src, trg, arg1, arg2, arg3, sets);
      var srcState = atn.states[src];
      srcState.addTransition(trans);
    }
    // edges for rule stop states can be derived, so they aren't serialized
    for (i = 0; i < atn.states.length; i++) {
      state = atn.states[i];
      for (j = 0; j < state.transitions.length; j++) {
        var t = state.transitions[j];
        if (!(t is RuleTransition)) {
          continue;
        }
        var outermostPrecedenceReturn = -1;
        if (atn.ruleToStartState[t.target.ruleIndex].isPrecedenceRule) {
          if (t.precedence == 0) {
            outermostPrecedenceReturn = t.target.ruleIndex;
          }
        }

        trans = new EpsilonTransition(t.followState,
            outermostPrecedenceReturn: outermostPrecedenceReturn);
        atn.ruleToStopState[t.target.ruleIndex].addTransition(trans);
      }
    }

    for (i = 0; i < atn.states.length; i++) {
      state = atn.states[i];
      if (state is BlockStartState) {
        // we need to know the end state to set its start state
        if (state.endState == null) {
          throw ("IllegalState");
        }
        // block end states can only be associated to a single block start
        // state
        if (state.endState.startState != null) {
          throw ("IllegalState");
        }
        state.endState.startState = state;
      }
      if (state is PlusLoopbackState) {
        for (j = 0; j < state.transitions.length; j++) {
          target = state.transitions[j].target;
          if (target is PlusBlockStartState) {
            target.loopBackState = state;
          }
        }
      } else if (state is StarLoopbackState) {
        for (j = 0; j < state.transitions.length; j++) {
          target = state.transitions[j].target;
          if (target is StarLoopEntryState) {
            target.loopBackState = state;
          }
        }
      }
    }
  }

  readDecisions(atn) {
    var ndecisions = this.readInt();
    for (var i = 0; i < ndecisions; i++) {
      var s = this.readInt();
      var decState = atn.states[s];
      atn.decisionToState.push(decState);
      decState.decision = i;
    }
  }

  readLexerActions(atn) {
    if (atn.grammarType == ATNType.LEXER) {
      var count = this.readInt();
      atn.lexerActions = initArray(count, null);
      for (var i = 0; i < count; i++) {
        var actionType = this.readInt();
        var data1 = this.readInt();
        if (data1 == 0xFFFF) {
          data1 = -1;
        }
        var data2 = this.readInt();
        if (data2 == 0xFFFF) {
          data2 = -1;
        }
        var lexerAction = this.lexerActionFactory(actionType, data1, data2);
        atn.lexerActions[i] = lexerAction;
      }
    }
  }

  generateRuleBypassTransitions(atn) {
    var i;
    var count = atn.ruleToStartState.length;
    for (i = 0; i < count; i++) {
      atn.ruleToTokenType[i] = atn.maxTokenType + i + 1;
    }
    for (i = 0; i < count; i++) {
      this.generateRuleBypassTransition(atn, i);
    }
  }

  generateRuleBypassTransition(atn, idx) {
    var i, state;
    var bypassStart = new BasicBlockStartState();
    bypassStart.ruleIndex = idx;
    atn.addState(bypassStart);

    var bypassStop = new BlockEndState();
    bypassStop.ruleIndex = idx;
    atn.addState(bypassStop);

    bypassStart.endState = bypassStop;
    atn.defineDecisionState(bypassStart);

    bypassStop.startState = bypassStart;

    var excludeTransition = null;
    var endState = null;

    if (atn.ruleToStartState[idx].isPrecedenceRule) {
      // wrap from the beginning of the rule to the StarLoopEntryState
      endState = null;
      for (i = 0; i < atn.states.length; i++) {
        state = atn.states[i];
        if (this.stateIsEndStateFor(state, idx)) {
          endState = state;
          excludeTransition = state.loopBackState.transitions[0];
          break;
        }
      }
      if (excludeTransition == null) {
        throw ("Couldn't identify final state of the precedence rule prefix section.");
      }
    } else {
      endState = atn.ruleToStopState[idx];
    }

    // all non-excluded transitions that currently target end state need to
    // target blockEnd instead
    for (i = 0; i < atn.states.length; i++) {
      state = atn.states[i];
      for (var j = 0; j < state.transitions.length; j++) {
        var transition = state.transitions[j];
        if (transition == excludeTransition) {
          continue;
        }
        if (transition.target == endState) {
          transition.target = bypassStop;
        }
      }
    }

    // all transitions leaving the rule start state need to leave blockStart
    // instead
    var ruleToStartState = atn.ruleToStartState[idx];
    var count = ruleToStartState.transitions.length;
    while (count > 0) {
      bypassStart.addTransition(ruleToStartState.transitions[count - 1]);
      ruleToStartState.transitions = ruleToStartState.transitions.slice(-1);
    }
    // link the new states
    atn.ruleToStartState[idx].addTransition(new EpsilonTransition(bypassStart));
    bypassStop.addTransition(new EpsilonTransition(endState));

    var matchState = new BasicState();
    atn.addState(matchState);
    matchState.addTransition(
        new AtomTransition(bypassStop, atn.ruleToTokenType[idx]));
    bypassStart.addTransition(new EpsilonTransition(matchState));
  }

  stateIsEndStateFor(state, idx) {
    if (state.ruleIndex != idx) {
      return null;
    }
    if (!(state is StarLoopEntryState)) {
      return null;
    }
    var maybeLoopEndState =
        state.transitions[state.transitions.length - 1].target;
    if (!(maybeLoopEndState is LoopEndState)) {
      return null;
    }
    if (maybeLoopEndState.epsilonOnlyTransitions &&
        (maybeLoopEndState.transitions[0].target is RuleStopState)) {
      return state;
    } else {
      return null;
    }
  }

//
// Analyze the {@link StarLoopEntryState} states in the specified ATN to set
// the {@link StarLoopEntryState//isPrecedenceDecision} field to the
// correct value.
//
// @param atn The ATN.
//
  markPrecedenceDecisions(atn) {
    for (var i = 0; i < atn.states.length; i++) {
      var state = atn.states[i];
      if (!(state is StarLoopEntryState)) {
        continue;
      }
      // We analyze the ATN to determine if this ATN decision state is the
      // decision for the closure block that determines whether a
      // precedence rule should continue or complete.
      //
      if (atn.ruleToStartState[state.ruleIndex].isPrecedenceRule) {
        var maybeLoopEndState =
            state.transitions[state.transitions.length - 1].target;
        if (maybeLoopEndState is LoopEndState) {
          if (maybeLoopEndState.epsilonOnlyTransitions &&
              (maybeLoopEndState.transitions[0].target is RuleStopState)) {
            state.isPrecedenceDecision = true;
          }
        }
      }
    }
  }

  verifyATN(atn) {
    if (!this.deserializationOptions.verifyATN) {
      return;
    }
    // verify assumptions
    for (var i = 0; i < atn.states.length; i++) {
      var state = atn.states[i];
      if (state == null) {
        continue;
      }
      this.checkCondition(
          state.epsilonOnlyTransitions || state.transitions.length <= 1);
      if (state is PlusBlockStartState) {
        this.checkCondition(state.loopBackState != null);
      } else if (state is StarLoopEntryState) {
        this.checkCondition(state.loopBackState != null);
        this.checkCondition(state.transitions.length == 2);
        if (state.transitions[0].target is StarBlockStartState) {
          this.checkCondition(state.transitions[1].target is LoopEndState);
          this.checkCondition(!state.nonGreedy);
        } else if (state.transitions[0].target is LoopEndState) {
          this.checkCondition(
              state.transitions[1].target is StarBlockStartState);
          this.checkCondition(state.nonGreedy);
        } else {
          throw ("IllegalState");
        }
      } else if (state is StarLoopbackState) {
        this.checkCondition(state.transitions.length == 1);
        this.checkCondition(state.transitions[0].target is StarLoopEntryState);
      } else if (state is LoopEndState) {
        this.checkCondition(state.loopBackState != null);
      } else if (state is RuleStartState) {
        this.checkCondition(state.stopState != null);
      } else if (state is BlockStartState) {
        this.checkCondition(state.endState != null);
      } else if (state is BlockEndState) {
        this.checkCondition(state.startState != null);
      } else if (state is DecisionState) {
        this.checkCondition(
            state.transitions.length <= 1 || state.decision >= 0);
      } else {
        this.checkCondition(
            state.transitions.length <= 1 || (state is RuleStopState));
      }
    }
  }

  checkCondition(condition, {message = null}) {
    if (!condition) {
      if (message == null) {
        message = "IllegalState";
      }
      throw (message);
    }
  }

  readInt() {
    return this.data[this.pos++];
  }

  readInt32() {
    var low = this.readInt();
    var high = this.readInt();
    return low | (high << 16);
  }

  readLong() {
    var low = this.readInt32();
    var high = this.readInt32();
    return (low & 0x00000000FFFFFFFF) | (high << 32);
  }

  readUUID() {
    var bb = [];
    for (var i = 7; i >= 0; i--) {
      var int = this.readInt();
      /* jshint bitwise: false */
      bb[(2 * i) + 1] = int & 0xFF;
      bb[2 * i] = (int >> 8) & 0xFF;
    }
    return byteToHex[bb[0]] +
        byteToHex[bb[1]] +
        byteToHex[bb[2]] +
        byteToHex[bb[3]] +
        '-' +
        byteToHex[bb[4]] +
        byteToHex[bb[5]] +
        '-' +
        byteToHex[bb[6]] +
        byteToHex[bb[7]] +
        '-' +
        byteToHex[bb[8]] +
        byteToHex[bb[9]] +
        '-' +
        byteToHex[bb[10]] +
        byteToHex[bb[11]] +
        byteToHex[bb[12]] +
        byteToHex[bb[13]] +
        byteToHex[bb[14]] +
        byteToHex[bb[15]];
  }

  edgeFactory(atn, type, src, trg, arg1, arg2, arg3, sets) {
    var target = atn.states[trg];
    switch (type) {
      case Transition.EPSILON:
        return new EpsilonTransition(target);
      case Transition.RANGE:
        return arg3 != 0
            ? new RangeTransition(target, Token.EOF, arg2)
            : new RangeTransition(target, arg1, arg2);
      case Transition.RULE:
        return new RuleTransition(atn.states[arg1], arg2, arg3, target);
      case Transition.PREDICATE:
        return new PredicateTransition(target, arg1, arg2, arg3 != 0);
      case Transition.PRECEDENCE:
        return new PrecedencePredicateTransition(target, arg1);
      case Transition.ATOM:
        return arg3 != 0
            ? new AtomTransition(target, Token.EOF)
            : new AtomTransition(target, arg1);
      case Transition.ACTION:
        return new ActionTransition(target, arg1, arg2, arg3 != 0);
      case Transition.SET:
        return new SetTransition(target, sets[arg1]);
      case Transition.NOT_SET:
        return new NotSetTransition(target, sets[arg1]);
      case Transition.WILDCARD:
        return new WildcardTransition(target);
      default:
        throw "The specified transition type: " + type + " is not valid.";
    }
  }

  stateFactory(type, ruleIndex) {
    if (this.stateFactories == null) {
      var sf = [];
      sf[ATNState.INVALID_TYPE] = null;
      sf[ATNState.BASIC] = () {
        return new BasicState();
      };
      sf[ATNState.RULE_START] = () {
        return new RuleStartState();
      };
      sf[ATNState.BLOCK_START] = () {
        return new BasicBlockStartState();
      };
      sf[ATNState.PLUS_BLOCK_START] = () {
        return new PlusBlockStartState();
      };
      sf[ATNState.STAR_BLOCK_START] = () {
        return new StarBlockStartState();
      };
      sf[ATNState.TOKEN_START] = () {
        return new TokensStartState();
      };
      sf[ATNState.RULE_STOP] = () {
        return new RuleStopState();
      };
      sf[ATNState.BLOCK_END] = () {
        return new BlockEndState();
      };
      sf[ATNState.STAR_LOOP_BACK] = () {
        return new StarLoopbackState();
      };
      sf[ATNState.STAR_LOOP_ENTRY] = () {
        return new StarLoopEntryState();
      };
      sf[ATNState.PLUS_LOOP_BACK] = () {
        return new PlusLoopbackState();
      };
      sf[ATNState.LOOP_END] = () {
        return new LoopEndState();
      };
      this.stateFactories = sf;
    }
    if (type > this.stateFactories.length ||
        this.stateFactories[type] == null) {
      throw ("The specified state type " + type + " is not valid.");
    } else {
      var s = this.stateFactories[type]();
      if (s != null) {
        s.ruleIndex = ruleIndex;
        return s;
      }
    }
  }

  lexerActionFactory(type, data1, data2) {
    if (this.actionFactories == null) {
      var af = [];
      af[LexerActionType.CHANNEL.index] = (data1, data2) {
        return new LexerChannelAction(data1);
      };
      af[LexerActionType.CUSTOM.index] = (data1, data2) {
        return new LexerCustomAction(data1, data2);
      };
      af[LexerActionType.MODE.index] = (data1, data2) {
        return new LexerModeAction(data1);
      };
      af[LexerActionType.MORE.index] = (data1, data2) {
        return LexerMoreAction.INSTANCE;
      };
      af[LexerActionType.POP_MODE.index] = (data1, data2) {
        return LexerPopModeAction.INSTANCE;
      };
      af[LexerActionType.PUSH_MODE.index] = (data1, data2) {
        return new LexerPushModeAction(data1);
      };
      af[LexerActionType.SKIP.index] = (data1, data2) {
        return LexerSkipAction.INSTANCE;
      };
      af[LexerActionType.TYPE.index] = (data1, data2) {
        return new LexerTypeAction(data1);
      };
      this.actionFactories = af;
    }
    if (type > this.actionFactories.length ||
        this.actionFactories[type] == null) {
      throw ("The specified lexer action type " + type + " is not valid.");
    } else {
      return this.actionFactories[type](data1, data2);
    }
  }
}

createByteToHex() {
  var bth = [];
  for (var i = 0; i < 256; i++) {
    bth[i] = (i + 0x100).toString(16).substr(1).toUpperCase();
  }
  return bth;
}

var byteToHex = createByteToHex();
