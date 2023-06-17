# Arrays
An array is a constant number of homogeneous values (i.e. having the same type), laid out sequentially in memory.  A single value within the array is known as an _element_.  Each element in an array is identified by its _index_.  The type of the index must be a fixed point type, a unit type, or a union containing only unit type fields.

## Array Types
The `[ ... ]` prefix operator turns an element type into an array type.  The type of the index is placed within the brackets, and the type of the element is placed on the right.
```verdi
A :: [u4] u32       // 16 elements, indexed 0-15
B :: [bool] s64     // 2 elements, indexed by false and true
```

Since most arrays are indexed using integers starting from 0, there is syntactic sugar to support that:
```verdi
X :: [3]u32 // equivalent to [@fixed 0~3]u32
```

The `mut` type modifier can be placed either before the `[]` or after; they both result in all the array elements becoming mutable.  Placing it after is recommended, for symmetry with pointer and slice type literals.

## Element Ordering
Elements are laid out according to the natural ordering of their index type.  For example, if we have an array  `a : [s4]s32` then `a[-8]` is the first element and `a[7]` is the last.

Arrays can be nested, where the element type of the "outer" array is itself an array:
```verdi
c : [u1][u1][s2]u8 = ---
// total of 16 elements, laid out in order:
// c[0][0][-2]
// c[0][0][-1]
// c[0][0][0]
// c[0][0][1]
// c[0][1][-2]
// c[0][1][-1]
// c[0][1][0]
// c[0][1][1]
// c[1][0][-2]
// c[1][0][-1]
// c[1][0][0]
// c[1][0][1]
// c[1][1][-2]
// c[1][1][-1]
// c[1][1][0]
// c[1][1][1]
```


## Array Literals
The `.[]` operator creates an array value when applied to a type:
```verdi
u32.[ 0, 1, 2 ]
```
By default, the index type is `@fixed 0 ~ n` where `n` is the number of values provided, however this can be changed if the inferred type's index type is different.  In fact, the element type may omitted when it can be inferred from context as well:
```verdi
.[ 2, 3, 4 ] as [3]u32
```

## Operations
* `X.len` is a numeric constant corresponding to the array length.
* `X.last` is the index of the last element of the array.
* `X.range` is the inclusive range from 0 to `last`
* `X.Index` is a fixed-point type capable of storing every valid index for the array (and no other values).
* `X.Range` is a range type that can hold any subset of `X.range`
* `X.Element` is the element's type.
* `++` concatenates two arrays of the same element type.
* `**` repeats an array a fixed number of times.  One side must be a non-negative integer constant.
* `X[X.Index]` accesses an individual element in an array.
* `X[X.Range]` creates a slice corresponding to part of an array.



