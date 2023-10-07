# Variables
A program that does useful work will need to keep track of data that is not known at compile-time.  Such data can be stored in variables, which are declared in the same way as constants, except that the second `:` is replaced by `=`.
```foot
x := 5
y: s32 = 1 + 1
```
Variables must always be initialized, unless its type has a default value, in which case the `=` can be omitted.

## Mutability
Variables are immutable by default, meaning their value cannot be changed once they are initialized.  When a variable needs to be modifiable, it can be declared with a mutable type:
```foot
x: mut s32 = 5
```

Note that a variable with a fully-inferred type is always immutable, even if the type of the value assigned to it is mutable.  However mutability may be explicitly specified without specifying the whole type:
```foot
x: s32 = 5
mutable_x: mut s32 = 5

y := mutable_x
mutable_y_1: mut = mutable_x
mutable_y_2: mut = x
```

## Explicit non-initialization
In rare cases, you may want to explicitly leave a variable uninitialized:
```foot
whatever: s32 = ---
```
Note that the variable must be assigned before it can be read.  When safety checks are enabled, uninitialized variables will be internally wrapped in a [union](../unions/index) and unwrapped whenever it is accessed, with a panic occurring if it hasn't been initialized yet.  In the case of an immutable variable, safety checks will also be generated before initialization to ensure it is not double-initialized.
