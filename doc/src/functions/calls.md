# Function Calls
Functions are called by surrounding the function name with the `'` token, turning it into a binary operator.  There may not be whitespace between the `'` and the function name, and there must be on the other side.
```foot
result := a 'plus' b
```

Function calls may also be made that mimic prefix or suffix operators, by omitting the `'` on one side:
```foot
result1 := prefix_fn' x
result2 := x 'suffix_fn
```
When called this way, the value of the omitted argument will be the default for its type.  At least one parameter must be provided, so a function taking no parameters must be passed `nil` on at least one side.

## Function lookup
If the function name is a plain identifier, then in addition to potentially being found in the current scope for normal identifier lookup, the compiler will also look within the scope of the types of both arguments:
```foot
A :: distinct u32 {
    add :: fn lhs: A ' rhs: A {
        return lhs + rhs
    }
}

a1 : A : 1234
a2 : A : 2345

a3 := a1 'add' a2
```

## Argument Swapping
If there is no function with types that are compatible with the types that the function is being called with, but there is exactly one which matches when the left and right sides are swapped, then that swapped version is used:
```foot
A :: distinct struct {}
B :: distinct struct {}
asdf :: fn A ' B => nil

main :: fn {
    B.{} 'asdf' A.{}
}
```

## More Arguments
A pattern that mimics method calls in other languages is possible with struct literals:
```foot
receiver 'func' .{ .param1 = 1234, .param2 = 3456 }
```
When the fields of the parameter struct have different types, it's often possible to omit the field names, making this syntax equivalent to C-style function calls in terms of brevity:
```foot
receiver 'func' .{ 1234, "asdf", .some_symbol }
```
