# Expressions
Declarations use _expressions_ to define the type and initialization of constants and variables.  
All expressions have a type (though it may be inferred from context) and a result, which is a value of that type.  Every expression's result can be characterized as _constant_, _immutable_ or _mutable_.  The mutability of some expressions is restricted, for example:
* A declaration's type expression must be constant
* A constant declaration's initializer must be constant
* The left side of an assignment must be mutable

The simplest expressions, which don't syntactically rely on any other expressions, are sometimes called _terminal expressions_.  These include:
* Identifiers
* Symbols
* Numeric literals
* String literals
* `nil`
* `unreachable`
* `@noreturn`
* `@dim`
* `@unit`
* `@error`
* `@rational_constant`
* `@done`

## Operators
One or two expressions can be combined using an _operator_.  The "sub-expressions" are called _operands_.  Some operators only work on operands of certain types.  

Operators that apply to only one _operand_ are called _unary operators_.  If a unary operator consists of a symbol, keyword, or built-in that appears before the operand, it is known as a _prefix operator_.  If a unary operator consists of a symbol, keyword, or built-in that appears after the operand, it is known as a _suffix operator_.

There is one unary operator that "wraps" its operand: parentheses.  This operator always "passes through" its operand unchanged, but allows for the grouping of sub-expressions that normally wouldn't be possible based on the [operator precedence rules](#expression-precedence).

_Binary operators_ consist of two operands separated by a symbol/keyword/built-in.  Some binary operators may also require symbols/keywords/built-ins at before the first operand or after the second operand.

## Complex Expressions
Any expression that doesn't meet our definitions for terminal expressions or operators is a _complex expression_.

Some complex expressions include blocks wrapped in `{` `}` brackets, which define new scopes, and contain a list of declarations, and (possibly) fields or statements:
* [Union type literals](../unions/index.md#type-literals)
* [Struct type literals](../structs/index.md#type-literals)
* Distinct type literals
* Procedural blocks

Other complex expressions wrap a list of expressions or assignments:
* [Struct Literals](../structs/literals.md)
* [Union Literals](../unions/literals.md)
* [Array Literals](../arrays/index.md#array-literals)

Finally, some complex expressions have syntax unique to themselves:
* Function type literals
* Function definitions
* `if` expressions
* `for` expressions
* `while`/`until` expressions
* `match` expressions
* `with` expressions

## Procedural Blocks
A procedural block contains an ordered list of statements.  A statement may be any of the following:
* A declaration
	* Note unlike other scopes, declarations in procedural blocks can't be referenced before they're declared.
* An assignment
	* `variable = expr`
* A partial struct assignment
	* `variable .= expr`
* An expression, in some cases
    * The expression's type, `T`, must be one of:
        * A zero-size type (e.g. `nil` or `@noreturn`)
		* An optional of a zero-size type
    * The expression may be prefixed with the `defer` or `errordefer` keyword

Since procedural blocks are expressions, they evaluate to a value and are typechecked by the compiler.
A value can be returned with a `break` expression.  Any control flow paths that exit the block without using a `break` or `return`
will yield a result of `nil`.  If you want to exit a procedural block early without returning a value, you can use `continue`, which is equivalent to `break nil`.
