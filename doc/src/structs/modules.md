# Modules
The top level of every file is simply the inner part of a `distinct struct {}` definition.  Each module _exports_ exactly one constant that can be imported by other modules.  By default, that constant is simply the module's struct type, but it can be specified explicitly as well:
```
@export 3.14
```
This can be especially useful for exporting a union type:
```
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
Other modules can be imported using the `@import` built-in.  The identifier following `@import` exists outside the module's scope, and instead is resolved by the build system.  `@import` is an expression, and the imported constant is the result, so you can assign it to a name in your module like you would any other constant:
```
Goods :: @import Goods
Services :: @import Services
```
Since this results in a lot of duplicate identifiers, the `@import` expression itself can also be treated as a constant declaration, where it defines a symbol within the current scope using the same name as the module name:
```
@import Goods
@import Services
```

# Aside: Build System Integration
The default build system uses the filesystem to automatically discover modules.

When an unknown module is first imported, the build system will first replace any invalid filename characters in the module name with underscores.  Then it will begin searching for that filename in the directory containing the module that is importing.  It will continue searching in parent directories until it reaches a directory containing a `deps.vdat` file.  If no `deps.vdat` file is found, or if multiple candidate files are found, or no candidate files are found, an error is reported.  Otherwise, the new dependency is written to the `deps.vdat` file.

The `deps.vdat` file is a Verdi literal data file, which is a subset of Verdi syntax that allows for the definition of a single constant expression.  It looks like this:
```
Dependency.[
	.{ "path/to/module1.verdi"
		.[
			.{ .module2, "path/to/module2.verdi" }
			.{ .module3, "path/to/module3.verdi" }
		]
	}
	.{ "path/to/module2.verdi"
		.[ .{ .module3_by_another_name, "path/to/module3.verdi" } ]
	}
	"path/to/module3.verdi"
]
```
