# Conditional Expressions
The `if` keyword is used to conditionally evaluate an expression.  It is followed by two expressions.  The first expression is always evaluated, and its result is coerced to `bool`.  If the result is `true` then the second expression is evaluated, and becomes the `if` expression's result.  Otherwise the `if` expression's result is `nil`.

The type of the `if` expression is the peer type resolution of the second expression and `nil`.  In other words, the second expression's result type is made optional, if it is not already.
```foot
expr_when_true: T = ...
result : ?T = if condition expr_when_true
```

## Interaction with Procedural Blocks
Often the target of an `if` expression will be a procedural block, leading to something that looks more like an if statement in C-like languages:
```foot
if condition {
    // ...
}
```
This works just like you would expect; if the condition evaluates to false, the entire procedural block is not executed.  But now let's consider the ubiquitous `if...else` loop familiar to almost all C-derrived languages:
```foot
if condition { 
    // ...
} else {
    // ...
}
```
In Foot, the result of a procedural block is `nil` when no `break` expression is executed within it, and `else` is the nil-coalescing operator, which means in this case the `else` clause would be executed regardless of whether the condition was true.  That's both unintuitive and unhelpful, so Foot makes a special case for procedural blocks that occur as the target of an `if` expression: they behave as if they ended with `break @done`.  Since `@done` is not `nil`, this makes `if ... else` (and `if ... else if ... else`, etc.) behave just like someone familiar with C would expect.

Explicitly using `break nil` (or something equivalent, like `continue`) will still cause the result of a procedural `if` block to be `nil`, so any `else` clause would be executed.

## Optional Unwrapping
An `if` expression can also be used to conditionally evaluate an expression, based on whether or not an optional value is `nil`:
```foot
optional_value : ?T = ...
if non_optional_value := optional_value result_expression
```
A new scope is created and `non_optional_value` becomes available in `result_expression`.  Multiple optionals may be unwrapped simultaneously; the result expression will only be evaluated if none of the optionals are `nil`:
```foot
if a := maybe_a, b := maybe_b {
    // something with a, b
}
```
The optional expressions will be evaluated from left to right, one at a time, and once one is discovered to be `nil`, any remaining optional expressions will not be evaluated.  The result of the `if` expression will then be `nil`.

If an optional is unwrapped with a `mut` type modifier, then its location will overlap with the optional's location, such that any changes to it will affect the original optional.
