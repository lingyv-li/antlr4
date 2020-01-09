//
/* Copyright (c) 2012-2017 The ANTLR Project. All rights reserved.
 * Use of this file is governed by the BSD 3-clause license that
 * can be found in the LICENSE.txt file in the project root.
 */

// This implementation of {@link TokenStream} loads tokens from a
// {@link TokenSource} on-demand, and places the tokens in a buffer to provide
// access to any previous token by index.
//
// <p>
// This token stream ignores the value of {@link Token//getChannel}. If your
// parser requires the token stream filter tokens to only those on a particular
// channel, such as {@link Token//DEFAULT_CHANNEL} or
// {@link Token//HIDDEN_CHANNEL}, use a filtering token stream such a
// {@link CommonTokenStream}.</p>

// this is just to keep meaningful parameter types to Parser
import 'IntStream.dart';
import 'IntervalSet.dart';
import 'Lexer.dart';
import 'RuleContext.dart';
import 'Token.dart';
import 'TokenSource.dart';

/**
 * An {@link IntStream} whose symbols are {@link Token} instances.
 */
abstract class TokenStream extends IntStream {
  /**
   * Get the {@link Token} instance associated with the value returned by
   * {@link #LA LA(k)}. This method has the same pre- and post-conditions as
   * {@link IntStream#LA}. In addition, when the preconditions of this method
   * are met, the return value is non-null and the value of
   * {@code LT(k).getType()==LA(k)}.
   *
   * @see IntStream#LA
   */
  Token LT(int k);

  /**
   * Gets the {@link Token} at the specified {@code index} in the stream. When
   * the preconditions of this method are met, the return value is non-null.
   *
   * <p>The preconditions for this method are the same as the preconditions of
   * {@link IntStream#seek}. If the behavior of {@code seek(index)} is
   * unspecified for the current state and given {@code index}, then the
   * behavior of this method is also unspecified.</p>
   *
   * <p>The symbol referred to by {@code index} differs from {@code seek()} only
   * in the case of filtering streams where {@code index} lies before the end
   * of the stream. Unlike {@code seek()}, this method does not adjust
   * {@code index} to point to a non-ignored symbol.</p>
   *
   * @throws IllegalArgumentException if {code index} is less than 0
   * @throws UnsupportedOperationException if the stream does not support
   * retrieving the token at the specified index
   */
  Token get(int index);

  /**
   * Gets the underlying {@link TokenSource} which provides tokens for this
   * stream.
   */
  TokenSource getTokenSource();

  /**
   * Return the text of all tokens within the specified {@code interval}. This
   * method behaves like the following code (including potential exceptions
   * for violating preconditions of {@link #get}, but may be optimized by the
   * specific implementation.
   *
   * <pre>
   * TokenStream stream = ...;
   * String text = "";
   * for (int i = interval.a; i &lt;= interval.b; i++) {
   *   text += stream.get(i).getText();
   * }
   * </pre>
   *
   * <pre>
   * TokenStream stream = ...;
   * String text = stream.getText(new Interval(0, stream.size()));
   * </pre>
   *
   * <pre>
   * TokenStream stream = ...;
   * String text = stream.getText(ctx.getSourceInterval());
   * </pre>
   *
   * @param interval The interval of tokens within this stream to get text
   * for.
   * @return The text of all tokens / within the specified interval in this
   * stream.
   */
  String getText([Interval interval]);

  /**
   * Return the text of all tokens in the source interval of the specified
   * context. This method behaves like the following code, including potential
   * exceptions from the call to {@link #getText(Interval)}, but may be
   * optimized by the specific implementation.
   *
   * <p>If {@code ctx.getSourceInterval()} does not return a valid interval of
   * tokens provided by this stream, the behavior is unspecified.</p>
   *
   * @param ctx The context providing the source interval of tokens to get
   * text for.
   * @return The text of all tokens within the source interval of {@code ctx}.
   */
  String getTextFromCtx(RuleContext ctx);

  /**
   * Return the text of all tokens in this stream between {@code start} and
   * {@code stop} (inclusive).
   *
   * <p>If the specified {@code start} or {@code stop} token was not provided by
   * this stream, or if the {@code stop} occurred before the {@code start}
   * token, the behavior is unspecified.</p>
   *
   * <p>For streams which ensure that the {@link Token#getTokenIndex} method is
   * accurate for all of its provided tokens, this method behaves like the
   * following code. Other streams may implement this method in other ways
   * provided the behavior is consistent with this at a high level.</p>
   *
   * <pre>
   * TokenStream stream = ...;
   * String text = "";
   * for (int i = start.getTokenIndex(); i &lt;= stop.getTokenIndex(); i++) {
   *   text += stream.get(i).getText();
   * }
   * </pre>
   *
   * @param start The first token in the interval to get text for.
   * @param stop The last token in the interval to get text for (inclusive).
   * @return The text of all tokens lying between the specified {@code start}
   * and {@code stop} tokens.
   *
   * @throws UnsupportedOperationException if this stream does not support
   * this method for the specified tokens
   */
  String getTextRange(Token start, Token stop);
}

/**
 * This implementation of {@link TokenStream} loads tokens from a
 * {@link TokenSource} on-demand, and places the tokens in a buffer to provide
 * access to any previous token by index.
 *
 * <p>
 * This token stream ignores the value of {@link Token#getChannel}. If your
 * parser requires the token stream filter tokens to only those on a particular
 * channel, such as {@link Token#DEFAULT_CHANNEL} or
 * {@link Token#HIDDEN_CHANNEL}, use a filtering token stream such a
 * {@link CommonTokenStream}.</p>
 */
class BufferedTokenStream implements TokenStream {
  /**
   * The {@link TokenSource} from which tokens for this stream are fetched.
   */
  TokenSource tokenSource;

  /**
   * A collection of all tokens fetched from the token source. The list is
   * considered a complete view of the input once {@link #fetchedEOF} is set
   * to {@code true}.
   */
  List<Token> tokens = List<Token>();

  /**
   * The index into {@link #tokens} of the current token (next token to
   * {@link #consume}). {@link #tokens}{@code [}{@link #p}{@code ]} should be
   * {@link #LT LT(1)}.
   *
   * <p>This field is set to -1 when the stream is first constructed or when
   * {@link #setTokenSource} is called, indicating that the first token has
   * not yet been fetched from the token source. For additional information,
   * see the documentation of {@link IntStream} for a description of
   * Initializing Methods.</p>
   */
  int p = -1;

  /**
   * Indicates whether the {@link Token#EOF} token has been fetched from
   * {@link #tokenSource} and added to {@link #tokens}. This field improves
   * performance for the following cases:
   *
   * <ul>
   * <li>{@link #consume}: The lookahead check in {@link #consume} to prevent
   * consuming the EOF symbol is optimized by checking the values of
   * {@link #fetchedEOF} and {@link #p} instead of calling {@link #LA}.</li>
   * <li>{@link #fetch}: The check to prevent adding multiple EOF symbols into
   * {@link #tokens} is trivial with this field.</li>
   * <ul>
   */
  bool fetchedEOF;

  BufferedTokenStream(TokenSource tokenSource) {
    if (tokenSource == null) {
      throw new ArgumentError.notNull("tokenSource");
    }
    this.tokenSource = tokenSource;
  }

  TokenSource getTokenSource() {
    return tokenSource;
  }

  int get index => p;

  int mark() {
    return 0;
  }

  void release(int marker) {
    // no resources to release
  }

  void seek(int index) {
    lazyInit();
    p = adjustSeekIndex(index);
  }

  int get size {
    return tokens.length;
  }

  void consume() {
    bool skipEofCheck;
    if (p >= 0) {
      if (fetchedEOF) {
        // the last token in tokens is EOF. skip check if p indexes any
        // fetched token except the last.
        skipEofCheck = p < tokens.length - 1;
      } else {
        // no EOF token in tokens. skip check if p indexes a fetched token.
        skipEofCheck = p < tokens.length;
      }
    } else {
      // not yet initialized
      skipEofCheck = false;
    }

    if (!skipEofCheck && LA(1) == IntStream.EOF) {
      throw new StateError("cannot consume EOF");
    }

    if (sync(p + 1)) {
      p = adjustSeekIndex(p + 1);
    }
  }

  /** Make sure index {@code i} in tokens has a token.
   *
   * @return {@code true} if a token is located at index {@code i}, otherwise
   *    {@code false}.
   * @see #get(int i)
   */
  bool sync(int i) {
    assert(i >= 0);
    int n = i - tokens.length + 1; // how many more elements we need?
    //System.out.println("sync("+i+") needs "+n);
    if (n > 0) {
      int fetched = fetch(n);
      return fetched >= n;
    }

    return true;
  }

  /** Add {@code n} elements to buffer.
   *
   * @return The actual number of elements added to the buffer.
   */
  int fetch(int n) {
    if (fetchedEOF) {
      return 0;
    }

    for (int i = 0; i < n; i++) {
      Token t = tokenSource.nextToken();
      if (t is WritableToken) {
        t.setTokenIndex(tokens.length);
      }
      tokens.add(t);
      if (t.type == Token.EOF) {
        fetchedEOF = true;
        return i + 1;
      }
    }

    return n;
  }

  Token get(int i) {
    if (i < 0 || i >= tokens.length) {
      throw new RangeError.index(i, tokens);
    }
    return tokens[i];
  }

  /** Get all tokens from start..stop inclusively */
  List<Token> getRange(int start, [int stop]) {
    if (start < 0 || stop < 0) return null;
    lazyInit();
    List<Token> subset = [];
    if (stop >= tokens.length) stop = tokens.length - 1;
    for (int i = start; i <= stop; i++) {
      Token t = tokens[i];
      if (t.type == Token.EOF) break;
      subset.add(t);
    }
    return subset;
  }

  int LA(int i) {
    return LT(i).type;
  }

  Token LB(int k) {
    if ((p - k) < 0) return null;
    return tokens[p - k];
  }

  Token LT(int k) {
    lazyInit();
    if (k == 0) return null;
    if (k < 0) return LB(-k);

    int i = p + k - 1;
    sync(i);
    if (i >= tokens.length) {
      // return EOF token
      // EOF must be last token
      return tokens.last;
    }
//		if ( i>range ) range = i;
    return tokens[i];
  }

  /**
   * Allowed derived classes to modify the behavior of operations which change
   * the current stream position by adjusting the target token index of a seek
   * operation. The default implementation simply returns {@code i}. If an
   * exception is thrown in this method, the current stream index should not be
   * changed.
   *
   * <p>For example, {@link CommonTokenStream} overrides this method to ensure that
   * the seek target is always an on-channel token.</p>
   *
   * @param i The target token index.
   * @return The adjusted target token index.
   */
  int adjustSeekIndex(int i) {
    return i;
  }

  void lazyInit() {
    if (p == -1) {
      setup();
    }
  }

  void setup() {
    sync(0);
    p = adjustSeekIndex(0);
  }

  /** Reset this token stream by setting its token source. */
  void setTokenSource(TokenSource tokenSource) {
    this.tokenSource = tokenSource;
    tokens.clear();
    p = -1;
    fetchedEOF = false;
  }

  /** Given a start and stop index, return a List of all tokens in
   *  the token type BitSet.  Return null if no tokens were found.  This
   *  method looks at both on and off channel tokens.
   */
  List<Token> getTokens(
      [int start = null, int stop = null, Set<int> types = null]) {
    if (start == null && stop == null) {
      return tokens;
    }
    lazyInit();
    if (start < 0 || start >= tokens.length) {
      throw new RangeError.index(start, tokens);
    } else if (stop < 0 || stop >= tokens.length) {
      throw new RangeError.index(stop, tokens);
    }
    if (start > stop) return null;

    // list = tokens[start:stop]:{T t, t.getType() in types}
    List<Token> filteredTokens = [];
    for (int i = start; i <= stop; i++) {
      Token t = tokens[i];
      if (types == null || types.contains(t.type)) {
        filteredTokens.add(t);
      }
    }
    if (filteredTokens.isEmpty) {
      filteredTokens = null;
    }
    return filteredTokens;
  }

  /**
   * Given a starting index, return the index of the next token on channel.
   * Return {@code i} if {@code tokens[i]} is on channel. Return the index of
   * the EOF token if there are no tokens on channel between {@code i} and
   * EOF.
   */
  int nextTokenOnChannel(int i, int channel) {
    sync(i);
    if (i >= size) {
      return size - 1;
    }

    Token token = tokens[i];
    while (token.channel != channel) {
      if (token.type == Token.EOF) {
        return i;
      }

      i++;
      sync(i);
      token = tokens[i];
    }

    return i;
  }

  /**
   * Given a starting index, return the index of the previous token on
   * channel. Return {@code i} if {@code tokens[i]} is on channel. Return -1
   * if there are no tokens on channel between {@code i} and 0.
   *
   * <p>
   * If {@code i} specifies an index at or after the EOF token, the EOF token
   * index is returned. This is due to the fact that the EOF token is treated
   * as though it were on every channel.</p>
   */
  int previousTokenOnChannel(int i, int channel) {
    sync(i);
    if (i >= size) {
      // the EOF token is on every channel
      return size - 1;
    }

    while (i >= 0) {
      Token token = tokens[i];
      if (token.type == Token.EOF || token.channel == channel) {
        return i;
      }

      i--;
    }

    return i;
  }

  /** Collect all tokens on specified channel to the right of
   *  the current token up until we see a token on DEFAULT_TOKEN_CHANNEL or
   *  EOF. If channel is -1, find any non default channel token.
   */
  List<Token> getHiddenTokensToRight(int tokenIndex, [int channel = -1]) {
    lazyInit();
    if (tokenIndex < 0 || tokenIndex >= tokens.length) {
      throw new RangeError.index(tokenIndex, tokens);
    }

    int nextOnChannel =
        nextTokenOnChannel(tokenIndex + 1, Lexer.DEFAULT_TOKEN_CHANNEL);
    int to;
    int from = tokenIndex + 1;
    // if none onchannel to right, nextOnChannel=-1 so set to = last token
    if (nextOnChannel == -1)
      to = size - 1;
    else
      to = nextOnChannel;

    return filterForChannel(from, to, channel);
  }

  /** Collect all tokens on specified channel to the left of
   *  the current token up until we see a token on DEFAULT_TOKEN_CHANNEL.
   *  If channel is -1, find any non default channel token.
   */
  List<Token> getHiddenTokensToLeft(int tokenIndex, [int channel = -1]) {
    lazyInit();
    if (tokenIndex < 0 || tokenIndex >= tokens.length) {
      throw new RangeError.index(tokenIndex, tokens);
    }

    if (tokenIndex == 0) {
      // obviously no tokens can appear before the first token
      return null;
    }

    int prevOnChannel =
        previousTokenOnChannel(tokenIndex - 1, Lexer.DEFAULT_TOKEN_CHANNEL);
    if (prevOnChannel == tokenIndex - 1) return null;
    // if none onchannel to left, prevOnChannel=-1 then from=0
    int from = prevOnChannel + 1;
    int to = tokenIndex - 1;

    return filterForChannel(from, to, channel);
  }

  List<Token> filterForChannel(int from, int to, int channel) {
    List<Token> hidden = [];
    for (int i = from; i <= to; i++) {
      Token t = tokens[i];
      if (channel == -1) {
        if (t.channel != Lexer.DEFAULT_TOKEN_CHANNEL) hidden.add(t);
      } else {
        if (t.channel == channel) hidden.add(t);
      }
    }
    if (hidden.length == 0) return null;
    return hidden;
  }

  String get sourceName => tokenSource.sourceName;

  String getText([Interval interval = null]) {
    interval = interval ??
        Interval.of(0, size - 1); // Get the text of all tokens in this buffer.
    int start = interval.a;
    int stop = interval.b;
    if (start < 0 || stop < 0) return "";
    fill();
    if (stop >= tokens.length) stop = tokens.length - 1;

    StringBuffer buf = new StringBuffer();
    for (int i = start; i <= stop; i++) {
      Token t = tokens[i];
      if (t.type == Token.EOF) break;
      buf.write(t.text);
    }
    return buf.toString();
  }

  String getTextFromCtx(RuleContext ctx) {
    return getText(ctx.getSourceInterval());
  }

  String getTextRange(Token start, Token stop) {
    if (start != null && stop != null) {
      return getText(Interval.of(start.tokenIndex, stop.tokenIndex));
    }

    return "";
  }

  /** Get all tokens from lexer until EOF */
  void fill() {
    lazyInit();
    final int blockSize = 1000;
    while (true) {
      int fetched = fetch(blockSize);
      if (fetched < blockSize) {
        return;
      }
    }
  }
}

/**
 * This class extends {@link BufferedTokenStream} with functionality to filter
 * token streams to tokens on a particular channel (tokens where
 * {@link Token#getChannel} returns a particular value).
 *
 * <p>
 * This token stream provides access to all tokens by index or when calling
 * methods like {@link #getText}. The channel filtering is only used for code
 * accessing tokens via the lookahead methods {@link #LA}, {@link #LT}, and
 * {@link #LB}.</p>
 *
 * <p>
 * By default, tokens are placed on the default channel
 * ({@link Token#DEFAULT_CHANNEL}), but may be reassigned by using the
 * {@code ->channel(HIDDEN)} lexer command, or by using an embedded action to
 * call {@link Lexer#setChannel}.
 * </p>
 *
 * <p>
 * Note: lexer rules which use the {@code ->skip} lexer command or call
 * {@link Lexer#skip} do not produce tokens at all, so input text matched by
 * such a rule will not be available as part of the token stream, regardless of
 * channel.</p>we
 */
class CommonTokenStream extends BufferedTokenStream {
  /**
   * Specifies the channel to use for filtering tokens.
   *
   * <p>
   * The default value is {@link Token#DEFAULT_CHANNEL}, which matches the
   * default channel assigned to tokens created by the lexer.</p>
   */
  int channel = Token.DEFAULT_CHANNEL;

  /**
   * Constructs a new {@link CommonTokenStream} using the specified token
   * source and filtering tokens to the specified channel. Only tokens whose
   * {@link Token#getChannel} matches {@code channel} or have the
   * {@link Token#getType} equal to {@link Token#EOF} will be returned by the
   * token stream lookahead methods.
   *
   * @param tokenSource The token source.
   * @param channel The channel to use for filtering tokens.
   */
  CommonTokenStream(TokenSource tokenSource, [this.channel])
      : super(tokenSource);

  int adjustSeekIndex(int i) {
    return nextTokenOnChannel(i, channel);
  }

  Token LB(int k) {
    if (k == 0 || (p - k) < 0) return null;

    int i = p;
    int n = 1;
    // find k good tokens looking backwards
    while (n <= k && i > 0) {
      // skip off-channel tokens
      i = previousTokenOnChannel(i - 1, channel);
      n++;
    }
    if (i < 0) return null;
    return tokens[i];
  }

  Token LT(int k) {
    //System.out.println("enter LT("+k+")");
    lazyInit();
    if (k == 0) return null;
    if (k < 0) return LB(-k);
    int i = p;
    int n = 1; // we know tokens[p] is a good one
    // find k good tokens
    while (n < k) {
      // skip off-channel tokens, but make sure to not look past EOF
      if (sync(i + 1)) {
        i = nextTokenOnChannel(i + 1, channel);
      }
      n++;
    }
//		if ( i>range ) range = i;
    return tokens[i];
  }

  /** Count EOF just once. */
  int getNumberOfOnChannelTokens() {
    int n = 0;
    fill();
    for (int i = 0; i < tokens.length; i++) {
      Token t = tokens[i];
      if (t.channel == channel) n++;
      if (t.type == Token.EOF) break;
    }
    return n;
  }
}
