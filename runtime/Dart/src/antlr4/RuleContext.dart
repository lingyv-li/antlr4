/* Copyright (c) 2012-2017 The ANTLR Project. All rights reserved.
 * Use of this file is governed by the BSD 3-clause license that
 * can be found in the LICENSE.txt file in the project root.
 */

///

//  A rule context is a record of a single rule invocation. It knows
//  which context invoked it, if any. If there is no parent context, then
//  naturally the invoking state is not valid.  The parent link
//  provides a chain upwards from the current rule invocation to the root
//  of the invocation tree, forming a stack. We actually carry no
//  information about the rule associated with this context (except
//  when parsing). We keep only the state number of the invoking state from
//  the ATN submachine that invoked this. Contrast this with the s
//  pointer inside ParserRuleContext that tracks the current state
//  being "executed" for the current rule.
//
//  The parent contexts are useful for computing lookahead sets and
//  getting error information.
//
//  These objects are used during parsing and prediction.
//  For the special case of parsers, we use the subclass
//  ParserRuleContext.
//
//  @see ParserRuleContext
///

import 'tree/Tree.dart';

import 'atn/ATN.dart';
import 'IntervalSet.dart';
import 'Parser.dart';
import 'ParserRuleContext.dart';
import 'Recognizer.dart';
import 'tree/Trees.dart';

/** A rule context is a record of a single rule invocation.
 *
 *  We form a stack of these context objects using the parent
 *  pointer. A parent pointer of null indicates that the current
 *  context is the bottom of the stack. The ParserRuleContext subclass
 *  as a children list so that we can turn this data structure into a
 *  tree.
 *
 *  The root node always has a null pointer and invokingState of -1.
 *
 *  Upon entry to parsing, the first invoked rule function creates a
 *  context object (a subclass specialized for that rule such as
 *  SContext) and makes it the root of a parse tree, recorded by field
 *  Parser._ctx.
 *
 *  public final SContext s() throws RecognitionException {
 *      SContext _localctx = new SContext(_ctx, getState()); <-- create new node
 *      enterRule(_localctx, 0, RULE_s);                     <-- push it
 *      ...
 *      exitRule();                                          <-- pop back to _localctx
 *      return _localctx;
 *  }
 *
 *  A subsequent rule invocation of r from the start rule s pushes a
 *  new context object for r whose parent points at s and use invoking
 *  state is the state with r emanating as edge label.
 *
 *  The invokingState fields from a context object to the root
 *  together form a stack of rule indication states where the root
 *  (bottom of the stack) has a -1 sentinel value. If we invoke start
 *  symbol s then call r1, which calls r2, the  would look like
 *  this:
 *
 *     SContext[-1]   <- root node (bottom of the stack)
 *     R1Context[p]   <- p in rule s called r1
 *     R2Context[q]   <- q in rule r1 called r2
 *
 *  So the top of the stack, _ctx, represents a call to the current
 *  rule and it holds the return address from another rule that invoke
 *  to this rule. To invoke a rule, we must always have a current context.
 *
 *  The parent contexts are useful for computing lookahead sets and
 *  getting error information.
 *
 *  These objects are used during parsing and prediction.
 *  For the special case of parsers, we use the subclass
 *  ParserRuleContext.
 *
 *  @see ParserRuleContext
 */
abstract class RuleContext extends RuleNode {
  /// What context invoked this rule?
  RuleContext parentCtx = null;

  /// What state invoked the rule associated with this context?
  /// The "return address" is the followState of invokingState
  /// If parent is null, this should be -1.
  int invokingState = -1;

  RuleContext({this.parentCtx, this.invokingState});

  int depth() {
    var n = 0;
    var p = this;
    while (p != null) {
      p = p.parentCtx;
      n++;
    }
    return n;
  }

  /// A context is empty if there is no invoking state; meaning nobody call
  /// current context.
  isEmpty() => invokingState == -1;

  /// satisfy the ParseTree / SyntaxTree interface
  getSourceInterval() => Interval.INVALID;

  get ruleContext => this;

  RuleContext getParent() => parentCtx;

  setParent(RuleContext parent) {
    this.parentCtx = parent;
  }

  getPayload() => this;

  /**
   * Return the combined text of all child nodes. This method only considers
   *  tokens which have been added to the parse tree.
   *  <p>
   *  Since tokens on hidden channels (e.g. whitespace or comments) are not
   *  added to the parse trees, they will not appear in the output of this
   *  method.
   */
  String getText() {
    if (getChildCount() == 0) {
      return "";
    }

    final builder = new StringBuffer();
    for (int i = 0; i < getChildCount(); i++) {
      builder.write(getChild(i).getText());
    }

    return builder.toString();
  }

  int get ruleIndex => -1;

  /// For rule associated with this parse tree internal node, return
  /// the outer alternative number used to match the input. Default
  /// implementation does not compute nor store this alt num. Create
  /// a subclass of ParserRuleContext with backing field and set
  /// option contextSuperClass.
  /// to set it.
  getAltNumber() => ATN.INVALID_ALT_NUMBER;

  /// Set the outer alternative number for this context node. Default
  /// implementation does nothing to avoid backing field overhead for
  /// trees that don't need it.  Create
  /// a subclass of ParserRuleContext with backing field and set
  /// option contextSuperClass.
  setAltNumber(int altNumber) {}

  ParseTree getChild(int i) {
    return null;
  }

  getChildCount() => 0;

  T accept<T>(ParseTreeVisitor<T> visitor) {
    return visitor.visitChildren(this);
  }

  /// Print out a whole tree, not just a node, in LISP format
  /// (root child1 .. childN). Print just a node if this is a leaf.
  ///
  toStringTree({List<String> ruleNames, Parser parser}) {
    return Trees.toStringTree(this, ruleNames: ruleNames, recog: parser);
  }

  String toString({List<String> ruleNames, Recognizer recog, RuleContext stop}) {
    ruleNames = ruleNames ?? recog.getRuleNames();
    final buf = new StringBuffer();
    var p = this;
    buf.write("[");
    while (p != null && p != stop) {
      if (ruleNames == null) {
        if (!p.isEmpty()) {
          buf.write(p.invokingState);
        }
      } else {
        int ruleIndex = p.ruleIndex;
        String ruleName = ruleIndex >= 0 && ruleIndex < ruleNames.length
            ? ruleNames[ruleIndex]
            : ruleIndex.toString();
        buf.write(ruleName);
      }

      if (p.getParent() != null &&
          (ruleNames != null || !p.getParent().isEmpty())) {
        buf.write(" ");
      }

      p = p.getParent();
    }

    buf.write("]");
    return buf.toString();
  }

  static final EMPTY = new ParserRuleContext();
}
