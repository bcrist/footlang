# Optional Types
An optional type is any union type that has at least two fields, and exactly one of them is `nil`.

Any type can be turned into an optional type with the `?` prefix operator.
`?T` is syntactic sugar for `nil | T`.  Note that this also means that `??T == ?T`.  If you want a nested optional, it has to be defined like this:
```foot
union {
    .: nil
    .: ?T
}
```

If `T` is a pointer or a non-full-range fixed point type, then its payload will be guaranteed to be embedded in the union field ID, and the optional type will be the same size as the underlying type.

## Operations
The `else` operator can be used to replace nil with a default value:
```foot
optional else default_value
```

Optionals can be "unwrapped" with [`if`](../expr/if.md).  If the union contains more than one other field, it's generally better to use [`match`](../expr/match.md)