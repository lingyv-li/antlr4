//
/* Copyright (c) 2012-2017 The ANTLR Project. All rights reserved.
 * Use of this file is governed by the BSD 3-clause license that
 * can be found in the LICENSE.txt file in the project root.
 */
//

import '../util/MurmurHash.dart';

enum LexerActionType {
  CHANNEL, //The type of a {@link LexerChannelAction} action.
  CUSTOM, //The type of a {@link LexerCustomAction} action.
  MODE, //The type of a {@link LexerModeAction} action.
  MORE, //The type of a {@link LexerMoreAction} action.
  POP_MODE, //The type of a {@link LexerPopModeAction} action.
  PUSH_MODE, //The type of a {@link LexerPushModeAction} action.
  SKIP, //The type of a {@link LexerSkipAction} action.
  TYPE, //The type of a {@link LexerTypeAction} action.
}

class LexerAction {
  var actionType;
  bool isPositionDependent;
  LexerAction(action) {
    this.actionType = action;
    this.isPositionDependent = false;
  }

  hashCode() {
    var hash = new MurmurHash();
    this.updateHashCode(hash);
    return hash.finish();
  }

  updateHashCode(hash) {
    hash.update(this.actionType);
  }

  equals(other) {
    return this == other;
  }
}

//
// Implements the {@code skip} lexer action by calling {@link Lexer//skip}.
//
// <p>The {@code skip} command does not have any parameters, so this action is
// implemented as a singleton instance exposed by {@link //INSTANCE}.</p>
class LexerSkipAction extends LexerAction {
  LexerSkipAction() : super(LexerActionType.SKIP);

// Provides a singleton instance of this parameterless lexer action.
  static final INSTANCE = LexerSkipAction();

  execute(lexer) {
    lexer.skip();
  }

  toString() {
    return "skip";
  }
}

//  Implements the {@code type} lexer action by calling {@link Lexer//setType}
// with the assigned type.
class LexerTypeAction extends LexerAction {
  var type;
  LexerTypeAction(this.type) : super(LexerActionType.TYPE);

  execute(lexer) {
    lexer.type = this.type;
  }

  updateHashCode(hash) {
    hash.update(this.actionType, this.type);
  }

  equals(other) {
    if (this == other) {
      return true;
    } else if (!(other is LexerTypeAction)) {
      return false;
    } else {
      return this.type == other.type;
    }
  }

  toString() {
    return "type(" + this.type + ")";
  }
}

// Implements the {@code pushMode} lexer action by calling
// {@link Lexer//pushMode} with the assigned mode.
class LexerPushModeAction extends LexerAction {
  var mode;
  LexerPushModeAction(this.mode) : super(LexerActionType.PUSH_MODE);

// <p>This action is implemented by calling {@link Lexer//pushMode} with the
// value provided by {@link //getMode}.</p>
  execute(lexer) {
    lexer.pushMode(this.mode);
  }

  updateHashCode(hash) {
    hash.update(this.actionType, this.mode);
  }

  equals(other) {
    if (this == other) {
      return true;
    } else if (!(other is LexerPushModeAction)) {
      return false;
    } else {
      return this.mode == other.mode;
    }
  }

  toString() {
    return "pushMode(" + this.mode + ")";
  }
}

// Implements the {@code popMode} lexer action by calling {@link Lexer//popMode}.
//
// <p>The {@code popMode} command does not have any parameters, so this action is
// implemented as a singleton instance exposed by {@link //INSTANCE}.</p>
class LexerPopModeAction extends LexerAction {
  LexerPopModeAction() : super(LexerActionType.POP_MODE);
  static final INSTANCE = new LexerPopModeAction();

// <p>This action is implemented by calling {@link Lexer//popMode}.</p>
  execute(lexer) {
    lexer.popMode();
  }

  toString() {
    return "popMode";
  }
}

// Implements the {@code more} lexer action by calling {@link Lexer//more}.
//
// <p>The {@code more} command does not have any parameters, so this action is
// implemented as a singleton instance exposed by {@link //INSTANCE}.</p>
class LexerMoreAction extends LexerAction {
  LexerMoreAction() : super(LexerActionType.MORE);

  static final INSTANCE = new LexerMoreAction();

// <p>This action is implemented by calling {@link Lexer//popMode}.</p>
  execute(lexer) {
    lexer.more();
  }

  toString() {
    return "more";
  }
}

// Implements the {@code mode} lexer action by calling {@link Lexer//mode} with
// the assigned mode.
class LexerModeAction extends LexerAction {
  var mode;
  LexerModeAction(this.mode) : super(LexerActionType.MODE);

// <p>This action is implemented by calling {@link Lexer//mode} with the
// value provided by {@link //getMode}.</p>
  execute(lexer) {
    lexer.mode(this.mode);
  }

  updateHashCode(hash) {
    hash.update(this.actionType, this.mode);
  }

  equals(other) {
    if (this == other) {
      return true;
    } else if (!(other is LexerModeAction)) {
      return false;
    } else {
      return this.mode == other.mode;
    }
  }

  toString() {
    return "mode(" + this.mode + ")";
  }
}
// Executes a custom lexer action by calling {@link Recognizer//action} with the
// rule and action indexes assigned to the custom action. The implementation of
// a custom action is added to the generated code for the lexer in an override
// of {@link Recognizer//action} when the grammar is compiled.
//
// <p>This class may represent embedded actions created with the <code>{...}</code>
// syntax in ANTLR 4, as well as actions created for lexer commands where the
// command argument could not be evaluated when the grammar was compiled.</p>

// Constructs a custom lexer action with the specified rule and action
// indexes.
//
// @param ruleIndex The rule index to use for calls to
// {@link Recognizer//action}.
// @param actionIndex The action index to use for calls to
// {@link Recognizer//action}.

class LexerCustomAction extends LexerAction {
  var ruleIndex;
  var actionIndex;
  LexerCustomAction(this.ruleIndex, this.actionIndex)
      : super(LexerActionType.CUSTOM) {
    this.isPositionDependent = true;
  }

// <p>Custom actions are implemented by calling {@link Lexer//action} with the
// appropriate rule and action indexes.</p>
  execute(lexer) {
    lexer.action(null, this.ruleIndex, this.actionIndex);
  }

  updateHashCode(hash) {
    hash.update(this.actionType, this.ruleIndex, this.actionIndex);
  }

  equals(other) {
    if (this == other) {
      return true;
    } else if (!(other is LexerCustomAction)) {
      return false;
    } else {
      return this.ruleIndex == other.ruleIndex &&
          this.actionIndex == other.actionIndex;
    }
  }
}

// Implements the {@code channel} lexer action by calling
// {@link Lexer//setChannel} with the assigned channel.
// Constructs a new {@code channel} action with the specified channel value.
// @param channel The channel value to pass to {@link Lexer//setChannel}.
class LexerChannelAction extends LexerAction {
  var channel;
  LexerChannelAction(this.channel) : super(LexerActionType.CHANNEL);

// <p>This action is implemented by calling {@link Lexer//setChannel} with the
// value provided by {@link //getChannel}.</p>
  execute(lexer) {
    lexer._channel = this.channel;
  }

  updateHashCode(hash) {
    hash.update(this.actionType, this.channel);
  }

  equals(other) {
    if (this == other) {
      return true;
    } else if (!(other is LexerChannelAction)) {
      return false;
    } else {
      return this.channel == other.channel;
    }
  }

  toString() {
    return "channel(" + this.channel + ")";
  }
}
// This implementation of {@link LexerAction} is used for tracking input offsets
// for position-dependent actions within a {@link LexerActionExecutor}.
//
// <p>This action is not serialized as part of the ATN, and is only required for
// position-dependent lexer actions which appear at a location other than the
// end of a rule. For more information about DFA optimizations employed for
// lexer actions, see {@link LexerActionExecutor//append} and
// {@link LexerActionExecutor//fixOffsetBeforeMatch}.</p>

// Constructs a new indexed custom action by associating a character offset
// with a {@link LexerAction}.
//
// <p>Note: This class is only required for lexer actions for which
// {@link LexerAction//isPositionDependent} returns {@code true}.</p>
//
// @param offset The offset into the input {@link CharStream}, relative to
// the token start index, at which the specified lexer action should be
// executed.
// @param action The lexer action to execute at a particular offset in the
// input {@link CharStream}.
class LexerIndexedCustomAction extends LexerAction {
  var offset;
  var action;
  LexerIndexedCustomAction(this.offset, this.action)
      : super(action.actionType) {
    this.isPositionDependent = true;
  }

// <p>This method calls {@link //execute} on the result of {@link //getAction}
// using the provided {@code lexer}.</p>
  execute(lexer) {
    // assume the input stream position was properly set by the calling code
    this.action.execute(lexer);
  }

  updateHashCode(hash) {
    hash.update(this.actionType, this.offset, this.action);
  }

  equals(other) {
    if (this == other) {
      return true;
    } else if (!(other is LexerIndexedCustomAction)) {
      return false;
    } else {
      return this.offset == other.offset && this.action == other.action;
    }
  }
}
