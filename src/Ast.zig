const std = @import("std");
const Token = @import("Token.zig");

const Ast = @This();

token_handle: Token.Handle,
info: Info,

pub const Handle = u31;

pub const Kind = std.meta.Tag(Info);
pub const Info = union(enum) {
    numeric_literal,
    string_literal,
    id_ref,
    symbol,
    inferred_type,
    mut_inferred_type,
    empty, // used when list would normally be used, in the case where there are no items

    list: Binary,

    constant_declaration: Binary, // identifier : left : right
    variable_declaration: Binary, // identifier : left = right (`= right` may be omitted, `empty is used instead)
    field_declaration: Binary,    // symbol : left = right (`= right` may be omitted, `empty` is used instead)

    assignment: Binary, // left = right

    proc_block: Handle, // { ... }

    group: Handle, // (x)
    logical_not: Handle, // not x
    try_expr: Handle, // try x
    return_expr: Handle, // return x
    break_expr: Handle, // break x
    mut_type: Handle, // mut x
    distinct_type: Handle, // distinct x
    error_type: Handle, // error x
    defer_expr: Handle, // defer x
    errordefer_expr: Handle, // errordefer x
    negate: Handle, // -x
    range_expr_infer_start_exclusive_end: Handle, // ~x
    range_expr_infer_start_inclusive_end: Handle, // ~~x
    optional_type: Handle, // ?x
    make_pointer: Handle,   // *x
    unmake_pointer: Handle, // x*
    slice_type: Handle, // []x
    range_expr_infer_end: Handle, // x~ or x~~

    if_expr: Binary,
    while_expr: Binary,
    until_expr: Binary,
    repeat_while: Binary,
    repeat_until: Binary,
    repeat_infinite: Handle,
    with_expr: Binary,
    with_only: Binary,
    for_expr: Binary,

    typed_array_literal: Binary, // left is type, right is contents
    anonymous_array_literal: Handle,
    typed_struct_literal: Binary, // left is type, right is contents
    anonymous_struct_literal: Handle,
    typed_union_literal: Binary, // left is type, right is contents
    anonymous_union_literal: Handle,
    array_type: Binary, // [left]right
    member_access: Binary, // left.right
    indexed_access: Binary, // left[right]
    array_repeat: Binary, // left**right
    array_concat: Binary, // left++right
    raise_exponent: Binary, // left^right
    multiply: Binary, // left*right
    divide_exact: Binary, // left/right
    add: Binary, // left+right
    subtract: Binary, // left-right
    range_expr_exclusive_end: Binary, // left~right
    range_expr_inclusive_end: Binary, // left~~right
    type_sum_operator: Binary, // left|right
    type_product_operator: Binary, // left&right
    coerce: Binary, // left as right
    apply_dim: Binary, // left in right
    test_active_field: Binary, // left is right
    coalesce: Binary, // left else right
    catch_expr: Binary, // left catch right
    test_less_than: Binary, // left < right
    test_less_than_or_equal: Binary, // left <= right
    test_greater_than: Binary, // left > right
    test_greater_than_or_equal: Binary, // left >= right
    test_equal: Binary, // left == right
    test_inequal: Binary, // left <> right
    compare: Binary, // left <=> right
    logical_and: Binary, // left and right
    logical_or: Binary, // left or right
    apply_tag: Binary, // left is expr, right is tag constant
    ambiguous_call: Binary, // left'right or left ' right
    suffix_call: Binary, // left 'right
    prefix_call: Binary, // left' right
    infix_call: Binary, // left is function, right is infix_call_args
    infix_call_args: Binary,
};

pub const Binary = struct {
    left: Handle,
    right: Handle,
};