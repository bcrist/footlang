# Defer Statements
The `defer` keyword creates a statement that allows an expression to be delayed and only evaluated when execution leaves the procedural block that contains it (whether normally or by `return`/`break`/`!`).

A deferred expression must also be a statement (i.e. it must have a zero-size result type), and it may not contain a `return` or `!` expression.

If a procedural block contains multiple deferred expressions, they are executed in the reverse order that they were declared.

## Return Capture
A `defer` statement may capture the result value of the function/block that encloses it.  In this case the `=>` token separates the declaration from the deferred expression:

```foot
my_fn: fn -> u32 {
    defer x: => @io.stdout 'write_int' x catch unreachable

    return 0
}
```

The captured return variable may be declared with a type.  If so, the actual return value type must be coercible to that type, or, if the return type is a union, at least one of the union payloads must be coercible to that type (similar to a union-unwrapping `if` or `while`).  At runtime, if the return value's active field can't be coerced to the declared type, then the deferred expression is skipped.  One use case for this is running cleanup code for resources that would normally be returned from the function, in the case that
an error occurs instead:

```foot
create_thing: fn {
    the_thing := allocate_thing' nil
    defer _: @error => deallocate_thing' the_thing

    do_something_that_may_error' nil !

    return the_thing
}
```
