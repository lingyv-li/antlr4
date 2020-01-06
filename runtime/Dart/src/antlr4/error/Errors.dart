/* Copyright (c) 2012-2017 The ANTLR Project. All rights reserved.
 * Use of this file is governed by the BSD 3-clause license that
 * can be found in the LICENSE.txt file in the project root.
 */

// The root of the ANTLR exception hierarchy. In general, ANTLR tracks just
//  3 kinds of errors: prediction errors, failed predicate errors, and
//  mismatched input errors. In each case, the parser knows where it is
//  in the input, where it is in the ATN, the rule invocation stack,
//  and what kind of problem occurred.
import 'package:meta/meta.dart';
import '../atn/SemanticContext.dart';
import '../atn/Transition.dart';

class RecognitionException extends Error {
  String message;
  var recognizer;
  var input;
  var ctx;
  var offendingToken;
  var offendingState;
  RecognitionException({@required message,@required  recognizer,@required  input,@required  ctx}) {
    this.stackTrace;
    this.message = message;
    this.recognizer = recognizer;
    this.input = input;
    this.ctx = ctx;
    // The current {@link Token} when an error occurred. Since not all streams
    // support accessing symbols by index, we have to track the {@link Token}
    // instance itself.
    this.offendingToken = null;
    // Get the ATN state number the parser was in at the time the error
    // occurred. For {@link NoViableAltException} and
    // {@link LexerNoViableAltException} exceptions, this is the
    // {@link DecisionState} number. For others, it is the state whose outgoing
    // edge we couldn't match.
    this.offendingState = -1;
    if (this.recognizer != null) {
      this.offendingState = this.recognizer.state;
    }
  }

// <p>If the state number is not known, this method returns -1.</p>

//
// Gets the set of input symbols which could potentially follow the
// previously matched symbol at the time this exception was thrown.
//
// <p>If the set of expected tokens is not known and could not be computed,
// this method returns {@code null}.</p>
//
// @return The set of token types that could potentially follow the current
// state in the ATN, or {@code null} if the information is not available.
// /
  getExpectedTokens() {
    if (this.recognizer != null) {
      return this
          .recognizer
          .atn
          .getExpectedTokens(this.offendingState, this.ctx);
    } else {
      return null;
    }
  }

  toString() {
    return this.message;
  }
}

final a = {"message": 2};

class LexerNoViableAltException extends RecognitionException {
  var startIndex;
  var deadEndConfigs;
  LexerNoViableAltException(lexer, input, startIndex, deadEndConfigs)
  : super(message: "", recognizer: lexer, input: input, ctx: null) {
    this.startIndex = startIndex;
    this.deadEndConfigs = deadEndConfigs;
  }

  toString() {
    var symbol = "";
    if (this.startIndex >= 0 && this.startIndex < this.input.size) {
      symbol = this.input.getText(this.startIndex, this.startIndex);
    }
    return "LexerNoViableAltException" + symbol;
  }
}

// Indicates that the parser could not decide which of two or more paths
// to take based upon the remaining input. It tracks the starting token
// of the offending input and also knows where the parser was
// in the various paths when the error. Reported by reportNoViableAlternative()
//
class NoViableAltException extends RecognitionException {
  var deadEndConfigs;
  var startToken;
  NoViableAltException(
      recognizer, input, startToken, offendingToken, deadEndConfigs, ctx)
      : super(
          message: "",
          recognizer: recognizer,
          input: input,
          ctx: ctx
        ) {
    ctx = ctx || recognizer._ctx;
    offendingToken = offendingToken || recognizer.getCurrentToken();
    startToken = startToken || recognizer.getCurrentToken();
    input = input || recognizer.getInputStream();

    // Which configurations did we try at input.index() that couldn't match
    // input.LT(1)?//
    this.deadEndConfigs = deadEndConfigs;
    // The token object at the start index; the input stream might
    // not be buffering tokens so get a reference to it. (At the
    // time the error occurred, of course the stream needs to keep a
    // buffer all of the tokens but later we might not have access to those.)
    this.startToken = startToken;
    this.offendingToken = offendingToken;
  }
}

// This signifies any kind of mismatched input exceptions such as
// when the current input does not match the expected token.
//
class InputMismatchException extends RecognitionException {
  InputMismatchException(recognizer)
      : super(
          message: "",
          recognizer: recognizer,
          input: recognizer.getInputStream(),
          ctx: recognizer._ctx
        ) {
    this.offendingToken = recognizer.getCurrentToken();
  }
}

// A semantic predicate failed during validation. Validation of predicates
// occurs when normally parsing the alternative just like matching a token.
// Disambiguating predicate evaluation occurs when we test a predicate during
// prediction.

class FailedPredicateException extends RecognitionException {
  int ruleIndex;
  int predicateIndex;
  Predicate predicate;
  FailedPredicateException(recognizer, predicate, message)
      : super(
          message: this.formatMessage(predicate, message || null),
          recognizer: recognizer,
          input: recognizer.getInputStream(),
          ctx: recognizer._ctx
        ) {
    var s = recognizer._interp.atn.states[recognizer.state];
    var trans = s.transitions[0];
    if (trans is PredicateTransition) {
      this.ruleIndex = trans.ruleIndex;
      this.predicateIndex = trans.predIndex;
    } else {
      this.ruleIndex = 0;
      this.predicateIndex = 0;
    }
    this.predicate = predicate;
    this.offendingToken = recognizer.getCurrentToken();
  }

  formatMessage(predicate, message) {
    if (message != null) {
      return message;
    } else {
      return "failed predicate: {" + predicate + "}?";
    }
  }
}

class ParseCancellationException extends Error {
  ParseCancellationException(): super() {
    this.stackTrace;
  }
}
