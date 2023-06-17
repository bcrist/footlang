# Operator Precedence
TODO: Very WIP...

|  | Operator | Description | Associativity |
|---|---|---|---|
| 1 | `x' x` | Prefix function call | right |
| 1 | `x 'x' x` | Infix function call | left |
| 1 | `x 'x` | Suffix function call | left |
| 2 | `(x)` | Grouping | |
| 3 | `x.x` | Member Access | left |
| 3 | `x.[...]` | Array literal | |
| 3 | `x.{...}` | Struct literal | |
| 3 | `x.(...)` | Union literal | |
| 3 | `x[x]` | Element Access, Slicing | left |
| 3 | `x~~` | Range literal: inferred end | |
| 3 | `x*` | Pointer dereference | |
| 4 | `x**x` | Constant array repetition | left |
| 5 | `x++x` | Constant array concatenation | left |
| 6 | `not x` | Logical complement | right |
| 6 | `-x` | 2's complement negation | right |
| 6 | `~x` | Range literal: inferred start, exclusive end | right |
| 6 | `~~x` | Range literal: inferred start, inclusive end | right |
| 6 | `?x` | Optional type modifier | right |
| 6 | `[x]x` | Array type modifier | right |
| 6 | `*x` | Pointer type modifier, address-of | right |
| 6 | `.[...]` | Array literal | |
| 6 | `.{...}` | Struct literal | |
| 6 | `.(...)` | Union literal | |
| 6 | `match x {...}` | Match expression | |
| 6 | `struct {...}` | Struct literal | |
| 6 | `union {...}` | Union literal | |
| 6 | `union: x {...}` | Union literal (explicit ID type) | |
| 6 | `fn ...` | Function type or definition | |
| 6 | `try x` | Error propagation | |
| 6 | `return x` | Function return | |
| 6 | `break x` | Block return | |
| 6 | `mut x` | Mutable type modifier | |
| 6 | `distinct x` | Distinct type modifier | |
| 6 | `error x` | Error type modifier | |
| 6 | `@zzzzz x` | Prefix intrinsic operators | |
| 7 | `x^x` | Exponentiation | right |
| 8 | `x*x` | Multiplication | left |
| 8 | `x/x` | Exact Division | left |
| 9 | `x+x` | Addition | left |
| 9 | `x-x` | Subtraction | left |
| 10 | `x~x` | Range literal: exclusive end | left |
| 10 | `x~~x` | Range literal: inclusive end | left |
| 10 | <code>x\|x</code> | Union type merging | left |
| 10 | `x&x` | Tuple type literal | left |
| 11 | `x as x` | Coercion | left |
| 11 | `x in x` | Dimensioning | left |
| 11 | `x is x` | Union active field test | left |
| 11 | `x else x` | Optional coalescing | left |
| 11 | `x catch x` | Error handling | left |
| 11 | `x @zzzzz x` | Binary intrinsic operators | left |
| 12 | `x<x` | Less-than | left |
| 12 | `x<=x` | Less-than or equal-to | left |
| 12 | `x>x` | Greater-than | left |
| 12 | `x>=x` | Greater-than or equal-to | left |
| 12 | `x<=>x` | Three-way comparison | left |
| 13 | `x==x` | Equality | left |
| 13 | `x<>x` | Inequality | left |
| 14 | `x and x` | Logical conjunction | left |
| 15 | `x or x` | Logical disjunction | left |
| 16 | `x#x` | Tagging | left |
