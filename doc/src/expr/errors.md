# Error Control Flow
Foot does not have exceptions.  Like most systems programming languages, errors are reported as regular values.  When an expression or function has the possibility of failing, it can return a union where one or more values represent the error condition.  The caller then has the responsibility of sorting out what was returned with a `map` expression or some other way to handle the error(s).  When values are tagged as [error types](dimensions.md#error-types) some language features are available to streamline the handling of error values.

## `catch`
A `catch` expression has syntax identical to a map-union expression, except union fields that don't have the `@error` dimension will not be mapped to a different value.  Every `catch` prong specified (including `_`) implicitly only matches `@error` values:
```foot
maybe_error_expr catch ( _ => default_on_error )
// is roughly equivalent to:
with v := maybe_error_expr v map (
    _: @error => default_on_error
    _ => v
)
```

## Try operator
Manually checking for errors can get tedious, and a lot of functions will just want to propagate any error values up to their caller, which can be done with the try (`!`) operator:
```foot
expr !
// is roughly equivalent to:
expr catch ( e: => return e )
```

# TODO: Error Context Data
When an error is returned, the PC (or some value that can uniquely identify a source location) is saved to a special stack allocator.
If there were any @context variables in scope at the time of the return, their data is copied to the temporary allocator, and a pointer to the copied data is saved to the error stack allocator.
This allows the context data to be retrieved when printing an error message, etc.
TODO figure out how to access context data programmatically - @get_error_context returns slice?  Or some iterator function defined in the std?
Allow a function to reset any error data currently on the error stack - same as it would when returning, but without needing to actually return.  Programs can call this after logging an error manually if they think another error might happen before returning.

If a function can call another function that might return an error, then the size of the error allocator is saved to a hidden variable upon function entry.
If the function then does _not_ return an error itself, the error allocator is reset to it's original size; discarding any error info generated during that function.

# TODO: Allocators
opaque - opaque type but without size or alignment data - just an address.

General allocator interface:
```foot
Allocator :: distinct struct {
    data: ?&opaque
    impl: &fn data: ?&opaque ' v: ?[]u8, size: usize, align_bits: ualign, min_count: usize, max_count: usize -> &mut[]u8

    // Codegen will automatically generate versions of these functions as needed, and put them into an overload set.
    alloc   :: fn Allocator ' T: @type_of Some_Type, len: usize -> []mut Some_Type
    dupe    :: fn Allocator ' v: []Some_Type -> []mut Some_Type
    free    :: fn Allocator ' v: []Some_Type
    realloc :: fn Allocator ' v: []Some_Type, len: usize -> []mut Some_Type     // min_count = len, max_count = len
    resize  :: fn Allocator ' v: []Some_Type, len: usize => []mut Some_Type     // min_count = @min(len, v.len), max_count = len
    create  :: fn Allocator ' T: @type_of Some_Type -> &mut Some_Type
    clone   :: fn Allocator ' v: &Some_Type -> &mut Some_Type
    destroy :: fn Allocator ' v: &Some_Type
}
```

If an allocation request can't be fulfilled due to insufficient memory, etc. the allocator implementation will @panic.
Fallible_Allocator works the same as Allocator except allocating functions can return `error Allocation_Failed` instead of @panicing.
