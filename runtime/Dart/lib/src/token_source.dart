import 'dart:math';

import 'char_stream.dart';
import 'common_token_factory.dart';
import 'token.dart';
import 'misc/Pair.dart';

/**
 * A source of tokens must provide a sequence of tokens via {@link #nextToken()}
 * and also must reveal it's source of characters; {@link CommonToken}'s text is
 * computed from a {@link CharStream}; it only store indices into the char
 * stream.
 *
 * <p>Errors from the lexer are never passed to the parser. Either you want to keep
 * going or you do not upon token recognition error. If you do not want to
 * continue lexing then you do not want to continue parsing. Just throw an
 * exception not under {@link RecognitionException} and Java will naturally toss
 * you all the way out of the recognizers. If you want to continue lexing then
 * you should not throw an exception to the parser--it has already requested a
 * token. Keep lexing until you get a valid one. Just report errors and keep
 * going, looking for a valid token.</p>
 */
abstract class TokenSource {
  /**
   * Return a {@link Token} object from your input stream (usually a
   * {@link CharStream}). Do not fail/return upon lexing error; keep chewing
   * on the characters until you get a good one; errors are not passed through
   * to the parser.
   */
  Token nextToken();

  /**
   * Get the line number for the current position in the input stream. The
   * first line in the input is line 1.
   *
   * @return The line number for the current position in the input stream, or
   * 0 if the current token source does not track line numbers.
   */
  int getLine();

  /**
   * Get the index into the current line for the current position in the input
   * stream. The first character on a line has position 0.
   *
   * @return The line number for the current position in the input stream, or
   * -1 if the current token source does not track character positions.
   */
  int get charPositionInLine;

  /**
   * Get the {@link CharStream} from which this token source is currently
   * providing tokens.
   *
   * @return The {@link CharStream} associated with the current position in
   * the input, or {@code null} if no input stream is available for the token
   * source.
   */
  CharStream get inputStream;

  /**
   * Gets the name of the underlying input source. This method returns a
   * non-null, non-empty string. If such a name is not known, this method
   * returns {@link IntStream#UNKNOWN_SOURCE_NAME}.
   */
  String get sourceName;

  /**
   * Set the {@link TokenFactory} this token source should use for creating
   * {@link Token} objects from the input.
   *
   * @param factory The {@link TokenFactory} to use for creating tokens.
   */
  void setTokenFactory(TokenFactory factory);

  /**
   * Gets the {@link TokenFactory} this token source is currently using for
   * creating {@link Token} objects from the input.
   *
   * @return The {@link TokenFactory} currently used by this token source.
   */
  TokenFactory getTokenFactory();
}

/**
 * Provides an implementation of {@link TokenSource} as a wrapper around a list
 * of {@link Token} objects.
 *
 * <p>If the final token in the list is an {@link Token#EOF} token, it will be used
 * as the EOF token for every call to {@link #nextToken} after the end of the
 * list is reached. Otherwise, an EOF token will be created.</p>
 */
class ListTokenSource implements TokenSource {
  /**
   * The wrapped collection of {@link Token} objects to return.
   */
  final List<Token> tokens;

  /**
   * The name of the input source. If this value is {@code null}, a call to
   * {@link #getSourceName} should return the source name used to create the
   * the next token in {@link #tokens} (or the previous token if the end of
   * the input has been reached).
   */
  final String sourceName;

  /**
   * The index into {@link #tokens} of token to return by the next call to
   * {@link #nextToken}. The end of the input is indicated by this value
   * being greater than or equal to the number of items in {@link #tokens}.
   */
  int i;

  /**
   * This field caches the EOF token for the token source.
   */
  Token eofToken;

  /**
   * This is the backing field for {@link #getTokenFactory} and
   * {@link setTokenFactory}.
   */
  TokenFactory _factory = CommonTokenFactory.DEFAULT;

  /**
   * Constructs a new {@link ListTokenSource} instance from the specified
   * collection of {@link Token} objects.
   *
   * @param tokens The collection of {@link Token} objects to provide as a
   * {@link TokenSource}.
   * @exception NullPointerException if {@code tokens} is {@code null}
   */

  /**
   * Constructs a new {@link ListTokenSource} instance from the specified
   * collection of {@link Token} objects and source name.
   *
   * @param tokens The collection of {@link Token} objects to provide as a
   * {@link TokenSource}.
   * @param sourceName The name of the {@link TokenSource}. If this value is
   * {@code null}, {@link #getSourceName} will attempt to infer the name from
   * the next {@link Token} (or the previous token if the end of the input has
   * been reached).
   *
   * @exception NullPointerException if {@code tokens} is {@code null}
   */
  ListTokenSource(this.tokens, [this.sourceName = null]) {
    if (tokens == null) {
      throw new ArgumentError.notNull("tokens");
    }
  }

  /**
   * {@inheritDoc}
   */

  int get charPositionInLine {
    if (i < tokens.length) {
      return tokens[i].charPositionInLine;
    } else if (eofToken != null) {
      return eofToken.charPositionInLine;
    } else if (tokens.length > 0) {
      // have to calculate the result from the line/column of the previous
      // token, along with the text of the token.
      Token lastToken = tokens[tokens.length - 1];
      String tokenText = lastToken.text;
      if (tokenText != null) {
        int lastNewLine = tokenText.lastIndexOf('\n');
        if (lastNewLine >= 0) {
          return tokenText.length - lastNewLine - 1;
        }
      }

      return lastToken.charPositionInLine +
          lastToken.stopIndex -
          lastToken.startIndex +
          1;
    }

    // only reach this if tokens is empty, meaning EOF occurs at the first
    // position in the input
    return 0;
  }

  /**
   * {@inheritDoc}
   */

  Token nextToken() {
    if (i >= tokens.length) {
      if (eofToken == null) {
        int start = -1;
        if (tokens.length > 0) {
          int previousStop = tokens[tokens.length - 1].stopIndex;
          if (previousStop != -1) {
            start = previousStop + 1;
          }
        }

        int stop = max(-1, start - 1);
        eofToken = _factory.create(
            Token.EOF,
            "EOF",
            Pair(this, inputStream),
            Token.DEFAULT_CHANNEL,
            start,
            stop,
            getLine(),
            charPositionInLine);
      }

      return eofToken;
    }

    Token t = tokens[i];
    if (i == tokens.length - 1 && t.type == Token.EOF) {
      eofToken = t;
    }

    i++;
    return t;
  }

  /**
   * {@inheritDoc}
   */

  int getLine() {
    if (i < tokens.length) {
      return tokens[i].line;
    } else if (eofToken != null) {
      return eofToken.line;
    } else if (tokens.length > 0) {
      // have to calculate the result from the line/column of the previous
      // token, along with the text of the token.
      Token lastToken = tokens[tokens.length - 1];
      int line = lastToken.line;

      String tokenText = lastToken.text;
      if (tokenText != null) {
        for (int i = 0; i < tokenText.length; i++) {
          if (tokenText[i] == '\n') {
            line++;
          }
        }
      }

      // if no text is available, assume the token did not contain any newline characters.
      return line;
    }

    // only reach this if tokens is empty, meaning EOF occurs at the first
    // position in the input
    return 1;
  }

  /**
   * {@inheritDoc}
   */

  CharStream get inputStream {
    if (i < tokens.length) {
      return tokens[i].inputStream;
    } else if (eofToken != null) {
      return eofToken.inputStream;
    } else if (tokens.length > 0) {
      return tokens[tokens.length - 1].inputStream;
    }

    // no input stream information is available
    return null;
  }

  /**
   * {@inheritDoc}
   */

  String getSourceName() {
    if (sourceName != null) {
      return sourceName;
    }

    CharStream _inputStream = inputStream;
    if (_inputStream != null) {
      return _inputStream.sourceName;
    }

    return "List";
  }

  /**
   * {@inheritDoc}
   */

  void setTokenFactory(TokenFactory factory) {
    this._factory = factory;
  }

  /**
   * {@inheritDoc}
   */

  TokenFactory getTokenFactory() {
    return _factory;
  }
}
