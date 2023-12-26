/**
 * Provides a utility class that preserves the minimal memory requirements of a string and combines
 * it with the ability to access characters by grapheme, e.g. a visible character.
 */
module gstring;

import std.traits : isSomeChar, isSomeString;
import std.uni : Grapheme, byGrapheme;
import std.range : isInputRange, ElementType;

public import std.string : CaseSensitive;

@safe:

/// An alias for GString using `char` (UTF-8).
alias CGString = GString!char;

/// An alias for GString using `wchar` (UTF-16).
alias WGString = GString!wchar;

/// An alias for GString using `dchar` (UTF-32).
alias DGString = GString!dchar;

/**
 * A `GString`, or grapheme-string, is a unicode-aware string supporting simple array-index
 * operations that operate on graphemes (displayable characters).
 *
 * For example, consider the string "R̆um". At what array index is the character 'u'? Because this is
 * a UTF-8 encoded string, it is actually at index 3, not 1. "R̆" is composed of 2 unicode
 * code-points, "R" and " ̆ " (combining breve). The "R" code-point is encoded in a single byte, but
 * the combining breve requires two bytes. These two code-points are combined into a single visible
 * character (grapheme), "R̆".
 *
 * This type permits simple array-index operations based on graphemes, that is, the visible position
 * of characters. It uses a string as its undrelying storage without an additional memory footprint.
 * However, array-like operations tend to have `O(n)` complexity, because the type must compute the
 * offset of each grapheme. Thus, `GString` is best used with smaller strings, especially those that
 * need to perform operations by character position, such as in user interfaces.
 *
 * If memory is not an issue, and array-like operations by Grapheme are needed for very large
 * strings, it is better to use `dchar[]` or `Grapheme[]`.
 *
 * Params:
 * CharT = Controls the type of encoding to use. `char` => UTF-8, `wchar` => UTF-16, and
 *         `dchar` => UTF-32.
 */
struct GString(CharT)
if (isSomeChar!CharT) {
  alias StringT = immutable(CharT)[];

  /// The underlying stored string using UTF encoding according to CharT.
  StringT rawString;

  this(StringT str) {
    this.rawString = str;
  }

  this(R)(R str)
  if (isSomeString!R) {
    this(toStringT(str));
  }

  /**
   * A GString can be used with libraries that operate on normal strings, however, they are treated
   * like normal strings, and these libraries should be used with caution.
   */
  alias rawString this;

  ///
  unittest {
    import std.string : capitalize;
    auto t1 = typeof(this)("test");
    assert(capitalize(t1) == "Test");
  }

  private static StringT toStringT(R)(R str)
  if (isSomeString!R) {
    static if (is(CharT == char)) {
      import std.utf : toUTF8;
      return str.toUTF8();
    } else static if (is(CharT == wchar)) {
      import std.utf : toUTF16;
      return str.toUTF16();
    } else static if (is(CharT == dchar)) {
      import std.utf : toUTF32;
      return str.toUTF32();
    }
  }

  private static StringT toStringT(C)(C ch)
  if (isSomeChar!C) {
    static if (is(CharT == char)) {
      import std.conv : text;
      return toStringT(text(ch));
    } else static if (is(CharT == wchar)) {
      import std.conv : wtext;
      return toStringT(wtext(ch));
    } else static if (is(CharT == dchar)) {
      import std.conv : dtext;
      return toStringT(dtext(ch));
    }
  }

  string toString() const {
    import std.utf : toUTF8;
    return toUTF8(rawString);
  }

  wstring toWString() const {
    import std.utf : toUTF16;
    return toUTF16(rawString);
  }

  dstring toDString() const {
    import std.utf : toUTF32;
    return toUTF32(rawString);
  }

  /**
   * Returns the i'th displayable character (Grapheme) within the `GString`.
   *
   * Complexity: `O(i)`. Each Grapheme is composed of a variable number of code-points, and
   * code-poinst are composed of a variable number of characters (code-units).
   */
  Grapheme opIndex(size_t i) {
    import std.range : drop;
    return rawString.byGrapheme.drop(i).front;
  }

  ///
  unittest {
    auto t1 = typeof(this)("Test R̆ȧm͆b̪õ.");
    assert(t1[3].length == 1);
    assert(t1[3][0] == 't');
    assert(t1[5].length == 2);
    assert(t1[5][0] == 'R' && t1[5][1] == '\u0306');
    assert(t1[6].length == 2);
    assert(t1[6][0] == 'a' && t1[6][1] == '\u0307');
  }

  /**
   * Returns a range of Graphemes representing the original string.
   *
   * To retrieve a string, use `toString()`, `toWString()`, or `toDString()`.
   *
   * Complexity: `O(length)`
   */
  Grapheme[] opIndex() {
    import std.array : array;
    return rawString.byGrapheme.array;
  }

  /**
   * Creates a data structure to represent the 0'th index during array slicing,
   * e.g. `gstring[i..j]`.
   */
  size_t[2] opSlice(size_t dim = 0)(size_t i, size_t j)
  {
    return [i, j];
  }

  Grapheme[] opIndex()(size_t[2] slice) {
    import std.range : drop, take, array;
    return rawString.byGrapheme.drop(slice[0]).take(slice[1]-slice[0]).array;
  }

  unittest {
    auto t1 = typeof(this)("Test R̆ȧm͆b̪õ");
    assert(t1[2..7] == typeof(this)("st R̆ȧ")[]);
  }

  /// Replaces a single grapheme in the GString.
  void opIndexAssign(R)(R str, size_t i)
  if (isSomeString!R) {
    opIndexAssign(Grapheme(str), i);
  }

  /// ditto
  void opIndexAssign(C)(C ch, size_t i)
  if (isSomeChar!C) {
    opIndexAssign(Grapheme(ch), i);
  }

  /// ditto
  void opIndexAssign(Grapheme g, size_t i) {
    import std.uni : graphemeStride;
    import std.array : array;

    ptrdiff_t charIdx = 0;
    for (int idx = 0; idx < i; idx++, charIdx += rawString.graphemeStride(charIdx)) {}

    ptrdiff_t nextCharIdx = charIdx + rawString.graphemeStride(charIdx);
    rawString = rawString[0..charIdx] ~ toStringT(g[].array) ~ rawString[nextCharIdx..$];
  }

  ///
  unittest {
    auto t1 = typeof(this)("Test R̆ȧm͆b̪õ");
    t1[6] = Grapheme("a");
    assert(t1.rawString == "Test R̆am͆b̪õ");  // Reduces string size.
    t1[6] = Grapheme("ȧ");
    assert(t1.rawString == "Test R̆ȧm͆b̪õ");  // Increases string size.
    t1[7] = "m";
    assert(t1.rawString == "Test R̆ȧmb̪õ");
    t1[8] = 'b';
    assert(t1.rawString == "Test R̆ȧmbõ");
  }

  /// Enables the use of `foreach (Grapheme; ...)` statements.
  int opApply(scope int delegate (Grapheme) @safe dg) {
    foreach (grapheme; rawString.byGrapheme) {
      int result = dg(grapheme);
      if (result)
        return result;
    }
    return 0;
  }

  ///
  unittest {
    auto t1 = typeof(this)("Test R̆ȧm͆b̪õ");
    StringT nakedString;
    StringT nakedExpected = "Test Rambo";
    foreach (g; t1) {
      nakedString ~= g[0];
    }
    assert(nakedString == nakedExpected);
  }

  /// Enables the use of `foreach (size_t, Grapheme; ...)` statements.
  int opApply(scope int delegate (size_t index, Grapheme) @safe dg) {
    size_t index = 0;
    foreach (grapheme; rawString.byGrapheme) {
      int result = dg(index, grapheme);
      if (result)
        return result;
      index++;
    }
    return 0;
  }

  ///
  unittest {
    auto t1 = typeof(this)("Test R̆ȧm͆b̪õ");
    StringT nakedString;
    StringT nakedExpected = "Test Rambo";
    size_t isum = 0;
    foreach (i, g; t1) {
      isum += i;
      nakedString ~= g[0];
    }
    assert(isum == 1 + 2 + 3 + 4 + 5 + 6 + 7 + 8 + 9);
    assert(nakedString == nakedExpected);
  }

  /// A binary operator to allow appending with a Grapheme.
  typeof(this) opBinary(string op : "~")(Grapheme g) {
    import std.array : array;
    return typeof(this)(rawString ~ toStringT(g[].array));
  }

  /// ditto
  typeof(this) opBinaryRight(string op : "~")(Grapheme g) {
    import std.array : array;
    return typeof(this)(toStringT(g[].array) ~ rawString);
  }

  ///
  unittest {
    auto t1 = typeof(this)("Test ");
    auto t2 = t1 ~ Grapheme("A");
    assert(t2.rawString == "Test A");
    auto t3 = Grapheme("B") ~ t1;
    assert(t3.rawString == "BTest ");
  }

  /// A binary operator to allow appending with arbitrary strings.
  typeof(this) opBinary(string op : "~", R)(R str)
  if (isSomeString!R) {
    return typeof(this)(rawString ~ toStringT(str));
  }

  /// ditto
  typeof(this) opBinaryRight(string op : "~", R)(R str)
  if (isSomeString!R) {
    return typeof(this)(toStringT(str) ~ rawString);
  }

  ///
  unittest {
    auto t1 = typeof(this)("Test ");
    auto t2 = t1 ~ "A";
    assert(t2.rawString == "Test A");
    auto t3 = t1 ~ "B"w;
    assert(t3.rawString == "Test B");
    auto t4 = t1 ~ "C"d;
    assert(t4.rawString == "Test C");
    auto t5 = "D"w ~ t1;
    assert(t5.rawString == "DTest ");
  }

  /// A binary operator supporting appending a single character.
  typeof(this) opBinary(string op : "~", C)(C ch)
  if (isSomeChar!C) {
    import std.conv : to;
    return typeof(this)(rawString ~ to!CharT(ch));
  }

  /// ditto
  typeof(this) opBinaryRight(string op : "~", C)(C ch)
  if (isSomeChar!C) {
    import std.conv : to;
    return typeof(this)(to!CharT(ch) ~ rawString);
  }

  ///
  unittest {
    auto t1 = typeof(this)("Test ");
    auto t2 = t1 ~ 'A';
    assert(t2.rawString == "Test A");
    auto t3 = t1 ~ cast(wchar) 'B';
    assert(t3.rawString == "Test B");
    auto t4 = t1 ~ cast(dchar) 'C';
    assert(t4.rawString == "Test C");
    auto t5 = cast(dchar) 'D' ~ t1;
    assert(t5.rawString == "DTest ");
  }

  /// Allows appending to an existing GString using the `~=` operator.
  void opOpAssign(string op : "~", R)(R str)
  if (isSomeString!R) {
    this.rawString ~= toStringT(str);
  }

  /// ditto
  void opOpAssign(string op : "~", C)(C ch)
  if (isSomeChar!C) {
    this.rawString ~= toStringT(ch);
  }

  /// ditto
  void opOpAssign(string op : "~")(Grapheme g) {
    import std.array : array;
    this.rawString ~= toStringT(g[].array);
  }

  ///
  unittest {
    auto t1 = typeof(this)("Test");
    t1 ~= "R᪶";
    assert(t1.rawString == "TestR᪶");
    t1 ~= 'ö';
    assert(t1.rawString == "TestR᪶ö");
    t1 ~= Grapheme("b");
    assert(t1.rawString == "TestR᪶öb");
  }

  /// Finds the grapheme-index of the given search string.
  ptrdiff_t indexOf(R)(R str)
  if (isSomeString!R) {
    import std.algorithm : startsWith;
    import std.uni : graphemeStride;

    StringT target = toStringT(str);
    ptrdiff_t index = 0;
    for (ptrdiff_t i = 0; index < rawString.length; index += rawString.graphemeStride(index), i++) {
      if (rawString[index..$].startsWith(target)) {
        return i;
      }
    }
    return -1;
  }

  ///
  unittest {
    auto t1 = typeof(this)("Test R̆ȧm͆b̪õ R̆ȧm͆b̪õ");
    assert(t1.indexOf("ȧ") == 6);
    assert(t1.indexOf("m̪") == -1);
  }

}

///
unittest {
  auto t1 = CGString("Test R̆ȧm͆b̪õ");
  assert(t1.indexOf("ȧ") == 6);
  assert(t1.indexOf("m̪") == -1);
  t1[9] = "í";
  assert(t1.toString() == "Test R̆ȧm͆b̪í");
}
