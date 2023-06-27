# Scope Expressions
The `with` keyword allows one or more declarations to be added to a new scope, and used to evaluate an expression, without creating a new procedural block:
```foot
with x := something, y := something_else expression
```
Usually `with` is used in conjunction with another control flow expression, like `if`, to avoid excessive indentation or polluting the enclosing block:
```foot
with x := whatever if x == something {
    do_something' x
}
```
Or a loop:
```foot
with x := whatever repeat {
    // ...
} until x == end_condition
```

## Isolated Scopes
A `with only`  expression works just like a normal `with` expression, but it restricts access to any non-constant declarations from enclosing procedural blocks.  This can be helpful as a first step in extracting a chunk of code into a function.
```foot
x := something
y := something_else

with only a := x {
    // x and y are not in scope here but a is
}
```

## Mutability and Location
Declarations in a `with` expression always act like normal declarations within a procedural block; If you declare a mutable variable, changes to its value will not affect the original value used to initialize it.
