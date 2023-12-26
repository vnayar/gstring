# Background

Unicode strings can be difficult to work with, due to the multi-byte encoding per unicode code-point
in UTF, as well as the fact that multiple code-points may be needed to show a glyph. Consider
[Unicode Combining Characters](https://en.wikipedia.org/wiki/Combining_character), which are
code-points whose purpose is to modify other characters. For example, the letter `R` (U+0052)
followed by the combining character ` ̆ ` (COMBINING BREVE, U+0306) produces the output `R̆`.

Unicode Transformation Format (UTF) is a method of encoding unicode code-points in a variable byte
format. In UTF-8, a single code-point can be encoded in one to four bytes. Bits are used to encoded
to deliver a "payload", which is the unicode code-point.

Consider the following UTF-8 encodings for code-points:

| **No. Bytes** | **Payload Bits** | **Byte 1**  | **Byte 2** | **Byte 3** | **Byte 4** |
|---------------|------------------|-------------|------------|------------|------------|
| 1             | 7                | 0xxxxxxx    |            |            |            |
| 2             | 10               | 110xxxxx    | 10xxxxxx   |            |            |
| 3             | 15               | 1110xxxx    | 10xxxxxx   | 10xxxxxx   |            |
| 4             | 20               | 11110xxx    | 10xxxxxx   | 10xxxxxx   | 10xxxxxx   |

Following the previous example, the COMBINING BREVE character ` ̆ ` (U+0306) is encoded in 2 bytes
as: `110_xxxxx 10_xxxxxx` => `110_011-00 10_00-0110` => `0xcc 0x86`

Putting everything together, the grapheme `R̆`, composed of two unicode code-points (U+0052 and
U+0306), encoded in a multi-byte encoding scheme like UTF-8, is represented as:
`0xxxxxxx, 110_xxxxx + 10_xxxxxx` => `01010010, 110_01100 + 10_000110` => `0x52, 0xcc + 0x86`

While the usage of Unicode and UTF has many advantages, it also has many complications in terms of
writing software. Consider the following kinds of operations which, if implemented on ASCII data,
can be trivially solved by treating characters as arrays of individual characters:
- Reversing the characters of a string.
- Searching for a sub-string.
- Embedding numbers in combined data + text binary formats.
- Extracting a substring of a certain length, e.g. getting a 3-character suffix.

# Purpose

This library exists to provide a data structure which combines the expressive power of Unicode and
UTF with the ability to write simple array-index-based algorithms, which are easy to perform on
non-unicode data. The primary inspiration is the [QString](https://doc.qt.io/qt-6/qstring.html) data
type from the [Qt framework](https://www.qt.io), however, this type does not take into account
graphemes with multiple code-points.

# Usage

Simple array operations work on unicode strings, e.g. UTF-8, according to their visible character
positions.

```
import gstring : CGString;
auto t1 = CGString("Test R̆ȧm͆b̪õ");
assert(t1.indexOf("ȧ") == 6);
assert(t1.indexOf("m̪") == -1);
t1[9] = "í";
assert(t1.toString() == "Test R̆ȧm͆b̪í");
```
