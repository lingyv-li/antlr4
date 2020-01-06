/* Copyright (c) 2012-2017 The ANTLR Project. All rights reserved.
 * Use of this file is governed by the BSD 3-clause license that
 * can be found in the LICENSE.txt file in the project root.
 */
//

/// A token has properties: text, type, line, character position in the line
/// (so we can ignore tabs), token channel, index, and source from which
/// we obtained this token.
class Token {
  List source = null;
  var type = null; // token type of the token
  var channel = null; // The parser ignores everything not on DEFAULT_CHANNEL
  var start = null; // optional; return -1 if not implemented.
  var stop = null; // optional; return -1 if not implemented.
  var tokenIndex = null; // from 0..n-1 of the token object in the input stream
  var line = null; // line=1..n of the 1st character
  var column = null; // beginning of the line at which it occurs, 0..n-1
  String _text = null; // text of the token.

  String get text {
    return this._text;
  }

  /// Explicitly set the text for this token. If {code text} is not
  /// {@code null}, then {@link //getText} will return this value rather than
  /// extracting the text from the input.
  ///
  /// @param text The explicit text of the token, or {@code null} if the text
  /// should be obtained from the input along with the start and stop indexes
  /// of the token.
  set text(String text) {
    this._text = text;
  }

  getTokenSource() {
    return this.source[0];
  }

  getInputStream() {
    return this.source[1];
  }

  static const INVALID_TYPE = 0;

  /// During lookahead operations, this "token" signifies we hit rule end ATN state
  /// and did not follow it despite needing to.
  static const EPSILON = -2;

  static const MIN_USER_TOKEN_TYPE = 1;

  static const EOF = -1;

  /// All tokens go to the parser (unless skip() is called in that rule)
  /// on a particular "channel". The parser tunes to a particular channel
  /// so that whitespace etc... can go to the parser on a "hidden" channel.
  static const DEFAULT_CHANNEL = 0;

  /// Anything on different channel than DEFAULT_CHANNEL is not parsed
  /// by parser.
  static const HIDDEN_CHANNEL = 1;
}

class CommonToken extends Token {
  CommonToken(
      {source = CommonToken.EMPTY_SOURCE,
      type = null,
      channel = Token.DEFAULT_CHANNEL,
      start = -1,
      stop = -1}) {
    this.source = source;
    this.type = type;
    this.channel = channel;
    this.start = start;
    this.stop = stop;
    this.tokenIndex = -1;
    if (this.source[0] != null) {
      this.line = source[0].line;
      this.column = source[0].column;
    } else {
      this.column = -1;
    }
  }

  /// Constructs a new {@link CommonToken} as a copy of another {@link Token}.
  ///
  /// <p>
  /// If {@code oldToken} is also a {@link CommonToken} instance, the newly
  /// constructed token will share a reference to the {@link //text} field and
  /// the {@link Pair} stored in {@link //source}. Otherwise, {@link //text} will
  /// be assigned the result of calling {@link //getText}, and {@link //source}
  /// will be constructed from the result of {@link Token//getTokenSource} and
  /// {@link Token//getInputStream}.</p>
  ///
  /// @param oldToken The token to copy.
  ///
  clone() {
    var t = new CommonToken(
        source: this.source,
        type: this.type,
        channel: this.channel,
        start: this.start,
        stop: this.stop);
    t.tokenIndex = this.tokenIndex;
    t.line = this.line;
    t.column = this.column;
    t.text = this.text;
    return t;
  }

  String get text {
    if (this._text != null) {
      return this._text;
    }
    var input = this.getInputStream();
    if (input == null) {
      return null;
    }
    var n = input.size;
    if (this.start < n && this.stop < n) {
      return input.getText(this.start, this.stop);
    } else {
      return "<EOF>";
    }
  }

  set text(String text) {
    this._text = text;
  }

  /// An empty {@link Pair} which is used as the default value of
  /// {@link //source} for tokens that do not have a source.
  static const EMPTY_SOURCE = [null, null];

  @override
  String toString() {
    var txt = this.text;
    if (txt != null) {
      txt = txt
          .replaceAll(r"\n", r"\\n")
          .replaceAll(r"\r", r"\\r")
          .replaceAll(r"\t", r"\\t");
    } else {
      txt = "<no text>";
    }
    return "[@" +
        this.tokenIndex +
        "," +
        this.start +
        ":" +
        this.stop +
        "='" +
        txt +
        "',<" +
        this.type +
        ">" +
        (this.channel > 0 ? ",channel=" + this.channel : "") +
        "," +
        this.line +
        ":" +
        this.column +
        "]";
  }
}
