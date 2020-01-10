/**
 * A chunk is either a token tag, a rule tag, or a span of literal text within a
 * tree pattern.
 *
 * <p>The method {@link ParseTreePatternMatcher#split(String)} returns a list of
 * chunks in preparation for creating a token stream by
 * {@link ParseTreePatternMatcher#tokenize(String)}. From there, we get a parse
 * tree from with {@link ParseTreePatternMatcher#compile(String, int)}. These
 * chunks are converted to {@link RuleTagToken}, {@link TokenTagToken}, or the
 * regular tokens of the text surrounding the tags.</p>
 */
abstract class Chunk {}

/**
 * Represents a placeholder tag in a tree pattern. A tag can have any of the
 * following forms.
 *
 * <ul>
 * <li>{@code expr}: An unlabeled placeholder for a parser rule {@code expr}.</li>
 * <li>{@code ID}: An unlabeled placeholder for a token of type {@code ID}.</li>
 * <li>{@code e:expr}: A labeled placeholder for a parser rule {@code expr}.</li>
 * <li>{@code id:ID}: A labeled placeholder for a token of type {@code ID}.</li>
 * </ul>
 *
 * This class does not perform any validation on the tag or label names aside
 * from ensuring that the tag is a non-null, non-empty string.
 */
class TagChunk extends Chunk {
  /**
   * This is the backing field for {@link #getTag}.
   */
  final String tag;

  /**
   * This is the backing field for {@link #getLabel}.
   */
  final String label;

  /**
   * Construct a new instance of {@link TagChunk} using the specified label
   * and tag.
   *
   * @param label The label for the tag. If this is {@code null}, the
   * {@link TagChunk} represents an unlabeled tag.
   * @param tag The tag, which should be the name of a parser rule or token
   * type.
   *
   * @exception IllegalArgumentException if {@code tag} is {@code null} or
   * empty.
   */
  TagChunk(this.tag, {this.label}) {
    if (tag == null || tag.isEmpty) {
      throw new ArgumentError.value(tag, "tag", "cannot be null or empty");
    }
  }

  /**
   * Get the tag for this chunk.
   *
   * @return The tag for the chunk.
   */
  String getTag() {
    return tag;
  }

  /**
   * Get the label, if any, assigned to this chunk.
   *
   * @return The label assigned to this chunk, or {@code null} if no label is
   * assigned to the chunk.
   */

  String getLabel() {
    return label;
  }

  /**
   * This method returns a text representation of the tag chunk. Labeled tags
   * are returned in the form {@code label:tag}, and unlabeled tags are
   * returned as just the tag name.
   */
  String toString() {
    if (label != null) {
      return label + ":" + tag;
    }

    return tag;
  }
}

/**
 * Represents a span of raw text (concrete syntax) between tags in a tree
 * pattern string.
 */
class TextChunk extends Chunk {
  /**
   * This is the backing field for {@link #getText}.
   */

  final String text;

  /**
   * Constructs a new instance of {@link TextChunk} with the specified text.
   *
   * @param text The text of this chunk.
   * @exception IllegalArgumentException if {@code text} is {@code null}.
   */
  TextChunk(this.text) {
    if (text == null) {
      throw new ArgumentError.notNull("text");
    }
  }

  /**
   * Gets the raw text of this chunk.
   *
   * @return The text of the chunk.
   */

  String getText() {
    return text;
  }

  /**
   * {@inheritDoc}
   *
   * <p>The implementation for {@link TextChunk} returns the result of
   * {@link #getText()} in single quotes.</p>
   */
  String toString() {
    return "'" + text + "'";
  }
}
