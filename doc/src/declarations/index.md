# Declarations
Declarations represent named functions or pieces of data that are associated with a particular scope.  They can be placed in structs, unions, or procedural blocks.  Declarations may be either constants (defined with `::` ) or variables (defined with `:=`).

Here are some examples of declarations:
```verdi
mol :: 6.0221408 * 10^23

mol_f32 : f32 : mol

add :: fn a ' b {
    return a + b
}

my_global_data := s32.[ 1, 2, 3 ]

state : My_State = ---
```

# Identifiers
Identifiers are names defined by declarations.  Most identifiers must match the regular expression:
```
@?[A-Za-z_][A-Za-z0-9_<>\\]*
```

Regular identifiers beginning with `@` are reserved for compiler-provided intrinsics.  Declarations are not allowed to use such identifiers.

## Linespace in Identifiers
Sometimes you may want to add spacing inside identifiers to make it more readable, or to line up parts of identifiers on adjacent lines.  Within an identifier, the backslash (`\`) character is ignored, as well as any whitespace characters following it (other than newlines).  The backslash may not be the first character in an identifier.

```
apple\ _pie :: 1
orange\_pie :: 2
pecan\ _pie :: 3
pumpkin_pie :: 4
```
Like `_` in numeric literals, these spacers hold no semantic meaning, and don't need to be used in other usages of the same identifier.

## Arbitrary Identifiers
If an identifier needs to include whitespace or other characters not normally allowed in an identifier, an arbitrary string literal may be turned into an identifier by prefixing the string literal with `@`:
```
@"Hello World" :: "Hello, World!"
```

# Scopes
Declarations are only "visible" within the scope where they are defined.  Some scopes may have additional nested scopes within them.  Declarations from "outer" scopes are visible within the child scopes as well.  It is a compile error if an inner scope contains a declaration using a name that is also defined by one of its parent scopes.

Variables within procedural blocks are lexically scoped; identifiers must be declared before being referenced.  Constant declarations, and variable declarations within struct and union scopes, are order-independent; identifiers can be used before they are declared.

# Types
In addition to a value and identifier, every declaration in Verdi also has has a type, which determines how the value can be used.  Often the type can be inferred from the initializing value, however it can also be explicitly specified:
```verdi
pi : @rational_constant : 3.1415926
version : [5]u8 : "1.0.0"
```

# Aside: No Semicolons?
In C, declarations must end with a semicolon.  This helps clear up some ambiguous situations that arise due to treating all whitespace the same (including newlines).

Verdi does not require a sigil (semicolon or otherwise) to separate declarations.  Instead, if the end of a line is reached, and the current declaration being parsed could be ended there, then it is.  Newlines can be escaped with a backslash before the end of the line.  Linespace or comments may appear after the backslash, but any semantic tokens will cancel the effect of the escape.