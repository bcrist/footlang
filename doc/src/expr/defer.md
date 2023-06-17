# Defer Statements
The `defer` keyword creates a statement that allows an expression to be delayed and only evaluated when execution leaves the procedural block that contains it (whether normally or by `return`/`break`/`try`).

A deferred expression must also be a statement (i.e. it must have a zero-size result type), and it may not contain a `return` or `try` expression.

If a procedural block contains multiple deferred expressions, they are executed in the reverse order that they were declared.

## Error Defer
The `errordefer` keyword works just like `defer`, but the expression only gets evaluated when the value being returned has dimension `@error` or is a union whose active field has dimension `@error`.

Using `errordefer` helps clean up resources that would have been returned or cleaned up later in the function, in the event that an error causes the function to return early.