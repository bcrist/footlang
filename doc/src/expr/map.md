# Map Expressions
A `map` expression contains a list of _prongs_.  Each prong consists of a list of patterns and another expression to evaluate if the original expression matches one of the patterns.
```foot
query_expr map (
    map_list1 => expression1
    map_list2 => expression2
)
```
Exactly one prong will be selected, based on the value of a query expression, and that prong's expression will be evaluated, with its result becoming the `map` expression's result value.

Instead of new lines, prongs may be separated by commas, but the list of prongs must always be enclosed in `(` `)`.  This block is not considered a procedural block, so it does not interact with `break`.

## Fixed-Point
When the query expression's type is a fixed-point number, the map conditions may be constants that can be coerced to that type or subranges of that type's range, or `_`, which will match any value not matched by another prong:
```foot
x : u32 = ...
y := x map (
    0, 20~30 => 1234
    3~10, 1 => 2345
    _ => 1829
)
```
Every value in the query type's range must be represented in exactly one prong.  The default (`_`) prong should be omitted if and only if every possible value is covered by another prong.

## Union
When the query expression's type is a union, the map conditions may be symbols, types, dimensions, constants or ranges that correspond to field IDs, or `_`:
```foot
x : union { ... } = ...
y := x map (
    .asdf => expr1
    u32, u16 => expr2
    0, 1 => expr3
    _ => default_value
)
```
Each union field ID must match exactly one prong.  When specifying a type, it must match the payload type exactly (no coercion is attempted) but it may match multiple fields.  When specifying field ID(s) numerically, they must be explicitly assigned field IDs, not compiler picked IDs.

### Payload Access
Often the inner map expressions will want to access the payload data stored in the union for the matched field:
```foot
x map (
    val := .asdf => expr1
    val : mut = .abc => expr2
    val : u32 => expr3
    _ => expr4
)
```
The "initializer" of the declaration is the normal union map condition list, but the declaration will actually be initialized using the payload value.  The payload type must be able to be coerced to the type of the declaration.

If the initializer is omitted, any field whose type can be coerced to the declaration's type will be matched.

If the payload declaration is `mut`, any changes to it will be reflected in the original union value.

Struct destructuring may be used to access fields of a payload struct:
```foot
x map (
    a:_, b:_ => expr_using_a_and_b
    _ => default_expr
)
```

### Constrained Default Prong
Often when mapping a union type with many fields, only a few are "interesting", and you don't need to do anything for any of the rest.  This would seem like a good time to use a default prong, but that can be a footgun if a new field is added to the union in the future: the compiler would automatically group that into the default prong as well.  Often it would be nicer to have to explicitly decide what to do with the new field, and have the compiler complain if you forget.

To help with this, the `_` token can be replaced with `@_`, followed by a 5-digit base-62 value which is a hash of all the remaining unmatched fields:

```foot
x map (
    .field1 => expr1
    .field2 => expr2
    @_ f1Zz4 => default_value
)
```

If this hash is not provided or is incorrect, the compiler will generate an error with the expected value.  If a single field was added, the compiler will mention that that field is not handled yet, otherwise it will list all the unhandled fields.

Note that there may still only be one default prong; you can't have multiple constrained default prongs or an unconstrained default prong after a constrained one.  This feature is only meant to avoid the footgun of default prongs when adding new fields to existing unions.

The base-62 hash contains 29 bits of entropy and is guaranteed to be a valid identifier token (in particular, it will never start with a number).  It may or may not be unique; it does not interact with other symbols in the current scope.

## `any` Values
When the query expression's type is `any`, the map conditions must be types, dimensions, or `_`.  Payload access works exactly like for unions.
```foot
x map (
    u32 => expr1
    val := u16 => expr2 //
    val : u8 => expr3
    _ => expr4
)
```

## Types
When the query expression's type is `@type`, the map conditions must be types, dimensions, or `_`, but unlike for `any`, there is no payload to access.

## Other Query Types
It may make sense to add support for other types of query expressions in the future, e.g. structs or arrays.  It's not clear whether such use cases are common or useful enough to justify complicating the language.  More investigation is warranted.

# Aside: Why Parentheses?
In most other C-like languages, a `match` or `switch` expression or statement uses `{ ... }` braces to demarcate the different cases, but in Foot, parentheses are used instead.  This is mostly a stylistic choice which might seem strange at first, but there are a few reasons for it:
* `{ ... }` should always introduces a new scope.  Match expressions also introduce new scopes, but it's one per prong, not one for the entire block.
* `break` and `continue` only interact with procedural blocks, not `map` expressions.  Someone new to the language might wrongly assume they should use `break` to return a value from a `map`; hopefully by using `( ... )` it is more obvious that won't work.
* Often times the expressions on the right of a map condition's `=>` will be a procedural block, including on the last prong, which would often lead to a double `}}` ending to the expression that's easy to typo.  With `})` hopefully it's a little more obvious what's going on.
