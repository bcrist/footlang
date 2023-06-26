# Unit Types
A struct that contains no fields (or only fields with zero size) is known as a _unit type_, because it holds no data, therefore it has only one possible "value."

Unlike normal structs, unit type structs may be coerced to their single constant value, and vice versa, as necessary.

Unit types are normally given an anonymous dimension in order to make them distinct.  The following are all equivalent ways to declare a unit type:
```foot
A :: struct {} in @dim
B :: distinct struct {}
C :: @unit
```

## Built-in Unit Types
The `nil` keyword is a built-in unit type for use with [Optional Types]().
`@done` is a predefined unit type for use with `break` when exiting a loop without a value.  It is also returned automatically from procedural blocks in the result expression of an `if`.
