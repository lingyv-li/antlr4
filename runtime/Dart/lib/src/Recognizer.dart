//
/* Copyright (c) 2012-2017 The ANTLR Project. All rights reserved.
 * Use of this file is governed by the BSD 3-clause license that
 * can be found in the LICENSE.txt file in the project root.
 */
//
import 'token.dart';
import 'error/error_listener.dart';
import 'common_token_factory.dart';
import 'int_stream.dart';
import 'rule_context.dart';
import 'utils.dart';
import 'Vocabulary.dart';
import 'atn/atn.dart';
import 'atn/atn_simulator.dart';
import 'atn/info.dart';
import 'error/errors.dart';

abstract class Recognizer<ATNInterpreter extends ATNSimulator> {
  static const EOF = -1;

  static final Map<Vocabulary, Map<String, int>> tokenTypeMapCache = {};
  static final Map<List<String>, Map<String, int>> ruleIndexMapCache = {};
  List<ErrorListener> _listeners = [ConsoleErrorListener.INSTANCE];
  ATNInterpreter interp;
  int _stateNumber = -1;

  List<String> getRuleNames();

  /**
   * Get the vocabulary used by the recognizer.
   *
   * @return A {@link Vocabulary} instance providing information about the
   * vocabulary used by the grammar.
   */
  Vocabulary getVocabulary();

  /**
   * Get a map from token names to token types.
   *
   * <p>Used for XPath and tree pattern compilation.</p>
   */
  Map<String, int> getTokenTypeMap() {
    Vocabulary vocabulary = getVocabulary();

    Map<String, int> result = tokenTypeMapCache[vocabulary];
    if (result == null) {
      result = {};
      for (int i = 0; i <= getATN().maxTokenType; i++) {
        String literalName = vocabulary.getLiteralName(i);
        if (literalName != null) {
          result[literalName] = i;
        }

        String symbolicName = vocabulary.getSymbolicName(i);
        if (symbolicName != null) {
          result[symbolicName] = i;
        }
      }

      result["EOF"] = Token.EOF;
      result = Map.unmodifiable(result);
      tokenTypeMapCache[vocabulary] = result;
    }

    return result;
  }

  /**
   * Get a map from rule names to rule indexes.
   *
   * <p>Used for XPath and tree pattern compilation.</p>
   */
  Map<String, int> getRuleIndexMap() {
    final ruleNames = getRuleNames();
    if (ruleNames == null) {
      throw UnsupportedError(
          "The current recognizer does not provide a list of rule names.");
    }

    var result = ruleIndexMapCache[ruleNames];
    if (result == null) {
      result = Map.unmodifiable(toMap(ruleNames));
      ruleIndexMapCache[ruleNames] = result;
    }

    return result;
  }

  int getTokenType(String tokenName) {
    final ttype = getTokenTypeMap()[tokenName];
    if (ttype != null) return ttype;
    return Token.INVALID_TYPE;
  }

  /**
   * If this recognizer was generated, it will have a serialized ATN
   * representation of the grammar.
   *
   * <p>For interpreters, we don't know their serialized ATN despite having
   * created the interpreter from it.</p>
   */
  String getSerializedATN() {
    throw new UnsupportedError("there is no serialized ATN");
  }

  /** For debugging and other purposes, might want the grammar name.
   *  Have ANTLR generate an implementation for this method.
   */
  String getGrammarFileName();

  /**
   * Get the {@link ATN} used by the recognizer for prediction.
   *
   * @return The {@link ATN} used by the recognizer for prediction.
   */
  ATN getATN();

  /**
   * Get the ATN interpreter used by the recognizer for prediction.
   *
   * @return The ATN interpreter used by the recognizer for prediction.
   */
  ATNInterpreter getInterpreter() {
    return interp;
  }

  /** If profiling during the parse/lex, this will return DecisionInfo records
   *  for each decision in recognizer in a ParseInfo object.
   *
   * @since 4.3
   */
  ParseInfo getParseInfo() {
    return null;
  }

  /**
   * Set the ATN interpreter used by the recognizer for prediction.
   *
   * @param interpreter The ATN interpreter used by the recognizer for
   * prediction.
   */
  void setInterpreter(ATNInterpreter interpreter) {
    interp = interpreter;
  }

  /** What is the error header, normally line/character position information? */
  String getErrorHeader(RecognitionException e) {
    int line = e.offendingToken.line;
    int charPositionInLine = e.offendingToken.charPositionInLine;
    return "line $line:$charPositionInLine";
  }

  /**
   * @exception NullPointerException if {@code listener} is {@code null}.
   */
  void addErrorListener(ErrorListener listener) {
    if (listener == null) {
      throw new ArgumentError.notNull("listener");
    }

    _listeners.add(listener);
  }

  void removeErrorListener(ErrorListener listener) {
    _listeners.remove(listener);
  }

  void removeErrorListeners() {
    _listeners.clear();
  }

  List<ErrorListener> getErrorListeners() {
    return _listeners;
  }

  ErrorListener getErrorListenerDispatch() {
    return new ProxyErrorListener(getErrorListeners());
  }

  // subclass needs to override these if there are sempreds or actions
  // that the ATN interp needs to execute
  bool sempred(RuleContext _localctx, int ruleIndex, int actionIndex) {
    return true;
  }

  bool precpred(RuleContext localctx, int precedence) {
    return true;
  }

  void action(RuleContext _localctx, int ruleIndex, int actionIndex) {}

  int get state {
    return _stateNumber;
  }

  /** Indicate that the recognizer has changed internal state that is
   *  consistent with the ATN state passed in.  This way we always know
   *  where we are in the ATN as the parser goes along. The rule
   *  context objects form a stack that lets us see the stack of
   *  invoking rules. Combine this and we have complete ATN
   *  configuration information.
   */
  void set state(int atnState) {
//		System.err.println("setState "+atnState);
    _stateNumber = atnState;
//		if ( traceATNStates ) _ctx.trace(atnState);
  }

  IntStream get inputStream;

  void setInputStream(IntStream input);

  TokenFactory getTokenFactory();

  void setTokenFactory(TokenFactory input);
}
