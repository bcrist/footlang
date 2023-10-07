# Source Encoding

The Foot compiler operates on sequences of 8-bit bytes.  These are assumed to be UTF-8 encoded text, but the only byte values with special semantic meaning are ASCII characters:

* Newlines: 0x0A,
* Linespace: 0x09, 0x0D, 0x1F, 0x20
* Decimal Digits: 0x30 - 0x39
* Letters: 0x41 - 0x5A, 0x61 - 9x7A
* Special Symbols: 0x2E, 0x5F
* Operators: 0x21 - 0x2D, 0x2F, 0x3A - 0x40, 0x5B - 0x5E, 0x60, 0x7B - 0x7E

The remaining C0 control characters are not allowed anywhere within a Foot source file, and will be reported as an invalid character:

* 0x00 - 0x08
* 0x0B - 0x0C
* 0x0E - 0x1E
* 0x7F

When the compiler is run with the `allow_utf8` option, all bytes from 0x80 - 0xFF are considered the same as letters in identifiers and string literals, otherwise they are not allowed at all and the source file must be pure ASCII.

## Linting

Even though the compiler may accept some files which are not well-formed UTF-8 encoded text, tools which produce Foot code should ideally ensure that the following assumptions hold:

* Files consist entirely of valid UTF-8 codepoint encodings.
* Codepoints which can be encoded in multiple ways use the canonical (shortest) encoding.
* All 0x0D characters are immediately followed by 0x0A (bare CRs are not considered newlines; make sure they're part of a CRLF sequence).
* If any lines end with 0x0D, 0x0A (CRLF) then all of them should.
* Unicode C1 control characters (U+0080 - U+00A0) are not used.
* The UTF-16 surrogate code units (U+D800 - U+DFFF) are not used, either individually or in pairs.
* The BOM character (U+FEFF) is not used.
* The Unicode "Specials" block (U+FFF0 - U+FFFF) is not used.
* Non-printing codepoints are not used, except for the ASCII characters noted above.
    * This includes all characters from `C` and `S` categories, except as noted above.
    * If there is a legitimate need for these, they should be encoded using unicode escapes in string literals.
* All identifier tokens should be in normalized form KD
* All string literals should be in normalized form D

Tools which don't include full unicode support may skip some of these (particularly the last three).

## Unit Separators

You may notice that ASCII 0x1F is listed above as a valid character.  This is the Unit Separator (US) character, which is defined to have application-specific semantics.  The Foot compiler treats it the same as it would treat a space or tab character (except within string literals).  They are intended to work somewhat like [elastic tabstops](https://nick-gravgaard.com/elastic-tabstops/), but that idea never caught on, and it has a big problem of not degrading gracefully in software that doesn't support it.  The actual alignment in our case is done by automatically inserting spaces preceding the US character, so software that doesn't understand this convention will generally show the US character as a symbol (often a triangle), but will still align the lines correctly for viewing.

Note that Unit Separators are entirely optional and have no effect on Foot language semantics.  If you don't like them it's safe to strip them out.

### Examples
Cleaner indentation for types and values defined within long expressions:
```foot
some_long_declaration_name : []Some_Type : .[ ▼first_value  ▼,\
                                              ▼second_value ▼,\
                                              ▼third_value  ▼,\
                                              ▼fourth_value ▼]
```

Tabular alignment of many near-identical declarations or statements:
```foot
abc     ▼:: "Hello"
asldkfj ▼:: "World"
a1      ▼:: 222
a2      ▼:: 444
asdf3   ▼:: 234
asdf44  ▼:: 432
```

Within string literals, US characters are ignored, but they can still be used in the source code to create pre-formatted tables that automatically adjust when edited:
```foot
\\ +------------▼+--------▼+----------▼+
\\ | apples     ▼| $0.49  ▼|          ▼|
\\ | tangerines ▼| $2.22  ▼|          ▼|
\\ | oranges    ▼| $0.39  ▼| On Sale! ▼|
\\ | peanuts    ▼| $14.99 ▼|          ▼|
\\ +------------▼+--------▼+----------▼+
```

### Editor Support
Foot editors are encouraged to deal with US characters as follows:

* When the cursor is just before a US character, and a request is made to move the cursor to the left, it should skip over as many copies of the preceding character as possible.
    * When the cursor is just after a US character, and a backspace request is made, it should delete the US character, plus all the "padding" characters preceding it.
* When there is only one type of character between the current cursor and the next US character, and a request is made to move the cursor to the right, it should skip over all of the identical characters and end up just before the US character.
    * When the "delete character to the right" action is used, the above logic should also apply, but the US character itself should also be deleted.
* If the tab key is pressed, move the cursor to just after the next US character on the current line, then select all the text in that "cell".
    * If there is another US character to the right, apply the "move left" logic from that point to find the end of the "cell".
    * If there is no US character to the right, move to the end and insert a US character instead.
    * If the shift key is held, move to the left instead of to the right.
    * Skip this in cases where the editor would normally treat the tab key as a request to indent (e.g. when at the beginning of the line)
* When text is inserted or deleted, if a US character was added, or if the line contains a US character to the right of the edit, run the Unit Separator Adjustment Algorithm (below).
    * The algorithm may need to be run multiple times, starting at the location just preceeding each inserted US, and/or just preceeding the first pre-existing US character after the edit.
* Visually, US characters aligning above/below one another should ideally appear as a vertical bar, with no break between lines, and distinct from `|` characters.  They should appear in a color that does not contrast highly with the background.

### Unit Separator Adjustment Algorithm
* Let `n` be the number of US characters to the left on the current line, plus one (to include the US character currently being processed).
* Collect all lines above and below the current line that contain at least `n` US characters.
* For each line:
    * Place the cursor just before the `n`'th US character on the line.
    * Move one character to the left.
    * While the character on the left and right side of the cursor is the same, move to the left.
        * If this is the original line that we started on, don't move left past the original cursor's column index (this allows manually inserting spaces at the end of the currently longest "cell").
    * Let `min_col` refer to the column offset at this point.
* Let `max_col` be the maximum value of `min_col` across all of the lines.
* For each line:
    * Place the cursor just before the `n`'th US character on the line.
    * Move one character to the left.
    * Let `col` be the current column offset at this point.
    * If `col > max_col`, delete characters to the left until they are equal.
    * If `col < max_col`, copy the character on the right side of the cursor onto the left side, until they are equal.

Note this algorithm is idempotent; running it on text that has already been correctly adjusted will have no effect.

TODO: double US for right-aligned cells?  e.g.
 1234.12 ▼▼
    1.04 ▼▼
  123.33 ▼▼
