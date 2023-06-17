# `unreachable` and `@noreturn`
A union without any fields has no possible values, meaning it can't exist at runtime.  Empty unions will never affect the result of peer type resolution.

`unreachable` is an expression whose type is `union {}`.  The compiler can assume that any expression having an empty union type will never be evaluated, so in non-optimized builds, it will replace the evaluation of `unreachable` with `@assert false`.

The `@noreturn` built-in is syntactic sugar for `union {}`.  Even though it's slightly more characters, it communicates intent more clearly in some cases.

# `bool`
The `bool` type is a predefined union that is used in a variety of ways:
* Result type for comparison operators (except `<=>`)
* Operand and result type for logical operators
* Accepted by [`if`](../expr/if.md) and [`while/until`](../expr/while.md) 
It is defined as:
```verdi
bool :: union : u1 {
    0 => .false
    1 => .true
}
true :: bool.true
false :: bool.false
```

# `cmp`
The `cmp` type is a predefined union that is the result type for the `<=>` operator; typically used for sorting:
```verdi
cmp :: union : s2 {
    -1 => .less
    0 => .equal
    1 => .greater
}
```
