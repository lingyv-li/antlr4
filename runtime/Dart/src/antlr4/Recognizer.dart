//
/* Copyright (c) 2012-2017 The ANTLR Project. All rights reserved.
 * Use of this file is governed by the BSD 3-clause license that
 * can be found in the LICENSE.txt file in the project root.
 */
//
import 'dart:developer';

import './Token.dart';
import './error/ErrorListener.dart';

class Recognizer {
  var _listeners = [ConsoleErrorListener.INSTANCE];
  var _interp = null;
  var _stateNumber = -1;

  static final tokenTypeMapCache = {};
  static final ruleIndexMapCache = {};

  var ruleNames = []; // TODO what is this

  checkVersion(toolVersion) {
    var runtimeVersion = "4.7.2";
    if (runtimeVersion != toolVersion) {
      log("ANTLR runtime and generated code versions disagree: $runtimeVersion!=$toolVersion");
    }
  }

  addErrorListener(listener) {
    this._listeners.add(listener);
  }

  removeErrorListeners() {
    this._listeners = [];
  }

  getTokenTypeMap() {
    var tokenNames = this.getTokenNames();
    if (tokenNames == null) {
      throw ("The current recognizer does not provide a list of token names.");
    }
    var result = tokenTypeMapCache[tokenNames];
    if (result == null) {
      result = tokenNames.reduce((o, k, i) {
        o[k] = i;
      });
      result.EOF = Token.EOF;
      tokenTypeMapCache[tokenNames] = result;
    }
    return result;
  }

// Get a map from rule names to rule indexes.
//
// <p>Used for XPath and tree pattern compilation.</p>
//
  getRuleIndexMap() {
    var ruleNames = this.ruleNames;
    if (ruleNames == null) {
      throw ("The current recognizer does not provide a list of rule names.");
    }
    var result = ruleIndexMapCache[ruleNames];
    if (result == null) {
      result = ruleNames.reduce((o, k, i) {
        o[k] = i;
      });
      ruleIndexMapCache[ruleNames] = result;
    }
    return result;
  }

  getTokenType(tokenName) {
    var ttype = this.getTokenTypeMap()[tokenName];
    if (ttype != null) {
      return ttype;
    } else {
      return Token.INVALID_TYPE;
    }
  }

// What is the error header, normally line/character position information?//
  getErrorHeader(e) {
    var line = e.getOffendingToken().line;
    var column = e.getOffendingToken().column;
    return "line " + line + ":" + column;
  }

// How should a token be displayed in an error message? The default
//  is to display just the text, but during development you might
//  want to have a lot of information spit out.  Override in that case
//  to use t.toString() (which, for CommonToken, dumps everything about
//  the token). This is better than forcing you to override a method in
//  your token objects because you don't have to go modify your lexer
//  so that it creates a new Java type.
//
// @deprecated This method is not called by the ANTLR 4 Runtime. Specific
// implementations of {@link ANTLRErrorStrategy} may provide a similar
// feature when necessary. For example, see
// {@link DefaultErrorStrategy//getTokenErrorDisplay}.
//
  getTokenErrorDisplay(t) {
    if (t == null) {
      return "<no token>";
    }
    var s = t.text;
    if (s == null) {
      if (t.type == Token.EOF) {
        s = "<EOF>";
      } else {
        s = "<" + t.type + ">";
      }
    }
    s = s.replace("\n", r"\n").replace("\r", r"\r").replace("\t", r"\t");
    return "'" + s + "'";
  }

  getErrorListenerDispatch() {
    return new ProxyErrorListener(this._listeners);
  }

// subclass needs to override these if there are sempreds or actions
// that the ATN interp needs to execute
  sempred(localctx, ruleIndex, actionIndex) {
    return true;
  }

  precpred(localctx, precedence) {
    return true;
  }

//Indicate that the recognizer has changed internal state that is
//consistent with the ATN state passed in.  This way we always know
//where we are in the ATN as the parser goes along. The rule
//context objects form a stack that lets us see the stack of
//invoking rules. Combine this and we have complete ATN
//configuration information.

  get state {
    return this._stateNumber;
  }

  set state(state) {
    this._stateNumber = state;
  }
}
