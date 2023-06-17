# Aside: Type Equivalence
In C, and most languages descended from it, most complex types use either name equivalence or identity equivalence, meaning if you define two structs with the same fields, but different names, they're entirely distinct types that can't be used interchangeably.

On the other hand, most of these languages use structural equivalence for numeric types and other built-in primitive types, meaning as long as a type has the same structure (i.e. "looks the same") as another, it is literally the same type.

Often, this behavior is exactly what we want, but there are cases where we'd rather have the opposite for both categories of types.  Languages then often need to either provide complicated standard library mechanisms or additional language features to compensate for this.

# Distinct Types
Types in Verdi always have structural equivalence.  This applies to all types, including structs and unions.  However, the structure of a type includes its _dimension_.  Types with different dimensions are never equivalent.  Unlike types, dimensions have identity equivalence, so by applying an anonymous dimension to a type, the type then effectively gains identity equivalence as well:
```
My_Pair :: struct {
	a: u32
	b: u32
} in @dim
```
The `@dim` built-in creates a new dimension, and the `in` operator applies it to the struct we defined just prior.  Since `in @dim` isn't the most intuitive syntax, generally you'd instead use the `distinct` type modifier, which is syntactic sugar that has the same meaning, but operates as a prefix instead:
```
My_Pair :: distinct struct {
	a: u32
	b: u32
}
```

Only distinct types may contain declarations.

## Dimension Removal
The `@undim` prefix operator takes a type and returns a version of the type without any dimension applied.  It can also take a value of a dimensioned type and return the same value with no dimension.

# Named Dimensions
Dimensions allow more power than just enforcing identity equivalence.  Dimensions are constants, and can therefore be declared with a name:
```
milliseconds :: @dim

fn sleep duration: usize in milliseconds { ... }

sleep' 1000 // compile error
sleep' 1000 in milliseconds // works!
```

Dimensions can also be combined to create composite dimensions, using multiplication, division, and exponentiation, and arithmetic on dimensioned numbers automatically creates a result of the proper dimension:
```
meter :: @dim
second :: @dim

my_speed: in meter/second: 0.4 in meter / 0.9 in second
```
Multiplying or dividing a dimension by itself increases or decreases the _rank_ (i.e. exponent) of that dimension.  The rank must be an integer, so exponentiation of dimensioned numbers only works when the exponent is an integer constant.  A dimension can have rank 0, making it effectively unitless, and yet still be present on a type:
```
x: u32 in meter^0 = 13 in meter / 2 in meter
```
Technically `distinct` is syntactic sugar for `in @dim^0`, not `in @dim`.  The distinction is only relevant when applied to numeric types though.  `@dim^0` does not change under multiplication or division with itself, but multiplication and division against structs or unions is not possible.

Finally, dimensions can be offset and scaled to support automatic conversions between types:
```
km :: 1000 * meter
mile :: 621.371 * meter
minute :: 60 * second
hour :: 60 * minute
kph :: km/hour
mph :: mile/hour
speed_limit_kph : kph : 60 in mph


deg_K :: @dim
deg_C :: deg_K + 273.15
deg_F :: 1.8 * deg_C + 32
boiling_F :: 100 in deg_C as deg_F

cycles :: @dim^0 // unitless dimension
radians :: cycles * @tau
degrees :: cycles * 360
```

The scale and offset of a dimension are stored as Numeric Constants, so any linear conversion equation can be represented.  When doing a conversion, these conversion constants are inlined into the conversion.  Therefore, if the conversion can't be performed exactly, a rounding cast must be performed.

There are a few other programming languages that support units of measure ([F#](https://learn.microsoft.com/en-us/dotnet/fsharp/language-reference/units-of-measure) and [Frink](https://frinklang.org/#HowFrinkIsDifferent) come to mind), but this is a very rare feature for a systems programming language.

# Coercion
An undimensioned value can be coerced to a value with the same type, but of any dimension.  Similarly, a dimensioned value can be coerced to the same type but with no dimension.  However coercion directly between dimensions is not allowed.

Additionally, coercion between _similar_ dimensions is allowed.  Dimensions are similar if they contain the same root `@dim`s with the same ranks.  Any scalar or offset transformations are ignored when checking for similarity.

Coercion between different dimensioned types is allowed if the dimension is the same, and the coercion would be allowed for undimensioned types.

# Error Types
The built-in `@error` refers to a special dimension.  When a type has this dimension (along with potentially others) it can take part in [error control flow](expr/errors.md).

When defining a type, `error T` is roughly equivalent to `T in @error`.  `distinct` and `error` may be combined to create a type with dimension `@error * @dim^0`.
