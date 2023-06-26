# Floating-Point Numbers
Foot supports four IEEE-754 binary floating point types:
* `f16`
* `f32`
* `f64`
* `f128`

Custom and non-IEEE-754 floating point types are not supported.

## Creation from constant range
The four floating point base types may be prefixed with `@` to create variants with a limited range:
```foot
@f16 0 ~ 1
@f32 0 ~ 1
@f64 0 ~ 1
@f128 0 ~ 1
```

## Creation from struct literal
Just like `@fixed`, Instead of a constant range, a struct literal may be used to create a float type variant using `@f16`, `@f32`, etc., as long as the struct matches the definition:
```foot
T: @type: ...

Operators: .all | .offset | .comparison | .identity | .none

struct {
    .range: @range T
    .operators: Operators = .all
}
```
Additionally, the `@float` operator can be used with the definition:
```foot
struct {
    .base: T
    .range: @range T = T.range
    .operators: Operators = T.operators
}
```

## Operations
* Identity: `==`, `<>`
	* Result is bool
	* Note that floating point equality is not the same as bitwise equality.  e.g. `-0 == 0`
* Comparison: `<`, `>`, `<=`, `>=`, `<=>`
	* Result is bool
* Offset: `+`, `-`, `-` (negation)
	* Result type's range and possibly base type may be different from operands,
* Scalar: 
	* `*`: Multiply
		* Result may require overflow and/or rounding casts
	* `/`: Exact division
		* Result may require overflow and/or rounding casts
	* `^`: Exact Exponentiation
		* Result may require overflow and/or rounding casts
	* `@tdiv`, `@tmod`: Truncated division
	* `@fdiv`, `@fmod`: Floor division
	* `@cdiv`, `@cmod`: Ceiling division
	* `@rdiv`, `@rmod`: Rounded division
	* `@ediv`, `@emod`: Euclidean division
	* `@*div` result type is always an integer (fixed point)
	* `@*mod` result type is always the same (floating point) type as the operands

Like fixed point numbers, the set of allowed operations on float types may be limited:
* All operators
* Dimension-preserving operators
	* Offset/Comparison/Identity only
* Comparison/Identity only
* Identity only
* None (values must be cast to another type to be useful)