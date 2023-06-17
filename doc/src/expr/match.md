# Match Expressions
A `match` expression contains a list of _prongs_.  Each prong consists of a list of conditions where it matches and a result expression to evaluate in that case.
```
match query_expr {
	match_condition_list1 => expression1
	match_condition_list2 => expression2
}
```
Exactly one prong will be selected, based on the value of a query expression, and that prong's expression will be evaluated, with its result becoming the `match` expression's result value.

Instead of new lines, prongs may be separated by commas, but the list of prongs must always be enclosed in `{` `}`.  This block is not considered a procedural block, so it does not interact with `break`.

## Fixed-Point
When the query expression's type is a fixed-point number, the match conditions may be constants that can be coerced to that type or subranges of that type's range, or `_`, which will match any value not matched by another prong:
```
x : u32 = ...
y := match x {
	0, 20~30 => 1234
	3~10, 1 => 2345
	_ => 1829
}
```
Every value in the query type's range must be represented in exactly one prong.  The default (`_`) prong should be omitted if and only if every possible value is covered by another prong.

## Union
When the query expression's type is a union, the match conditions may be symbols, types, dimensions, constants or ranges that correspond to field IDs, or `_`:
```
x : union { ... } = ...
y := match x {
	.asdf => expr1
	u32, u16 => expr2
	0, 1 => expr3
	_ => default_value
}
```
Each union field ID must match exactly one prong.  When specifying a type, it must match the payload type exactly (no coercion is attempted) but it may match multiple fields.  When specifying field ID(s) numerically, they must be explicitly assigned field IDs, not compiler picked IDs.

### Payload Access
Often the inner match expressions will want to access the payload data stored in the union for the matched field:
```
match x {
	val := .asdf => expr1
	val : mut = .abc => expr2
	val : u32 => expr3
	_ => expr4
}
```
The "initializer" of the declaration is the normal union match condition list, but the declaration will actually be initialized using the payload value.  The payload type must be able to be coerced to the type of the declaration.

If the initializer is omitted, any field whose type can be coerced to the declaration's type will be matched.

If the payload declaration is `mut`, any changes to it will be reflected in the original union value.

Struct destructuring may be used to access fields of a payload struct:
```
match x {
	a:_, b:_ => expr_using_a_and_b
	_ => default_expr
}
```

## `any` Values
When the query expression's type is `any`, the match conditions must be types, dimensions, or `_`.  Payload access works exactly like for unions.
```
match x {
	u32 => expr1
	val := u16 => expr2 //
	val : u8 => expr3
	_ => expr4
}
```

## Types
When the query expression's type is `@type`, the match conditions must be types, dimensions, or `_`, but unlike for `any`, there is no payload to access.

## Other Query Types
It may make sense to add support for other types of query expressions in the future, e.g. structs or arrays.  It's not clear whether such use cases are common or useful enough to justify complicating the language.  More investigation is warranted.
