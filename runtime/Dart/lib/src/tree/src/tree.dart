/* Copyright (c) 2012-2017 The ANTLR Project. All rights reserved.
 * Use of this file is governed by the BSD 3-clause license that
 * can be found in the LICENSE.txt file in the project root.
 */

import 'dart:developer';

import '../../interval_set.dart';
import '../../parser.dart';
import '../../parser_rule_context.dart';
import '../../rule_context.dart';
import '../../token.dart';

/// The basic notion of a tree has a parent, a payload, and a list of children.
///  It is the most abstract interface for all the trees used by ANTLR.
abstract class Tree {
  Tree getParent();

  dynamic getPayload();

  Tree getChild(int i);

//  Tree getChild(int i);

  int getChildCount();

  String toStringTree();
}

abstract class SyntaxTree extends Tree {
  /// Return an {@link Interval} indicating the index in the
  /// {@link TokenStream} of the first and last token associated with this
  /// subtree. If this node is a leaf, then the interval represents a single
  /// token and has interval i..i for token index i.
  ///
  /// <p>An interval of i..i-1 indicates an empty interval at position
  /// i in the input stream, where 0 &lt;= i &lt;= the size of the input
  /// token stream.  Currently, the code base can only have i=0..n-1 but
  /// in concept one could have an empty interval after EOF. </p>
  ///
  /// <p>If source interval is unknown, this returns {@link Interval#INVALID}.</p>
  ///
  /// <p>As a weird special case, the source interval for rules matched after
  /// EOF is unspecified.</p>
  Interval getSourceInterval();
}

abstract class ParseTree extends SyntaxTree {
  // the following methods narrow the return type; they are not additional methods
  ParseTree getParent();

  ParseTree getChild(int i);

  /// Set the parent for this node.
  ///
  ///  This is not backward compatible as it changes
  ///  the interface but no one was able to create custom
  ///  nodes anyway so I'm adding as it improves internal
  ///  code quality.
  ///
  ///  One could argue for a restructuring of
  ///  the class/interface hierarchy so that
  ///  setParent, addChild are moved up to Tree
  ///  but that's a major change. So I'll do the
  ///  minimal change, which is to add this method.
  ///
  ///  @since 4.7
  void setParent(RuleContext parent);

  /// The {@link ParseTreeVisitor} needs a double dispatch method. */
  T accept<T>(ParseTreeVisitor<T> visitor);

  /// Return the combined text of all leaf nodes. Does not get any
  ///  off-channel tokens (if any) so won't return whitespace and
  ///  comments if they are sent to parser on hidden channel.
  String getText();

  /// Specialize toStringTree so that it can print out more information
  /// 	based upon the parser.
  String toStringTree({Parser parser});
}

abstract class RuleNode extends ParseTree {
  RuleContext get ruleContext;
}

abstract class TerminalNode extends ParseTree {
  Token get symbol;
}

abstract class ErrorNode extends TerminalNode {}

abstract class ParseTreeVisitor<T> {
  /**
   * {@inheritDoc}
   *
   * <p>The default implementation calls {@link ParseTree#accept} on the
   * specified tree.</p>
   */
  visit(ParseTree tree) {
    return tree.accept(this);
  }

  /**
   * {@inheritDoc}
   *
   * <p>The default implementation initializes the aggregate result to
   * {@link #defaultResult defaultResult()}. Before visiting each child, it
   * calls {@link #shouldVisitNextChild shouldVisitNextChild}; if the result
   * is {@code false} no more children are visited and the current aggregate
   * result is returned. After visiting a child, the aggregate result is
   * updated by calling {@link #aggregateResult aggregateResult} with the
   * previous aggregate result and the result of visiting the child.</p>
   *
   * <p>The default implementation is not safe for use in visitors that modify
   * the tree structure. Visitors that modify the tree should override this
   * method to behave properly in respect to the specific algorithm in use.</p>
   */
  T visitChildren(RuleNode node) {
    T result = defaultResult();
    var n = node.getChildCount();
    for (var i = 0; i < n; i++) {
      if (!shouldVisitNextChild(node, result)) {
        break;
      }

      final c = node.getChild(i);
      final childResult = c.accept(this);
      result = aggregateResult(result, childResult);
    }

    return result;
  }

  /**
   * {@inheritDoc}
   *
   * <p>The default implementation returns the result of
   * {@link #defaultResult defaultResult}.</p>
   */

  T visitTerminal(TerminalNode node) {
    return defaultResult();
  }

  /**
   * {@inheritDoc}
   *
   * <p>The default implementation returns the result of
   * {@link #defaultResult defaultResult}.</p>
   */

  T visitErrorNode(ErrorNode node) {
    return defaultResult();
  }

  /**
   * Gets the default value returned by visitor methods. This value is
   * returned by the default implementations of
   * {@link #visitTerminal visitTerminal}, {@link #visitErrorNode visitErrorNode}.
   * The default implementation of {@link #visitChildren visitChildren}
   * initializes its aggregate result to this value.
   *
   * <p>The base implementation returns {@code null}.</p>
   *
   * @return The default value returned by visitor methods.
   */
  T defaultResult() {
    return null;
  }

  /**
   * Aggregates the results of visiting multiple children of a node. After
   * either all children are visited or {@link #shouldVisitNextChild} returns
   * {@code false}, the aggregate value is returned as the result of
   * {@link #visitChildren}.
   *
   * <p>The default implementation returns {@code nextResult}, meaning
   * {@link #visitChildren} will return the result of the last child visited
   * (or return the initial value if the node has no children).</p>
   *
   * @param aggregate The previous aggregate value. In the default
   * implementation, the aggregate value is initialized to
   * {@link #defaultResult}, which is passed as the {@code aggregate} argument
   * to this method after the first child node is visited.
   * @param nextResult The result of the immediately preceeding call to visit
   * a child node.
   *
   * @return The updated aggregate result.
   */
  T aggregateResult(T aggregate, T nextResult) => nextResult;

  /**
   * This method is called after visiting each child in
   * {@link #visitChildren}. This method is first called before the first
   * child is visited; at that point {@code currentResult} will be the initial
   * value (in the default implementation, the initial value is returned by a
   * call to {@link #defaultResult}. This method is not called after the last
   * child is visited.
   *
   * <p>The default implementation always returns {@code true}, indicating that
   * {@code visitChildren} should only return after all children are visited.
   * One reason to override this method is to provide a "short circuit"
   * evaluation option for situations where the result of visiting a single
   * child has the potential to determine the result of the visit operation as
   * a whole.</p>
   *
   * @param node The {@link RuleNode} whose children are currently being
   * visited.
   * @param currentResult The current aggregate result of the children visited
   * to the current point.
   *
   * @return {@code true} to continue visiting children. Otherwise return
   * {@code false} to stop visiting children and immediately return the
   * current aggregate result from {@link #visitChildren}.
   */
  bool shouldVisitNextChild(RuleNode node, T currentResult) => true;
}

abstract class ParseTreeListener {
  void visitTerminal(TerminalNode node);

  void visitErrorNode(ErrorNode node);

  void enterEveryRule(ParserRuleContext node);

  void exitEveryRule(ParserRuleContext node);
}

class TraceListener implements ParseTreeListener {
  final Parser parser;

  TraceListener(this.parser);

  void enterEveryRule(ParserRuleContext ctx) {
    log("enter   " +
        parser.getRuleNames()[ctx.ruleIndex] +
        ", LT(1)=${parser.inputStream.LT(1).text}");
  }

  void visitTerminal(TerminalNode node) {
    log("consume ${node.symbol} rule " +
        parser.getRuleNames()[parser.getContext().ruleIndex]);
  }

  void visitErrorNode(ErrorNode node) {}

  void exitEveryRule(ParserRuleContext ctx) {
    log("exit    ${parser.getRuleNames()[ctx.ruleIndex]}" +
        ", LT(1)=" +
        parser.inputStream.LT(1).text);
  }
}

class TrimToSizeListener implements ParseTreeListener {
  static final TrimToSizeListener INSTANCE = new TrimToSizeListener();

  void enterEveryRule(ParserRuleContext ctx) {}

  void visitTerminal(TerminalNode node) {}

  void visitErrorNode(ErrorNode node) {}

  void exitEveryRule(ParserRuleContext ctx) {
    // TODO trim dart List's size
//    if (ctx.children is List) {
//      (ctx.children).trimToSize();
//    }
  }
}

class TerminalNodeImpl extends TerminalNode {
  Token symbol;
  ParseTree parentCtx;

  TerminalNodeImpl(this.symbol);

  getChild(i) {
    return null;
  }

  getParent() {
    return this.parentCtx;
  }

  void setParent(RuleContext parent) {
    this.parentCtx = parent;
  }

  Token getPayload() => symbol;

  Interval getSourceInterval() {
    if (symbol == null) return Interval.INVALID;

    int tokenIndex = symbol.tokenIndex;
    return new Interval(tokenIndex, tokenIndex);
  }

  int getChildCount() {
    return 0;
  }

  T accept<T>(ParseTreeVisitor<T> visitor) {
    return visitor.visitTerminal(this);
  }

  String getText() {
    return symbol.text;
  }

  String toStringTree({Parser parser}) {
    return toString();
  }

  String toString() {
    if (symbol.type == Token.EOF) return "<EOF>";
    return symbol.text;
  }
}

/// Represents a token that was consumed during resynchronization
/// rather than during a valid match operation. For example,
/// we will create this kind of a node during single token insertion
/// and deletion as well as during "consume until error recovery set"
/// upon no viable alternative exceptions.
class ErrorNodeImpl extends TerminalNodeImpl implements ErrorNode {
  ErrorNodeImpl(token) : super(token);

  isErrorNode() => true;

  T accept<T>(ParseTreeVisitor<T> visitor) {
    return visitor.visitErrorNode(this);
  }
}

class ParseTreeWalker {
  void walk(ParseTreeListener listener, ParseTree t) {
    if (t is ErrorNode) {
      listener.visitErrorNode(t);
      return;
    } else if (t is TerminalNode) {
      listener.visitTerminal(t);
      return;
    }
    RuleNode r = t;
    enterRule(listener, r);
    int n = r.getChildCount();
    for (int i = 0; i < n; i++) {
      walk(listener, r.getChild(i));
    }
    exitRule(listener, r);
  }

  /**
   * The discovery of a rule node, involves sending two events: the generic
   * {@link ParseTreeListener#enterEveryRule} and a
   * {@link RuleContext}-specific event. First we trigger the generic and then
   * the rule specific. We to them in reverse order upon finishing the node.
   */
  void enterRule(ParseTreeListener listener, RuleNode r) {
    ParserRuleContext ctx = r.ruleContext;
    listener.enterEveryRule(ctx);
    ctx.enterRule(listener);
  }

  void exitRule(ParseTreeListener listener, RuleNode r) {
    ParserRuleContext ctx = r.ruleContext;
    ctx.exitRule(listener);
    listener.exitEveryRule(ctx);
  }

  static final DEFAULT = new ParseTreeWalker();
}
