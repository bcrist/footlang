const std = @import("std");
const Token = @import("Token.zig");
const Error = @import("Error.zig");
const Parser = @import("Parser.zig");

const Source = @This();

handle: Handle,
name: []const u8,
text: []const u8,
token_data: Token.List,

pub const Handle = u32;

pub fn deinit(self: Source, gpa: std.mem.Allocator, maybe_arena: ?std.mem.Allocator) void {
    self.token_data.deinit(gpa);
    if (maybe_arena) |arena| {
        arena.free(self.name);
        arena.free(self.text);
    }
}
