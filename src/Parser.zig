const std = @import("std");
const console = @import("console");
const Token = @import("Token.zig");
const Error = @import("Error.zig");
const Source = @import("Source.zig");
const Declaration = @import("Declaration.zig");
const Expression = @import("Expression.zig");
const Compiler = @import("Compiler");

const Parser = @This();

gpa: std.mem.Allocator,
temp_arena: std.mem.Allocator,
errors: std.ArrayListUnmanaged(Error) = .{},

source_handle: Source.Handle = 0,
token_kinds: []Token.Kind = &.{},
next_token: Token.Handle = 0,

declarations: std.MultiArrayList(Declaration) = .{},
expressions: std.MultiArrayList(Expression) = .{},
module_decls: std.ArrayListUnmanaged(Declaration.Handle) = .{},

const SyncError = error{Sync};

pub fn init(gpa: std.mem.Allocator, temp_arena: std.mem.Allocator) Parser {
    return .{
        .gpa = gpa,
        .temp_arena = temp_arena,
    };
}

pub fn deinit(self: *Parser) void {
    self.module_decls.deinit(self.gpa);
    self.declarations.deinit(self.gpa);
    self.errors.deinit(self.gpa);
}

pub fn parse(self: *Parser, source_handle: Source.Handle, token_kinds: []Token.Kind) void {
    std.debug.assert(self.errors.items.len == 0);
    std.debug.assert(self.declarations.len == 0);
    std.debug.assert(self.module_decls.items.len == 0);

    self.source_handle = source_handle;
    self.token_kinds = token_kinds;
    self.next_token = 0;

    while (!self.tryToken(.eof)) {
        const maybe_decl = self.tryDeclaration(.{ .allow_field = true }) catch {
            self.syncPastToken(.newline);
            continue;
        };
        if (maybe_decl) |handle| {
            self.module_decls.append(self.gpa, handle) catch @panic("OOM");
        } else if (self.tryNewline()) {
            continue;
        } else {
            const first = self.next_token;
            self.syncPastToken(.newline);
            var last = self.backtrackToken(self.next_token, .{});
            if (first + 50 < last) {
                self.recordErrorAbs("Expected a declaration", first, Error.FlagSet.initOne(.has_continuation));
                self.recordErrorAbs("End of item", last, Error.FlagSet.initOne(.supplemental));
            } else {
                self.recordErrorAbsRange("Expected a declaration", .{
                    .first = first,
                    .last = last,
                }, .{});
            }
        }
    }
}

const TryDeclarationOptions = struct {
    allow_field: bool = false,
};
fn tryDeclaration(self: *Parser, options: TryDeclarationOptions) SyncError!?Declaration.Handle {
    var flags = Declaration.FlagSet.initEmpty();

    const start_token = self.next_token;

    self.skipLinespace();
    const token_handle = self.tryIdentifier() orelse blk: {
        if (options.allow_field) {
            if (self.trySymbol()) |token_handle| {
                flags.insert(.field);
                break :blk token_handle;
            }
        }
        self.next_token = start_token;
        return null;
    };

    self.skipLinespace();
    if (!self.tryToken(.colon)) {
        self.next_token = start_token;
        return null;
    }

    var type_expr_handle: ?Expression.Handle = null;

    self.skipLinespace();
    if (self.tryToken(.colon)) {
        flags.insert(.constant);
    } else if (self.tryToken(.eql)) {
        // non-constant
    } else if (self.tryToken(.kw_mut)) {
        flags.insert(.mutable);

        self.skipLinespace();
        if (try self.tryExpression()) |type_expr| {
            type_expr_handle = type_expr;
        }

        self.skipLinespace();
        if (self.tryToken(.colon)) {
            flags.insert(.constant);
        } else if (self.tryToken(.eql)) {
            // non-constant
        } else {
            self.recordErrorAbs("Failed to parse declaration", token_handle, Error.FlagSet.initMany(&.{ .supplemental, .has_continuation }));
            self.recordError("Expected ':' or '=' followed by initializer expression", .{});
            return error.Sync;
        }
    } else if (try self.tryExpression()) |type_expr| {
        type_expr_handle = type_expr;

        self.skipLinespace();
        if (self.tryToken(.colon)) {
            flags.insert(.constant);
        } else if (self.tryToken(.eql)) {
            // non-constant
        } else {
            self.recordErrorAbs("Failed to parse declaration", token_handle, Error.FlagSet.initMany(&.{ .supplemental, .has_continuation }));
            self.recordError("Expected ':' or '=' followed by initializer expression", .{});
            return error.Sync;
        }
    } else {
        self.recordErrorAbs("Failed to parse declaration", token_handle, Error.FlagSet.initMany(&.{ .supplemental, .has_continuation }));
        self.recordError("Expected ':' or '=' or type expression", .{});
        return error.Sync;
    }

    self.skipLinespace();
    const initializer_expr_handle = try self.tryExpression() orelse {
        self.recordErrorAbs("Failed to parse declaration", token_handle, Error.FlagSet.initMany(&.{ .supplemental, .has_continuation }));
        self.recordError("Expected initializer expression", .{});
        return error.Sync;
    };

    if (!self.tryNewline()) {
        self.recordErrorAbs("Failed to parse declaration", token_handle, Error.FlagSet.initMany(&.{ .supplemental, .has_continuation }));
        self.recordError("Expected end of line", .{});
        return error.Sync;
    }

    const handle = @intCast(Declaration.Handle, self.declarations.len);
    self.declarations.append(self.gpa, .{
        .token_handle = token_handle,
        .type_or_dim_expr_handle = type_expr_handle,
        .initializer_expr_handle = initializer_expr_handle,
        .flags = flags,
    }) catch @panic("OOM");

    return handle;
}

fn tryExpression(self: *Parser) SyncError!?Expression.Handle {
    // TODO memoize
    return self.tryExpressionPratt(0);
}

const OperatorInfo = struct {
    token: Token.Handle,

    // If used, this should be an expression from tryExpression, not tryExpressionPratt or tryPrimaryExpression
    // This ensures that if the operator is rejected, the expression won't leak
    other: ?Expression.Handle,

    kind: Expression.Kind,
    left_bp: u8,

    // When null, this must be used as a suffix operator, otherwise it can be a binary operator.
    right_bp: ?u8,

    // When both right_bp and alt_when_suffix are non-null, this may be either an infix or a suffix operator.
    // When it functions as a suffix, these override the values from the outer struct:
    alt_when_suffix: ?struct {
        // This must be at least as large as the outer left_bp
        left_bp: u8,
        kind: Expression.Kind,
    },
};
fn tryPrefixOperator(self: *Parser) SyncError!?OperatorInfo {
    const begin = self.next_token;
    self.skipLinespace();
    const t = self.next_token;
    const kind = self.token_kinds[t];

    if (kind == .eof) {
        self.next_token = begin;
        return null;
    }

    self.next_token += 1;

    const base_bp: u8 = if (self.tryLinespace()) 0x40 else 0xC0;
    var info = OperatorInfo{
        .token = t,
        .other = null,
        .kind = undefined,
        .left_bp = 0xFF, // this should only be changed if you want to prevent certain nested unary operator combinations
        .right_bp = base_bp,
        .alt_when_suffix = null,
    };
    switch (kind) {
        .kw_return => {
            info.right_bp = base_bp - 0x38;
            info.kind = .return_expr;
        },
        .kw_break => {
            info.right_bp = base_bp - 0x38;
            info.kind = .break_expr;
        },

        .kw_try => {
            info.right_bp = base_bp - 0x30;
            info.kind = .try_expr;
        },

        .kw_not => {
            info.right_bp = base_bp - 0x5;
            info.kind = .logical_not;
        },

        .kw_mut      => { info.kind = .mut_type; },
        .kw_distinct => { info.kind = .distinct_type; },
        .kw_error    => { info.kind = .error_type; },

        .tilde => {
            info.right_bp = base_bp + 0x2D;
            info.kind = .range_expr_infer_start_exclusive_end;
        },
        .tilde_tilde => {
            info.right_bp = base_bp + 0x2D;
            info.kind = .range_expr_infer_start_inclusive_end;
        },

        .question => {
            info.right_bp = base_bp + 0x3D;
            info.kind = .optional_type;
        },
        .star => {
            info.right_bp = base_bp + 0x3D;
            info.kind = .make_pointer;
        },
        .dash => {
            info.right_bp = base_bp + 0x3D;
            info.kind = .negate;
        },
        .index_open => {
            info.right_bp = base_bp + 0x3D;
            const index_expr = try self.tryExpression();
            self.skipLinespace();
            if (self.tryToken(.index_close)) {
                info.kind = if (index_expr) |_| .array_type else .slice_type;
                info.other = index_expr;
            } else {
                const error_token = self.next_token;

                self.recordErrorAbsRange("Failed to parse array/slice type literal prefix", .{
                    .first = t,
                    .last = error_token,
                }, Error.FlagSet.initMany(&.{ .supplemental, .has_continuation }));
                self.recordErrorAbs("Expected ']'", error_token, .{});
                return error.Sync;
            }
        },

        else => {
            self.next_token = begin;
            return null;
        },
    }
    return info;
}
fn tryOperator(self: *Parser) SyncError!?OperatorInfo {
    const begin = self.next_token;
    const linespace_before = self.tryLinespace();
    const t = self.next_token;
    const kind = self.token_kinds[t];

    if (kind == .eof) {
        self.next_token = begin;
        return null;
    }

    self.next_token += 1;
    const linespace_after = self.tryLinespace();

    const left_base: u8 = if (linespace_before) 0x40 else 0xC0;
    const right_base: u8 = if (linespace_after) 0x40 else 0xC0;
    var info = OperatorInfo{
        .token = t,
        .other = null,
        .kind = undefined,
        .left_bp = left_base,
        .right_bp = right_base + 1,
        .alt_when_suffix = null,
    };

    switch (kind) {
        .octothorpe  => {
            info.left_bp = left_base - 0x3F;
            info.right_bp = right_base - 0x3E;
            info.kind = .apply_tag;
        },

        .bar => {
            info.left_bp = left_base - 0x13;
            info.right_bp = right_base - 0x12;
            info.kind = .type_sum_operator;
        },

        .amp => {
            info.left_bp = left_base - 0x11;
            info.right_bp = right_base - 0x10;
            info.kind = .type_product_operator;
        },

        .kw_or => {
            info.left_bp = left_base - 0xA;
            info.right_bp = right_base - 0x9;
            info.kind = .logical_or;
        },

        .kw_and => {
            info.left_bp = left_base - 0x8;
            info.right_bp = right_base - 0x7;
            info.kind = .logical_and;
        },

        // not = -5

        .eql_eql     => { info.left_bp = left_base - 0x4; info.right_bp = right_base - 0x3; info.kind = .test_equal; },
        .diamond     => { info.left_bp = left_base - 0x4; info.right_bp = right_base - 0x3; info.kind = .test_inequal; },

        .lt          => { info.left_bp = left_base - 0x2; info.right_bp = right_base - 0x1; info.kind = .test_less_than; },
        .gt          => { info.left_bp = left_base - 0x2; info.right_bp = right_base - 0x1; info.kind = .test_greater_than; },
        .lt_eql      => { info.left_bp = left_base - 0x2; info.right_bp = right_base - 0x1; info.kind = .test_less_than_or_equal; },
        .gt_eql      => { info.left_bp = left_base - 0x2; info.right_bp = right_base - 0x1; info.kind = .test_greater_than_or_equal; },
        .spaceship   => { info.left_bp = left_base - 0x2; info.right_bp = right_base - 0x1; info.kind = .compare; },
        .kw_is       => { info.left_bp = left_base - 0x2; info.right_bp = right_base - 0x1; info.kind = .test_active_field; },

        .kw_else     => { info.kind = .coalesce; },
        .kw_catch    => { info.kind = .catch_expr; },
        .apostrophe => {
            if (linespace_before == linespace_after) {
                info.kind = .ambiguous_call;
            } else if (linespace_before) {
                info.kind = .suffix_call;
            } else {
                info.kind = .prefix_call;
            }
        },

        .tilde => { 
            info.left_bp = left_base + 0x20;
            info.right_bp = right_base + 0x21;
            info.kind = .range_expr_exclusive_end;
            info.alt_when_suffix = .{
                .left_bp = left_base + 0x20,
                .kind = .range_expr_infer_end,
            };
        },
        .tilde_tilde => {
            info.left_bp = left_base + 0x20;
            info.right_bp = right_base + 0x21;
            info.kind = .range_expr_inclusive_end;
            info.alt_when_suffix = .{
                .left_bp = left_base + 0x20,
                .kind = .range_expr_infer_end,
            };
        },

        .kw_as => {
            info.left_bp = left_base + 0x2E;
            info.right_bp = right_base + 0x2F;
            info.kind = .coerce;
        },

        .kw_in => {
            info.left_bp = left_base + 0x31;
            info.right_bp = right_base + 0x30;
            info.kind = .apply_dim;
        },

        .plus_plus => {
            info.left_bp = left_base + 0x32;
            info.right_bp = right_base + 0x33;
            info.kind = .array_concat;
        },

        .star_star => {
            info.left_bp = left_base + 0x34;
            info.right_bp = right_base + 0x35;
            info.kind = .array_repeat;
        },

        .plus => {
            info.left_bp = left_base + 0x36;
            info.right_bp = right_base + 0x37;
            info.kind = .add;
        },
        .dash => {
            info.left_bp = left_base + 0x36;
            info.right_bp = right_base + 0x37;
            info.kind = .subtract;
        },

        .star => {
            info.left_bp = left_base + 0x38;
            info.right_bp = right_base + 0x39;
            info.kind = .multiply;
            info.alt_when_suffix = .{
                .left_bp = left_base + 0x3E,
                .kind = .unmake_pointer,
            };
        },
        .slash => {
            info.left_bp = left_base + 0x38;
            info.right_bp = right_base + 0x39;
            info.kind = .divide_exact;
        },

        .caret => {
            info.left_bp = left_base + 0x3B;
            info.right_bp = right_base + 0x3A;
            info.kind = .raise_exponent;
        },

        // prefix operators = 0x3C, 0x3D

        // postfix .star
        .dot => {
            info.left_bp = left_base + 0x3E;
            info.right_bp = right_base + 0x3F;
            info.kind = .member_access;
        },
        .index_open => {
            if (try self.tryExpression()) |index_expr| {
                self.skipLinespace();
                if (self.tryToken(.index_close)) {
                    info.left_bp = left_base + 0x3E;
                    info.right_bp = null;
                    info.kind = .indexed_access;
                    info.other = index_expr;
                    return info;
                } else {
                    const error_token = self.next_token;

                    self.recordErrorAbsRange("Failed to parse index expression", .{
                        .first = t,
                        .last = error_token,
                    }, Error.FlagSet.initMany(&.{ .supplemental, .has_continuation }));
                    self.recordErrorAbs("Expected ']'", error_token, .{});
                    return error.Sync;
                }
            } else {
                const error_token = self.next_token;

                self.recordErrorAbsRange("Failed to parse index expression", .{
                    .first = t,
                    .last = error_token,
                }, Error.FlagSet.initMany(&.{ .supplemental, .has_continuation }));
                self.recordErrorAbs("Expected expression", error_token, .{});
                return error.Sync;
            }
        },

        else => {
            self.next_token = begin;
            return null;
        },
    }
    return info;
}

fn tryExpressionPratt(self: *Parser, min_binding_power: u8) SyncError!?Expression.Handle {
    const before_prefix_operator = self.next_token;

    var expr = if (try self.tryPrefixOperator()) |operator| e: {
        if (operator.left_bp >= min_binding_power) {
            if (try self.tryExpressionPratt(operator.right_bp.?)) |right| {
                if (operator.other) |left| {
                    break :e self.addBinaryExpression(operator.kind, operator.token, left, right);
                } else {
                    break :e self.addUnaryExpression(operator.kind, operator.token, right);
                }
            }
        }
        self.next_token = before_prefix_operator;
        return null;
    } else (try self.tryPrimaryExpression()) orelse return null;

    var expr_is_suffix_call = false;
    while (true) {
        const before_operator = self.next_token;
        if (try self.tryOperator()) |operator| {
            if (operator.left_bp >= min_binding_power) {
                if (operator.right_bp) |binding_power| {
                    std.debug.assert(operator.other == null);
                    if (try self.tryExpressionPratt(binding_power)) |right| {
                        if (operator.kind == .prefix_call and expr_is_suffix_call) {
                            const suffix_call = self.expressions.items(.info)[expr].suffix_call;
                            var args_expr = self.addBinaryExpression(.infix_call_args, operator.token, suffix_call.left, right);

                            self.expressions.items(.info)[expr] = .{ .infix_call = .{
                                .left = suffix_call.right,
                                .right = args_expr
                            }};
                            expr_is_suffix_call = false;
                            continue;
                        }

                        std.debug.print("left_bp:{}  right_bp:{}  kind:{s}\n", .{ operator.left_bp, binding_power, @tagName(operator.kind) });
                        expr = self.addBinaryExpression(operator.kind, operator.token, expr, right);
                        expr_is_suffix_call = operator.kind == .suffix_call;
                        continue;
                    } else if (operator.alt_when_suffix) |alt_operator| {
                        if (alt_operator.left_bp >= min_binding_power and try self.tryExpression() == null) {
                            expr = self.addUnaryExpression(alt_operator.kind, operator.token, expr);
                            expr_is_suffix_call = false;
                            continue;
                        }
                    }
                } else if (operator.other) |right| {
                    expr = self.addBinaryExpression(operator.kind, operator.token, expr, right);
                    expr_is_suffix_call = false;
                    continue;
                } else {
                    expr = self.addUnaryExpression(operator.kind, operator.token, expr);
                    expr_is_suffix_call = false;
                    continue;
                }
            }
        }
        self.next_token = before_operator;
        break;
    }

    return expr;
}

fn tryPrimaryExpression(self: *Parser) SyncError!?Expression.Handle {
    const begin = self.next_token;
    self.skipLinespace();
    const token_handle = self.next_token;
    return switch (self.token_kinds[token_handle]) {
        .id => self.consumeTerminalExpression(.id_ref),
        .paren_open => try self.parenExpression(),
        .string_literal, .line_string_literal => self.stringLiteral(),
        .numeric_literal => self.consumeTerminalExpression(.numeric_literal),
        .dot => if (self.trySymbol()) |symbol_token_handle| self.addTerminalExpression(.symbol, symbol_token_handle) else null,
        else => {
            self.next_token = begin;
            return null;
        },
    };
}

fn parenExpression(self: *Parser) SyncError!?Expression.Handle {
    const expr_begin = self.next_token;
    std.debug.assert(self.token_kinds[expr_begin] == .paren_open);
    self.next_token += 1;
    self.skipLinespace();
    if (try self.tryExpression()) |expr| {
        self.skipLinespace();
        if (!self.tryToken(.paren_close)) {
            const error_token = self.next_token;

            self.recordErrorAbsRange("Failed to parse parenthesized expression", .{
                .first = expr_begin,
                .last = error_token,
            }, Error.FlagSet.initMany(&.{ .supplemental, .has_continuation }));
            self.recordErrorAbs("Expected ')'", error_token, .{});
            return error.Sync;
        }
        return self.addUnaryExpression(.group, expr_begin, expr);
    }

    const error_token = self.next_token;

    self.recordErrorAbsRange("Failed to parse parenthesized expression", .{
        .first = expr_begin,
        .last = error_token,
    }, Error.FlagSet.initMany(&.{ .supplemental, .has_continuation }));
    self.recordErrorAbs("Expected expression", error_token, .{});
    return error.Sync;
}

fn stringLiteral(self: *Parser) Expression.Handle {
    const literal_token = self.next_token;
    if (self.tryToken(.string_literal)) {
        return self.addTerminalExpression(.string_literal, literal_token);
    } else if (self.tryToken(.line_string_literal)) {
        while (true) {
            const end = self.next_token;
            if (!self.tryToken(.newline)) break;
            self.skipLinespace();
            if (self.tryToken(.line_string_literal)) continue;

            self.next_token = end;
            break;
        }
        return self.addTerminalExpression(.string_literal, literal_token);
    } else unreachable;
}

fn trySymbol(self: *Parser) ?Token.Handle {
    const start_token = self.next_token;
    if (self.tryToken(.dot)) {
        if (self.tryIdentifier()) |token_handle| {
            return token_handle;
        }
    }
    self.next_token = start_token;
    return null;
}

fn tryIdentifier(self: *Parser) ?Token.Handle {
    if (self.tryToken(.id)) {
        return self.next_token - 1;
    }
    return null;
}

fn tryNewline(self: *Parser) bool {
    const begin = self.next_token;
    self.skipLinespace();
    switch (self.token_kinds[self.next_token]) {
        .newline => {
            self.next_token += 1;
            return true;
        },
        .eof => return true,
        else => {
            self.next_token = begin;
            return false;
        }
    }
}

fn tryWhitespace(self: *Parser) bool {
    var found = false;
    while (switch (self.token_kinds[self.next_token]) {
        .linespace, .newline, .comment => true,
        else => false,
    }) {
        self.next_token += 1;
        found = true;
    }
    return found;
}

fn skipWhitespace(self: *Parser) void {
    while (switch (self.token_kinds[self.next_token]) {
        .linespace, .newline, .comment => true,
        else => false,
    }) {
        self.next_token += 1;
    }
}

fn tryLinespace(self: *Parser) bool {
    var found = false;
    while (switch (self.token_kinds[self.next_token]) {
        .linespace, .comment => true,
        else => false,
    }) {
        self.next_token += 1;
        found = true;
    }
    return found;
}

fn skipLinespace(self: *Parser) void {
    while (switch (self.token_kinds[self.next_token]) {
        .linespace, .comment => true,
        else => false,
    }) {
        self.next_token += 1;
    }
}

fn tryToken(self: *Parser, kind: Token.Kind) bool {
    if (self.token_kinds[self.next_token] == kind) {
        self.next_token += 1;
        return true;
    } else {
        return false;
    }
}

fn syncPastToken(self: *Parser, kind: Token.Kind) void {
    while (true) {
        const found = self.token_kinds[self.next_token];
        self.next_token += 1;
        if (found == kind) {
            return;
        }
        switch (found) {
            .block_open => self.syncPastToken(.block_close),

            .kw_not, .kw_try, .kw_mut, .kw_break, .kw_error, .kw_distinct, .kw_return,
            .dot, .colon, .eql, .dash, .question, .star, .apostrophe, .tilde, .tilde_tilde,
            .reserved, .linespace, .newline, .id, .comment, .plus, .slash,
            .line_string_literal, .string_literal, .numeric_literal,
            .bar, .amp, .octothorpe, .money, .caret,
            .kw_as, .kw_in, .kw_is, .kw_else,
            .kw_catch, .kw_and, .kw_or, .index_open, .paren_open,
            .dot_paren_open, .dot_index_open, .dot_block_open,
            .thin_arrow, .thick_arrow, .plus_plus, .star_star,
            .spaceship, .diamond, .lt, .gt, .lt_eql, .gt_eql, .eql_eql,
            .paren_close, .index_close, .block_close => {},

            .eof => {
                self.next_token -= 1;
                return;
            },
        }
    }
}

const BacktrackOptions = struct {
    any_one_token: bool = true,
    eof: bool = true,
    newline: bool = true,
    comment: bool = true,
    linespace: bool = true,
};
fn backtrackToken(self: *Parser, token_handle: Token.Handle, options: BacktrackOptions) Token.Handle {
    var t = token_handle;
    if (t == 0) return t;

    const token_kinds = self.token_kinds;

    if (options.any_one_token or options.eof and token_kinds[t] == .eof) {
        t -= 1;
        if (t == 0) return t;
    }

    if (options.newline and token_kinds[t] == .newline) {
        t -= 1;
        if (t == 0) return t;
    }

    if (options.comment and token_kinds[t] == .comment) {
        t -= 1;
        if (t == 0) return t;
    }

    if (options.linespace and token_kinds[t] == .linespace) {
        t -= 1;
    }

    return t;
}

fn consumeTerminalExpression(self: *Parser, kind: Expression.Kind) Expression.Handle {
    const token_handle = self.next_token;
    self.next_token += 1;
    return self.addTerminalExpression(kind, token_handle);
}

fn addTerminalExpression(self: *Parser, kind: Expression.Kind, token_handle: Token.Handle) Expression.Handle {
    @setEvalBranchQuota(10000);
    switch (kind) {
        inline else => |k| if (std.meta.FieldType(Expression.Info, k) == void) {
            const info = @unionInit(Expression.Info, @tagName(k), {});
            return self.addExpressionInfo(token_handle, info);
        },
    }
    unreachable;
}

fn addUnaryExpression(self: *Parser, kind: Expression.Kind, token_handle: Token.Handle, inner: Expression.Handle) Expression.Handle {
    @setEvalBranchQuota(10000);
    switch (kind) {
        inline else => |k| if (std.meta.FieldType(Expression.Info, k) == Expression.Handle) {
            const info = @unionInit(Expression.Info, @tagName(k), inner);
            return self.addExpressionInfo(token_handle, info);
        },
    }
    unreachable;
}

fn addBinaryExpression(self: *Parser, kind: Expression.Kind, token_handle: Token.Handle, left: Expression.Handle, right: Expression.Handle) Expression.Handle {
    @setEvalBranchQuota(10000);
    switch (kind) {
        inline else => |k| if (std.meta.FieldType(Expression.Info, k) == Expression.Binary) {
            const info = @unionInit(Expression.Info, @tagName(k), .{ .left = left, .right = right });
            return self.addExpressionInfo(token_handle, info);
        },
    }
    unreachable;
}

fn addExpressionInfo(self: *Parser, token_handle: Token.Handle, info: Expression.Info) Expression.Handle {
    const handle = @intCast(Expression.Handle, self.expressions.len);
    self.expressions.append(self.gpa, .{
        .token_handle = token_handle,
        .info = info,
        .flags = .{},
    }) catch @panic("OOM");
    return handle;
}

fn recordError(self: *Parser, desc: []const u8, flags: Error.FlagSet) void {
    self.recordErrorAbs(desc, self.next_token, flags);
}
fn recordErrorRel(self: *Parser, desc: []const u8, token_offset: i8, flags: Error.FlagSet) void {
    self.recordErrorAbs(desc, @intCast(Token.Handle, @as(i64, self.next_token) + token_offset), flags);
}
fn recordErrorAbs(self: *Parser, desc: []const u8, token: Token.Handle, flags: Error.FlagSet) void {
    self.errors.append(self.gpa, .{
        .source_handle = self.source_handle,
        .context = .{ .token = token },
        .desc = desc,
        .flags = flags,
    }) catch @panic("OOM");
}

fn recordErrorAbsRange(self: *Parser, desc: []const u8, range: Token.Range, flags: Error.FlagSet) void {
    self.errors.append(self.gpa, .{
        .source_handle = self.source_handle,
        .context = .{ .token_range = range },
        .desc = desc,
        .flags = flags,
    }) catch @panic("OOM");
}

const DumpContext = struct {
    source_text: []const u8,
    token_offsets: []const u32,
    styles: []const console.Style,
    next_style: usize = 0,
};

pub fn dump(self: *Parser, ctx: DumpContext, writer: anytype) !void {
    var mut_ctx = ctx;

    for (self.module_decls.items) |decl_handle| {
        if (mut_ctx.styles.len > 0) {
            try mut_ctx.styles[mut_ctx.next_style].apply(writer);
            mut_ctx.next_style = (mut_ctx.next_style + 1) % mut_ctx.styles.len;
        }
        try self.dumpDecl(&mut_ctx, writer, "Declaration:", decl_handle, .{}, .{});
        try writer.writeByte('\n');
    }

    if (mut_ctx.styles.len > 0) {
        try (console.Style{}).apply(writer);
    }
}

const DumpPrefix = struct {
    prev: ?*const DumpPrefix = null,
    prefix: []const u8 = "",

    pub fn dump(self: DumpPrefix, writer: anytype) !void {
        if (self.prev) |prev| try prev.dump(writer);
        try writer.writeAll(self.prefix);
    }
};

fn dumpDecl(self: *Parser, ctx: *DumpContext, writer: anytype, label: []const u8, decl_handle: Declaration.Handle, first: DumpPrefix, extra: DumpPrefix) !void {
    try first.dump(writer);

    var style_buf1: [32]u8 = undefined;
    var style_buf2: [32]u8 = undefined;

    var set_style: []const u8 = "";
    var reset_style: []const u8 = "";
    if (ctx.styles.len > 0) {
        var stream1 = std.io.fixedBufferStream(&style_buf1);
        try ctx.styles[ctx.next_style].apply(stream1.writer());
        set_style = stream1.getWritten();

        var stream2 = std.io.fixedBufferStream(&style_buf2);
        try (console.Style{}).apply(stream2.writer());
        reset_style = stream2.getWritten();

        ctx.next_style = (ctx.next_style + 1) % ctx.styles.len;
    }

    try writer.writeAll(label);
    try writer.writeAll(set_style);

    const decl = self.declarations.get(decl_handle);
    var iter = decl.flags.iterator();
    while (iter.next()) |flag| {
        try writer.print(" {s}", .{ @tagName(flag) });
    }

    const token = Token.init(.{
        .kind = self.token_kinds[decl.token_handle],
        .offset = ctx.token_offsets[decl.token_handle],
    }, ctx.source_text);

    try writer.print(" '{s}'", .{ std.fmt.fmtSliceEscapeUpper(token.text) });

    try writer.writeAll(reset_style);
    try writer.writeByte('\n');

    if (decl.type_or_dim_expr_handle) |expr_handle| {
        var buf1: [40]u8 = undefined;
        var buf2: [40]u8 = undefined;

        var new_first = DumpPrefix{ .prev = &extra, .prefix = undefined };
        var new_extra = DumpPrefix{ .prev = &extra, .prefix = undefined };

        new_first.prefix = try std.fmt.bufPrint(&buf1, "{s} *= ", .{ set_style });

        if (decl.initializer_expr_handle != null) {
            new_extra.prefix = try std.fmt.bufPrint(&buf2, "{s} |  ", .{ set_style });
        } else {
            new_extra.prefix = try std.fmt.bufPrint(&buf2, "{s}    ", .{ set_style });
        }

        try self.dumpExpr(ctx, writer, "Type:", expr_handle, new_first, new_extra);
    }

    if (decl.initializer_expr_handle) |expr_handle| {
        var buf1: [40]u8 = undefined;
        var buf2: [40]u8 = undefined;

        var new_first = DumpPrefix{ .prev = &extra, .prefix = undefined };
        var new_extra = DumpPrefix{ .prev = &extra, .prefix = undefined };

        new_first.prefix = try std.fmt.bufPrint(&buf1, "{s} *= ", .{ set_style });
        new_extra.prefix = try std.fmt.bufPrint(&buf2, "{s}    ", .{ set_style });

        try self.dumpExpr(ctx, writer, "Init:", expr_handle, new_first, new_extra);
    }
}

fn dumpExpr(self: *Parser, ctx: *DumpContext, writer: anytype, label: []const u8, decl_handle: Expression.Handle, first: DumpPrefix, extra: DumpPrefix) !void {
    try first.dump(writer);

    var style_buf1: [32]u8 = undefined;
    var style_buf2: [32]u8 = undefined;

    var set_style: []const u8 = "";
    var reset_style: []const u8 = "";
    if (ctx.styles.len > 0) {
        var stream1 = std.io.fixedBufferStream(&style_buf1);
        try ctx.styles[ctx.next_style].apply(stream1.writer());
        set_style = stream1.getWritten();

        var stream2 = std.io.fixedBufferStream(&style_buf2);
        try (console.Style{}).apply(stream2.writer());
        reset_style = stream2.getWritten();

        ctx.next_style = (ctx.next_style + 1) % ctx.styles.len;
    }

    try writer.writeAll(label);
    try writer.writeAll(set_style);

    const expr = self.expressions.get(decl_handle);
    const tag = @as(Expression.Kind, expr.info);
    try writer.print(" {s}", .{ @tagName(tag) });
    var iter = expr.flags.iterator();
    while (iter.next()) |flag| {
        try writer.print(" {s}", .{ @tagName(flag) });
    }

    @setEvalBranchQuota(10000);
    switch (tag) {
        inline else => |k| {
            const F = std.meta.FieldType(Expression.Info, k);
            if (F == Expression.Handle) {
                try writer.writeAll(reset_style);
                try writer.writeByte('\n');

                var buf1: [40]u8 = undefined;
                var buf2: [40]u8 = undefined;

                var new_first = DumpPrefix{ .prev = &extra, .prefix = undefined };
                var new_extra = DumpPrefix{ .prev = &extra, .prefix = undefined };

                new_first.prefix = try std.fmt.bufPrint(&buf1, "{s} *= ", .{ set_style });
                new_extra.prefix = try std.fmt.bufPrint(&buf2, "{s}    ", .{ set_style });

                try self.dumpExpr(ctx, writer, "X:", @field(expr.info, @tagName(k)), new_first, new_extra);

            } else if (F == Expression.Binary) {
                try writer.writeAll(reset_style);
                try writer.writeByte('\n');

                var buf1: [40]u8 = undefined;
                var buf2: [40]u8 = undefined;

                var new_first = DumpPrefix{ .prev = &extra, .prefix = undefined };
                var new_extra = DumpPrefix{ .prev = &extra, .prefix = undefined };

                new_first.prefix = try std.fmt.bufPrint(&buf1, "{s} *= ", .{ set_style });
                new_extra.prefix = try std.fmt.bufPrint(&buf2, "{s} |  ", .{ set_style });


                const bin = @field(expr.info, @tagName(k));
                try self.dumpExpr(ctx, writer, "L:", bin.left, new_first, new_extra);

                new_extra.prefix = try std.fmt.bufPrint(&buf2, "{s}    ", .{ set_style });
                try self.dumpExpr(ctx, writer, "R:", bin.right, new_first, new_extra);

            } else if (F == void) {
                if (k == .id_ref) {
                    const token = Token.init(.{
                        .kind = self.token_kinds[expr.token_handle],
                        .offset = ctx.token_offsets[expr.token_handle],
                    }, ctx.source_text);

                    try writer.print(" '{s}'", .{ std.fmt.fmtSliceEscapeUpper(token.text) });
                }

                try writer.writeAll(reset_style);
                try writer.writeByte('\n');
            } else {
                unreachable;
            }
        },
    }
}