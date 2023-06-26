# The `any` Type
Very occasionally it's useful to have pointers whose type is only known at runtime, and that's exactly what the `any` type is for.

Any value that has an address can be coerced to `any`.  The `any` value holds a pointer to the original value, and the type that was used to initialize it.

The type can be extracted with `v.type`.
The address can be extracted with `v.addr`.

A `mut any` can be reassigned to point to a new value, but even a non-mutable `any` can refer to mutable data, if it is initialized with a value that's mutable.

A `match` expression is be used to access the original value as one of a specific set of types.

## Example
The poster-child for `any` is an equivalent to C's `printf`:
```foot
print :: fn args: []any {
    // ...
}

main :: fn {
    name := "World"
    print' .["Hello %!  My favorite number is %\n", name, 7 as u8]
}
```