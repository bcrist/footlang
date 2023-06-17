# Error Control Flow
Verdi does not have exceptions.  Like most systems programming languages, errors are reported as regular values.  When an expression or function has the possibility of failing, it can return a union where one or more values represent the error condition.  The caller then has the responsibility of sorting out what was returned with a `match` expression or some other way to handle the error(s).  When values are tagged as [error types](dimensions.md#error-types) some language features are available to streamline the handling of error values.

## `catch`
A `catch` expression is syntactic sugar for a `match` expression that extracts any error values from a union:
```verdi
maybe_error_expr catch e: default_on_error
// is roughly equivalent to:
with v := maybe_error_expr match v {
    e: @error => default_on_error
    _ => v
}
```
If the error value itself isn't needed, the declaration can be omitted entirely:
```verdi
maybe_error_expr catch default_on_error
// is equivalent to:
maybe_error_expr catch _: default_on_error
```
Therefore `catch` is analogous to `else` except instead of replacing `nil` with a default value, it replaces any value dimensioned with `@error` with a default value.

## `try`
Manually checking for errors can get tedious, and a lot of functions will just want to propagate any error values up to their caller, which can be done with the `try` operator:
```verdi
try expr
// is roughly equivalent to:
expr catch e: return e
```
