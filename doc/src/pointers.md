# Pointers
A pointer holds the address of exactly one value of a particular type.  A pointer type literal is created using the `*` prefix operator:
```foot
*T     // pointer to immutable value of type T
*mut T // pointer to mutable value of type T
```

## Referencing and Dereferencing
When the `*` prefix operator is used on a non-type value, it creates a pointer to that value.  The `*` suffix operator dereferences a pointer, accessing the value it points to.  If the tokens following the `*` suffix operator can be interpreted as an expression, then the `*` will be interpreted as multiplication, therefore parentheses may need to be used in some cases to ensure that the deference is parsed correctly:
```foot
if pointer_to_bool* { ... }
// will be interpreted as:
if (pointer_to_bool * { ... })
// and the compiler will then complain when there is no result expression.
// instead you want:
if (pointer_to_bool*) { ... }
```

## Packed Pointers
Normally pointers only give the address of a value with byte-granularity, the assumption is that the value starts at bit 0 and uses some number of bits according to its type.  Packed pointers also store a bit offset, allowing them to point to values that aren't aligned to byte boundaries.

Any regular pointer may be converted to a packed pointer, but packed pointers cannot be converted to regular pointers.

```foot
*packed T
*packed mut T
```

# Slices
A slice is a pointer to a runtime-known number of contiguous values of the same type.  That may sound similar to the definition of an array, but there are several important differences:
* There is a layer of indirection, like a pointer to an array.
* The number of values is not guaranteed to be known at compile time.
* The indexes are always unsigned integers.

A slice is larger than a regular pointer, because in addition to the location of the first value, it also stores the number of values that are allowed to be accessed through the slice.

## Type Literals
A slice type can be created with the `[]` prefix operator.  Just like pointers, slices can also refer to mutable or packed data.
```foot
Slice_of_T :: []T
Mutable_Slice :: []mut T
Packed_Slice :: []packed T
Mutable_Packed_Slice :: []packed mut T   // or []mut packed T
```
