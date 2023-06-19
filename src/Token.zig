const std = @import("std");

const Token = @This();

offset: u32,
kind: Kind,
source: []const u8,

pub const Handle = u32;

const Kind = enum (u8) {
    reserved,
    eof,
    linespace,
    newline,
    id,
    comment,
    line_string_literal,
    string_literal,
    numeric_literal,
    paren_open,
    paren_close,
    index_open,
    index_close,
    block_open,
    block_close,
};

pub fn init(data: TokenData, source: []const u8) Token {
    var remaining = source[data.offset..];
    var token_len = switch (data.kind) {
        .eof => 0,

        .reserved,
        .newline,
        .paren_open,
        .paren_close,
        .index_open,
        .index_close,
        .block_open,
        .block_close,
            => 1,

        .linespace => blk: {
            var consume_newline = remaining[0] == '\\';
            var end: usize = 1;
            while (end < remaining.len) : (end += 1) {
                switch (remaining[end]) {
                    0...9, 11...' ', 127 => {},
                    '\\' => {
                        if (remaining[end - 1] == '\\') {
                            break :blk end - 1;
                        }
                        consume_newline = true;
                    },
                    '\n' => {
                        if (consume_newline) {
                            consume_newline = false;
                        } else {
                            break;
                        }
                    },
                    else => break,
                }
            }
            break :blk end;
        },

        .comment, .line_string_literal => blk: {
            var end: usize = 2;
            while (end < remaining.len) : (end += 1) {
                switch (remaining[end]) {
                    '\n' => break,
                    else => {},
                }
            }
            break :blk end;
        },

        .string_literal => getStringLiteralEnd(remaining),

        .id => if (remaining[0] == '@' and remaining.len > 1 and remaining[1] == '"')
            getStringLiteralEnd(remaining[1..]) + 1
        else blk: {
            var consume_linespace = false;
            var end: usize = 1;
            while (end < remaining.len) : (end += 1) {
                switch (remaining[end]) {
                    'A'...'Z', 'a'...'z', '0'...'9', '_', '@', 128...255 => {
                        consume_linespace = false;
                    },
                    '\\' => {
                        consume_linespace = true;
                    },
                    0...9, 11...' ', 127 => if (!consume_linespace) break,
                    else => break,
                }
            }
            break :blk end;
        },

        .numeric_literal => if (remaining.len <= 1) 1 else blk: {
            var consume_linespace = false;
            var found_dot = false;
            var allow_alpha = true;
            var end: usize = 1;
            while (end < remaining.len) : (end += 1) {
                switch (remaining[end]) {
                    '0'...'9' => {
                        allow_alpha = true;
                        consume_linespace = false;
                    },
                    'A'...'Z', 'a'...'z', '_', 128...255 => {
                        consume_linespace = false;
                        if (!allow_alpha) break;
                    },
                    '\\' => {
                        consume_linespace = true;
                    },
                    '.' => {
                        consume_linespace = false;
                        if (found_dot) {
                            break;
                        } else {
                            found_dot = true;
                            allow_alpha = false;
                        }
                    },
                    0...9, 11...' ', 127 => if (!consume_linespace) break,
                    else => break,
                }
            }
            if (remaining[end - 1] == '.') {
                end -= 1;
            }
            break :blk end;
        },
    };
    return .{
        .offset = data.offset,
        .kind = data.kind,
        .source = remaining[0..token_len],
    };
}

fn getStringLiteralEnd(literal: []const u8) u32 {
    var in_escape = false;
    var end: usize = 1;
    while (end < literal.len) : (end += 1) {
        const ch = literal[end];
        if (ch == '\n') {
            break;
        } else if (in_escape) {
            in_escape = false;
            continue;
        } else switch (ch) {
            '"' => {
                end += 1;
                break;
            },
            '\\' => {
                in_escape = true;
            },
            else => {},
        }
    }
    return @intCast(u32, end);
}

const TokenData = struct {
    offset: u32,
    kind: Kind,
};
const TokenList = std.MultiArrayList(TokenData);


fn checkKeyword(haystack: []const u8, kw: []const u8, kind: Kind) ?Kind {
    if (std.mem.eql(u8, haystack, kw)) {
        return kind;
    } else {
        return null;
    }
}

pub fn lex(allocator: std.mem.Allocator, source: []const u8) TokenList {
    var tokens = TokenList{};
    tokens.setCapacity(allocator, source.len / 2 + 100) catch @panic("OOM");

    var i: u32 = 0;
    while (i < source.len) {
        var data = TokenData {
            .offset = i,
            .kind = undefined,
        };
        data.kind = switch (source[i]) {
            'A'...'Z', '_', '@', 128...255 => .id,
            'a'...'z' => blk: {
                data.kind = .id;
                const token = Token.init(data, source);
                break :blk switch (token.source.len) {
                    // 'a' => checkKeyword(remaining, "as", .kw_as) orelse .id,
                    // 'b' => checkKeyword(remaining, "break", .kw_break) orelse .id,
                    // 'c' => checkKeyword(remaining, "catch", .kw_catch) orelse checkKeyword(remaining, "continue", .kw_continue) orelse .id,
                    // 'd' => checkKeyword(remaining, "defer", .kw_defer) orelse checkKeyword(remaining, "dimension", .kw_dimension) orelse .id,
                    // 'e' => checkKeyword(remaining, "else", .kw_else) orelse checkKeyword(remaining, "errdefer", .kw_errdefer) orelse checkKeyword(remaining, "export", .kw_export) orelse checkKeyword(remaining, "exact", .kw_exact) orelse .id,
                    // 'f' => checkKeyword(remaining, "fn", .kw_fn) orelse checkKeyword(remaining, "for", .kw_for) orelse .id,
                    // 'i' => checkKeyword(remaining, "if", .kw_if) orelse checkKeyword(remaining, "import", .kw_import) orelse .id,
                    // 'm' => checkKeyword(remaining, "mut", .kw_mut) orelse checkKeyword(remaining, "match", .kw_match) orelse checkKeyword(remaining, "module", .kw_module) orelse .id,
                    // 'p' => checkKeyword(remaining, "pub", .kw_pub) orelse checkKeyword(remaining, "packed", .kw_packed) orelse .id,
                    // 'r' => checkKeyword(remaining, "repeat", .kw_repeat) orelse .id,
                    // 's' => checkKeyword(remaining, "struct", .kw_struct) orelse checkKeyword(remaining, "strong", .kw_strong) orelse .id,
                    // 't' => checkKeyword(remaining, "try", .kw_try) orelse .id,
                    // 'u' => checkKeyword(remaining, "using", .kw_using) orelse checkKeyword(remaining, "until", .kw_until) orelse checkKeyword(remaining, "union", .kw_union) orelse checkKeyword(remaining, "unit", .kw_unit) orelse .id,
                    // 'w' => checkKeyword(remaining, "while", .kw_while) orelse checkKeyword(remaining, "weak", .kw_weak) orelse .id,
                    else => .id,
                };
            },
            0...9, 11...' ', 127 => .linespace,
            '\\' => if (source.len <= i + 1) .linespace else switch (source[i + 1]) {
                '\\' => .line_string_literal,
                else => .linespace,
            },
            '\n' => .newline,
            '"' => .string_literal,
            '0'...'9' => .numeric_literal,
            '(' => .paren_open,
            ')' => .paren_close,
            '[' => .index_open,
            ']' => .index_close,
            '{' => .block_open,
            '}' => .block_close,
            '/' => if (source.len > i + 1 and source[i + 1] == '/') .comment else .reserved,
            else => .reserved,
        };

        tokens.append(allocator, data) catch @panic("OOM");
        i += @intCast(u32, Token.init(data, source).source.len);
    }

    tokens.append(allocator, .{
        .offset = @intCast(u32, source.len),
        .kind = .eof,
    }) catch @panic("OOM");

    if (tokens.capacity > (tokens.len / 4) * 5) blk: {
        var old = tokens;
        tokens = tokens.clone(allocator) catch break :blk;
        old.deinit(allocator);
    }
    return tokens;
}


fn testLex(src: []const u8, expected_tokens: []const Kind) !void {
    var tokens = lex(std.testing.allocator, src);
    defer tokens.deinit(std.testing.allocator);
    try std.testing.expectEqualSlices(Kind, expected_tokens, tokens.items(.kind));
}

test "Lexer linespace" {
    try testLex(" ", &.{ .linespace, .eof });
    try testLex("\t", &.{ .linespace, .eof });
    try testLex("\x00", &.{ .linespace, .eof });
    try testLex("   \t", &.{ .linespace, .eof });
    try testLex("  \\\n  ", &.{ .linespace, .eof });
    try testLex("  \\ \t \n  ", &.{ .linespace, .eof });
}

test "Lexer newline" {
    try testLex("\n", &.{ .newline, .eof });
    try testLex("\n\n", &.{ .newline, .newline, .eof });
}

test "Lexer ids" {
    try testLex("abcd", &.{ .id, .eof });
    try testLex("ab\\cd", &.{ .id, .eof });
    try testLex("ab\\  \tcd", &.{ .id, .eof });
    try testLex("abcd efg", &.{ .id, .linespace, .id, .eof });
}

test "Lexer integers" {
    try testLex("1234", &.{ .numeric_literal, .eof });
    try testLex("0123 0x10fff", &.{ .numeric_literal, .linespace, .numeric_literal, .eof });
    try testLex("0b1010111010101", &.{ .numeric_literal, .eof });
    try testLex("0o14777", &.{ .numeric_literal, .eof });
    try testLex("0q123123", &.{ .numeric_literal, .eof });
    try testLex("0.123123", &.{ .numeric_literal, .eof });
}

test "Lexer comments" {
    try testLex("// comment", &.{ .comment, .eof });
    try testLex(
        \\//aasdf
        \\//asdf asdf a;sdlfkjasdf@#$%&^#@()(*&)
    , &.{ .comment, .newline, .comment, .eof });
}

test "Lexer strings" {
    try testLex("\"abc\"", &.{ .string_literal, .eof });
    try testLex("\"\\\"\"", &.{ .string_literal, .eof });
    try testLex("\"\\( U+123 0x55 0b1010 =0123 )\"", &.{ .string_literal, .eof });

    try testLex(
        \\    \\
        \\    \\
        \\\\
        , &.{
            .linespace, .line_string_literal, .newline,
            .linespace, .line_string_literal, .newline,
            .line_string_literal, .eof
        });

    try testLex(
        \\\\
        \\\\
        \\
        , &.{ .line_string_literal, .newline, .line_string_literal, .newline, .eof });
}
