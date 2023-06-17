# Unions
Unions are tagged sum types, similar to Zig's `union(enum)` or Rust's `enum` types.  Like structs, they are aggregate types that can contain both fields and declarations.  Unlike structs, only one field of a union may hold a value at any given time.

## Type Literals
Like struct fields, each field in a union has a name and a type, and the name must be unique within the union.  Unlike struct fields, union fields cannot have default values.
```verdi
union {
    .hello: u8
    .world: u16
}
```

Multiple fields may be placed on the same line if separated by commas.

### Unit Fields
A union where all fields have a unit type is effectively equivalent to an enum in languages like C++.  Since this is a frequent use case, the type may be omitted from a union field, which is equivalent to explicitly setting it to `@unit`:
```verdi
union { .apple, .orange, .pear }
```

### Anonymous Fields
Another frequent use case for unions is representing the same kind of object, but represented by different types.  In these cases the name isn't really meaningful, so we can have anonymous fields in unions, just like structs:
```verdi
union {
    .: u16
    .: * f32
}
```

This can also be used to create function overload sets (since each function has its own distinct type)

### Type Sum Operator
Similar to the `&` operator for wrapping types in a struct, there is a `|` operator which wraps types in a union.  If any of the operands are non-dimensioned unions, they will be flattened and their fields merged with the resulting union.  Dimensioned unions will be embedded as a distinct payload type.

When merging unions, if multiple field definitions are structurally equivalent, only one of the matches will be kept.
```verdi
A :: distinct u32
B :: union {
    .apple
    .orange
}
C :: B.apple
D :: distinct union { .asdf }

A | B | C | D == union {
    .: A
    .apple: B.apple
    .orange: B.orange
    .: D
}
```

Union fields without explicitly specified IDs may have a different ID assigned by the compiler in the merged union.  If multiple fields in the merged union attempt to use the same ID explicitly, it is an error.

## Coercion
A value of type `T` may be coerced to a union type `U` in either of these cases:
* `T` can be coerced to the type of exactly one field in `U`
* All of the following conditions hold:
	* `T` is a union type
	* `U` is undimensioned, or `T` and `U` have the same dimension
	* For every field in `T` one of the following holds, where `F` is the type of the field in `T`:
		* `U` has a named field with the same name as the field in `T`, and `F` can be coerced to the field's type.
		* `F` can be coerced to the type of exactly one field in `U`

If both cases are possible, the coercion is ambiguous, and therefore not allowed.

Note that unlike structs, coercion from a union type to the type of one of its fields is not allowed.  Use [match](../expr/match.md) or [catch](../expr/errors.md) to ensure that all fields are handled.

## `is` operator
The `is` operator returns `.true` if the active field of the union value on the left matches the symbol or type on the right.  Usually it will be better to just use a [`match`](../expr/match.md), but sometimes you just want to check for one thing.

## Mutability
If a union value is not `mut`, then none of its fields are `mut`, even if they were declared so.  Note this is a shallow transformation; it does not affect the type of data accessible through pointers or slices.

If a union field is not declared `mut`, but the union value itself is `mut`, then the union can be overwritten by a newly initialized union value, but the value can't be modified after initialization (e.g. with a [`match`](../expr/match.md)).
