# Conditionally Bounded Loops
The `while` keyword allows an optional-typed expression to be evaluated repeatedly, until it becomes non-`nil`, or until a condition expression is no longer `true`, whichever happens first:
```foot
while condition_expr optional_expr
```
`condition_expr` is evaluated before `optional_expr`, and the latter is not evaluated if it evaluates to `.false`.  The `while` expression's value is `nil` in this case.
If `optional_expr` evaluates to a non-`nil` value, the loop ends immediately. `condition_expr` is not evaluated again.  The `while` expression's value is the value from `optional_expr`.  

## `repeat`
If you always need to evaluate the loop expression at least once, you can use a `repeat`...`while` loop:
```foot
repeat optional_expr while condition_expr
```
This works exactly the same as a regular `while` expression, except the conditional expression is evaluated _after_ the optional expression, instead of before.

## `until`
The `until` keyword works exactly like `while`, except the condition expression is complemented:
```foot
until condition expr
// is the same as:
while not condition expr

repeat expr until condition
// is the same as:
repeat expr while not condition
```

## Interaction with Procedural Blocks
Unlike C, the `break` keyword in Foot doesn't interact directly with loops, but it ends up having the same effect:
```foot
x := while ... {
    // ...
    break 1234
}
```
Note that since the `while` expression evaluates to `nil` if the loop ends due to the condition being false, you can use the `else` operator with it, just like `if`:
```foot
x := while ... {
    if ... break 1234
} else 2345
```
When you want to break out of a loop, you can use the `done` keyword (or `break @done`), just like with `if`:
```foot
while ... {
    if ... done
}
```
Note that the while loops type in this case is `?@done`.

Most C-like languages have a `continue` keyword that skips the rest of a loop's block, but does not break out of the loop.  In Foot this can be accomplished without an extra keyword; instead you just need `break nil`:
```foot
while ... {
    if ... break nil
    // processing to skip goes here...
}
```
Since this isn't very intuitive to readers that aren't familiar with the language, Foot does provide a `continue` keyword that is exactly equivalent to `break nil`, and it is encouraged to use it where possible.

## Union/Optional Unwrapping
Like an `if` expression, the condition expression of a `while` expression may be replaced with one or more union-unwrapping declarations, and these declarations will be visible when evaluating the main expression:
```foot
while a := maybe_a, b : SomeUnionPayload = some_func_returning_union' nil {
    // ...
}
```
Note that the initializer expression(s) will be re-evaluated every loop iteration.  If the unwrapped variables are mutable, and they are changed in the course of the loop, the changes will be overwritten at the start of the next loop.

If an unwrapped variable is `mut` then its location will overlap with the union, such that any changes to it will affect the original union, if it has a location.  But the union is usually a temporary returned from an iterator function, so the modified value will just be overwritten by the next temporary result.

Unwrapping does not work with `repeat` or `until` loops.
