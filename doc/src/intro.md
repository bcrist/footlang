# Introduction

The Foot programming language is a compiled, imperative, and procedural systems programming language that is statically and fairly strongly typed.
Some of its features include:
 - Prefix, infix, and suffix function calls
 - Function overloading
 - Binary fixed-point numbers of arbitrary width and granularity
 - Numeric subrange types
 - No implicit numerical overflows
 - Pointers & Slices
 - Structures & Discriminated Unions
 - Field access by type (or name)
 - Opt-in mutability
 - Arrays indexed by non-numeric types
 - Deferred execution at scope exit
 - Bidirectional type inference within expressions
 - Structural type equivalence
 - Type dimensions
 - Type reflection
 - Error context variables (TODO)
 - Significant line breaks
 - Multi-line strings
 - Readable string escapes
 - Source code generation tools

Some things which are currently non-goals, but may one day become aspirational:
 - Highly optimized machine code
 - Support for a large number of platforms
 - Interop with C or other languages

It will never include:
 - Garbage collection
 - Dynamic typing
 - Exceptions
 - RAII/destructors
 - Operator overloading
 - Pointer arithmetic
 - Inheritance
 - Covariant & Contravariant types
 - Generic or polymorphic types or functions
 - Preprocessor or compile-time macros
 - Closures
 - Regexen

## Name
"Foot" refers to the proverbial "footguns" prevalent in certain other systems programming languages.  The hope is that by removing the gun, the foot might be saved.

When referring to the language informally, simply "Foot" is preferred.  "Footlang" should be used only to avoid confusion with biological locomotive appendages when using search engines.

The preferred file extension for Foot source code is `.foot`, however `.foo` is also not considered objectionable.
