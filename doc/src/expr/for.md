# Iteration Loops
The `for` keyword allows an expression to be evaluated once for each item in an array, slice, or range, or each field in a struct or union type.  The name used to refer to each value is set up using a variable declaration, and that name is visible in the scope of the expression that appears after it:
```verdi
// iterate an array:
a :: u32.[ 1, 2, 3, 4 ]
for x := a {
    // ...
}

// or a slice:
for x := a[1~3]  call_some_func' x

// or a range:
for x := 0 ~ 10 {
    // ...
}

// or a type:
S :: struct {
    .a: u32,
    .b: u32,
    .c: u8,
}
for info := S {
    // info is a tuple containing the field's symbol and type
}
```

## Mutable Array/Slice Access
When iterating over an array or slice, the declarations in a `for` loop have the same location as the actual data in the array/slice, so if you declare it to be mutable, you can change the data within the original array/slice:
```verdi
mutable_array : [4] mut u32 = ---
for x : mut = mutable_array {
    x = 1
}
@assert mutable_array[0] == 1
@assert mutable_array[1] == 1
@assert mutable_array[2] == 1
@assert mutable_array[3] == 1
```
Note in the above example, if `mutable_array` had been defined as `[4] u32` then attempting to capture the element value into a mutable declaration would be a compile error.

If you really wanted a mutable local copy, capture it immutably, then assign it to a second mutable variable:
```verdi
for x := mutable_array {
    mutable_copy : mut = x
}
```
When iterating over ranges or type fields, declarations may be marked `mut`, but they will work like normal variable declarations and will receive their own unique location.

## Reverse Iteration
A `for`'s iterable declaration may be prefixed with `@rev` to iterate it in reverse order:
```verdi
for @rev x := 0 ~ 10 {
    // 9, 8, 7, ... 0
}
```

## Multiple Sequences
A `for` expression can iterate over multiple sequences simultaneously.  The sequences must have the same length, and a runtime check is generated in safe builds to ensure this.  Some sequences may be iterated in reverse order while others may be iterated in the forward direction:
```verdi
for x := 0 ~, @rev y := 1 ~~ 10 {
    // x     y
    // 0     10
    // 1     9
    // 2     8
    // 3     7
    //   ...
    // 9     1
}
```

## Interaction with Procedural Blocks
Like `repeat`/`while`/`until` loops, a `for` loop will stop as soon as it's main expression evaluates to a non-`nil` value, so you can use procedural blocks, `break`, and `else` in the same ways.

## Destructuring
Like normal assignment statements, destructuring may be used to extract multiple parts when the element type being iterated is a struct.  One example where this can be useful is when iterating over the fields in a type:
```verdi
S :: struct {
    .a: u32,
    .b: u32,
    .c: u8,
}
for field: @symbol, type: @type = S {
    // ...
}
```