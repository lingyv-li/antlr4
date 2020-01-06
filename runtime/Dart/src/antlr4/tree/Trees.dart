/* Copyright (c) 2012-2017 The ANTLR Project. All rights reserved.
 * Use of this file is governed by the BSD 3-clause license that
 * can be found in the LICENSE.txt file in the project root.
 */
import '../Token.dart';
import './Tree.dart';
import '../ParserRuleContext.dart';
import '../RuleContext.dart';
import '../atn/ATN.dart';

/** A set of utility routines useful for all kinds of ANTLR trees. */
class Trees {
// Print out a whole tree in LISP form. {@link //getNodeText} is used on the
//  node payloads to get the text for the nodes.  Detect
//  parse trees and extract data appropriately.
  static toStringTree(tree, {ruleNames = null, recog = null}) {
    if (recog != null) {
      ruleNames = recog.ruleNames;
    }
    var s = Trees.getNodeText(tree, ruleNames: ruleNames);
    s = Utils.escapeWhitespace(s, false);
    var c = tree.getChildCount();
    if (c == 0) {
      return s;
    }
    var res = "(" + s + ' ';
    if (c > 0) {
      s = Trees.toStringTree(tree.getChild(0), ruleNames: ruleNames);
      res += s;
    }
    for (var i = 1; i < c; i++) {
      s = Trees.toStringTree(tree.getChild(i), ruleNames: ruleNames);
      res += (' ' + s);
    }
    res += ")";
    return res;
  }

  static getNodeText(t, {ruleNames = null, recog = null}) {
    if (recog != null) {
      ruleNames = recog.ruleNames;
    }
    if (ruleNames != null) {
      if (t is RuleContext) {
        var altNumber = t.getAltNumber();
        if (altNumber != ATN.INVALID_ALT_NUMBER) {
          return ruleNames[t.ruleIndex] + ":" + altNumber;
        }
        return ruleNames[t.ruleIndex];
      } else if (t is ErrorNode) {
        return t.toString();
      } else if (t is TerminalNode) {
        if (t.symbol != null) {
          return t.symbol.text;
        }
      }
    }
    // no recog for rule names
    var payload = t.getPayload();
    if (payload is Token) {
      return payload.text;
    }
    return t.getPayload().toString();
  }

// Return ordered list of all children of this node
  static getChildren(t) {
    var list = [];
    for (var i = 0; i < t.getChildCount(); i++) {
      list.add(t.getChild(i));
    }
    return list;
  }

// Return a list of all ancestors of this node.  The first node of
//  list is the root and the last is the parent of this node.
//
  static getAncestors(t) {
    var ancestors = [];
    t = t.getParent();
    while (t != null) {
      ancestors = [t] + (ancestors);
      t = t.getParent();
    }
    return ancestors;
  }

  static findAllTokenNodes(t, ttype) {
    return Trees.findAllNodes(t, ttype, true);
  }

  static findAllRuleNodes(t, ruleIndex) {
    return Trees.findAllNodes(t, ruleIndex, false);
  }

  static findAllNodes(t, index, findTokens) {
    var nodes = [];
    Trees._findAllNodes(t, index, findTokens, nodes);
    return nodes;
  }

  static _findAllNodes(t, index, findTokens, nodes) {
    // check this node (the root) first
    if (findTokens && (t is TerminalNode)) {
      if (t.symbol.type == index) {
        nodes.push(t);
      }
    } else if (!findTokens && (t is ParserRuleContext)) {
      if (t.ruleIndex == index) {
        nodes.push(t);
      }
    }
    // check children
    for (var i = 0; i < t.getChildCount(); i++) {
      Trees._findAllNodes(t.getChild(i), index, findTokens, nodes);
    }
  }

  static descendants(t) {
    var nodes = [t];
    for (var i = 0; i < t.getChildCount(); i++) {
      nodes += Trees.descendants(t.getChild(i));
    }
    return nodes;
  }
}
