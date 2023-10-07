# Fixed-Point Numbers
Most numbers in Foot programs will be fixed-point.  Values of fixed-point types are stored as signed or unsigned binary numbers.  The type has a constant multiplier or divisor, which must be a power of 2.  This allows for the representation of (some) fractional values.

Additionally, the type tracks the minimum and maximum values that the type is allowed to represent.  This tracking allows the omission of overflow safety checks in many cases.  If two fixed point numbers only differ in their minimum and/or maximum values, then any values shared in common are guaranteed to have the same representation in memory.

## Type Literals
### Full-range integers
Any identifier starting with `u` or `s` and followed by a decimal integer N, between 0 and 65535, defines an unsigned or signed integer of N bits. The minimum and maximum values correspond to the normal `[| 0, 2^N |)` or `[| -(2^(N-1)), 2^(N-1) |)` range for binary integers.

Examples:
```foot
u0 // can only represent the value 0
u1 // 0 or 1
s8 // any integer in [-128, 127]
```

### Full-range fixed-point
A full-range integer literal, followed by `x` and a decimal integer M, between 0 and 65535, defines a full-range fixed-point type, where M is the number of additional fractional bits that exist in the LSBs of the number.  The full width 

Examples:
```foot
u4x4 // 4 integer bits, 4 fractional bits = 8 bits total
s8x4 // 8 integer bits (including 1 sign bit), 4 fractional bits = 12 bits total
```

## Creation from constant range
The `@fixed` prefix operator will turn a constant range value into a fixed point type with minimum and maximum values set according to the range:
```foot
@fixed 1~~5
```
If the range's element type is a fixed-point type, then the resulting type is a subset of the same type, just (potentially) with reduced range.  Otherwise, the range's element type must be `@rational_constant` and the bounds must be integers, and it will choose the smallest number of bits necessary to encode any integer in the range.  If it contains no negative values, then it will be unsigned.

## Creation from struct literal
The `@fixed` operator can also turn a struct literal into a type.  The literal must match one of the following struct definitions:
```foot
Operators: .all + .scalar + .offset + .comparison + .identity + .none
Rounding: .down + .up + .floor + .ceil + .half_down + .half_up + .half_floor + .half_ceil + .half_even

T: @type: ...
struct {
    .base: T
    .range: @range T = T.range
    .operators: Operators = .all
    .rounding: Rounding = .down
}
struct {
    .range: @range @rational_constant
    .operators: Operators = .all
    .rounding: Rounding = .down
}
struct {
    .range: @range @rational_constant
    .ulp: @rational_constant
    .operators: Operators = .all
    .rounding: Rounding = .down
}
```

Examples:
```foot
@fixed .{ u16, 1 ~ 1000 }
@fixed .{ 1 ~ 1000, 0.25 }
@fixed .{ u32, .identity }
@fixed .{ u32, 0.125, .half_down, .offset } // equivalent to u29x3
```

## Operations
By default, fixed-point numbers support all the operators you would expect:
* Reflection:
	* `X.base`: The full-range integral type used to store values.
	* `X.ulp`: The difference between any value and the next larger/smaller value
	* `X.range`: The range of values representable by this type
	* `X.operators`: The set of operations this type is capable of
* Identity: `==`, `<>`
	* Result is bool
* Comparison: `<`, `>`, `<=`, `>=`, `<=>`
	* Result is bool
* Offset: `+`, `-`, `-` (negation)
	* Result type's range and possibly base type may be different from operands,
* Scalar: 
	* `*`: Multiply and expand result type to avoid overflow
		* Result type may have more bits than the operands
	* `/`: Exact division; usually requires a rounding cast
		* Result type may have more fractional bits than the dividend
    * `^`: Exact exponentiation; usually requires a rounding cast
		* Result type may have more bits than the operands
	* `@tdiv`, `@tmod`: Truncated division
	* `@fdiv`, `@fmod`: Floor division
	* `@cdiv`, `@cmod`: Ceiling division
	* `@rdiv`, `@rmod`: Rounded division
	* `@ediv`, `@emod`: Euclidean division
	* `@*div` result type is always an integer
	* `@*mod` result type is always the same type as the operands
* Bitwise: `@and`, `@nand`, `@or`, `@nor`, `@xor`, `@xnor`, `@not`
	* Result type has the same base type, but probably different range.
* Shifts: 
	* `@tshr`: Shift right and truncate LSBs
	* `@eshr`: Shift right and panic if any 1 bits would be shifted out
	* `@tshl`: Shift left and truncate MSBs
	* `@eshl`: Shift left and expand the result type so that no data is lost
* Concatenation: `++`, `**`
	* Expands result type to fit all bits

Fixed point number types may be created which restrict the set of built-in operators that can be used with that type.  This is useful, for example, when using integer handles, where allowing arithmetic is undesirable.  The possible sets of allowed operators are:
* All operators
* Arithmetic operators
	* Scalar/Offset/Comparison/Identity only
* Dimension-preserving operators
	* Offset/Comparison/Identity only
* Comparison/Identity only
* Identity only
* None (values must be cast to another type to be useful)