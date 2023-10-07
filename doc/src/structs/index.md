# Structs
Struct types represent aggregations of zero or more _fields_, where all fields exist simultaneously and are stored contiguously in memory.  A _field_ is a named and typed value.

Structs always have deterministic layout (field ordering).  Fields are always aligned to byte boundaries, and may have larger alignment requirements based on the type of the field and the target architecture.

## Type Literals
Struct types can contain both fields and declarations.  Declarations are created when a normal identifier is used on the left side of the `::` or `:=` operators.  Fields are created when a symbol literal is used on the left.
```foot
struct {
    .x: T = default_value
    .y := 1 as u32
    
    something := "this is a declaration, not a field"
}
```

If all fields of a struct have a default value, then then the struct itself is considered to have a default value.

### Anonymous Fields
Struct fields may be declared without a name.  Such fields are known as _anonymous fields_:
```foot
struct {
    .: T = default_value
    .: U
}
```
Since anonymous fields can't be accessed by name, they normally would be given unique types so that they can be accessed by type (see [Coercion](#coercion) and [Assignment](#assignment))

### Type Product Operator
In type theory, the concept of a struct is sometimes known as a _product type_.  In this vein, Foot allows the `*` operator to work on types, combining two or more types and wraping them in an anonymous struct.  All fields within this struct will also be anonymous, and the resulting struct will be undimensioned.
```foot
A * B * C == struct {
    .: A
    .: B
    .: C
}
```
Note that more than two fields can be combined with a chain of `*` operators.  If any of the operands are non-dimensioned structs, they will be flattened and their fields will be appended to the resulting anonymous struct.  Values of dimensioned struct types will be embedded as a single field in the result.

## Field Copying
Coercion, assignment, and partial assignment of structs involve copying fields from one struct to another.  If `source` is a field of type `S` in the source struct, and `dest` is a field of type `D` in the destination struct, then `source` is assigned or initialized from `dest` under one of two conditions:
* `source` and `dest` have the same name in both structs, and `S` can be coerced to `D`.
* `source` is the only field that can be coerced to `D`

## Assignment
```foot
S :: struct ...
D :: struct ...
source : S = ...
dest : D = ...

dest = source
```
The assignment above is allowed when all of the following hold: 
* `D` is non-dimensional or has the same dimension as `S`
* Every field in `dest` can be copied from exactly one field in `source`
* Every field in `source` can be copied to at least one field in `dest`

TODO: consider making normal assignment only work if the memory layout is compatible (i.e. no conversion code required).  Use `@convert` or something to indicate that a conversion is acceptable.

### With `%`
```foot
dest = source%
```
The assignment above is allowed when all of the following hold: 
* `D` is non-dimensional or has the same dimension as `S`
* Every field in `dest` can be assigned from exactly one field in `source`

## Partial Assignment
```foot
D :: struct ...
source : S = ...
dest : D = ...

dest .= source
```
The partial assignment above is allowed when exactly one of the following cases holds:
* `dest` contains exactly one field that `source` can be coerced to
* all of the following hold:
	* `S` is a struct type
	* `D` is non-dimensional or has the same dimension as `S`
	* At least one field in `dest` can be assigned from a field in `source`
	* No field in `dest` can be assigned from multiple fields in `source`
	* Every field in `source` can be assigned to at least one field in `dest`

### With `%`
```foot
dest .= source%
```
The partial assignment above is allowed when exactly one of the following cases holds:
* `dest` contains exactly one field that `source` can be coerced to
* all of the following hold:
	* `S` is a struct type
	* `D` is non-dimensional or has the same dimension as `S`
	* At least one field in `dest` can be assigned from a field in `source`
	* No field in `dest` can be assigned from multiple fields in `source`

## Coercion
```foot
D = struct ...
S = struct ...
source : S = ...
dest : D = source
```
The coercion above is allowed as long as the following assignment would be allowed:
```foot
dest2 : mut D = ---
dest2 = source
```

### With `%`
```foot
dest : D = source%
```
The coercion above is allowed as long as the following assignment would be allowed:
```foot
dest2 : mut D = ---
dest2 = source%
```

### From non-structs
```foot
D = struct ...
@require not S is .struct
source : S = ...
dest : D = source
```
The coercion above is equivalent to:
```foot
dest : D = .{ source }
```

## Destructuring
If multiple comma separated values appear on the left side of an assignment, the compiler wraps them in an anonymous struct.  The values may be variable declarations, or variable references.  Destructuring does not support partial assignment, but you can use `%` on the right side.
```foot
main :: fn {
    a : mut u32 = 0
    a, x: u8, b: _ = .{
        .x = 1
        .a = 123
        .b = 321 as u32
    }
}
```

## Mutability
If a struct value is not `mut`, then none of its fields are `mut`, even if they were declared so.  Note this is a shallow transformation; it does not affect the type of data accessible through pointers or slices.

If a struct field is not declared `mut`, but the struct itself is `mut`, then the field can only be changed after initialization by an assignment that overwrites every field in the struct.