/* Copyright (c) 2012-2017 The ANTLR Project. All rights reserved.
 * Use of this file is governed by the BSD 3-clause license that
 * can be found in the LICENSE.txt file in the project root.
 */

import '../../atn/atn.dart';
import '../../input_stream.dart';
import '../../interval_set.dart';
import '../../lexer.dart';
import '../../parser.dart';
import '../../parser_rule_context.dart';
import '../../recognizer.dart';
import '../../rule_context.dart';
import '../../token.dart';
import '../../token_stream.dart';
import '../../util/utils.dart';

/** The root of the ANTLR exception hierarchy. In general, ANTLR tracks just
 *  3 kinds of errors: prediction errors, failed predicate errors, and
 *  mismatched input errors. In each case, the parser knows where it is
 *  in the input, where it is in the ATN, the rule invocation stack,
 *  and what kind of problem occurred.
 */
class RecognitionException extends StateError {
  /**
   * Gets the {@link Recognizer} where this exception occurred.
   *
   * <p>If the recognizer is not available, this method returns {@code null}.</p>
   *
   * @return The recognizer where this exception occurred, or {@code null} if
   * the recognizer is not available.
   */
  final Recognizer recognizer;

  /**
   * Gets the {@link RuleContext} at the time this exception was thrown.
   *
   * <p>If the context is not available, this method returns {@code null}.</p>
   *
   * @return The {@link RuleContext} at the time this exception was thrown.
   * If the context is not available, this method returns {@code null}.
   */
  final RuleContext ctx;

  /**
   * Gets the input stream which is the symbol source for the recognizer where
   * this exception was thrown.
   *
   * <p>If the input stream is not available, this method returns {@code null}.</p>
   *
   * @return The input stream which is the symbol source for the recognizer
   * where this exception was thrown, or {@code null} if the stream is not
   * available.
   */
  final IntStream inputStream;

  /**
   * The current {@link Token} when an error occurred. Since not all streams
   * support accessing symbols by index, we have to track the {@link Token}
   * instance itself.
   */
  Token offendingToken;

  /**
   * Get the ATN state number the parser was in at the time the error
   * occurred. For {@link NoViableAltException} and
   * {@link LexerNoViableAltException} exceptions, this is the
   * {@link DecisionState} number. For others, it is the state whose outgoing
   * edge we couldn't match.
   *
   * <p>If the state number is not known, this method returns -1.</p>
   */
  int offendingState = -1;

  RecognitionException(this.recognizer, this.inputStream, this.ctx,
      [String message = ""])
      : super(message) {
    if (recognizer != null) this.offendingState = recognizer.state;
  }

  /**
   * Gets the set of input symbols which could potentially follow the
   * previously matched symbol at the time this exception was thrown.
   *
   * <p>If the set of expected tokens is not known and could not be computed,
   * this method returns {@code null}.</p>
   *
   * @return The set of token types that could potentially follow the current
   * state in the ATN, or {@code null} if the information is not available.
   */
  IntervalSet get expectedTokens {
    if (recognizer != null) {
      return recognizer.getATN().getExpectedTokens(offendingState, ctx);
    }
    return null;
  }
}

class LexerNoViableAltException extends RecognitionException {
  /** Matching attempted at what input index? */
  final int startIndex;

  /** Which configurations did we try at input.index() that couldn't match input.LA(1)? */
  final ATNConfigSet deadEndConfigs;

  LexerNoViableAltException(
      Lexer lexer, CharStream input, this.startIndex, this.deadEndConfigs)
      : super(lexer, input, null);

  int getStartIndex() {
    return startIndex;
  }

  ATNConfigSet getDeadEndConfigs() {
    return deadEndConfigs;
  }

  CharStream get inputStream {
    return super.inputStream;
  }

  String toString() {
    String symbol = "";
    if (startIndex >= 0 && startIndex < inputStream.size) {
      symbol = inputStream.getText(Interval.of(startIndex, startIndex));
      symbol = escapeWhitespace(symbol);
    }

    return "${LexerNoViableAltException}('${symbol}')";
  }
}

/** Indicates that the parser could not decide which of two or more paths
 *  to take based upon the remaining input. It tracks the starting token
 *  of the offending input and also knows where the parser was
 *  in the various paths when the error. Reported by reportNoViableAlternative()
 */
class NoViableAltException extends RecognitionException {
  /** Which configurations did we try at input.index() that couldn't match input.LT(1)? */

  final ATNConfigSet deadEndConfigs;

  /** The token object at the start index; the input stream might
   * 	not be buffering tokens so get a reference to it. (At the
   *  time the error occurred, of course the stream needs to keep a
   *  buffer all of the tokens but later we might not have access to those.)
   */

  final Token startToken;

//   NoViableAltException(Parser recognizer) { // LL(1) error
//    this(recognizer,
//        recognizer.inputStream,
//        recognizer.getCurrentToken(),
//        recognizer.getCurrentToken(),
//        null,
//        recognizer._ctx);
//  }

  NoViableAltException._(Parser recognizer, TokenStream input, this.startToken,
      Token offendingToken, this.deadEndConfigs, ParserRuleContext ctx)
      : super(recognizer, input, ctx) {
    this.offendingToken = offendingToken;
  }

  NoViableAltException(Parser recognizer,
      [TokenStream input,
      Token startToken,
      Token offendingToken,
      ATNConfigSet deadEndConfigs,
      ParserRuleContext ctx])
      : this._(
            recognizer,
            input ?? recognizer.inputStream,
            startToken ?? recognizer.getCurrentToken(),
            offendingToken ?? recognizer.getCurrentToken(),
            deadEndConfigs ?? null,
            ctx ?? recognizer.getContext());

  Token getStartToken() {
    return startToken;
  }

  ATNConfigSet getDeadEndConfigs() {
    return deadEndConfigs;
  }
}

/** This signifies any kind of mismatched input exceptions such as
 *  when the current input does not match the expected token.
 */
class InputMismatchException extends RecognitionException {
  InputMismatchException(Parser recognizer,
      [int state = -1, ParserRuleContext ctx])
      : super(recognizer, recognizer.inputStream,
            ctx ?? recognizer.getContext()) {
    this.offendingState = state;
    this.offendingToken = offendingToken;
  }
}

/** A semantic predicate failed during validation.  Validation of predicates
 *  occurs when normally parsing the alternative just like matching a token.
 *  Disambiguating predicate evaluation occurs when we test a predicate during
 *  prediction.
 */
class FailedPredicateException extends RecognitionException {
  int ruleIndex;
  int predicateIndex;
  final String predicate;

  FailedPredicateException(Parser recognizer,
      [this.predicate = null, String message = null])
      : super(recognizer, recognizer.inputStream, recognizer.getContext(),
            formatMessage(predicate, message)) {
    ATNState s = recognizer.getInterpreter().atn.states[recognizer.state];

    AbstractPredicateTransition trans = s.transition(0);
    if (trans is PredicateTransition) {
      this.ruleIndex = (trans as PredicateTransition).ruleIndex;
      this.predicateIndex = (trans as PredicateTransition).predIndex;
    } else {
      this.ruleIndex = 0;
      this.predicateIndex = 0;
    }

    this.offendingToken = recognizer.getCurrentToken();
  }

  int getRuleIndex() {
    return ruleIndex;
  }

  int getPredIndex() {
    return predicateIndex;
  }

  String getPredicate() {
    return predicate;
  }

  static String formatMessage(String predicate, String message) {
    if (message != null) {
      return message;
    }

    return "failed predicate: {$predicate}?";
  }
}
