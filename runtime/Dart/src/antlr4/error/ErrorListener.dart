//
/* Copyright (c) 2012-2017 The ANTLR Project. All rights reserved.
 * Use of this file is governed by the BSD 3-clause license that
 * can be found in the LICENSE.txt file in the project root.
 */

// Provides an empty default implementation of {@link ANTLRErrorListener}. The
// default implementation of each method does nothing, but can be overridden as
// necessary.

import 'dart:developer';
import 'package:logging/logging.dart';

class ErrorListener {
  static syntaxError(recognizer, offendingSymbol, line, column, msg, e) {}

  static reportAmbiguity(
      recognizer, dfa, startIndex, stopIndex, exact, ambigAlts, configs) {}

  static reportAttemptingFullContext(
      recognizer, dfa, startIndex, stopIndex, conflictingAlts, configs) {}

  static reportContextSensitivity(
      recognizer, dfa, startIndex, stopIndex, prediction, configs) {}
}

class ConsoleErrorListener extends ErrorListener {
  ///
  /// Provides a default instance of {@link ConsoleErrorListener}.
  ///
  static final INSTANCE = ConsoleErrorListener();

  ///
  /// {@inheritDoc}
  ///
  /// <p>
  /// This implementation prints messages to {@link System//err} containing the
  /// values of {@code line}, {@code charPositionInLine}, and {@code msg} using
  /// the following format.</p>
  ///
  /// <pre>
  /// line <em>line</em>:<em>charPositionInLine</em> <em>msg</em>
  /// </pre>
  ///
  syntaxError(recognizer, offendingSymbol, line, column, msg, e) {
    log("line " + line + ":" + column + " " + msg, level: Level.SEVERE.value);
  }
}

class ProxyErrorListener extends ErrorListener {
  var delegates;
  ProxyErrorListener(delegates) {
    if (delegates == null) {
      throw "delegates";
    }
    this.delegates = delegates;
  }

  syntaxError(recognizer, offendingSymbol, line, column, msg, e) {
    this.delegates.map((d) {
      d.syntaxError(recognizer, offendingSymbol, line, column, msg, e);
    });
  }

  reportAmbiguity(
      recognizer, dfa, startIndex, stopIndex, exact, ambigAlts, configs) {
    this.delegates.map((d) {
      d.reportAmbiguity(
          recognizer, dfa, startIndex, stopIndex, exact, ambigAlts, configs);
    });
  }

  reportAttemptingFullContext(
      recognizer, dfa, startIndex, stopIndex, conflictingAlts, configs) {
    this.delegates.map((d) {
      d.reportAttemptingFullContext(
          recognizer, dfa, startIndex, stopIndex, conflictingAlts, configs);
    });
  }

  reportContextSensitivity(
      recognizer, dfa, startIndex, stopIndex, prediction, configs) {
    this.delegates.map((d) {
      d.reportContextSensitivity(
          recognizer, dfa, startIndex, stopIndex, prediction, configs);
    });
  }
}
