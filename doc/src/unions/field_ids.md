# Field IDs
In addition to the "payload" value, unions also store a fixed point number to identify which field is currently active.  By default, these will be integers assigned starting at 1 (note, not 0) for the first field and incrementing for each subsequent field, however the ID values may also be selected manually as well:
```foot
union {
    16 => .sixteen: u8
    17 => .seventeen: u8
    .something: u8  // The compiler will pick an ID for this field.
}
```

The active ID will be stored separately from the active field's payload value.  By default the type of the ID will be the fixed point type with ULP as close to 1 as possible, and minimum range such that all field IDs can be represented.  It can also be specified manually, but it must always be a fixed-point type:
```foot
union: u8 { .a, .b, .c }
```

If there are unused IDs in the union's ID type, the union may be marked incomplete:
```foot
incomplete union: u8 { .a, .b, .c }
```
The compiler will ensure that any [map](../expr/map.md) contains a `_` prong to handle these extra encodings.  Non-incomplete unions will always have an implicit [unreachable](builtin.md#unreachable-and-noreturn) prong for `_`.

## Embedded Payloads
It occasionally makes sense to embed one or more fields' payloads directly in the ID value by providing a list or range of ID values to correlate with a particular field.  Exactly as many values must be specified as there are permutations of the payload value, unless you use an open range, or explicitly let the compiler pick the remaining values:
```foot
union {
    1~~16 => .a: u4
    0, 18~ => .b: u4  // compiler assigns 0, 18~~33
    17, _ => .c: u4   // compiler assigns 17 and fifteen other arbitrary values
}
```
