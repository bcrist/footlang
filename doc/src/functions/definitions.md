# Function Definitions
A function definition looks a lot like a function type literal, but the `Left` and `Right` types are replaced with variable declarations, and a procedural block is placed at the end:
```verdi
my_func :: fn left: Left ' right: Right -> Result {
    // ...
}
```
Note that there is no initializer for `left` or `right`; the variable always gets initialized by the value provided when the function is called.

If one or both parameters are not used, the variable name can be replaced with `_`.  Otherwise the compiler will report the unused variable as an error.

When the function type can be inferred (e.g. when declaring an inline function to pass to another function) the `Left` and `Right` types may be omitted:
```verdi
meta_func :: fn _: (fn i32) {}

main :: fn {
    meta_func' fn a {
        @assert @typeof a == i32
    }
}
```

## Struct Parameters
If more than two parameters are needed, one or both sides may use an anonymous struct type:
```verdi
my_func :: fn left: Left ' right: struct { .a: s32, .b: s32 } -> Result {
    // ...
}
```
This syntax can be shortened by simply defining multiple variables:
```verdi
my_func :: fn left: Left ' a: s32, b: s32 -> Result {
    // ...
}
```
This has exactly the same type as the previous function definition, but in addition to being shorter, `a` and `b` become local variables in the function's scope, so instead of referring to `right.a`, you can just use `a`.

## Result Type Inference
If the `Result` type is not specified, instead of being assumed to be `nil`, it is inferred based on the things that may be returned by the procedural block:
```verdi
my_func :: fn {
    return 0 as s32
}
// @type_of my_func == fn -> s32
```

## Expression Functions
Functions containing a single return statement can be shortened by using `=>` followed by the return expression, instead of a procedural block:
```verdi
X :: struct {
    .value: i32
}

add :: fn lhs: X ' rhs: X => (lhs.value + rhs.value) as X
```
