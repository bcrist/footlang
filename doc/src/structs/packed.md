# Packed Structs
```foot
packed struct {
    .x: u5
    .y: u11
}
```

Packed structs do not guarantee that fields are byte aligned, except the first.  They are stored as if the bits of each field's data were concatenated (the first field is the LSB) and then the resulting bitstring is written in little-endian order

The types of all fields in a packed struct have an implicit `packed` flag such that when you try to take a pointer to a packed field, you get a `&packed T` pointer, which includes a bit offset as well as address.

Similarly, taking a slice or pointer to an array within a packed struct yields a packed pointer or slice.