const std = @import("std");
const Token = @import("Token.zig");
const Expression = @import("Expression.zig");

const Declaration = @This();

token_handle: Token.Handle,
type_or_dim_expr_handle: ?Expression.Handle,
initializer_expr_handle: ?Expression.Handle,
flags: FlagSet = .{},

pub const FlagSet = std.EnumSet(Flag);
pub const Flag = enum {
    field,
    mutable,
    constant,
};

pub const Handle = u31;
