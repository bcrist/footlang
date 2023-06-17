# Ranges
A range represents a subset of the possible values that a fixed-point type may store.

## Type Literals
A range type is defined using the `@range` built-in, along with the fixed-point type that can represent each value in the range (and possibly more):
```
X :: @range s32
Y :: @range u16x16
```

## Operations
* `R.Type`: The fixed-point type of values within the range
* `r.first`: The minimum value of the range
* `r.last`: The maximum value of the range
* `r.span`: Equivalent to `r.last - r.first`
* `r.count`: The number of distinct values in the range
* `r.end`: Equivalent to `r.last + r.Type.ulp`
* `r[x]`: Equivalent to `(r.first + x) as r.Type`
* `r1[r2]`: Equivalent to `(r1.first + r2.first) ~~ (r1.first + r2.last)`, where the result's `last` is not greater than `r1.last`.
* `r.contains' x`: Bounds checking
* `for x := r ...`: Iteration
* `x 'expand' y`: Expand to contain another range or fixed point value
* `x 'intersect' y`: Contract to the intersection of two ranges

## Memory Layout
A range is stored as the minimum and maximum values within the range.

## Range Literals
The `~~` operator creates a range from minimum and maximum operands.  If the operands are rational constants, they must be integers, and the type of the range will be as small as possible.
```
// 0, 1, 2, 3, 4, 5
0 ~~ 5
```

The `~` operator works like `~~`, except the maximum value is one ULP less than the right side:
```
// 0, 1, 2, 3, 4
0 ~ 5
```

If one side of the the `~` or `~~` operators is omitted, it is inferred based on the minimum/maximum value of `Range.Type`.  Sometimes it may be necessary to wrap such a range literal in parentheses to avoid ambiguity.  Creating a range with the maximum span can be done with:
```
T :: @fixed ...
(~~) as @range T
```

## Type Coercion
A range type may be coerced to a different range type, as long as every possible range in the original range type can also be represented in the new range type.
