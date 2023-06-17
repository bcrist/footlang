# String Literals

String literals are syntactic sugar for [array literals](./index.md#array-literals), where the element type has a size of at least 8 bits.  String literals are usually surrounded by double quotes:
 ```verdi
"Hellorld!"
``` 

Only printable ASCII characters, excluding the double quote, are allowed within the quotes.  This means the set of allowable octets are: 32 (space), 33 (`!`), and 35 (`#`) through 126 (`~`).  Octet 92 (`\`) is reserved for escape sequences:
```verdi
"\t" // 9; escaped tab
"\n" // 10; escaped line feed
"\r" // 13; escaped carriage return
"\q" // 34; escaped double quote
"\"" // 34; escaped double quote
"\b" // 92; escaped backslash
"\\" // 92; escaped backslash
```
The `\"` and `\\` escapes are supported due to their ubiquity in other languages, but the `\q` and `\b` forms should usually be preferred as they avoid a lot of the problems with the usual method:
* Easier to read when appearing next to a closing `"` or another escape sequence.
* Double-escaping (e.g. in code generation) doesn't require an explosion of `\` characters.
* Editors without good language support are less likely to be confused about the end of the string.
* Editors and IDEs with automatic insertion of matching quotes are less likely to do the wrong thing while you type.

A backslash preceding an opening parenthesis encodes zero or more octets:
```verdi
"\()"               // escaped empty string
"\(       )"        // escaped empty string
"\(0)"              // 0; escaped nul
"\(255)"            // 255; escaped raw byte
"\(0b1111_1111)"    // 255; escaped raw byte
"\(0x11FF00)"       // 0, 255, 17; escaped raw bytes (little-endian)
"\(0x11 0xFF 0x00)" // 17, 255, 0; escaped raw bytes
"\(U+25A0)"         // 226, 150, 160; escaped UTF8-encoded 'black square' codepoint
"\(=bGlnaHQgd29y)"  // 108, 105, 103, 104, 116, 32, 119, 111, 114; base64 encoded bytes
```
The escape sequence continues until the first closing parenthesis.  The parenthesized contents may contain any of the following:
* Nothing
	* Encodes no bytes
	* May be useful for alignment of different parts of string literals on different lines.
* An unsigned decimal integer literal
	* Must be between 0 and 255.
	* Always encodes exactly one byte.
* A hexadecimal, octal, quaternary, or binary integer literal
	* Will be encoded in little-endian, using `(b+7)/8` bytes, where `b` is the number of bits in the literal
	* Leading 0's may be added to force a longer encoding of small numbers.
* A hex unicode codepoint symbol, starting with `U+` and followed by 1-6 hex digits
	* Will be encoded using the canonical (i.e. shortest possible) UTF8 encoding.
	* The `U` and hex digits `A`-`F` are case-insensitive.
* An equals character (`=`) followed by a base64-encoded string
	- Any of the RFC-standardized base64 variants are valid:
		- `A`-`Z` represent code units 0-25
		- `a`-`z` represent code units 26-51
		- `0`-`9` represent code units 52-61
		- Either `+` or `-` are accepted as code unit 62
		- Any of `/`, `_`, or `,` are accepted as code unit 63
		- Trailing padding `=` are ignored

Multiple of the above tokens may be combined, separated by one or more spaces.
Each token will be handled as if it had been placed in its own separate `\()` wrapper.
Spaces at the beginning or end of the parenthesized escape are also allowed.

Any backslash not followed by `q`, `"`, `b`, `\`, `r`, `n`, `t`, or `(` will generate a compile error. 
A compile error will also result from `\(` without a matching `)` or where the content inside cannot be parsed as above.

When the compiler is run with the `allow_utf8` option enabled, byte values `0x80` or higher may be embedded directly in string literals instead of requiring them to be escaped, allowing most codepoints to be encoded directly as UTF8.  This is not enabled by default, because allowing the use of UTF8 as a source code encoding introduces a lot of footguns (zero-width spaces, normalization forms, etc.)

# Multi-Line String Literals
A double backslash (outside of a quoted string literal) defines a multi-line string literal.
Any following bytes are copied directly into the string constant unmodified, until the end of the line.  The end of a line is just before the first `\n` byte (LF), or one byte earlier if the previous byte is `\r` (CR).
If the next line begins with a double backslash (after any optional linespace characters) then it continues the same literal.  A single `\n` is used to separate lines regardless of what separator is used in the source code.
The string constant does not end with `\n` unless the last line is empty after the double backslash:

```verdi
\\This is all
\\the same
    \\string constant!

\\But this
\\is a different one,
\\and it ends with \n
\\
```
Note that there are no escape sequences in multi-line literals, but there are also no prohibitions on what bytes can be used, so the only binary strings that can't be represented are those that contain `\r\n` (that sequence will become just `\n`).
