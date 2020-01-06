//
/* Copyright (c) 2012-2017 The ANTLR Project. All rights reserved.
 * Use of this file is governed by the BSD 3-clause license that
 * can be found in the LICENSE.txt file in the project root.
 */
//

//
// This implementation of {@link ANTLRErrorListener} can be used to identify
// certain potential correctness and performance problems in grammars. "Reports"
// are made by calling {@link Parser//notifyErrorListeners} with the appropriate
// message.
//
// <ul>
// <li><b>Ambiguities</b>: These are cases where more than one path through the
// grammar can match the input.</li>
// <li><b>Weak context sensitivity</b>: These are cases where full-context
// prediction resolved an SLL conflict to a unique alternative which equaled the
// minimum alternative of the SLL conflict.</li>
// <li><b>Strong (forced) context sensitivity</b>: These are cases where the
// full-context prediction resolved an SLL conflict to a unique alternative,
// <em>and</em> the minimum alternative of the SLL conflict was found to not be
// a truly viable alternative. Two-stage parsing cannot be used for inputs where
// this situation occurs.</li>
// </ul>

import '../IntervalSet.dart';
import '../Recognizer.dart';
import 'ErrorListener.dart';

class DiagnosticErrorListener extends ErrorListener {
  // whether all ambiguities or only exact ambiguities are reported.
  final bool exactOnly;
  DiagnosticErrorListener({this.exactOnly = true});

  reportAmbiguity(
      recognizer, dfa, startIndex, stopIndex, exact, ambigAlts, configs) {
    if (this.exactOnly && !exact) {
      return;
    }
    var msg = "reportAmbiguity d=" +
        this.getDecisionDescription(recognizer, dfa) +
        ": ambigAlts=" +
        this.getConflictingAlts(ambigAlts, configs) +
        ", input='" +
        recognizer
            .getTokenStream()
            .getText(new Interval(startIndex, stopIndex)) +
        "'";
    recognizer.notifyErrorListeners(msg);
  }

  reportAttemptingFullContext(
      recognizer, dfa, startIndex, stopIndex, conflictingAlts, configs) {
    var msg = "reportAttemptingFullContext d=" +
        this.getDecisionDescription(recognizer, dfa) +
        ", input='" +
        recognizer
            .getTokenStream()
            .getText(new Interval(startIndex, stopIndex)) +
        "'";
    recognizer.notifyErrorListeners(msg);
  }

  reportContextSensitivity(
      recognizer, dfa, startIndex, stopIndex, prediction, configs) {
    var msg = "reportContextSensitivity d=" +
        this.getDecisionDescription(recognizer, dfa) +
        ", input='" +
        recognizer
            .getTokenStream()
            .getText(new Interval(startIndex, stopIndex)) +
        "'";
    recognizer.notifyErrorListeners(msg);
  }

  getDecisionDescription(Recognizer recognizer, dfa) {
    final decision = dfa.decision;
    final ruleIndex = dfa.atnStartState.ruleIndex;

    final ruleNames = recognizer.ruleNames;
    if (ruleIndex < 0 || ruleIndex >= ruleNames.length) {
      return "" + decision;
    }
    var ruleName = ruleNames[ruleIndex] || null;
    if (ruleName == null || ruleName.length == 0) {
      return "" + decision;
    }
    return "" + decision + " (" + ruleName + ")";
  }

//
// Computes the set of conflicting or ambiguous alternatives from a
// configuration set, if that information was not already provided by the
// parser.
//
// @param reportedAlts The set of conflicting or ambiguous alternatives, as
// reported by the parser.
// @param configs The conflicting or ambiguous configuration set.
// @return Returns {@code reportedAlts} if it is not {@code null}, otherwise
// returns the set of alternatives represented in {@code configs}.
//
  getConflictingAlts(reportedAlts, configs) {
    if (reportedAlts != null) {
      return reportedAlts;
    }
    var result = new BitSet();
    for (var i = 0; i < configs.items.length; i++) {
      result.add(configs.items[i].alt);
    }
    return "{" + result.values().join(", ") + "}";
  }
}
