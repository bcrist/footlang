# Symbols
Symbols are similar to normal identifiers, in that they both refer to named things defined elsewhere, but instead of following normal identifier lookup rules, symbols resolve only when they are coerced to a different type, and their resolution depends on the type they are being coerced to.

## Literals
Symbol literals always start with a `.`:
```foot
.hellorld
.true
.asdf_123
```

Just like regular identifiers, symbols with arbitrary names may be constructed from string literals:
```foot
.@"Don't Do This\r\nPlease!"
```

## Constants and Identity
Symbols may be assigned to constants, and may be compared with each other for equality.  The symbol name may be extracted as a constant string.
```foot
symbol :: .asdf
symbol_name: []u8: *@nameof symbol

main :: fn {
    @assert @typeof symbol == @symbol
    if symbol == .asdf { ... }
}
```

No other types can be coerced to `@symbol`, so once a symbol has been coerced to a concrete type, it can't be compared with other symbols directly anymore

## Declarations within types
One common use case for symbols is to reference declarations within a type:
```foot
A :: distinct s32 {
    some_special_value :: 0xDEADBEEF as A
}

something: A: .some_special_value
// is the same as:
something: A: A.some_special_value
```

## Struct and union fields
If a symbol's name matches a field name it resolves to that field's type.  For structs this is rarely useful, since the types of struct fields are rarely related to the struct type itself.  But for unions, this can be very useful:
```foot
U :: union {
    .abc
    .def: s32
}

x: U = .abc // unit type coerces to its unit value, which coerces to a union value

// these are equivalent:
y1: U = 0 as .def // same as 0 as s32
y2: U = .def.{0} // same as s32.{0}
```

## Function calls
When a function is called using a normal identifier, the types of both operands will be searched for overloads, as well as the current scope, but the type of the result will not normally be searched.  If the function call uses a symbol instead of an identifier, then the outward-in inferred result type will be searched for overloads, and _only_ that type will be searched.  For example:
```foot
S :: struct {
    .a: s32,
    .b: s32,
    
    init: fn a: s32, b: s32 {
        return S.{ .a = a, .b = b }
    }
}

something: S = 123 '.init' 456
// is equivalent to
something := 123 'S.init' 456

// but this is a compile error, since there is no outward-in inferred type:
error := 123 '.init' 456
```

## Coercion to `@type`
If a symbol is coerced to `@type`, it becomes a union type with one `@unit` field of the same name.  For example the following declarations are equivalent:
```foot
A: @type: .hello
B :: union { .hello }
C :: union { .hello: @unit }
```

## Coercion with `as`
If an expression is coerced using the `as` operator, and a symbol appears as the right hand side, it will look for a matching declaration using outward-in type inference, and if that fails, then inward-out inference.  For example:
```foot
T :: distinct u8 {
    X :: u64
}

E :: union {
    X: u8
    Y: u64
}

t : T = 13
e : E = t as .X // u8 coercion (outward in), followed by union coercion
// To avoid this behavior, use a temporary declaration with type inference:
x := t as .X  // u64 coercion (inward out)
t2 : E = x    // union coercion
```
This might seem confusing, since `as` normally requires a `@type` value on the right side, so you might expect that the symbol would turn into a new anonymous union type here.  But that behavior isn't useful here, so we explicitly override with behavior that is useful in this case.