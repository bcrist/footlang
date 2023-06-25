const std = @import("std");
const console = @import("console");
const Compiler = @import("Compiler");
const Token = @import("Token.zig");
const Source = @import("Source.zig");

const Error = @This();

source_handle: Source.Handle,
context: Context,
desc: []const u8,
flags: FlagSet,

pub const Context = union (enum) {
    token: Token.Handle,
    token_range: Token.Range,
};

pub const FlagSet = std.EnumSet(Flags);
pub const Flags = enum {
    desc_is_allocated_from_arena,
    supplemental,
    has_continuation,
};

pub const Handle = u32;

pub fn print(c: *const Compiler, first_error_handle: Handle, writer: anytype) !Handle {
    var source: *Source = undefined;
    var span_buf: [10]console.SourceSpan = undefined;

    const spans = for (1.., first_error_handle.., &span_buf) |num_spans, error_handle, *span| {
        const err = c.errors.items[error_handle];
        source = &c.sources.items[err.source_handle];

        span.* = console.SourceSpan{
            .offset = undefined,
            .len = undefined,
        };

        switch (err.context) {
            .token => |token_handle| {
                const token = Token.init(source.token_data.get(token_handle), source.text);
                span.offset = token.offset;
                span.len = token.text.len;
            },
            .token_range => |range| {
                const first_token = Token.init(source.token_data.get(range.first), source.text);
                const last_token = Token.init(source.token_data.get(range.last), source.text);
                span.offset = first_token.offset;
                span.len = last_token.offset + last_token.text.len - first_token.offset;
            },
        }
        span.note = err.desc;

        if (err.flags.contains(.supplemental)) {
            span.style = .{ .fg = .yellow };
            span.note_style = .{ .fg = .yellow };
        } else {
            span.style = (console.Style{ .fg = .red }).withFlag(.underline);
            span.note_style = .{ .fg = .red };
        }

        if (!err.flags.contains(.has_continuation)) break span_buf[0..num_spans];
    } else &span_buf;

    try writer.writeByte('\n');
    try console.printContext(source.text, spans, writer, 160, .{ .filename = source.name });
    return @intCast(Handle, first_error_handle + spans.len);
}
