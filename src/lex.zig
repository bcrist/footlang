const std = @import("std");

const Lexer = @This();

const TokenKind = enum (u8) {
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

    pub fn isIdentifier(self: TokenKind) bool {
        return switch (self) {
            .id,
                => true,
            . reserved,
            .eof,
            .linespace,
            .newline,
            .id,
            .comment,
            .line_string_literal,
            .string_literal,
            .numeric_literal,
            .paren_open,
            .paren_close,
            .index_open,
            .index_close,
            .block_open,
            .block_close,
                => false,
        };
    }
};

const TokenList = struct {

};

const Token = struct {
    begin: u32,
    end: u32,
    kind: TokenKind;
};




pub const Token = struct {
    offset: u32,
    kind: TokenKind,

    pub const Handle = u32;

    pub fn location(self: Token, source: []const u8) []const u8 {
        var remaining = source[self.offset..];
        var token_len = switch (self.kind) {
            .eof => 0,
            .newline,
            .dollar1,
            .octothorpe,
            .percent,
            .slash,
            .plus,
            .minus,
            .paren_open,
            .paren_close,
            .index_open,
            .index_close,
            .block_open,
            .block_close,
            .dot1,
            .question1,
            .quote,
            .star,
            .bar1,
            .lt,
            .gt,
            .eq1,
            .comma,
            .colon,
            .semi,
            .caret,
                => 1,
            // .kw_as,
            // .kw_fn,
            // .kw_if,
            .dollar2,
            .percent_eq,
            .slash_eq,
            .plus_eq,
            .minus_eq,
            .arrow,
            .dot2,
            .dot_brace,
            .dot_index,
            .dot_question,
            .dot_star,
            .question2,
            .star_eq,
            .bar2,
            .lt_eq,
            .gt_eq,
            .eq2,
            .lt_gt,
                => 2,
            // .kw_for,
            // .kw_mut,
            // .kw_pub,
            .kw_try,
            .dollar3,
            .dot3,
            .lt_eq_gt,
                => 3,
            // .kw_else,
            // .kw_unit,
            // .kw_weak,
            //     => 4,
            // .kw_break,
            // .kw_catch,
            // .kw_defer,
            // .kw_exact,
            // .kw_match,
            // .kw_union,
            // .kw_until,
            // .kw_using,
            // .kw_while,
            //     => 5,
            // .kw_export,
            // .kw_import,
            // .kw_module,
            // .kw_packed,
            // .kw_repeat,
            // .kw_strong,
            // .kw_struct,
            //     => 6,
            // .kw_continue,
            // .kw_errdefer,
            //     => 8,
            // .kw_dimension,
            //     => 9,

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

            .linespace => blk: {
                var consume_newline = remaining[0] == '\\';
                var end: usize = 1;
                while (end < remaining.len) : (end += 1) {
                    switch (remaining[end]) {
                        0...9, 11...' ', 127 => {},
                        '\\' => {
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

            .reserved => blk: {
                var end: usize = 1;
                while (end < remaining.len) : (end += 1) {
                    switch (remaining[end]) {
                        '~', '!', '^', '&', '`' => {},
                        else => break,
                    }
                }
                break :blk end;
            },
        };

        return remaining[0..token_len];
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
};
pub const TokenList = std.MultiArrayList(Token);

fn checkKeyword(haystack: []const u8, kw: []const u8, kind: TokenKind) ?TokenKind {
    if (std.mem.eql(u8, haystack, kw)) {
        return kind;
    } else {
        return null;
    }
}

pub fn lex(allocator: std.mem.Allocator, source: []const u8) !TokenList {
    var tokens = TokenList {};
    try tokens.setCapacity(allocator, source.len / 2 + 100);

    var i: u32 = 0;
    while (i < source.len) {
        var token = Token {
            .offset = i,
            .kind = undefined,
        };
        token.kind = switch (source[i]) {
            'A'...'Z', '_', '@', 128...255 => .id,
            'a'...'z' => blk: {
                var remaining = source[i..];
                var end: usize = 1;
                while (end < remaining.len) : (end += 1) {
                    switch (remaining[end]) {
                        'a'...'z', 'A'...'Z', '_', '@', 128...255 => {},
                        else => break,
                    }
                }
                remaining = remaining[0..end];
                break :blk switch (source[i]) {
                    'a' => checkKeyword(remaining, "as", .kw_as) orelse .id,
                    'b' => checkKeyword(remaining, "break", .kw_break) orelse .id,
                    'c' => checkKeyword(remaining, "catch", .kw_catch) orelse checkKeyword(remaining, "continue", .kw_continue) orelse .id,
                    'd' => checkKeyword(remaining, "defer", .kw_defer) orelse checkKeyword(remaining, "dimension", .kw_dimension) orelse .id,
                    'e' => checkKeyword(remaining, "else", .kw_else) orelse checkKeyword(remaining, "errdefer", .kw_errdefer) orelse checkKeyword(remaining, "export", .kw_export) orelse checkKeyword(remaining, "exact", .kw_exact) orelse .id,
                    'f' => checkKeyword(remaining, "fn", .kw_fn) orelse checkKeyword(remaining, "for", .kw_for) orelse .id,
                    'i' => checkKeyword(remaining, "if", .kw_if) orelse checkKeyword(remaining, "import", .kw_import) orelse .id,
                    'm' => checkKeyword(remaining, "mut", .kw_mut) orelse checkKeyword(remaining, "match", .kw_match) orelse checkKeyword(remaining, "module", .kw_module) orelse .id,
                    'p' => checkKeyword(remaining, "pub", .kw_pub) orelse checkKeyword(remaining, "packed", .kw_packed) orelse .id,
                    'r' => checkKeyword(remaining, "repeat", .kw_repeat) orelse .id,
                    's' => checkKeyword(remaining, "struct", .kw_struct) orelse checkKeyword(remaining, "strong", .kw_strong) orelse .id,
                    't' => checkKeyword(remaining, "try", .kw_try) orelse .id,
                    'u' => checkKeyword(remaining, "using", .kw_using) orelse checkKeyword(remaining, "until", .kw_until) orelse checkKeyword(remaining, "union", .kw_union) orelse checkKeyword(remaining, "unit", .kw_unit) orelse .id,
                    'w' => checkKeyword(remaining, "while", .kw_while) orelse checkKeyword(remaining, "weak", .kw_weak) orelse .id,
                    else => .id,
                };
            },
            '\n' => .newline,
            '"' => .string_literal,
            '0'...'9' => .numeric_literal,
            '#' => .octothorpe,
            '(' => .paren_open,
            ')' => .paren_close,
            '[' => .index_open,
            ']' => .index_close,
            '{' => .block_open,
            '}' => .block_close,
            ',' => .comma,
            ':' => .colon,
            ';' => .semi,
            '^' => .caret,
            0...9, 11...' ', '\\', 127 => if (source[i] == '\\' and source.len > i + 1 and source[i + 1] == '\\') .line_string_literal else .linespace,
            '/' => if (source.len <= i + 1) .slash else switch (source[i + 1]) {
                '/' => .comment,
                '=' => .slash_eq,
                else => .slash,
            },
            '$' => if (source.len > i + 1 and source[i + 1] == '$') blk: {
                break :blk if (source.len > i + 2 and source[i + 2] == '$') .dollar3 else .dollar2;
            } else .dollar1,
            '%' => if (source.len > i + 1 and source[i + 1] == '=') .percent_eq else .percent,
            '+' => if (source.len > i + 1 and source[i + 1] == '=') .plus_eq else .plus,
            '-' => if (source.len <= i + 1) .minus else switch (source[i + 1]) {
                '>' => .arrow,
                '=' => .minus_eq,
                else => .minus,
            },
            '.' => if (source.len <= i + 1) .dot1 else switch (source[i + 1]) {
                '.' => if (source.len > i + 2 and source[i + 2] == '.') .dot3 else .dot2,
                '{' => .dot_brace,
                '[' => .dot_index,
                '?' => .dot_question,
                '*' => .dot_star,
                else => .dot1,
            },
            '?' => if (source.len > i + 1 and source[i + 1] == '?') .question2 else .question1,
            '\'' => .quote,
            '*' => if (source.len > i + 1 and source[i + 1] == '=') .star_eq else .star,
            '|' => if (source.len > i + 1 and source[i + 1] == '|') .bar2 else .bar1,
            '=' => if (source.len > i + 1 and source[i + 1] == '=') .eq2 else .eq1,
            '<' => if (source.len <= i + 1) .lt else switch (source[i + 1]) {
                '=' => if (source.len > i + 2 and source[i + 2] == '>') .lt_eq_gt else .lt_eq,
                '>' => .lt_gt,
                else => .lt,
            },
            '>' => if (source.len > i + 1 and source[i + 1] == '=') .gt_eq else .gt,
            '~', '!', '&', '`' => .reserved,
        };

        try tokens.append(allocator, token);
        i += @intCast(u32, token.location(source).len);
    }

    try tokens.append(allocator, .{
        .offset = source.len,
        .kind = .eof,
    });

    if (tokens.capacity > (tokens.len / 4) * 5) blk: {
        var old = tokens;
        tokens = tokens.clone(allocator) catch break :blk;
        old.deinit(allocator);
    }
    return tokens;
}


test "Lexer" {
    const src =
            \\"Hello world",\  
            \\ arg\  f :: \ f(a+b || c)
            \\      x += 1\  ___3 -> -3 {
            \\          .[ asdf..2... ] <=> {}
            ;

    var tokens = try lex(std.testing.allocator, src);
    defer tokens.deinit(std.testing.allocator);
    var stdout = std.io.getStdOut().writer();
    for (tokens.items(.kind)) |_, i| {
        const token = tokens.get(i);
        try stdout.print(".{s}\t\"{}\"\n", .{ @tagName(token.kind), std.zig.fmtEscapes(token.location(src)) });
    }
    try stdout.print("{} tokens\n", .{ tokens.len });
}

test "Lexer sieve" {
    const src = @embedFile("examples/sieve.zyx");
    var tokens = try lex(std.testing.allocator, src);
    defer tokens.deinit(std.testing.allocator);
    var stdout = std.io.getStdOut().writer();
    for (tokens.items(.kind)) |_, i| {
        const token = tokens.get(i);
        try stdout.print(".{s}\t\"{}\"\n", .{ @tagName(token.kind), std.zig.fmtEscapes(token.location(src)) });
    }
    try stdout.print("{} tokens\n", .{ tokens.len });
}
