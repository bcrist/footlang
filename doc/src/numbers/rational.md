# Numeric Literals
All numeric literals in Verdi represent rational constants.

Decimal integers have exactly the value you'd expect:
 ```verdi
 1337 == 1000 + 300 + 30 + 7
 42   == 4 * 10 + 2
 -7   == 7 * -1
``` 

There is no limit to the range of literals:
```verdi
13407807929942597099574024998205846127479365820592393377723561443721764030073546976801874298166903427690031858186486050853753882811946569946433649006084096 == 2^512
```

## Base prefixes

A literal starting with `0x` is a hexadecimal number:
```verdi
0xF    == 15
0xFF   == 0Xff
-0x201 == -513
0b111  == 7
```

Binary, octal, and quaternary (base-4) literals are also supported:
```verdi
0b1111 == 0xF
0o777 == 0x1FF
0q333 == 0x3F
```

Unlike some languages, leading zeroes _do not_ indicate octal base; the leading 0's are simply ignored:
```verdi
01234 == 1234
0000  == 0
```

## Spacers
Underscores may be placed between digits in a numeric literal to help with readability.  There may be multiple in a row, and they may appear before the base prefix character, or the end of the literal, but the first character of the literal cannot be a spacer.
```verdi
123_456 == 12_3456
0__x__1__0__ == 16
```

## Decimal points
Digits that appear after a `.` encode rational numeric literals.  It must not be the first nor last character of the literal.
```verdi
3.1 = 31 / 10
1.23456 == 123456 / 100000
0x2.F == 0x2F / 16
0b111.011 == 59 / 8
```

# Rational Numbers
Numeric literals (and the results of certain operations on numeric literals) have an unspecified type which can be coerced to any fixed-point or floating-point type that can represent the number exactly.  If there isn't an exact representation, a [rounding cast]() may be used.  Note that once coerced to fixed or floating point type, the value is still considered constant.

Rational constants can exist at runtime, but would typically only be used in such a way for code generation.

## Operations
Addition (`+`), subtraction (`-`), and multiplication (`*`) always yield a new rational constant when both operands are rational.

Division (`/`) by zero is a compile error, but otherwise division of two rational constants yields another rational constant.

Exponentiation (`^`) is allowed when the left side is rational, and the right side is an integer.  This is because some exponentiations with fractional exponents result in irrational numbers; e.g. `2^0.5`


