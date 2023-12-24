# Modules
The top level of every file is simply the inner part of a `distinct struct {}` definition.  Each module _exports_ exactly one constant that can be imported by other modules.  By default, that constant is simply the module's struct type, but it can be specified explicitly as well:
```foot
@export 3.14
```
This can be especially useful for exporting a union type:
```foot
@export Color
Color :: union {
    .red
    .yellow
    .blue
    
    // ...
}
```

You can refer to a module's type within the module itself using the `@module` built-in.

## Importing Modules
Other modules can be imported using the `@import` prefix operator.  The right-side expression can have any type, but it must be a constant (and usually [symbols](symbols) are used).  The build system then looks up the module, and the result of the `@import` expression is the constant that was exported by that module.  You can use it directly in an expression or assign it to a name in your module like you would any other constant:
```foot
Goods :: @import .Goods
Services :: @import .Services
```
Within declarative scopes, an `@import` declaration can be used to reduce boilerplate.  The following is functionally identical to the above snippet:
```foot
@import Goods
@import Services
```
Note that there is no `::` or `:=` token which normally appears in a declaration, and this only works when you would normally import a symbol expression (as above).  The symbol to import is constructed using the same name as the identifier being declared.

### "Generic" Imports
Foot does not have types with parametric polymorphism (commonly known as Generics).  Foot instead relies on code generation to avoid requiring programmers to re-implement data structures and algorithms for every use case.  The main way this is accomplished is by `@import`ing a constant struct literal.  The struct type itself identifies what code generator to use (i.e. the generic type) and the struct fields are analyzed to determine how to generate that specific instance (equivalent to generic type parameters).  For example, here are some data structure generators provided in the standard library:
```
Int_List :: @import @Array_List.{ i32 }
My_Hash_Map :: @import @Hash_Map.{ .k = i32, .v = Some_Other_Type }
```

## Module Lookup
When the compiler is used as a library, module lookup is performed by a callback that must be provided when starting the compiler.

The standalone compiler allows a build script to do the same thing, but also provides a default implementation that searches for dependencies on the filesystem, and generates code for data structures found in the standard library


# Aside: Build System Integration
The default build system uses the filesystem to automatically discover modules.

When an unknown module is first imported, the build system will first replace any invalid filename characters in the module name with underscores.  Then it will begin searching for that filename in the directory containing the module that is importing.  It will continue searching in parent directories until it reaches a directory containing a `deps.vdat` file.  If no `deps.vdat` file is found, or if multiple candidate files are found, or no candidate files are found, an error is reported.  Otherwise, the new dependency is written to the `deps.vdat` file.

The `deps.vdat` file is a Foot literal data file, which is a subset of Foot syntax that allows for the definition of a single constant expression.  It looks like this:
```foot
Dependency.[
    .{ "path/to/module1.foot"
        .[
            .{ .module2, "path/to/module2.foot" }
            .{ .module3, "path/to/module3.foot" }
        ]
    }
    .{ "path/to/module2.foot"
        .[ .{ .module3_by_another_name, "path/to/module3.foot" } ]
    }
    "path/to/module3.foot"
]
```
