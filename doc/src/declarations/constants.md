# Constants
There are several definitions of "constant" that are often conflated in programming:

* A value known at compile-time
* A value that cannot change after it has been initialized
* An immutable view of a (usually non-constant) value

In Foot, "constant" only refers to the first meaning.  This roughly corresponds to Zig's `comptime` or C++'s `constexpr`, but in Foot, compile-time evaluation is intentionally very limited.  Instead, Foot programs should rely on the language's runtime introspection to process and generates code as necessary at build-time.

Constants can be declared with the `::` operator, which associates an identifier with a constant:
```foot
pi :: 3.1415926
version :: "1.0.0"
```
Basic operations on constants typically result in a new constant:
```foot
life :: 10
the_universe :: life * 3
everything :: 2
the_answer :: life + the_universe + everything
```
However the results of [functions calls](functions.md#function-calls) are never constants.