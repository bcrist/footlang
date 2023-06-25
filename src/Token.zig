const std = @import("std");

const Token = @This();

offset: u32,
kind: Kind,
text: []const u8,

pub const Handle = u32;

pub const Range = struct {
    first: Handle,
    last: Handle,
};

pub const Kind = enum (u8) {
    reserved,
    eof,
    linespace,
    newline,
    comment,
    line_string_literal,
    string_literal,
    numeric_literal,
    id,
    kw_not,
    kw_try,
    kw_mut,
    kw_break,
    kw_error,
    kw_return,
    kw_distinct,
    kw_as,
    kw_in,
    kw_is,
    kw_else,
    kw_catch,
    kw_and,
    kw_or,
    paren_open,
    paren_close,
    index_open,
    index_close,
    block_open,
    block_close,
    dot,
    dot_paren_open,
    dot_index_open,
    dot_block_open,
    colon,
    eql,
    dash,
    tilde,
    tilde_tilde,
    question,
    star,
    star_star,
    apostrophe,
    plus,
    plus_plus,
    slash,
    bar,
    amp,
    caret,
    octothorpe,
    money,
    spaceship,
    diamond,
    lt,
    gt,
    lt_eql,
    gt_eql,
    eql_eql,
    thin_arrow,
    thick_arrow,
};

pub fn init(data: Data, text: []const u8) Token {
    var remaining = text[data.offset..];
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
        .dot,
        .colon,
        .eql,
        .dash,
        .tilde,
        .question,
        .star,
        .apostrophe,
        .plus,
        .slash,
        .bar,
        .amp,
        .caret,
        .octothorpe,
        .money,
        .lt,
        .gt,
            => 1,

        .tilde_tilde,
        .kw_as,
        .kw_in,
        .kw_is,
        .kw_or,
        .diamond,
        .eql_eql,
        .lt_eql,
        .gt_eql,
        .thin_arrow,
        .thick_arrow,
        .star_star,
        .plus_plus,
        .dot_paren_open,
        .dot_index_open,
        .dot_block_open,
            => 2,

        .kw_try,
        .kw_not,
        .kw_mut,
        .kw_and,
        .spaceship,
            => 3,

        .kw_else,
            => 4,

        .kw_catch,
        .kw_error,
        .kw_break,
            => 5,

        .kw_return => 6,
        .kw_distinct => 8,


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
                    'A'...'Z', 'a'...'z', '0'...'9', '_', '<', '>', 128...255 => {
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
        .text = remaining[0..token_len],
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

pub const Data = struct {
    offset: u32,
    kind: Kind,
};
pub const List = std.MultiArrayList(Data);


fn checkKeyword(haystack: []const u8, kw: []const u8, kind: Kind) ?Kind {
    if (std.mem.eql(u8, haystack, kw)) {
        return kind;
    } else {
        return null;
    }
}

pub fn lex(allocator: std.mem.Allocator, text: []const u8) List {
    var tokens = List{};
    tokens.setCapacity(allocator, text.len / 2 + 100) catch @panic("OOM");

    var i: u32 = 0;
    while (i < text.len) {
        var data = Data {
            .offset = i,
            .kind = undefined,
        };
        data.kind = switch (text[i]) {
            'A'...'Z', '_', '@', 128...255 => .id,
            'a'...'z' => blk: {
                data.kind = .id;
                const token = Token.init(data, text);
                break :blk switch (token.text.len) {
                    2 => checkKeyword(token.text, "as", .kw_as)
                        orelse checkKeyword(token.text, "or", .kw_or)
                        orelse checkKeyword(token.text, "in", .kw_in)
                        orelse checkKeyword(token.text, "is", .kw_is)
                        orelse .id,
                    3 => checkKeyword(token.text, "not", .kw_not)
                        orelse checkKeyword(token.text, "and", .kw_and)
                        orelse checkKeyword(token.text, "mut", .kw_mut)
                        orelse checkKeyword(token.text, "try", .kw_try)
                        orelse .id,
                    4 => checkKeyword(token.text, "else", .kw_else)
                        orelse .id,
                    5 => checkKeyword(token.text, "break", .kw_break)
                        orelse checkKeyword(token.text, "catch", .kw_catch)
                        orelse checkKeyword(token.text, "error", .kw_break)
                        orelse .id,
                    6 => checkKeyword(token.text, "return", .kw_return)
                        orelse .id,
                    8 => checkKeyword(token.text, "distinct", .kw_distinct)
                        orelse .id,
                    else => .id,
                };
            },
            0...9, 11...' ', 127 => .linespace,
            '\\' => if (text.len <= i + 1) .linespace else switch (text[i + 1]) {
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
            ':' => .colon,
            '|' => .bar,
            '&' => .amp,
            '?' => .question,
            '#' => .octothorpe,
            '$' => .money,
            '^' => .caret,
            '\'' => .apostrophe,
            '.' => if (text.len > i + 1) switch (text[i + 1]) {
                '[' => .dot_index_open,
                '(' => .dot_paren_open,
                '{' => .dot_block_open,
                else => .dot,
            } else .dot,
            '=' => if (text.len > i + 1) switch (text[i + 1]) {
                '=' => .eql_eql,
                '>' => .thick_arrow,
                else => .eql,
            } else .eql,
            '<' => if (text.len > i + 1) switch (text[i + 1]) {
                '>' => .diamond,
                '=' => if (text.len > i + 2 and text[i + 2] == '>') .spaceship else .lt_eql,
                else => .lt,
            } else .lt,
            '+' => if (text.len > i + 1 and text[i + 1] == '+') .plus_plus else .plus,
            '*' => if (text.len > i + 1 and text[i + 1] == '*') .star_star else .star,
            '>' => if (text.len > i + 1 and text[i + 1] == '=') .gt_eql else .gt,
            '-' => if (text.len > i + 1 and text[i + 1] == '>') .thin_arrow else .dash,
            '~' => if (text.len > i + 1 and text[i + 1] == '~') .tilde_tilde else .tilde,
            '/' => if (text.len > i + 1 and text[i + 1] == '/') .comment else .slash,
            else => .reserved,
        };

        tokens.append(allocator, data) catch @panic("OOM");
        i += @intCast(u32, Token.init(data, text).text.len);
    }

    tokens.append(allocator, .{
        .offset = @intCast(u32, text.len),
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
