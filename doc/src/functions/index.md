# Functions
C and it's descendants allow functions to take an arbitrary number of arguments and return a single value, while languages like Lua, Odin, and Jai expand that to allow multiple return values.  Verdi does the opposite: all functions take exactly two arguments and produce one return value.

This might sound limiting, since a large portion of functions need to take more than two parameters, but this can be handled exactly the same way that multiple return values are often handled: use a tuple (struct).  Verdi's struct literals make that easy.

Verdi's approach has a variety of advantages:.
* Functions can be used as prefix, infix, or suffix operators without needing special syntax or additional language features
* Calls with many parameters are less fragile when adding/reordering function parameters, since the struct literal will require fields be named when a value could be coerced to the type of more than one field
* Parameters can be built incrementally before calling the function, and can be shared between multiple calls
* The chance of having deeply parenthesized expressions is greatly reduced
* The compiler (and metaprogramming/code generation) is simpler, since every function type references exactly three other types

## Function Types
A function type defines the interface to a function, consisting of:
* The type of the left side argument
* The type of the right side argument
* The type of the result

A function type literal looks like:
```
fn Left ' Right -> Result
```
If one or more of `Left`, `Right`, and `Result` are `nil`, then they can be omitted:
```
fn ' Right -> Result
fn Left -> Result
fn -> Result
fn Left ' Right
fn ' Right
fn Left
fn
```

## Calling Conventions
TODO