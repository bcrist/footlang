# Conditionally Bounded Loops
The `while` keyword allows an optional-typed expression to be evaluated repeatedly, until it becomes non-`nil`, or until a condition expression is no longer `true`, whichever happens first:
```verdi
while condition_expr optional_expr
```
`condition_expr` is evaluated before `optional_expr`, and the latter is not evaluated if it evaluates to `.false`.  The `while` expression's value is `nil` in this case.
If `optional_expr` evaluates to a non-`nil` value, the loop ends immediately. `condition_expr` is not evaluated again.  The `while` expression's value is the value from `optional_expr`.  

## `repeat`
If you always need to evaluate the loop expression at least once, you can use a `repeat`...`while` loop:
```verdi
repeat optional_expr while condition_expr
```
This works exactly the same as a regular `while` expression, except the conditional expression is evaluated _after_ the optional expression, instead of before.

## `until`
The `until` keyword works exactly like `while`, except the condition expression is complemented:
```verdi
until condition expr
// is the same as:
while not condition expr

repeat expr until condition
// is the same as:
repeat expr while not condition
```

## Interaction with Procedural Blocks
Unlike C, the `break` keyword in Verdi doesn't interact directly with loops, but it ends up having the same effect:
```verdi
x := while ... {
    // ...
    break 1234
}
```
Note that since the `while` expression evaluates to `nil` if the loop ends due to the condition being false, you can use the `else` operator with it, just like `if`:
```verdi
x := while ... {
    if ... break 1234
} else 2345
```
When you want to break out of a loop, but a value doesn't need to be extracted, you can use the built-in unit type `@done` (or any other unit type besides `nil`):
```verdi
while ... {
    if ... break @done
} else @done
```
Note the final `else @done` is required here so that the result of the expression is always `@done` and not `?@done`.  Alternatively the result could be discarded with an underscore assignment:
```verdi
_ = while ... {
    if ... break @done
}
```
Most C-like languages have a `continue` keyword that skips the rest of a loop's block, but does not break out of the loop.  In Verdi this can be accomplished without an extra keyword; instead you just need `break nil`:
```verdi
while ... {
    if ... break nil
    // processing to skip goes here...
}
```
Since this isn't very intuitive to readers that aren't familiar with the language, Verdi does provide a `continue` keyword that is exactly equivalent to `break nil`, and it is encouraged to use it where possible.

## Optional Unwrapping
Like an `if` expression, the condition expression of a `while` expression may be replaced with one or more optional-unwrapping declarations, and these declarations will be visible when evaluating the main expression:
```verdi
while a := maybe_a, b := some_func_returning_optional' nil {
    // ...
}
```
Note that the optional expression(s) will be re-evaluated every loop iteration.  If the unwrapped variables are mutable, and they are changed in the course of the loop, the changes will be overwritten at the start of the next loop.

If an optional is unwrapped with a `mut` type modifier, then its location will overlap with the optional's location, such that any changes to it will affect the original optional.

Optional unwrapping does not work with `repeat` or `until` loops.
