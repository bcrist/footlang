# Keywords

```
and     as          bool        break       catch       continue
defer   distinct    else        error       fn          for
if      in          incomplete  is          map
mut     nil         not         only        or          packed
repeat  return      struct      union       unreachable
until   while       with
```

# Built-ins

| Usage | Description |
|---|---|
| `@fixed x` | Creates a fixed-point type from a range or struct literal |
| `@anytype` | Represents the type of types |
| `dividend @tdiv divisor` | Truncated division |
| `dividend @fdiv divisor` | Floor division |
| `dividend @cdiv divisor` | Ceiling division |
| `dividend @rdiv divisor` | Rounded division |
| `dividend @ediv divisor` | Euclidean division |
| `dividend @tmod divisor` | Truncated modulus |
| `dividend @fmod divisor` | Floor modulus |
| `dividend @cmod divisor` | Ceiling modulus |
| `dividend @rmod divisor` | Rounded modulus |
| `dividend @emod divisor` | Euclidean modulus |
| `x @and y` | Bitwise AND |
| `x @nand y` | Bitwise NAND |
| `x @or y` | Bitwise OR |
| `x @nor y` | Bitwise NOR |
| `x @xor y` | Bitwise XOR |
| `x @xnor y` | Bitwise XNOR |
| `@not x` | Bitwise NOT |
| `x @tshr y` | Truncating Shift Right |
| `x @eshr y` | Exact Shift Right (panic if any 1 bits would be shifted out) |
| `x @tshl y` | Truncating Shift Left |
| `x @eshl y` | Exact Shift Left (expand the result type so that no data can be lost) |
| `@range x` | Creates a range type from a fixed-point type |
| `@f16 x` | Creates a binary16 float from a range or struct literal |
| `@f32 x` | Creates a binary32 float from a range or struct literal |
| `@f64 x` | Creates a binary64 float from a range or struct literal |
| `@f128 x` | Creates a binary128 float from a range or struct literal |
| `@float x` | Creates a floating point type from a struct literal |
| `x @trunc` | Truncate to a full-range fixed point type |
| `x @wrap` | Wrap any out of range values into the valid range of the result type |
| `x @saturate` | Clamp any out of range values to the min/max value possible for the type |
| `x @round_zero` | Round toward zero (truncate lost precision) |
| `x @round_inf` | Round away from zero |
| `x @round_positive` | Round towards +inf |
| `x @round_negative` | Round towards -inf |
| `@round_half_zero` | Round to nearest; ties towards zero |
| `@round_half_inf` | Round to nearest; ties away from zero |
| `@round_half_positive` | Round to nearest; ties towards positive infinity |
| `@round_half_negative` | Round to nearest; ties towards negative infinity |
| `@round_half_even` | Round to nearest; ties towards closest even |
| `@noreturn` | The type of an unreachable expression; equivalent to `union {}` |
| `@dim` | Creates a new dimension |
| `@unit` | Creates a new unit type |
| `@error` | The error dimension |
| `@rational_constant` | The type of a numerical rational constant |
| `@done` | A built-in unit type |
| `@symbol` | The type of symbol expressions |
| `x @undim` | Dimension removal |
| `@assert x` | Runtime assertion |
| `@require x` | Compile-time assertion |
| `@type_of x` | Determine the result type of an expression without evaluating it |
| `@import x` | Used to import another module |
| `@export x` | Used to change the constant corresponding to the current module |
| `@module` | The type of the current module |
| `@nameof x` | Get the name of a symbol, type, or field |

# Naming Conventions

Apart from the reserved names above, users are free to use whatever naming convention they prefer, however users are encouraged to adopt the naming convention used by the standard library.  The rules of that convention are as follows:

* Type names for aggregates (structs, unions, and arrays) having non-zero size shall be rendered in "proper snake case".
* All other names shall be rendered in "lower snake case".  This includes:
    * Variable names
    * Constant names (except constants referring to aggregate types as above)
    * Function names
    * Dimension names
    * Numeric type names
    * Range type names
    * Pointer/slice type names (when assigned to an alias)
    * Empty struct/union type names (i.e. unit types and namespaces)
    * Symbol names
    * Struct and union field names
* When an identifier is created by adding a prefix and/or suffix to another identifier, the capitalization of the original identifier should be retained, but the prefix/suffix should be named as above.

## Proper Snake Case Rules

* All words are separated by underscores
* All letters within acronyms and initialisms are capitalized
* For all other words, only the first letter is capitalized

## Lower Snake Case Rules

* All words are separated by underscores
* All words use only lowercase letters and/or numbers
